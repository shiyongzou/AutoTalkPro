#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

REPORT_PATH="docs/reports/latest_gate.json"
MARKDOWN_PATH="docs/reports/latest_gate.md"
COVERAGE_THRESHOLD="${COVERAGE_THRESHOLD:-70}"
COVERAGE_VALUE="${COVERAGE_VALUE:-}"
UI_TOKEN_COVERAGE="${UI_TOKEN_COVERAGE:-}"
UI_TOKEN_THRESHOLD="${UI_TOKEN_THRESHOLD:-0.9}"
UI_VIOLATION_COUNT="${UI_VIOLATION_COUNT:-0}"
UI_VIOLATION_THRESHOLD="${UI_VIOLATION_THRESHOLD:-0}"

ci_status="passed"
ci_detail="ok"
ci_exit=0

echo "[release-check] run ci gate"
set +e
"$ROOT_DIR/scripts/ci_gate.sh"
ci_exit=$?
set -e
if [[ "$ci_exit" -ne 0 ]]; then
  ci_status="failed"
  ci_detail="ci_gate exit code $ci_exit"
fi

echo "[release-check] build gate artifacts"
cmd=(
  dart run tool/release_gate_report.dart
  --output "$REPORT_PATH"
  --markdown-output "$MARKDOWN_PATH"
  --ci-status "$ci_status"
  --ci-detail "$ci_detail"
  --coverage-threshold "$COVERAGE_THRESHOLD"
  --ui-token-threshold "$UI_TOKEN_THRESHOLD"
  --ui-violation-threshold "$UI_VIOLATION_THRESHOLD"
  --ui-violation-count "$UI_VIOLATION_COUNT"
)

if [[ -n "$COVERAGE_VALUE" ]]; then
  cmd+=(--coverage "$COVERAGE_VALUE")
fi

if [[ -n "$UI_TOKEN_COVERAGE" ]]; then
  cmd+=(--ui-token-coverage "$UI_TOKEN_COVERAGE")
fi

"${cmd[@]}"

echo "[release-check] report ready: $REPORT_PATH"
echo "[release-check] markdown ready: $MARKDOWN_PATH"
if [[ -f "$MARKDOWN_PATH" ]]; then
  echo
  echo "[release-check] readable markdown"
  cat "$MARKDOWN_PATH"
fi

if [[ "$ci_status" != "passed" ]]; then
  echo "[release-check] failed: ci gate not passed"
  exit "$ci_exit"
fi

echo "[release-check] passed"
