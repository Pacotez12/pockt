import React from 'react';
import { cn } from '@/lib/utils';

export interface SkeletonProps extends React.HTMLAttributes<HTMLDivElement> {
  shimmer?: boolean;
}

export function Skeleton({ className, shimmer = true, ...props }: SkeletonProps) {
  return (
    <div
      role="status"
      aria-label="Cargando..."
      className={cn(
        'rounded-xl bg-glass-fill border border-glass-border',
        shimmer && 'skeleton-shimmer',
        className
      )}
      {...props}
    />
  );
}
