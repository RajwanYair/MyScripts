#!/usr/bin/env node
// =============================================================================
// parallel-quality.mjs — Run all quality checks concurrently.
// Generic utility for any web project. Buffers output and only prints failures.
//
// Usage: node scripts/parallel-quality.mjs [check1 check2 ...]
// Default checks: typecheck lint lint:css lint:md format:check
// =============================================================================
import { exec } from "node:child_process";

const defaultChecks = ["typecheck", "lint", "lint:css", "lint:md", "format:check"];
const checks = process.argv.length > 2 ? process.argv.slice(2) : defaultChecks;

const results = await Promise.all(
  checks.map(
    (name) =>
      new Promise((resolve) => {
        const start = Date.now();
        exec(`npm run ${name}`, { maxBuffer: 10 * 1024 * 1024 }, (error, stdout, stderr) => {
          resolve({ name, code: error?.code ?? 0, output: stdout + stderr, ms: Date.now() - start });
        });
      }),
  ),
);

const failed = results.filter((r) => r.code !== 0);
const passed = results.filter((r) => r.code === 0);

for (const { name, ms } of passed) {
  console.log(`  \u2713  ${name} (${ms}ms)`);
}

if (failed.length > 0) {
  for (const { name, output, ms } of failed) {
    process.stderr.write(`\n${"─".repeat(60)}\n\u274c  ${name} FAILED (${ms}ms)\n${"─".repeat(60)}\n`);
    process.stderr.write(output);
  }
  process.exit(1);
}

console.log(`\n\u2713  All ${checks.length} quality checks passed`);
