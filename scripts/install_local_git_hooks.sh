#!/usr/bin/env bash
# SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
#
# Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
# All rights reserved.
#
# TTZip: High-performance native archiving and compression engine for macOS.
# SPDX-License-Identifier: BSD-3-Clause
#
# Installs local pre-push and pre-commit Git hooks for zero-cloud CI verification.

set -e

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOKS_DIR="$REPO_ROOT/.git/hooks"

mkdir -p "$HOOKS_DIR"

cat << 'EOF' > "$HOOKS_DIR/pre-push"
#!/usr/bin/env bash
# TTZip Local Zero-Cloud CI Pre-Push Gate

set -e

REPO_ROOT="$(git rev-parse --show-toplevel)"
echo "======================================================================"
echo "⚡️ Running TTZip Local CI Gate (Zero Cloud Actions Quota)..."
echo "======================================================================"

"$REPO_ROOT/scripts/run_local_ci_gate.sh"
EOF

chmod +x "$HOOKS_DIR/pre-push"

echo "✅ Local Git pre-push hook installed successfully at: $HOOKS_DIR/pre-push"
echo "   All future git push operations will run the 6-stage CI gate locally (0 cloud runner minutes used)."
