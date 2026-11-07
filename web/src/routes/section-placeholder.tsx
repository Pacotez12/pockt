import React, { useEffect } from 'react';

export function SectionPlaceholderRoute({
  title,
  stage,
}: {
  title: string;
  stage: string;
}) {
  useEffect(() => {
    document.title = `${title} · Pockt`;
  }, [title]);

  return (
    <div className="space-y-6">
      <h1 className="text-[26px] sm:text-[28px] font-extrabold tracking-tight text-text-primary">
        {title}
      </h1>
      <div className="rounded-2xl p-8 bg-glass-fill border border-glass-border text-center max-w-[500px]">
        <div className="text-[15px] font-bold text-text-primary">{title}</div>
        <div className="text-[13px] text-text-secondary mt-1.5 leading-relaxed">
          Esta sección estará disponible en la {stage}.
        </div>
      </div>
    </div>
  );
}
