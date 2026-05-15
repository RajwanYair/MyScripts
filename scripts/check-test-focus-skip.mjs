#!/usr/bin/env node
// =============================================================================
// check-test-focus-skip.mjs — Prevent .only/.skip from being committed in tests.
// Generic utility for pre-commit or CI.
// Usage: node scripts/check-test-focus-skip.mjs [glob-pattern]
// Default: checks tests/**/*.{ts,js,mts,mjs}
// =============================================================================
import { readFileSync } from "node:fs";
import { glob } from "node:fs/promises";
import { resolve } from "node:path";

const pattern = process.argv[2] || "tests/**/*.{ts,js,mts,mjs}";
const cwd = process.cwd();

const FORBIDDEN_PATTERNS = [
  { re: /\b(describe|it|test)\.only\b/g, label: ".only" },
  { re: /\b(describe|it|test)\.skip\b/g, label: ".skip" },
  { re: /\bfdescribe\b/g, label: "fdescribe" },
  { re: /\bfit\b/g, label: "fit (focused test)" },
  { re: /\bxdescribe\b/g, label: "xdescribe" },
  { re: /\bxit\b/g, label: "xit" },
];

let violations = 0;

async function main() {
  const files = [];
  for await (const entry of glob(pattern, { cwd, exclude: ["node_modules"] })) {
    files.push(resolve(cwd, entry));
  }

  for (const file of files) {
    const content = readFileSync(file, "utf8");
    const lines = content.split("\n");

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];
      // Skip comments
      if (line.trimStart().startsWith("//") || line.trimStart().startsWith("*")) continue;

      for (const { re, label } of FORBIDDEN_PATTERNS) {
        re.lastIndex = 0;
        if (re.test(line)) {
          const relPath = file.replace(cwd + "/", "").replace(cwd + "\\", "");
          console.error(`${relPath}:${i + 1} — Found "${label}"`);
          violations++;
        }
      }
    }
  }

  if (violations > 0) {
    console.error(`\n${violations} focus/skip violation(s) found. Remove before committing.`);
    process.exit(1);
  } else {
    console.log(`Checked ${files.length} test file(s) — no .only/.skip found.`);
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
