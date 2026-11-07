import { describe, it, expect } from 'vitest';
import fs from 'node:fs';
import path from 'node:path';
import YAML from 'yaml';
import { AppSchema } from './schema';

describe('AppSchema matches backend/powersync/sync-streams.yaml', () => {
  it('defines all 12 tables and exact columns from sync-streams.yaml', () => {
    // Locate sync-streams.yaml in repo
    const yamlPath = path.resolve(__dirname, '../../../../backend/powersync/sync-streams.yaml');
    expect(fs.existsSync(yamlPath)).toBe(true);

    const yamlContent = fs.readFileSync(yamlPath, 'utf8');
    const parsed = YAML.parse(yamlContent);
    const queries: string[] = parsed.streams.user_data.queries;

    expect(queries.length).toBe(12);

    // Schema tables map by name
    const schemaTables = new Map(AppSchema.tables.map((t) => [t.name, t]));
    expect(schemaTables.size).toBe(12);

    for (const query of queries) {
      // Regex parse "SELECT col1, col2, ... FROM tablename WHERE ..."
      const match = query.match(/SELECT\s+(.+?)\s+FROM\s+(\w+)\s+WHERE/i);
      expect(match).not.toBeNull();
      if (!match) continue;

      const rawCols = match[1].split(',').map((c) => c.trim());
      const tableName = match[2].trim();

      const table = schemaTables.get(tableName);
      expect(table, `Table ${tableName} should exist in schema`).toBeDefined();
      if (!table) continue;

      // Extract non-id columns from YAML
      const yamlColsWithoutId = rawCols.filter((c) => c !== 'id');
      const schemaColNames = table.columns.map((c) => c.name);

      // Verify all non-id columns exist in schema
      for (const col of yamlColsWithoutId) {
        expect(
          schemaColNames,
          `Column "${col}" of table "${tableName}" should exist in AppSchema`
        ).toContain(col);
      }

      // Verify no extra columns exist in schema that are not in YAML
      for (const col of schemaColNames) {
        expect(
          yamlColsWithoutId,
          `AppSchema column "${col}" in "${tableName}" should be in sync-streams.yaml`
        ).toContain(col);
      }

      // Column count check
      expect(schemaColNames.length).toBe(yamlColsWithoutId.length);
    }
  });

  it('passes AppSchema.validate()', () => {
    expect(() => AppSchema.validate()).not.toThrow();
  });
});
