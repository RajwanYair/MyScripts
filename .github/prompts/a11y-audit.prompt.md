---
mode: agent
tools: [read_file, run_in_terminal, grep_search, replace_string_in_file]
description: WCAG 2.2 AA accessibility audit — axe-core scan + manual checklist + remediation.
---

# Accessibility Audit Prompt

Audit the application against WCAG 2.2 AA and fix all violations. Reference: `docs/REACT_SPA_PLAYBOOK.md`.

## Step 1 — Automated scan

```bash
npm run test:e2e
```

The E2E tests run `@axe-core/playwright` on every page — collect all violations.

## Step 2 — Manual checklist

- [ ] All interactive elements reachable by keyboard (Tab, Shift+Tab, Enter, Space, Escape, Arrow keys)
- [ ] Focus is visible on every focusable element
- [ ] Focus traps work correctly in modals/dialogs (keyboard enters and can exit)
- [ ] All form inputs have associated `<label>` (via `htmlFor` or `aria-label`)
- [ ] All images have meaningful `alt` text (or `alt=""` for decorative)
- [ ] All icon-only buttons have `aria-label`
- [ ] Color contrast ≥ 4.5:1 for body text, ≥ 3:1 for large text
- [ ] Toast/alert messages announced via `aria-live="polite"` or `role="alert"`
- [ ] RTL layout correct for Hebrew and Arabic locales

## Step 3 — Common fixes in React/TypeScript projects

```tsx
// ❌ Missing label
<input type="text" onChange={...} />
// ✅ With label
<label htmlFor="width">{t('config.width')}</label>
<input id="width" type="text" onChange={...} />

// ❌ Redundant ARIA roles on semantic elements
<ul role="list"><li role="listitem">
// ✅ Remove — roles are implicit
<ul><li>

// ❌ Non-interactive div with keyboard handler
<div onClick={handler} onKeyDown={handler}>
// ✅ Use semantic button
<button onClick={handler}>

// ❌ Icon button without label
<button><ChevronIcon /></button>
// ✅ With accessible label
<button aria-label={t('actions.expand')}><ChevronIcon aria-hidden /></button>
```

## Step 4 — Constraints

- Do not add redundant `role` attributes that duplicate implicit semantics
- Do not use `tabIndex > 0` (breaks natural tab order)
- Keep `aria-label` text translatable via `t()` — never hardcode English strings

## Step 5 — Validate

```bash
npm run lint        # jsx-a11y rules
npm run test:e2e    # axe-core assertions
npm run typecheck   # ensure no TS regressions
```
