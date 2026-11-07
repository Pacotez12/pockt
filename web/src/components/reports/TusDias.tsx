import React, { useEffect, useRef, useState, useMemo } from 'react';
import * as THREE from 'three';
import { formatGs } from '@/lib/format';
import { heatLevels } from '@/lib/calc/heat_levels';

export interface DayData {
  date: Date;
  amount: number;
  txCount: number;
  topMerchant?: string;
  level?: number;
}

export interface TusDiasProps {
  days: DayData[];
  periodLabel?: string;
  totalAmount?: number;
  onSelectDay?: (day: DayData) => void;
  className?: string;
}

const HEAT_PALETTE = ['#1a1a1d', '#55263A', '#94344D', '#DA534F', '#FF3D7F'];

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

export function TusDias({
  days,
  periodLabel = 'Gastado en 6 meses',
  totalAmount,
  onSelectDay,
  className = '',
}: TusDiasProps) {
  const [mode, setMode] = useState<'2d' | '3d'>('2d');
  const [webGLSupported, setWebGLSupported] = useState<boolean>(true);
  const [hoveredDay, setHoveredDay] = useState<{
    day: DayData;
    x: number;
    y: number;
  } | null>(null);

  const containerRef = useRef<HTMLDivElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const animationFrameRef = useRef<number | null>(null);

  // Compute levels using heatLevels calculation
  const enrichedDays = useMemo(() => {
    const amounts = days.map((d) => d.amount);
    const levels = heatLevels(amounts);
    return days.map((d, i) => ({
      ...d,
      level: levels.get(i) ?? 0,
    }));
  }, [days]);

  const computedTotal = useMemo(() => {
    if (typeof totalAmount === 'number') return totalAmount;
    return days.reduce((sum, d) => sum + d.amount, 0);
  }, [days, totalAmount]);

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
      renderer.setSize(canvas.clientWidth || 856, canvas.clientHeight || 360, false);
    } catch {
      setWebGLSupported(false);
      setMode('2d');
      return;
    }

    const scene = new THREE.Scene();
    const cam = new THREE.OrthographicCamera(-1, 1, 1, -1, 0.1, 200);
    scene.add(new THREE.AmbientLight(0xffffff, 0.55));
    const dl = new THREE.DirectionalLight(0xffffff, 1.6);
    dl.position.set(-12, 30, 18);
    scene.add(dl);

    const totalDays = enrichedDays.length;
    const W = Math.ceil(totalDays / 7);
    const D = 7;

    const geo = new THREE.CylinderGeometry(0.4, 0.4, 1, 24);
    geo.translate(0, 0.5, 0);
    const mat = new THREE.MeshStandardMaterial({ roughness: 0.45, metalness: 0.05 });
    const mesh = new THREE.InstancedMesh(geo, mat, totalDays);
    scene.add(mesh);

    const threePalette = HEAT_PALETTE.map((c) => new THREE.Color(c));
    for (let i = 0; i < totalDays; i++) {
      const lvl = enrichedDays[i]?.level ?? 0;
      mesh.setColorAt(i, threePalette[lvl]);
    }
    if (mesh.instanceColor) mesh.instanceColor.needsUpdate = true;

    const m = new THREE.Matrix4();
    const q = new THREE.Quaternion();
    const s = new THREE.Vector3();
    const p = new THREE.Vector3();

    let k = mode === '3d' ? 1 : 0;
    let v = 0;
    const target = 1;
    let yaw = 0;
    let yawT = 0;
    let hoverIndex = -1;

    const reduceMotion =
      typeof window !== 'undefined' &&
      window.matchMedia('(prefers-reduced-motion: reduce)').matches;

    const maxAmt = Math.max(...enrichedDays.map((d) => d.amount), 1);

    function updateLayout() {
      const h = k;
      for (let i = 0; i < totalDays; i++) {
        const e = enrichedDays[i];
        const w = Math.floor(i / 7);
        const d = i % 7;
        const ht = 0.06 + h * ((e.amount / maxAmt) * 7 + 0.05) + (i === hoverIndex ? 0.25 * h : 0);
        p.set(w - (W - 1) / 2, 0, d - (D - 1) / 2);
        s.set(i === hoverIndex ? 1.12 : 1, ht, i === hoverIndex ? 1.12 : 1);
        m.compose(p, q, s);
        mesh.setMatrixAt(i, m);
      }
      mesh.instanceMatrix.needsUpdate = true;
    }

    function lerp(a: number, b: number, t: number) {
      return a + (b - a) * t;
    }

    function updateCamera() {
      const asp = (canvas.clientWidth || 856) / (canvas.clientHeight || 360);
      const z = lerp(6.6, 10.5, k);
      cam.left = -z * asp;
      cam.right = z * asp;
      cam.top = z;
      cam.bottom = -z;
      cam.updateProjectionMatrix();

      const tilt = lerp(0.001, 0.95, k);
      const az = lerp(0, -0.72, k) + yaw * k;
      const r = 60;
      cam.position.set(
        Math.sin(az) * Math.cos(Math.PI / 2 - tilt) * r,
        Math.sin(Math.PI / 2 - tilt) * r * 1.0,
        Math.cos(az) * Math.cos(Math.PI / 2 - tilt) * r
      );
      if (k < 0.002) cam.position.set(0, 60, 0.001);
      cam.lookAt(0, lerp(0, 1.2, k), 0);
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

      animationFrameRef.current = requestAnimationFrame(tick);
    }

    animationFrameRef.current = requestAnimationFrame(tick);

    // Pointer events on canvas
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

      if (hoverIndex >= 0 && enrichedDays[hoverIndex]) {
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
      if (hoverIndex >= 0 && enrichedDays[hoverIndex] && onSelectDay) {
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
      canvas.removeEventListener('pointerdown', onPointerDown);
      window.removeEventListener('pointerup', onPointerUp);
      canvas.removeEventListener('pointermove', onPointerMove);
      canvas.removeEventListener('pointerleave', onPointerLeave);
      canvas.removeEventListener('click', onClick);
      renderer.dispose();
      geo.dispose();
      mat.dispose();
    };
  }, [mode, webGLSupported, enrichedDays, onSelectDay]);

  // Weeks for 2D grid
  const weeks = useMemo(() => {
    const result: DayData[][] = [];
    for (let i = 0; i < enrichedDays.length; i += 7) {
      result.push(enrichedDays.slice(i, i + 7));
    }
    return result;
  }, [enrichedDays]);

  const handleCellClick = (day: DayData) => {
    if (onSelectDay) onSelectDay(day);
  };

  const handleCellMouseEnter = (
    day: DayData,
    e: React.MouseEvent<SVGRectElement | HTMLElement>
  ) => {
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

  return (
    <div
      ref={containerRef}
      className={`card relative overflow-hidden bg-black border border-white/10 rounded-[22px] p-5.5 select-none ${className}`}
      data-testid="tus-dias-container"
    >
      {/* Header */}
      <div className="flex justify-between items-start relative z-10 mb-2">
        <div>
          <div className="text-[13px] text-white/60">{periodLabel}</div>
          <div className="text-[28px] font-extrabold text-white tracking-tight mt-0.5">
            {formatGs(computedTotal)}
          </div>
        </div>

        {/* 2D / 3D Segmented Control */}
        <div className="seg">
          <button
            type="button"
            className={mode === '2d' ? 'on' : ''}
            onClick={() => setMode('2d')}
          >
            2D
          </button>
          <button
            type="button"
            className={mode === '3d' ? 'on' : ''}
            onClick={() => setMode('3d')}
            title={!webGLSupported ? 'Sin aceleración WebGL en este dispositivo' : undefined}
          >
            3D
          </button>
        </div>
      </div>

      {/* 3D WebGL Canvas */}
      {show3D && (
        <canvas
          ref={canvasRef}
          className="w-full h-[360px] cursor-crosshair block"
          data-testid="tus-dias-3d-canvas"
        />
      )}

      {/* 2D SVG Grid Fallback / Default */}
      {!show3D && (
        <div className="w-full overflow-x-auto py-4">
          <svg
            data-testid="tus-dias-2d-svg"
            viewBox={`0 0 ${weeks.length * 28 + 20} 220`}
            className="w-full min-w-[700px] h-[220px]"
          >
            {weeks.map((week, wIdx) =>
              week.map((day, dIdx) => {
                const x = 10 + wIdx * 28;
                const y = 10 + dIdx * 28;
                const color = HEAT_PALETTE[day.level ?? 0];
                return (
                  <rect
                    key={`${wIdx}-${dIdx}`}
                    x={x}
                    y={y}
                    width={22}
                    height={22}
                    rx={6}
                    fill={color}
                    data-testid="tus-dias-cell"
                    className="cursor-pointer transition-transform hover:scale-110 origin-center"
                    onClick={() => handleCellClick(day)}
                    onMouseEnter={(e) => handleCellMouseEnter(day, e)}
                    onMouseLeave={handleCellMouseLeave}
                  />
                );
              })
            )}
          </svg>
        </div>
      )}

      {/* Legend */}
      <div className="flex items-center justify-end gap-1.5 text-[11.5px] text-white/40 mt-3">
        <span>menos</span>
        {HEAT_PALETTE.map((color, i) => (
          <i
            key={i}
            className="w-2.5 h-2.5 rounded-[3px] inline-block"
            style={{ backgroundColor: color }}
          />
        ))}
        <span>más</span>
      </div>

      {/* Tooltip */}
      {hoveredDay && (
        <div
          data-testid="tus-dias-tooltip"
          className="pointer-events-none absolute z-20 bg-[#17171a] border border-white/15 rounded-xl p-3 text-xs shadow-2xl transition-opacity duration-100"
          style={{
            left: `${hoveredDay.x}px`,
            top: `${hoveredDay.y}px`,
          }}
        >
          <div className="text-white/40 capitalize">
            {hoveredDay.day.date.toLocaleDateString('es-PY', {
              weekday: 'short',
              day: 'numeric',
              month: 'short',
            })}
          </div>
          <div className="text-base font-bold text-white my-0.5">
            {hoveredDay.day.amount > 0 ? formatGs(hoveredDay.day.amount) : 'Sin gastos'}
          </div>
          {hoveredDay.day.amount > 0 && (
            <div className="text-white/50 text-[11px]">
              {hoveredDay.day.txCount} {hoveredDay.day.txCount === 1 ? 'movimiento' : 'movimientos'}
              {hoveredDay.day.topMerchant ? ` · más alto: ${hoveredDay.day.topMerchant}` : ''}
            </div>
          )}
        </div>
      )}
    </div>
  );
}
