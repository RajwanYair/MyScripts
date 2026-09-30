---
mode: agent
tools:
  - read_file
  - create_file
  - replace_string_in_file
  - multi_replace_string_in_file
  - run_in_terminal
  - get_errors
  - grep_search
  - semantic_search
description: >
  Scaffold a complete new feature for a TypeScript/React SPA — engine module,
  store slice, React panel, i18n keys, unit tests, and mounting.
---

# Web Feature Agent — MyScripts Workspace

You are the **web feature agent** for TypeScript/React SPA projects in this workspace.
Use the active SPA project as the canonical implementation for local patterns.

## Input

Implement feature **`${featureName}`** in `${projectPath}`: ${description}

## Architecture layers

### 1 — Engine (`src/engine/${feature}.ts`)

- Pure TypeScript — no React, no DOM, no side effects
- Named exports only (no default exports)
- JSDoc on every exported function
- RangeError guards for invalid inputs
- ≤ 300 lines

### 2 — Store slice (`src/store/slices/${feature}-slice.ts`)

```ts
export interface ${Feature}Slice { /* state */ }
export const create${Feature}Slice = (set): ${Feature}Slice => ({
  /* initial state + setters */
});
```

Register in main store.

### 3 — Component (`src/components/${tab}/${Feature}Panel.tsx`)

- Named export only
- Tailwind logical properties (`ms-*`, `me-*`, `ps-*`, `pe-*`)
- `wood-*` design tokens for colours
- ARIA live regions for dynamic content
- ≤ 600 lines; helpers → sibling `.ts`

### 4 — i18n

Add under `${feature}.*` namespace to BOTH locale files. Run `npm run i18n:coverage`.

### 5 — Mount

Import and render in the appropriate parent panel.

### 6 — Tests (`tests/engine/${feature}.test.ts`)

- `it.each` for parametrised cases
- `cfg()` helper for config fixtures
- ≥ 10 test cases, ≤ 400 lines

## Quality gates

```bash
npm run quality   # 0 errors
npm test          # all pass
npm run dead:check # 0 orphaned
```
