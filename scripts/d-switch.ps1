$ErrorActionPreference = 'Stop'

function Show-Usage {
@"
用法:
  scripts\d-switch.cmd Dalt -1
  scripts\d-switch.cmd Dctrl -1
  scripts\d-switch.cmd list-windows [--json]
  scripts\d-switch.cmd find-window <关键字> [候选数量] [--json]
  scripts\d-switch.cmd activate-window <关键字> [候选序号] [--json]
  scripts\d-switch.cmd activate-process <进程名> [候选序号] [--json]
  scripts\d-switch.cmd activate-handle <句柄> [--json]

PowerShell:
  powershell -File scripts/d-switch.ps1 activate-window QQ
"@ | Write-Host
}

function Parse-PositiveInt([string]$raw, [string]$label) {
    if ([string]::IsNullOrWhiteSpace($raw)) { throw "$label 不能为空" }
    $parsed = $raw.TrimStart('-')
    if ($parsed -notmatch '^\d+$' -or $parsed -eq '0') { throw "$label 无效: $raw" }
    return [int]$parsed
}

# 常见应用别名/缩写映射表（小写）
$script:AppAliases = @{
    # 企业应用 - 中文 + 拼音
    '企微' = @('企业微信', 'wechatwork', 'wecom')
    '企业微' = @('企业微信', 'wechatwork', 'wecom')
    'qiwei' = @('企业微信', 'wechatwork', 'wecom')
    'qiyou' = @('企业微信', 'wechatwork', 'wecom')  # 跳跃匹配辅助
    'wx' = @('微信', 'wechat')
    'weixin' = @('微信', 'wechat')
    'vx' = @('微信', 'wechat')
    'qq' = @('qq', 'tim', '腾讯')
    '钉钉' = @('钉钉', 'dingtalk')
    'dingding' = @('钉钉', 'dingtalk')
    '飞书' = @('飞书', 'lark')
    'feishu' = @('飞书', 'lark')
    
    # 编辑器/IDE
    'code' = @('code', 'vscode', 'visual studio code')
    'vscode' = @('vscode', 'visual studio code')
    'vs' = @('visual studio', 'vscode')
    'idea' = @('idea', 'intellij')
    'pycharm' = @('pycharm')
    'vim' = @('vim', 'neovim', 'nvim')
    
    # 浏览器
    'chrome' = @('chrome', 'google chrome')
    'edge' = @('edge', 'microsoft edge')
    'ff' = @('firefox', '火狐')
    'firefox' = @('firefox', '火狐')
    
    # 终端
    'cmd' = @('cmd', 'command prompt')
    'wt' = @('windows terminal', 'terminal')
    '终端' = @('terminal', 'windows terminal', 'cmd', 'powershell', 'git bash')
    'terminal' = @('terminal', 'windows terminal')
    
    # 开发工具
    'git' = @('git', 'github', 'git bash')
    'github' = @('github', 'git')
    'docker' = @('docker', 'docker desktop')
    
    # 文件管理
    '文件' = @('explorer', '文件资源管理器', '文件夹')
    '资源管理器' = @('explorer', '文件资源管理器')
    'explorer' = @('explorer', '文件资源管理器')
    
    # 媒体
    '音乐' = @('spotify', 'music', '网易云音乐', 'qq音乐')
    '视频' = @('vlc', 'potplayer', 'media player')
}

function Normalize-Text([string]$Text) {
    if ([string]::IsNullOrWhiteSpace($Text)) { return '' }
    # 先移除连字符，使 "企业微信-文档" 和 "企业微信文档" 能互相匹配
    $text = $Text.ToLowerInvariant() -replace '-', ''
    return ([regex]::Replace($text, '[^\p{L}\p{Nd}]+', ' ')).Trim()
}

# 展开查询词的所有可能形式（原词 + 别名映射）
function Expand-QueryVariants([string]$Query) {
    $variants = New-Object System.Collections.Generic.HashSet[string]
    $normalized = Normalize-Text $Query
    [void]$variants.Add($normalized)
    [void]$variants.Add($Query.ToLowerInvariant())
    
    # 检查别名映射
    $queryLower = $Query.ToLowerInvariant()
    foreach ($alias in $script:AppAliases.Keys) {
        if ($queryLower -eq $alias -or $normalized -eq $alias) {
            foreach ($target in $script:AppAliases[$alias]) {
                [void]$variants.Add($target)
                [void]$variants.Add((Normalize-Text $target))
            }
        }
    }
    
    # 智能扩展：尝试从拼音提取可能的匹配（如 qiyeweixinwendang -> 企业微信）
    # 添加中文关键词作为潜在匹配目标
    if ($queryLower -match 'qiyou|qiwei|weixin|wechat') {
        [void]$variants.Add('企业微信')
        [void]$variants.Add('微信')
    }
    if ($queryLower -match 'wendang|wen') {
        [void]$variants.Add('文档')
    }
    if ($queryLower -match 'dingding|ding') {
        [void]$variants.Add('钉钉')
    }
    
    return @($variants)
}

