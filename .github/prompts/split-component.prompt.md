---
mode: agent
tools: [read_file, run_in_terminal, grep_search, replace_string_in_file]
description: Split oversized React component files (> 400 lines) into focused sub-components.
---

# Split Component Prompt

Split React component files that exceed the size limit into focused, maintainable sub-components.

## Size Limits

| File type | Max lines |
| --- | --- |
| Engine module | 300 L |
| React component | 400 L |
| Store slice | 250 L |
| Test file | 400 L |

## Step 1 — Find oversized files

```bash
Get-ChildItem src -Recurse -Filter "*.tsx" |
  ForEach-Object { [PSCustomObject]@{ Lines = (Get-Content $_.FullName).Count; File = $_.FullName } } |
  Where-Object { $_.Lines -gt 400 } | Sort-Object Lines -Descending
```

## Step 2 — Identify split boundaries

Before splitting, identify natural boundaries:

- Distinct visual sections (header, body, footer of a panel)
- Distinct feature responsibilities (list vs. detail vs. form)
- Utility functions that can move to a sibling `.ts` file

## Step 3 — Apply split

```tsx
// ❌ Before: MonolithPanel.tsx (600 L) — all in one file
export function MonolithPanel() {
  // ... 600 lines mixing header, items list, and detail view
}

// ✅ After: MonolithPanel.tsx (80 L) — compose sub-components
import { MonolithHeader } from './MonolithHeader';
import { MonolithList } from './MonolithList';
import { MonolithDetail } from './MonolithDetail';

export function MonolithPanel() {
  return (
    <div>
      <MonolithHeader />
      <MonolithList />
      <MonolithDetail />
    </div>
  );
}
```

## Step 4 — react-refresh rule

Extract non-component exports to sibling `.ts` files:

```ts
// ❌ Wrong — mixing component and utility in same file
export function formatLabel(s: string) { … }   // utility
export function ItemCard() { … }               // component

// ✅ Correct
// format-label.ts
export function formatLabel(s: string) { … }
// ItemCard.tsx
import { formatLabel } from './format-label';
export function ItemCard() { … }
```

## Step 5 — Validate

```bash
npm run typecheck
npm run lint
npm test
```

All must pass. No behavior changes — split is refactor only.
