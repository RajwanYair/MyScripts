import { defineConfig } from "vite";
import type { UserConfig } from "vite";
import os from "node:os";
import { resolve } from "node:path";

/**
 * Shared Vite base configuration for MyScripts workspace projects.
 * Import and spread in your project's vite.config.ts:
 *
 *   import baseConfig from '../tooling/vite.base.ts';
 *   export default defineConfig({ ...baseConfig, cacheDir: resolve(os.tmpdir(), 'ProjectName', '.vite_cache') });
 *
 * IMPORTANT: Every project MUST set its own cacheDir pointing to $TEMP.
 * Do NOT rely on the default .vite/ inside the project dir.
 * Example: cacheDir: resolve(os.tmpdir(), 'WoodworkingShop', '.vite_cache')
 */
export const baseConfig: UserConfig = {
  /** $TEMP enforcement — override with your project name: resolve(os.tmpdir(), 'MyProject', '.vite_cache') */
  cacheDir: resolve(os.tmpdir(), "project", ".vite_cache"),
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
