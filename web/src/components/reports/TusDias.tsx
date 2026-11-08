import React, { useEffect, useRef, useState, useMemo } from 'react';
import * as THREE from 'three';
import { RoundedBoxGeometry } from 'three/examples/jsm/geometries/RoundedBoxGeometry.js';
import { computeTusDiasCameraFraming } from '@/lib/calc/tus_dias_3d_camera';
import { formatGs } from '@/lib/format';
import { heatLevels } from '@/lib/calc/heat_levels';
import {
  computeTusDiasWindow,
  computeTusDiasStats,
  type DailyDataPoint,
  type DayDataWithFlags,
} from '@/lib/calc/tus_dias_stats';
import { useTheme } from '@/lib/theme';
import { CountUp } from '@/components/CountUp';

export type DayData = DailyDataPoint;

export interface TusDiasProps {
  days: DayData[];
  periodLabel?: string;
  totalAmount?: number;
  referenceDate?: Date;
  today?: Date;
  initialMode?: '2d' | '3d';
  onSelectDay?: (day: DayData) => void;
  className?: string;
}

export const HEAT_PALETTE_DARK = ['#1a1a1d', '#55263A', '#94344D', '#DA534F', '#FF3D7F'];
export const HEAT_PALETTE_LIGHT = ['#E8E8E9', '#FFE0DA', '#FFBDB7', '#F98E8F', '#FF3D7F'];

const MONTH_NAMES = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'setiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

const MONTH_SHORT = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'set',
  'oct',
  'nov',
  'dic',
];

function isWebGLAvailable(): boolean {
  if (typeof window === 'undefined') return false;
  try {
    const canvas = document.createElement('canvas');
    return !!(
      window.WebGLRenderingContext &&
      (canvas.getContext('webgl') || canvas.getContext('experimental-webgl'))
    );
  } catch {
    return false;
  }
}

function createTodayRingGeometry(): THREE.BufferGeometry {
  const shape = new THREE.Shape();
  const w = 0.88;
  const h = 0.88;
  const r = 0.12;
  const x = -w / 2;
  const y = -h / 2;
  shape.moveTo(x + r, y);
  shape.lineTo(x + w - r, y);
  shape.quadraticCurveTo(x + w, y, x + w, y + r);
  shape.lineTo(x + w, y + h - r);
  shape.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
  shape.lineTo(x + r, y + h);
  shape.quadraticCurveTo(x, y + h, x, y + h - r);
  shape.lineTo(x, y + r);
  shape.quadraticCurveTo(x, y, x + r, y);

  const hole = new THREE.Path();
  const hw = 0.74;
  const hh = 0.74;
  const hr = 0.08;
  const hx = -hw / 2;
  const hy = -hh / 2;
  hole.moveTo(hx + hr, hy);
  hole.lineTo(hx + hw - hr, hy);
  hole.quadraticCurveTo(hx + hw, hy, hx + hw, hy + hr);
  hole.lineTo(hx + hw, hy + hh - hr);
  hole.quadraticCurveTo(hx + hw, hy + hh, hx + hw - hr, hy + hh);
  hole.lineTo(hx + hr, hy + hh);
  hole.quadraticCurveTo(hx, hy + hh, hx, hy + hh - hr);
  hole.lineTo(hx, hy + hr);
  hole.quadraticCurveTo(hx, hy, hx + hr, hy);
  shape.holes.push(hole);

  const ringGeo = new THREE.ShapeGeometry(shape);
  ringGeo.rotateX(-Math.PI / 2);
  return ringGeo;
}

function lerp(a: number, b: number, t: number): number {
  return a + (b - a) * t;
}

