---
applyTo: "**/src/**/*.{ts,tsx},**/tests/**/*.{ts,tsx},**/vite.config.ts,**/vitest.config.ts,**/playwright.config.ts,**/eslint.config.*,**/tsconfig*.json"
---

# React / TypeScript SPA Instructions

> Reference implementation: use the active React SPA sub-project as the local pattern reference.
> These patterns are battle-tested and enforced by CI. Apply them to every TypeScript SPA in this workspace.

## Zero-Suppression Rule

No exceptions. Fix the root cause instead.

- No `eslint-disable` comments of any kind
- No `@ts-ignore` or `@ts-nocheck`
- No `as any` or `as unknown as T` without a type guard function
- No `// @ts-expect-error`

## TypeScript 6 Strictness

```jsonc
// tsconfig.app.json compilerOptions — production baseline
{
  "target": "ESNext",
  "module": "esnext",
  "moduleResolution": "bundler",
  "verbatimModuleSyntax": true,
  "strict": true,
  "erasableSyntaxOnly": true, // no enum, no namespace, no const enum
  "noUnusedLocals": true,
  "noUnusedParameters": true,
  "noImplicitOverride": true,
  "allowUnreachableCode": false,
  "allowUnusedLabels": false,
  "noFallthroughCasesInSwitch": true,
  "forceConsistentCasingInFileNames": true,
}
```

**`erasableSyntaxOnly` means:**

```ts
// ❌ Forbidden
enum Direction { Left, Right }
namespace Helpers { … }
const enum Color { Red = 0 }

// ✅ Use instead
const Direction = { Left: 'left', Right: 'right' } as const;
type Direction = typeof Direction[keyof typeof Direction];
```

## Engine Purity Rule

Files in `src/engine/` (or equivalent pure-TS computation layer) **must not** import React, DOM APIs, or store state. They are pure TypeScript — tested directly, re-usable in workers and Node.

```ts
// ❌ Engine file importing React
import { useState } from "react";

// ✅ Engine file — pure computation only
export function computeArea(width: number, height: number): number {
  return width * height;
}
```

## react-refresh Rule

Component files (`src/components/**/*.tsx`) must export **only** React components. Extract utilities to sibling `.ts` files.

```ts
// ❌ Wrong — mixing component and non-component exports
export function formatDate(d: Date) { … }
export function MyCard() { … }

// ✅ Correct — utility in sibling file
// src/components/feature/format-date.ts
export function formatDate(d: Date) { … }
// src/components/feature/MyCard.tsx
import { formatDate } from './format-date';
export function MyCard() { … }
```

## State Management (Zustand 5)

```ts
// Reading state
const { config, items } = useAppStore();

// Writing state — always spread full slice
set((s) => ({ ...s, config: { ...s.config, width } }));

// Outside React (workers, tests, imperative code)
useAppStore.getState().setConfig({ width: 800 });
```

Large stores use slices:

```ts
// store/slices/ui-slice.ts
export type UiSlice = { sidebarOpen: boolean; toggleSidebar: () => void };
export const createUiSlice = (set): UiSlice => ({
  sidebarOpen: true,
  toggleSidebar: () => set((s) => ({ ...s, sidebarOpen: !s.sidebarOpen })),
});
```

## i18n Parity Rule

Every `t('key')` call needs an entry in **both** `en.json` **and** `he.json` in the same commit. For other locales, copy the English value as a placeholder.

```tsx
const { t } = useTranslation();
// Key must exist in en.json + he.json
<label>{t("config.width")}</label>;
```

Run `npm run i18n:coverage` to verify 100% parity before commit.

## RTL-Safe Layout

Use Tailwind CSS v4 logical properties — never physical direction classes.

```tsx
// ❌ Physical direction — breaks RTL (Arabic/Hebrew)
<div className="ml-4 pl-2 text-left">

// ✅ Logical properties — works in LTR and RTL
<div className="ms-4 ps-2 text-start">
```

Logical property map: `ms-*` = margin-start, `me-*` = margin-end, `ps-*` = padding-start, `pe-*` = padding-end, `start-*`/`end-*` for inset positioning.

## ARIA Patterns (jsx-a11y enforced)

```tsx
// ❌ Redundant roles on semantic elements
<ul role="list"><li role="listitem">

// ✅ Semantic HTML — roles implicit
<ul><li>

// ❌ Keyboard handler on non-interactive div
<div onKeyDown={handler}>

// ✅ Use a button or role="button" with keyboard support
<button onClick={handler} onKeyDown={...}>
```

## $TEMP Enforcement

All intermediate artifacts must go to the OS temp directory. Nothing in `dist/`, `coverage/`, or workspace root after a build.

