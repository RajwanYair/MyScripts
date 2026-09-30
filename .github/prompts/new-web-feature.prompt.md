---
mode: agent
tools: [read_file, replace_string_in_file, create_file, run_in_terminal, grep_search]
description: Scaffold a complete React feature — engine module, store slice, component panel, i18n keys, unit tests, and mount point.
---

# New React Feature Prompt

Scaffold a complete new feature for a React/TypeScript SPA following the workspace patterns in `docs/REACT_SPA_PLAYBOOK.md`.

## Feature to build

`$FEATURE_NAME` — `$FEATURE_DESCRIPTION`

## Implementation order (do not skip layers)

1. **Engine** (`src/engine/<feature>.ts`): pure TypeScript, no React, no DOM.
   - Define types in `src/engine/types.ts` or a local `types.ts` sibling
   - Export from `src/engine/index.ts`
   - Max 300 lines — split by domain if larger

2. **Store slice** (`src/store/slices/<feature>-slice.ts`):
   - Define `FeatureSlice` type and `createFeatureSlice` factory
   - Compose into the root store in `src/store/cabinet-store.ts`
   - Persist only stable user data

3. **Component** (`src/components/<section>/<FeaturePanel>.tsx`):
   - Export only React components from `.tsx` files
   - Extract utilities to sibling `.ts` files
   - Use `useTranslation()` for all user-visible strings
   - Use Tailwind logical properties (`ms-*`, `me-*`) — no `ml-*`/`mr-*`
   - Max 400 lines — split into sub-components if larger

4. **i18n** (`src/i18n/en.json` and `src/i18n/he.json`):
   - Add `<feature>.*` namespace keys in both files in the **same commit**
   - Run `npm run i18n:coverage` to verify 100% parity

5. **Mount**: wire component into its parent panel

6. **Tests** (`tests/engine/<feature>.test.ts` and `tests/components/<feature>.test.tsx`):
   - Unit tests for engine functions — import directly, no store or React
   - Component tests with `renderHook` or `render` + `screen`
   - Use `it.each` for parametrized positive/negative pairs
   - Min 10 test cases covering happy path + edge cases + invalid inputs

## Constraints

- Zero `eslint-disable`, `@ts-ignore`, `as any`
- No `enum` or `namespace` — use `as const` + union types
- Engine must pass `npm run typecheck` with zero errors
- All intermediate build artifacts → `$TEMP`

## Quality gate (run before marking done)

```bash
npm run typecheck
npm run lint
npm run i18n:coverage
npm test
```
