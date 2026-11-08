export interface MovementExportRow {
  type: string;
  amount: number;
  occurred_at: number; // Unix seconds or ms
  category_name?: string | null;
  note?: string | null;
  merchant?: string | null;
}

export function escapeCsvField(field: string): string {
  let value = field;
  if (value.length > 0) {
    const stripped = value.replace(/^[ \t\r\n]+/, '');
    const startsWithFormula =
      stripped.length > 0 && '=+-@'.includes(stripped[0]);
    const startsWithControlOrPipe =
      value.startsWith('\t') || value.startsWith('\r') || value.startsWith('|');

    if (startsWithFormula || startsWithControlOrPipe) {
      value = `'${value}`;
    }
  }
  if (
    value.includes(';') ||
    value.includes('"') ||
    value.includes('\n') ||
    value.includes('\r')
  ) {
    return `"${value.replaceAll('"', '""')}"`;
  }
  return value;
}

export function formatExportDate(timestampInSecondsOrMs: number): string {
  const ms =
    timestampInSecondsOrMs > 1e11
      ? timestampInSecondsOrMs
      : timestampInSecondsOrMs * 1000;
  const d = new Date(ms);
  const year = d.getFullYear();
  const month = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  const hours = String(d.getHours()).padStart(2, '0');
  const minutes = String(d.getMinutes()).padStart(2, '0');
  return `${year}-${month}-${day} ${hours}:${minutes}`;
}

export function mapTypeToSpanish(type: string): string {
  switch (type) {
    case 'expense':
      return 'Gasto';
    case 'income':
      return 'Ingreso';
    case 'transfer':
      return 'Transferencia';
    default:
      return type;
  }
}

export function toCsv(rows: MovementExportRow[]): string {
  let csv = '\uFEFFFecha;Tipo;Monto;Categoría;Nota;Comercio\n';
  for (const row of rows) {
    const fecha = formatExportDate(row.occurred_at);
    const tipo = mapTypeToSpanish(row.type);
    const monto = String(row.amount);
    const categoria = escapeCsvField(row.category_name || '');
    const nota = escapeCsvField(row.note || '');
    const comercio = escapeCsvField(row.merchant || '');
    csv += `${fecha};${tipo};${monto};${categoria};${nota};${comercio}\n`;
  }
  return csv;
}

export async function toXlsx(rows: MovementExportRow[]): Promise<Uint8Array> {
  const ExcelJS = await import('exceljs').then((m) => (m.default ? m.default : m));
  const workbook = new ExcelJS.Workbook();
  const sheet = workbook.addWorksheet('Movimientos');

  sheet.columns = [
    { header: 'Fecha', key: 'fecha', width: 18 },
    { header: 'Tipo', key: 'tipo', width: 14 },
    { header: 'Monto', key: 'monto', width: 16 },
    { header: 'Categoría', key: 'categoria', width: 20 },
    { header: 'Nota', key: 'nota', width: 28 },
    { header: 'Comercio', key: 'comercio', width: 24 },
  ];

  const headerRow = sheet.getRow(1);
  headerRow.font = { bold: true };

  for (const row of rows) {
    const rowRef = sheet.addRow({
      fecha: formatExportDate(row.occurred_at),
      tipo: mapTypeToSpanish(row.type),
      monto: Number(row.amount),
      categoria: row.category_name || '',
      nota: row.note || '',
      comercio: row.merchant || '',
    });

    rowRef.getCell('monto').numFmt = '#,##0';
  }

  const buffer = await workbook.xlsx.writeBuffer();
  return new Uint8Array(buffer);
}

export function getExportFilename(
  type: 'csv' | 'xlsx',
  date = new Date()
): string {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `pockt-movimientos-${year}-${month}-${day}.${type}`;
}

export function downloadBlob(blob: Blob, filename: string): void {
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
}
