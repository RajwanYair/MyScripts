# Advanced Project Patterns

> Reusable patterns proven in production. Apply to any project that grows beyond basic CI/CD.
> Primary reference: `Wedding/` v32.2.0 (vanilla web), `WoodworkingShop/` v4.2.0 (React SPA).

## $TEMP Enforcement

All intermediate build artifacts **must** route to the OS temp directory. The workspace
must be commit-clean after any build, test, or lint run.

### Directory Structure

```text
$TEMP/<ProjectName>/
├── .vite/                ← Vite build cache (vite.config → cacheDir)
├── .eslintcache          ← ESLint cache (--cache-location)
├── .stylelintcache       ← Stylelint cache (--cache-location)
├── coverage/             ← Vitest/pytest coverage reports
├── test-results/         ← Playwright/pytest output
├── playwright-report/    ← Playwright HTML report
├── stryker-tmp/          ← Mutation testing workspace
├── .lighthouseci/        ← Lighthouse CI output
└── bench-results.json    ← Vitest bench output
```

### Implementation

**Vite (`vite.config.js`):**

```js
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const TEMP_DIR = join(tmpdir(), 'my-project');

export default defineConfig({
  cacheDir: join(TEMP_DIR, '.vite'),
  build: { outDir: 'dist' } // dist stays in-project for deployment
});
```

**Vitest (`vitest.config.js`):**

```js
export default defineConfig({
  test: {
    coverage: {
      reportsDirectory: join(tmpdir(), 'my-project', 'coverage')
    }
  }
});
```

**Playwright (`playwright.config.mjs`):**

```js
export default defineConfig({
  outputDir: join(tmpdir(), 'my-project', 'test-results'),
  reporter: [['html', { outputFolder: join(tmpdir(), 'my-project', 'playwright-report') }]]
});
```

**ESLint + Stylelint (via npm scripts):**

```json
{
  "lint:js": "eslint src --cache --cache-location \"$TEMP/my-project/.eslintcache\"",
  "lint:css": "stylelint css/**/*.css --cache --cache-location \"$TEMP/my-project/.stylelintcache\""
}
```

### Rule

If a build-time artifact path is not under `os.tmpdir()`, it is wrong. The only
exception is `dist/` which is the deployment output.

---

## Version Sync Pattern

For projects with version strings in multiple files, create a `sync-version.mjs`
script that propagates `package.json` version to all other locations.

### Template (`scripts/sync-version.mjs`)

```js
#!/usr/bin/env node
import { readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

const pkg = JSON.parse(readFileSync('package.json', 'utf8'));
const version = pkg.version;

/** @type {Array<{file: string, pattern: RegExp, replacement: string}>} */
const targets = [
  {
    file: 'src/core/config.js',
    pattern: /VERSION\s*=\s*['"][^'"]+['"]/,
    replacement: `VERSION = '${version}'`
  },
  {
    file: 'public/sw.js',
    pattern: /CACHE_NAME\s*=\s*['"][^'"]+['"]/,
    replacement: `CACHE_NAME = 'app-v${version}'`
  },
  {
    file: '.github/copilot-instructions.md',
    pattern: /v\d+\.\d+\.\d+/g,
    replacement: `v${version}`
  },
  // Add project-specific targets here
];

let updated = 0;
for (const { file, pattern, replacement } of targets) {
  const filepath = join(process.cwd(), file);
  const content = readFileSync(filepath, 'utf8');
  const newContent = content.replace(pattern, replacement);
  if (content !== newContent) {
    writeFileSync(filepath, newContent);
    console.log(`✓ ${file}`);
    updated++;
  }
}
console.log(`\nUpdated ${updated}/${targets.length} files to v${version}`);
```

### Usage

```json
{
  "scripts": {
    "sync:version": "node scripts/sync-version.mjs"
  }
}
```

Run after bumping `package.json` version, before committing.

---

## Canonical Facts Enforcement

For projects with multiple documentation files that reference the same facts
(version, test count, utils count), create a check script that enforces parity.

### Concept

Define canonical values in one place (usually `package.json` + test output),
then verify all documentation surfaces reflect those values.

### Template (`scripts/check-canonical-facts.mjs`)

