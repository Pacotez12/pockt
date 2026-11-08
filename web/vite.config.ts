import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/vite';
import path from 'node:path';
import fs from 'node:fs';

const vercelConfig = JSON.parse(fs.readFileSync(path.resolve(import.meta.dirname, 'vercel.json'), 'utf8'));

export default defineConfig({
  plugins: [
    react(),
    tailwindcss(),
  ],
  resolve: {
    alias: {
      '@': path.resolve(import.meta.dirname, './src'),
    },
  },
  optimizeDeps: {
    exclude: ['@powersync/web'],
  },
  worker: {
    format: 'es',
  },
  build: {
    rollupOptions: {
      output: {
        manualChunks(id: string) {
          if (
            id.includes('node_modules/react/') ||
            id.includes('node_modules/react-dom/') ||
            id.includes('node_modules/react-router/') ||
            id.includes('node_modules/react-router-dom/')
          ) {
            return 'vendor-react';
          }
          if (id.includes('node_modules/@supabase/')) {
            return 'vendor-supabase';
          }
        },
      },
    },
  },
  server: {
    host: '127.0.0.1',
    port: 5173,
  },
  preview: {
    host: '127.0.0.1',
    port: 4173,
    // Mismas cabeceras que en Vercel, para probar la CSP con el build real.
    headers: Object.fromEntries(
      vercelConfig.headers
        .find((h: { source: string }) => h.source === '/(.*)')
        .headers.map((h: { key: string; value: string }) => [h.key, h.value]),
    ),
  },
});
