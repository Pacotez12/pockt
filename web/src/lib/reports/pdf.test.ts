import { describe, it, expect, vi } from 'vitest';
import { generateReportPdf, type ReportPdfData } from './pdf';

describe('generateReportPdf', () => {
  const sampleData: ReportPdfData = {
    periodLabel: 'Octubre 2026',
    totalExpenses: 3214500,
    totalIncome: 6000000,
    netSavings: 2785500,
    highestMonth: {
      name: 'Agosto',
      amount: 4020000,
    },
    annualSubscriptions: {
      amount: 2443500,
      count: 4,
    },
    topCategories: [
      { name: 'Supermercado', amount: 1450000, percentage: 45.1 },
      { name: 'Transporte', amount: 620000, percentage: 19.3 },
      { name: 'Servicios', amount: 380000, percentage: 11.8 },
    ],
    topMerchants: [
      { name: 'Superseis', amount: 980000, percentage: 30.5 },
      { name: 'Bolt', amount: 620000, percentage: 19.3 },
      { name: 'Biggie', amount: 470000, percentage: 14.6 },
    ],
    antExpenses: {
      total: 340000,
      count: 14,
      percentageOfExpenses: 10.6,
      topMerchants: [
        { name: 'Café Martínez', amount: 120000 },
        { name: 'Kiosco', amount: 85000 },
      ],
    },
  };

  it('generates a non-empty PDF blob/bytes for given report data', async () => {
    const pdfBlob = await generateReportPdf(sampleData);
    expect(pdfBlob).toBeDefined();
    expect(pdfBlob.size).toBeGreaterThan(100);
    expect(pdfBlob.type).toBe('application/pdf');
  });

  it('handles empty categories and merchants gracefully without error', async () => {
    const emptyData: ReportPdfData = {
      periodLabel: 'Noviembre 2026',
      totalExpenses: 0,
      totalIncome: 0,
      netSavings: 0,
      topCategories: [],
      topMerchants: [],
    };
    const pdfBlob = await generateReportPdf(emptyData);
    expect(pdfBlob).toBeDefined();
    expect(pdfBlob.size).toBeGreaterThan(100);
  });
});
