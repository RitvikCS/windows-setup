# windows-setup

Sets up a Windows laptop (work or personal) for development: Windows Terminal
with the same Catppuccin Mocha Starship prompt as my Linux machines, Node and
Claude Code on Windows, and a full Linux toolchain inside WSL.

The Linux side reuses [devcon-dotfiles](https://github.com/RitvikCS/devcon-dotfiles)
(eza, bat, fzf, zoxide, starship, LazyVim config), and the Windows prompt downloads
its `starship.toml` from there too. Change the prompt in that repo, not here.

| Where | What gets installed |
|---|---|
| Windows (`setup-windows.ps1`) | Windows Terminal (themed, Nerd Font, Ubuntu as default tab), GitHub CLI, Starship, fnm + Node LTS, zoxide, fzf, ripgrep, Claude Code CLI, PowerShell profile, git identity, `.wslconfig` |
| WSL Ubuntu (`wsl/setup.sh`) | build tools, ripgrep, fd, jq, GitHub CLI, devcon-dotfiles, fnm + Node LTS, Neovim ≥ 0.11.2, Miniforge (conda), Claude Code CLI, git identity |

## Before you start (by hand, once)

1. **Check with IT** before installing anything, because it's their laptop:
   - Is WSL allowed? Enabling it needs admin rights and a reboot.
   - Are Claude Code / the Claude desktop app approved? Many companies have an AI-tools policy.
   - Is it OK to sign in to a personal GitHub account on this machine?
   - Does the company inspect HTTPS traffic (Zscaler, Netskope, etc.)? If you
     don't know, see [Troubleshooting](#curl-apt-or-claude-fail-with-certificate-errors);
     the WSL script detects it and tells you.
2. **Install Git and PowerShell 7.** Open the built-in "Windows PowerShell" and run:
   ```powershell
   winget install --id Git.Git -e
   winget install --id Microsoft.PowerShell -e
   ```
   (Or download them: [git-scm.com](https://git-scm.com/downloads/win),
   [PowerShell 7](https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-windows).)
3. **Install a Nerd Font.** Without one the prompt shows boxes instead of icons.
   Download **JetBrainsMono** from [nerdfonts.com](https://www.nerdfonts.com/font-downloads),
   unzip it, select all the `.ttf` files, right-click → **Install**.
   (Or `winget install --id DEVCOM.JetBrainsMonoNerdFont -e`.)
   If you pick a different Nerd Font, pass its name: `-FontFace "FiraCode Nerd Font"`.
4. **Open Windows Terminal once** and close it. That creates the settings file the
   script themes. It comes with Windows 11; on Windows 10 the script installs it, so
   re-run the script after opening it.
5. **Enable WSL** (once IT says yes). Open PowerShell **as Administrator**:
   ```powershell
   wsl --install
   ```
   Reboot. Ubuntu opens and asks for a Linux username and password (this is a separate
   account from Windows; the password is what `sudo` asks for). You can do this step
   later. The Windows script works without WSL and tells you what's left.
6. **Install the apps you want yourself** (the scripts only set up dev tooling):
   - [VS Code](https://code.visualstudio.com/), then add its **WSL** extension
     (`ms-vscode-remote.remote-wsl`) so `code .` inside Ubuntu opens the folder with the
     Linux toolchain. In VS Code settings, set the terminal font to your Nerd Font
     (`"terminal.integrated.fontFamily": "JetBrainsMono Nerd Font"`), or the prompt shows boxes there.
   - [Claude desktop app](https://claude.ai/download).

## Run it

**1. Windows.** Open a new, **non-admin** PowerShell 7 window (`pwsh`):

```powershell
mkdir $HOME\dev -Force; cd $HOME\dev
git clone https://github.com/RitvikCS/windows-setup.git
cd windows-setup
pwsh -ExecutionPolicy Bypass -File .\setup-windows.ps1
```

It asks for your name, your work email, an optional personal email (used for repos under
`~/personal/`), whether you use a VPN, and runs `gh auth login`. When it finishes it
prints a **Still to do** list for anything it couldn't do. It doesn't stop at the first problem.

Then close the window and open a new Windows Terminal, then run `claude` once to log in.

**2. WSL.** In the Ubuntu tab:

```bash
bash /mnt/c/Users/<you>/dev/windows-setup/wsl/setup.sh
```

The Windows script prints this command with your real path. Then `exec bash`,
`claude` (log in again; WSL is a separate install), and `nvim` (LazyVim installs
its plugins on first launch).

Both scripts are safe to re-run, e.g. after `git pull`. They skip whatever is already
done and back up any file they replace (`*.bak`).

## Day to day

- **Keep code inside WSL** (`~/dev/...`), not under `/mnt/c`. Cross-filesystem access is
  many times slower, and file watchers misbehave there. `open .` opens the current WSL folder
  in Explorer, and `code .` opens it in VS Code if you use it.
- **Python:** `conda create -n myproj python=3.12 && conda activate myproj`. The base
  env doesn't auto-activate, and Starship shows the active env.
- **Node:** fnm switches versions per project from `.nvmrc` / `.node-version` (`fnm use`, `fnm install 20`).
- **Claude Code** is installed twice, once on Windows and once in WSL. Use the WSL one for
  Linux projects (it supports sandboxing), and the Windows one for Windows-only projects.

### Why Miniforge instead of Miniconda?

It's the same `conda`, with the same commands and environments. The only difference is
the default package channel. Miniconda defaults to Anaconda's `defaults` channel, and
Anaconda's terms require a paid licence for organisations with 200+ employees. Miniforge
defaults to the community **conda-forge** channel, which is free for everyone. On a work
laptop that's the safe choice. If your company already pays for Anaconda, either is fine.

## Troubleshooting

### `curl`, `apt` or `claude` fail with certificate errors

Your company probably runs a TLS-inspecting proxy (Zscaler is the common one; look for its
icon in the system tray). It re-signs HTTPS traffic with a company root certificate. Windows
trusts that certificate because IT installed it, but WSL's Linux doesn't, so every
download there fails. `wsl/setup.sh` detects this and stops with a message.

To confirm: open `https://github.com` in Edge → padlock → certificate. If the top of the chain
is your company or Zscaler (not e.g. *Sectigo* / *USERTrust*), that's it. Export that
root from PowerShell (replace `Zscaler` with the name you saw):

```powershell
Get-ChildItem Cert:\LocalMachine\Root | Where-Object Subject -match 'Zscaler'
# exactly one result? then:
$cert = Get-ChildItem Cert:\LocalMachine\Root | Where-Object Subject -match 'Zscaler' | Select-Object -First 1
Export-Certificate -Cert $cert -FilePath $HOME\corp-ca.cer
```

Then re-run the WSL script with it:

```bash
CORP_CA=/mnt/c/Users/<you>/corp-ca.cer bash /mnt/c/Users/<you>/dev/windows-setup/wsl/setup.sh
```

It adds the certificate to Ubuntu's trust store and points Node, Python/pip and conda at it.

### WSL has no internet while on VPN

Edit `%USERPROFILE%\.wslconfig` and make sure it has:

```ini
[wsl2]
networkingMode=mirrored
```

then `wsl --shutdown` in PowerShell and reopen Ubuntu. (DNS tunneling and auto-proxy are on by
default on Windows 11 22H2+.) Microsoft lists some VPNs and Zscaler/Global Secure Access
setups that still misbehave, see
[WSL troubleshooting](https://learn.microsoft.com/windows/wsl/troubleshooting#common-issues).

### Something isn't found right after the script finishes

PATH changes only reach **new** terminals. Close every Windows Terminal window and reopen.

### The script refuses to run or the profile doesn't load

- "Run this from a normal window": don't use "Run as administrator".
- "ConstrainedLanguage mode": IT has locked PowerShell down, so ask them; the profile can't work.
- Windows PowerShell 5.1 profile not loading: its execution policy is set by IT. PowerShell 7
  (the default in Windows Terminal after setup) is unaffected.
