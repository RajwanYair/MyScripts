---
description: "Run a targeted OWASP Top 10 security audit against the current project codebase."
---

# Security Audit

Perform a security review against the OWASP Top 10.

> Adapt the checklist below to the project's threat model. Not all categories apply
> to every project type (e.g., static PWAs have no A01/A07 exposure).

## Automated Checks

Run these first — all must exit 0 before proceeding:

```powershell
# Lint (includes security-related rules)
npx eslint src tests --max-warnings 0   # JS/TS
ruff check src tests                     # Python

# Type safety
npx tsc --noEmit                         # TypeScript
mypy src                                 # Python

# Dependency audit
npm audit --audit-level=high             # Node.js
pip-audit                                # Python
```

## Manual Review Checklist

### A01 — Broken Access Control

- [ ] Authorization checks on all sensitive endpoints
- [ ] No IDOR vulnerabilities (direct object references)
- [ ] Least-privilege principle applied to all roles

### A02 — Cryptographic Failures

- [ ] No secrets or API keys committed to source
- [ ] Sensitive data encrypted at rest and in transit
- [ ] No weak algorithms (MD5, SHA1 for security)

### A03 — Injection

- [ ] No `innerHTML` with unsanitized data (XSS)
- [ ] No `eval()` or `new Function()` calls
- [ ] No `shell=True` with user-controlled input (command injection)
- [ ] No SQL injection vectors (parameterized queries only)
- [ ] Input validated at system boundaries

### A04 — Insecure Design

- [ ] Threat model documented for the project's attack surface
- [ ] Rate limiting on public-facing endpoints
- [ ] Defense in depth (multiple layers of protection)

### A05 — Security Misconfiguration

- [ ] No debug endpoints exposed in production
- [ ] CORS configured restrictively (no wildcards in production)
- [ ] CSP headers configured (if web-facing)
- [ ] No default credentials

### A06 — Vulnerable Components

- [ ] `npm audit` / `pip-audit` returns 0 HIGH/CRITICAL vulnerabilities
- [ ] GitHub Actions pinned to full SHAs
- [ ] Renovate/Dependabot configured for automatic updates

### A07 — Identification & Authentication Failures

- [ ] Strong password policies (if auth exists)
- [ ] MFA available for admin accounts
- [ ] Session tokens rotated on login

### A08 — Software and Data Integrity

- [ ] `npm audit signatures` passes (Sigstore verification)
- [ ] No `.npmrc` / `.pypirc` auth tokens in repo
- [ ] CI artifacts verified for integrity

### A09 — Security Logging & Monitoring

- [ ] Error messages do not leak stack traces or internal paths
- [ ] Logs do not contain PII, API keys, or credentials
- [ ] Audit trail for sensitive operations

### A10 — Server-Side Request Forgery

- [ ] External URLs not constructed from user input
- [ ] Allowlist for outbound requests (if applicable)

## Reporting

For each finding:

1. **Severity**: Critical / High / Medium / Low
2. **Location**: file + line number
3. **Description**: what the vulnerability is
4. **Fix**: exact code change needed

Fix all Critical and High findings before the next release tag.
