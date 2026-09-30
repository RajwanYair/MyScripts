#!/usr/bin/env bash
# Install-DevTools.sh — One-shot installer for the MyScripts shared dev toolchain (macOS / Linux).
#
# Installs (idempotently):
#   - Node 22 LTS via nvm
#   - npm @ latest + corepack
#   - GitHub CLI (gh)
#   - Playwright browsers (chromium + firefox, system deps)
#   - @lhci/cli for Lighthouse CI
#   - stylelint + stylelint-config-standard (global)
#
# Safe to re-run.

set -euo pipefail

step()  { printf '\033[36m[+]\033[0m %s\n' "$*"; }
skip()  { printf '\033[90m[=]\033[0m %s\n' "$*"; }
done_() { printf '\033[32m[✓]\033[0m %s\n' "$*"; }

# ── nvm ────────────────────────────────────────────────────────────────────
if [ ! -d "$HOME/.nvm" ]; then
    step 'Installing nvm...'
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
else
    skip 'nvm already installed.'
fi
export NVM_DIR="$HOME/.nvm"
# shellcheck disable=SC1091
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# ── Node 22 LTS ────────────────────────────────────────────────────────────
node_version='22'
if ! node --version 2>/dev/null | grep -q '^v22\.'; then
    step "Installing Node $node_version LTS..."
    nvm install "$node_version"
    nvm use "$node_version"
else
    skip "Node $(node --version) already active."
fi

step 'Updating npm to latest...'
npm install -g npm@latest >/dev/null
step 'Enabling corepack...'
corepack enable >/dev/null

# ── GitHub CLI ─────────────────────────────────────────────────────────────
if ! command -v gh >/dev/null 2>&1; then
    step 'Installing GitHub CLI...'
    if command -v brew >/dev/null 2>&1; then
        brew install gh
    elif command -v apt-get >/dev/null 2>&1; then
        sudo apt-get install -y gh
    else
        echo 'WARNING: install gh manually from https://cli.github.com/'
    fi
else
    skip "GitHub CLI already installed ($(gh --version | head -n 1))."
fi

# ── Global npm tools ───────────────────────────────────────────────────────
step 'Installing stylelint + tailwindcss config globally...'
npm install -g stylelint stylelint-config-standard stylelint-config-tailwindcss >/dev/null
step 'Installing @lhci/cli globally...'
npm install -g @lhci/cli >/dev/null

# ── Playwright browsers ────────────────────────────────────────────────────
step 'Installing Playwright browsers (chromium + firefox)...'
npx --yes playwright@latest install --with-deps chromium firefox >/dev/null

done_ 'All shared dev tools are installed.'
