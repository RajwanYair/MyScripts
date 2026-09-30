import { defineConfig } from "vite";
import { resolve } from "node:path";
import os from "node:os";
import baseConfig from "../tooling/vite.base.ts";

// =============================================================================
// Vite config template for new web projects.
// Replace <PROJECT_NAME> with your project name.
// Replace <REPO_NAME> with the actual GitHub repository name.
// =============================================================================
export default defineConfig({
  ...baseConfig,
  base: "./<REPO_NAME>/",
  cacheDir: resolve(os.tmpdir(), "<PROJECT_NAME>", ".vite_cache"),
  build: {
    ...baseConfig.build,
    outDir: "dist",
    rollupOptions: {
      output: {
        manualChunks: (id) => {
          if (id.includes("react-dom") || id.includes("/node_modules/react/") || id.includes("zustand"))
            return "vendor";
          if (id.includes("/i18next") || id.includes("/react-i18next"))
            return "i18n-vendor";
          return undefined;
        },
      },
    },
  },
});
