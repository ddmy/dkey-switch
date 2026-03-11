$ErrorActionPreference = 'Continue'

Write-Host "🔒 DKey Switch Agent Security Audit"
Write-Host "==================================="

$issues = 0
$warnings = 0

function Warn([string]$m) { Write-Host "⚠️  WARNING: $m"; $script:warnings++ }
function Fail([string]$m) { Write-Host "❌ ISSUE: $m"; $script:issues++ }
function Pass([string]$m) { Write-Host "✅ $m" }

Write-Host "1) Checking required files..."
$required = @(
  "SKILL.md","_meta.json",
  "scripts/d-switch.sh","scripts/d-switch.ps1","scripts/d-switch.cmd",
  "scripts/security-audit.sh","scripts/security-audit.ps1","scripts/security-audit.cmd",
  "references/ai-e2e-cases.md"
)
foreach ($f in $required) {
  if (Test-Path $f) { Pass "$f exists" } else { Fail "$f missing" }
}

Write-Host "2) Checking command hints..."
$skill = if (Test-Path "SKILL.md") { Get-Content "SKILL.md" -Raw } else { "" }
if ($skill -match "Dalt|Dctrl|find-window|list-windows|activate-window|activate-process|activate-handle") {
  Pass "SKILL.md contains command hints"
} else {
  Warn "SKILL.md may be missing command hints"
}

Write-Host "3) Checking usage reference updates..."
$usage = if (Test-Path "references/usage-patterns.md") { Get-Content "references/usage-patterns.md" -Raw } else { "" }
if ($usage -match "find-window|activate-window|activate-process|activate-handle|--json") {
  Pass "references/usage-patterns.md contains new window commands"
} else {
  Warn "references/usage-patterns.md may be missing new window commands"
}

Write-Host "4) Checking JSON output hints..."
if ($skill -match "--json") {
  Pass "SKILL.md contains json output hints"
} else {
  Warn "SKILL.md may be missing json output hints"
}

Write-Host "5) Checking AI canonical routing hints..."
if ($skill -match "AI 决策模板|Canonical" -and $usage -match "Canonical Intent -> Command") {
  Pass "AI canonical routing hints exist in SKILL and usage docs"
} else {
  Warn "Canonical routing hints may be missing"
}

Write-Host "6) Checking status contract references..."
if ($skill -match "activated|not_found|choice_out_of_range|activation_failed" -and $usage -match "ok|activated|not_found|choice_out_of_range|activation_failed") {
  Pass "Status contract appears in SKILL and usage docs"
} else {
  Warn "Status contract may be incomplete"
}

Write-Host "7) Checking exit code references..."
if ($skill -match "退出码约定" -and $usage -match "Exit Codes" -and $usage -match "0|1|2|3|4") {
  Pass "Exit code references exist"
} else {
  Warn "Exit code references may be missing"
}

Write-Host "8) Checking memory fact alignment..."
$memoryDoc = if (Test-Path "assets/MEMORY.md") { Get-Content "assets/MEMORY.md" -Raw } else { "" }
if ($memoryDoc -match "scripts/d-switch.ps1" -and $memoryDoc -match "activate-window|activate-process|activate-handle") {
  Pass "assets/MEMORY.md is aligned with current command surface"
} else {
  Warn "assets/MEMORY.md may be outdated"
}

Write-Host "9) Checking onboarding release checklist..."
$onboarding = if (Test-Path "assets/ONBOARDING.md") { Get-Content "assets/ONBOARDING.md" -Raw } else { "" }
if ($onboarding -match "Release Checklist" -and $onboarding -match "Fast Verification Commands") {
  Pass "assets/ONBOARDING.md contains release checklist"
} else {
  Warn "assets/ONBOARDING.md may be missing release checklist"
}

Write-Host "10) Checking AI E2E cases coverage..."
$cases = if (Test-Path "references/ai-e2e-cases.md") { Get-Content "references/ai-e2e-cases.md" -Raw } else { "" }
$caseCount = ([regex]::Matches($cases, "\n\d+\. Intent:")).Count
if ($cases -match "Expected status" -and $caseCount -ge 10) {
  Pass "references/ai-e2e-cases.md has $caseCount cases"
} else {
  Warn "AI E2E cases may be insufficient (found: $caseCount)"
}

Write-Host "==================================="
if ($issues -eq 0) {
  Write-Host "Audit complete: $warnings warning(s), 0 issue(s)."
  exit 0
} else {
  Write-Host "Audit complete: $warnings warning(s), $issues issue(s)."
  exit 1
}
