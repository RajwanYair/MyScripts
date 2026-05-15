# Changelog

All notable changes to this workspace will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

> **Scope**: this changelog covers the **root workspace** only — shared tooling,
> templates, scripts, CI infrastructure, docs, and the root hub `index.html`.
> Each sub-project (BudgetManager, CrossTide, …) maintains its own changelog
> inside its own repository.

## [Unreleased]

### Added
- `CHANGELOG.md` (this file) with Keep a Changelog format.
- `docs/ARCHITECTURE.md` with workspace-level Mermaid architecture diagram.
- Root link-health and JSON-schema validation jobs in CI (Phase 4).
- `npm run serve` script for local hub verification.

### Changed
- Dedupe `ROADMAP.md` — removed stale trailing copy of phases/state summary.
- CI workflow now invokes `npm run check` instead of duplicating logic inline.

### Removed
- `my_settings.json` (orphaned, unreferenced personalization file).
- `build/` CMake artifacts at workspace root (sub-project artifact leak).
- `test_env_clean/` stray Python virtualenv.

## [1.0.0] — 2026-05-15

### Added
- Initial workspace commit and GitHub repository `RajwanYair/MyScripts`.
- Centralized JS/TS tooling: root `package.json`, `tooling/` base configs
  (ESLint, TypeScript, Vitest, Vite, Prettier, Stylelint, Playwright,
  HTMLHint, Markdownlint, Commitlint).
- Centralized Python tooling: root `pyproject.toml` (ruff, mypy, pytest,
  coverage, bandit) and `pyrightconfig.json`.
- Workspace `.github/` infrastructure: Copilot instructions, prompts, skills,
  AGENTS.md, issue templates, PR template, CONTRIBUTING.md, SECURITY.md,
  CODEOWNERS, Dependabot config.
- CI workflows: `ci.yml` (workspace validation), `release.yml` (template
  archive packaging), `security.yml` (CodeQL, Trivy, TruffleHog, npm audit).
- Root hub `index.html` linking to all sub-projects and their GitHub Pages
  endpoints.
- Reusable scripts: `validate-mermaid.mjs`, `check-bundle-size.mjs`,
  `check-test-focus-skip.mjs`.
- Templates for new repos under `templates/` (CI, gitignores, configs).
- `.vscode/` shared settings, tasks, extensions recommendations, and
  `mcp.json` with GitHub, Fetch, Filesystem, Playwright, GitKraken,
  Cloudflare servers.

[Unreleased]: https://github.com/RajwanYair/MyScripts/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/RajwanYair/MyScripts/releases/tag/v1.0.0
