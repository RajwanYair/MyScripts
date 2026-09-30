# Changelog

All notable changes to this workspace will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

> **Scope**: this changelog covers the **root workspace** only — shared tooling,
> templates, scripts, CI infrastructure, docs, and the root hub `index.html`.
> Each sub-project (BudgetManager, CrossTide, …) maintains its own changelog
> inside its own repository.

## [Unreleased]

## [1.1.0] — 2026-09-30

### Added

- **Scripts** (backported from sub-projects):
  - `scripts/parallel-quality.mjs` — concurrent quality runner (from WoodworkingShop)
  - `scripts/sbom.mjs` — CycloneDX SBOM generation (from WoodworkingShop)
  - `scripts/check-owasp.mjs` — OWASP Top 10 static source scanner (from FamilyDashBoard)
  - `scripts/arch-check.mjs` — layer architecture enforcement (from CrossTide)
  - `scripts/lint-wrapper.mjs` — ESLint with $TEMP cache (from WoodworkingShop)
  - `scripts/lint-css-wrapper.mjs` — Stylelint with $TEMP cache (from WoodworkingShop)
  - `scripts/check-actions-pinned.mjs` — GitHub Actions SHA-pin enforcement (from FamilyDashBoard)
  - `scripts/check-dead-exports.mjs` — dead export detection (from FamilyDashBoard)
- **Templates** (new):
  - `templates/bundle-budget.template.json` — bundle size budget scaffold
  - `templates/bench-budget.template.json` — benchmark budget scaffold
  - `templates/supply-chain.yml` — supply chain security workflow
  - `templates/scorecard.yml` — OpenSSF Scorecard workflow
  - `templates/dependabot-auto-merge.yml` — auto-merge minor/patch deps
  - `templates/gitleaks.template.toml` — secret scanning config
  - `templates/renovate.template.json` — Renovate bot config template
- **Pre-commit hooks**: gitleaks secret scanning, shfmt shell formatting
- **package.json**: `engines` field, `simple-git-hooks`, `lint-staged`, `knip` config
- New devDependencies: `knip`, `rimraf`, `eslint-plugin-no-only-tests`,
  `eslint-plugin-react`, `eslint-plugin-regexp`, `eslint-plugin-testing-library`,
  `@cyclonedx/cyclonedx-npm`

### Changed

- **package.json**: bumped all dependencies to latest (TypeScript 6.0.3,
  Vite 8.0.14, Vitest 4.1.7, ESLint 10.4, Playwright 1.60, etc.)
- **requirements.txt**: bumped all Python deps (ruff 0.12, mypy 1.16,
  pytest 8.3, rich 14, pydantic 2.10, FastAPI 0.115, etc.)
- **pyproject.toml**: added ruff rules PTH, PERF, FURB, LOG, TCH; bumped
  pytest minversion to 8.0; added Python 3.14 to black targets
- **pre-commit**: bumped ruff 0.12.0, mypy 1.16.1, bandit 1.9.0
- **CI workflow**: validates all new scripts and template JSON files
- **templates/ci-web.yml**: added concurrency groups, `--ignore-scripts`,
  CSS lint, format check, bundle-size check
- **templates/eslint.config.mjs**: full 7-plugin flat config (from WoodworkingShop pattern)
- **templates/vite.config.ts**: added $TEMP cacheDir, manualChunks strategy
- **templates/tsconfig-web.json**: added lib, jsx, config include
- **.editorconfig**: added TypeScript/CSS/HTML/Docker/GitHub Actions sections
- **.markdownlintignore**: excludes all sub-project directories
- **.gitignore**: added SBOM/SARIF/security artifact exclusions
- **dependabot.yml**: added `actions` group for GitHub Actions updates
- **Install-DevTools.ps1**: added knip, pre-commit to global installs

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

[Unreleased]: https://github.com/RajwanYair/MyScripts/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/RajwanYair/MyScripts/releases/tag/v1.1.0
[1.0.0]: https://github.com/RajwanYair/MyScripts/releases/tag/v1.0.0
