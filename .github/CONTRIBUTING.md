# Contributing Guidelines

Thank you for contributing to the MyScripts workspace!
This document covers setup and standards for all project types (web/TypeScript and Python).

## Code of Conduct

- Be respectful and inclusive
- Provide constructive feedback
- Focus on the issue, not the person

---

## Development Setup

### Prerequisites

- **Node.js 22+** (for web/TypeScript projects)
- **Python 3.9+** (for Python projects)
- **Git**
- **VS Code** with recommended extensions (see `.vscode/extensions.json`)

### Setup Steps

1. Clone the repository.

2. Install JS/TS shared dependencies (run **once at the workspace root**):

   ```powershell
   npm install
   ```

3. Install Python tools (workspace-wide):

   ```powershell
   pip install -r requirements.txt
   pip install pytest pytest-cov ruff mypy bandit
   ```

4. (Optional) Install pre-commit hooks:

   ```bash
   pip install pre-commit
   pre-commit install
   ```

---

## Coding Standards

### Web / TypeScript

- **Framework**: Vite 8 + TypeScript 6 (strict mode)
- **Testing**: Vitest 4 (unit) + Playwright 1.59 (E2E)
- **Linting**: ESLint 10 flat config (`--max-warnings 0`)
- **Formatting**: Prettier (config via `tooling/prettier.base.json`)
- **CSS**: Stylelint (`tooling/stylelint/base.cjs`)
- **HTML**: HTMLHint (`tooling/htmlhint/base.json`)
- Sub-project configs must **extend** from `../tooling/` — no duplication
- Run `npm install` at workspace root only; never inside a sub-project

```typescript
// Always use strict types
function processItem(item: string, verbose = false): ProcessResult {
  // ...
}
```

### Python

- **Style**: PEP 8, 100-character line limit
- **Type hints**: required on every function
- **Docstrings**: Google style
- **Formatting**: `ruff format`
- **Linting**: `ruff check`
- **Security**: `bandit -r src/ -ll`
- No hardcoded absolute paths — use `Path(__file__).parent.resolve()`
- No bare `except:` — use specific exception types

```python
from pathlib import Path
from dataclasses import dataclass

@dataclass
class Result:
    success: bool
    message: str

def process_file(file_path: Path, verbose: bool = False) -> Result:
    if not file_path.exists():
        return Result(success=False, message=f"File not found: {file_path}")
    return Result(success=True, message="Processed")
```

---

## Running Quality Checks

### Web projects (from within the sub-project dir)

```powershell
npx eslint . --max-warnings 0
npx tsc -b --noEmit
npx vitest run --coverage
npx vite build
```

### Python projects (from workspace root)

```powershell
python -m ruff check src/ tests/
python -m ruff format --check src/ tests/
python -m mypy src/ --ignore-missing-imports
python -m bandit -r src/ -ll
python -m pytest tests/ -v --cov=src --cov-report=term-missing
```

### Workspace-level validation (root)

```powershell
npm run check
```

---

## Pull Request Process

1. **Branch** from `main`: `git checkout -b feat/my-feature` or `fix/issue-123`
2. **Commit** with [Conventional Commits](https://www.conventionalcommits.org/):
   `feat:`, `fix:`, `docs:`, `chore:`, `ci:`, `refactor:`
3. **Run quality checks** for the affected stack (see above)
4. **Push** and open a PR against `main`
5. Fill in the PR template completely
6. Ensure CI passes before requesting review

### Commit Message Format

```text
type(scope): short description

Longer explanation if needed.

Closes #123
```

---

## Testing Requirements

- **Web**: 90%+ line/branch coverage via Vitest; E2E via Playwright for user flows
- **Python**: 90%+ coverage via pytest-cov
- Add tests for all new functionality; update tests for changed behaviour

---

## Questions?

Open a GitHub Issue for questions or to discuss potential contributions.
