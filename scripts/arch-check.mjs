#!/usr/bin/env node
// =============================================================================
// arch-check.mjs — Layer architecture enforcement for TypeScript projects.
// Ensures imports respect a defined layer hierarchy (no upward imports).
//
// Usage: node scripts/arch-check.mjs [src-dir]
// Default: src/
//
// Configure layers in the LAYERS array below (ordered from lowest to highest).
// A layer may import from layers at its level or below, but NEVER above.
// =============================================================================
import { readFileSync, readdirSync, statSync } from "node:fs";
import { resolve, join, extname, relative, dirname, sep } from "node:path";

const srcDir = resolve(process.cwd(), process.argv[2] || "src");

// Layer hierarchy: index 0 = lowest (can be imported by all), last = highest
// Customize per project. Common pattern:
//   types → domain/engine → core/services → ui/components → pages/app
const LAYERS = [
  "types",      // Pure types, no runtime
  "engine",     // Pure computation, no DOM/React
  "domain",     // Domain models
  "core",       // Core services
  "utils",      // Shared utilities
  "hooks",      // React hooks
  "components", // React components
  "pages",      // Page-level components
  "app",        // App shell
];

function getLayer(filePath) {
  const rel = relative(srcDir, filePath).split(sep);
  for (let i = 0; i < rel.length; i++) {
    const idx = LAYERS.indexOf(rel[i]);
    if (idx !== -1) return { name: rel[i], level: idx };
  }
  return null;
}

const IMPORT_RE = /(?:^|\n)\s*import\s+(?:[\s\S]*?)\s+from\s+['"]([^'"]+)['"]/g;
const EXTENSIONS = new Set([".ts", ".tsx", ".mts"]);

function walkDir(dir) {
  const results = [];
  try {
    for (const entry of readdirSync(dir, { withFileTypes: true })) {
      const full = join(dir, entry.name);
      if (entry.isDirectory()) {
        if (["node_modules", "dist", "build", "__tests__"].includes(entry.name)) continue;
        results.push(...walkDir(full));
      } else if (EXTENSIONS.has(extname(entry.name))) {
        results.push(full);
      }
    }
  } catch { /* skip */ }
  return results;
}

let violations = 0;
const files = walkDir(srcDir);

for (const file of files) {
  const sourceLayer = getLayer(file);
  if (!sourceLayer) continue;

  const content = readFileSync(file, "utf8");
  let match;
  IMPORT_RE.lastIndex = 0;

  while ((match = IMPORT_RE.exec(content)) !== null) {
    const importPath = match[1];
    // Only check relative imports
    if (!importPath.startsWith(".")) continue;

    const resolvedImport = resolve(dirname(file), importPath);
    const targetLayer = getLayer(resolvedImport);
    if (!targetLayer) continue;

    if (targetLayer.level > sourceLayer.level) {
      const relFile = relative(process.cwd(), file);
      console.error(
        `  ${relFile}: "${sourceLayer.name}" (L${sourceLayer.level}) imports from "${targetLayer.name}" (L${targetLayer.level}) — forbidden upward import`,
      );
      violations++;
    }
  }
}

if (violations > 0) {
  console.error(`\n\u274c  ${violations} architecture violation(s) found`);
  process.exit(1);
} else {
  console.log(`\u2713  Architecture check passed — ${files.length} files, ${LAYERS.length} layers`);
}
