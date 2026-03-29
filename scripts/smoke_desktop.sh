#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

echo "[smoke] run static checks"
"$ROOT_DIR/scripts/ci_gate.sh"

echo "[smoke] build macos debug app"
fvm spawn 3.41.5 build macos --debug

echo "[smoke] complete"
