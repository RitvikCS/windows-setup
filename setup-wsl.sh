#!/bin/bash
# setup-wsl.sh
# Run with: bash setup-wsl.sh

set -euo pipefail

# ── Colors (fallback if gum not yet installed) ─────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'
RED='\033[0;31m';   MAGENTA='\033[0;35m'; BOLD='\033[1m'; NC='\033[0m'

step()     { echo -e "\n${CYAN}  ► $1${NC}"; }
done_msg() { echo -e "    ${GREEN}✓ $1${NC}"; }
skip()     { echo -e "    ${YELLOW}✓ $1 (already done)${NC}"; }
info()     { echo -e "    ${NC}· $1${NC}"; }
fail()     { echo -e "    ${RED}✗ $1${NC}"; exit 1; }

# ── Header ────────────────────────────────────────────────────────────────────
clear
echo -e "${MAGENTA}${BOLD}"
echo "  ╔══════════════════════════════════════════╗"
echo "  ║         WSL Dev Environment Setup        ║"
echo "  ╚══════════════════════════════════════════╝"
echo -e "${NC}"

# ── gum ───────────────────────────────────────────────────────────────────────
step "Setting up gum (interactive UI)..."
if command -v gum &>/dev/null; then
    skip "gum already installed"
else
    info "Adding Charm apt repo..."
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://repo.charm.sh/apt/gpg.key \
        | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg
    echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" \
        | sudo tee /etc/apt/sources.list.d/charm.list > /dev/null
    sudo apt update -qq && sudo apt install -y gum
    done_msg "gum installed"
fi

# ── GitHub CLI ────────────────────────────────────────────────────────────────
step "Checking GitHub CLI (gh)..."
if command -v gh &>/dev/null; then
    skip "gh $(gh --version | awk '{print $3}' | head -1) already installed"
else
    gum spin --spinner dot --title "Installing GitHub CLI..." -- bash -c '
        sudo mkdir -p -m 755 /etc/apt/keyrings
        out=$(mktemp)
        wget -nv -O"$out" https://cli.github.com/packages/githubcli-archive-keyring.gpg
        cat "$out" | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
        sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
            | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
        sudo apt update -qq && sudo apt install -y gh
    '
    done_msg "gh installed"
fi

# ── GitHub Auth ───────────────────────────────────────────────────────────────
step "Checking GitHub authentication..."
if gh auth status &>/dev/null; then
    skip "Already logged into GitHub"
else
    echo ""
    gum style \
        --border rounded --padding "0 2" \
        --border-foreground 212 \
        "You'll be prompted to log in to GitHub."
    echo ""
    gh auth login
    done_msg "GitHub login complete"
fi

# ── Git Config ────────────────────────────────────────────────────────────────
step "Checking git identity..."
GIT_NAME=$(git config --global user.name 2>/dev/null || true)
GIT_EMAIL=$(git config --global user.email 2>/dev/null || true)

if [ -n "$GIT_NAME" ] && [ -n "$GIT_EMAIL" ]; then
    skip "Git identity already set to '$GIT_NAME <$GIT_EMAIL>'"
else
    echo ""
    if [ -z "$GIT_NAME" ]; then
        GIT_NAME=$(gum input --placeholder "Your full name" --prompt "  Name › ")
        git config --global user.name "$GIT_NAME"
    fi
    if [ -z "$GIT_EMAIL" ]; then
        GIT_EMAIL=$(gum input --placeholder "your@email.com" --prompt "  Email › ")
        git config --global user.email "$GIT_EMAIL"
    fi
    done_msg "Git identity set to '$GIT_NAME <$GIT_EMAIL>'"
fi

# ── nvm ───────────────────────────────────────────────────────────────────────
step "Checking nvm..."
if [ -d "$HOME/.nvm" ]; then
    skip "nvm already installed"
else
    gum spin --spinner dot --title "Installing nvm..." -- \
        bash -c 'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash'

    # Add nvm init to .bashrc if not already there
    if ! grep -q 'NVM_DIR' "$HOME/.bashrc"; then
        cat >> "$HOME/.bashrc" << 'EOF'

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
EOF
    fi
    done_msg "nvm installed"
fi

# Source nvm for this session
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# ── Node ──────────────────────────────────────────────────────────────────────
step "Checking Node.js..."
if command -v node &>/dev/null; then
    skip "Node.js $(node --version) already installed"
else
    gum spin --spinner dot --title "Installing Node.js LTS..." -- \
        bash -c ". $HOME/.nvm/nvm.sh && nvm install --lts && nvm alias default node"
    done_msg "Node.js $(node --version) installed"
fi

# ── Claude Code ───────────────────────────────────────────────────────────────
step "Checking Claude Code..."
if command -v claude &>/dev/null; then
    skip "Claude Code already installed"
else
    gum spin --spinner dot --title "Installing Claude Code..." -- \
        npm install -g @anthropic-ai/claude-code
    done_msg "Claude Code installed"
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}"
echo "  ╔══════════════════════════════════════════╗"
echo "  ║         WSL Setup Complete! 🎉           ║"
echo "  ╚══════════════════════════════════════════╝"
echo -e "${NC}"
echo -e "  ${BOLD}Next steps:${NC}"
echo -e "    • Restart your terminal or run: ${CYAN}source ~/.bashrc${NC}"
echo -e "    • Start Claude Code with: ${CYAN}claude${NC}"
echo ""
