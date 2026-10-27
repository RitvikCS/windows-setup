# Manual setup guide (Windows work laptop)

Do this by hand, top to bottom. You'll **type** the lines in code blocks marked
`powershell` or `bash`, and **copy** the file contents into the places named.
Budget about 1–2 hours, mostly waiting for downloads.

Each section ends with a **Check** step. Don't move on until it passes.

---

## 0. Before anything: ask IT

- Is **WSL** allowed? Turning it on needs admin and a reboot.
- Are **Claude Code / the Claude app** approved? Many companies have an AI-tools policy.
- Is it OK to sign in to a **personal GitHub** account on this laptop?
- Does the company **inspect HTTPS traffic** (Zscaler, Netskope...)? If they say yes,
  or you see a Zscaler icon in the system tray, you'll need section 9.

---

## 1. Apps you download yourself

| App | Where |
|---|---|
| VS Code | https://code.visualstudio.com/ (then add the **WSL** extension, `ms-vscode-remote.remote-wsl`) |
| Claude desktop app | https://claude.ai/download |
| JetBrainsMono Nerd Font | https://www.nerdfonts.com/font-downloads → JetBrainsMono → unzip → select all `.ttf` → right-click → **Install** |

The font matters: without a Nerd Font the prompt shows boxes instead of icons.

---

## 2. Windows tools (winget)

Open **Windows PowerShell** (not as administrator) and type these one at a time.
Accept the UAC prompt if one appears.

```powershell
winget install -e --id Git.Git
winget install -e --id Microsoft.PowerShell
winget install -e --id GitHub.cli
winget install -e --id Starship.Starship
winget install -e --id OpenJS.NodeJS.LTS
winget install -e --id ajeetdsouza.zoxide
winget install -e --id junegunn.fzf
winget install -e --id BurntSushi.ripgrep.MSVC
winget install -e --id sharkdp.fd
winget install -e --id eza-community.eza
winget install -e --id sharkdp.bat
winget install -e --id jqlang.jq
```

Windows 10 only (Windows 11 already has it): `winget install -e --id Microsoft.WindowsTerminal`

> **"Failed when searching source: msstore ... 0x8A15005E certificate did not match"?**
> Your company inspects HTTPS traffic, and winget's Microsoft Store catalogue refuses that.
> Update **App Installer** from the Microsoft Store (search it, open its page), reopen the
> terminal, then stop winget searching the Store unless asked:
> `winget source edit msstore --explicit true`
> (On an older winget without `edit`: `winget source remove msstore` from an admin terminal.)
> Until then, add `--source winget` to each install.

Node is a plain install, not fnm: it works in every terminal and app, not only in
PowerShell with your profile loaded. Per-project Node versions are handled by fnm in WSL.

**Close every terminal window.** PATH changes only reach new windows.

**Check:** open **Windows Terminal**, open a **PowerShell** tab (PowerShell 7, not
"Windows PowerShell") and run:

```powershell
git --version; gh --version; node --version; npm --version; starship --version; zoxide --version; fzf --version; rg --version; fd --version; eza --version; bat --version; jq --version
```

Every command should print a version.

---

## 3. Windows Terminal look

1. Windows Terminal → **Settings** (Ctrl+,) → bottom-left **Open JSON file**.
2. Find `"schemes": [` and paste this **inside the brackets**. If something is
   already in there, add a comma between entries:

   ```json
   {
     "name": "Catppuccin Mocha",
     "cursorColor": "#F5E0DC",
     "selectionBackground": "#585B70",
     "background": "#1E1E2E",
     "foreground": "#CDD6F4",
     "black": "#45475A",
     "red": "#F38BA8",
     "green": "#A6E3A1",
     "yellow": "#F9E2AF",
     "blue": "#89B4FA",
     "purple": "#F5C2E7",
     "cyan": "#94E2D5",
     "white": "#BAC2DE",
     "brightBlack": "#585B70",
     "brightRed": "#F38BA8",
     "brightGreen": "#A6E3A1",
     "brightYellow": "#F9E2AF",
     "brightBlue": "#89B4FA",
     "brightPurple": "#F5C2E7",
     "brightCyan": "#94E2D5",
     "brightWhite": "#A6ADC8"
   }
   ```
3. Find `"defaults": {}` under `"profiles"` and replace it with:

   ```json
   "defaults": {
     "colorScheme": "Catppuccin Mocha",
     "font": { "face": "JetBrainsMono Nerd Font" }
   },
   ```
4. Save. If Terminal complains, a comma is missing or extra. Fix it and save again.
5. Settings → **Startup** → Default profile → **PowerShell** (switch it to Ubuntu
   after section 7).

**Check:** the background turns dark purple-grey.

---

## 4. Prompt + PowerShell profile

**Starship config.** Type:

```powershell
mkdir $HOME\.config -Force
notepad $HOME\.config\starship.toml
```

