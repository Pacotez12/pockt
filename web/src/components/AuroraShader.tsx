import React, { useEffect, useRef } from 'react';
import { useTheme } from '@/lib/theme';
import { cn } from '@/lib/utils';

export interface AuroraShaderProps {
  opacity?: number;
  interactive?: boolean;
  className?: string;
  /** El login es siempre oscuro (boceto aprobado), sin importar el tema. */
  forceDark?: boolean;
}

const VERTEX_SHADER_SRC = `
attribute vec2 p;
void main() {
  gl_Position = vec4(p, 0.0, 1.0);
}
`;

const FRAGMENT_SHADER_SRC = `
precision highp float;
uniform vec2 r;
uniform float t;
uniform vec2 mo;
uniform float u_light;

float h(vec2 p) {
  return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float n(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  return mix(
    mix(h(i), h(i + vec2(1.0, 0.0)), f.x),
    mix(h(i + vec2(0.0, 1.0)), h(i + vec2(1.0, 1.0)), f.x),
    f.y
  );
}

float fbm(vec2 p) {
  float v = 0.0;
  float a = 0.5;
  for (int i = 0; i < 5; i++) {
    v += a * n(p);
    p *= 2.02;
    a *= 0.5;
  }
  return v;
}

void main() {
  vec2 uv = gl_FragCoord.xy / r;
  float as = r.x / r.y;
  vec2 p = uv * vec2(as, 1.0) * 1.4;
  float tt = t * 0.045;

  float q = fbm(p + vec2(tt, -tt * 0.7));
  float w = fbm(p * 1.25 + q * 1.9 + vec2(-tt * 0.6, tt));

  vec3 orange = vec3(1.0, 0.54, 0.24);
  vec3 pink = vec3(1.0, 0.24, 0.5);
  vec3 plum = vec3(0.33, 0.15, 0.23);

  float m1 = smoothstep(0.42, 0.95, w) * smoothstep(1.25, 0.15, length((uv - vec2(0.78, 0.82)) * vec2(as, 1.0) * 0.7));
  float m2 = smoothstep(0.48, 1.0, fbm(p * 0.9 - vec2(tt * 0.8, 0.0) + w)) * smoothstep(1.2, 0.1, length((uv - vec2(0.2, 0.18)) * vec2(as, 1.0) * 0.7));
  float md = smoothstep(0.45, 0.0, length((uv - mo) * vec2(as, 1.0)));

  if (u_light > 0.5) {
    // Light mode: clean warm off-white base with soft pastel warm orange/pink tints
    vec3 baseCol = vec3(0.97, 0.97, 0.975);
    vec3 warmAccent = mix(orange, pink, uv.x);
    float glow = clamp(m1 * 0.12 + m2 * 0.10 + md * 0.04, 0.0, 1.0);
    vec3 col = mix(baseCol, warmAccent, glow);
    gl_FragColor = vec4(col, 1.0);
  } else {
    // Dark mode
    vec3 col = plum * q * 0.35 + orange * m1 * 0.8 + pink * m2 * 0.65 + mix(orange, pink, uv.x) * md * 0.16;
    col += (h(gl_FragCoord.xy + fract(t) * 100.0) - 0.5) * 0.05;
    gl_FragColor = vec4(col, 1.0);
  }
}
`;

