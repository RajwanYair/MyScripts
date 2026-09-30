#!/usr/bin/env node
// =============================================================================
// lint-wrapper.mjs — ESLint with cache directed to $TEMP.
// Generic utility — reads project name from package.json.
//
// Usage: node scripts/lint-wrapper.mjs [additional-eslint-args...]
// =============================================================================
import { execSync } from "node:child_process";
import { readFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";

const pkg = JSON.parse(readFileSync(path.resolve("package.json"), "utf8"));
const projectName = pkg.name || "project";
const tempCacheDir = path.join(os.tmpdir(), projectName, ".eslintcache");

const extraArgs = process.argv.slice(2).join(" ");
const cmd = `npx eslint --cache --cache-location "${tempCacheDir}" --max-warnings 0 . ${extraArgs}`;

try {
  execSync(cmd, { stdio: "inherit" });
} catch {
  process.exit(1);
}
