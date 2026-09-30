---
description: >
  Add i18n keys to TypeScript sub-projects — create keys in all required locale
  files with full parity, validate no missing translations, and update the source
  components to use the new keys.
---

# i18n: Add New Keys

Add new translation keys to a TypeScript sub-project's i18n files with full parity
across all locale files.

## Target Project

Project: **`${projectName}`**
New keys to add: **`${keyList}`**

## Parity Rule

Every `t('key')` call MUST have a matching entry in **all locale files** present in
`src/i18n/` (for example: `en.json`, `he.json`, `ar.json`, `de.json`, `es.json`,
`fr.json`).

Minimum requirement: `en.json` + `he.json` must have real translations. Other
locales may copy the English value as a placeholder (mark with a `// TODO:` comment
in the `.jsonc` file, or leave a note in the PR body).

## Step 1 — Identify Key Namespace

Read the existing `en.json` to understand the key naming convention:

```text
features.featureName.label        → "Feature Name"
features.featureName.description  → "What this feature does"
calculator.inputs.width.label     → "Width"
calculator.inputs.width.hint      → "Enter width in millimetres"
calculator.outputs.result.label   → "Result"
```

Keys must be:

- Dot-namespaced, lowercase with camelCase segments
- Grouped by feature/section
- Never reuse generic keys across unrelated features

## Step 2 — Add to en.json

Add the new key(s) in the correct namespace location. Use `replace_string_in_file`
to insert after the last key in the section.

## Step 3 — Add to he.json (required)

Provide an accurate Hebrew translation for every new key. Do NOT copy the English
value — use a proper Hebrew translation.

## Step 4 — Add to Other Locale Files

For additional locale files:

- Use the English value as a placeholder if a real translation is not available
- Add a comment in the PR body listing which keys need proper translations

## Step 5 — Update Source Component

Find the component(s) that will use the new keys. Update them to call `t('key')`:

```tsx
const { t } = useTranslation();
<label>{t("calculator.inputs.width.label")}</label>;
```

## Step 6 — Validate i18n Coverage

```bash
cd <TypeScriptSpaProject> && npm run i18n:coverage
```

This must exit with code 0 (100% coverage — no missing keys).

## Step 7 — TypeScript Validation

```bash
cd <TypeScriptSpaProject> && npx tsc --noEmit
```

## Common Mistakes to Avoid

- Duplicating a key that already exists (search first)
- Using different key names in different locale files
- Adding keys to `en.json` but forgetting `he.json`
- Using translation values as fallback keys (e.g. `t('Submit')` instead of `t('common.submitButton')`)
- Adding `.json5` or `.jsonc` comments to `.json` files — use `.jsonc` extension if you need comments
