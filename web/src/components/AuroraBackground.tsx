import React from 'react';

export function AuroraBackground() {
  return (
    <div className="pointer-events-none fixed inset-0 overflow-hidden -z-10">
      {/* Top ambient orange/coral orb */}
      <div
        className="absolute w-[680px] h-[680px] -top-[420px] left-1/2 -translate-x-1/2 rounded-full blur-3xl opacity-35 dark:opacity-40"
        style={{
          background: 'radial-gradient(circle, #FF7053 0%, rgba(255, 61, 127, 0.25) 45%, transparent 70%)',
        }}
      />
      {/* Subtle bottom corner ambient glow */}
      <div
        className="absolute w-[480px] h-[480px] -bottom-[280px] -right-[120px] rounded-full blur-3xl opacity-20 dark:opacity-25"
        style={{
          background: 'radial-gradient(circle, #FF3D7F 0%, transparent 65%)',
        }}
      />
    </div>
  );
}
