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
  "scripts/security-audit.sh","scripts/security-audit.ps1","scripts/security-audit.cmd"
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

Write-Host "==================================="
if ($issues -eq 0) {
  Write-Host "Audit complete: $warnings warning(s), 0 issue(s)."
  exit 0
} else {
  Write-Host "Audit complete: $warnings warning(s), $issues issue(s)."
  exit 1
}
