import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  build: {
    // Build output goes directly into wwwroot so ASP.NET can serve it
    outDir: '../dist',
    emptyDir: true,
  },
  server: {
    port: 3000,
    open: true,
    allowedHosts: true,
  },
});
