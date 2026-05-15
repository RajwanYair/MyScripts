/**
 * Vitest shared config for pure Node.js projects (no DOM).
 *
 * Usage:
 *   import { nodeVitestConfig } from "../tooling/vitest/node.mjs";
 *   export default defineConfig({ test: nodeVitestConfig });
 */

import { sharedVitestTestConfig } from "./base.mjs";

/**
 * Vitest test config preset for projects that run entirely in Node.js
 * (Cloudflare Workers tested via Miniflare, CLI scripts, pure TS libs, etc.).
 */
export const nodeVitestConfig = {
    ...sharedVitestTestConfig,
    environment: "node",
};
