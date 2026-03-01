import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/vite';
import electron from 'vite-plugin-electron';
import path from 'path';

export default defineConfig({
  plugins: [
    react(),
    tailwindcss(),
    electron([
      {
        entry: 'electron/main.ts',
        onstart(args) {
          // VS Code sets ELECTRON_RUN_AS_NODE=1 which disables Electron APIs.
          // Delete it from the spawned Electron process env.
          const cleanEnv = { ...process.env };
          delete cleanEnv.ELECTRON_RUN_AS_NODE;
          args.startup(['.', '--no-sandbox'], { env: cleanEnv });
        },
        vite: {
          build: {
            outDir: 'dist-electron',
            rollupOptions: {
              external: ['electron'],
            },
          },
        },
      },
      {
        entry: 'electron/preload.ts',
        onstart(args) {
          args.reload();
        },
        vite: {
          build: {
            outDir: 'dist-electron',
            rollupOptions: {
              external: ['electron'],
            },
          },
        },
      },
    ]),
  ],
  base: './',
  resolve: {
    alias: {
      '@': path.resolve(__dirname, 'src'),
    },
  },
  build: {
    outDir: 'dist',
    emptyOutDir: true,
  },
  server: {
    port: 5173,
    strictPort: true,
  },
});
