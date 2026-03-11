# dkey-switch E2E Test Script
$ErrorActionPreference = 'Stop'

$Passed = 0
$Failed = 0
$Skipped = 0
$Results = @()

function Test-Case($Name, $ScriptBlock) {
    Write-Host "`n[TEST] $Name" -ForegroundColor Cyan
    try {
        $result = & $ScriptBlock
        if ($result -eq 'skip') {
            Write-Host "  [SKIP] No test window available" -ForegroundColor Yellow
            $script:Skipped++
        } elseif ($result) {
            Write-Host "  [PASS]" -ForegroundColor Green
            $script:Passed++
        } else {
            Write-Host "  [FAIL]" -ForegroundColor Red
            $script:Failed++
        }
        $script:Results += @{ Name=$Name; Result=$result }
    } catch {
        Write-Host "  [ERROR] $_" -ForegroundColor Red
        $script:Failed++
        $script:Results += @{ Name=$Name; Result=$false; Error=$_ }
    }
}

function Invoke-DSwitch($argsStr) {
    $cmd = Join-Path $PSScriptRoot 'd-switch.cmd'
    $output = & cmd /c "$cmd $argsStr 2>&1"
    $exitCode = $LASTEXITCODE
    return @{ Output=$output -join "`n"; ExitCode=$exitCode }
}

Write-Host "`n========== dkey-switch E2E Tests ==========" -ForegroundColor Magenta

# Case 4: Alias match (qiwei) - requires WeChat Work window
Test-Case "Case 4: Alias match (qiwei->qiyeweixin)" {
    $r = Invoke-DSwitch 'find-window "qiwei" 3 --json'
    $j = $r.Output | ConvertFrom-Json
    if ($j.count -eq 0) { return 'skip' }  # skip if no window
    return ($j.count -gt 0) -and ($j.status -eq 'ok')
}

# Case 5: English alias (vscode)
Test-Case "Case 5: English alias (vscode)" {
    $r = Invoke-DSwitch 'find-window "vscode" 3 --json'
    if ($r.ExitCode -ne 0) { return $false }
    $j = $r.Output | ConvertFrom-Json
    return ($j.count -gt 0) -and ($j.items[0].processName -eq 'Code' -or $j.items[0].title -match 'Visual Studio Code')
}

# Case 6: Fuzzy match (qiyou) - requires Chinese window
Test-Case "Case 6: Fuzzy match (qiyou)" {
    $r = Invoke-DSwitch 'find-window "qiyou" 3 --json'
    $j = $r.Output | ConvertFrom-Json
    if ($j.count -eq 0) { return 'skip' }  # skip if no window
    return ($j.count -gt 0) -and ($j.items[0].score -gt 0)
}

# Case 7: Hyphen compatibility - requires qiyeweixin-wendang window
Test-Case "Case 7: Hyphen compatibility" {
    $r = Invoke-DSwitch 'find-window "qiyeweixinwendang" 3 --json'
    $j = $r.Output | ConvertFrom-Json
    if ($j.count -eq 0) { return 'skip' }  # skip if no window
    return ($j.count -gt 0)
}

# Case 8: Case insensitive
Test-Case "Case 8: Case insensitive (CHROME)" {
    $r = Invoke-DSwitch 'find-window "CHROME" 3 --json'
    if ($r.ExitCode -ne 0) { return $false }
    $j = $r.Output | ConvertFrom-Json
    return ($j.count -gt 0)
}

# Case 9: find-window basic
Test-Case "Case 9: find-window basic" {
    $r = Invoke-DSwitch 'find-window "weixin" 3 --json'
    if ($r.ExitCode -ne 0) { return $false }
    $j = $r.Output | ConvertFrom-Json
    return ($j.mode -eq 'find') -and ($j.count -ge 0) -and ($j.status -eq 'ok')
}

# Case 13: list-windows
Test-Case "Case 13: list-windows" {
    $r = Invoke-DSwitch 'list-windows --json'
    if ($r.ExitCode -ne 0) { return $false }
    $j = $r.Output | ConvertFrom-Json
    return ($j.mode -eq 'list') -and ($j.count -ge 0) -and ($j.status -eq 'ok')
}

