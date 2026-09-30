/**
 * Shared Vitest base configuration for MyScripts workspace projects.
 *
 * Coverage $TEMP enforcement — every project's vitest.config.ts MUST set:
 *
 *   import os from 'node:os';
 *   import { join } from 'node:path';
 *   coverage: {
 *     provider: 'v8',
 *     reportsDirectory: join(os.tmpdir(), 'ProjectName', 'coverage'),
 *     thresholds: { lines: 80, functions: 80, branches: 80, statements: 80 },
 *   }
 *
 * Example (WoodworkingShop):
 *   reportsDirectory: join(os.tmpdir(), 'WoodworkingShop', 'coverage')
 */
export const sharedVitestTestConfig = {
    environment: "happy-dom",
    globals: true,
    pool: "forks",
    maxForks: 4,
    testTimeout: 10000,
    hookTimeout: 10000,
};

/** Minimum coverage thresholds — applied per-project; adjust up as coverage improves. */
export const sharedCoverageThresholds = {
    lines: 80,
    functions: 80,
    branches: 80,
    statements: 80,
};
