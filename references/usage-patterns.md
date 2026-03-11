# Usage Patterns

## Cross-Platform First Step

- Windows：优先执行 Windows 原生入口。
- Windows 首选：
  - `scripts\d-switch.cmd activate-window <关键字>`
  - `powershell -File scripts/d-switch.ps1 activate-window <关键字>`
- Git Bash / WSL 兼容：
  - `bash scripts/d-switch.sh activate-window <关键字>`
- macOS：当前仓库无同等自动化脚本，使用快捷键降级。
- macOS 快捷键建议：窗口 `Cmd+Tab`，页签 `Ctrl+Tab` 或 `Cmd+Shift+]`。

## Preferred Path (窗口操作优先级)

- 首选：`scripts\d-switch.cmd activate-window <关键字>`
- 次选：`scripts\d-switch.cmd find-window <关键字> 3` 后执行 `scripts\d-switch.cmd activate-window <关键字>`
- 进程稳定时：`scripts\d-switch.cmd activate-process <进程名>`
- 已有句柄时：`scripts\d-switch.cmd activate-handle <句柄>`
- 回退：仅在无法明确命中窗口时，使用 `scripts\d-switch.cmd Dalt -1`
- Git Bash / WSL 兼容路径：`bash scripts/d-switch.sh ...`

## Canonical Intent -> Command

- 意图：切到某个明确窗口
- 命令：`scripts\d-switch.cmd activate-window <关键字>`
- 意图：窗口不明确，先看候选
- 命令：`scripts\d-switch.cmd find-window <关键字> 3 --json`
- 意图：在候选中激活第 n 个
- 命令：`scripts\d-switch.cmd activate-window <关键字> <候选序号> --json`
- 意图：只知道进程名
- 命令：`scripts\d-switch.cmd activate-process <进程名> 1 --json`
- 意图：只知道句柄
- 命令：`scripts\d-switch.cmd activate-handle <句柄> --json`
- 意图：已在目标窗口，只切标签
- 命令：`scripts\d-switch.cmd Dctrl -1`

## Window Switching

- 命令：`scripts\d-switch.cmd Dalt -N`
- 用途：兼容/回退模式下，在多个应用窗口间小步切换
- 参数说明：兼容 `N` 与 `-N`，推荐 `-N`

## Process Window Locate

- 适用场景：用户需要查看某个进程/应用对应窗口，但当前不在前台。
- 推荐策略：先执行 `activate-window`，若不确定再 `find-window` 后 `activate-window`。
- 回退策略：仅在无法命中目标窗口时，才重复执行 `scripts\d-switch.cmd Dalt -1`。
- 找到后动作：停止切换，执行下一步业务操作。

## Window Discovery

- 命令：`scripts\d-switch.cmd list-windows`
- 用途：列出当前可操作窗口，包含最小化窗口。
- 结构化输出：`scripts\d-switch.cmd list-windows --json`

## Fuzzy Window Match

- 命令：`scripts\d-switch.cmd find-window <关键字> [候选数量]`
- 用途：按窗口标题 + 进程名做模糊匹配，输出优先级最高的前几个候选。
- 推荐策略：先查看候选列表，再决定是否要激活最佳匹配窗口。
- 结构化输出：`scripts\d-switch.cmd find-window <关键字> [候选数量] --json`

## Direct Window Activation

- 命令：`scripts\d-switch.cmd activate-window <关键字> [候选序号] [--json]`
- 用途：恢复并激活指定候选窗口，使其到前台；默认激活第 1 个候选。

## Process-first Activation

- 命令：`scripts\d-switch.cmd activate-process <进程名> [候选序号] [--json]`
- 用途：只按进程名匹配窗口，适合 VS Code、WindowsTerminal 这类标题经常变化的窗口。

## Handle Activation

- 命令：`scripts\d-switch.cmd activate-handle <句柄> [--json]`
- 用途：根据 `list-windows` / `find-window` 返回的窗口句柄，精确激活目标窗口。

## Tab Switching

- 命令：`scripts\d-switch.cmd Dctrl -N`
- 用途：浏览器或编辑器多标签快速切换
- 参数说明：兼容 `N` 与 `-N`，推荐 `-N`

## JSON Contract (Recommended)

- 推荐所有编排调用使用 `--json`
- 常见状态：`ok`、`activated`、`not_found`、`choice_out_of_range`、`activation_failed`
- 失败处理建议：
- `not_found` -> 改用更短关键词重试，或先 `list-windows --json`
- `choice_out_of_range` -> 先用 `find-window ... --json` 获取候选数
- `activation_failed` -> 优先重试 1 次，再降级 `Dalt -1`

## Exit Codes

- `0` success
- `1` bad command/args
- `2` target not found
- `3` activation failed
- `4` choice out of range
