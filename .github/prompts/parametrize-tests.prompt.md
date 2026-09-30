---
mode: agent
description: Convert repetitive tests to parametrized form — it.each (Vitest) or pytest.mark.parametrize (pytest).
---

# Test Refactor — Parametrize Tests

Refactor `${testFile}` to use parametrized test patterns.

## Goal

Reduce test file length by ≥ 20 % by collapsing repetitive `it` / `def test_` blocks
into parametrized tables.

## TypeScript / Vitest Pattern

```ts
// BEFORE — repetitive pair
it('validates narrow width', () => {
  expect(validate({ width: 100 }).ok).toBe(false);
});
it('validates wide width', () => {
  expect(validate({ width: 800 }).ok).toBe(true);
});

// AFTER — parametrized table
it.each([
  [{ width: 100 }, false],
  [{ width: 800 }, true],
] as const)('validates width %o → %s', (input, expected) => {
  expect(validate(input).ok).toBe(expected);
});
```

## Python / pytest Pattern

```python
# BEFORE — repetitive pair
def test_narrow_width():
    assert validate({'width': 100}).ok is False

def test_wide_width():
    assert validate({'width': 800}).ok is True

# AFTER — parametrized
@pytest.mark.parametrize('width,expected', [(100, False), (800, True)])
def test_width_validation(width: int, expected: bool) -> None:
    assert validate({'width': width}).ok is expected
```

## Constraints

- **Never skip tests** — fix root cause, don't remove cases
- **Never use `as any`** (TypeScript) — properly type table rows
- **Group related assertions** in one test block rather than spreading across multiple
- Keep the file ≤ 400 lines after refactoring

## Steps

1. Read the full test file.
2. Identify groups of 2+ structurally identical test blocks differing only in input/expected values.
3. Collapse each group into a parametrized table.
4. Extract any repeated fixture objects into a `const` / fixture near the top.
5. Run the test suite — all tests must still pass with the same count.
6. Confirm line count dropped by ≥ 20 %.