# 跳跃匹配：检查查询词是否以相同顺序出现在目标文本中（支持省略字符）
function Test-FuzzyMatch([string]$Query, [string]$Target) {
    if ([string]::IsNullOrWhiteSpace($Query) -or [string]::IsNullOrWhiteSpace($Target)) { return $false }
    
    $q = $Query.ToLowerInvariant()
    $t = $Target.ToLowerInvariant()
    
    $qIndex = 0
    $tIndex = 0
    
    while ($qIndex -lt $q.Length -and $tIndex -lt $t.Length) {
        if ($q[$qIndex] -eq $t[$tIndex]) {
            $qIndex++
        }
        $tIndex++
    }
    
    return $qIndex -eq $q.Length
}

# 计算跳跃匹配分数
function Get-FuzzyMatchScore([string]$Query, [string]$Target) {
    if ([string]::IsNullOrWhiteSpace($Query) -or [string]::IsNullOrWhiteSpace($Target)) { return 0 }
    
    $q = $Query.ToLowerInvariant()
    $t = $Target.ToLowerInvariant()
    
    $qIndex = 0
    $tIndex = 0
    $consecutiveMatches = 0
    $totalMatches = 0
    $lastMatchIndex = -1
    
    while ($qIndex -lt $q.Length -and $tIndex -lt $t.Length) {
        if ($q[$qIndex] -eq $t[$tIndex]) {
            $totalMatches++
            if ($lastMatchIndex -ge 0 -and $tIndex -eq $lastMatchIndex + 1) {
                $consecutiveMatches++
            }
            $lastMatchIndex = $tIndex
            $qIndex++
        }
        $tIndex++
    }
    
    if ($qIndex -lt $q.Length) { return 0 }  # 未完全匹配
    
    # 分数计算：基础分 + 连续匹配奖励 + 完整度奖励
    $score = 30 * $totalMatches + 20 * $consecutiveMatches
    # 如果完全匹配整个词，额外加分
    if ($t.Contains($q)) { $score += 50 }
    # 如果是开头匹配，额外加分
    if ($t.StartsWith($q)) { $score += 30 }
    
    return $score
}

