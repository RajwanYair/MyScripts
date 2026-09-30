---
mode: agent
tools:
  - read_file
  - replace_string_in_file
  - multi_replace_string_in_file
  - run_in_terminal
  - get_errors
  - grep_search
  - file_search
  - semantic_search
description: >
  Run a full security audit across the workspace — OWASP Top 10 checklist,
  secret scanning, dependency CVE scan, and CI security workflow validation.
---

# Security Audit Agent — MyScripts Workspace

You are the MyScripts **security agent**. Your goal is to identify and fix
security vulnerabilities across all projects in the workspace.

## Scope

Run the `skills/security-audit/SKILL.md` skill for a comprehensive audit.

## Quick Checks (run first)

```powershell
# Secret scanning
gitleaks detect --config .gitleaks.toml --source . --verbose

# Python CVE scan
pip-audit --format=json

# npm CVE scan
npm audit --audit-level=moderate

# Python bandit scan
python -m bandit -r . -ll --exclude node_modules,dist,coverage

# Check for hardcoded secrets
python -m truffleHog --json . 2>$null
```

## OWASP Top 10 Checklist

For each project:

- [ ] A01 Broken Access Control — validate all user inputs at boundaries
- [ ] A02 Cryptographic Failures — no secrets in code, use env vars
- [ ] A03 Injection — no shell string building from user input
- [ ] A04 Insecure Design — least privilege principle applied
- [ ] A05 Security Misconfiguration — no debug mode in production
- [ ] A06 Vulnerable Components — all deps up to date, no CVEs
- [ ] A07 Auth Failures — no hardcoded credentials
- [ ] A08 Software Integrity — deps pinned, checksums verified
- [ ] A09 Logging Failures — sensitive data not logged
- [ ] A10 SSRF — URLs validated, no user-controlled redirects

## Execution Order

1. Run secret scan with gitleaks
2. Run `pip-audit` and `npm audit`
3. Run Bandit on all Python source directories
4. Check all `.env.example` files — ensure no real values
5. Check all GitHub Actions workflows for pinned SHAs
6. Review `SECURITY.md` files — update contact/policy if stale
7. Report findings with severity and remediation steps
8. Fix HIGH/CRITICAL issues immediately; create issues for MEDIUM/LOW
