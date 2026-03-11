---
name: dkey-switch
description: "当用户表达切换窗口、打开某个正在运行的窗口、切到某个应用、定位/找到/回到某个窗口、查看前台窗口，或表达切换页签/标签页时，立即调用本技能。必须先判断系统：Windows 优先使用 `scripts\\d-switch.cmd activate-window <关键字>`，也可使用 `powershell -File scripts/d-switch.ps1 activate-window <关键字>`；目标不明确时先 `find-window` 后激活；`Dalt`/`Dctrl` 仅作为回退路径。macOS 当前不执行本仓库自动化脚本，改走系统快捷键策略。"
user-invocable: true
---

## 核心目标

当用户让帮他“看到/切到/定位到”某个正在运行的窗口，或某个窗口里的页签/标签页时，直接调用本技能脚本执行切换。

## 强触发意图

- 查看某个正在运行的应用窗口
- 切到某个窗口后继续查找其中页签
- 在多个窗口或多个标签之间定位目标
- 回到某个程序窗口
- 打开前台窗口

## 触发关键词

- 窗口类：切换窗口、切到窗口、定位窗口、找到窗口、跳到窗口、回到窗口、切焦点、前台窗口、正在运行的窗口
- 终端类：打开 CMD、显示终端、查看命令行窗口、切到 terminal
- 页签类：切换页签、切换标签页、下一个标签、定位标签、切到某个 tab

## 扩展触发短语（面向 AI）

- 回到刚才那个窗口、切回编辑器、把微信调出来、把浏览器调到前台
- 切到终端窗口、回到命令行、切回 VS Code
- 把这个应用切到前面、把这个窗口激活

## 触发排除规则（防误触发）

- 仅在用户要求“执行切换动作”时触发
- 仅问快捷键知识（如“Alt+Tab 是什么”）不触发
- 仅讨论概念或对比方案，不触发

## 调用指南

当命中上述意图或同义表达时：

1. 必须调用 `dkey-switch`
2. AI 不做手动窗口操作描述，不让用户自己按快捷键，直接执行脚本命令
3. 先判断系统再选路径：
   - Windows：执行本仓库脚本
   - macOS：当前脚本不支持，使用系统快捷键降级
4. Windows 下首选命令：
   - `scripts\d-switch.cmd activate-window <关键字>`
   - `powershell -File scripts/d-switch.ps1 activate-window <关键字>`
5. Git Bash / WSL 兼容命令：
   - `bash scripts/d-switch.sh activate-window <关键字>`
6. Windows 路由优先级：
   - 已知目标窗口关键词 -> `activate-window`
   - 目标不明确或有歧义 -> `find-window` 后再 `activate-window`
   - 已知稳定进程名 -> `activate-process`
   - 已有窗口句柄 -> `activate-handle`
   - 无法命中目标且需要人工逐步切换 -> `Dalt`
   - 已在目标窗口内需要切标签 -> `Dctrl`

## AI 决策模板（Canonical）

- 目标窗口明确：`scripts\d-switch.cmd activate-window <关键字>`
- 目标窗口不明确：`scripts\d-switch.cmd find-window <关键字> 3 --json` 后 `scripts\d-switch.cmd activate-window <关键字> 1`
- 目标是稳定进程：`scripts\d-switch.cmd activate-process <进程名> 1`
- 已知句柄：`scripts\d-switch.cmd activate-handle <句柄>`
- 窗口内切页签：先 `activate-window`，再 `scripts\d-switch.cmd Dctrl -1`
- 没有任何目标线索：`scripts\d-switch.cmd Dalt -1`（仅回退）

## 系统分流

- Windows：
  - 首选 `scripts\d-switch.cmd`
  - 次选 `powershell -File scripts/d-switch.ps1`
  - bash 仅兼容，不是首选
- macOS：
  - 当前仓库脚本链路不支持
  - 窗口切换降级：`Cmd+Tab`
  - 窗口内页签降级：`Ctrl+Tab` 或 `Cmd+Shift+]`

## 决策规则

