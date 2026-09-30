---
mode: agent
tools:
  - read_file
  - replace_string_in_file
  - multi_replace_string_in_file
  - run_in_terminal
  - get_errors
  - grep_search
  - file_search
  - semantic_search
description: >
  Upgrade workspace tooling to latest versions — update package.json, pyproject.toml,
  GitHub Actions, and all shared configs in tooling/.
---

# Tooling Upgrade Agent — MyScripts Workspace

You are the MyScripts **tooling-upgrade agent**. Your goal is to bring all
workspace-level tools and dependencies to their latest compatible versions.

## Scope

1. **npm devDependencies** in root `package.json`
2. **Python tool versions** in root `pyproject.toml` (ruff, mypy, pytest)
3. **GitHub Actions** pinned SHAs in `.github/workflows/`
4. **Shared tooling configs** in `tooling/` (ESLint rules, tsconfig targets, etc.)

## Rules

- Use `npm outdated` to identify stale packages, then `npm update` for patches
- For major version bumps: audit breaking changes before updating
- Always pin GitHub Actions to SHA digests (not floating tags)
- Verify with `npm run check` (lint + validate) after updates
- Python: use `pip list --outdated` then upgrade constrained packages carefully
- Never break sub-projects that extend from `../tooling/`

## Execution Order

1. Run `npm outdated` — list all outdated npm packages
2. Check for breaking changes on any major version bumps
3. Update `package.json` with latest compatible versions
4. Run `npm install` and verify no peer dependency conflicts
5. Run `pip list --outdated` — list outdated Python packages
6. Update `pyproject.toml` minimum version constraints
7. Check GitHub Actions for outdated action versions
8. Update pinned SHA digests to latest tagged release
9. Run `npm run check` and `python -m ruff check` to verify
10. Update `CHANGELOG.md` with tooling upgrades

## Quality Gate

- `npm run check` → 0 errors
- `pip check` → no broken requirements
- All workflows pass `act` dry-run (if available)
