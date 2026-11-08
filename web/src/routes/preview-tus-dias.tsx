import React, { useMemo, useEffect } from 'react';
import { useSearchParams } from 'react-router-dom';
import { TusDias, type DayData } from '@/components/reports/TusDias';

export function PreviewTusDiasRoute() {
  const [params] = useSearchParams();
  const weeksCount = parseInt(params.get('weeks') || '8', 10);
  const themeParam = params.get('theme') || 'dark';
  const modeParam = (params.get('mode') as '2d' | '3d') || '3d';

  useEffect(() => {
    const root = document.documentElement;
    if (themeParam === 'light') {
      root.classList.add('light');
      root.classList.remove('dark');
    } else {
      root.classList.remove('light');
      root.classList.add('dark');
    }
  }, [themeParam]);

  const mockData = useMemo(() => {
    const refDate = new Date(2026, 10, 8); // Sunday 8 Nov 2026
    const totalDays = weeksCount * 7;
    const days: DayData[] = [];

    // Start date totalDays - 7 before refDate (aligning to week start Monday)
    const startDate = new Date(refDate);
    startDate.setDate(refDate.getDate() - (totalDays - 7));
    // Find Monday of that week
    const dayOfWeek = (startDate.getDay() + 6) % 7;
    startDate.setDate(startDate.getDate() - dayOfWeek);

    for (let i = 0; i < totalDays; i++) {
      const curDate = new Date(startDate);
      curDate.setDate(startDate.getDate() + i);

      // Create variation in spending
      let amt = 0;
      let txCount = 0;
      let topMerchant: string | undefined;

      const isMax = i === Math.floor(totalDays * 0.45);
      if (isMax) {
        amt = 1850000;
        txCount = 3;
        topMerchant = 'Shopping del Sol';
      } else if (i % 5 === 0) {
        amt = 0; // empty day
      } else if (i % 2 === 0) {
        amt = 75000 + (i % 7) * 45000;
        txCount = 2;
        topMerchant = 'Superseis';
      } else {
        amt = 35000 + (i % 4) * 20000;
        txCount = 1;
        topMerchant = 'Biggie';
      }

      days.push({
        date: curDate,
        amount: amt,
        txCount,
        topMerchant,
      });
    }

    return { days, refDate };
  }, [weeksCount]);

  return (
    <div className="min-h-screen p-6 bg-background text-text-primary transition-colors">
      <div className="max-w-4xl mx-auto space-y-4">
        <div className="flex items-center justify-between">
          <h1 className="text-xl font-bold">
            Tus Días 3D Preview ({weeksCount} semanas · {themeParam})
          </h1>
          <div className="text-xs text-text-tertiary">
            Viewport test: compu / 412px mobile
          </div>
        </div>

        <TusDias
          days={mockData.days}
          referenceDate={mockData.refDate}
          today={mockData.refDate}
          initialMode={modeParam}
        />
      </div>
    </div>
  );
}
