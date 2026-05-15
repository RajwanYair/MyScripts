#!/usr/bin/env node
// =============================================================================
// check-bundle-size.mjs — Enforce maximum bundle size thresholds after build.
// Generic utility for Vite-based web projects.
// Usage: node scripts/check-bundle-size.mjs [dist-dir] [max-kb]
// Default: dist/ directory, 500 KB max per chunk, 1500 KB total.
// =============================================================================
import { readdirSync, statSync } from "node:fs";
import { resolve, join, extname } from "node:path";

const distDir = resolve(process.cwd(), process.argv[2] || "dist");
const maxChunkKB = parseInt(process.argv[3] || "500", 10);
const maxTotalKB = parseInt(process.argv[4] || "1500", 10);

const JS_EXTENSIONS = new Set([".js", ".mjs"]);
const CSS_EXTENSIONS = new Set([".css"]);

function walkDir(dir) {
  const results = [];
  try {
    const entries = readdirSync(dir, { withFileTypes: true });
    for (const entry of entries) {
      const fullPath = join(dir, entry.name);
      if (entry.isDirectory()) {
        results.push(...walkDir(fullPath));
      } else {
        results.push(fullPath);
      }
    }
  } catch {
    // Directory doesn't exist
  }
  return results;
}

function formatKB(bytes) {
  return (bytes / 1024).toFixed(1);
}

const files = walkDir(distDir);
const jsFiles = files.filter((f) => JS_EXTENSIONS.has(extname(f)));
const cssFiles = files.filter((f) => CSS_EXTENSIONS.has(extname(f)));
const allBundleFiles = [...jsFiles, ...cssFiles];

if (allBundleFiles.length === 0) {
  console.error(`No JS/CSS files found in ${distDir}. Did you build first?`);
  process.exit(1);
}

let totalBytes = 0;
let errors = 0;

console.log("Bundle Size Report");
console.log("=".repeat(60));

for (const file of allBundleFiles) {
  const size = statSync(file).size;
  const sizeKB = size / 1024;
  totalBytes += size;

  const relPath = file.replace(distDir + "/", "").replace(distDir + "\\", "");
  const status = sizeKB > maxChunkKB ? "OVER" : "OK";
  const marker = status === "OVER" ? "❌" : "✅";

  console.log(`${marker} ${formatKB(size).padStart(8)} KB  ${relPath}`);

  if (status === "OVER") {
    errors++;
  }
}

console.log("=".repeat(60));
const totalKB = totalBytes / 1024;
const totalStatus = totalKB > maxTotalKB ? "❌ OVER" : "✅ OK";
console.log(`${totalStatus}  Total: ${formatKB(totalBytes)} KB (max: ${maxTotalKB} KB)`);
console.log(`       Chunks: ${allBundleFiles.length} (max per chunk: ${maxChunkKB} KB)`);

if (errors > 0 || totalKB > maxTotalKB) {
  console.error(`\nBundle size check FAILED.`);
  process.exit(1);
} else {
  console.log(`\nBundle size check passed.`);
}