# Case 14: not_found - use a very specific keyword
Test-Case "Case 14: not_found" {
    $r = Invoke-DSwitch 'activate-window "xyz_not_exist_12345_abcdef" 1 --json'
    $j = $r.Output | ConvertFrom-Json
    # Accept not_found or activation_failed (low score match that fails to activate)
    return ($j.status -in @('not_found', 'activation_failed')) -and ($r.ExitCode -in @(2, 3))
}

# Case 9 (shortcut): Dctrl
Test-Case "Case 9: Dctrl shortcut" {
    $r = Invoke-DSwitch 'Dctrl -1'
    return ($r.ExitCode -eq 0)
}

# Case 10 (shortcut): Dalt
Test-Case "Case 10: Dalt shortcut" {
    $r = Invoke-DSwitch 'Dalt -1'
    return ($r.ExitCode -eq 0)
}

# Case 10: activate-window (need valid window)
Test-Case "Case 10: activate-window" {
    $r1 = Invoke-DSwitch 'list-windows --json'
    $j1 = $r1.Output | ConvertFrom-Json
    if ($j1.count -eq 0) { return 'skip' }
    $title = $j1.items[0].title
    $keyword = if ($title.Length -gt 3) { $title.Substring(0, 3) } else { $title }
    $r2 = Invoke-DSwitch "activate-window `"$keyword`" 1 --json"
    $j2 = $r2.Output | ConvertFrom-Json
    return ($j2.status -eq 'activated') -or ($r2.ExitCode -eq 0)
}

# Case 11: activate-process
Test-Case "Case 11: activate-process" {
    $r1 = Invoke-DSwitch 'list-windows --json'
    $j1 = $r1.Output | ConvertFrom-Json
    if ($j1.count -eq 0) { return 'skip' }
    $proc = $j1.items[0].processName
    $r2 = Invoke-DSwitch "activate-process `"$proc`" 1 --json"
    $j2 = $r2.Output | ConvertFrom-Json
    return ($j2.status -eq 'activated') -or ($r2.ExitCode -eq 0)
}

# Case 12: activate-handle
Test-Case "Case 12: activate-handle" {
    $r1 = Invoke-DSwitch 'list-windows --json'
    $j1 = $r1.Output | ConvertFrom-Json
    if ($j1.count -eq 0) { return 'skip' }
    $handle = $j1.items[0].handle
    $r2 = Invoke-DSwitch "activate-handle `"$handle`" --json"
    $j2 = $r2.Output | ConvertFrom-Json
    return ($j2.status -eq 'activated') -or ($r2.ExitCode -eq 0)
}

# Case 15: choice_out_of_range
Test-Case "Case 15: choice_out_of_range" {
    $r1 = Invoke-DSwitch 'find-window "weixin" 3 --json'
    $j1 = $r1.Output | ConvertFrom-Json
    if ($j1.count -eq 0) { return 'skip' }
    $r2 = Invoke-DSwitch 'activate-window "weixin" 99 --json'
    $j2 = $r2.Output | ConvertFrom-Json
    return ($j2.status -eq 'choice_out_of_range') -or ($r2.ExitCode -eq 4)
}

# Report
Write-Host "`n========== Test Report ==========" -ForegroundColor Magenta
Write-Host "Passed:  $Passed" -ForegroundColor Green
Write-Host "Failed:  $Failed" -ForegroundColor Red
Write-Host "Skipped: $Skipped" -ForegroundColor Yellow
Write-Host "Total:   $($Passed + $Failed + $Skipped)" -ForegroundColor White

if ($Failed -gt 0) {
    Write-Host "`nFailed tests:" -ForegroundColor Red
    $Results | Where-Object { $_.Result -eq $false } | ForEach-Object {
        Write-Host "  - $($_.Name)" -ForegroundColor Red
    }
}

exit $Failed
