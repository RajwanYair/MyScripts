---
applyTo: "**/src/**/*.js,**/css/**/*.css,**/index.html"
---

# Vanilla Web App Instructions

> For projects using vanilla JavaScript (ES2025+) with CSS `@layer` — no React, no TypeScript compilation.
> Reference implementation: use the active vanilla-web sub-project as the local pattern reference.

## Architecture Pattern

```text
src/
  main.js             ← Vite entry, bootstrap, lifecycle wiring
  core/               ← app primitives: store, events, routing, i18n, ui helpers
  sections/           ← feature modules with mount/unmount lifecycle
  services/           ← backend, sync, auth, storage, external APIs
  utils/              ← pure helpers: validate, format, sanitize, transform
  templates/          ← lazy-loaded HTML fragments
  handlers/           ← event delegation / action dispatch
  i18n/               ← locale JSON files (lazy-loaded)
css/
  variables.css       ← design tokens (custom properties)
  base.css            ← reset, typography, global styles
  layout.css          ← page/section layout grid
  components.css      ← reusable UI components
  responsive.css      ← breakpoint overrides
  print.css           ← print media styles
  auth.css            ← auth-specific styles (optional)
public/
  sw.js               ← service worker (versioned cache)
  manifest.json       ← PWA manifest
index.html            ← HTML shell (minimal, no inline JS)
```

## Mandatory Rules

1. **`textContent` only** — never `innerHTML` with unsanitized data; use DOMPurify if HTML rendering is required
2. **i18n all visible strings** — `data-i18n="key"` on HTML, `t('key')` in JS
3. **CSS custom properties only** — never hardcode colors, spacing, or shadows
4. **No inline `getElementById`** — collect DOM refs in an `el` object at section init
5. **localStorage prefix** — all keys prefixed with `{app}_v{N}_` (e.g., `project_v1_`)
6. **Pure ESM** — no `window.*` globals, no `var`, no CommonJS
7. **No eval/innerHTML** — CI security scan must pass
8. **Lint clean** — `npm run lint` exits 0 (0 errors, 0 warnings)

## CSS Architecture — `@layer` Pattern

```css
@layer variables, base, layout, components, utilities, responsive, print;

@layer variables {
  :root {
    --color-primary: oklch(0.6 0.2 270);
    --color-surface: oklch(0.98 0 0);
    --radius-md: 0.5rem;
    --shadow-card: 0 2px 8px oklch(0 0 0 / 0.08);
  }
}

@layer base {
  *,
  *::before,
  *::after {
    box-sizing: border-box;
  }
}
```

Rules:

- Layer order controls specificity — later layers override earlier
- Use native CSS nesting with `&`
- RTL-first if project is Hebrew/Arabic: `dir="rtl"` on `<html>`
- Use logical properties (`margin-inline-start` not `margin-left`)
- Glassmorphism: `backdrop-filter: blur(16px)` with fallback
- Themes via `body.theme-{name}` class swapping custom properties

## Section Module Pattern

```js
// src/sections/feature.js
import { t } from "../core/i18n.js";
import { getState, setState } from "../core/store.js";

/** @type {Record<string, HTMLElement | null>} */
let el = {};

export function mount(container) {
  el.root = container;
  el.title = container.querySelector('[data-ref="title"]');
  render();
}

export function unmount() {
  el = {};
}

export function render() {
  if (!el.root) return;
  el.title.textContent = t("feature.title");
}
```

## Event Delegation

Use `data-action` attributes instead of per-element listeners:

```js
container.addEventListener("click", (e) => {
  const action = e.target.closest("[data-action]")?.dataset.action;
  if (action && actions[action]) actions[action](e);
});
```

## State Management

- Single store module (`src/core/store.js`) as source of truth
- Persist to `localStorage` with app prefix
- Cross-module communication via store subscriptions or custom events
- Never mutate state directly from UI — always go through store

## Build Config

Use `vite.config.js` (not `.ts` for vanilla projects):

- Entry: `src/main.js`
- `base: "./"` for GitHub Pages
- Manual chunks for large dependencies
- Cache dir in `$TEMP` to keep workspace clean

## Quality Gates

```bash
npm run lint          # ESLint + Stylelint + HTMLHint (0 errors, 0 warnings)
npm test             # Vitest (all pass)
npm run build        # Vite production build (exits 0)
```

## What NOT to Do

- Don't add React/framework dependencies for a vanilla app
- Don't use TypeScript compilation — use JSDoc types + `// @ts-check` if needed
- Don't add `enum` or `namespace` — those are TypeScript-only constructs
- Don't hardcode colors — use CSS custom properties
- Don't skip `data-i18n` on new visible strings
- Don't put build artifacts in the project directory — use `$TEMP`
- Don't add `// eslint-disable` comments — fix the issue
