#!/usr/bin/env bash
set -euo pipefail

LINES="${1:-800}"
HOME_DIR="${HOME:-$PWD}"
SRC="$HOME_DIR/.tg_ai_sales_desktop/logs/runtime.log"
DESKTOP="$HOME_DIR/Desktop"
STAMP="$(date '+%Y%m%d_%H%M%S')"
OUT="$DESKTOP/tg_ai_recent_logs_${STAMP}.log"

mkdir -p "$DESKTOP"

if [[ ! -f "$SRC" ]]; then
  echo "No runtime logs yet: $SRC"
  exit 0
fi

tail -n "$LINES" "$SRC" > "$OUT"
echo "Exported: $OUT"
