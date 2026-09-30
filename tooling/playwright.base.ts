import { defineConfig, devices } from "@playwright/test";
import type { PlaywrightTestConfig } from "@playwright/test";
import os from "node:os";
import path from "node:path";

/**
 * Shared Playwright base configuration for MyScripts workspace projects.
 * Import and spread in your project's playwright.config.ts:
 *
 *   import { baseConfig } from '../tooling/playwright.base.ts';
 *   export default defineConfig({ ...baseConfig, outputDir: path.join(os.tmpdir(), 'ProjectName', 'test-results') });
 *
 * IMPORTANT: Every project MUST set its own outputDir pointing to $TEMP.
 * Example: outputDir: path.join(os.tmpdir(), 'WoodworkingShop', 'test-results')
 */
export const baseConfig: PlaywrightTestConfig = {
  /** $TEMP enforcement — override with your project name: path.join(os.tmpdir(), 'MyProject', 'test-results') */
  outputDir: path.join(os.tmpdir(), "project", "test-results"),
  testDir: "./tests/e2e",
  timeout: 30_000,
  expect: { timeout: 5_000 },
  fullyParallel: true,
  forbidOnly: !!process.env["CI"],
  retries: process.env["CI"] ? 2 : 0,
  workers: process.env["CI"] ? 1 : undefined,
  reporter: process.env["CI"] ? "github" : "list",
  use: {
    baseURL: "http://localhost:5173",
    trace: "on-first-retry",
    screenshot: "only-on-failure",
  },
  projects: [
    { name: "chromium", use: { ...devices["Desktop Chrome"] } },
    { name: "firefox", use: { ...devices["Desktop Firefox"] } },
  ],
  webServer: {
    command: "npm run dev",
    url: "http://localhost:5173",
    reuseExistingServer: !process.env["CI"],
    timeout: 30_000,
  },
};

export default defineConfig(baseConfig);
