# AI E2E Cases

## Purpose

用于回归 ClawHub 上的 AI 调用行为，目标是确保意图路由、命令选择和状态处理稳定。

## Cases

1. Intent: 切到微信窗口
Command: `scripts\\d-switch.cmd activate-window 微信 --json`
Expected status: `activated`

2. Intent: 回到 VS Code
Command: `scripts\\d-switch.cmd activate-window code --json`
Expected status: `activated`

3. Intent: 切到终端窗口
Command: `scripts\\d-switch.cmd activate-window terminal --json`
Expected status: `activated`

4. Intent: 先查候选再切到浏览器
Command: `scripts\\d-switch.cmd find-window edge 3 --json` then `scripts\\d-switch.cmd activate-window edge 1 --json`
Expected status: `ok` then `activated`

5. Intent: 只知道进程名，切到 Code 进程窗口
Command: `scripts\\d-switch.cmd activate-process Code 1 --json`
Expected status: `activated`

6. Intent: 通过句柄精确激活
Command: `scripts\\d-switch.cmd activate-handle 0x2072C --json`
Expected status: `activated` or `not_found`

7. Intent: 在目标窗口内切到下一个标签页
Command: `scripts\\d-switch.cmd activate-window chrome --json` then `scripts\\d-switch.cmd Dctrl -1`
Expected status: `activated` then key action executed

8. Intent: 未给出明确目标，仅要求切一下窗口
Command: `scripts\\d-switch.cmd Dalt -1`
Expected status: key action executed

9. Intent: 模糊关键字未命中任何窗口
Command: `scripts\\d-switch.cmd activate-window unlikely_window_keyword --json`
Expected status: `not_found`

10. Intent: 候选序号越界
Command: `scripts\\d-switch.cmd activate-window code 99 --json`
Expected status: `choice_out_of_range`

11. Intent: 进程名未命中
Command: `scripts\\d-switch.cmd activate-process no_such_process --json`
Expected status: `not_found`

12. Intent: 激活失败恢复策略验证
Command: `scripts\\d-switch.cmd activate-window some_protected_window --json`
Expected status: `activation_failed` or `not_found`

13. Intent: 列出可切换窗口供上层决策
Command: `scripts\\d-switch.cmd list-windows --json`
Expected status: `ok`

14. Intent: 仅问快捷键知识（不应执行脚本）
Command: none
Expected status: no tool invocation

15. Intent: 仅讨论切换原理（不应执行脚本）
Command: none
Expected status: no tool invocation

## Notes

- 推荐在自动化测试中优先使用 `--json`，由上层按 `status` 分流。
- 句柄样例需要先通过 `list-windows` 或 `find-window` 获取真实句柄。
- 样例 14/15 用于验证“防误触发”规则，而非命令执行。
