# Workspace Architecture

> **Scope**: This document describes the **root workspace** (`MyScripts/`).
> Each sub-project owns its own architecture docs inside its own repo.

## Mission

`MyScripts/` is a **generic template workspace** and a **shared tooling
aggregator**. It contains nothing that ships to end users; it ships
*conventions, configs, scripts, templates, and a developer hub* that all
sub-projects consume.

The root is **not** a deployable web app. Its only runtime surface is the
static [hub `index.html`](../index.html) for local navigation and
discoverability.

## High-level diagram

```mermaid
flowchart TB
    subgraph Root[" MyScripts/ — shared workspace (this repo) "]
        direction TB
        Hub["index.html<br/>(hub page)"]
        Tooling["tooling/<br/>ESLint · TS · Vitest · Vite · Prettier ·<br/>Stylelint · Playwright · HTMLHint · Markdownlint"]
        Scripts["scripts/<br/>validate-mermaid · check-bundle-size ·<br/>check-test-focus-skip"]
        Templates["templates/<br/>CI · gitignores · MCP · ESLint/Vite/TSConfig"]
        GH[".github/<br/>workflows · CODEOWNERS · CONTRIBUTING ·<br/>SECURITY · ISSUE_TEMPLATE · PULL_REQUEST"]
        VSC[".vscode/<br/>settings · tasks · extensions · mcp"]
        Docs["docs/<br/>ARCHITECTURE · WORKSPACE_GUIDE ·<br/>WEB_APP_BEST_PRACTICES"]
        Pkg["package.json + node_modules/<br/>(shared deps for all TS sub-projects)"]
        Py["pyproject.toml<br/>(shared tool configs for all Python sub-projects)"]
    end

    subgraph Subs[" Sub-projects (independent repos, gitignored at root) "]
        direction TB
        Web["Web / TypeScript<br/>BudgetManager · CrossTide · CrossTideWeb ·<br/>FamilyDashBoard · Wedding · WoodworkingShop ·<br/>rajwanyair.github.io"]
        Pys["Python CLIs<br/>DupDetector · FileNameManipulator ·<br/>FileProcessor · OptimizeBrowsers ·<br/>OptimizeWIN_n_WSL · PPA · SingleMethod ·<br/>SortComics · UbuntuEnhancer · VHDXCompress ·<br/>VSCode.RemoteSSH.Verifier"]
        Native["Native<br/>ExplorerLens.io (C++) · RegiLattice (C#)"]
    end

    Hub -- "links to local + Pages" --> Web
    Hub -- "links to GitHub" --> Pys
    Hub -- "links to GitHub" --> Native

    Tooling -. "extends/imports via ../tooling/" .-> Web
    Pkg -. "resolves shared deps from ../node_modules/" .-> Web
    Py -. "ruff · mypy · pytest configs" .-> Pys

    Templates -. "scaffold seed" .-> Web
    Templates -. "scaffold seed" .-> Pys
    Templates -. "scaffold seed" .-> Native

    GH -. "Copilot prompts/instructions reference" .-> Web
    GH -. "Copilot prompts/instructions reference" .-> Pys
```

## CI flow at the root

```mermaid
flowchart LR
    Push[Push / PR / Tag] --> CI[CI workflow]
    CI --> ToolLint[Tooling lint &<br/>config JSON validation]
    CI --> MdLint[Markdown lint]
    CI --> TplValidate[Template YAML/HTML<br/>validation]
    CI --> LinkCheck[Hub index.html<br/>link health]
    Tag[git tag v*.*.*] --> Rel[Release workflow]
    Rel --> Archive[Build template archive<br/>+ sha256 checksums]
    Rel --> GHRel[GitHub Release with<br/>attached assets]
    Push --> Sec[Security workflow]
    Sec --> CodeQL & Trivy & TruffleHog & NpmAudit
```

## Key invariants

1. **No sub-project files are tracked at the root.** Each sub-project lives
   in its own GitHub repo and is cloned alongside; root `.gitignore` excludes
   all sub-project directories.
2. **Single source of truth for shared configs**, in [tooling/](../tooling/).
   Sub-projects `extends`/`import` these via `../tooling/` — never copy.
3. **One `node_modules` per machine**, at the root. Sub-projects must not run
   `npm install` locally.
4. **Root CI never depends on sub-project state** — it only validates files
   the root owns (tooling, templates, docs, scripts, hub).
5. **No secrets in repo** — use GitHub Secrets / `.env` (gitignored).
6. **Portable paths only** — no absolute paths, no `${userHome}`-specific
   values in committed configs.

## Decision log (short)

| Decision | Rationale |
|---------|-----------|
| Flat workspace (no Nx/Turborepo) | Sub-projects are independent product repos with separate release cadences; monorepo tooling would add coupling without benefit. |
| Static `index.html` at root, separate dynamic hub at `rajwanyair.github.io` | Root hub is for **local** dev navigation; live hub auto-syncs from the GitHub API. Drift is acceptable because each serves a different audience. |
| Node 22 (CI) + Python 3.9+ (root configs only) | Long-term-support versions; matches sub-project requirements. |
| `softprops/action-gh-release@v2` + sha256 sidecar | Modern, maintained action with checksum support for supply-chain integrity. |

See also: [WORKSPACE_GUIDE.md](WORKSPACE_GUIDE.md) and [ROADMAP.md](../ROADMAP.md).