function Get-MatchScore {
    param(
        [pscustomobject]$Window,
        [string]$Query,
        [string]$MatchMode = 'mixed'
    )

    $normalizedQuery = Normalize-Text $Query
    if ([string]::IsNullOrWhiteSpace($normalizedQuery)) { return 0 }

    $title = Normalize-Text $Window.Title
    $process = Normalize-Text $Window.ProcessName
    $rawTitle = $Window.Title
    $rawProcess = $Window.ProcessName
    $score = 0
    
    # 获取查询词的所有变体形式
    $queryVariants = Expand-QueryVariants $Query

    if ($MatchMode -eq 'process') {
        # 优先检查别名完全匹配
        foreach ($variant in $queryVariants) {
            if ($process -eq $variant) { $score += 250; break }
            if ($process.StartsWith($variant)) { $score += 180; break }
        }
        
        if ($process.Contains($normalizedQuery)) { $score += 120 }

        foreach ($token in ($normalizedQuery -split '\s+' | Where-Object { $_ })) {
            if ($process -match "(^| )$([regex]::Escape($token))( |$)") { $score += 20 }
            elseif ($process.Contains($token)) { $score += 10 }
        }

        if ($Window.IsForeground) { $score -= 5 }
        return $score
    }

    # === 标题匹配（优先级高于进程）===
    # 1. 完全匹配（包括别名展开后的完全匹配）
    foreach ($variant in $queryVariants) {
        if ($title -eq $variant) { $score += 160; break }
    }
    if ($title -eq $normalizedQuery) { $score += 150 }
    
    # 2. 开头匹配
    foreach ($variant in $queryVariants) {
        if ($title.StartsWith($variant)) { $score += 110; break }
    }
    if ($title.StartsWith($normalizedQuery)) { $score += 100 }
    
    # 3. 包含匹配
    foreach ($variant in $queryVariants) {
        if ($title.Contains($variant) -and $variant.Length -gt 2) { $score += 90; break }
    }
    if ($title.Contains($normalizedQuery)) { $score += 80 }
    
    # 4. 跳跃模糊匹配（如"企微"→"企业微信"）
    $fuzzyScore = Get-FuzzyMatchScore $Query $rawTitle
    if ($fuzzyScore -gt 0) { $score += $fuzzyScore }
    
    # === 进程匹配 ===
    foreach ($variant in $queryVariants) {
        if ($process -eq $variant) { $score += 140; break }
        if ($process.StartsWith($variant)) { $score += 100; break }
    }
    if ($process -eq $normalizedQuery) { $score += 130 }
    if ($process.StartsWith($normalizedQuery)) { $score += 90 }
    if ($process.Contains($normalizedQuery)) { $score += 70 }
    
    # 进程名模糊匹配
    $processFuzzyScore = Get-FuzzyMatchScore $Query $rawProcess
    if ($processFuzzyScore -gt 0) { $score += $processFuzzyScore * 0.8 }

    # 词级别匹配
    foreach ($token in ($normalizedQuery -split '\s+' | Where-Object { $_ })) {
        if ($title -match "(^| )$([regex]::Escape($token))( |$)") { $score += 14 }
        elseif ($title.Contains($token)) { $score += 8 }

        if ($process -match "(^| )$([regex]::Escape($token))( |$)") { $score += 12 }
        elseif ($process.Contains($token)) { $score += 6 }
    }

    if ($Window.IsForeground) { $score -= 5 }
    return $score
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;

public static class DSwitchWin32
{
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern IntPtr GetShellWindow();

    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool IsWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool IsIconic(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern int GetWindowTextLength(IntPtr hWnd);

    [DllImport("user32.dll", CharSet=CharSet.Unicode)]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

    [DllImport("user32.dll")]
    public static extern int GetWindowLong(IntPtr hWnd, int nIndex);

    [DllImport("user32.dll")]
    public static extern IntPtr GetWindow(IntPtr hWnd, uint uCmd);

    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    public static extern int GetWindowThreadProcessId(IntPtr hWnd, out int lpdwProcessId);

    [DllImport("user32.dll")]
    public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool BringWindowToTop(IntPtr hWnd);

    public const int GWL_EXSTYLE = -20;
    public const int WS_EX_TOOLWINDOW = 0x00000080;
    public const uint GW_OWNER = 4;
    public const int SW_RESTORE = 9;
}
"@

function Get-CandidateWindows {
    $shellWindow = [DSwitchWin32]::GetShellWindow()
    $foregroundWindow = [DSwitchWin32]::GetForegroundWindow()
    $script:WindowItems = New-Object System.Collections.ArrayList
    $script:WindowIndex = 0

    $callback = [DSwitchWin32+EnumWindowsProc]{
        param([IntPtr]$hWnd,[IntPtr]$lParam)

        if ($hWnd -eq $shellWindow) { return $true }
        if (-not [DSwitchWin32]::IsWindow($hWnd)) { return $true }

        $isVisible = [DSwitchWin32]::IsWindowVisible($hWnd)
        $isMinimized = [DSwitchWin32]::IsIconic($hWnd)
        if (-not $isVisible -and -not $isMinimized) { return $true }

        $owner = [DSwitchWin32]::GetWindow($hWnd, [DSwitchWin32]::GW_OWNER)
        if ($owner -ne [IntPtr]::Zero) { return $true }

        $exStyle = [DSwitchWin32]::GetWindowLong($hWnd, [DSwitchWin32]::GWL_EXSTYLE)
        if (($exStyle -band [DSwitchWin32]::WS_EX_TOOLWINDOW) -ne 0) { return $true }

        $length = [DSwitchWin32]::GetWindowTextLength($hWnd)
        if ($length -le 0) { return $true }

        $builder = New-Object System.Text.StringBuilder ($length + 1)
        [void][DSwitchWin32]::GetWindowText($hWnd, $builder, $builder.Capacity)
        $title = $builder.ToString().Trim()
        if ([string]::IsNullOrWhiteSpace($title)) { return $true }

        $processId = 0
        [void][DSwitchWin32]::GetWindowThreadProcessId($hWnd, [ref]$processId)

        try {
            $processName = (Get-Process -Id $processId -ErrorAction Stop).ProcessName
        } catch {
            $processName = 'unknown'
        }

        [void]$script:WindowItems.Add([pscustomobject]@{
            Index = $script:WindowIndex
            Title = $title
            ProcessName = $processName
            ProcessId = $processId
            Handle = $hWnd
            HandleHex = ('0x{0:X}' -f $hWnd.ToInt64())
            IsMinimized = $isMinimized
            IsForeground = ($hWnd -eq $foregroundWindow)
            State = if ($isMinimized) { 'Minimized' } elseif ($hWnd -eq $foregroundWindow) { 'Foreground' } else { 'Visible' }
            ApproxAltTabSteps = $script:WindowIndex + 1
        })

        $script:WindowIndex++
        return $true
    }

    [void][DSwitchWin32]::EnumWindows($callback, [IntPtr]::Zero)
    return $script:WindowItems.ToArray()
}

function Build-MatchList {
    param(
        [object[]]$SourceWindows,
        [string]$Query,
        [int]$Limit,
        [string]$MatchMode = 'mixed',
        [int]$MinScore = 50
    )

    $result = foreach ($w in $SourceWindows) {
        $score = Get-MatchScore -Window $w -Query $Query -MatchMode $MatchMode
        # 使用最小分数阈值过滤低质量匹配（避免误匹配）
        if ($score -ge $MinScore) {
            [pscustomobject]@{
                Index = $w.Index
                Title = $w.Title
                ProcessName = $w.ProcessName
                ProcessId = $w.ProcessId
                Handle = $w.Handle
                HandleHex = $w.HandleHex
                IsMinimized = $w.IsMinimized
                IsForeground = $w.IsForeground
                State = $w.State
                ApproxAltTabSteps = $w.ApproxAltTabSteps
                Score = $score
            }
        }
    }

    return @(
        $result |
        Sort-Object -Property @{Expression='Score';Descending=$true}, @{Expression='Index';Descending=$false} |
        Select-Object -First $Limit
    )
}

function Convert-WindowResult {
    param(
        [object[]]$Windows,
        [string]$Mode,
        [string]$Query = '',
        [int]$Choice = 1,
        [string]$Status = 'ok'
    )

    $rank = 0
    $items = @()
    foreach ($w in $Windows) {
        $rank++
        $items += [pscustomobject]@{
            rank = $rank
            index = $w.Index + 1
            title = $w.Title
            processName = $w.ProcessName
            processId = $w.ProcessId
            state = $w.State
            isMinimized = $w.IsMinimized
            isForeground = $w.IsForeground
            handle = $w.HandleHex
            approxAltTabSteps = $w.ApproxAltTabSteps
            score = if ($null -ne $w.PSObject.Properties['Score']) { $w.Score } else { $null }
        }
    }

    [pscustomobject]@{
        mode = $Mode
        query = $Query
        choice = $Choice
        status = $Status
        count = $items.Count
        items = $items
    }
}

function Activate-Window {
    param([pscustomobject]$Window)

    if ($Window.IsMinimized) {
        [void][DSwitchWin32]::ShowWindowAsync($Window.Handle, [DSwitchWin32]::SW_RESTORE)
        Start-Sleep -Milliseconds 150
    }

    [void][DSwitchWin32]::BringWindowToTop($Window.Handle)
    Start-Sleep -Milliseconds 50
    $activated = [DSwitchWin32]::SetForegroundWindow($Window.Handle)
    Start-Sleep -Milliseconds 150
    $isForeground = ([DSwitchWin32]::GetForegroundWindow() -eq $Window.Handle)

    [pscustomobject]@{
        Activated = ($activated -or $isForeground)
        IsForeground = $isForeground
    }
}

function Show-Matches {
    param(
        [string]$Query,
        [object[]]$Matches,
        [switch]$ForActivation
    )

    if ($Matches.Count -eq 0) {
        Write-Host "No windows matched `"$Query`"."
        return
    }

    if ($ForActivation) {
        Write-Host "Query: $Query. Top candidates found below; the first one will be activated."
    } else {
        Write-Host "Query: $Query. Top ranked candidates:"
    }

    $i = 1
    foreach ($m in $Matches) {
        Write-Host ('#{0} score={1} state={2} approxDalt={3} title="{4}" process="{5}" handle={6}' -f $i,$m.Score,$m.State,$m.ApproxAltTabSteps,$m.Title,$m.ProcessName,$m.HandleHex)
        $i++
    }
}

function Show-WindowList {
    param([object[]]$Windows)

    if ($Windows.Count -eq 0) {
        Write-Host 'No switchable windows were found.'
        return
    }

    Write-Host ("Discovered {0} candidate windows:" -f $Windows.Count)
    foreach ($w in $Windows) {
        Write-Host ('[{0,2}] [{1,-10}] {2} <{3}> handle={4}' -f ($w.Index + 1),$w.State,$w.Title,$w.ProcessName,$w.HandleHex)
    }
}

$Command = if ($args.Count -ge 1) { [string]$args[0] } else { '' }
$Arg1    = if ($args.Count -ge 2) { [string]$args[1] } else { $null }
$Arg2    = if ($args.Count -ge 3) { [string]$args[2] } else { $null }
$Arg3    = if ($args.Count -ge 4) { [string]$args[3] } else { $null }

if ([string]::IsNullOrWhiteSpace($Command) -or $Command -in @('help','-h','--help')) {
    Show-Usage
    exit 0
}

if ($Command -in @('Dalt','Dctrl')) {
    $times = Parse-PositiveInt $Arg1 '次数参数'
    $modifier = if ($Command -eq 'Dalt') { 'alt' } else { 'control' }
    Write-Host "执行: $modifier + tab, 重复 $times 次..."
    for ($i = 0; $i -lt $times; $i++) {
        if ($modifier -eq 'alt') {
            [System.Windows.Forms.SendKeys]::SendWait('%{TAB}')
        } else {
            [System.Windows.Forms.SendKeys]::SendWait('^{TAB}')
        }
        Start-Sleep -Milliseconds 100
    }
    exit 0
}

$outputFormat = 'text'
if ($Arg1 -eq '--json' -or $Arg2 -eq '--json' -or $Arg3 -eq '--json') { $outputFormat = 'json' }

$windows = @(Get-CandidateWindows)

switch ($Command) {
    'list-windows' {
        if ($outputFormat -eq 'json') {
            Convert-WindowResult -Windows $windows -Mode 'list' | ConvertTo-Json -Depth 5
        } else {
            Show-WindowList -Windows $windows
        }
        exit 0
    }

    'find-window' {
        if ([string]::IsNullOrWhiteSpace($Arg1)) { throw '请提供窗口关键字。' }
        $limit = 3
        if ($Arg2 -and $Arg2 -ne '--json') { $limit = Parse-PositiveInt $Arg2 '候选数量' }
        $matches = @(Build-MatchList -SourceWindows $windows -Query $Arg1 -Limit $limit -MatchMode 'mixed')
        if ($outputFormat -eq 'json') {
            Convert-WindowResult -Windows $matches -Mode 'find' -Query $Arg1 | ConvertTo-Json -Depth 5
        } else {
            Show-Matches -Query $Arg1 -Matches $matches
        }
        exit 0
    }

    'activate-window' {
        if ([string]::IsNullOrWhiteSpace($Arg1)) { throw '请提供窗口关键字。' }
        $choice = 1
        if ($Arg2 -and $Arg2 -ne '--json') { $choice = Parse-PositiveInt $Arg2 '候选序号' }
        $matches = @(Build-MatchList -SourceWindows $windows -Query $Arg1 -Limit ([Math]::Max($choice, 3)) -MatchMode 'mixed')

        if ($matches.Count -eq 0) {
            if ($outputFormat -eq 'json') {
                Convert-WindowResult -Windows $matches -Mode 'activate' -Query $Arg1 -Choice $choice -Status 'not_found' | ConvertTo-Json -Depth 5
            } else {
                Show-Matches -Query $Arg1 -Matches $matches -ForActivation
            }
            exit 2
        }

        if ($choice -gt $matches.Count) {
            if ($outputFormat -eq 'json') {
                Convert-WindowResult -Windows $matches -Mode 'activate' -Query $Arg1 -Choice $choice -Status 'choice_out_of_range' | ConvertTo-Json -Depth 5
            } else {
                Write-Host "Choice $choice is out of range. Only $($matches.Count) candidate(s) are available."
            }
            exit 4
        }

        if ($outputFormat -ne 'json') {
            Show-Matches -Query $Arg1 -Matches $matches -ForActivation
        }

        $target = $matches[$choice - 1]
        $res = Activate-Window -Window $target
        if ($res.IsForeground) {
            if ($outputFormat -eq 'json') {
                Convert-WindowResult -Windows $matches -Mode 'activate' -Query $Arg1 -Choice $choice -Status 'activated' | ConvertTo-Json -Depth 5
            } else {
                Write-Host ('Activated candidate #{0}: "{1}" <{2}>' -f $choice,$target.Title,$target.ProcessName)
            }
            exit 0
        } else {
            if ($outputFormat -eq 'json') {
                Convert-WindowResult -Windows $matches -Mode 'activate' -Query $Arg1 -Choice $choice -Status 'activation_failed' | ConvertTo-Json -Depth 5
            } else {
                Write-Host ('Activation failed for candidate #{0}: "{1}" <{2}>.' -f $choice,$target.Title,$target.ProcessName)
            }
            exit 3
        }
    }

    'activate-process' {
        if ([string]::IsNullOrWhiteSpace($Arg1)) { throw '请提供进程名。' }
        $choice = 1
        if ($Arg2 -and $Arg2 -ne '--json') { $choice = Parse-PositiveInt $Arg2 '候选序号' }
        $matches = @(Build-MatchList -SourceWindows $windows -Query $Arg1 -Limit ([Math]::Max($choice, 3)) -MatchMode 'process')

        if ($matches.Count -eq 0) {
            if ($outputFormat -eq 'json') {
                Convert-WindowResult -Windows $matches -Mode 'activate-process' -Query $Arg1 -Choice $choice -Status 'not_found' | ConvertTo-Json -Depth 5
            } else {
                Show-Matches -Query $Arg1 -Matches $matches -ForActivation
            }
            exit 2
        }

        if ($choice -gt $matches.Count) {
            if ($outputFormat -eq 'json') {
                Convert-WindowResult -Windows $matches -Mode 'activate-process' -Query $Arg1 -Choice $choice -Status 'choice_out_of_range' | ConvertTo-Json -Depth 5
            } else {
                Write-Host "Choice $choice is out of range. Only $($matches.Count) candidate(s) are available."
            }
            exit 4
        }

        if ($outputFormat -ne 'json') {
            Show-Matches -Query $Arg1 -Matches $matches -ForActivation
        }

        $target = $matches[$choice - 1]
        $res = Activate-Window -Window $target
        if ($res.IsForeground) {
            if ($outputFormat -eq 'json') {
                Convert-WindowResult -Windows $matches -Mode 'activate-process' -Query $Arg1 -Choice $choice -Status 'activated' | ConvertTo-Json -Depth 5
            } else {
                Write-Host ('Activated process candidate #{0}: "{1}" <{2}>' -f $choice,$target.Title,$target.ProcessName)
            }
            exit 0
        } else {
            if ($outputFormat -eq 'json') {
                Convert-WindowResult -Windows $matches -Mode 'activate-process' -Query $Arg1 -Choice $choice -Status 'activation_failed' | ConvertTo-Json -Depth 5
            } else {
                Write-Host ('Activation failed for process candidate #{0}: "{1}" <{2}>.' -f $choice,$target.Title,$target.ProcessName)
            }
            exit 3
        }
    }

    'activate-handle' {
        if ([string]::IsNullOrWhiteSpace($Arg1)) { throw '请提供窗口句柄。' }
        $normalized = $Arg1.Trim().ToLowerInvariant()
        if (-not $normalized.StartsWith('0x')) { $normalized = '0x' + $normalized }

        $target = $windows | Where-Object { $_.HandleHex.ToLowerInvariant() -eq $normalized } | Select-Object -First 1
        if (-not $target) {
            if ($outputFormat -eq 'json') {
                Convert-WindowResult -Windows @() -Mode 'activate-handle' -Query $Arg1 -Status 'not_found' | ConvertTo-Json -Depth 5
            } else {
                Write-Host "No window found for handle $Arg1."
            }
            exit 2
        }

        $res = Activate-Window -Window $target
        if ($res.IsForeground) {
            if ($outputFormat -eq 'json') {
                Convert-WindowResult -Windows @($target) -Mode 'activate-handle' -Query $Arg1 -Status 'activated' | ConvertTo-Json -Depth 5
            } else {
                Write-Host ('Activated handle {0}: "{1}" <{2}>' -f $target.HandleHex,$target.Title,$target.ProcessName)
            }
            exit 0
        } else {
            if ($outputFormat -eq 'json') {
                Convert-WindowResult -Windows @($target) -Mode 'activate-handle' -Query $Arg1 -Status 'activation_failed' | ConvertTo-Json -Depth 5
            } else {
                Write-Host ('Activation failed for handle {0}: "{1}" <{2}>.' -f $target.HandleHex,$target.Title,$target.ProcessName)
            }
            exit 3
        }
    }

    default {
        Show-Usage
        exit 1
    }
}

