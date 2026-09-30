---
mode: agent
description: Diagnose and fix failing tests — trace assertion failures, update snapshots, fix regressions.
---

# Fix Tests

Diagnose and fix all failing tests in the current project.

## Task

Run the test suite and fix all failures until the suite passes green.

## Strategy

1. Run the test suite — capture full output.
   - Python: `python -m pytest tests/ -v --tb=short 2>&1`
   - TypeScript: `npx vitest run 2>&1`
2. Identify each failing test: file, test name, assertion, actual vs. expected.
3. Categorize failures:
   - **Stale assertion** — test expectation outdated after a code change → update test
   - **Regression** — new code broke existing behavior → fix the source code
   - **Type error in test** — test doesn't compile → fix the test's type usage
   - **Missing mock/fixture** — test uses an API without setup → add to setup file
4. Fix each failure in the appropriate file.
5. Re-run the test suite — confirm all pass.
6. Run linter to confirm no lint/type regressions.

## Constraints

- **Never skip tests** (`it.skip`, `describe.skip`, `pytest.mark.skip`) — fix the root cause.
- **Never use `as any`** in TypeScript test files — properly type test data.
- **Use parametrized patterns** (`it.each` in Vitest, `pytest.mark.parametrize`) for multiple related cases.
- **Maintain coverage** — do not remove test cases; fix or replace them.

## Python-specific

- Fix import errors first (missing `conftest.py`, `__init__.py`)
- Check `tests/conftest.py` for missing fixtures
- Ensure mocks use `unittest.mock` or `pytest-mock` patterns

## TypeScript-specific

- Check `tests/setup.ts` for missing browser API mocks
- Use `vi.mock()` for module mocking, not manual stubs
- Verify `vitest.config.ts` includes the correct `environment` (happy-dom/jsdom)