Notepad asks to create the file: click Yes. Paste the contents of
[devcon-dotfiles/config/starship.toml](https://github.com/RitvikCS/devcon-dotfiles/blob/main/config/starship.toml)
(use the **Raw** button, then select all and copy). Save.

**Profile.** Type:

```powershell
New-Item -ItemType File -Force $PROFILE
notepad $PROFILE
```

Paste this, then save. It's also in the repo as
[windows/profile.ps1](https://github.com/RitvikCS/windows-setup/blob/main/windows/profile.ps1)
(click **Raw** to copy it):

```powershell
# Claude Code's installer puts claude.exe here
$localBin = Join-Path $HOME '.local\bin'
if ((Test-Path $localBin) -and (($env:PATH -split ';') -notcontains $localBin)) {
    $env:PATH = "$localBin;$env:PATH"
}

# eza / bat instead of ls / cat (these return text: use Get-ChildItem / Get-Content in pipelines)
Remove-Item Alias:ls -Force -ErrorAction SilentlyContinue
Remove-Item Alias:cat -Force -ErrorAction SilentlyContinue
function ls   { eza --icons=auto @args }
function ll   { eza -l --icons=auto --git @args }
function la   { eza -la --icons=auto --git @args }
function tree { eza --tree --icons=auto @args }
function cat  { bat --paging=never @args }

# fzf lists files with fd; PSFzf gives Ctrl+R history, Ctrl+T files, Alt+C cd
$env:FZF_DEFAULT_COMMAND = 'fd --type f --hidden --follow --exclude .git'
$env:FZF_CTRL_T_COMMAND  = $env:FZF_DEFAULT_COMMAND
$env:FZF_ALT_C_COMMAND   = 'fd --type d --hidden --follow --exclude .git'
if (Get-Module -ListAvailable PSFzf) {
    Import-Module PSFzf
    Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
    Set-PSReadLineKeyHandler -Key 'Alt+c' -ScriptBlock { Invoke-FuzzySetLocation }
}

# zoxide: z <dir> jumps, zi picks
Invoke-Expression (& { (zoxide init powershell | Out-String) })

# starship last
Invoke-Expression (& starship init powershell)
```

Install the fzf keybindings module (answer **Y** if it asks about an untrusted repository):

```powershell
Install-Module PSFzf -Scope CurrentUser
```

**Check:** open a new PowerShell tab. You should see the coloured prompt with icons
(not boxes), `ll` gives a coloured listing, and Ctrl+R opens a fuzzy history search.

> If it says "running scripts is disabled", your company locks the execution policy.
> Try `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`. If that's refused, ask IT.

---

## 5. Node, Claude Code, git, GitHub (Windows)

First check Git can reach GitHub through the company network (no login needed):

```powershell
git config --show-origin --get-all http.sslBackend
git ls-remote https://github.com/RitvikCS/windows-setup
```

If `ls-remote` prints `refs/heads/main`, Git already works. Git for Windows' installer
usually sets `schannel` (Windows' certificate store) in `C:\Program Files\Git\etc\gitconfig`.
Only if it says `SSL certificate problem`, run
`git config --global http.sslBackend schannel` and test again.

```powershell
git config --global user.name  "Your Name"
git config --global user.email "you@work.com"
irm https://claude.ai/install.ps1 | iex
gh auth login
```

The name and email are just
text; `gh auth login` is the step that needs your GitHub account (pick GitHub.com →
HTTPS → Login with a web browser). Claude Code logs in with your Claude account, not GitHub.

Open a **new** tab, then:

```powershell
claude          # log in once
```

**If `npm install` fails with `SELF_SIGNED_CERT_IN_CHAIN`**, make Node trust Windows'
certificate store, then open a new tab:

```powershell
[Environment]::SetEnvironmentVariable('NODE_OPTIONS', '--use-system-ca', 'User')
```

**Optional, for a personal email on personal repos.** Anything cloned under
`C:\Users\<you>\personal\` will commit with this email:

```powershell
git config --file $HOME\.gitconfig-personal user.email "you@personal.com"
git config --global includeIf.gitdir:~/personal/.path "~/.gitconfig-personal"
```

---

## 6. Turn on WSL (after IT says yes)

Open PowerShell **as Administrator**:

```powershell
wsl --install
```

Reboot. Ubuntu opens by itself and asks for a **Linux username and password**. This is
a separate account; the password is what `sudo` will ask for.

**If you use a VPN**, create `C:\Users\<you>\.wslconfig` (e.g. `notepad $HOME\.wslconfig`)
with:

```ini
[wsl2]
networkingMode=mirrored
```

then run `wsl --shutdown` in PowerShell and reopen Ubuntu.

---

## 7. Ubuntu (WSL) basics

Everything from here is typed in the **Ubuntu** tab. In Windows Terminal Settings →
Startup, set the default profile to **Ubuntu** now.

First, test that downloads work:

```bash
curl -sSI https://github.com | head -1
```

- `HTTP/2 200` → good, continue.
- `SSL certificate problem` → do **section 9** first, then come back.
- Hangs or `Could not resolve host` → VPN problem, see the `.wslconfig` step in section 6.

Then:

```bash
sudo apt update
sudo apt install -y build-essential curl wget git unzip zip jq ripgrep fd-find htop tree gh
mkdir -p ~/.local/bin && ln -sf "$(command -v fdfind)" ~/.local/bin/fd
git config --global user.name  "Your Name"
git config --global user.email "you@work.com"
gh auth login
gh auth setup-git
```

**Check:** `gh auth status` says "Logged in".

---

## 8. Ubuntu dev environment

### Shell tools + prompt (your devcon-dotfiles)

Clone it rather than copying files by hand. The configs are symlinked, so a later
`git pull` keeps this machine in sync with your others. (Hand-copied configs go stale,
which is exactly what happened to the old windows-setup repo.)

```bash
git clone https://github.com/RitvikCS/devcon-dotfiles ~/dev/devcon-dotfiles
bash ~/dev/devcon-dotfiles/install.sh
```

That installs eza, bat, fzf, zoxide, starship and fnm, links `starship.toml` and the
LazyVim config into `~/.config`, and hooks its aliases into `~/.bashrc`. Read
`install.sh` first if you like; it's short.

### Node

```bash
exec bash
fnm install --lts
node --version
```

### Neovim (LazyVim needs 0.11.2 or newer)

```bash
apt-cache policy neovim | grep Candidate
```

- Candidate **0.11.2 or higher** (Ubuntu 26.04): `sudo apt install -y neovim`
- Lower (Ubuntu 24.04 has 0.9.5): use the official build:

```bash
curl -fLo /tmp/nvim.tar.gz https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
sudo tar -C /opt -xzf /tmp/nvim.tar.gz
sudo ln -sf /opt/nvim-linux-x86_64/bin/nvim /usr/local/bin/nvim
nvim --version | head -1
```

### Python: Miniforge (conda)

It's the same `conda` as Miniconda, but it uses the free conda-forge channel instead of
Anaconda's, which needs a paid licence at companies with 200+ employees.

```bash
curl -fLo /tmp/miniforge.sh https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh
bash /tmp/miniforge.sh
```

Accept the licence, keep the default location, and answer **yes** to "initialize conda". Then:

```bash
exec bash
conda config --set auto_activate false
conda config --set changeps1 false
```

(starship already shows the active env, so `changeps1 false` stops conda adding a second label to the prompt.)

### Claude Code

```bash
curl -fsSL https://claude.ai/install.sh | bash
exec bash
claude          # log in (separate from the Windows install)
```

### A few WSL extras

`nano ~/.bashrc` (or `nvim`), paste this at the bottom, then save:

```bash
# fzf via fd
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
# Windows interop
alias open='explorer.exe'   # open . -> Explorer here
alias clip='clip.exe'       # cmd | clip -> Windows clipboard
```

**Check:** in a new Ubuntu tab you have the starship prompt, `ll` works, Ctrl+R opens fzf,
`z <dir>` jumps, `nvim` installs its plugins on first start, and `code .` opens VS Code
attached to WSL.

**Keep your code in `~/dev` inside Ubuntu, not under `/mnt/c`.** The Windows drive is
much slower from Linux.

---

## 9. Only if HTTPS fails in Ubuntu (company proxy certificate)

The proxy re-signs HTTPS traffic with a company certificate. Windows trusts it; Ubuntu doesn't.

**In Edge:** open https://github.com → padlock → certificate → note the name at the top of
the chain (e.g. "Zscaler Root CA"). **In PowerShell** (replace `Zscaler` with that name):

```powershell
Get-ChildItem Cert:\LocalMachine\Root | Where-Object Subject -match 'Zscaler'
```

If exactly one appears:

```powershell
$cert = Get-ChildItem Cert:\LocalMachine\Root | Where-Object Subject -match 'Zscaler' | Select-Object -First 1
Export-Certificate -Cert $cert -FilePath $HOME\corp-ca.cer
```

**In Ubuntu** (replace `<you>` with your Windows username):

```bash
openssl x509 -inform der -in /mnt/c/Users/<you>/corp-ca.cer -out /tmp/corp-ca.crt
sudo cp /tmp/corp-ca.crt /usr/local/share/ca-certificates/corp-ca.crt
sudo update-ca-certificates
```

Then add to the bottom of `~/.bashrc` (Node and Python don't read the system store):

```bash
export NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt
export REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
```

And after installing Miniforge: `conda config --set ssl_verify /etc/ssl/certs/ca-certificates.crt`

**Check:** `curl -sSI https://github.com | head -1` shows `HTTP/2 200`.
