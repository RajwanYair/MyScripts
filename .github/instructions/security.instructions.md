---
applyTo: "**/src/**,**/public/**"
---

# Security Instructions — MyScripts Projects

Rules enforced for all source and public files across workspace projects.

## OWASP A03 — Injection

- **No `innerHTML` with unsanitized data** — use `textContent` or DOMPurify.
- **No `eval()`**, `new Function()`, or `setTimeout(string)`.
- **No `dangerouslySetInnerHTML`** in React components — all user content
  through React's auto-escaping JSX.
- String-based exports (G-code, DXF, SVG, CSV) must sanitise user-supplied
  text: strip control characters, limit length to ≤ 255 chars.

## OWASP A05 — Security Misconfiguration

- `public/_headers` must include:

  ```text
  Content-Security-Policy: default-src 'self'; ...
  X-Frame-Options: DENY
  X-Content-Type-Options: nosniff
  Referrer-Policy: strict-origin-when-cross-origin
  Permissions-Policy: geolocation=(), camera=(), microphone=()
  ```

- No `unsafe-eval` in CSP `script-src` unless documented inline with a
  JSDoc comment explaining the specific requirement.

## OWASP A06 — Vulnerable Components

- Run `npm audit --audit-level=moderate` before every release.
- No known CVEs at `high` or `critical` severity in production dependencies.

## OWASP A08 — Integrity Failures

- No remote `<script>` or `<link>` tags without SRI hashes.
- Service worker must not cache cross-origin resources without an allow-list.

## Secrets hygiene

- No API keys, tokens, or passwords in source files.
- `.github/.gitleaks.toml` guards all repos — do not disable rules.
- `import.meta.env.VITE_*` or `process.env.*` only for runtime config.

## localStorage / sessionStorage

- Store only non-sensitive config. Prefix all keys: `{app}_v{N}_`.
- Never store auth tokens or PII in browser storage.
- Always use try/catch around `JSON.parse` + type guard before use.