```js
#!/usr/bin/env node
import { readFileSync } from 'node:fs';

const pkg = JSON.parse(readFileSync('package.json', 'utf8'));
const version = pkg.version;

/** @type {Array<{file: string, check: (content: string) => boolean, message: string}>} */
const facts = [
  {
    file: 'AGENTS.md',
    check: (c) => c.includes(`version: \`${version}\``),
    message: `AGENTS.md must contain "version: \`${version}\`"`
  },
  {
    file: '.github/copilot-instructions.md',
    check: (c) => c.includes(`v${version}`),
    message: `.github/copilot-instructions.md must reference v${version}`
  },
  {
    file: 'README.md',
    check: (c) => c.includes(version),
    message: `README.md must reference ${version}`
  }
];

let failures = 0;
for (const { file, check, message } of facts) {
  try {
    const content = readFileSync(file, 'utf8');
    if (!check(content)) {
      console.error(`✗ ${message}`);
      failures++;
    } else {
      console.log(`✓ ${file}`);
    }
  } catch {
    console.error(`✗ ${file} — file not found`);
    failures++;
  }
}

process.exitCode = failures > 0 ? 1 : 0;
console.log(`\n${failures === 0 ? 'All facts consistent' : `${failures} inconsistencies found`}`);
```

### Usage

```json
{
  "scripts": {
    "check:facts": "node scripts/check-canonical-facts.mjs"
  }
}
```

Add to CI pipeline after lint and test steps.

---

## Pre-Release Checklist Template

Every production project should define a pre-release checklist. Store it in
the project's `copilot-instructions.md` or as a prompt file.

### Generic Checklist

| # | Check | Command |
|---|-------|---------|
| 1 | Zero lint errors/warnings | `npm run lint` — 0 errors, 0 warnings |
| 2 | Zero test failures | `npm test` — all pass, 0 skipped |
| 3 | Zero type errors | `npx tsc --noEmit` (TS) or typecheck script |
| 4 | No dead code/exports | `npm run dead:check` (Knip or custom) |
| 5 | No eval/innerHTML | Security scan passes |
| 6 | Build succeeds | `npm run build` exits 0 |
| 7 | Bundle under budget | `npm run bundle:check` exits 0 |
| 8 | Docs current | CHANGELOG has entry, README badge matches |
| 9 | Version synced | `npm run sync:version` — all files consistent |
| 10 | Canonical facts match | `npm run check:facts` — exits 0 |
| 11 | i18n complete | All new keys have translations |
| 12 | Commit + tag | `git commit && git tag vX.Y.Z && git push --tags` |

### As a Prompt File (`.github/prompts/pre-release.prompt.md`)

```markdown
---
description: "Run the full pre-release checklist before tagging a new version."
mode: agent
---

Run the pre-release checklist for this project:

1. Run lint: \`npm run lint\` — must exit 0, 0 warnings
2. Run tests: \`npm test\` — all pass
3. Check for dead exports: \`npm run dead:check\`
4. Build: \`npm run build\` — must exit 0
5. Version sync: \`npm run sync:version\`
6. Canonical facts: \`npm run check:facts\`
7. Verify CHANGELOG.md has entry for new version
8. Report any failures and suggest fixes
```

---

## Sprint & Roadmap Tracking

For actively evolving projects, maintain a `ROADMAP.md` that doubles as a sprint
backlog and decision log.

### ROADMAP.md Structure

```markdown
# Project Roadmap

## Current State
- Version: X.Y.Z
- Tests: N across M files
- Status: Active development

## Sprint Backlog

### Sprint N — [Theme Name]
- [ ] Feature A
- [ ] Feature B
- [x] Feature C (completed in vX.Y.Z)

### Sprint N+1 — [Theme Name]
- [ ] Feature D
- [ ] Feature E

## Sealed Decisions
Decisions that are final and not up for re-evaluation:

| Decision | Rationale | Date |
|----------|-----------|------|
| Vanilla JS (no framework) | Minimal runtime, full control | 2024-01 |
| CSS @layer | Specificity control, no build step | 2024-01 |

## Tech Debt Register

| Item | Severity | Sprint Target |
|------|----------|---------------|
| Legacy sync code | Medium | S+2 |
```

### Integration with Copilot

Create a `roadmap-status.prompt.md`:

```markdown
---
description: "Report current sprint status from ROADMAP.md"
mode: ask
---

Read ROADMAP.md and report:
1. Current sprint number and theme
2. Completed vs remaining items
3. Any blockers or tech debt items due this sprint
```

### Commit Convention

- After each sprint: `git commit -m "feat(sprint-N): [summary]"`
- After every 5 sprints or milestone: tag a release

---

## Agent Scaffolding

For complex projects, define specialized AI agents that have domain expertise.

### When to Create Agents

Create a dedicated agent when:

