#!/usr/bin/env node
// =============================================================================
// lint-css-wrapper.mjs — Stylelint with cache directed to $TEMP.
// Generic utility — reads project name from package.json.
//
// Usage: node scripts/lint-css-wrapper.mjs [glob-pattern]
// Default: "src/**/*.css"
// =============================================================================
import { execSync } from "node:child_process";
import { readFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";

const pkg = JSON.parse(readFileSync(path.resolve("package.json"), "utf8"));
const projectName = pkg.name || "project";
const tempCacheDir = path.join(os.tmpdir(), projectName, ".stylelintcache");

const pattern = process.argv[2] || '"src/**/*.css"';
const cmd = `npx stylelint --cache --cache-location "${tempCacheDir}" --max-warnings 0 ${pattern}`;

try {
  execSync(cmd, { stdio: "inherit" });
} catch {
  process.exit(1);
}
