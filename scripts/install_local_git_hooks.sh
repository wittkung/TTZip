#!/usr/bin/env bash
# SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
#
# Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
# All rights reserved.
#
# TTZip: High-performance native archiving and compression engine for macOS.
#
# Installs local pre-push and pre-commit Git hooks for zero-cloud CI verification.

set -e

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOKS_DIR="$REPO_ROOT/.git/hooks"

mkdir -p "$HOOKS_DIR"

cat << 'EOF' > "$HOOKS_DIR/pre-push"
#!/usr/bin/env bash
# SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
#
# Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
# All rights reserved.
#
# TTZip: High-performance native archiving and compression engine for macOS.
# TTZip Local Zero-Cloud CI Pre-Push Gate & Single-File LOC Gate (<= 800 LOC)

set -e

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || (cd "$(dirname "$0")/../.." && pwd))"
cd "$REPO_ROOT"

echo "======================================================================"
echo "⚡️ Running TTZip Local CI Gate (Zero Cloud Actions Quota)..."
echo "======================================================================"

# 1. Direct Single-File LOC Defense Gate Check
"$REPO_ROOT/scripts/lint_loc_gate.sh"

# 2. Complete Local CI Gate Execution
"$REPO_ROOT/scripts/run_local_ci_gate.sh"
EOF

chmod +x "$HOOKS_DIR/pre-push"

echo "✅ Local Git pre-push hook installed successfully at: $HOOKS_DIR/pre-push"
echo "   All future git push operations will run the LOC defense gate & automated test stages locally (0 cloud runner minutes used)."
