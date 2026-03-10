# TOOLS.md

## Runtime

- Shell: `bash`
- Platform: Windows + Git Bash / WSL
- Bridge: PowerShell `System.Windows.Forms.SendKeys`

## Common Commands

- `bash scripts/d-switch.sh Dalt -2`
- `bash scripts/d-switch.sh Dctrl -4`
- `bash scripts/security-audit.sh`

## Gotchas

- 脚本会真实切换焦点，执行前确保当前窗口状态可控
- 某些系统策略可能限制 `SendKeys`
