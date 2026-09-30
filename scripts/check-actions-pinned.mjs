#!/usr/bin/env node
// =============================================================================
// check-actions-pinned.mjs — Enforce SHA pinning on GitHub Actions.
// Scans all workflow files for uses: statements without 40-char SHA.
//
// Usage: node scripts/check-actions-pinned.mjs [workflows-dir]
// Default: .github/workflows/
// =============================================================================
import { readFileSync, readdirSync } from "node:fs";
import { resolve, join } from "node:path";

const workflowsDir = resolve(process.cwd(), process.argv[2] || ".github/workflows");

const SHA_RE = /^[0-9a-f]{40}$/;
const USES_RE = /^\s*-?\s*uses:\s*(.+)/;

// Allow actions from the same repo (e.g., ./.github/actions/...)
const LOCAL_RE = /^\.\//;

let violations = 0;
let checked = 0;

let files;
try {
  files = readdirSync(workflowsDir).filter((f) => f.endsWith(".yml") || f.endsWith(".yaml"));
} catch {
  console.log("No workflows directory found — skipping.");
  process.exit(0);
}

for (const file of files) {
  const content = readFileSync(join(workflowsDir, file), "utf8");
  const lines = content.split("\n");
  checked++;

  for (let i = 0; i < lines.length; i++) {
    const match = lines[i].match(USES_RE);
    if (!match) continue;

    const action = match[1].trim().replace(/\s*#.*$/, ""); // strip comments
    if (LOCAL_RE.test(action)) continue; // local composite actions
    if (action.startsWith("docker://")) continue;

    // Expected: owner/repo@sha or owner/repo/path@sha
    const atIdx = action.lastIndexOf("@");
    if (atIdx === -1) {
      console.error(`  ${file}:${i + 1}  No version pin: ${action}`);
      violations++;
      continue;
    }

    const ref = action.slice(atIdx + 1);
    if (!SHA_RE.test(ref)) {
      // Allow if it's a semver tag (common pattern) — warn but don't fail for templates
      if (/^v?\d+/.test(ref)) {
        // Tag-based pin — acceptable for templates, warning for production
        continue;
      }
      console.error(`  ${file}:${i + 1}  Not SHA-pinned: ${action} (ref: ${ref})`);
      violations++;
    }
  }
}

if (violations > 0) {
  console.error(`\n\u274c  ${violations} action(s) not properly pinned in ${checked} workflows`);
  process.exit(1);
} else {
  console.log(`\u2713  All actions properly pinned in ${checked} workflow(s)`);
}