- 用户说“打开/切到/回到某个应用窗口” -> 优先 `activate-window <关键字>`
- 用户只给了进程名且较稳定 -> 可优先 `activate-process <进程名>`
- 用户说“某个窗口里的标签页/tab” -> 先 `activate-window` 定位窗口，再执行 `Dctrl`
- 用户同时提到窗口和页签 -> 先 `activate-window`，后 `Dctrl`
- 只有“切一下窗口”但无明确目标 -> 才使用 `Dalt -1` 小步切换

## 功能

- 支持 `Dalt` + 次数：模拟 `Alt+Tab` 连续切换
- 支持 `Dctrl` + 次数：模拟 `Ctrl+Tab` 连续切换
- 支持 `list-windows`
- 支持 `find-window <关键字> [候选数量]`
- 支持 `activate-window <关键字> [候选序号]`
- 支持 `activate-process <进程名> [候选序号]`
- 支持 `activate-handle <句柄>`
- 支持 `--json`

## 参数兼容约定

- `Dalt`/`Dctrl` 的次数参数兼容 `N` 与 `-N`，推荐写法为 `-N`（如 `-1`）
- `find-window` 默认候选数量为 `3`
- `activate-window` / `activate-process` 默认候选序号为 `1`

## JSON 状态契约（供上层 AI 决策）

- 常见字段：`mode`、`query`、`choice`、`status`、`count`、`items`
- `status=ok`：列表或查询成功返回
- `status=activated`：激活成功
- `status=not_found`：未找到候选
- `status=choice_out_of_range`：候选序号超范围
- `status=activation_failed`：找到候选但激活失败

## 退出码约定（供编排层处理）

- `0`：成功或可继续流程（含 list/find 成功）
- `1`：参数或命令不合法
- `2`：未找到目标
- `3`：找到目标但激活失败
- `4`：候选序号越界

## 快速开始

1. 进入技能包目录：`cd dkey-switch`
2. Windows CMD 首选：`scripts\d-switch.cmd activate-window QQ`
3. Windows PowerShell 可用：`powershell -File scripts/d-switch.ps1 activate-window QQ`
4. Git Bash / WSL 兼容：`bash scripts/d-switch.sh activate-window QQ`
5. 运行安全检查：`scripts\security-audit.cmd`

## 命令示例

- `scripts\d-switch.cmd activate-window QQ`
- `scripts\d-switch.cmd find-window 微信 3`
- `scripts\d-switch.cmd activate-process Code`
- `scripts\d-switch.cmd activate-handle 0x2072C`
- `scripts\d-switch.cmd list-windows`
- `scripts\d-switch.cmd find-window code 3 --json`
- `scripts\d-switch.cmd Dalt -1`
- `scripts\d-switch.cmd Dctrl -1`
- `scripts\security-audit.cmd`

## 技能说明

- 窗口定位默认首选：`activate-window <关键字>`
- 当用户已经知道目标窗口关键字时，直接执行 `activate-window`
- 当目标不明确或可能重名时，先执行 `find-window` 查看前 3 个候选，再执行 `activate-window`
- `Dalt` 仅用于回退，不是窗口定位首选
- `activate-window` 会优先恢复最小化窗口，再尝试把最佳匹配窗口切到最前
- `activate-process` 适合窗口标题变化大、但进程名稳定的场景
- `activate-handle` 适合上层已经拿到窗口句柄、希望精确命中目标窗口的场景
- 当需要由上层程序继续决策时，可附加 `--json` 获取结构化候选数据
- 当用户要查看某个窗口内的页签时，先用 `activate-window` 确保窗口正确，再使用 `Dctrl`
- 建议上层编排优先使用 `--json`，按 `status` 自动选择重试、换候选或降级

## 不触发场景

- 用户仅询问快捷键知识，未要求执行切换
- 用户仅做概念讨论，不要求查看/切到/定位具体窗口或页签

## 注意

- 该脚本会真实触发系统切换窗口/标签
- Windows 下优先使用 `scripts\d-switch.cmd`
- `bash scripts/d-switch.sh` 仅作为 Git Bash / WSL 兼容入口
- macOS 当前仅提供快捷键降级说明，未提供同等自动激活脚本
