---
applyTo: "**"
---

# GitHub Copilot Workspace Instructions

## Project Overview

Cross-platform Python development workspace containing multiple utility and automation projects.
All projects follow the **Universal Project Enhancement Framework v15.0.0**.

## Projects in this Workspace

| Project | Description | Language |
| --- | --- | --- |
| `BudgetManager` | Budget tracking web app | TypeScript |
| `CrossTide` | Stock crossover analysis app | TypeScript |
| `CrossTideWeb` | CrossTide web companion | TypeScript |
| `DupDetector` | Duplicate file finder | Python |
| `ExplorerLens.io` | Windows Shell extension | C++ |
| `FamilyDashBoard` | Family TV dashboard | TypeScript |
| `FileNameManipulator` | Filename utility | Python |
| `FileProcessor` | File processing pipeline | Python |
| `OptimizeBrowsers` | Browser optimizer | Python |
| `OptimizeWIN_n_WSL` | Windows/WSL optimizer | Python |
| `PPA` | PPA automation | Python |
| `RegiLattice` | Registry tweaks toolkit | C# |
| `SingleMethod` | Single-method scripts | Python |
| `SortComics` | Comic/media sorter | Python |
| `UbuntuEnhancer` | Ubuntu setup utility | Python |
| `VHDXCompress` | VHDX compressor | Python |
| `VSCode.RemoteSSH.Verifier` | SSH verifier | Python |
| `Wedding` | Wedding manager | TypeScript |
| `WoodworkingShop` | Woodworking project manager | TypeScript |

## Technical Stack

- **Language**: Python 3.9+ (prefer system-wide installation over virtual environments)
- **CLI Framework**: Click 8.1+ or argparse with Rich 13.0+
- **Configuration**: Pydantic 2.0+ models, YAML with `${ENV_VAR:default}` substitution
- **Packaging**: PEP 517/518 with hatchling build backend
- **Testing**: pytest with coverage, GitHub Actions CI/CD
- **Linting**: ruff (primary — replaces flake8, black, isort)
- **Formatting**: ruff format
- **Type Checking**: mypy + pyright/pylance
- **Web Stack**: Vite 8 + TypeScript 6 + Vitest 4 + Playwright 1.59 + ESLint 10 flat config
- **MCP**: GitHub, Fetch, Playwright, GitKraken servers (see `.vscode/mcp.json`)
- **CI/CD**: GitHub Actions with pinned action versions
- **Documentation Graphics**: SVG and Mermaid (never raster images for diagrams)

## Core Architecture Patterns

### Centralized Tools (MyScripts/ = Single Source of Truth)

All development tools, shared configs, and dependencies live at the `MyScripts/` root.
Sub-projects reference them via `../tooling/` and the root `node_modules/`.

- **JS/TS deps**: `npm install` at root only — sub-projects resolve from `../node_modules/`
- **Python tools**: root `pyproject.toml` configures ruff, mypy, pytest, coverage for all projects
- **Base configs**: `tooling/` (ESLint, TypeScript, Vitest, Vite, Prettier, Playwright, etc.)
- **Shared scripts**: `scripts/` (Mermaid validation, bundle checks, test guards)
- **Templates**: `templates/` (CI workflows, gitignore, config scaffolds)
- **MCP servers**: `.vscode/mcp.json` (workspace-wide)
- Sub-projects contain ONLY: source code, project-specific overrides, and `extends`/`import` refs

### Single Entry Point

- One main executable per project with command routing
- All functionality via CLI, Desktop GUI (Tkinter), and Web GUI (FastAPI)
- Shared backend services

### Portability First

```python
# ✅ Always use relative paths
PROJECT_ROOT = Path(__file__).parent.resolve()
config = PROJECT_ROOT / "config" / "default.yaml"

# ❌ Never hardcode absolute paths
config = "C:\\Users\\name\\project\\config.yaml"
```

### Configuration Hierarchy (highest → lowest priority)

1. Command-line arguments
2. Environment variables (`${VAR:default}` in YAML)
3. User config file
4. Default config

### Standard Project Structure

```
project-name/
├── project-name          # Single entry point (no .py extension)
├── README.md
├── CHANGELOG.md
├── LICENSE
├── VERSION
├── requirements.txt
├── pyproject.toml        # Tool configs (ruff, mypy, pytest, coverage)
├── pyrightconfig.json    # Pyright/Pylance settings
├── src/
│   ├── cli/              # Click commands
│   ├── core/             # Business logic
│   ├── gui/              # Tkinter desktop GUI
│   └── utils/            # Shared helpers
├── config/
│   └── default.yaml      # Default configuration
├── tests/
│   ├── conftest.py
│   ├── unit/
│   └── integration/
└── docs/
```

## Coding Standards

### Type Hints — Required Everywhere

```python
from typing import Callable
from pathlib import Path

def process_item(
    item: str,
    verbose: bool = False,
    callback: Callable[[int, int], None] | None = None,
) -> ProcessResult:
    ...
```

### Data Classes Over Dicts

```python
from dataclasses import dataclass, field

@dataclass
class ProcessResult:
    success: bool
    message: str
    duration: float = 0.0
    errors: list[str] = field(default_factory=list)
```

