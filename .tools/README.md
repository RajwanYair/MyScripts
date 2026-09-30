# MyScripts/.tools — Shared Development Tooling

> Production-grade tooling baseline shared by every project under `MyScripts/`.
> Each sibling project remains self-contained and clonable in isolation, but
> inherits the conventions baked into this directory.

## Contents

| File                     | Purpose                                                                   |
| ------------------------ | ------------------------------------------------------------------------- |
| `.nvmrc`                 | Pins **Node 22 LTS** as the canonical runtime                             |
| `.npmrc`                 | `engine-strict=true`, `save-exact=true`, `audit-level=high`, `fund=false` |
| `editorconfig.shared`    | Universal editor settings (LF, UTF-8, 2-space JS/JSON/YAML, 4-space text) |
| `prettierrc.shared.json` | Universal Prettier baseline (single quote, trailing commas, 120 cols)     |
| `Install-DevTools.ps1`   | One-shot Windows installer (Node, gh, Playwright browsers, Lighthouse)    |
| `Install-DevTools.sh`    | Same, for macOS/Linux                                                     |
| `README.md`              | This file                                                                 |

## One-time setup (Windows / PowerShell)

```powershell
cd "$HOME/Documents/MyScripts/.tools"
./Install-DevTools.ps1
```

The script installs (idempotently):

- Node 22 LTS via `nvm-windows`
- `npm@latest` and `corepack` enable
- `gh` CLI via `winget`
- Playwright browsers cached to `~/AppData/Local/ms-playwright`
- `@lhci/cli` globally (Lighthouse CI)
- `stylelint`, `stylelint-config-standard`, `stylelint-config-tailwindcss` globally

## One-time setup (macOS / Linux)

```bash
cd ~/Documents/MyScripts/.tools
./Install-DevTools.sh
```

Verify:

```bash
node --version       # v22.x
npm --version        # 11.x
gh --version         # 2.60+
lhci --version       # 0.15+
stylelint --version  # 16+
```

## How sibling projects consume this

Per-project configs live at each project's root (so each project still works
when cloned in isolation), but they should mirror what is set here:

```text
MyScripts/
├── .tools/                       ← this directory (shared baseline)
│   ├── .nvmrc
│   ├── .npmrc
│   ├── editorconfig.shared
│   ├── prettierrc.shared.json
│   └── README.md
├── WoodworkingShop/              ← React/TS PWA
│   ├── .nvmrc                    ← copy of .tools/.nvmrc
│   ├── .editorconfig             ← derived from editorconfig.shared
│   ├── .prettierrc.json          ← derived from prettierrc.shared.json
│   └── package.json
└── <other-project>/
    └── ...
```

When bootstrapping a new project under `MyScripts/`, copy the four config
files from `.tools/` into the project root and customise only where the
project genuinely diverges (e.g. a Python project needs different Prettier
settings).

## 🗂 Intermediate files convention

All transient outputs (caches, reports, build temp) **must** live under
`$TEMP` (Windows) / `$TMPDIR` (Unix). For Node tooling:

- npm cache → `%LOCALAPPDATA%/npm-cache` (Windows) or `~/.npm` (Unix)
- ESLint cache → `node_modules/.cache/eslint/` per project
- Vitest cache → `node_modules/.vitest/` per project
- Coverage / Playwright / Lighthouse reports → per-project `coverage/`,
  `playwright-report/`, `.lighthouseci/` (all gitignored)

Never commit transient outputs. Each sibling project's `.gitignore` enforces
this.

## 📌 Versioning

This shared scaffold is updated in lockstep with the Cabinet Planner project's
production releases. The current baseline corresponds to:

- **Node:** 22 LTS
- **npm:** 11.x
- **TypeScript:** 6.x
- **Vite:** 8.x
- **ESLint:** 10 flat config + `eslint-plugin-jsx-a11y`
- **Prettier:** 3.x
- **Stylelint:** 16.x (with `stylelint-config-tailwindcss`)
- **Playwright:** 1.60.x
- **GitHub CLI:** 2.60+
- **Lighthouse CI:** 0.15+
