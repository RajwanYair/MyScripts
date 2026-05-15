# MyScripts

Centralized development workspace containing multiple independent projects with
shared tooling, quality gates, and CI/CD infrastructure.

## Architecture

```
MyScripts/                          ← Centralized tools (single source of truth)
├── tooling/                        ← Shared base configs
├── scripts/                        ← Quality scripts (Mermaid, bundle, test guards)
├── templates/                      ← Starter files for new repos
├── package.json + node_modules/    ← Shared JS/TS dependencies
├── pyproject.toml                  ← Shared Python tool configs
├── .github/                        ← Instructions, prompts, workflows, templates
├── .vscode/                        ← Shared editor settings + MCP servers
│
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
├── RegiLattice/                    ← C# registry tweaks toolkit
├── SingleMethod/                   ← Python single-method scripts
├── SortComics/                     ← Python comic/media sorter
├── UbuntuEnhancer/                 ← Python Ubuntu setup utility
├── VHDXCompress/                   ← Python VHDX compressor
├── VSCode.RemoteSSH.Verifier/      ← Python SSH verifier
├── Wedding/                        ← TypeScript wedding manager
└── WoodworkingShop/                ← Woodworking project manager
```

## Quickstart

```powershell
# JS/TS projects — install shared dependencies (once, at root)
npm install

# Python projects — tools configured in pyproject.toml
pip install ruff mypy pytest pytest-cov bandit

# Run quality checks
python -m ruff check src/ tests/
python -m pytest tests/ -v
```

## Centralization Policy

All development tools live at this root level. Sub-projects **must not**:
- Run `npm install` locally (they resolve from `../node_modules/`)
- Duplicate configs from `tooling/` (they `extends`/`import` via `../tooling/`)
- Install separate linting/formatting tools

Sub-projects contain **only**: source code, project-specific config overrides,
and relative references to shared bases.

## Shared Tools

| Resource | Path | Purpose |
|----------|------|---------|
| Base configs | `tooling/` | ESLint, TypeScript, Vitest, Vite, Prettier, Playwright |
| Python configs | `pyproject.toml` | ruff, mypy, pytest, coverage, bandit |
| Quality scripts | `scripts/` | Mermaid validation, bundle-size checks, test guards |
| CI templates | `templates/` | Workflows, gitignore, config scaffolds |
| MCP servers | `.vscode/mcp.json` | GitHub, Fetch, Playwright, GitKraken, Cloudflare |
| Copilot rules | `.github/instructions/` | Python, testing, CI/CD, workspace conventions |
| Copilot prompts | `.github/prompts/` | Code review, project creation, quality fixes, tests |

## Documentation

- [Architecture](docs/ARCHITECTURE.md) — workspace diagram, invariants, decision log
- [Workspace Guide](docs/WORKSPACE_GUIDE.md) — operating procedures, new repo setup
- [Web Best Practices](docs/WEB_APP_BEST_PRACTICES.md) — consolidated web standards
- [Tooling README](tooling/README.md) — how to extend shared configs
- [Roadmap](ROADMAP.md) — phased improvement plan
- [Changelog](CHANGELOG.md) — versioned release notes (root workspace only)
- [Contributing](.github/CONTRIBUTING.md) — development setup and PR process
- [Security](.github/SECURITY.md) — vulnerability reporting