- A domain area has >10 specific rules/patterns
- Multiple team members work on the same domain
- The domain requires specialized context (auth, i18n, performance)
- Common tasks in that domain benefit from step-by-step workflows

### Agent File Template (`.github/agents/<name>.agent.md`)

```markdown
---
description: "<Domain> specialist for <Project>. Use when: <trigger conditions>."
tools:
  - run_in_terminal
  - read_file
  - replace_string_in_file
  - grep_search
  - file_search
  - semantic_search
---

# <Domain> Agent — <Project>

## Expertise
- <Area 1>
- <Area 2>

## Key Files
| File | Purpose |
|------|---------|
| `src/path/to/module.js` | Main module for this domain |
| `tests/path/to/test.js` | Test coverage |

## Workflows

### Add [Feature]
1. Step 1
2. Step 2
3. Run `npm run lint && npm test`

### Debug [Issue Type]
1. Check logs at...
2. Common causes: ...

## Rules
- Always do X before Y
- Never modify Z without updating W
```

### Skill File Template (`.github/skills/<name>/SKILL.md`)

```markdown
---
description: "Use when: <conditions>. Provides step-by-step <domain> procedures."
---

# <Skill Name>

## When to Use
- Condition A
- Condition B

## Procedure
### Step 1 — <Name>
...

### Step 2 — <Name>
...

## Checklist
- [ ] Item 1
- [ ] Item 2
```

### Recommended Agent Categories

| Agent | Domain | Example Triggers |
|-------|--------|-----------------|
| Release Engineer | Versioning, CHANGELOG, tagging | "bump version", "release" |
| Security Agent | OWASP, CSP, secrets | "security audit", "vulnerability" |
| Performance Agent | Bundle, Lighthouse, caching | "optimize", "slow", "bundle size" |
| i18n Agent | Translations, RTL, locales | "translate", "add locale", "RTL" |
| Designer | UI/UX, themes, accessibility | "redesign", "theme", "responsive" |
| Domain Agent | Business logic specific | Varies by project |

---

## i18n Parity Enforcement

For multilingual projects, enforce translation completeness in CI.

### Pattern

```js
// scripts/check-i18n-parity.mjs
import { readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';

const I18N_DIR = 'src/i18n';
const PRIMARY_LOCALE = 'en';

const files = readdirSync(I18N_DIR).filter(f => f.endsWith('.json'));
const primary = JSON.parse(readFileSync(join(I18N_DIR, `${PRIMARY_LOCALE}.json`), 'utf8'));
const primaryKeys = new Set(Object.keys(flattenKeys(primary)));

let failures = 0;
for (const file of files) {
  if (file === `${PRIMARY_LOCALE}.json`) continue;
  const locale = JSON.parse(readFileSync(join(I18N_DIR, file), 'utf8'));
  const localeKeys = new Set(Object.keys(flattenKeys(locale)));

  const missing = [...primaryKeys].filter(k => !localeKeys.has(k));
  if (missing.length > 0) {
    console.error(`${file}: ${missing.length} missing keys`);
    failures += missing.length;
  }
}

process.exitCode = failures > 0 ? 1 : 0;
```

### CI Integration

Add to the lint/check phase:

```json
{
  "scripts": {
    "i18n:check": "node scripts/check-i18n-parity.mjs"
  }
}
```

---

## Architecture Boundary Enforcement

Use ESLint `no-restricted-imports` to enforce module boundaries:

```js
// eslint.config.mjs — architecture rules
{
  files: ['src/sections/**/*.js'],
  rules: {
    'no-restricted-imports': ['error', {
      patterns: [
        { group: ['../sections/*'], message: 'Sections must not import from other sections' },
        { group: ['../services/*'], message: 'Use core/store for cross-module data' }
      ]
    }]
  }
}
```

### Enforcement Script

For projects needing deeper checks (circular deps, layer violations):

```js
// scripts/arch-check.mjs
// Parse import graph, verify no layer violations
// Layers: utils → core → services → sections → main
```

---

## HTMLHint for Entry Pages

For projects with significant HTML (entry pages, templates):

### Configuration (`.htmlhintrc`)

```json
{
  "extends": ["../tooling/htmlhint/base.json"],
  "rules": {
    "doctype-first": true,
    "tag-pair": true,
    "attr-lowercase": true,
    "id-unique": true,
    "src-not-empty": true,
    "attr-no-duplication": true,
    "alt-require": true
  }
}
```

### CI Integration

```json
{
  "scripts": {
    "lint:html": "htmlhint index.html src/templates/**/*.html"
  }
}
```
