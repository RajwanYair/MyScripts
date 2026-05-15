#!/usr/bin/env node
// =============================================================================
// validate-mermaid.mjs — Validate Mermaid diagram syntax in Markdown files
// Generic utility for use in CI/CD pipelines and pre-commit hooks.
// Usage: node scripts/validate-mermaid.mjs [glob-pattern]
// Default: validates all .md files in the workspace.
// =============================================================================
import { readFileSync, existsSync } from "node:fs";
import { glob } from "node:fs/promises";
import { resolve } from "node:path";

const pattern = process.argv[2] || "**/*.md";
const cwd = process.cwd();
const excludeDirs = ["node_modules", "dist", "build", "coverage", ".git", "external"];

const MERMAID_FENCE_RE = /^```mermaid\s*$/gm;
const FENCE_END_RE = /^```\s*$/gm;

// Basic syntax checks for common mermaid diagram types
const VALID_STARTS = [
  /^\s*(graph|flowchart)\s+(TD|TB|BT|RL|LR)/,
  /^\s*sequenceDiagram/,
  /^\s*classDiagram/,
  /^\s*stateDiagram/,
  /^\s*erDiagram/,
  /^\s*gantt/,
  /^\s*pie/,
  /^\s*gitGraph/,
  /^\s*mindmap/,
  /^\s*timeline/,
  /^\s*journey/,
  /^\s*quadrantChart/,
  /^\s*xychart-beta/,
  /^\s*%%/,
];

let errors = 0;
let checked = 0;

async function findMarkdownFiles() {
  const files = [];
  for await (const entry of glob(pattern, { cwd, exclude: excludeDirs })) {
    if (entry.endsWith(".md")) {
      files.push(resolve(cwd, entry));
    }
  }
  return files;
}

function extractMermaidBlocks(content) {
  const blocks = [];
  const lines = content.split("\n");
  let inBlock = false;
  let blockStart = 0;
  let blockLines = [];

  for (let i = 0; i < lines.length; i++) {
    if (!inBlock && /^```mermaid\s*$/.test(lines[i])) {
      inBlock = true;
      blockStart = i + 1;
      blockLines = [];
    } else if (inBlock && /^```\s*$/.test(lines[i])) {
      blocks.push({ start: blockStart, content: blockLines.join("\n") });
      inBlock = false;
      blockLines = [];
    } else if (inBlock) {
      blockLines.push(lines[i]);
    }
  }

  if (inBlock) {
    blocks.push({ start: blockStart, content: blockLines.join("\n"), unclosed: true });
  }

  return blocks;
}

function validateBlock(block) {
  if (block.unclosed) {
    return "Unclosed mermaid code fence";
  }

  const trimmed = block.content.trim();
  if (!trimmed) {
    return "Empty mermaid block";
  }

  const hasValidStart = VALID_STARTS.some((re) => re.test(trimmed));
  if (!hasValidStart) {
    return `Unrecognized mermaid diagram type: "${trimmed.split("\n")[0].substring(0, 40)}..."`;
  }

  return null;
}

async function main() {
  const files = await findMarkdownFiles();

  for (const file of files) {
    const content = readFileSync(file, "utf8");
    const blocks = extractMermaidBlocks(content);

    for (const block of blocks) {
      checked++;
      const error = validateBlock(block);
      if (error) {
        const relPath = file.replace(cwd + "/", "").replace(cwd + "\\", "");
        console.error(`ERROR: ${relPath}:${block.start} — ${error}`);
        errors++;
      }
    }
  }

  console.log(`\nChecked ${checked} mermaid block(s) in ${files.length} file(s).`);

  if (errors > 0) {
    console.error(`\n${errors} error(s) found.`);
    process.exit(1);
  } else {
    console.log("All mermaid blocks pass basic validation.");
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
