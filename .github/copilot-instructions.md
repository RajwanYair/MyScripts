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

```text
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

## React / TypeScript SPA Projects

> Full patterns: `.github/instructions/web-react.instructions.md` (auto-loaded for `src/**/*.{ts,tsx}`)
> Deep reference: `docs/REACT_SPA_PLAYBOOK.md`

When working on a React/TypeScript SPA sub-project:

### Mandatory constraints

- **Zero suppression**: no `eslint-disable`, `@ts-ignore`, `@ts-nocheck`, `as any`
- **TypeScript 6 strict**: `erasableSyntaxOnly: true` — no `enum`, no `namespace` — use `as const` + union types
- **$TEMP enforcement**: all build artifacts, coverage, test results go to `%TEMP%\ProjectName\`
- **Engine purity**: `src/engine/` — pure TypeScript, no React, no DOM, no side-effects
- **react-refresh rule**: `.tsx` files export **only** React components — utilities go to sibling `.ts` files
- **RTL-safe layout**: Tailwind logical properties (`ms-*`, `me-*`, `start-*`, `end-*`) — never `ml-*`/`mr-*`
- **i18n parity**: every `t('key')` must have entries in both `en.json` and `he.json`

### Quality gate (run before done)

```powershell
npm run typecheck     # tsc --noEmit — must exit 0
npm run lint          # ESLint flat config, --max-warnings 0
npm run i18n:coverage # en/he parity check
npm test              # Vitest
```

### What NOT to do (React SPA specific)

- Don't add `// eslint-disable-*` comments
- Don't use `as any` or `as unknown as T` without a type guard
- Don't add `enum` or `namespace` — use `as const`
- Don't skip `he.json` when adding i18n keys
- Don't hardcode colors — use design tokens or Tailwind semantic classes
- Don't put intermediate build files in the project dir — use `$TEMP`

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

MCP servers are configured in `.vscode/mcp.json` for VS Code and `.mcp.json`
for Copilot CLI and other compatible clients. Keep server names and pinned
package versions aligned between both files. VS Code uses password-masked
secret inputs; Copilot CLI reads `${BRAVE_API_KEY}` from the process environment.
Never commit API keys or tokens.

| Server               | Purpose                                                                                                  |
| -------------------- | -------------------------------------------------------------------------------------------------------- |
| `github`             | Official GitHub MCP — PRs, issues, workflows, code search                                                |
| `fetch`              | Retrieve web content and API responses                                                                   |
| `filesystem`         | Scoped workspace file access                                                                             |
| `playwright`         | Browser automation for E2E debugging                                                                     |
| `gitkraken`          | Git ops, blame, diff, PR workflow                                                                        |
| `cloudflare`         | Cloudflare Pages/Workers management                                                                      |
| `memory`             | Persistent agent notes across sessions                                                                   |
| `sequentialthinking` | Multi-step problem decomposition                                                                         |
| `context7`           | Up-to-date library documentation (React, Vite, pytest, etc.)                                             |
| `brave-search`       | Web search for docs, blog posts, and solutions not in Context7                                           |
| `chrome-devtools`    | Isolated Chrome debugging, console/network inspection, and performance traces; usage statistics disabled |

The Filesystem server is limited to `${workspaceFolder}` in VS Code and `.`
in Copilot CLI. Pass `excludePatterns` to recursive `search_files` and
`directory_tree` tool calls to omit `.git`, dependency, build, and coverage paths;
do not pass unsupported `--exclude` server arguments.
Chrome DevTools can inspect browser content; do not use it with sensitive
sessions or data.

## Copilot Customization Assets

| Type         | Location                                              | Purpose                                                                  |
| ------------ | ----------------------------------------------------- | ------------------------------------------------------------------------ |
| Instructions | `.github/instructions/*.instructions.md`              | File-scoped rules via `applyTo:` globs                                   |
| Prompts      | `.github/prompts/*.prompt.md`                         | Reusable task workflows — see table below                                |
| Agents       | `.github/agents/*.agent.md`                           | Custom agent definitions — see table below                               |
| Skills       | `.github/skills/*/SKILL.md`                           | Portable task workflows (release, security-audit, workspace-maintenance) |
| AGENTS.md    | `.github/AGENTS.md`                                   | Agent guide with all available assets                                    |
| Memory       | `/memories/`, `/memories/session/`, `/memories/repo/` | Three-tier persistent notes                                              |

### Available Agents

| Agent             | Purpose                                                                |
| ----------------- | ---------------------------------------------------------------------- |
| `new-project`     | Scaffold a new sub-project from workspace template                     |
| `upgrade-tooling` | Upgrade shared tooling configs and shared scripts                      |
| `security-audit`  | OWASP Top 10 security audit (Python + TypeScript)                      |
| `web-sprint`      | Execute a TypeScript/React sprint item end-to-end                      |
| `web-feature`     | Scaffold a complete React feature (engine + store + UI + i18n)         |
| `debug`           | Diagnose and fix test/build/runtime failures without suppression       |
| `release`         | Full release workflow: version bump → CHANGELOG → tag → GitHub Release |
| `cleanup`         | Production cleanup: dead code, lint, $TEMP enforcement, quality gate   |

### Available Prompts

| Prompt                  | Purpose                                              |
| ----------------------- | ---------------------------------------------------- |
| `a11y-audit`            | WCAG 2.2 AA accessibility audit and remediation      |
| `bundle-optimize`       | Bundle size analysis and chunk optimization          |
| `code-review`           | Structured code review against project conventions   |
| `create-project`        | Create a project from the workspace template         |
| `csp-hardening`         | Harden Content Security Policy                       |
| `dependency-update`     | Safely audit and update dependencies                 |
| `fix-lint`              | Fix lint and type errors                             |
| `fix-quality`           | Diagnose and fix quality gate failures               |
| `fix-tests`             | Diagnose and fix failing unit tests                  |
| `i18n-add-keys`         | Add translation keys with locale parity              |
| `lighthouse-ci`         | Configure and troubleshoot Lighthouse CI             |
| `modernize-tooling`     | Audit and modernize VS Code and CI tooling           |
| `new-web-feature`       | Add a web feature across engine, store, UI, and i18n |
| `parametrize-tests`     | Convert repetitive tests to parametrized cases       |
| `perf-debug`            | Diagnose and fix web performance issues              |
| `roadmap-sprint`        | Execute a roadmap sprint item with quality gates     |
| `security-audit`        | OWASP security audit for client-side applications    |
| `split-component`       | Split oversized React components                     |
| `version-bump`          | Update project version metadata                      |
| `workspace-maintenance` | Check workspace and project health                   |
| `write-tests`           | Generate tests for existing functionality            |

- **Skills auto-discovery**: When a skill matches the request, load it with `read_file` before acting.
- **Subagents**: Use `runSubagent` for multi-file exploration and complex tasks.
- **Batch edits**: Use `multi_replace_string_in_file` for 2+ independent edits.
- **Code intelligence**: Use `vscode_listCodeUsages` before renaming/removing exports.
- **Extension shortcuts**: Prefer `get_errors` over terminal for lint/type/spell diagnostics.
- **Copilot NES**: `github.copilot.nextEditSuggestions.enabled: true` is on in all workspaces — leverage it for sequential edits.
- **PR description**: `pullRequestDescriptionGeneration.instructions` is configured — AI-generated descriptions follow Conventional Commits.
- **Test generation**: `testGeneration.instructions` is configured — generated tests use `it.each` with deterministic fixtures.
