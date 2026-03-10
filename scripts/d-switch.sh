#!/usr/bin/env bash

# 获取命令行参数
# $1 是指令(如 Dalt)，$2 是参数(如 -2)
command="$1"
countArg="$2"

if [[ -z "$command" || -z "$countArg" ]]; then
    echo "用法: bash scripts/d-switch.sh <Dalt|Dctrl> <-次数>"
    exit 1
fi

# 解析次数 (去掉前导 '-' 并转为数字)
times="${countArg#-}"

if ! [[ "$times" =~ ^[0-9]+$ ]]; then
    echo "次数参数无效: $countArg"
    exit 1
fi

# 确定修饰键
if [[ "$command" == "Dalt" ]]; then
    modifier="alt"
else
    modifier="control"
fi

echo "执行: ${modifier} + tab, 重复 ${times} 次..."

# 执行逻辑（Windows 下通过 PowerShell SendKeys 模拟）
powershell -NoProfile -ExecutionPolicy Bypass -Command "
Add-Type -AssemblyName System.Windows.Forms

\$times = [int]'$times'
\$modifier = '$modifier'

for (\$i = 0; \$i -lt \$times; \$i++) {
    if (\$modifier -eq 'alt') {
        [System.Windows.Forms.SendKeys]::SendWait('%{TAB}')
    } else {
        [System.Windows.Forms.SendKeys]::SendWait('^{TAB}')
    }
    Start-Sleep -Milliseconds 100
}
"
