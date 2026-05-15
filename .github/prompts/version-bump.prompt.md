---
description: "Bump the project version number consistently across all files that reference it. Use when releasing a new version."
---

# Version Bump

Bump the version from the current value to a new semver target.

## Steps

1. **Confirm current version**: Check `package.json` (or `pyproject.toml` for Python).
2. **Load release skill**: If the project has `.github/skills/release/SKILL.md`, load it — it contains the canonical file list.
3. **Replace version strings**: For each file in the release skill table, replace every occurrence of the old version with the new one.
4. **CHANGELOG entry**: Add at the top: `## [X.Y.Z] — YYYY-MM-DD` with a bulleted summary.
5. **Verify consistency**: Run any version-consistency check scripts the project has.

## Common Version Locations

| File                         | Language   | Field/Pattern                    |
| ---------------------------- | ---------- | -------------------------------- |
| `package.json`               | JS/TS      | `"version": "X.Y.Z"`            |
| `pyproject.toml`             | Python     | `version = "X.Y.Z"`             |
| `CHANGELOG.md`               | Any        | `## [X.Y.Z]` header             |
| `README.md`                  | Any        | Version badge / header           |
| `copilot-instructions.md`    | Any        | Version in title/description     |
| Service Worker / `sw.js`     | JS/TS      | `APP_VERSION` constant           |

> Each project may have additional files — always check the release skill first.

## Output

List every file changed and the old → new version string for each.
Paste the new CHANGELOG entry.
