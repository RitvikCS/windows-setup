#!/usr/bin/env bash
# wsl/setup.sh - Linux side of the dev setup, run inside Ubuntu (WSL) as your
# normal user, after setup-windows.ps1:
#
#   bash /mnt/c/Users/<you>/dev/windows-setup/wsl/setup.sh
#
# Behind a TLS-inspecting proxy (see README troubleshooting), point it at the
# exported company root certificate:
#
#   CORP_CA=/mnt/c/Users/<you>/corp-ca.cer bash .../wsl/setup.sh
#
# Shell tools, prompt and nvim config come from devcon-dotfiles so every Linux
# box shares one copy. Safe to re-run.
set -euo pipefail

DOTFILES_REPO="${DOTFILES_REPO:-https://github.com/RitvikCS/devcon-dotfiles}"
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dev/devcon-dotfiles}"
CORP_CA="${CORP_CA:-}"
NVIM_MIN=0.11.2 # LazyVim's minimum
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

GREEN='\033[0;32m' YELLOW='\033[1;33m' CYAN='\033[0;36m' GRAY='\033[0;90m'
RED='\033[0;31m' MAGENTA='\033[0;35m' BOLD='\033[1m' NC='\033[0m'
step() { echo -e "\n${CYAN}  > $1${NC}"; }
ok() { echo -e "    ${GREEN}[OK] $1${NC}"; }
skip() { echo -e "    ${GRAY}[--] $1${NC}"; }
info() { echo -e "    ...  $1"; }
die() {
	echo -e "    ${RED}[!!] $1${NC}"
	exit 1
}
TODO=()
todo() {
	echo -e "    ${YELLOW}[!!] $1${NC}"
	TODO+=("$1")
}
have() { command -v "$1" >/dev/null 2>&1; }

echo -e "${MAGENTA}${BOLD}"
echo "  =========================================="
echo "       WSL Dev Environment Setup"
echo "  =========================================="
echo -e "${NC}"

# --- Preflight -----------------------------------------------------------------
step "Preflight checks"
[ "$(id -u)" -ne 0 ] || die "Run as your normal user, not root (sudo is used where needed)."
grep -qi microsoft /proc/version || info "this doesn't look like WSL - continuing anyway"
[ "$(uname -m)" = x86_64 ] || die "Only x86_64 is handled (Miniforge/nvim downloads)."
sudo -v || die "sudo failed"
ok "user $(whoami), sudo works"

# --- Company root certificate (TLS-inspecting proxies like Zscaler) -----------------
if [ -n "$CORP_CA" ]; then
	step "Company root certificate"
	[ -f "$CORP_CA" ] || die "CORP_CA=$CORP_CA does not exist"
	tmp_pem="$(mktemp)"
	# Accept PEM or DER (what Windows' Export-Certificate writes); strip CRLF
	if ! tr -d '\r' <"$CORP_CA" | openssl x509 -out "$tmp_pem" 2>/dev/null; then
		openssl x509 -inform der -in "$CORP_CA" -out "$tmp_pem" || die "$CORP_CA is not a PEM or DER certificate"
	fi
	if cmp -s "$tmp_pem" /usr/local/share/ca-certificates/corp-ca.crt; then
		skip "already trusted"
	else
		sudo install -m 644 "$tmp_pem" /usr/local/share/ca-certificates/corp-ca.crt
		sudo update-ca-certificates >/dev/null
		ok "installed into the system trust store"
	fi
	rm -f "$tmp_pem"
fi

step "HTTPS connectivity"
# Judge by curl's exit code, not the HTTP status: a proxy block page is still a
# working connection, while 35/60/77 etc. mean the TLS handshake/cert failed.
rc=0
curl -sS -o /dev/null --max-time 15 https://github.com 2>/dev/null || rc=$?
case $rc in
0) ok "github.com reachable" ;;
35 | 51 | 53 | 54 | 58 | 59 | 60 | 66 | 77 | 80 | 82 | 83 | 90 | 91)
	die "github.com answers but its certificate isn't trusted (curl exit $rc): a proxy is inspecting TLS.
         Export your company's root certificate (README > Troubleshooting) and re-run with CORP_CA=<path>." ;;
*) die "No HTTPS from WSL (curl exit $rc). On VPN? See README > Troubleshooting (mirrored networking)." ;;
esac

