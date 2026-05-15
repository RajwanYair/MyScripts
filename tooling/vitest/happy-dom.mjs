/**
 * Vitest shared config for browser-like projects using happy-dom.
 *
 * Usage:
 *   import { happyDomVitestConfig } from "../tooling/vitest/happy-dom.mjs";
 *   export default defineConfig({ test: happyDomVitestConfig });
 */

import { sharedVitestTestConfig } from "./base.mjs";

/**
 * Vitest test config preset for projects that simulate a browser DOM via
 * happy-dom (components, UI helpers, card loaders, etc.).
 */
export const happyDomVitestConfig = {
    ...sharedVitestTestConfig,
    environment: "happy-dom",
};
