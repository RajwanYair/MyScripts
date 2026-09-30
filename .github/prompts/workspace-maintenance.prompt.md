---
description: >
  Comprehensive workspace health check — cleans generated files, runs all quality
  gates, checks dead code, audits dependencies, reviews security, and verifies
  all sub-projects are in a production-ready state.
---

# Workspace Maintenance

Run a full health check across the MyScripts workspace and every sub-project.
Fix every issue found before reporting done.

## Step 1 — Clean Generated Files

Verify no intermediate build artifacts are in the workspace root:

```bash
# Should return zero results
Get-ChildItem -Recurse -Include "*.eslintcache","htmlcov",".coverage",".pytest_cache" -ErrorAction SilentlyContinue |
  Where-Object { $_.FullName -notlike "*\node_modules\*" -and $_.FullName -notlike "*\.git\*" }
```

If any leak is found, move paths to `$TEMP`:

- Python coverage → `$env:TEMP\<ProjectName>\coverage\`
- ESLint cache → `$env:TEMP\<ProjectName>\.eslintcache`
- Pytest cache → `$env:TEMP\<ProjectName>\.pytest_cache`

## Step 2 — Root-Level Quality (Node.js tooling)

```bash
# From MyScripts root
npm run lint          # Validate shared configs and scripts
npm run lint:md       # Lint all Markdown files
```

## Step 3 — Python Sub-Projects

For each Python sub-project that has a `pyproject.toml`:

```bash
cd <ProjectName>
ruff check . && ruff format --check .
mypy src/ --ignore-missing-imports
pytest tests/ -x --tb=short -q
```

## Step 4 — TypeScript Sub-Projects

For each TypeScript sub-project that has a `package.json`:

```bash
cd <ProjectName>
npx tsc --noEmit
npx eslint . --max-warnings 0
npx vitest run --reporter=verbose
npm run build
```

## Step 5 — Dead Code Check

```bash
# TypeScript sub-projects: run knip if configured
cd <TypeScriptProject> && npm run dead:check

# Python: check for unused imports
cd ../<PythonProject> && ruff check . --select F401
```

## Step 6 — Bundle Size (TypeScript SPAs)

```bash
cd <TypeScriptSpaProject> && npm run bundle:check
```

## Step 7 — Security Audit

```bash
# Node.js (root + each TS sub-project)
npm audit --audit-level=high

# Python (for each project with requirements.txt)
pip-audit -r requirements.txt --progress-spinner off
```

## Step 8 — Dependency Freshness

Report (but do NOT auto-upgrade):

```bash
# Node
npm outdated

# Python
pip list --outdated --format=columns
```

## Step 9 — Markdown Quality

```bash
npx markdownlint-cli2 "**/*.md" --ignore node_modules --config .markdownlint.json
```

## Step 10 — i18n Coverage (TypeScript SPA projects with localization)

```bash
cd <TypeScriptSpaProject> && npm run i18n:coverage
```

## Step 11 — Actions Pin Check

```bash
node scripts/check-actions-pinned.mjs
```

## Step 12 — Final Summary

Report as a table:

| Check               | Status | Issues |
| ------------------- | ------ | ------ |
| Clean TEMP          | ✅/❌  | ...    |
| Root lint           | ✅/❌  | ...    |
| Python projects     | ✅/❌  | ...    |
| TypeScript projects | ✅/❌  | ...    |
| Dead code           | ✅/❌  | ...    |
| Bundle size         | ✅/❌  | ...    |
| Security            | ✅/❌  | ...    |
| Dependencies        | ✅/❌  | ...    |
| Markdown            | ✅/❌  | ...    |
| i18n coverage       | ✅/❌  | ...    |
| Actions pinned      | ✅/❌  | ...    |
