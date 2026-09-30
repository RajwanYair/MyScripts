#!/usr/bin/env node
// =============================================================================
// check-owasp.mjs — OWASP Top 10 static source scanner for web projects.
// Scans source files for common security anti-patterns (A01–A10).
//
// Usage: node scripts/check-owasp.mjs [src-dir]
// Default: src/
// =============================================================================
import { readFileSync, readdirSync, statSync } from "node:fs";
import { resolve, join, extname, relative } from "node:path";

const srcDir = resolve(process.cwd(), process.argv[2] || "src");
const EXTENSIONS = new Set([".ts", ".tsx", ".js", ".mjs", ".jsx"]);

const rules = [
  // A01: Broken Access Control
  { id: "A01", pattern: /\beval\s*\(/g, message: "eval() usage — code injection risk" },
  { id: "A01", pattern: /new\s+Function\s*\(/g, message: "new Function() — code injection risk" },
  // A02: Cryptographic Failures
  { id: "A02", pattern: /\bMath\.random\b/g, message: "Math.random() for crypto — use crypto.getRandomValues()" },
  { id: "A02", pattern: /\bmd5\b/gi, message: "MD5 usage — use SHA-256+ or BLAKE3" },
  { id: "A02", pattern: /\bsha1\b/gi, message: "SHA-1 usage — use SHA-256+" },
  // A03: Injection
  { id: "A03", pattern: /innerHTML\s*=/g, message: "innerHTML assignment — use DOMPurify or textContent" },
  { id: "A03", pattern: /outerHTML\s*=/g, message: "outerHTML assignment — use DOMPurify" },
  { id: "A03", pattern: /document\.write\s*\(/g, message: "document.write() — injection risk" },
  { id: "A03", pattern: /insertAdjacentHTML\s*\(/g, message: "insertAdjacentHTML — sanitize first" },
  // A05: Security Misconfiguration
  { id: "A05", pattern: /Access-Control-Allow-Origin.*\*/g, message: "CORS wildcard — restrict origins" },
  { id: "A05", pattern: /\"unsafe-inline\"/g, message: "CSP unsafe-inline — use nonces or hashes" },
  { id: "A05", pattern: /\"unsafe-eval\"/g, message: "CSP unsafe-eval — remove eval dependency" },
  // A07: Authentication Failures
  { id: "A07", pattern: /(?:password|secret|token|apikey|api_key)\s*[:=]\s*["'`][^"'`]+["'`]/gi, message: "Possible hardcoded credential" },
  // A08: Software and Data Integrity Failures
  { id: "A08", pattern: /<script\s+src=["']https?:\/\/[^"']+["'](?!\s+integrity)/g, message: "External script without SRI integrity attribute" },
  // A09: Security Logging Failures
  { id: "A09", pattern: /console\.(log|info|debug)\s*\([^)]*(?:password|token|secret|key)/gi, message: "Logging potentially sensitive data" },
];

function walkDir(dir) {
  const results = [];
  try {
    for (const entry of readdirSync(dir, { withFileTypes: true })) {
      const full = join(dir, entry.name);
      if (entry.isDirectory()) {
        if (["node_modules", "dist", "build", ".git", "coverage"].includes(entry.name)) continue;
        results.push(...walkDir(full));
      } else if (EXTENSIONS.has(extname(entry.name))) {
        results.push(full);
      }
    }
  } catch { /* skip inaccessible */ }
  return results;
}

let violations = 0;
const files = walkDir(srcDir);

for (const file of files) {
  const content = readFileSync(file, "utf8");
  const lines = content.split("\n");
  const relPath = relative(process.cwd(), file);

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    // Skip comments
    if (line.trimStart().startsWith("//") || line.trimStart().startsWith("*")) continue;

    for (const rule of rules) {
      rule.pattern.lastIndex = 0;
      if (rule.pattern.test(line)) {
        console.error(`  ${relPath}:${i + 1}  [${rule.id}] ${rule.message}`);
        violations++;
      }
    }
  }
}

if (violations > 0) {
  console.error(`\n\u274c  ${violations} OWASP violation(s) found in ${files.length} files`);
  process.exit(1);
} else {
  console.log(`\u2713  No OWASP violations in ${files.length} files`);
}
