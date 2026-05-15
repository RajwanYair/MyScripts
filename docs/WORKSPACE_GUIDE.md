# Workspace Operating Guide

> **MyScripts** is an umbrella folder containing multiple independent Git repositories.
> It is **not** a monorepo — each subfolder is published as its own GitHub repo.

## Centralized Tool Architecture

**All development tools live in `MyScripts/` (this directory).** Sub-projects one
level below reference them via relative paths (`../`). This keeps tooling
consistent, updatable in one place, and prevents version drift across projects.

```
MyScripts/                          ← CENTRALIZED TOOLS LIVE HERE
├── package.json + node_modules/    ← shared JS/TS deps (npm install here only)
├── pyproject.toml                  ← shared Python tool configs (ruff, mypy, pytest)
├── tooling/                        ← shared base configs (ESLint, TS, Vitest, Vite…)
├── scripts/                        ← shared quality scripts
├── templates/                      ← starter files for new repos
├── .vscode/                        ← shared VS Code + MCP settings
├── .github/                        ← shared Copilot instructions
│
├── ProjectA/                       ← sub-project (own git repo)
│   ├── tsconfig.json               ← extends ../tooling/tsconfig/base-*.json
│   ├── eslint.config.mjs           ← imports ../tooling/eslint/*.mjs
│   └── ...project source...
└── ProjectB/
    └── ...
```

**Rules:**
1. `npm install` — run ONLY at `MyScripts/` root, never inside a sub-project
2. Config files in sub-projects — `extends` or `import` from `../tooling/`
3. Never vendor/copy `tooling/` into a sub-project
4. Python tools (ruff, mypy, pytest) — configured once in root `pyproject.toml`
5. Sub-projects contain ONLY project-specific overrides and source code

## Directory Layout

```
MyScripts/                          ← umbrella root (NOT a git repo)
├── .github/                        ← shared Copilot instructions, templates, CI
├── .vscode/                        ← shared VS Code settings (multi-root)
├── docs/                           ← this guide + workspace-level docs
├── templates/                      ← starter files for new repos
├── BudgetManager/                  ← TypeScript budget tracking app
├── CrossTide/                      ← TypeScript stock crossover app
├── CrossTideWeb/                   ← TypeScript web companion
├── DupDetector/                    ← Python duplicate-file finder
├── ExplorerLens.io/                ← C++ Windows Shell extension
├── FamilyDashBoard/                ← TypeScript family TV dashboard
├── FileNameManipulator/            ← Python filename utility
├── FileProcessor/                  ← Python file processing pipeline
├── OptimizeBrowsers/               ← Python browser optimizer
├── OptimizeWIN_n_WSL/              ← Python Windows/WSL optimizer
├── PPA/                            ← Python PPA automation
├── rajwanyair.github.io/           ← GitHub user site (Pages hub)
├── RegiLattice/                    ← C# registry tweaks toolkit
├── SingleMethod/                   ← Python single-method scripts
├── SortComics/                     ← Python comic/media sorter
├── UbuntuEnhancer/                 ← Python Ubuntu setup utility
├── VHDXCompress/                   ← Python VHDX compressor
├── VSCode.RemoteSSH.Verifier/      ← Python SSH verifier
├── Wedding/                        ← TypeScript wedding manager
└── WoodworkingShop/                ← TypeScript woodworking project manager
```

## Adding a New Repository

1. Create a subfolder: `MyScripts/<RepoName>/`
2. Initialize git: `cd <RepoName> && git init && git branch -M main`
3. Add these **minimum required files**:

| File | Purpose |
|---|---|
| `README.md` | Purpose, quickstart, build/test, Pages URL |
| `.gitignore` | Language-appropriate (copy from `templates/`) |
| `index.html` | GitHub Pages landing page (see below) |
| `.github/workflows/pages.yml` | Auto-deploy to GitHub Pages |

1. Create the repo on GitHub: `gh repo create RajwanYair/<RepoName> --public --source=.`
2. Push: `git push -u origin main`
3. Enable GitHub Pages: Settings → Pages → Source: "GitHub Actions"

## GitHub Pages Expectations

Every repo **must** serve a site at:

```
https://rajwanyair.github.io/<RepoName>/
```

### Rules for `index.html`

- Place at repo root (or built to a deploy directory).
- **Use relative paths** for all assets:
  - `./css/style.css` (correct)
  - `/css/style.css` (broken — resolves to user site root)
