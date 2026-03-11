---
name: dkey-switch
description: AI 窗口切换技能。用于定位并激活 Windows 上的目标窗口，支持窗口查找、进程匹配、句柄激活与标签切换回退。
argument-hint: <窗口关键字|进程名|窗口句柄>
metadata: {
   "clawdbot":{
      "emoji":"🪟",
      "requires":{
         "bins":["powershell"]
      },
      "install":[
         {"id":"winget-powershell","kind":"winget","package":"Microsoft.PowerShell","bins":["powershell"],"label":"Install PowerShell (winget)"}
      ]
   }
}
---

## Identity & Scope

本技能用于 AI 执行窗口切换动作（window focus/activation），目标是“直接定位并激活目标窗口”，而不是只给快捷键建议。

支持命令（capabilities）：

- `Dalt`：模拟 `Alt+Tab` 小步切换（回退路径）
- `Dctrl`：模拟 `Ctrl+Tab` 标签切换
- `list-windows`
- `find-window <关键字> [候选数量] [--json]`
- `activate-window <关键字> [候选序号] [--json]`
- `activate-process <进程名> [候选序号] [--json]`
- `activate-handle <句柄> [--json]`

## Triggering Rules

命中以下意图时应触发本技能：

- “切到/回到/定位/激活”某个已打开窗口
- “切到某窗口后，再切 tab/标签页”
- “只知道进程名或句柄，要求切到对应窗口”

典型触发表达（examples）：

- 回到 VS Code / 把微信调出来 / 切到终端窗口
- 切到浏览器后切下一页签
- 把这个窗口拉到前台

## Intent -> Command

优先按意图选择命令（canonical mapping）：

- 明确窗口关键词：`scripts\d-switch.cmd activate-window <关键字> --json`
- 窗口有歧义：`scripts\d-switch.cmd find-window <关键字> 3 --json`，再 `scripts\d-switch.cmd activate-window <关键字> <序号> --json`
- 仅有进程名：`scripts\d-switch.cmd activate-process <进程名> 1 --json`
- 已知句柄：`scripts\d-switch.cmd activate-handle <句柄> --json`
- 已在目标窗口内切标签：`scripts\d-switch.cmd Dctrl -1`
- 无目标线索仅要求“切一下”：`scripts\d-switch.cmd Dalt -1`

## Command Protocol

调用约定（protocol）：

- 建议编排默认使用 `--json`（recommended），由上层按 `status` 分流。
- Windows 入口优先级：
- `scripts\d-switch.cmd ...`（primary）
- `powershell -File scripts/d-switch.ps1 ...`（secondary）
- `bash scripts/d-switch.sh ...`（Git Bash/WSL 兼容）
- macOS 当前无等价自动化脚本，仅降级为系统快捷键：窗口 `Cmd+Tab`，标签 `Ctrl+Tab` 或 `Cmd+Shift+]`。

参数默认值（defaults）：

- `find-window` 默认候选数量是 `3`
- `activate-window` / `activate-process` 默认候选序号是 `1`
- `Dalt` / `Dctrl` 的次数兼容 `N` 和 `-N`，推荐 `-N`

## Decision Flow

执行顺序（decision flow）：

1. 先判定系统。Windows 走脚本链路；非 Windows 给降级方案。
2. 判断用户目标信息：关键字 > 进程名 > 句柄 > 无目标线索。
3. 有明确目标优先 `activate-*`；有歧义先 `find-window` 再激活。
4. 只有“切一下窗口”才使用 `Dalt`，不要把 `Dalt` 当主定位手段。
5. 涉及“窗口内 tab”时，先 `activate-window`，再 `Dctrl`。

## Failure Recovery

`--json` 结果字段（JSON contract）：`mode`、`query`、`choice`、`status`、`count`、`items`。

状态处理（status handling）：

- `status=ok`：列表/查询成功，继续下一步决策。
- `status=activated`：激活成功，流程结束。
- `status=not_found`：缩短或改写关键词重试；必要时先 `list-windows --json`。
- `status=choice_out_of_range`：先重新 `find-window ... --json` 获取候选数量。
- `status=activation_failed`：优先重试 1 次；仍失败再降级 `Dalt -1`。

退出码（exit code）：

- `0`：成功（含 `list/find` 成功）
- `1`：命令或参数不合法
- `2`：未找到目标
- `3`：找到目标但激活失败
- `4`：候选序号越界

## Examples

高价值示例（high-value cases）：

- 切到微信：`scripts\d-switch.cmd activate-window 微信 --json`
- 先查浏览器候选再切：`scripts\d-switch.cmd find-window edge 3 --json` -> `scripts\d-switch.cmd activate-window edge 1 --json`
- 只知道进程名：`scripts\d-switch.cmd activate-process Code 1 --json`
- 按句柄精确激活：`scripts\d-switch.cmd activate-handle 0x2072C --json`
- 切到目标窗口后切标签：`scripts\d-switch.cmd activate-window chrome --json` -> `scripts\d-switch.cmd Dctrl -1`
- 无明确目标只切一步：`scripts\d-switch.cmd Dalt -1`

## Non-trigger Cases

以下场景不应调用技能（no invocation）：

- 用户只问快捷键知识，例如“`Alt+Tab` 是什么”
- 用户只讨论原理/概念，不要求执行切换动作

## Notes

- 本技能会真实触发系统窗口或标签切换，请按用户意图执行。
- 建议所有可编排路径优先使用 `--json`，减少歧义并支持自动重试。
- 命令真源为 `scripts/d-switch.ps1`；文档与脚本参数语义保持一致。
