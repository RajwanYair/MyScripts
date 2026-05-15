# MyScripts Workspace — Agent Guide

This file is for repository-aware coding agents (GitHub Copilot, Copilot Coding Agent,
and custom agents) working at the MyScripts workspace level.

## Primary Goal

Maintain the centralized tool architecture. All shared configs, dependencies, and
scripts live here. Sub-projects reference them via relative paths (`../tooling/`,
`../node_modules/`).

## Workspace Structure

```text
MyScripts/                      ← you are here (centralized tools)
├── tooling/                    ← shared base configs (ESLint, TS, Vitest, Vite…)
├── scripts/                    ← shared quality scripts
├── templates/                  ← starter files for new repos
├── package.json                ← shared JS/TS dependencies
├── pyproject.toml              ← shared Python tool configs
├── .github/instructions/       ← path-specific Copilot instructions
├── .github/prompts/            ← reusable Copilot prompts
├── .vscode/mcp.json            ← MCP server configuration
└── <SubProject>/               ← independent git repos (one level below)
```

## Operating Rules

1. Read `.github/instructions/workspace.instructions.md` before making workspace-level changes.
2. Never install `node_modules` inside sub-projects — they resolve from root.
3. Never duplicate `tooling/` configs into sub-projects — they extend via `../tooling/`.
4. Python tool configs (ruff, mypy, pytest) are in root `pyproject.toml` — shared by all.
5. Keep changes scoped. Don't refactor sub-projects unless the task requires it.
6. Validate changes: run `ruff check` for Python, `npx eslint` for TS, `pytest` for tests.

## MCP Servers Available

Agents can use these MCP servers (configured in `.vscode/mcp.json`):

| Server       | Type             | Capability                                                                |
| ------------ | ---------------- | ------------------------------------------------------------------------- |
| `github`     | `http`           | PR, issue, workflow context, code search (Copilot-managed auth)           |
| `fetch`      | `stdio`          | HTTP requests, API testing, web content                                   |
| `filesystem` | `stdio`          | Scoped file read/write (workspace root, heavy dirs excluded)              |
| `playwright` | `stdio`          | Browser automation, visual debugging (`@microsoft/mcp-server-playwright`) |
| `gitkraken`  | `http`           | Git blame, log, diff, branch ops, PR workflow                             |
| `cloudflare` | `streamableHttp` | Workers, Pages, D1, KV, R2 management                                     |

## Available Prompts

| Prompt              | File                                  | Use When                                     |
| ------------------- | ------------------------------------- | -------------------------------------------- |
| `code-review`       | `prompts/code-review.prompt.md`       | Reviewing code against workspace standards   |
| `create-project`    | `prompts/create-project.prompt.md`    | Scaffolding a new Python project             |
| `fix-quality`       | `prompts/fix-quality.prompt.md`       | Fixing lint/type/security issues             |
| `write-tests`       | `prompts/write-tests.prompt.md`       | Generating pytest tests                      |
| `fix-lint`          | `prompts/fix-lint.prompt.md`          | Fixing lint and type errors to zero warnings |
| `version-bump`      | `prompts/version-bump.prompt.md`      | Bumping version across all project files     |
| `security-audit`    | `prompts/security-audit.prompt.md`    | OWASP Top 10 security review                 |
| `modernize-tooling` | `prompts/modernize-tooling.prompt.md` | Auditing and modernizing VS Code/CI tooling  |

## Available Skills

| Skill            | File                             | Use When                                                       |
| ---------------- | -------------------------------- | -------------------------------------------------------------- |
| `release`        | `skills/release/SKILL.md`        | Creating a versioned release (version bump → tag → GH release) |
| `security-audit` | `skills/security-audit/SKILL.md` | Running OWASP security audit with automated + manual checklist |

## Available Instructions

| File                        | Applies To                      | Purpose                                  |
| --------------------------- | ------------------------------- | ---------------------------------------- |
| `workspace.instructions.md` | `**`                            | Architecture, patterns, coding standards |
| `python.instructions.md`    | `**/*.py`                       | Python-specific style and patterns       |
| `testing.instructions.md`   | `**/tests/**`                   | Testing framework and conventions        |
| `cicd.instructions.md`      | `**/*.yml,**/*.yaml,.github/**` | CI/CD and GitHub Actions patterns        |

## Quality Gates

Before marking any task complete, verify:

- [ ] `ruff check src/ tests/` — zero lint errors (Python)
- [ ] `ruff format --check src/ tests/` — formatting clean (Python)
- [ ] `mypy src/ --ignore-missing-imports` — no new type errors (Python)
- [ ] `npx eslint .` — zero errors (TypeScript, when applicable)
- [ ] `npx tsc --noEmit` — type-check passes (TypeScript, when applicable)
- [ ] `pytest tests/ -v` — all tests pass
- [ ] No hardcoded paths, secrets, or credentials introduced
- [ ] Changes follow the centralized architecture (no vendored copies)

## Copilot Coding Agent (GitHub Actions)

When running as a Copilot Coding Agent in CI:

- Environment setup: see `templates/copilot-setup-steps.yml`
- Python deps: `pip install -r requirements.txt`
- JS/TS deps: `npm ci` at workspace root
- Available tools: ruff, mypy, pytest, eslint, tsc, vitest, playwright

## Stop Conditions

Stop and report instead of guessing when:

- A sub-project has its own `node_modules/` or `package-lock.json` — flag it, don't silently fix
- A change would break the centralized architecture
- A referenced file is cloud-only (OneDrive) and inaccessible
- A CI workflow would need secrets you don't have access to
- A task requires modifying >5 files across different sub-projects (ask for scope confirmation)
- Build/test failures are pre-existing — report clearly, don't broaden scope