export function TusDias({
  days,
  periodLabel,
  totalAmount,
  referenceDate,
  today,
  initialMode = '2d',
  onSelectDay,
  className = '',
}: TusDiasProps) {
  const themeContext = useTheme();
  const isLight =
    themeContext?.resolvedTheme === 'light' ||
    (typeof document !== 'undefined' &&
      document.documentElement.classList.contains('light'));
  const resolvedTheme: 'light' | 'dark' = isLight ? 'light' : 'dark';
  const palette = resolvedTheme === 'light' ? HEAT_PALETTE_LIGHT : HEAT_PALETTE_DARK;

  const [mode, setMode] = useState<'2d' | '3d'>(initialMode);
  const [webGLSupported, setWebGLSupported] = useState<boolean>(true);
  const [hoveredDay, setHoveredDay] = useState<{
    day: DayDataWithFlags;
    x: number;
    y: number;
  } | null>(null);
  const [focusedCoord, setFocusedCoord] = useState<{ w: number; d: number } | null>(null);

  const containerRef = useRef<HTMLDivElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const scrollContainerRef = useRef<HTMLDivElement>(null);
  const animationFrameRef = useRef<number | null>(null);
  const maxBadgeRef = useRef<HTMLDivElement>(null);
  const monthRefsMap = useRef<Map<string, HTMLDivElement>>(new Map());

  const realToday = useMemo(() => today ?? referenceDate ?? new Date(), [today, referenceDate]);

  // Compute adaptive window
  const windowData = useMemo(() => {
    return computeTusDiasWindow({
      dataPoints: days,
      referenceDate,
      today: realToday,
    });
  }, [days, referenceDate, realToday]);

  // Compute stats on the window
  const stats = useMemo(() => {
    return computeTusDiasStats({
      days: windowData.days,
      today: realToday,
    });
  }, [windowData.days, realToday]);

  // Compute levels using heatLevels calculation on window days
  const enrichedDays = useMemo<DayDataWithFlags[]>(() => {
    const amounts = windowData.days.map((d) => d.amount);
    const levels = heatLevels(amounts);
    return windowData.days.map((d, i) => ({
      ...d,
      level: levels.get(i) ?? 0,
    }));
  }, [windowData.days]);

  const computedTotal = useMemo(() => {
    if (typeof totalAmount === 'number') return totalAmount;
    return stats.totalSpent;
  }, [stats.totalSpent, totalAmount]);

  // Title: "Gastado desde el <fecha>"
  const dynamicTitle = useMemo(() => {
    if (periodLabel && !periodLabel.includes('últimos 6 meses') && !periodLabel.includes('en 6 meses')) {
      return periodLabel;
    }
    const d = stats.startDate;
    const monthStr = MONTH_NAMES[d.getMonth()] || '';
    return `Gastado desde el ${d.getDate()} de ${monthStr}`;
  }, [periodLabel, stats.startDate]);

  // Weeks breakdown (7 days each)
  const weeks = useMemo<DayDataWithFlags[][]>(() => {
    const result: DayDataWithFlags[][] = [];
    for (let i = 0; i < enrichedDays.length; i += 7) {
      result.push(enrichedDays.slice(i, i + 7));
    }
    return result;
  }, [enrichedDays]);

  // First week of each month to display month labels
  const monthLabelsByWeek = useMemo(() => {
    const labels: (string | null)[] = [];
    let lastMonth = -1;

    for (let w = 0; w < weeks.length; w++) {
      const week = weeks[w];
      if (!week || week.length === 0) {
        labels.push(null);
        continue;
      }
      // Check the month of the first day or middle day of the week
      const currentMonth = week[0].date.getMonth();
      if (w === 0) {
        labels.push(MONTH_SHORT[currentMonth]);
        lastMonth = currentMonth;
      } else {
        // Did a month transition happen in this week?
        const transitionDay = week.find((d) => d.date.getMonth() !== lastMonth);
        if (transitionDay) {
          const newMonth = transitionDay.date.getMonth();
          labels.push(MONTH_SHORT[newMonth]);
          lastMonth = newMonth;
        } else {
          labels.push(null);
        }
      }
    }
    return labels;
  }, [weeks]);

  const monthOverlayData = useMemo(() => {
    const items: { key: string; w: number; label: string }[] = [];
    monthLabelsByWeek.forEach((lbl, w) => {
      if (lbl) {
        items.push({ key: `month-${w}-${lbl}`, w, label: lbl });
      }
    });
    return items;
  }, [monthLabelsByWeek]);

  useEffect(() => {
    setWebGLSupported(isWebGLAvailable());
  }, []);

  // WebGL 3D Scene setup and lifecycle
  useEffect(() => {
    if (mode !== '3d' || !webGLSupported || !canvasRef.current) {
      if (animationFrameRef.current) {
        cancelAnimationFrame(animationFrameRef.current);
        animationFrameRef.current = null;
      }
      return;
    }

    const canvas = canvasRef.current;
    let renderer: THREE.WebGLRenderer;
    try {
      renderer = new THREE.WebGLRenderer({
        canvas,
        antialias: true,
        alpha: true,
      });
      renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
      const initialW = canvas.clientWidth || 800;
      const initialH =
        canvas.clientHeight ||
        (typeof window !== 'undefined' && window.innerWidth < 640 ? 280 : 340);
      renderer.setSize(initialW, initialH, false);
    } catch {
      setWebGLSupported(false);
      setMode('2d');
      return;
    }

    const scene = new THREE.Scene();
    const cam = new THREE.OrthographicCamera(-1, 1, 1, -1, 0.1, 200);

    // Hemisphere light + directional light (soft, balanced, true colors)
    const hemiLight = new THREE.HemisphereLight(
      0xffffff,
      resolvedTheme === 'light' ? 0xd0d0d8 : 0x22222a,
      0.85
    );
    scene.add(hemiLight);

    const dl = new THREE.DirectionalLight(0xffffff, 1.15);
    dl.position.set(12, 28, 16);
    scene.add(dl);

    const totalDays = enrichedDays.length;
    const W = weeks.length;
    const D = 7;

    // RoundedBoxGeometry: width=0.85, height=1.0, depth=0.85, segments=3, radius=0.10
    const geo = new RoundedBoxGeometry(0.85, 1.0, 0.85, 3, 0.10);
    geo.translate(0, 0.5, 0); // Put base at Y=0 so scaling in Y grows upwards
    const mat = new THREE.MeshStandardMaterial({ roughness: 0.35, metalness: 0.04 });
    const mesh = new THREE.InstancedMesh(geo, mat, totalDays);
    scene.add(mesh);

    const threePalette = palette.map((c) => new THREE.Color(c));
    const emptyColor = new THREE.Color(palette[0]);
    const futureColor = new THREE.Color(resolvedTheme === 'light' ? 0xe2e2e5 : 0x18181b);

    for (let i = 0; i < totalDays; i++) {
      const d = enrichedDays[i];
      if (d?.isFuture) {
        mesh.setColorAt(i, futureColor);
      } else if (d?.amount <= 0) {
        mesh.setColorAt(i, emptyColor);
      } else {
        const lvl = d?.level ?? 0;
        mesh.setColorAt(i, threePalette[lvl]);
      }
    }
    if (mesh.instanceColor) mesh.instanceColor.needsUpdate = true;

    // Today indicator: orange rounded ring on today's tile
    const todayIdx = enrichedDays.findIndex((d) => d.isToday);
    const todayRingGeo = createTodayRingGeometry();
    const todayMat = new THREE.MeshBasicMaterial({ color: 0xff8a3d, side: THREE.DoubleSide });
    const todayMesh = new THREE.Mesh(todayRingGeo, todayMat);
    todayMesh.visible = todayIdx >= 0;
    scene.add(todayMesh);

    // Tallest building index
    let maxIdx = -1;
    let maxAmt = 0;
    for (let i = 0; i < totalDays; i++) {
      if (!enrichedDays[i].isFuture && enrichedDays[i].amount > maxAmt) {
        maxAmt = enrichedDays[i].amount;
        maxIdx = i;
      }
    }

    const m = new THREE.Matrix4();
    const q = new THREE.Quaternion();
    const s = new THREE.Vector3();
    const p = new THREE.Vector3();
    const projVector = new THREE.Vector3();

    let k = mode === '3d' ? 1 : 0;
    let v = 0;
    const target = 1;
    let yaw = 0;
    let yawT = 0;
    let hoverIndex = -1;

    const reduceMotion =
      typeof window !== 'undefined' &&
      window.matchMedia('(prefers-reduced-motion: reduce)').matches;

    const maxAmtRef = Math.max(...enrichedDays.map((d) => d.amount), 1);

    function updateLayout() {
      for (let i = 0; i < totalDays; i++) {
        const e = enrichedDays[i];
        const w = Math.floor(i / 7);
        const d = i % 7;
        const isHovered = i === hoverIndex;

        let targetHt: number;
        if (e.isFuture) {
          targetHt = 0.06;
        } else if (e.amount <= 0) {
          targetHt = 0.12;
        } else {
          targetHt = 0.35 + Math.sqrt(e.amount / maxAmtRef) * 3.2;
        }

        const ht = lerp(0.12, targetHt, k) + (isHovered ? 0.15 * k : 0);
        const scaleXZ = isHovered ? 1.06 : 1.0;

        p.set(w - (W - 1) / 2, 0, d - (D - 1) / 2);
        s.set(scaleXZ, ht, scaleXZ);
        m.compose(p, q, s);
        mesh.setMatrixAt(i, m);

        if (i === todayIdx) {
          todayMesh.position.set(p.x, ht + 0.005, p.z);
        }
      }
      mesh.instanceMatrix.needsUpdate = true;
    }

    function updateCamera() {
      const canvasW = canvas.clientWidth || 800;
      const canvasH =
        canvas.clientHeight ||
        (typeof window !== 'undefined' && window.innerWidth < 640 ? 280 : 340);
      const maxHeight = 0.35 + 3.2;
      const currentMax = lerp(0.12, maxHeight, k);

      const framing = computeTusDiasCameraFraming({
        weeks: W,
        days: D,
        maxHeight: currentMax,
        canvasWidth: canvasW,
        canvasHeight: canvasH,
        k,
        yaw,
      });

      cam.left = framing.left;
      cam.right = framing.right;
      cam.top = framing.top;
      cam.bottom = framing.bottom;
      cam.position.set(framing.camPosition.x, framing.camPosition.y, framing.camPosition.z);
      cam.lookAt(framing.camTarget.x, framing.camTarget.y, framing.camTarget.z);
      cam.updateProjectionMatrix();
    }

    let lastTime = performance.now();
    function tick(now: number) {
      const dt = Math.min(0.033, (now - lastTime) / 1000);
      lastTime = now;

      if (reduceMotion) {
        k = target;
      } else {
        const stiff = 120;
        const damp = 2 * Math.sqrt(stiff) * 0.82;
        const a = stiff * (target - k) - damp * v;
        v += a * dt;
        k += v * dt;
      }

      yaw += (yawT - yaw) * Math.min(1, dt * 8);
      updateLayout();
      updateCamera();
      renderer.render(scene, cam);

      // Project HTML overlay positions
      const cWidth = canvas.clientWidth || 800;
      const cHeight =
        canvas.clientHeight ||
        (typeof window !== 'undefined' && window.innerWidth < 640 ? 280 : 340);

      for (const item of monthOverlayData) {
        const el = monthRefsMap.current.get(item.key);
        if (el) {
          projVector.set(item.w - (W - 1) / 2, 0, (D - 1) / 2 + 0.65);
          projVector.project(cam);
          const screenX = ((projVector.x + 1) / 2) * cWidth;
          const screenY = ((-projVector.y + 1) / 2) * cHeight;
          el.style.transform = `translate3d(${screenX}px, ${screenY}px, 0) translate(-50%, 0)`;
        }
      }

      if (maxBadgeRef.current && maxIdx >= 0) {
        const maxW = Math.floor(maxIdx / 7);
        const maxD = maxIdx % 7;
        const maxX = maxW - (W - 1) / 2;
        const maxZ = maxD - (D - 1) / 2;
        const maxHt = lerp(0.12, 0.35 + 3.2, k);
        projVector.set(maxX, maxHt + 0.15, maxZ);
        projVector.project(cam);
        const screenX = ((projVector.x + 1) / 2) * cWidth;
        const screenY = ((-projVector.y + 1) / 2) * cHeight;
        maxBadgeRef.current.style.transform = `translate3d(${screenX}px, ${screenY - 10}px, 0) translate(-50%, -100%)`;
        maxBadgeRef.current.style.opacity = k > 0.15 ? '1' : '0';
      }

      animationFrameRef.current = requestAnimationFrame(tick);
    }

    animationFrameRef.current = requestAnimationFrame(tick);

    const resizeObserver = new ResizeObserver(() => {
      if (!canvas || !renderer) return;
      const w = canvas.clientWidth || 800;
      const h =
        canvas.clientHeight ||
        (typeof window !== 'undefined' && window.innerWidth < 640 ? 280 : 340);
      renderer.setSize(w, h, false);
      renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
      updateCamera();
    });
    resizeObserver.observe(canvas);

    const ray = new THREE.Raycaster();
    const mv = new THREE.Vector2();
    let drag: { x: number; y0: number } | null = null;

    const onPointerDown = (e: PointerEvent) => {
      drag = { x: e.clientX, y0: yawT };
    };

    const onPointerUp = () => {
      drag = null;
    };

    const onPointerMove = (e: PointerEvent) => {
      const rect = canvas.getBoundingClientRect();
      if (drag && target === 1) {
        yawT = Math.max(-0.6, Math.min(0.6, drag.y0 + (e.clientX - drag.x) / 300));
      }
      mv.set(
        ((e.clientX - rect.left) / rect.width) * 2 - 1,
        -((e.clientY - rect.top) / rect.height) * 2 + 1
      );
      ray.setFromCamera(mv, cam);
      const hits = ray.intersectObject(mesh);
      const hit = hits[0];
      hoverIndex = hit && hit.instanceId !== undefined ? hit.instanceId : -1;

      if (hoverIndex >= 0 && enrichedDays[hoverIndex] && !enrichedDays[hoverIndex].isFuture) {
        const containerRect = containerRef.current?.getBoundingClientRect();
        setHoveredDay({
          day: enrichedDays[hoverIndex],
          x: e.clientX - (containerRect?.left || 0) + 14,
          y: e.clientY - (containerRect?.top || 0) + 14,
        });
      } else {
        setHoveredDay(null);
      }
    };

    const onPointerLeave = () => {
      hoverIndex = -1;
      setHoveredDay(null);
    };

    const onClick = () => {
      if (
        hoverIndex >= 0 &&
        enrichedDays[hoverIndex] &&
        !enrichedDays[hoverIndex].isFuture &&
        onSelectDay
      ) {
        onSelectDay(enrichedDays[hoverIndex]);
      }
    };

    canvas.addEventListener('pointerdown', onPointerDown);
    window.addEventListener('pointerup', onPointerUp);
    canvas.addEventListener('pointermove', onPointerMove);
    canvas.addEventListener('pointerleave', onPointerLeave);
    canvas.addEventListener('click', onClick);

    return () => {
      if (animationFrameRef.current) cancelAnimationFrame(animationFrameRef.current);
      resizeObserver.disconnect();
      canvas.removeEventListener('pointerdown', onPointerDown);
      window.removeEventListener('pointerup', onPointerUp);
      canvas.removeEventListener('pointermove', onPointerMove);
      canvas.removeEventListener('pointerleave', onPointerLeave);
      canvas.removeEventListener('click', onClick);

      geo.dispose();
      mat.dispose();
      todayRingGeo.dispose();
      todayMat.dispose();
      renderer.dispose();
      scene.clear();
    };
  }, [
    mode,
    webGLSupported,
    enrichedDays,
    weeks.length,
    monthOverlayData,
    onSelectDay,
    palette,
    resolvedTheme,
  ]);

  const handleCellClick = (day: DayDataWithFlags) => {
    if (day.isFuture) return;
    if (onSelectDay) onSelectDay(day);
  };

  const handleKeyDown = (
    e: React.KeyboardEvent<HTMLElement>,
    w: number,
    d: number,
    day: DayDataWithFlags
  ) => {
    let nextW = w;
    let nextD = d;

    if (e.key === 'ArrowLeft') {
      nextW = Math.max(0, w - 1);
    } else if (e.key === 'ArrowRight') {
      nextW = Math.min(weeks.length - 1, w + 1);
    } else if (e.key === 'ArrowUp') {
      nextD = Math.max(0, d - 1);
    } else if (e.key === 'ArrowDown') {
      nextD = Math.min((weeks[w]?.length || 7) - 1, d + 1);
    } else if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault();
      handleCellClick(day);
      return;
    } else {
      return;
    }

    e.preventDefault();
    const colLength = weeks[nextW]?.length || 0;
    if (nextD >= colLength) {
      nextD = colLength - 1;
    }

    setFocusedCoord({ w: nextW, d: nextD });

    const targetId = `tus-dias-cell-${nextW}-${nextD}`;
    const el = document.getElementById(targetId);
    if (el) {
      el.focus();
    }
  };

  const handleCellMouseEnter = (
    day: DayDataWithFlags,
    e: React.MouseEvent<HTMLElement>
  ) => {
    if (day.isFuture) {
      setHoveredDay(null);
      return;
    }
    const containerRect = containerRef.current?.getBoundingClientRect();
    setHoveredDay({
      day,
      x: e.clientX - (containerRect?.left || 0) + 14,
      y: e.clientY - (containerRect?.top || 0) + 14,
    });
  };

  const handleCellMouseLeave = () => {
    setHoveredDay(null);
  };

  const show3D = mode === '3d' && webGLSupported;

  // Auto-scroll 2D grid to the right on mount so recent days are immediately visible
  useEffect(() => {
    if (!show3D && scrollContainerRef.current) {
      const el = scrollContainerRef.current;
      el.scrollLeft = el.scrollWidth;
      const rId = requestAnimationFrame(() => {
        if (el) el.scrollLeft = el.scrollWidth;
      });
      return () => cancelAnimationFrame(rId);
    }
  }, [show3D, weeks]);

  return (
    <div
      ref={containerRef}
      className={`relative overflow-hidden bg-glass-fill border border-glass-border rounded-2xl p-5 select-none shadow-sm ${className}`}
      data-testid="tus-dias-container"
    >
      {/* Header */}
      <div className="flex justify-between items-start relative z-10 mb-1">
        <div>
          <div className="text-[13px] text-text-tertiary">{dynamicTitle}</div>
          <div className="text-[28px] font-extrabold text-text-primary tracking-tight mt-0.5 tabular-nums">
            <CountUp value={computedTotal} />
          </div>
        </div>

        {/* 2D / 3D Segmented Control */}
        <div className="inline-flex p-1 rounded-xl bg-white/5 border border-glass-border">
          <button
            type="button"
            className={`px-3.5 min-h-[40px] py-2 rounded-lg text-xs font-semibold transition-all cursor-pointer outline-none focus-visible:ring-2 focus-visible:ring-brand-start flex items-center justify-center ${
              mode === '2d'
                ? 'bg-white/10 text-text-primary shadow-sm on'
                : 'text-text-tertiary hover:text-text-primary hover:bg-white/5'
            }`}
            onClick={() => setMode('2d')}
          >
            2D
          </button>
          <button
            type="button"
            className={`px-3.5 min-h-[40px] py-2 rounded-lg text-xs font-semibold transition-all cursor-pointer outline-none focus-visible:ring-2 focus-visible:ring-brand-start flex items-center justify-center ${
              mode === '3d'
                ? 'bg-white/10 text-text-primary shadow-sm on'
                : 'text-text-tertiary hover:text-text-primary hover:bg-white/5'
            }`}
            onClick={() => setMode('3d')}
            title={!webGLSupported ? 'Sin aceleración WebGL en este dispositivo' : undefined}
          >
            3D
          </button>
        </div>
      </div>

      {/* 4 Stats Cards */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-2.5 my-4">
        <div className="p-2.5 sm:p-3 rounded-xl bg-white/[0.04] border border-glass-border">
          <small className="text-[11px] text-text-tertiary block">Día más caro</small>
          <b
            data-testid="stat-dia-mas-caro"
            className="block text-[15px] font-bold text-text-primary mt-0.5 tabular-nums"
          >
            {stats.maxExpenseDay.amount > 0 ? (
              <CountUp value={stats.maxExpenseDay.amount} />
            ) : (
              '-'
            )}
          </b>
          <small className="text-[11px] text-text-tertiary capitalize block truncate">
            {stats.maxExpenseDay.shortDate}
          </small>
        </div>

        <div className="p-2.5 sm:p-3 rounded-xl bg-white/[0.04] border border-glass-border">
          <small className="text-[11px] text-text-tertiary block">Promedio por día</small>
          <b
            data-testid="stat-promedio"
            className="block text-[15px] font-bold text-text-primary mt-0.5 tabular-nums"
          >
            <CountUp value={stats.dailyAverage.amount} />
          </b>
          <small className="text-[11px] text-text-tertiary block">
            en {stats.dailyAverage.daysCount} {stats.dailyAverage.daysCount === 1 ? 'día' : 'días'}
          </small>
        </div>

        <div className="p-2.5 sm:p-3 rounded-xl bg-white/[0.04] border border-glass-border">
          <small className="text-[11px] text-text-tertiary block">Días sin gastos</small>
          <b className="block text-[15px] font-bold text-text-primary mt-0.5 tabular-nums">
            {stats.noExpenseDays.count} de {stats.noExpenseDays.totalDays}
          </b>
          <small data-testid="stat-dias-sin-gastos" className="text-[11px] text-text-tertiary block">
            {stats.noExpenseDays.percentage} %
          </small>
        </div>

        <div className="p-2.5 sm:p-3 rounded-xl bg-white/[0.04] border border-glass-border">
          <small className="text-[11px] text-text-tertiary block">Racha actual</small>
          <b
            data-testid="stat-racha-actual"
            className="block text-[15px] font-bold text-text-primary mt-0.5 tabular-nums"
          >
            {stats.currentStreak.days} {stats.currentStreak.days === 1 ? 'día' : 'días'}
          </b>
          <small className="text-[11px] text-text-tertiary block">sin gastos</small>
        </div>
      </div>

      {/* 3D WebGL Canvas */}
      {show3D && (
        <div
          className="relative w-full h-[280px] sm:h-[340px] overflow-hidden select-none"
          data-testid="tus-dias-3d-wrapper"
        >
          <canvas
            ref={canvasRef}
            className="w-full h-full cursor-crosshair block"
            data-testid="tus-dias-3d-canvas"
          />

          {/* Month Labels HTML Overlay */}
          <div className="absolute inset-0 pointer-events-none overflow-hidden">
            {monthOverlayData.map((item) => (
              <div
                key={item.key}
                ref={(el) => {
                  if (el) monthRefsMap.current.set(item.key, el);
                  else monthRefsMap.current.delete(item.key);
                }}
                className="absolute top-0 left-0 text-[12px] font-medium text-text-secondary select-none pointer-events-none will-change-transform"
                style={{
                  transform: 'translate3d(-9999px, -9999px, 0)',
                }}
              >
                {item.label}
              </div>
            ))}

            {/* Max Expense Day Amount Badge */}
            {stats.maxExpenseDay.amount > 0 && (
              <div
                ref={maxBadgeRef}
                className="absolute top-0 left-0 px-2 py-0.5 rounded-lg bg-sheet-surface/90 dark:bg-zinc-900/90 backdrop-blur-md border border-glass-border shadow-md text-[12px] font-bold text-text-primary tabular-nums pointer-events-none will-change-transform transition-opacity duration-200"
                style={{
                  transform: 'translate3d(-9999px, -9999px, 0)',
                  opacity: 0,
                }}
              >
                {formatGs(stats.maxExpenseDay.amount)}
              </div>
            )}
          </div>
        </div>
      )}

      {/* 2D Heatmap Grid */}
      {!show3D && (
        <div className="w-full overflow-hidden">
          <div className="flex gap-2 justify-center">
            {/* Weekday labels: L, M, V, D in alternating rows */}
            <div
              className="grid grid-rows-7 text-[10px] text-text-tertiary font-semibold select-none shrink-0 pt-6"
              style={{
                rowGap: 'clamp(4px, 0.8vw, 8px)',
                gridTemplateRows: 'repeat(7, clamp(22px, 4.5vw, 48px))',
              }}
            >
              <span className="flex items-center justify-center">L</span>
              <span />
              <span className="flex items-center justify-center">M</span>
              <span />
              <span className="flex items-center justify-center">V</span>
              <span />
              <span className="flex items-center justify-center">D</span>
            </div>

            {/* Scrollable Columns Container */}
            <div
              ref={scrollContainerRef}
              data-testid="tus-dias-scroll-container"
              className="min-w-0 overflow-x-auto p-1.5"
            >
              <div
                className="flex min-w-max mx-auto justify-center"
                style={{ gap: 'clamp(4px, 0.8vw, 8px)' }}
              >
                {weeks.map((week, wIdx) => {
                  const monthLabel = monthLabelsByWeek[wIdx];
                  return (
                    <div
                      key={wIdx}
                      className="flex flex-col items-center"
                      style={{
                        width: 'clamp(22px, 4.5vw, 48px)',
                        gap: 'clamp(4px, 0.8vw, 8px)',
                      }}
                    >
                      {/* Month label header - no truncation, allows overflow */}
                      <div className="h-5 text-[11px] text-text-tertiary font-semibold text-left pl-0.5 select-none whitespace-nowrap overflow-visible">
                        {monthLabel || ''}
                      </div>

                      {/* 7 Days of the week */}
                      {week.map((day, dIdx) => {
                        const isFocused =
                          focusedCoord?.w === wIdx && focusedCoord?.d === dIdx;
                        const tabIndex =
                          day.isFuture
                            ? -1
                            : isFocused || (!focusedCoord && wIdx === 0 && dIdx === 0)
                            ? 0
                            : -1;

                        const dateKey = `${day.date.getFullYear()}-${String(
                          day.date.getMonth() + 1
                        ).padStart(2, '0')}-${String(day.date.getDate()).padStart(2, '0')}`;

                        const dateLabel = day.date.toLocaleDateString('es-PY', {
                          day: 'numeric',
                          month: 'long',
                        });
                        const amountLabel =
                          day.amount > 0 ? formatGs(day.amount) : 'Sin gastos';

                        let cellClass =
                          'rounded-[7px] transition-all relative outline-none select-none ';

                        if (day.isFuture) {
                          cellClass +=
                            'bg-transparent border border-dashed border-white/15 dark:border-white/15 border-black/20 cursor-default';
                        } else {
                          cellClass += 'cursor-pointer hover:scale-110 active:scale-95';
                        }

                        if (day.isToday) {
                          cellClass += ' ring-2 ring-[#FF8A3D] ring-offset-1 ring-offset-transparent z-10';
                        }

                        const cellColor = day.isFuture
                          ? 'transparent'
                          : palette[day.level ?? 0];

                        return (
                          <div
                            id={`tus-dias-cell-${wIdx}-${dIdx}`}
                            key={`${wIdx}-${dIdx}`}
                            role={day.isFuture ? 'presentation' : 'button'}
                            tabIndex={tabIndex}
                            aria-label={
                              day.isFuture
                                ? `${dateLabel}: futuro`
                                : `${dateLabel}: ${amountLabel}`
                            }
                            aria-disabled={day.isFuture ? true : undefined}
                            data-testid="tus-dias-cell"
                            data-date={dateKey}
                            data-today={day.isToday ? 'true' : 'false'}
                            data-future={day.isFuture ? 'true' : 'false'}
                            className={cellClass}
                            style={{
                              width: 'clamp(22px, 4.5vw, 48px)',
                              height: 'clamp(22px, 4.5vw, 48px)',
                              backgroundColor: cellColor,
                            }}
                            onClick={() => handleCellClick(day)}
                            onKeyDown={(e) => handleKeyDown(e, wIdx, dIdx, day)}
                            onFocus={() => {
                              if (!day.isFuture) setFocusedCoord({ w: wIdx, d: dIdx });
                            }}
                            onMouseEnter={(e) => handleCellMouseEnter(day, e)}
                            onMouseLeave={handleCellMouseLeave}
                          />
                        );
                      })}
                    </div>
                  );
                })}
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Legend */}
      <div className="flex flex-wrap items-center justify-between gap-2 text-[11px] text-text-tertiary mt-3 pt-2 border-t border-glass-border/40">
        <span className="text-[11px] text-text-tertiary">
          Hoy tiene borde naranja. Los días futuros sin pintar.
        </span>
        <div className="flex items-center gap-1.5 text-[11px]">
          <span>menos</span>
          {palette.map((color, i) => (
            <i
              key={i}
              className="w-2.5 h-2.5 rounded-[3px] inline-block"
              style={{ backgroundColor: color }}
            />
          ))}
          <span>más</span>
        </div>
      </div>

      {/* Tooltip */}
      {hoveredDay && !hoveredDay.day.isFuture && (
        <div
          data-testid="tus-dias-tooltip"
          className="pointer-events-none absolute z-20 bg-sheet-surface border border-glass-border rounded-xl p-3 text-xs shadow-2xl transition-opacity duration-100"
          style={{
            left: `${hoveredDay.x}px`,
            top: `${hoveredDay.y}px`,
          }}
        >
          <div className="text-text-tertiary capitalize">
            {hoveredDay.day.date.toLocaleDateString('es-PY', {
              weekday: 'short',
              day: 'numeric',
              month: 'short',
            })}
          </div>
          <div className="text-base font-bold text-text-primary my-0.5">
            {hoveredDay.day.amount > 0 ? formatGs(hoveredDay.day.amount) : 'Sin gastos'}
          </div>
          {hoveredDay.day.amount > 0 && (
            <div className="text-text-secondary text-[11px]">
              {hoveredDay.day.txCount}{' '}
              {hoveredDay.day.txCount === 1 ? 'movimiento' : 'movimientos'}
              {hoveredDay.day.topMerchant ? ` · más alto: ${hoveredDay.day.topMerchant}` : ''}
            </div>
          )}
        </div>
      )}
    </div>
  );
}
