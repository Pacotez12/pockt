import { formatGs } from '../format';

export interface ReportCategoryItem {
  name: string;
  amount: number;
  percentage: number;
}

export interface ReportMerchantItem {
  name: string;
  amount: number;
  percentage: number;
}

export interface ReportAntExpensesData {
  total: number;
  count: number;
  percentageOfExpenses: number;
  topMerchants: Array<{ name: string; amount: number }>;
}

export interface ReportPdfData {
  periodLabel: string;
  totalExpenses: number;
  totalIncome: number;
  netSavings: number;
  highestMonth?: {
    name: string;
    amount: number;
  };
  annualSubscriptions?: {
    amount: number;
    count: number;
  };
  topCategories: ReportCategoryItem[];
  topMerchants: ReportMerchantItem[];
  antExpenses?: ReportAntExpensesData;
}

export async function generateReportPdf(data: ReportPdfData): Promise<Blob> {
  const { jsPDF } = await import('jspdf');
  const doc = new jsPDF({
    orientation: 'portrait',
    unit: 'mm',
    format: 'a4',
  });

  const pageWidth = doc.internal.pageSize.getWidth();
  const margin = 18;
  const contentWidth = pageWidth - margin * 2;
  let y = margin;

  // Header
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(22);
  doc.setTextColor(20, 20, 22);
  doc.text('Pockt', margin, y + 6);

  doc.setFont('helvetica', 'normal');
  doc.setFontSize(10);
  doc.setTextColor(110, 110, 118);
  const dateStr = new Date().toLocaleDateString('es-PY', {
    day: '2-digit',
    month: 'long',
    year: 'numeric',
  });
  doc.text(`Generado el ${dateStr}`, pageWidth - margin, y + 6, { align: 'right' });

  y += 15;

  // Title & Period
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(16);
  doc.setTextColor(20, 20, 22);
  doc.text('Resumen de Reportes', margin, y);

  doc.setFont('helvetica', 'normal');
  doc.setFontSize(12);
  doc.setTextColor(90, 90, 98);
  doc.text(`Período: ${data.periodLabel}`, margin, y + 6);

  y += 14;

  // Thin separator rule
  doc.setDrawColor(220, 220, 225);
  doc.setLineWidth(0.3);
  doc.line(margin, y, margin + contentWidth, y);
  y += 6;

  // KPIs 4-box grid
  const kpiWidth = (contentWidth - 9) / 4;
  const kpiHeight = 22;

  const kpis = [
    { label: 'Gastado', value: formatGs(data.totalExpenses), color: [20, 20, 22] },
    { label: 'Ingresos', value: formatGs(data.totalIncome), color: [30, 140, 70] },
    { label: 'Ahorro neto', value: formatGs(data.netSavings), color: [20, 20, 22] },
    {
      label: 'Suscripciones / año',
      value: data.annualSubscriptions
        ? formatGs(data.annualSubscriptions.amount)
        : '-',
      color: [20, 20, 22],
    },
  ];

  for (let i = 0; i < kpis.length; i++) {
    const kx = margin + i * (kpiWidth + 3);
    doc.setFillColor(248, 248, 250);
    doc.roundedRect(kx, y, kpiWidth, kpiHeight, 2, 2, 'F');

    doc.setFont('helvetica', 'normal');
    doc.setFontSize(8.5);
    doc.setTextColor(100, 100, 110);
    doc.text(kpis[i].label, kx + 3, y + 6);

    doc.setFont('helvetica', 'bold');
    doc.setFontSize(10.5);
    doc.setTextColor(kpis[i].color[0], kpis[i].color[1], kpis[i].color[2]);
    doc.text(kpis[i].value, kx + 3, y + 15);
  }

  y += kpiHeight + 10;

  // Two columns: Top Categories & Top Merchants
  const colWidth = (contentWidth - 8) / 2;
  const col1X = margin;
  const col2X = margin + colWidth + 8;
  const sectionStartY = y;

  // Column 1: Categorías
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(12);
  doc.setTextColor(20, 20, 22);
  doc.text('Por categoría', col1X, y);
  y += 5;

  if (data.topCategories.length === 0) {
    doc.setFont('helvetica', 'italic');
    doc.setFontSize(9.5);
    doc.setTextColor(130, 130, 140);
    doc.text('Sin gastos en el período', col1X, y + 4);
    y += 10;
  } else {
    for (const cat of data.topCategories.slice(0, 7)) {
      y += 5;
      doc.setFont('helvetica', 'normal');
      doc.setFontSize(9.5);
      doc.setTextColor(30, 30, 35);
      const name = cat.name.length > 20 ? `${cat.name.slice(0, 19)}…` : cat.name;
      doc.text(name, col1X, y);

      const valStr = `${formatGs(cat.amount)} (${cat.percentage.toFixed(1)}%)`;
      doc.text(valStr, col1X + colWidth, y, { align: 'right' });

      // subtle bar
      y += 1.8;
      doc.setFillColor(235, 235, 240);
      doc.roundedRect(col1X, y, colWidth, 1.8, 0.9, 0.9, 'F');
      const barFill = Math.min(1, Math.max(0, cat.percentage / 100));
      if (barFill > 0) {
        doc.setFillColor(255, 112, 83);
        doc.roundedRect(col1X, y, colWidth * barFill, 1.8, 0.9, 0.9, 'F');
      }
      y += 2.5;
    }
  }

  const col1EndY = y;

  // Column 2: Comercios
  y = sectionStartY;
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(12);
  doc.setTextColor(20, 20, 22);
  doc.text('Dónde gastás más', col2X, y);
  y += 5;

  if (data.topMerchants.length === 0) {
    doc.setFont('helvetica', 'italic');
    doc.setFontSize(9.5);
    doc.setTextColor(130, 130, 140);
    doc.text('Sin comercios registrados', col2X, y + 4);
    y += 10;
  } else {
    for (const m of data.topMerchants.slice(0, 7)) {
      y += 5;
      doc.setFont('helvetica', 'normal');
      doc.setFontSize(9.5);
      doc.setTextColor(30, 30, 35);
      const name = m.name.length > 20 ? `${m.name.slice(0, 19)}…` : m.name;
      doc.text(name, col2X, y);

      const valStr = `${formatGs(m.amount)} (${m.percentage.toFixed(1)}%)`;
      doc.text(valStr, col2X + colWidth, y, { align: 'right' });

      // subtle bar
      y += 1.8;
      doc.setFillColor(235, 235, 240);
      doc.roundedRect(col2X, y, colWidth, 1.8, 0.9, 0.9, 'F');
      const barFill = Math.min(1, Math.max(0, m.percentage / 100));
      if (barFill > 0) {
        doc.setFillColor(107, 186, 240);
        doc.roundedRect(col2X, y, colWidth * barFill, 1.8, 0.9, 0.9, 'F');
      }
      y += 2.5;
    }
  }

  y = Math.max(col1EndY, y) + 10;

  // Gastos hormiga if available
  if (data.antExpenses && data.antExpenses.count > 0) {
    doc.setFillColor(252, 252, 253);
    doc.setDrawColor(230, 230, 235);
    doc.roundedRect(margin, y, contentWidth, 24, 2, 2, 'FD');

    doc.setFont('helvetica', 'bold');
    doc.setFontSize(10.5);
    doc.setTextColor(20, 20, 22);
    doc.text('Gastos hormiga', margin + 4, y + 6);

    doc.setFont('helvetica', 'normal');
    doc.setFontSize(9);
    doc.setTextColor(90, 90, 100);
    doc.text(
      `${data.antExpenses.count} gastos menores suman ${formatGs(data.antExpenses.total)} (${data.antExpenses.percentageOfExpenses.toFixed(1)}% del total gastado).`,
      margin + 4,
      y + 13
    );

    if (data.antExpenses.topMerchants.length > 0) {
      const topStr = data.antExpenses.topMerchants
        .map((tm) => `${tm.name}: ${formatGs(tm.amount)}`)
        .join(' · ');
      doc.text(`Principales: ${topStr}`, margin + 4, y + 19);
    }

    y += 32;
  }

  // Footer
  const footerY = doc.internal.pageSize.getHeight() - margin;
  doc.setFont('helvetica', 'normal');
  doc.setFontSize(8);
  doc.setTextColor(140, 140, 150);
  doc.text('Pockt Web · Control financiero personal', margin, footerY);
  doc.text('pockt.app', pageWidth - margin, footerY, { align: 'right' });

  return doc.output('blob');
}
