import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const distDir = path.resolve(__dirname, '../dist');
const assetsDir = path.join(distDir, 'assets');

if (!fs.existsSync(assetsDir)) {
  console.error('Error: dist/assets directory not found. Run npm run build first.');
  process.exit(1);
}

const files = fs.readdirSync(assetsDir);
const jsFiles = files.filter((f) => f.endsWith('.js'));
const entryFile = jsFiles.find((f) => f.startsWith('index-'));

if (!entryFile) {
  console.error('Error: entry chunk index-*.js not found in dist/assets.');
  process.exit(1);
}

const MAX_ENTRY_CHUNK_KB = 350;
const entryContent = fs.readFileSync(path.join(assetsDir, entryFile), 'utf8');
const entrySizeKb = fs.statSync(path.join(assetsDir, entryFile)).size / 1024;

console.log(`Bundle Check:`);
console.log(`- Entry chunk: ${entryFile} (${entrySizeKb.toFixed(2)} kB)`);

const bannedInEntry = [
  { name: 'three.js', check: (c) => c.includes('WebGLRenderer') || c.includes('THREE') },
  { name: 'jspdf', check: (c) => c.includes('jsPDF') },
  { name: 'exceljs', check: (c) => c.includes('ExcelJS') },
];

let failed = false;

if (entrySizeKb > MAX_ENTRY_CHUNK_KB) {
  console.error(`FAIL: Entry chunk exceeds ${MAX_ENTRY_CHUNK_KB} kB limit (${entrySizeKb.toFixed(2)} kB)`);
  failed = true;
}

for (const { name, check } of bannedInEntry) {
  if (check(entryContent)) {
    console.error(`FAIL: Entry chunk contains ${name}! It must be deferred.`);
    failed = true;
  }
}

// Check vendor chunks if present
for (const f of jsFiles) {
  if (f.startsWith('vendor-')) {
    const sizeKb = fs.statSync(path.join(assetsDir, f)).size / 1024;
    console.log(`- Vendor chunk: ${f} (${sizeKb.toFixed(2)} kB)`);
    if (sizeKb > MAX_ENTRY_CHUNK_KB) {
      console.error(`FAIL: Vendor chunk ${f} exceeds ${MAX_ENTRY_CHUNK_KB} kB (${sizeKb.toFixed(2)} kB)`);
      failed = true;
    }
    const content = fs.readFileSync(path.join(assetsDir, f), 'utf8');
    for (const { name, check } of bannedInEntry) {
      if (check(content)) {
        console.error(`FAIL: Vendor chunk ${f} contains ${name}!`);
        failed = true;
      }
    }
  }
}

// Check deferred heavy chunks
const reportesChunk = jsFiles.find((f) => f.startsWith('reportes-'));
const excelChunk = jsFiles.find((f) => f.startsWith('exceljs'));
const jspdfChunk = jsFiles.find((f) => f.startsWith('jspdf'));

console.log(`- Reportes chunk (deferred): ${reportesChunk || 'not found'}`);
console.log(`- ExcelJS chunk (deferred): ${excelChunk || 'not found'}`);
console.log(`- jsPDF chunk (deferred): ${jspdfChunk || 'not found'}`);

if (!excelChunk) {
  console.error('FAIL: exceljs is not properly code-split into its own chunk.');
  failed = true;
}

if (!jspdfChunk) {
  console.error('FAIL: jspdf is not properly code-split into its own chunk.');
  failed = true;
}

if (failed) {
  process.exit(1);
}

console.log('SUCCESS: All bundle size and code-splitting constraints satisfied.');
