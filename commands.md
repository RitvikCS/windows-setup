# Windows Dev Setup — Step by Step

Follow these steps in order. Each section has a check so you know when you're done.

---

## Step 1 — Fix Git Line Endings

Run this once to suppress LF/CRLF warnings:

```powershell
git config --global core.autocrlf true
```

---

## Step 2 — Allow PowerShell Scripts to Run

Open PowerShell as Administrator and run:

```powershell
Set-ExecutionPolicy Unrestricted
```

To verify it worked:

```powershell
Get-ExecutionPolicy
# Should output: Unrestricted
```

---

## Step 2 — Install WSL + Ubuntu

Still in PowerShell (as Administrator):

```powershell
wsl --install
```

> This may require a **restart**. After restarting, open PowerShell again and continue.

If Ubuntu wasn't installed automatically:

```powershell
wsl --install -d Ubuntu
```

Once Ubuntu opens, set a username and password when prompted — this is your Linux account.

---

## Step 3 — Run the Windows Setup Script

In PowerShell (does **not** need to be Administrator):

```powershell
powershell -ExecutionPolicy Bypass -File setup-windows.ps1
```

This installs: **Git, GitHub CLI, WezTerm, fnm, Scoop, Starship, Node.js, Claude Code**

It will skip anything already installed and prompt you for your name/email if not set.

> After it finishes, **restart your terminal** before continuing.

---

## Step 4 — Run the WSL Setup Script

Open Ubuntu (from Start menu or `wsl` in PowerShell), navigate to this folder, and run:

```bash
bash setup-wsl.sh
```

This installs: **GitHub CLI, nvm, Node.js, Claude Code, Miniconda, Starship** inside Linux.

It will also prompt you to log into GitHub and set your git identity if not already done.

> After it finishes, run `source ~/.bashrc` or restart your terminal.

To have conda's base environment activate automatically on every shell open:

```bash
conda config --set auto_activate_base true
```

---

## Done

You should now have a working dev environment on both Windows and WSL. To verify:

```powershell
# In PowerShell
gh auth status
git config --global --list
node --version
claude --version
```

```bash
# In WSL
gh auth status
node --version
claude --version
```
