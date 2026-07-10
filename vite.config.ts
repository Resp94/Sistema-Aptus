import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

import { cloudflare } from "@cloudflare/vite-plugin";

// https://vite.dev/config/
export default defineConfig({
  plugins: [react(), cloudflare()],
  server: {
    fs: {
      deny: ['**/reference/**'],
    },
  },
  // @ts-ignore
  test: {
    globals: true,
    environment: 'node',
    environmentMatchGlobs: [['src/pages/**', 'jsdom']],
    setupFiles: ['./src/test/setup-tests.ts'],
    include: ['src/**/*.{test,spec}.{ts,tsx}', 'scripts/**/*.{test,spec}.{js,mjs,ts}'],
  },
})