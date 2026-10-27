# WSL-only shell additions, sourced from ~/.bashrc. wsl/setup.sh copies this
# to ~/.config/windows-setup/bashrc.sh - edit the repo copy and re-run it.
# Prompt, aliases and tool inits live in devcon-dotfiles (shell/*.sh).

case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac

# Company root certificate installed by setup.sh (CORP_CA=...): node, python
# and pip bundle their own CA lists and ignore the system store otherwise.
if [ -f /usr/local/share/ca-certificates/corp-ca.crt ]; then
	export NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt
	export REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
	export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
fi

# fzf via fd: respects .gitignore, includes dotfiles
if command -v fd >/dev/null 2>&1; then
	export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
	export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
	export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
fi

# Windows interop
alias open='explorer.exe'  # open . -> Explorer in the current directory
alias clip='clip.exe'      # some-command | clip -> Windows clipboard
