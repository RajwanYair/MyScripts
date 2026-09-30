---
mode: agent
tools: [read_file, run_in_terminal, grep_search, replace_string_in_file]
description: Analyze bundle size, find heavy imports, and optimize to stay under budget.
---

# Bundle Optimization Prompt

Analyze the current bundle and bring it under the budget defined in `config/bundle-budget.json`.

## Step 1 — Baseline

```bash
npm run build
npm run bundle:check
```

Record the current sizes for all chunks.

## Step 2 — Identify heavy imports

```bash
# Visual treemap (if rollup-plugin-visualizer is available)
npx rollup-plugin-visualizer dist/**/*.js

# Or: check individual chunk sizes from build output
```

Look for:

- Barrel file imports that pull in the entire library
- Synchronously imported components that could be lazy-loaded
- Duplicate polyfills or helpers across chunks
- Test-only utilities leaked into production bundles

## Step 3 — Apply optimizations (in priority order)

1. **Lazy load heavy route/panel components**

   ```tsx
   const HeavyPanel = React.lazy(() => import('./HeavyPanel'));
   ```

2. **Eliminate barrel file imports** — import from the specific module path

   ```ts
   // ❌ Pulls in entire library
   import { specific } from 'large-lib';
   // ✅ Direct path import
   import specific from 'large-lib/specific';
   ```

3. **Move heavy deps to their own manual chunk** in `vite.config.ts`

   ```ts
   manualChunks: (id) => {
     if (id.includes('heavy-dep')) return 'heavy-dep';
   }
   ```

4. **Remove unused exports** — run `npm run dead:check` first

## Step 4 — Constraints

- Do not break any existing test
- Do not change public API signatures
- Do not add new production dependencies

## Step 5 — Validate

```bash
npm run build
npm run bundle:check
npm test
npm run dead:check
```

All must pass before marking done.
