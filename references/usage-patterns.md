# Usage Patterns

## Window Switching

- 命令：`bash scripts/d-switch.sh Dalt -N`
- 用途：快速在多个应用窗口间切换

## Process Window Locate (逐个定位窗口)

- 适用场景：用户需要查看某个进程/应用对应窗口，但当前不在前台。
- 推荐策略：使用 `Dalt -1` 单步切换，逐个检查当前窗口是否为目标。
- 操作方式：重复执行 `bash scripts/d-switch.sh Dalt -1`，直到找到目标窗口。
- 找到后动作：停止切换，执行下一步业务操作。

## Tab Switching

- 命令：`bash scripts/d-switch.sh Dctrl -N`
- 用途：浏览器或编辑器多标签快速切换
