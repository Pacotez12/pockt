import { describe, it, expect } from 'vitest';
import {
  escapeCsvField,
  toCsv,
  toXlsx,
  getExportFilename,
  MovementExportRow,
} from './export';
import ExcelJS from 'exceljs';

describe('export movements', () => {
  describe('escapeCsvField', () => {
    it('prefija con comilla simple los campos que Excel tomaría como fórmula', () => {
      expect(escapeCsvField('=SUM(A1:A9)')).toBe("'=SUM(A1:A9)");
      expect(escapeCsvField('+595981123456')).toBe("'+595981123456");
      expect(escapeCsvField('-2+3')).toBe("'-2+3");
      expect(escapeCsvField('@usuario')).toBe("'@usuario");
    });

    it('combina el prefijo con el entrecomillado cuando hace falta', () => {
      expect(escapeCsvField('=HYPERLINK("http://x";"y")')).toBe(
        '"\'=HYPERLINK(""http://x"";""y"")"'
      );
    });

    it('no toca los campos normales ni los que tienen el símbolo en medio', () => {
      expect(escapeCsvField('Supermercado')).toBe('Supermercado');
      expect(escapeCsvField('2x1 = promo')).toBe('2x1 = promo');
      expect(escapeCsvField('a@b.com')).toBe('a@b.com');
      expect(escapeCsvField('')).toBe('');
    });

    it('mantiene el entrecomillado de separadores, comillas y saltos de línea', () => {
      expect(escapeCsvField('uno;dos')).toBe('"uno;dos"');
      expect(escapeCsvField('dijo "hola"')).toBe('"dijo ""hola"""');
      expect(escapeCsvField('linea1\nlinea2')).toBe('"linea1\nlinea2"');
    });
  });

  describe('toCsv', () => {
    it('generates CSV with UTF-8 BOM, semicolon separator, and correct headers and values', () => {
      const rows: MovementExportRow[] = [
        {
          type: 'expense',
          amount: 184000,
          category_name: 'Comida',
          note: 'Compra semanal; pan y leche',
          merchant: 'Superseis',
          // 2026-10-28 13:20
          occurred_at: Math.floor(new Date('2026-10-28T13:20:00').getTime() / 1000),
        },
        {
          type: 'income',
          amount: 3000000,
          category_name: 'Sueldo',
          note: null,
          merchant: null,
          occurred_at: Math.floor(new Date('2026-10-27T10:00:00').getTime() / 1000),
        },
        {
          type: 'transfer',
          amount: 500000,
          category_name: 'Ahorro',
          note: '=TRANSFERENCIA',
          merchant: 'Banco Itaú',
          occurred_at: Math.floor(new Date('2026-10-26T08:00:00').getTime() / 1000),
        },
      ];

      const csv = toCsv(rows);

      // Must start with UTF-8 BOM
      expect(csv.startsWith('\uFEFF')).toBe(true);

      const lines = csv.slice(1).split('\n').filter(Boolean);
      expect(lines[0]).toBe('Fecha;Tipo;Monto;Categoría;Nota;Comercio');

      // First row
      expect(lines[1]).toContain('Gasto;184000;Comida;"Compra semanal; pan y leche";Superseis');
      // Second row
      expect(lines[2]).toContain('Ingreso;3000000;Sueldo;;');
      // Third row with formula protection on note
      expect(lines[3]).toContain('Transferencia;500000;Ahorro;\'=TRANSFERENCIA;Banco Itaú');
    });
  });

  describe('toXlsx', () => {
    it('generates valid Excel file buffer with columns and numeric formatted amounts', async () => {
      const rows: MovementExportRow[] = [
        {
          type: 'expense',
          amount: 184000,
          category_name: 'Comida',
          note: 'Almuerzo',
          merchant: 'Bolsi',
          occurred_at: Math.floor(new Date('2026-10-28T13:20:00').getTime() / 1000),
        },
      ];

      const buffer = await toXlsx(rows);
      expect(buffer).toBeDefined();
      expect(buffer.byteLength).toBeGreaterThan(0);

      // Verify with ExcelJS reader
      const workbook = new ExcelJS.Workbook();
      await workbook.xlsx.load(buffer as any);
      const sheet = workbook.getWorksheet('Movimientos');
      expect(sheet).toBeDefined();

      const headerRow = sheet?.getRow(1).values as string[];
      expect(headerRow).toContain('Fecha');
      expect(headerRow).toContain('Tipo');
      expect(headerRow).toContain('Monto');
      expect(headerRow).toContain('Categoría');

      const dataRow = sheet?.getRow(2);
      expect(dataRow?.getCell(2).value).toBe('Gasto');
      expect(dataRow?.getCell(3).value).toBe(184000); // numeric amount
    });
  });

  describe('getExportFilename', () => {
    it('formats filename with YYYY-MM-DD date and extension', () => {
      const date = new Date('2026-11-07T12:00:00');
      expect(getExportFilename('csv', date)).toBe('pockt-movimientos-2026-11-07.csv');
      expect(getExportFilename('xlsx', date)).toBe('pockt-movimientos-2026-11-07.xlsx');
    });
  });
});
