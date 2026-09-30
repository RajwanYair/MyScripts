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
├── .vscode/mcp.json            ← VS Code MCP server configuration
├── .mcp.json                   ← portable Copilot CLI MCP configuration
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

VS Code loads `.vscode/mcp.json`; Copilot CLI and compatible clients load the
root `.mcp.json`. Keep the server names aligned and local package versions
pinned in both files.

| Server               | Type    | Capability                                                                                              |
| -------------------- | ------- | ------------------------------------------------------------------------------------------------------- |
| `github`             | `http`  | GitHub pull requests, issues, workflows, repository context, and code search.                           |
| `fetch`              | `stdio` | Web content retrieval using the official Python MCP server through `uvx`.                               |
| `filesystem`         | `stdio` | File operations rooted at the workspace. `search_files` and `directory_tree` support `excludePatterns`. |
| `gitkraken`          | `http`  | Git history, blame, diffs, branches, and pull request workflow.                                         |
| `playwright`         | `stdio` | Browser automation and web testing.                                                                     |
| `cloudflare`         | `http`  | Cloudflare Workers, Pages, D1, KV, and R2.                                                              |
| `memory`             | `stdio` | Persistent key-value memory for agent context.                                                          |
| `sequentialthinking` | `stdio` | Structured multi-step reasoning.                                                                        |
| `context7`           | `stdio` | Current, version-specific library documentation.                                                        |
| `brave-search`       | `stdio` | Web search; requires `BRAVE_API_KEY`.                                                                   |
| `chrome-devtools`    | `stdio` | Isolated Chrome debugging and performance inspection; usage statistics disabled.                        |

Filesystem access is restricted to the workspace root, not the user profile.
Use `excludePatterns` on recursive search/tree calls to omit `.git`, dependency,
build, and coverage directories. Chrome DevTools can inspect browser content;
do not use it with sensitive sessions or data.

## Available Agents

Custom agents for common workspace operations:

| Agent             | File                              | Use When                                                  |
| ----------------- | --------------------------------- | --------------------------------------------------------- |
| `new-project`     | `agents/new-project.agent.md`     | Scaffolding a new project from workspace templates.       |
| `upgrade-tooling` | `agents/upgrade-tooling.agent.md` | Upgrading shared dependencies and tooling.                |
| `security-audit`  | `agents/security-audit.agent.md`  | Auditing workspace security posture.                      |
| `web-sprint`      | `agents/web-sprint.agent.md`      | Executing a web SPA sprint item end-to-end.               |
| `web-feature`     | `agents/web-feature.agent.md`     | Scaffolding a feature across engine, store, UI, and i18n. |
| `debug`           | `agents/debug.agent.md`           | Diagnosing and fixing test, build, or runtime failures.   |
| `release`         | `agents/release.agent.md`         | Preparing and publishing a versioned project release.     |
| `cleanup`         | `agents/cleanup.agent.md`         | Removing dead code and resolving quality-gate failures.   |

## Available Prompts

### Python / General

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
| `dependency-update` | `prompts/dependency-update.prompt.md` | Safely auditing and updating dependencies    |
| `csp-hardening`     | `prompts/csp-hardening.prompt.md`     | Hardening Content Security Policy            |

### React / TypeScript SPA (generic template guidance)

| Prompt                  | File                                      | Use When                                                |
| ----------------------- | ----------------------------------------- | ------------------------------------------------------- |
| `new-web-feature`       | `prompts/new-web-feature.prompt.md`       | Scaffold complete feature: engine, store, UI, i18n      |
| `bundle-optimize`       | `prompts/bundle-optimize.prompt.md`       | Bundle size over budget; identify and fix heavy imports |
| `a11y-audit`            | `prompts/a11y-audit.prompt.md`            | WCAG 2.2 AA axe-core scan, manual checklist, fixes      |
| `perf-debug`            | `prompts/perf-debug.prompt.md`            | Lighthouse / Core Web Vitals diagnosis and fixes        |
| `lighthouse-ci`         | `prompts/lighthouse-ci.prompt.md`         | Configuring and troubleshooting Lighthouse CI           |
| `split-component`       | `prompts/split-component.prompt.md`       | Split oversized React component files into smaller ones |
| `fix-tests`             | `prompts/fix-tests.prompt.md`             | Diagnose and fix failing tests (Python or TypeScript)   |
| `roadmap-sprint`        | `prompts/roadmap-sprint.prompt.md`        | Execute a sprint item end-to-end with quality gates     |
| `parametrize-tests`     | `prompts/parametrize-tests.prompt.md`     | Refactor repetitive tests to parametrized form          |
| `i18n-add-keys`         | `prompts/i18n-add-keys.prompt.md`         | Adding translation keys with locale parity              |
| `fix-quality`           | `prompts/fix-quality.prompt.md`           | Diagnosing and fixing project quality gates             |
| `version-bump`          | `prompts/version-bump.prompt.md`          | Bumping project versions consistently                   |
| `create-project`        | `prompts/create-project.prompt.md`        | Creating a project from the workspace template          |
| `workspace-maintenance` | `prompts/workspace-maintenance.prompt.md` | Checking workspace and project health                   |

