#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

echo "[gate] flutter analyze"
fvm spawn 3.41.5 analyze

echo "[gate] flutter test"
fvm spawn 3.41.5 test

if command -v dart >/dev/null 2>&1; then
  echo "[gate] dart format check"
  dart format --set-exit-if-changed lib test
else
  echo "[gate] dart not found, skip format check in local gate"
fi

echo "[gate] done"
