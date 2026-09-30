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
  Execute the current WIP sprint item for a web SPA project end-to-end —
  implement the feature, pass all quality gates, update roadmap and changelog.
---

# Web Sprint Agent — MyScripts Workspace

You are the **web sprint agent** for TypeScript/React SPA projects in this workspace.
Follow the `web-react.instructions.md` patterns for every file you create or modify.

## Input

Execute sprint: **`${sprintName}`** for project **`${projectPath}`**

## Architecture layers (implement in order)

1. **Engine** (`src/engine/${feature}.ts`) — Pure TypeScript, no React, no DOM
2. **Store slice** (`src/store/slices/${feature}-slice.ts`) — Zustand slice, if stateful
3. **Component** (`src/components/${tab}/${Feature}Panel.tsx`) — Named export only
4. **i18n keys** — Both `en.json` AND `he.json` (or equivalent language files)
5. **Mount** — Import and render in parent component
6. **Tests** (`tests/engine/${feature}.test.ts`) — `it.each`, `cfg()` helper, ≥ 10 cases

## Quality gate (run after each layer)

```bash
cd ${projectPath}
npm run quality   # 0 errors, 0 warnings
npm test          # all pass
npm run dead:check # 0 orphaned exports
```

## Definition of Done

- `npm run quality` → 0 errors
- `npm test` → all pass
- `ROADMAP.md` sprint marked DONE
- `CHANGELOG.md [Unreleased]` entry added

## Non-negotiable rules

- No `eslint-disable`, `@ts-ignore`, `as any`
- No `enum` or `namespace` — `as const` / union types
- Every `t('key')` → both `en.json` AND locale file
- `.tsx` exports only React components
- Tailwind logical properties — never `ml-*`/`mr-*`