export function AuroraShader({
  opacity = 1,
  interactive = true,
  className,
  forceDark = false,
}: AuroraShaderProps) {
  const { resolvedTheme } = useTheme();
  const isLight = !forceDark && resolvedTheme === 'light';
  const canvasRef = useRef<HTMLCanvasElement | null>(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    // Check WebGL availability
    let gl: WebGLRenderingContext | null = null;
    try {
      gl = canvas.getContext('webgl', {
        powerPreference: 'low-power',
        alpha: false,
        depth: false,
        stencil: false,
        antialias: false,
      });
    } catch {
      // WebGL not available
    }

    if (!gl) return;

    const compileShader = (type: number, src: string) => {
      const s = gl!.createShader(type);
      if (!s) return null;
      gl!.shaderSource(s, src);
      gl!.compileShader(s);
      return s;
    };

    const vs = compileShader(gl.VERTEX_SHADER, VERTEX_SHADER_SRC);
    const fs = compileShader(gl.FRAGMENT_SHADER, FRAGMENT_SHADER_SRC);
    if (!vs || !fs) return;

    const pr = gl.createProgram();
    if (!pr) return;
    gl.attachShader(pr, vs);
    gl.attachShader(pr, fs);
    gl.linkProgram(pr);
    gl.useProgram(pr);

    const buffer = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, buffer);
    gl.bufferData(
      gl.ARRAY_BUFFER,
      new Float32Array([-1, -1, 3, -1, -1, 3]),
      gl.STATIC_DRAW
    );

    const posLoc = gl.getAttribLocation(pr, 'p');
    gl.enableVertexAttribArray(posLoc);
    gl.vertexAttribPointer(posLoc, 2, gl.FLOAT, false, 0, 0);

    const ur = gl.getUniformLocation(pr, 'r');
    const ut = gl.getUniformLocation(pr, 't');
    const um = gl.getUniformLocation(pr, 'mo');
    const ul = gl.getUniformLocation(pr, 'u_light');

    const reduce =
      typeof window !== 'undefined' &&
      window.matchMedia?.('(prefers-reduced-motion: reduce)')?.matches;

    let mx = 0.7;
    let my = 0.5;
    let sx = 0.7;
    let sy = 0.5;

    const onPointerMove = (e: PointerEvent) => {
      if (!interactive) return;
      const w = window.innerWidth || 1;
      const h = window.innerHeight || 1;
      mx = e.clientX / w;
      my = 1.0 - e.clientY / h;
    };

    if (interactive) {
      window.addEventListener('pointermove', onPointerMove, { passive: true });
    }

    let animId: number | null = null;
    let isRunning = true;

    const renderFrame = (ms: number) => {
      if (!isRunning || !canvas || !gl) return;

      const dpr = Math.min(window.devicePixelRatio || 1, 1.5);
      const w = (canvas.clientWidth || window.innerWidth || 300) * dpr;
      const h = (canvas.clientHeight || window.innerHeight || 150) * dpr;

      if (canvas.width !== w || canvas.height !== h) {
        canvas.width = w;
        canvas.height = h;
        gl.viewport(0, 0, w, h);
      }

      sx += (mx - sx) * 0.04;
      sy += (my - sy) * 0.04;

      gl.uniform2f(ur, canvas.width, canvas.height);
      gl.uniform1f(ut, reduce ? 20.0 : ms / 1000 + 20.0);
      gl.uniform2f(um, sx, sy);
      gl.uniform1f(ul, isLight ? 1.0 : 0.0);
      gl.drawArrays(gl.TRIANGLES, 0, 3);

      if (!reduce && !document.hidden) {
        animId = requestAnimationFrame(renderFrame);
      }
    };

    animId = requestAnimationFrame(renderFrame);

    const onVisibility = () => {
      if (document.hidden) {
        if (animId) cancelAnimationFrame(animId);
      } else if (!reduce) {
        animId = requestAnimationFrame(renderFrame);
      }
    };

    document.addEventListener('visibilitychange', onVisibility);

    return () => {
      isRunning = false;
      if (interactive) {
        window.removeEventListener('pointermove', onPointerMove);
      }
      document.removeEventListener('visibilitychange', onVisibility);
      if (animId) cancelAnimationFrame(animId);
      try {
        gl?.deleteProgram(pr);
        gl?.deleteShader(vs);
        gl?.deleteShader(fs);
        gl?.deleteBuffer(buffer);
      } catch {
        // cleanup safe
      }
    };
  }, [interactive, isLight]);

  const effectiveOpacity = isLight ? Math.min(opacity, 0.45) : opacity;

  return (
    <div
      aria-hidden="true"
      className={cn('fixed inset-0 pointer-events-none -z-10 overflow-hidden', className)}
      style={{ opacity: effectiveOpacity }}
    >
      <canvas
        ref={canvasRef}
        className="w-full h-full block"
        style={{ background: isLight ? '#F7F7F8' : '#000000' }}
      />
      {/* Vignette overlay */}
      <div
        data-testid="aurora-vignette"
        className="absolute inset-0 pointer-events-none"
        style={{
          background: isLight
            ? 'none'
            : 'radial-gradient(ellipse at 30% 50%, transparent 30%, rgba(0, 0, 0, 0.55) 100%)',
        }}
      />
    </div>
  );
}
