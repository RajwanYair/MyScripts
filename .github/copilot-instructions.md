# GitHub Copilot Instructions

## Project Overview

Cross-platform Python development workspace containing multiple utility and automation projects.
All projects follow the Universal Project Enhancement Framework v15.0.0.

## Technical Stack

- **Language**: Python 3.9+ (prefer system-wide installation over virtual environments)
- **CLI Framework**: Click 8.1+ or argparse with Rich 13.0+ for beautiful terminal output
- **Configuration**: Pydantic 2.0+ models, YAML config files with environment variable substitution
- **Packaging**: Modern PEP 517/518 with hatchling or setuptools build backend
- **Testing**: pytest with coverage, GitHub Actions CI/CD

## Key Architecture Patterns

### Single Entry Point

- One main executable per project with command routing
- All functionality accessible via CLI, Desktop GUI (Tkinter), and Web GUI (FastAPI)
- Shared backend services used by all interfaces

### Portability First

```python
# ✅ Good - Always use relative paths
PROJECT_ROOT = Path(__file__).parent.resolve()
config = PROJECT_ROOT / "config" / "default.yaml"

# ❌ Bad - Never hardcode absolute paths
config = "C:\\Users\\name\\project\\config.yaml"
```

### Configuration Hierarchy

1. Command-line arguments (highest priority)
2. Environment variables
3. User configuration file
4. Default configuration (lowest priority)

## Coding Standards

### Python Best Practices

```python
# Use type hints everywhere
def process_item(
    item: str,
    verbose: bool = False,
    callback: Callable[[int, int], None] | None = None,
) -> ProcessResult:
    ...

# Use dataclasses for data structures
@dataclass
class ProcessResult:
    success: bool
    message: str
    duration: float = 0.0

# Use Enum for constants
class Status(str, Enum):
    PENDING = "pending"
    RUNNING = "running"
    COMPLETE = "complete"
```

### File Organization

```
project-root/
├── project-name          # Single entry point (no .py)
├── README.md
├── LICENSE, VERSION, requirements.txt
├── src/                  # cli/, core/, gui/, utils/
├── config/               # YAML configs
├── tests/                # pytest suite
└── docs/                 # Documentation
```

### Error Handling

- Always use specific exception types
- Provide meaningful error messages
- Implement graceful degradation
- Log errors with context

### Signal Handling

```python
import signal
import sys

def handle_shutdown(signum, frame):
    print("\nShutting down gracefully...")
    cleanup()
    sys.exit(0)

signal.signal(signal.SIGTERM, handle_shutdown)
signal.signal(signal.SIGINT, handle_shutdown)
```

## Package Management Philosophy

### Preference Order

1. **System packages** (apt, yum, brew) - Most stable
2. **pip with --break-system-packages** - For packages not in apt
3. **User install** (pip --user) - Fallback

### Requirements Files

- `requirements.txt` - Python packages (pip)
- `apt-packages.txt` - System packages (apt)

## Testing Requirements

- 90%+ code coverage goal
- Use pytest with pytest-cov
- Test on Windows, Linux, WSL, and macOS
- Include unit, integration, and cross-platform tests

## Documentation Standards

- Comprehensive README.md with examples
- QUICK_START.md for getting started
- CONFIGURATION.md for all settings
- Inline docstrings (Google style)
- Type hints for all functions

## Security Guidelines

- No hardcoded credentials or secrets
- No hardcoded proxy URLs - use configuration
- Use environment variables for sensitive data
- Validate all user input
- Use parameterized commands (no shell injection)

## Common Patterns

### Progress Tracking

```python
from rich.progress import Progress

with Progress() as progress:
    task = progress.add_task("Processing...", total=len(items))
    for item in items:
        process(item)
        progress.update(task, advance=1)
```

### Configuration Loading

```yaml
# config/default.yaml
app:
    name: "${APP_NAME:My Application}"
    debug: "${DEBUG:false}"
network:
    timeout: "${TIMEOUT:30}"
    proxy:
        enabled: "${PROXY_ENABLED:false}"
        url: "${PROXY_URL:}"
```

### CLI with Click

```python
import click
from rich.console import Console

console = Console()

@click.command()
@click.option('--verbose', '-v', is_flag=True)
@click.option('--config', '-c', type=click.Path(exists=True))
def main(verbose: bool, config: str | None):
    """Main entry point."""
    console.print("[green]Starting...[/green]")
```

## What NOT to Do

- Don't hardcode absolute paths
- Don't skip signal handlers
- Don't use print() - use logging or rich.console
- Don't leave debug code in production
- Don't commit secrets or credentials
- Don't create multiple entry points
- Don't skip tests for "simple" code

## Shell / Terminal

> **OS: Windows · Shell: PowerShell** — Every terminal command MUST use PowerShell syntax. Never use Unix/bash commands.
> Forbidden: `tail`, `grep`, `cat`, `head`, `find`, `ls`, `rm`, `cp`, `mv`, `touch`, `export VAR=`, `&&`.
> Use instead: `Select-Object -Last N`, `Select-String`, `Get-Content`, `Get-ChildItem`, `Remove-Item`, `Copy-Item`, `Move-Item`, `New-Item`, `$env:VAR =`. Chain with `;` not `&&`.

## MCP Servers

MCP servers are configured in `.vscode/mcp.json`. Available servers: github, fetch, filesystem, playwright, gitkraken, cloudflare.
- **Transport types**: `stdio` (local), `http` (Copilot-managed), `streamableHttp` (modern remote). Never use deprecated `sse`.
- **Deferred tools**: Always call `tool_search` before using any MCP-provided tool. Do not retry if first search returns no results.
- **Template**: `templates/mcp-template.json` has the starter MCP config for new projects.

## Copilot Customization Assets

| Type | Location | Purpose |
| --- | --- | --- |
| Instructions | `.github/instructions/*.instructions.md` | File-scoped rules via `applyTo:` globs |
| Prompts | `.github/prompts/*.prompt.md` | Reusable task workflows (lint, review, release, security) |
| Skills | `.github/skills/*/SKILL.md` | Domain-specific knowledge (release, security-audit) |
| AGENTS.md | `.github/AGENTS.md` | Agent guide with all available assets |
| Memory | `/memories/`, `/memories/session/`, `/memories/repo/` | Three-tier persistent notes |

- **Skills auto-discovery**: When a skill matches the request, load it with `read_file` before acting.
- **Subagents**: Use `runSubagent` for multi-file exploration and complex tasks.
- **Batch edits**: Use `multi_replace_string_in_file` for 2+ independent edits.
- **Code intelligence**: Use `vscode_listCodeUsages` before renaming/removing exports.
- **Extension shortcuts**: Prefer `get_errors` over terminal for lint/type/spell diagnostics.
