local wezterm = require 'wezterm'
return {
  default_prog = { 'powershell.exe' },
  launch_menu = {
    { label = 'PowerShell', args = { 'powershell.exe' } },
    { label = 'Ubuntu (WSL)', args = { 'wsl.exe', '-d', 'Ubuntu', '--cd', '~' } },
  },
}