```ts
// vitest.config.ts — coverage to $TEMP
import os from 'node:os';
import path from 'node:path';
const tmpDir = path.join(os.tmpdir(), 'ProjectName');
coverage: { reportsDirectory: path.join(tmpDir, 'coverage') }

// playwright.config.ts — test results to $TEMP
outputDir: path.join(os.tmpdir(), 'ProjectName', 'test-results'),

// scripts/lint.js — ESLint cache to $TEMP
execSync(`npx eslint --cache --cache-location "${path.join(os.tmpdir(), 'ProjectName', '.eslintcache')}" …`)

// vite.config.ts — build cache to $TEMP
cacheDir: resolve(os.tmpdir(), 'ProjectName', '.vite_cache'),
```

## Quality Gate Scripts

Every production SPA needs these npm scripts:

```jsonc
{
  "scripts": {
    "dev": "vite",
    "prebuild": "node scripts/sync-sw-version.js", // optional: PWA version sync
    "build": "tsc -b && vite build",
    "preview": "vite preview",
    "clean": "rimraf dist",
    "test": "vitest run",
    "test:watch": "vitest",
    "test:coverage": "vitest run --coverage",
    "test:e2e": "playwright test",
    "lint": "node scripts/lint.js", // ESLint → $TEMP cache
    "lint:css": "node scripts/lint-css.js", // Stylelint → $TEMP cache
    "lint:md": "markdownlint-cli2 \"*.md\" \"docs/**/*.md\"",
    "format": "prettier --write .",
    "format:check": "prettier --check .",
    "typecheck": "tsc -b --noEmit",
    "i18n:coverage": "node scripts/i18n-coverage.js", // for i18n apps
    "bundle:check": "node scripts/bundle-report.js", // budget enforcement
    "dead:check": "knip",
    "quality": "npm run typecheck && npm run lint && npm run lint:css && npm run lint:md && npm run format:check",
    "quality:fast": "node scripts/parallel-quality.js",
    "check": "npm run quality:fast && npm run test",
    "ci": "npm run check && npm run build && npm run bundle:check",
  },
}
```

## ESLint Flat Config (7 plugins)

```js
// eslint.config.js
import js from "@eslint/js";
import tseslint from "typescript-eslint";
import reactHooks from "eslint-plugin-react-hooks";
import reactRefresh from "eslint-plugin-react-refresh";
import react from "eslint-plugin-react";
import jsxA11y from "eslint-plugin-jsx-a11y";
import regexp from "eslint-plugin-regexp";
import testingLibrary from "eslint-plugin-testing-library";
import noOnlyTests from "eslint-plugin-no-only-tests";
import eslintConfigPrettier from "eslint-config-prettier";

export default defineConfig([
  globalIgnores(["dist", "coverage"]),
  {
    files: ["**/*.{ts,tsx}"],
    extends: [
      js.configs.recommended,
      tseslint.configs.recommended,
      reactRefresh.configs.vite,
      jsxA11y.flatConfigs.recommended,
      react.configs.flat.recommended,
      react.configs.flat["jsx-runtime"],
      regexp.configs["flat/recommended"],
    ],
    plugins: { "react-hooks": reactHooks },
    rules: {
      "@typescript-eslint/no-unused-vars": ["error", { argsIgnorePattern: "^_" }],
      "react-hooks/rules-of-hooks": "error",
      "react-hooks/exhaustive-deps": "warn",
      "react/prop-types": "off",
    },
  },
  {
    files: ["tests/**/*.{ts,tsx}"],
    plugins: { "testing-library": testingLibrary, "no-only-tests": noOnlyTests },
    rules: {
      ...testingLibrary.configs["flat/react"].rules,
      "no-only-tests/no-only-tests": "error",
    },
  },
  eslintConfigPrettier,
]);
```

Forbidden plugins (not in use, do not add): `sonarjs`, `promise`.

## Vite Chunk Strategy

```ts
// vite.config.ts — manualChunks for caching efficiency
manualChunks: (id) => {
  if (id.includes('react-dom') || id.includes('/node_modules/react/') || id.includes('zustand'))
    return 'vendor';
  if (id.includes('/i18next') || id.includes('/react-i18next'))
    return 'i18n-vendor';
  // Heavy optional deps get their own lazy chunk:
  // if (id.includes('heavy-lib')) return 'heavy-lib';
},
```

## Bundle Budget

Create `config/bundle-budget.json` and enforce via `scripts/bundle-report.js`:

```jsonc
{
  "totalJsKB": 1800,
  "totalCssKB": 60,
  "totalDistKB": 3000,
  "perFileKB": {
    "vendor": 300,
    "i18n-vendor": 80,
    "_default": 500,
  },
}
```

## Knip Dead Code

```jsonc
// package.json — "knip" section
{
  "knip": {
    "entry": ["src/main.tsx!", "src/engine/index.ts!"],
    "project": ["src/**/*.{ts,tsx}", "tests/**/*.{ts,tsx}"],
    "ignore": ["src/env.d.ts"],
  },
}
```

Run `npm run dead:check` before every release. Zero dead exports.

## Testing Conventions

