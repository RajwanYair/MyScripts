---
description: "Fix all lint and type errors to reach zero warnings. Use when CI lint or typecheck fails, or after adding new code."
---

# Fix Lint and Type Errors

Fix all lint and type errors in the workspace.

## Instructions

**Scope:** {{LINT_SCOPE}} _(default: `src tests`)_

### Rules — Never Violate

1. **No `eslint-disable` comments** — fix the root cause instead
2. **No `@ts-ignore` or `@ts-expect-error`** — add proper types or guards
3. **No `any` type widening** — use `unknown` + type guard if the shape is dynamic
4. **No `# type: ignore`** — fix the actual type error
5. **No `# pragma: no cover`** without explicit justification
6. **No bare `except:`** — use specific exception types

## Steps

1. Run lint to see all errors (adjust tool to your stack):

   ```powershell
   # TypeScript projects
   npx eslint src tests --max-warnings 0
   npx tsc --noEmit

   # Python projects
   ruff check src tests
   mypy src
   ```

2. Fix each error in the source. Common patterns:

   | Error                           | Fix                                               |
   | ------------------------------- | ------------------------------------------------- |
   | `no-unused-vars`                | Remove or prefix with `_` if intentionally unused |
   | `no-explicit-any`               | Replace with `unknown` + type guard               |
   | `prefer-const`                  | Change `let` → `const`                            |
   | Type `X is not assignable to Y` | Add missing field or narrow with type guard       |

3. Re-run until clean — 0 errors, 0 warnings.

## Verification

Run lint + typecheck + tests. Expected: zero errors, zero warnings, zero test failures.
No suppressions allowed — zero tolerance.
