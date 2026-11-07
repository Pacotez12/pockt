import React, { useEffect, useState } from 'react';
import { useReducedMotion } from 'motion/react';
import { formatGs } from '@/lib/format';
import { cn } from '@/lib/utils';

export interface CountUpProps {
  value: number;
  duration?: number;
  formatter?: (val: number) => string;
  className?: string;
}

function checkReducedMotion(): boolean {
  if (typeof window === 'undefined') return false;
  return Boolean(window.matchMedia?.('(prefers-reduced-motion: reduce)')?.matches);
}

export function CountUp({
  value,
  duration = 1000,
  formatter = (v) => formatGs(v),
  className,
}: CountUpProps) {
  const motionReduced = useReducedMotion();
  const prefersReduced = Boolean(motionReduced || checkReducedMotion());
  const [displayValue, setDisplayValue] = useState(() => (checkReducedMotion() ? value : 0));

  useEffect(() => {
    if (prefersReduced) {
      setDisplayValue(value);
      return;
    }

    let frameId: number;
    const startTime = performance.now();
    const startVal = 0;
    const diff = value - startVal;

    const tick = (now: number) => {
      const elapsed = now - startTime;
      const progress = Math.max(0, Math.min(1, elapsed / duration));
      // Ease out cubic
      const ease = 1 - Math.pow(1 - progress, 3);
      const current = Math.round(startVal + diff * ease);

      setDisplayValue(current);

      if (progress < 1) {
        frameId = requestAnimationFrame(tick);
      } else {
        setDisplayValue(value);
      }
    };

    frameId = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(frameId);
  }, [value, duration, prefersReduced]);

  return (
    <span className={cn('tabular-nums inline-block', className)}>
      {formatter(displayValue)}
    </span>
  );
}
