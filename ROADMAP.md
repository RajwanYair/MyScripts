# MyScripts Workspace Roadmap

> **Last updated**: 2026-05-14
> **Framework**: Universal Project Enhancement Framework v15.0.0

## Vision

A best-in-class, production-ready workspace where every sub-project shares
centralized tools, consistent quality gates, and a validated release process.

---

## Current State Summary

| Area | Status | Notes |
|------|--------|-------|
| Centralized JS/TS tooling | ✅ Done | Root `package.json` + `node_modules/`, `tooling/` base configs |
| Centralized Python tooling | ✅ Done | Root `pyproject.toml` (ruff, mypy, pytest, coverage, bandit) |
| Shared templates | ✅ Done | `templates/` — CI, gitignore, configs |
| Workspace instructions | ✅ Done | `.github/instructions/` — Python, CI/CD, testing, workspace |
| Copilot prompts | ✅ Done | `.github/prompts/` — code-review, create-project, fix-quality, write-tests |
| MCP servers | ✅ Done | `.vscode/mcp.json` — GitHub, Fetch, Filesystem, Playwright, GitKraken, Cloudflare |
| CI/CD workflows | ✅ Done | `ci.yml` validates workspace tooling; `release.yml` packages template archive |
| Security workflow | ✅ Done | CodeQL (Python + JS/TS), Trivy, npm audit, TruffleHog |
| Dependabot | ✅ Done | pip, npm, github-actions all covered |
| CODEOWNERS | ✅ Done | All projects mapped to `@RajwanYair` |
| Dead artifacts | ✅ Cleaned | `.github/docs/` removed; `debug.log` removed |
| Root index.html hub | ✅ Done | Links to all sub-projects + GitHub Pages endpoints |
| CONTRIBUTING.md | ✅ Done | Covers web (TypeScript) and Python workflows |
| PR template | ✅ Done | Dual checklist for web and Python stacks |
| npm scripts | ✅ Done | `npm run check` validates workspace-level tooling |
| Sub-project adoption | ⚠️ Partial | BudgetManager ✅, CrossTide/CrossTideWeb/Wedding ❌ (self-contained), FamilyDashBoard ❌ (vendored copy) |

---

## Phase 1 — Quality Gates: Zero Tolerance ✅ Complete

**Goal**: CI/CD fails on real issues, no suppression, no `|| echo` fallbacks.

- [x] CI workflow: replace Python-only CI with workspace validation CI
- [x] CI workflow: validates shared tooling configs, markdown, YAML templates
- [x] Release workflow: replaced Python `python -m build` with workspace template archive
- [x] Release workflow: uses `softprops/action-gh-release@v2`
- [x] Security workflow: added JS/TS CodeQL + npm audit
- [x] CODEOWNERS: all projects mapped to `@RajwanYair`; stale `/.github/docs/` reference removed
- [x] Remove `.github/docs/` dead artifacts (CLEANUP.md, PRODUCTION.md, production-directives.txt, PROJECT_SPEC_PROMPT.md, script_enhancement_guide.md)

---

## Phase 2 — Sub-Project Centralization (Short-term)

**Goal**: All web sub-projects use `../tooling/` — no vendored copies or self-contained configs.

- [ ] **CrossTide**: migrate `eslint.config.mjs`, `tsconfig.json`, `vitest.config.ts` to `../tooling/` imports; remove local `node_modules/` and `package-lock.json`
- [ ] **CrossTideWeb**: migrate configs to `../tooling/` imports
- [ ] **Wedding**: remove inline fallback rules from `eslint.config.mjs`; add `tsconfig.json` extends; remove local `node_modules/` and `package-lock.json`
- [ ] **FamilyDashBoard**: remove vendored `tooling/` directory; update refs from `./tooling/` to `../tooling/`
- [ ] Validate all sub-projects resolve from root `node_modules/`

---

## Phase 3 — Developer Experience & VS Code (Mid-term)

**Goal**: zero VS Code diagnostics from workspace config; reproducible dev setup.

- [ ] Consolidate `.vscode/settings.json` — remove stale/redundant keys
- [ ] Verify `.vscode/extensions.json` recommends correct extensions for all stacks
- [ ] Verify `.vscode/tasks.json` covers build/test/lint for both Python and web
- [ ] Pin tool versions in root `package.json` and `requirements.txt`

---

## Phase 4 — Documentation Excellence (Mid-term)

**Goal**: top-tier GitHub repo quality; visual clarity; docs match reality.

- [ ] Add SVG workspace architecture diagram (`docs/assets/architecture.svg`)
- [ ] Ensure all sub-projects link back to workspace docs for tooling setup
- [ ] Consolidate duplicated guidance between `copilot-instructions.md` and `workspace.instructions.md`

---

## Phase 5 — Security & Compliance (Mid-term)

**Goal**: security scanning in CI; dependency audit; secrets hygiene.

- [x] CodeQL analysis workflow — Python + JS/TS
- [x] TruffleHog secrets scan in CI
- [x] npm audit in security workflow
- [ ] Add Dependabot auto-merge for patch updates
- [ ] Verify no secrets in git history (`git log --all --diff-filter=A -- '*.env'`)
- [ ] Add `.env.example` templates where needed

---

## Phase 6 — Architecture Deep Rethink (Long-term)

**Goal**: best-in-class engineering decisions across all projects.

- [ ] Evaluate: monorepo tooling (Nx/Turborepo) for web projects vs current flat structure
- [ ] Decision log: document what stays and why (current flat model is chosen for simplicity)
- [ ] Observability: add structured logging pattern to shared Python tooling
- [ ] Performance: add bundle-size CI gate for web projects (script already exists in `scripts/`)

---

## Phase 7 — Release Readiness (Long-term)

**Goal**: ship like a professional product.

- [x] `release.yml` packages workspace template archive with sha256 checksums
- [ ] Define versioning scheme per project (semver, tag-based)
- [ ] Create release checklist template
- [ ] Add changelog automation (git-cliff or conventional-changelog)
- [ ] Sprint/release pattern: commit after each sprint, GH release every 5 sprints

---

## Phase 8 — Benchmark & Best Practices (Ongoing)

**Goal**: strategic comparison with top-class workspaces.

| Dimension | Our Status | Best-in-Class Target |
|-----------|-----------|---------------------|
| CI strictness | ✅ Hard fails | Hard fails, no suppressions |
| Centralized tooling | ✅ Mostly | 100% — no vendored copies |
| Docs quality | ✅ Good | SVG diagrams, architecture docs, badges |
| Release process | ✅ Template archive | Automated with changelog generation |
| Security scanning | ✅ Full suite | CodeQL + TruffleHog + npm audit + Dependabot auto-merge |
| DX (dev experience) | ✅ Good | Zero-config onboarding, single `npm install` |
| Test coverage | ⚠️ Varies | 90%+ enforced per project |

---

## Tech Debt Register

| Item | Priority | Effort | Notes |
|------|----------|--------|-------|
| CrossTide self-contained tooling | Medium | Medium | Requires config migration to `../tooling/` |
| FamilyDashBoard vendored tooling | Medium | Medium | Remove `./tooling/`, update paths |
| Wedding inline ESLint fallback | Low | Low | Remove try/catch pattern |
| Duplicated instructions content | Low | Medium | Merge `copilot-instructions.md` ↔ `workspace.instructions.md` |
| `.vscode/settings.json` cleanup | Low | Low | Remove stale/redundant keys |
| Architecture SVG diagram | Low | Medium | Visual overview for docs/ |