### Enums for Constants

```python
from enum import Enum

class Status(str, Enum):
    PENDING = "pending"
    RUNNING = "running"
    COMPLETE = "complete"
    FAILED = "failed"
```

### Error Handling

- Use specific exception types (never bare `except:`)
- Provide meaningful messages with context
- Implement graceful degradation
- Log errors with full context

### Signal Handling — Always Implement

```python
import signal
import sys

def handle_shutdown(signum: int, frame: object) -> None:
    print("\nShutting down gracefully...")
    cleanup()
    sys.exit(0)

signal.signal(signal.SIGTERM, handle_shutdown)
signal.signal(signal.SIGINT, handle_shutdown)
```

### Progress Tracking — Use Rich

```python
from rich.progress import Progress, SpinnerColumn, TimeElapsedColumn

with Progress(SpinnerColumn(), *Progress.get_default_columns(), TimeElapsedColumn()) as progress:
    task = progress.add_task("Processing...", total=len(items))
    for item in items:
        process(item)
        progress.advance(task)
```

### CLI Entry Points — Use Click

```python
import click
from rich.console import Console

console = Console()

@click.command()
@click.option("--verbose", "-v", is_flag=True, help="Enable verbose output")
@click.option("--config", "-c", type=click.Path(exists=True), help="Config file path")
@click.version_option(version="1.0.0")
def main(verbose: bool, config: str | None) -> None:
    """Project description here."""
    console.print("[green]Starting...[/green]")
```

## Package Management

### Preference Order

1. **System packages** (`apt`, `yum`, `brew`) — most stable
2. **pip** (`--break-system-packages`) — for packages not in system repos
3. **User install** (`pip --user`) — fallback only

### Never Use venv by Default

Unless explicitly requested, install system-wide.

## Testing Requirements

- **Goal**: 90%+ code coverage
- **Framework**: pytest with pytest-cov
- **Platforms**: Windows, Linux, WSL, macOS
- **Types**: unit + integration + cross-platform
- **Hypothesis**: property-based tests for complex logic

## Documentation Standards

- `README.md` — comprehensive with examples and badges
- `CHANGELOG.md` — Keep-a-Changelog format
- `docs/` — MkDocs with Material theme
- Google-style docstrings
- Type hints = documentation

## Security Guidelines (OWASP)

- **No hardcoded credentials** — use environment variables or keyring
- **No hardcoded proxy URLs** — use configuration files
- **Validate all user input** — at system boundaries
- **Parameterized commands** — never build shell strings from user input
- **Least privilege** — request admin only when necessary
- **No secrets in git** — `.env` files in `.gitignore`

## What NOT to Do

- Don't hardcode absolute paths anywhere
- Don't skip signal handlers (SIGTERM/SIGINT)
- Don't use `print()` — use `logging` or `rich.console`
- Don't leave debug code in production paths
- Don't commit secrets, credentials, or API keys
- Don't create multiple entry points per project
- Don't skip tests for "simple" code
- Don't use bare `except:` clauses
- Don't use mutable default arguments
- Don't add lint/security suppressions without documented justification
- Don't use raster images (PNG/JPG) for documentation diagrams
- Don't duplicate shared tooling configs — extend from `tooling/`
- Don't install separate `node_modules` per child web project without reason

## MCP (Model Context Protocol)

- Workspace MCP config is at `.vscode/mcp.json`
- New projects use `templates/mcp-template.json` as starting point
- Standard servers: GitHub, Fetch, Playwright, GitKraken, Cloudflare
- Add project-specific servers only when needed (Supabase, etc.)
- Always set `"description"` field for discoverability
- Use `--read-only` for database servers unless writes are explicitly needed
- MCP tools are available to Copilot agents via `tool_search` — prefer them for repo context

## Copilot Integration

- **Instructions** (`.github/instructions/*.instructions.md`): path-scoped rules via `applyTo` frontmatter
- **Prompts** (`.github/prompts/*.prompt.md`): reusable slash-command prompts with `description` and `mode`
- **Agents** (`.github/AGENTS.md`): workspace-level agent operating guide
- **Custom agents**: define in `.github/agents/<name>.md` with tools, instructions, and description
- Use `${file}`, `${selection}`, `${input:name}` variables in prompts
- Prefer `agent` mode for multi-step prompts, `ask` mode for information queries

## Web Project Standards

For TypeScript/JavaScript web projects in this workspace:

- Extend shared configs from `tooling/` (ESLint, Vite, Vitest, TypeScript, Playwright)
- Use vanilla TypeScript + semantic CSS by default; React only when justified
- Deploy to GitHub Pages with `base: "./<repo-name>/"`
- Use relative asset paths (never absolute `/` paths)
- Validate Mermaid diagrams in CI
- Use DOMPurify for HTML sanitization, Valibot/Zod for schema validation
- Keep secrets out of client bundles

## Documentation Graphics

- Use Mermaid fenced blocks for diagrams (GitHub renders natively)
- Export to SVG when styling control is needed; keep `.mmd` source alongside
- Never use PNG/JPG for flowcharts, architecture diagrams, or logos
- Store SVG assets in `docs/assets/` or `public/`