## Available Skills

| Skill                   | File                                    | Use When                                                                          |
| ----------------------- | --------------------------------------- | --------------------------------------------------------------------------------- |
| `release`               | `skills/release/SKILL.md`               | Creating a versioned release.                                                     |
| `security-audit`        | `skills/security-audit/SKILL.md`        | Running an OWASP security audit.                                                  |
| `workspace-maintenance` | `skills/workspace-maintenance/SKILL.md` | Auditing quality gates across the workspace and independent project repositories. |

## Recommended Awesome Copilot Plugins

VS Code and Copilot CLI include the `github/awesome-copilot` marketplace by
default. Workspace recommendations are declared in
`.github/copilot/settings.json`; they are recommendations, not bundled copies.

| Plugin | Use When |
| ------ | -------- |
| `context-engineering` | Mapping task context or planning a multi-file refactor. |
| `testing-automation` | Writing tests, using TDD, or exploring a site with Playwright. |
| `doublecheck` | Verifying factual claims and checking sources in generated analysis. |

These plugins are community-maintained and load on-demand skills and agents.
Review plugin contents before adding more, especially plugins that introduce
MCP servers, hooks, scripts, or external dependencies.

## Available Instructions

| File                          | Applies To                                                                                                                                       | Purpose                                            |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------- |
| `workspace.instructions.md`   | `**`                                                                                                                                             | Architecture, patterns, coding standards           |
| `git.instructions.md`         | `**`                                                                                                                                             | Git conventions and workflow                       |
| `python.instructions.md`      | `**/*.py`                                                                                                                                        | Python-specific style and patterns                 |
| `testing.instructions.md`     | `**/tests/**,**/conftest.py,**/*_test.py,**/test_*.py`                                                                                           | Testing framework and conventions                  |
| `cicd.instructions.md`        | `**/*.yml,**/*.yaml,.github/**`                                                                                                                  | CI/CD and GitHub Actions patterns                  |
| `security.instructions.md`    | `**/src/**,**/public/**`                                                                                                                         | Security requirements for source and public assets |
| `web-react.instructions.md`   | `**/src/**/*.{ts,tsx},**/tests/**/*.{ts,tsx},**/vite.config.ts,**/vitest.config.ts,**/playwright.config.ts,**/eslint.config.*,**/tsconfig*.json` | React/TypeScript SPA patterns and constraints      |
| `vanilla-web.instructions.md` | `**/src/**/*.js,**/css/**/*.css,**/index.html`                                                                                                   | Vanilla JS + CSS web app patterns                  |

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

## Advanced Patterns Reference

For production-grade patterns (agent scaffolding, version-sync, canonical facts enforcement,
$TEMP routing, sprint tracking, pre-release checklists, i18n parity, architecture boundaries):

→ See [`docs/ADVANCED_PATTERNS.md`](../docs/ADVANCED_PATTERNS.md)

## Creating Project-Specific Agents

When a sub-project needs specialized agents, create them at `<Project>/.github/agents/<name>.agent.md`.
The template and guidelines are in `docs/ADVANCED_PATTERNS.md § Agent Scaffolding`.

Recommended agent categories for production web apps:

- **Release Engineer** — version bumps, CHANGELOG, tagging
- **Security Agent** — OWASP, CSP, secrets
- **Performance Agent** — bundle size, Lighthouse, caching
- **i18n Agent** — translations, RTL, locale parity
- **Designer** — UI/UX, themes, accessibility
- **Domain Agent** — business logic specific to the project
- A task requires modifying >5 files across different sub-projects (ask for scope confirmation)
- Build/test failures are pre-existing — report clearly, don't broaden scope
