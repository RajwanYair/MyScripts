import { defineConfig } from "vite";
import baseConfig from "../tooling/vite.base.ts";

// =============================================================================
// Vite config template for new web projects.
// Replace <REPO_NAME> with the actual GitHub repository name.
// =============================================================================
export default defineConfig({
  ...baseConfig,
  base: "./<REPO_NAME>/",
  build: {
    ...baseConfig.build,
    outDir: "dist",
  },
});
