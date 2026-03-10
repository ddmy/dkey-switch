#!/usr/bin/env bash
set +e

echo "🔒 DKey Switch Agent Security Audit"
echo "==================================="

ISSUES=0
WARNINGS=0

warn() {
    echo "⚠️  WARNING: $1"
    ((WARNINGS++))
}

fail() {
    echo "❌ ISSUE: $1"
    ((ISSUES++))
}

pass() {
    echo "✅ $1"
}

echo "1) Checking required files..."
for f in "SKILL.md" "_meta.json" "scripts/d-switch.sh" "scripts/d-switch.ps1" "scripts/d-switch.cmd" "scripts/security-audit.sh" "scripts/security-audit.ps1" "scripts/security-audit.cmd"; do
    if [[ -f "$f" ]]; then
        pass "$f exists"
    else
        fail "$f missing"
    fi
done

echo "2) Checking command hints..."
if grep -q "Dalt\|Dctrl\|find-window\|list-windows\|activate-window\|activate-process\|activate-handle" "SKILL.md"; then
    pass "SKILL.md contains command hints"
else
    warn "SKILL.md may be missing command hints"
fi

echo "3) Checking usage reference updates..."
if grep -q "find-window\|activate-window\|activate-process\|activate-handle\|--json" "references/usage-patterns.md"; then
    pass "references/usage-patterns.md contains new window commands"
else
    warn "references/usage-patterns.md may be missing new window commands"
fi

echo "4) Checking JSON output hints..."
if grep -q -- "--json" "SKILL.md"; then
    pass "SKILL.md contains json output hints"
else
    warn "SKILL.md may be missing json output hints"
fi

echo "5) Checking script executable bit (best effort)..."
if [[ -x "scripts/d-switch.sh" ]]; then
    pass "scripts/d-switch.sh is executable"
else
    warn "scripts/d-switch.sh may not be executable on this filesystem"
fi

echo "==================================="
if [[ $ISSUES -eq 0 ]]; then
    echo "Audit complete: $WARNINGS warning(s), 0 issue(s)."
else
    echo "Audit complete: $WARNINGS warning(s), $ISSUES issue(s)."
fi
