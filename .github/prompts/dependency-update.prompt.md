---
description: >
  Review and safely apply dependency updates across all sub-projects —
  security patches applied immediately, minor/major updates reviewed first.
---

# Dependency Update Review

Audit and apply dependency updates across the MyScripts workspace following
the safe-update policy: security patches are applied immediately; minor/major
updates are reviewed for breaking changes first.

## Step 1 — Identify Outdated Dependencies

### Node.js (root + TypeScript sub-projects)

```bash
# Root workspace
npm outdated --depth=0

# Each TypeScript sub-project
cd <TypeScriptProject> && npm outdated --depth=0
```

### Python (each sub-project with requirements.txt)

```bash
pip list --outdated --format=columns
```

## Step 2 — Security Vulnerabilities First

```bash
# Node
npm audit --audit-level=moderate --json

# Python
pip-audit --format=json -r requirements.txt
```

Apply ALL security patches immediately regardless of semver bump:

```bash
npm audit fix
```

For Python: manually update the pinned version in `requirements.txt` after verifying
the patched version is compatible.

## Step 3 — Categorize Updates

For each outdated package, classify as:

| Package | Current | Latest | Type  | Action                       |
| ------- | ------- | ------ | ----- | ---------------------------- |
| example | 1.2.3   | 1.2.5  | patch | ✅ safe — apply              |
| example | 1.2.3   | 1.5.0  | minor | 🔍 review changelog          |
| example | 1.2.3   | 2.0.0  | major | ⚠️ breaking changes possible |

## Step 4 — Apply Patch Updates (Node)

```bash
# Apply patch updates only (does not touch major/minor)
npm update
```

Verify nothing broke:

```bash
npx tsc --noEmit && npx vitest run --reporter=dot
```

## Step 5 — Apply Patch Updates (Python)

Update `requirements.txt` to use the latest patch version for each package.

Verify nothing broke:

```bash
pip install -r requirements.txt
pytest tests/ -x -q
```

## Step 6 — Review Minor/Major Updates

For each minor/major update:

1. Read the package CHANGELOG from the release notes URL
2. Check if any public API used in this workspace has changed
3. Update if safe; add a comment in the PR describing why it's safe
4. If breaking: open a tracking issue — do NOT update now

## Step 7 — Update Lock Files & Commit

```bash
# Node
npm install  # regenerates package-lock.json
git add package-lock.json */package-lock.json

# Python (if using pip-compile)
pip-compile requirements.in -o requirements.txt

# Commit
git commit -m "chore(deps): update dependencies $(date +%Y-%m-%d)"
```

## Step 8 — Policy Reminders

- Never add a new runtime dependency without removing one (Node: ≤ 8 prod deps per TS project)
- Never add `GPL-2.0`, `GPL-3.0`, `AGPL-3.0`, `LGPL-2.1`, `LGPL-3.0` licensed packages
- Peer dependencies don't count toward the limit
- DevDependencies are unrestricted
