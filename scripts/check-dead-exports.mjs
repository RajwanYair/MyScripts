#!/usr/bin/env node
// =============================================================================
// check-dead-exports.mjs — Find unused exported symbols across src/.
// Lightweight alternative to knip for quick dead-code detection.
//
// Usage: node scripts/check-dead-exports.mjs [src-dir]
// Default: src/
// =============================================================================
import { readFileSync, readdirSync } from "node:fs";
import { resolve, join, extname, relative } from "node:path";

const srcDir = resolve(process.cwd(), process.argv[2] || "src");
const EXTENSIONS = new Set([".ts", ".tsx", ".mts", ".js", ".mjs", ".jsx"]);

function walkDir(dir) {
  const results = [];
  try {
    for (const entry of readdirSync(dir, { withFileTypes: true })) {
      const full = join(dir, entry.name);
      if (entry.isDirectory()) {
        if (["node_modules", "dist", "build", "__tests__", "test"].includes(entry.name)) continue;
        results.push(...walkDir(full));
      } else if (EXTENSIONS.has(extname(entry.name))) {
        results.push(full);
      }
    }
  } catch { /* skip */ }
  return results;
}

const EXPORT_RE = /export\s+(?:function|const|let|class|type|interface|enum)\s+(\w+)/g;
const EXPORT_DEFAULT_RE = /export\s+default\s+(?:function|class)\s+(\w+)/g;

const files = walkDir(srcDir);
const allContent = new Map();

// Phase 1: collect all exports
const exports = new Map(); // symbol → file

for (const file of files) {
  const content = readFileSync(file, "utf8");
  allContent.set(file, content);

  let match;
  EXPORT_RE.lastIndex = 0;
  while ((match = EXPORT_RE.exec(content)) !== null) {
    exports.set(match[1], file);
  }
  EXPORT_DEFAULT_RE.lastIndex = 0;
  while ((match = EXPORT_DEFAULT_RE.exec(content)) !== null) {
    exports.set(match[1], file);
  }
}

// Phase 2: check which exports are referenced elsewhere
const unused = [];

for (const [symbol, defFile] of exports) {
  // Skip index files (barrel exports) and main entry
  const relDef = relative(srcDir, defFile);
  if (relDef.includes("index.")) continue;

  let found = false;
  for (const [file, content] of allContent) {
    if (file === defFile) continue;
    // Simple word-boundary check
    if (new RegExp(`\\b${symbol}\\b`).test(content)) {
      found = true;
      break;
    }
  }

  if (!found) {
    unused.push({ symbol, file: relative(process.cwd(), defFile) });
  }
}

if (unused.length > 0) {
  console.warn(`\u26a0  ${unused.length} potentially unused export(s):`);
  for (const { symbol, file } of unused.slice(0, 50)) {
    console.warn(`  ${file}: ${symbol}`);
  }
  if (unused.length > 50) {
    console.warn(`  ... and ${unused.length - 50} more`);
  }
  // Exit 0 — this is advisory, not a gate (use knip for strict enforcement)
} else {
  console.log(`\u2713  No dead exports found in ${files.length} files`);
}
