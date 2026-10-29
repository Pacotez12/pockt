import { expect, test } from 'vitest';
import { AppSchema } from './schema';

test('spike_tx declara amount con almacenamiento INTEGER', () => {
  const table = AppSchema.tables.find((table) => table.name === 'spike_tx');
  expect(table).toBeDefined();
  expect(table?.columns.find((column) => column.name === 'amount')?.type).toBe('INTEGER');
});
