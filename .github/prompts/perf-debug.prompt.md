---
mode: agent
tools: [read_file, run_in_terminal, grep_search, replace_string_in_file]
description: Lighthouse / runtime performance diagnosis and remediation.
---

# Performance Diagnosis Prompt

Diagnose and fix performance issues in a React/TypeScript SPA. Targets from `docs/REACT_SPA_PLAYBOOK.md`:

| Metric | Target |
| --- | --- |
| LCP | < 1.5 s |
| FCP | < 1.2 s |
| TBT | < 200 ms |
| CLS | < 0.1 |
| Config → preview render | < 100 ms |
| Heavy algorithm (worker) | < 50 ms |
| Bundle size | < 1.8 MB JS total |

## Step 1 — Baseline measurement

```bash
npm run build
npm run lighthouse
# OR: manual Chrome DevTools Lighthouse on http://localhost:4173/RepoName/
```

Record all Core Web Vitals.

## Step 2 — Root cause diagnosis

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| High TBT | Long tasks on main thread | Move algorithm to Web Worker via Comlink |
| High FCP | Bundle too large | Lazy-load non-critical panels with `React.lazy` |
| Slow state update | Re-rendering too many components | Add Zustand selectors; memo heavy components |
| Slow algorithm | Synchronous on render path | Run in Worker; add memoization with `useMemo` |
| Large vendor chunk | Over-importing from libraries | Import from specific paths; tree-shake |
| High CLS | No layout reservations for async content | Add min-height/aspect-ratio placeholders |

## Step 3 — Profiling

In Chrome DevTools → Performance → Record:

1. Load the page
2. Interact with the performance-critical feature
3. Look for: long tasks (red blocks > 50 ms), layout shifts, excessive re-renders

React DevTools Profiler:

1. Enable "Record why each component rendered"
2. Interact with the slow surface
3. Identify components that re-render on unrelated state changes

## Step 4 — Apply fixes

Common React performance fixes:

```tsx
// Memoize expensive pure components
const HeavyList = memo(({ items }: Props) => <ul>…</ul>);

// Memoize expensive computations
const result = useMemo(() => expensiveCalc(input), [input]);

// Stable callbacks to prevent child re-renders
const handleClick = useCallback(() => dispatch(action), [dispatch]);

// Split Zustand selector to prevent unnecessary re-renders
const width = useCabinetStore((s) => s.config.width);      // ✅ only re-renders on width change
const { config } = useCabinetStore();                       // ❌ re-renders on any store change
```

## Step 5 — Validate

```bash
npm run build
npm run bundle:check
npm run bench:check   # ensure no algorithmic regression
npm run test:e2e      # no a11y/visual regressions
```
