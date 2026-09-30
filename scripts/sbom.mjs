#!/usr/bin/env node
// =============================================================================
// sbom.mjs — Generate CycloneDX SBOM (Software Bill of Materials).
// Generic utility for any npm project.
//
// CI:    writes sbom.json to workspace root (for upload-artifact)
// Local: writes to $TEMP/<project-name>/sbom.json
//
// Usage: node scripts/sbom.mjs [output-dir]
// =============================================================================
import { execSync } from "node:child_process";
import { mkdirSync, readFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";

const pkg = JSON.parse(readFileSync(path.resolve("package.json"), "utf8"));
const projectName = pkg.name || "project";

const isCI = process.env.CI === "true";
const outDir = process.argv[2]
  ? path.resolve(process.argv[2])
  : isCI
    ? path.resolve(".")
    : path.join(os.tmpdir(), projectName);

mkdirSync(outDir, { recursive: true });
const outFile = path.join(outDir, "sbom.json");

try {
  execSync(
    `npx --yes @cyclonedx/cyclonedx-npm@latest --output-format json --output-file "${outFile}" --package-lock-only`,
    { stdio: "inherit" },
  );
  console.log(`SBOM written to: ${outFile}`);
} catch {
  console.error("SBOM generation failed");
  process.exit(1);
}
