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
for f in "SKILL.md" "_meta.json" "scripts/d-switch.sh"; do
    if [[ -f "$f" ]]; then
        pass "$f exists"
    else
        fail "$f missing"
    fi
done

echo "2) Checking command hints..."
if grep -q "Dalt\|Dctrl" "SKILL.md"; then
    pass "SKILL.md contains command hints"
else
    warn "SKILL.md may be missing command hints"
fi

echo "3) Checking script executable bit (best effort)..."
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
