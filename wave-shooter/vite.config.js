import { defineConfig } from 'vite';

// base './' so the built bundle works from any static path (itch.io, GH pages, etc.)
export default defineConfig({
  base: './',
  build: {
    target: 'es2020',
    chunkSizeWarningLimit: 2000
  },
  server: {
    host: true
  }
});
