---
agent: agent
description: "Create a new Python project following the Universal Project Enhancement Framework v15.0.0 structure"
---

# Create New Project

Create a new Python project in this workspace following the **Universal Project Enhancement Framework v15.0.0**.

## Project Details

Project name: `${input:projectName}`
Description: `${input:description}`
Python minimum version: `${input:pythonVersion:3.9}`

## Required Output Structure

```text
${input:projectName}/
├── ${input:projectName}        # Entry point script (no .py extension)
├── README.md                   # Full documentation with badges
├── CHANGELOG.md                # Keep-a-Changelog format
├── LICENSE                     # MIT license
├── VERSION                     # Semver string e.g. 0.1.0
├── requirements.txt            # Runtime dependencies
├── pyproject.toml              # [project] + all tool configs from workspace root
├── pyrightconfig.json          # Copy from workspace root
├── .gitattributes              # Copy from workspace root
├── .markdownlint.json          # Copy from workspace root
├── src/
│   ├── __init__.py
│   ├── cli/
│   │   ├── __init__.py
│   │   └── main.py             # Click CLI entry point
│   ├── core/
│   │   ├── __init__.py
│   │   └── processor.py        # Main business logic
│   └── utils/
│       ├── __init__.py
│       └── helpers.py
├── config/
│   └── default.yaml            # App config with ${ENV_VAR:default} substitution
├── tests/
│   ├── conftest.py
│   ├── unit/
│   │   └── test_core.py
│   └── integration/
│       └── test_integration.py
├── docs/
│   └── README.md
└── .github/
    ├── copilot-instructions.md
    ├── CONTRIBUTING.md
    ├── SECURITY.md
    ├── CODEOWNERS
    ├── dependabot.yml
    ├── PULL_REQUEST_TEMPLATE.md
    ├── ISSUE_TEMPLATE/
    │   ├── bug_report.md
    │   ├── feature_request.md
    │   └── performance_issue.md
    ├── instructions/           # Copy all 4 from workspace .github/instructions/
    └── workflows/
        ├── ci.yml
        └── release.yml
```

## For Web Projects (TypeScript/Vite)

Add these files using templates from `templates/`:

```text
${input:projectName}/
├── index.html                  # Entry page (copy from templates/readme-index.html)
├── package.json                # Extends workspace shared deps
├── tsconfig.json               # Extends ../tooling/tsconfig/base-typescript.json
├── vite.config.ts              # Extends ../tooling/vite.base.ts
├── eslint.config.mjs           # Extends ../tooling/eslint/web-ts-app.mjs
├── vitest.config.ts            # Extends ../tooling/vitest/base.mjs
├── .vscode/
│   └── mcp.json                # Copy from templates/mcp-template.json
├── src/
│   ├── main.ts
│   ├── core/
│   ├── services/
│   └── styles/
├── tests/
│   └── unit/
└── .github/
    └── workflows/
        ├── ci.yml              # Copy from templates/ci-web.yml
        └── pages.yml           # Copy from templates/pages-workflow.yml
```

## MCP Configuration

Every project must include `.vscode/mcp.json` — copy from `templates/mcp-template.json`.

## Documentation Graphics

Use Mermaid fenced blocks for all diagrams in Markdown files. Never use PNG/JPG for diagrams.

## Code Standards

- Use Click 8.1+ for CLI
- Use Rich 13+ for terminal output
- Type hints everywhere
- Signal handlers (SIGTERM/SIGINT)
- Dataclasses for data structures
- Zero hardcoded paths (always `Path(__file__).parent.resolve()`)
- Google-style docstrings
- No bare `except:` clauses

## Entry Point Template

```python
#!/usr/bin/env python3
"""${input:projectName} — ${input:description}"""

import signal
import sys
from pathlib import Path

import click
from rich.console import Console

PROJECT_ROOT = Path(__file__).parent.resolve()
console = Console()


def handle_shutdown(signum: int, frame: object) -> None:
    console.print("\n[yellow]Shutting down gracefully...[/yellow]")
    sys.exit(0)


signal.signal(signal.SIGTERM, handle_shutdown)
signal.signal(signal.SIGINT, handle_shutdown)


@click.group()
@click.version_option(version="0.1.0")
def cli() -> None:
    """${input:description}"""


if __name__ == "__main__":
    cli()
```