# --- System packages -------------------------------------------------------------
step "System packages (apt)"
PACKAGES=(build-essential curl wget git unzip zip jq ripgrep fd-find htop tree ca-certificates gnupg)
MISSING=()
for pkg in "${PACKAGES[@]}"; do
	dpkg -s "$pkg" >/dev/null 2>&1 || MISSING+=("$pkg")
done
if [ ${#MISSING[@]} -eq 0 ]; then
	skip "all present"
else
	sudo apt-get update -qq
	sudo apt-get install -y -qq "${MISSING[@]}"
	ok "installed: ${MISSING[*]}"
fi
# Ubuntu names fd "fdfind"
mkdir -p "$HOME/.local/bin"
if have fdfind && [ ! -e "$HOME/.local/bin/fd" ]; then
	ln -s "$(command -v fdfind)" "$HOME/.local/bin/fd"
fi
export PATH="$HOME/.local/bin:$PATH"

# --- GitHub CLI ----------------------------------------------------------------------
step "GitHub CLI"
if have gh; then
	skip "gh $(gh --version | awk 'NR==1 {print $3}')"
else
	# Official apt repo: https://github.com/cli/cli/blob/trunk/docs/install_linux.md
	sudo mkdir -p -m 755 /etc/apt/keyrings
	curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg |
		sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
	sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
	echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" |
		sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
	sudo apt-get update -qq && sudo apt-get install -y -qq gh
	ok "gh installed"
fi

if gh auth status >/dev/null 2>&1; then
	skip "already logged in to GitHub"
elif gh auth login && gh auth setup-git; then
	ok "logged in; git uses gh for HTTPS credentials"
else
	todo "GitHub login did not finish - run: gh auth login && gh auth setup-git"
fi

# --- Git identity --------------------------------------------------------------------
step "Git identity"
GIT_NAME=$(git config --global user.name || true)
GIT_EMAIL=$(git config --global user.email || true)
if [ -n "$GIT_NAME" ] && [ -n "$GIT_EMAIL" ]; then
	skip "$GIT_NAME <$GIT_EMAIL>"
else
	[ -n "$GIT_NAME" ] || { read -rp "    Full name for commits: " GIT_NAME && git config --global user.name "$GIT_NAME"; }
	[ -n "$GIT_EMAIL" ] || { read -rp "    Default (work) email for commits: " GIT_EMAIL && git config --global user.email "$GIT_EMAIL"; }
	ok "$GIT_NAME <$GIT_EMAIL>"
fi
if git config --global --get 'includeIf.gitdir:~/personal/.path' >/dev/null; then
	skip "personal email for ~/personal/ already configured"
else
	read -rp "    Personal email for repos under ~/personal/ (Enter to skip): " PERSONAL_EMAIL
	if [ -n "$PERSONAL_EMAIL" ]; then
		git config --file "$HOME/.gitconfig-personal" user.email "$PERSONAL_EMAIL"
		# shellcheck disable=SC2088 # git expands the ~ itself
		git config --global 'includeIf.gitdir:~/personal/.path' '~/.gitconfig-personal'
		ok "repos under ~/personal/ commit as $PERSONAL_EMAIL"
	fi
fi

# --- devcon-dotfiles: eza, bat, fzf, zoxide, starship, fnm, nvim + starship config ----
step "Dotfiles ($DOTFILES_REPO)"
if [ -d "$DOTFILES_DIR/.git" ]; then
	git -C "$DOTFILES_DIR" pull --ff-only -q || todo "could not fast-forward $DOTFILES_DIR - update it by hand"
	skip "already cloned, pulled latest"
else
	mkdir -p "$(dirname "$DOTFILES_DIR")"
	git clone -q "$DOTFILES_REPO" "$DOTFILES_DIR"
	ok "cloned to $DOTFILES_DIR"
fi
bash "$DOTFILES_DIR/install.sh"

# --- Node (fnm was installed by the dotfiles when no node exists) --------------------------
step "Node.js LTS (via fnm)"
[ -d "$HOME/.local/share/fnm" ] && export PATH="$HOME/.local/share/fnm:$PATH"
if have fnm; then
	eval "$(fnm env --shell bash)"
	if fnm list | grep -q 'v[0-9]'; then
		skip "fnm already manages node"
	else
		fnm install --lts && fnm default lts-latest
		ok "node LTS installed"
	fi
elif have node; then
	skip "node $(node --version) present (not fnm-managed)"
else
	todo "no fnm or node - check the dotfiles install output above"
fi

# --- Neovim (apt's build is too old for LazyVim on Ubuntu < 26.04) -------------------------
step "Neovim >= $NVIM_MIN"
nvim_version() { nvim --version 2>/dev/null | awk 'NR==1 {sub(/^v/, "", $2); print $2}'; }
if have nvim && dpkg --compare-versions "$(nvim_version)" ge "$NVIM_MIN"; then
	skip "nvim $(nvim_version)"
else
	candidate=$(apt-cache policy neovim | awk '/Candidate:/ {print $2}')
	if [ -n "$candidate" ] && [ "$candidate" != "(none)" ] && dpkg --compare-versions "$candidate" ge "$NVIM_MIN"; then
		sudo apt-get install -y -qq neovim
	else
		info "apt has neovim ${candidate:-none}; using the official release tarball"
		tmp_tar="$(mktemp)"
		curl -fsSL -o "$tmp_tar" https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
		sudo rm -rf /opt/nvim-linux-x86_64
		sudo tar -C /opt -xzf "$tmp_tar"
		sudo ln -sfn /opt/nvim-linux-x86_64/bin/nvim /usr/local/bin/nvim
		rm -f "$tmp_tar"
	fi
	hash -r
	ok "nvim $(nvim_version)"
fi

# --- Miniforge (conda + conda-forge, no Anaconda licence needed) ---------------------------
step "Miniforge (conda)"
CONDA_DIR="$HOME/miniforge3"
if [ -x "$CONDA_DIR/bin/conda" ]; then
	skip "already installed at $CONDA_DIR"
elif have conda; then
	skip "conda already on PATH at $(command -v conda) - leaving it alone"
else
	installer="$(mktemp --suffix=.sh)"
	curl -fsSL -o "$installer" "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh"
	bash "$installer" -b -p "$CONDA_DIR" >/dev/null
	rm -f "$installer"
	"$CONDA_DIR/bin/conda" init bash >/dev/null
	ok "installed to $CONDA_DIR"
fi
if [ -x "$CONDA_DIR/bin/conda" ]; then
	# Keep the shell on system python until you `conda activate`; starship shows the env
	# conda 25.x renamed auto_activate_base -> auto_activate; try the new key first
	"$CONDA_DIR/bin/conda" config --set auto_activate false 2>/dev/null ||
		"$CONDA_DIR/bin/conda" config --set auto_activate_base false
	"$CONDA_DIR/bin/conda" config --set changeps1 false
	if [ -n "$CORP_CA" ]; then
		"$CONDA_DIR/bin/conda" config --set ssl_verify /etc/ssl/certs/ca-certificates.crt
	fi
fi

# --- Claude Code ---------------------------------------------------------------------------
step "Claude Code CLI"
if have claude || [ -x "$HOME/.local/bin/claude" ]; then
	skip "already installed"
elif curl -fsSL https://claude.ai/install.sh | bash; then
	ok "installed (log in by running: claude)"
else
	todo "Claude Code install failed - re-run: curl -fsSL https://claude.ai/install.sh | bash"
fi

# --- Shell extras (WSL-only bits devcon-dotfiles doesn't carry) ----------------------------
step "Shell extras"
mkdir -p "$HOME/.config/windows-setup"
cp "$SCRIPT_DIR/bashrc.sh" "$HOME/.config/windows-setup/bashrc.sh"
MARKER="# >>> windows-setup >>>"
if grep -qF "$MARKER" "$HOME/.bashrc"; then
	skip "already hooked into ~/.bashrc"
else
	cat >>"$HOME/.bashrc" <<EOF

$MARKER
[ -r "\$HOME/.config/windows-setup/bashrc.sh" ] && . "\$HOME/.config/windows-setup/bashrc.sh"
# <<< windows-setup <<<
EOF
	ok "hooked into ~/.bashrc"
fi

# --- Summary -------------------------------------------------------------------------------
echo -e "\n${GREEN}${BOLD}  =========================================="
echo "        WSL setup finished"
echo -e "  ==========================================${NC}"
if [ ${#TODO[@]} -gt 0 ]; then
	echo -e "\n  ${YELLOW}Still to do:${NC}"
	for t in "${TODO[@]}"; do echo -e "    ${YELLOW}- $t${NC}"; done
fi
echo -e "\n  ${BOLD}Next:${NC}"
echo "    1. exec bash            (reload the shell)"
echo "    2. claude               (log in once inside WSL)"
echo "    3. nvim                 (LazyVim installs its plugins on first start)"
echo "    Keep code in ~/dev, not /mnt/c - the Windows drive is much slower from WSL."
echo ""
