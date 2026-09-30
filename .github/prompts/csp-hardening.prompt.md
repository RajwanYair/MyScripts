---
mode: agent
tools: [read_file, replace_string_in_file, run_in_terminal, grep_search]
description: Harden Content Security Policy headers for a client-side SPA.
---

# Content Security Policy Hardening

## Goal

Harden the hosting headers with a strict CSP:

- Blocks XSS via `default-src 'self'`
- Removes `unsafe-eval` and `unsafe-inline` where possible
- Preserves app functionality (Web Workers, inline styles if needed)

## Steps

### 1 — Read current headers

Check `public/_headers` (Cloudflare Pages) or `netlify.toml` or the
framework's `headers` config.

### 2 — Identify required directives

| Source type                     | Required directive                              |
| ------------------------------- | ----------------------------------------------- |
| App JS                          | `script-src 'self'`                             |
| Inline CSS (Tailwind vars, etc.) | `style-src 'self' 'unsafe-inline'`             |
| Web Workers                     | `worker-src 'self' blob:`                       |
| Fonts (if CDN)                  | `font-src 'self' https://fonts.gstatic.com`     |
| PWA Manifest                    | `manifest-src 'self'`                           |

### 3 — Apply a strict CSP

```text
Content-Security-Policy: default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; worker-src 'self' blob:; img-src 'self' data: blob:; font-src 'self'; manifest-src 'self'; connect-src 'self'; frame-ancestors 'none'; base-uri 'self'; form-action 'self'
X-Frame-Options: DENY
X-Content-Type-Options: nosniff
Referrer-Policy: strict-origin-when-cross-origin
Permissions-Policy: geolocation=(), camera=(), microphone=(), payment=()
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Resource-Policy: same-origin
```

### 4 — Test locally

Build and serve, then check the browser DevTools Console for CSP violations.

### 5 — Verify with Lighthouse

Run Lighthouse — CSP issues appear in the Best Practices category.

### 6 — Document

Add entry to `CHANGELOG.md [Unreleased]`:

```text
### Security
- Hardened CSP headers — removes unsafe-eval, adds frame-ancestors deny
```