- For SPAs with client-side routing, set `<base href="./">`.
- Non-web projects get a **landing page** linking to README, usage docs, and releases.
- The main `rajwanyair.github.io/index.html` catalog now loads RajwanYair public repositories dynamically from GitHub, so new repos do not require a manual card entry there.
- For generic README-driven landing pages, start from `templates/readme-index.html` and use its metadata overrides when the folder name differs from the GitHub repo name.

### Pages Workflow

Use the standard `pages.yml` from `templates/`:

```yaml
# .github/workflows/pages.yml
# Deploys repo root (or build output) to GitHub Pages
```

## Umbrella Root vs Repo Files

| Scope | Location | Examples |
|---|---|---|
| **Umbrella-wide** | `MyScripts/.vscode/`, `MyScripts/.github/` | VS Code settings, Copilot instructions, issue templates |
| **Repo-specific** | `<Repo>/.vscode/`, `<Repo>/.github/` | Language SDK paths, repo-specific workflows, CI |

### VS Code Settings Hierarchy

VS Code multi-root workspaces merge settings:

1. **Umbrella root** `.vscode/settings.json` — universal defaults (editor, terminal, formatting)
2. **Repo-level** `.vscode/settings.json` — language-specific overrides only (SDK paths, compile commands)

**Do not duplicate** umbrella settings inside repo folders.

## Git Hygiene

- Each repo should have `.gitignore` (see `templates/gitignore-python.txt` etc.)
- Each repo should have `.gitattributes` for consistent line endings
- Never commit secrets, credentials, or API keys
- Use Conventional Commits: `type(scope): description`

## Shared Web Guidance

For generic guidance that consolidates the working patterns from the web-facing projects in this workspace, use `docs/WEB_APP_BEST_PRACTICES.md`.

That guide captures the current workspace baseline for:

- shared JS/TS tool versions from the root `package.json`
- Vite, Vitest, ESLint, Playwright, Tailwind, and React usage guidance
- GitHub Pages deployment rules for SPAs and static sites
- layered frontend architecture, state, CSS, security, and testing practices
- workspace-level VS Code, GitHub, and Copilot integration patterns
- MCP (Model Context Protocol) server configuration best practices
- reusable quality scripts catalog (bundle analysis, architecture checks, i18n)
- CI/CD workflow catalog (security, quality, deployment)
- SVG and Mermaid diagram standards for documentation graphics

## MCP (Model Context Protocol) Setup

Every project should have a `.vscode/mcp.json` defining the MCP servers it uses. The workspace root provides a consolidated baseline at `.vscode/mcp.json`. New projects should start from `templates/mcp-template.json`.

Standard servers available to all projects:
- **GitHub** — PR, issue, workflow context
- **Fetch** — API testing and web content retrieval
- **Playwright** — browser automation and visual debugging
- **GitKraken** — git history, blame, PR workflow
- **Cloudflare** — Workers/Pages management (when applicable)
- **Filesystem** — scoped file access (workspace root only)

## Templates Directory

`templates/` contains starter files for new repositories:

| File | Purpose |
|---|---|
| `readme-index.html` | Generic README-style landing page for GitHub Pages |
| `pages-workflow.yml` | Static site deployment to GitHub Pages |
| `ci-web.yml` | CI workflow for TypeScript/Vite web projects |
| `security-workflows.yml` | Security scanning (CodeQL, Trivy, TruffleHog, Scorecard) |
| `copilot-setup-steps.yml` | Copilot coding agent environment setup |
| `mcp-template.json` | MCP server configuration for new projects |
| `eslint.config.mjs` | ESLint flat config extending shared base |
| `tsconfig-web.json` | TypeScript config for browser/Vite projects |
| `vite.config.ts` | Vite config extending shared base |
| `gitignore-python.txt` | Python .gitignore |
| `gitignore-web.txt` | Web/Node .gitignore |
| `gitignore-cpp.txt` | C++ .gitignore |
| `gitignore-dotnet.txt` | .NET .gitignore |
| `gitattributes-template.txt` | Git line-ending and diff rules |

## Documentation Graphics Rules

All documentation graphics must use SVG format:
- Use Mermaid fenced blocks for architecture, flow, and state diagrams
- Export complex diagrams as `.svg` with `.mmd` source files alongside
- Never use raster images (PNG/JPG) for diagrams or logos
- Store SVG assets in `docs/assets/` or `public/`
- Validate Mermaid syntax in CI using `validate-mermaid.mjs`
