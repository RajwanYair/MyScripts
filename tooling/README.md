# MyScripts Shared Tooling

> **Centralization Policy**: `MyScripts/` is the single source of truth for all
> development tools. Sub-projects (one level below) **MUST** reference these
> shared configs via `../tooling/` — never duplicate, vendor, or install tools
> locally. Only project-specific overrides belong inside a sub-project.

## What Lives Here (Centralized)

| Resource | Location | Purpose |
|----------|----------|---------|
| JS/TS dependencies | `MyScripts/package.json` + `node_modules/` | Shared `npm install` — never run inside sub-projects |
| Python tool configs | `MyScripts/pyproject.toml` | ruff, mypy, pytest, coverage, bandit defaults |
| Base configs | `MyScripts/tooling/` | ESLint, TypeScript, Vitest, Vite, Prettier, etc. |
| Shared scripts | `MyScripts/scripts/` | Mermaid validation, bundle-size checks, test guards |
| Starter templates | `MyScripts/templates/` | CI workflows, gitignore, config scaffolds |
| MCP servers | `MyScripts/.vscode/mcp.json` | GitHub, Fetch, Playwright, GitKraken, Filesystem |
| VS Code settings | `MyScripts/.vscode/settings.json` | Universal editor/formatter/linter defaults |
| Copilot instructions | `MyScripts/.github/` | Workspace-wide AI coding rules |

## What Belongs in a Sub-Project (Project-Specific Only)

- `package.json` — project name, scripts, metadata (no `dependencies` that duplicate root)
- `tsconfig.json` — `"extends": "../tooling/tsconfig/base-*.json"` + local `include`/`outDir`
- `eslint.config.mjs` — imports from `../tooling/eslint/*.mjs` + local overrides
- `vitest.config.ts` — imports from `../tooling/vitest/*.mjs` + local test paths
- `vite.config.ts` — imports from `../tooling/vite.base.ts` + local plugins/aliases
- `.github/workflows/` — repo-specific CI (extend from `templates/`)
- Source code, tests, docs, assets

## Directory Layout

```
tooling/
  eslint/
    base.mjs               ESLint flat-config base (rules + plugins)
    web-ts-app.mjs         ESLint preset for browser TypeScript apps
    node-ts-app.mjs        ESLint preset for Node.js TypeScript apps
  stylelint/
    base.cjs               Stylelint base (standard CSS + logical props)
  tsconfig/
    base-typescript.json   TypeScript strict base (ES2022, bundler, noEmit)
    base-node.json         Node.js variant (NodeNext modules, emits, outDir)
  vitest/
    base.mjs               Vitest base config (globals, thresholds)
    happy-dom.mjs          Vitest preset for browser/DOM tests (happy-dom)
    node.mjs               Vitest preset for pure Node.js projects
  markdownlint.base.json   Markdownlint rules (MD013 off, SVG in MD033 allowed)
  vite.base.ts             Vite base (es2022 target, sourcemaps, OXC minifier, port 5173)
  playwright.base.ts       Playwright base (chromium+firefox, CI retries)
  prettier.base.json       Prettier base (singleQuote, printWidth 100, LF)
  commitlint.base.cjs      Commitlint base (conventional commits, 10 types)
```

## Reusable Scripts (workspace root)

```
scripts/
  validate-mermaid.mjs       Validate Mermaid syntax in Markdown files
  check-bundle-size.mjs      Enforce max bundle size thresholds after build
  check-test-focus-skip.mjs  Prevent .only/.skip in committed test files
```

## How Projects Extend These Bases

Each project in this workspace should have minimal local config files that reference the shared bases. Example patterns:

### TypeScript (`tsconfig.json`)

Browser/Vite project (extends strict base, keeps bundler resolution):

```json
{
    "extends": "../tooling/tsconfig/base-typescript.json",
    "compilerOptions": {
        "outDir": "./dist",
        "rootDir": "./src"
    },
    "include": ["src", "tests"]
}
```

Node.js project (extends node variant with NodeNext modules and emit):

```json
{
    "extends": "../tooling/tsconfig/base-node.json",
    "compilerOptions": {
        "outDir": "./dist"
    },
    "include": ["src"]
}
```

Cloudflare Worker (extends node base but overrides module resolution for bundler):

```json
{
    "extends": "../../tooling/tsconfig/base-node.json",
    "compilerOptions": {
        "module": "ES2022",
        "moduleResolution": "bundler",
        "lib": ["ES2022"],
        "types": ["@cloudflare/workers-types"],
        "noEmit": true
    },
    "include": ["src/**/*.ts"]
}
```

### Vitest (`vitest.config.ts`)

Browser / DOM project (happy-dom):

```ts
import { defineConfig } from "vitest/config";
import { sharedVitestTestConfig } from "../tooling/vitest/base.mjs";
import { happyDomVitestConfig } from "../tooling/vitest/happy-dom.mjs";
export default defineConfig({ test: { ...sharedVitestTestConfig, ...happyDomVitestConfig } });
```

Pure Node.js project:

```ts
import { defineConfig } from "vitest/config";
import { nodeVitestConfig } from "../tooling/vitest/node.mjs";
export default defineConfig({ test: nodeVitestConfig });
```

### ESLint (`eslint.config.mjs`)

Browser / Vite TypeScript project (`web-ts-app.mjs`):

```js
import { webAppConfig } from "../tooling/eslint/web-ts-app.mjs";
export default [...webAppConfig({ tsconfigRootDir: import.meta.dirname })];
```

Node.js / Cloudflare Worker TypeScript project (`node-ts-app.mjs`):

```js
import { nodeAppConfig } from "../tooling/eslint/node-ts-app.mjs";
export default [
    ...nodeAppConfig({
        tsconfigRootDir: import.meta.dirname,
        files: ["src/**/*.ts"],
    }),
];
```

Low-level: import individual pieces from `base.mjs` for custom compositions:

```js
import base from "../tooling/eslint/base.mjs";
export default [...base];
```

### Stylelint

```js
// .stylelintrc.cjs
const base = require("../tooling/stylelint/base.cjs");
module.exports = { ...base };
```

### Markdownlint

```json
{ "extends": "../tooling/markdownlint.base.json" }
```

### Vite (`vite.config.ts`)

```ts
import { baseConfig } from '../tooling/vite.base.ts';
import { defineConfig } from 'vite';
export default defineConfig({ ...baseConfig, plugins: [...] });
```

### Prettier (`.prettierrc.json`)

```json
{ "extends": "../tooling/prettier.base.json" }
```

### Commitlint (`commitlint.config.cjs`)

```js
const base = require("../tooling/commitlint.base.cjs");
module.exports = { ...base };
```

## Adding a New Project

1. Create `YourProject/` alongside `BudgetManager/` in this workspace.
2. Add a minimal `package.json` with `"name"`, `"version"`, and dev scripts.
3. Reference the shared base configs above instead of duplicating rules.
4. Run `npm install` from this parent directory to bootstrap all projects.

## Updating Shared Rules

Edit the files in `tooling/` to affect all projects that extend them.
Test the change locally in one project before committing.
Document breaking changes with a comment in the config file.

## JS/TS Version Source Of Truth

For shared web application tooling versions, treat the root `MyScripts/package.json` as the workspace baseline.

- Shared tool configs live in `tooling/`
- Shared package versions live in the root `package.json`
- Child web projects should extend these shared configs and align to the root package versions unless a documented compatibility reason requires divergence

For the consolidated generic web application guidance that ties these pieces together, see `docs/WEB_APP_BEST_PRACTICES.md`.
