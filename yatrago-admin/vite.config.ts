import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/vite';

// The admin panel talks to the NestJS API. In dev we proxy both the API
// (/api/v1) and uploaded verification documents (/uploads) to the backend
// so the browser never hits CORS and doc URLs resolve locally.
const API_TARGET = process.env.VITE_API_TARGET ?? 'http://localhost:3000';

export default defineConfig({
  plugins: [react(), tailwindcss()],
  server: {
    port: 5174,
    proxy: {
      '/api': { target: API_TARGET, changeOrigin: true },
      '/uploads': { target: API_TARGET, changeOrigin: true },
    },
  },
});
