---
applyTo: "**"
---

# Git Conventions — MyScripts Workspace

## Commit Message Format

Use [Conventional Commits](https://www.conventionalcommits.org/):

```text
<type>(<scope>): <subject>

[optional body]

[optional footer: Closes #N]
```

### Types

| Type       | When to use                                 |
| ---------- | ------------------------------------------- |
| `feat`     | New feature or capability                   |
| `fix`      | Bug fix                                     |
| `chore`    | Maintenance, tooling, config updates        |
| `refactor` | Code restructure without behaviour change   |
| `test`     | Adding or fixing tests                      |
| `docs`     | Documentation only                          |
| `ci`       | CI/CD workflow changes                      |
| `perf`     | Performance improvement                     |
| `style`    | Formatting, whitespace (no logic change)    |
| `revert`   | Reverts a previous commit                   |
| `build`    | Build system or external dependency changes |

### Scope

Use the project name or sub-system as scope. Examples:

- `feat(ProjectName): add configuration import command`
- `fix(ProjectName): handle symlinks in scan path`
- `chore(tooling): upgrade ESLint to v10`
- `ci: add dependency-review workflow`

### Subject Rules

- Lowercase, imperative mood: "add", "fix", "remove" — not "added", "fixes", "removing"
- No trailing period
- 72 characters max on first line
- Body (optional) explains WHY, not WHAT

## Branch Naming

```text
feat/<ProjectName>-<short-description>
fix/<ProjectName>-<issue-or-description>
chore/<description>
ci/<description>
```

Examples:

- `feat/ProjectName-new-feature`
- `fix/ProjectName-symlink-handling`
- `chore/upgrade-eslint-v10`

## Pull Request Rules

- Title must follow the same Conventional Commits format as the commit message
- Description must include:
  - **What changed** — bullet list of changes
  - **Why** — motivation (link to issue if applicable)
  - **Quality gates** — confirm typecheck, lint, tests pass
- Never force-push to `main`
- Squash merge preferred for feature branches; merge commit for releases

## Tagging

Releases are tagged as `<ProjectName>-vX.Y.Z`:

```bash
git tag -a "ProjectName-v1.0.0" -m "ProjectName v1.0.0"
git push origin --tags
```

## .gitignore Checklist

Every project must ignore these paths in `.gitignore`:

```gitignore
# Python
__pycache__/
*.pyc
*.pyo
.mypy_cache/
.ruff_cache/
.pytest_cache/
htmlcov/
*.egg-info/
dist/

# Node / TypeScript
node_modules/
dist/
.vite_cache/
.eslintcache

# Build artifacts
build/
*.o
*.obj
*.pdb

# IDE
.vscode/settings.json  # workspace-local overrides only — not global settings
*.suo
*.user

# OS
.DS_Store
Thumbs.db

# Secrets
.env
.env.local
*.pem
*.key
```

## Signing Commits (Optional but Recommended)

```bash
git config --global commit.gpgsign true
git config --global gpg.program gpg
```
