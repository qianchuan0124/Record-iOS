#!/usr/bin/env bash
# Render prototype groups to PNG with headless Chrome (1500 wide @2x).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
CHROME="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
OUT="$ROOT/shots"
mkdir -p "$OUT"

python3 "$ROOT/build.py"

for group in bill analysis payroll deposit settings; do
  height=2200
  [ "$group" = "deposit" ] && height=1250
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars \
    --window-size=1500,$height --force-device-scale-factor=2 \
    --screenshot="$OUT/$group.png" \
    "file://$ROOT/index.html?only=$group" >/dev/null 2>&1
  echo "wrote shots/$group.png"
done
