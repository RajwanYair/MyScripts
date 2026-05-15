---
description: "Audit and modernize VS Code chat customizations, GitHub workflows, MCP servers, hooks, agents, skills, prompts, and version pins across any project."
---

# Modernize Tooling

Review the current workspace tooling and update it with the latest supported practices.

## Audit Scope

- `.vscode/settings.json`, `.vscode/extensions.json`, `.vscode/tasks.json`, `.vscode/mcp.json`
- `.github/workflows/*.yml`
- `.github/hooks/*.json` — hook events: `PostToolUse`, `PreToolUse`
- `.github/instructions/*.instructions.md` — `applyTo:` globs, `description:` fields
- `.github/prompts/*.prompt.md` — `description:`, `tools:` fields
- `.github/agents/*.agent.md` — `tools:` allowlist, `handoffs:`, `user-invocable:`, `argument-hint:`
- `.github/skills/*/SKILL.md` — discoverable `description:` frontmatter
- `.github/AGENTS.md`, `.github/copilot-instructions.md`
- `package.json` version pins

## Update Goals

- Align version pins with current stable releases
- Use the current VS Code/Copilot customization features:
  - `applyTo:` glob frontmatter on instructions (file-scoped activation)
  - Optional `model:` on prompts for model pinning
  - `tools:` allowlist + `handoffs:` + `user-invocable:` on custom agents
  - Skills auto-discovery via `description:` in `SKILL.md` frontmatter
  - Three-tier memory (`/memories/`, `/memories/session/`, `/memories/repo/`)
  - Subagents via `runSubagent` with `agentName` parameter
  - MCP: tools + resources + prompts + sampling/elicitation + inline apps
  - MCP transport: prefer `streamableHttp` (new), use `stdio` (local), deprecate `sse`
  - MCP auth: OAuth 2.0 flows or `${input:TOKEN}` variables
  - Edit-time hooks via `.github/hooks/*.json`
  - `vscode_askQuestions`, `vscode_listCodeUsages`, `vscode_renameSymbol`
  - `multi_replace_string_in_file` for batch edits
  - `manage_todo_list` for multi-step task tracking
  - `view_image` for multimodal image analysis
- Harden GitHub Actions with least privilege, concurrency control, timeouts
- Refresh test counts, coverage thresholds, and version banners across all `.github/**/*.md` files after releases

## Verification

1. `get_errors` on changed files
2. Confirm all version numbers, test counts, and coverage thresholds agree across files
3. Verify MCP servers start correctly (`MCP: List Servers` command)
