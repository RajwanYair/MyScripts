import { defineConfig } from "vite";
import type { UserConfig } from "vite";

/**
 * Shared Vite base configuration for MyScripts workspace projects.
 * Import and spread in your project's vite.config.ts:
 *
 *   import baseConfig from '../tooling/vite.base.ts';
 *   export default defineConfig({ ...baseConfig, ... });
 */
export const baseConfig: UserConfig = {
  build: {
    target: "es2022",
    sourcemap: true,
    minify: "oxc",
    rollupOptions: {
      output: {
        manualChunks: undefined,
      },
    },
  },
  server: {
    port: 5173,
    strictPort: false,
  },
  preview: {
    port: 4173,
    strictPort: false,
  },
};

export default defineConfig(baseConfig);
