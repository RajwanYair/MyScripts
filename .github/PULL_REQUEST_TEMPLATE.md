## Description

Brief description of what this PR does and why.

Closes #<!-- issue number -->

## Type of Change

- [ ] Bug fix (non-breaking change that fixes an issue)
- [ ] New feature (non-breaking change that adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to change)
- [ ] Refactor / code quality improvement
- [ ] Documentation update
- [ ] CI / build / tooling change
- [ ] Security fix

## Changes Made

- `path/to/file`: description of change
- `path/to/other`: description of change

## Testing

- [ ] Tests added / updated
- [ ] All existing tests pass
- [ ] Tested manually (describe below)

### How to Test

```bash
# Web projects
npx vitest run --coverage
npx playwright test

# Python projects
python -m pytest tests/ -v --tb=short
```

## Quality Checklist

### Web / TypeScript
- [ ] `eslint --max-warnings 0` passes
- [ ] `tsc --noEmit` passes (no type errors)
- [ ] `vitest run --coverage` passes with 90%+ coverage
- [ ] `vite build` succeeds with 0 warnings

### Python
- [ ] `ruff check` passes
- [ ] `ruff format --check` passes
- [ ] `mypy` passes (no new regressions)
- [ ] `pytest` passes with 90%+ coverage
- [ ] `bandit` security check clean

### Both
- [ ] No hardcoded absolute paths, secrets, or credentials
- [ ] No debug code left in production paths
- [ ] No blanket lint/type suppressions without documented justification
- [ ] Documentation updated if behaviour changed
- [ ] `CHANGELOG.md` updated (for user-visible changes)

## Screenshots (if applicable)

GUI changes, CLI output, etc.

