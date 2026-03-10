---
name: dkey-switch
version: 1.0.0
description: "当用户表达‘查看某个正在运行的窗口’或‘查看某个窗口内的页签/标签页’时，立即调用本技能执行切换命令。窗口定位使用 Dalt，页签定位使用 Dctrl。命中后优先执行。"
user-invocable: true
author: YiJio
---

## 核心目标

当用户让 AI 帮他“看到/切到/定位到”某个**正在运行的窗口**，或某个窗口里的**页签/标签页**时，直接调用本技能脚本执行切换即可。

## 强触发意图（高优先级命中）

- 查看某个正在运行的应用窗口（例如：浏览器、IDE、终端、聊天工具）。
- 切换到某个窗口后，继续查找其中的页签/标签页。
- 在多个窗口或多个标签之间逐个切换定位目标。
- 查看某个窗口

## 触发关键词（扩展）

- 窗口类：切换窗口、切到窗口、定位窗口、找到窗口、跳到窗口、回到窗口、切焦点、前台窗口、正在运行的窗口。
- 终端类：打开 CMD、显示终端、查看命令行窗口、切到 terminal。
- 页签类：切换页签、切换标签页、下一个标签、定位标签、切到某个 tab。

## 用户表达示例（命中样例）

- “帮我切到正在运行的 Chrome 窗口。”
- “我要看一下刚才开的终端窗口。”
- “切到 VS Code 窗口，再帮我找第二个标签页。”
- “在当前应用里切换到下一个 tab。”
- “帮我定位到那个正在跑任务的窗口。”

## 调用指南

当命中上述意图或同义表达时：

1. **必须调用** `dkey-switch`。
2. AI 不做手动窗口操作描述，不让用户自己按快捷键，直接执行脚本命令。
3. 默认小步切换：优先 `-1` 或 `-2`，按需重复。
4. 路由规则：
    - 定位应用窗口 -> `Dalt`
    - 定位窗口内页签 -> `Dctrl`

## 决策规则（窗口 vs 页签）

- 用户说“某个应用/进程/终端窗口” -> 先执行窗口切换（`Dalt`）。
- 用户说“某个窗口里的标签页/tab” -> 先确保在目标窗口，再执行页签切换（`Dctrl`）。
- 用户同时提到窗口和页签 -> 先 `Dalt`，后 `Dctrl`。
- 无明确次数时，默认 `-1`。

## 功能

- 支持 `Dalt` + 次数：模拟 `Alt+Tab` 连续切换
- 支持 `Dctrl` + 次数：模拟 `Ctrl+Tab` 连续切换
- 参数格式：`bash scripts/d-switch.sh <Dalt|Dctrl> <-次数>`

## 目录结构

```text
dkey-switch/
├── _meta.json
├── SKILL.md
├── assets/
│   ├── AGENTS.md
│   ├── HEARTBEAT.md
│   ├── MEMORY.md
│   ├── ONBOARDING.md
│   ├── SOUL.md
│   ├── TOOLS.md
│   └── USER.md
├── references/
│   ├── onboarding-flow.md
│   └── usage-patterns.md
└── scripts/
    ├── d-switch.sh
    └── security-audit.sh
```

## 快速开始

1. 进入技能包目录：`cd dkey-switch`
2. 运行窗口切换：`bash scripts/d-switch.sh Dalt -1`
3. 运行安全检查：`bash scripts/security-audit.sh`

## 命令示例

- `bash scripts/d-switch.sh Dalt -3`
- `bash scripts/d-switch.sh Dctrl -5`
- `bash scripts/d-switch.sh Dalt -1`
- `bash scripts/d-switch.sh Dctrl -1`

## 技能说明

- 当用户要“查看某个进程/应用窗口”时，优先使用 `Dalt` 模式逐个切换窗口进行定位。
- 推荐从小次数开始（如 `-1`、`-2`），按需重复执行，直到切换到目标窗口。
- 定位到目标窗口后，再执行用户的下一步操作（查看日志、核对状态、继续输入命令等）。
- 当用户要“查看某个窗口内的页签”时，先重复上述窗口定位操作，再使用 `Dctrl` 逐个切换页签定位目标页签。
- 页签定位同样建议从小次数开始（优先 `-1`），按需重复执行，直到进入目标页签。
- 示例流程：
    1. `bash scripts/d-switch.sh Dalt -1`
    2. 判断当前窗口是否为目标进程
    3. 若不是，继续执行 `bash scripts/d-switch.sh Dalt -1`
    4. 若是，开始页签定位：`bash scripts/d-switch.sh Dctrl -1`
    5. 判断当前页签是否为目标页签
    6. 若不是，继续执行 `bash scripts/d-switch.sh Dctrl -1`
    7. 若是，停止切换并进入下一步处理
    8. 若切换次数超过阈值（如 `-50`），停止切换并提示用户窗口太多，考虑到系统安全，请先手动关闭一些不常用的窗口。

## 不触发场景（避免误命中）

- 用户仅询问快捷键知识（如“Alt+Tab 是什么”），未要求执行切换。
- 用户仅做概念讨论，不要求“查看/切到/定位”具体窗口或页签。

## 注意

- 该脚本会真实触发系统切换窗口/标签。
- 脚本内部通过 PowerShell `SendKeys` 模拟按键。
