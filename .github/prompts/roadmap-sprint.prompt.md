---
mode: agent
description: Execute a roadmap sprint item end-to-end — implement the feature, pass all quality gates, update roadmap and changelog, then commit.
---

# Roadmap Sprint

Execute sprint item **`${sprintId}`** — `${description}`.

## Mandatory Constraints

- **Zero lint suppressions**: no `eslint-disable`, `@ts-ignore`, `@ts-nocheck`, `as any` (TypeScript)
- **No bare `except:`** — use specific exception types (Python)
- **Type hints required** on all function signatures (Python)
- **No hardcoded paths** — use `Path(__file__).parent.resolve()` or `$TEMP` (Python)
- For TypeScript SPAs: follow `.github/instructions/web-react.instructions.md` strictly

## Steps

1. Read the target file(s) to understand current structure.
2. Read `ROADMAP.md` to understand sprint context and acceptance criteria.
3. Plan the implementation (outline files to create/modify).
4. Implement the changes file-by-file following the project architecture.
5. Run the project's quality gate:
   - Python: `python -m ruff check src/ && python -m mypy src/ && python -m pytest tests/`
   - TypeScript: `npm run quality && npm test`
6. Fix any errors — zero tolerance.
7. Update `ROADMAP.md` to mark the sprint item `DONE`.
8. Append a brief entry to `CHANGELOG.md` under `[Unreleased]`.

## Definition of Done

- All tests pass with no skips
- Linter/type-checker: 0 errors, 0 warnings
- `ROADMAP.md` sprint item marked DONE
- `CHANGELOG.md [Unreleased]` entry added
- Working tree is clean (commit-ready)