```ts
// Use it.each for parametrized pairs — not one expect per it()
it.each([
  [{ width: 0 }, "width must be positive"],
  [{ depth: -1 }, "depth must be positive"],
])("validates %o → %s", (overrides, expected) => {
  const result = validate(cfg(overrides));
  expect(result.ok).toBe(false);
  expect(result.error).toContain(expected);
});

// Group related assertions in one it()
it("generates correct part count for standard cabinet", () => {
  const parts = generateParts(cfg());
  expect(parts).toHaveLength(12);
  expect(parts.every((p) => p.label)).toBe(true);
  expect(parts.some((p) => p.label === "Back Panel")).toBe(true);
});
```

## Composite GitHub Action Pattern

Reuse checkout + setup-node across workflows:

```yaml
# .github/actions/setup-node/action.yml
name: "Setup Node"
description: "Checkout + setup Node.js + npm ci"
runs:
  using: composite
  steps:
    - uses: actions/checkout@v4
    - uses: actions/setup-node@v4
      with:
        node-version-file: .nvmrc
        cache: npm
    - run: npm ci
      shell: bash
```

Reference from any workflow step:

```yaml
- uses: ./.github/actions/setup-node
```

## Security Baseline

Every SPA must have:

- `.gitleaks.toml` — prevent secret commits
- `.github/workflows/secret-scan.yml` — CI secret scanning
- `.github/workflows/codeql.yml` — CodeQL static analysis
- `scripts/sbom.js` — Software Bill of Materials generation
- No hardcoded tokens, API keys, or credentials anywhere in source

## PWA Pattern (optional, for offline-capable apps)

```ts
VitePWA({
  registerType: "prompt", // always require user consent
  strategies: "generateSW",
  injectRegister: false, // manual SW registration in main.tsx
  manifest: false, // keep public/manifest.json
  workbox: {
    skipWaiting: false, // never auto-activate without user action
    clientsClaim: false,
    globPatterns: ["**/*.{js,css,html,svg,png,woff2}"],
  },
});
```

## MCP Server Configuration

Every SPA workspace should configure these MCP servers in `.vscode/mcp.json`:

```jsonc
{
  "servers": {
    // Official GitHub MCP — PRs, issues, Actions workflows, code search
    "github": {
      "type": "http",
      "url": "https://api.githubcopilot.com/mcp/",
    },
    // Workspace file access (exclude heavy dirs)
    "filesystem": {
      "type": "stdio",
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-filesystem@2026.8.31",
        "${workspaceFolder}"
      ],
    },
    // Web content fetch for docs and API reference
    "fetch": {
      "type": "stdio",
      "command": "uvx",
      "args": ["mcp-server-fetch==2026.8.18"],
    },
    // Browser automation for E2E debugging in chat
    "playwright": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@playwright/mcp@0.0.79"],
    },
    // Isolated browser debugging with usage statistics disabled
    "chrome-devtools": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "chrome-devtools-mcp@1.10.1", "--isolated", "--no-usage-statistics"],
    },
    // GitKraken — git blame, log, diff, PR workflow
    "gitkraken": {
      "type": "http",
      "url": "https://mcp.gitkraken.com/mcp",
    },
  },
}
```

## Copilot Instruction Files

Every SPA workspace should have these `applyTo`-scoped instruction files in `.github/instructions/`:

| File                         | `applyTo` pattern         | Purpose                                             |
| ---------------------------- | ------------------------- | --------------------------------------------------- |
| `engine.instructions.md`     | `src/engine/**`           | Pure TS rules, coordinate system, RangeError guards |
| `components.instructions.md` | `src/components/**/*.tsx` | RTL, ARIA, i18n, Tailwind, size limits              |
| `store.instructions.md`      | `src/store/**`            | Zustand slice pattern, selectors, no side effects   |
| `tests.instructions.md`      | `tests/**`                | it.each, helpers, coverage targets                  |
| `i18n.instructions.md`       | `src/i18n/**,src/**`      | Parity rule, key naming, verification               |

## Dependabot Auto-Merge

Add `.github/workflows/dependabot-auto-merge.yml` to auto-merge patch/minor updates:

```yaml
on: { pull_request: { branches: [main] } }
permissions: { contents: write, pull-requests: write }
jobs:
  auto-merge:
    if: github.actor == 'dependabot[bot]'
    runs-on: ubuntu-latest
    steps:
      - uses: dependabot/fetch-metadata@v2
        id: meta
        with: { github-token: "${{ secrets.GITHUB_TOKEN }}" }
      - if: >
          steps.meta.outputs.update-type == 'version-update:semver-patch' ||
          steps.meta.outputs.update-type == 'version-update:semver-minor'
        run: gh pr merge --auto --squash "$PR_URL"
        env:
          PR_URL: ${{ github.event.pull_request.html_url }}
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## Node.js Version Baseline

Default Node: **24** (LTS). Test matrix: `[24, 26]`. Update `setup-node` composite action default to `24`.
Set `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: true` in workflow `env` to suppress deprecation warnings.
