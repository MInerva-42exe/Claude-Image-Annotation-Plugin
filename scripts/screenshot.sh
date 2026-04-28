#!/usr/bin/env bash
# Backend-aware screenshot wrapper.
# Usage: screenshot.sh <full|region|window|delay:N> [output_path]
# Default output: ~/Pictures/Screenshots/<ISO>.png

set -euo pipefail

MODE="${1:-full}"
OUT="${2:-}"

if [[ -z "$OUT" ]]; then
  DIR="$HOME/Pictures/Screenshots"
  mkdir -p "$DIR"
  OUT="$DIR/$(date -u +%Y-%m-%dT%H-%M-%SZ).png"
fi
mkdir -p "$(dirname "$OUT")"

DESKTOP="${XDG_CURRENT_DESKTOP:-}"
SESSION="${XDG_SESSION_TYPE:-}"

DELAY=0
if [[ "$MODE" == delay:* ]]; then
  DELAY="${MODE#delay:}"
  MODE=full
fi

pick_backend() {
  if [[ "$DESKTOP" == *KDE* ]] && command -v spectacle >/dev/null; then
    echo spectacle; return
  fi
  if [[ "$SESSION" == wayland ]] && command -v grim >/dev/null; then
    echo grim; return
  fi
  if command -v flameshot >/dev/null; then
    echo flameshot; return
  fi
  echo none
}

BACKEND="$(pick_backend)"
[[ "$BACKEND" == none ]] && {
  echo "no screenshot backend installed — run scripts/setup-env.sh" >&2
  exit 1
}

case "$BACKEND:$MODE" in
  spectacle:full)   spectacle -b -n -d "$DELAY" -o "$OUT" ;;
  spectacle:region) spectacle -b -n -r -o "$OUT" ;;
  spectacle:window) spectacle -b -n -a -o "$OUT" ;;
  grim:full)        [[ $DELAY -gt 0 ]] && sleep "$DELAY"; grim "$OUT" ;;
  grim:region)      command -v slurp >/dev/null || { echo "slurp not installed" >&2; exit 1; }; grim -g "$(slurp)" "$OUT" ;;
  grim:window)      echo "grim window mode not implemented in this wrapper — use region" >&2; exit 1 ;;
  flameshot:full)   flameshot full -d "$((DELAY*1000))" -p "$(dirname "$OUT")" -r > "$OUT" ;;
  flameshot:region) flameshot gui -p "$(dirname "$OUT")" ;;
  flameshot:window) echo "flameshot window mode not supported — use full or region" >&2; exit 1 ;;
  *) echo "unsupported mode '$MODE' for backend '$BACKEND'" >&2; exit 1 ;;
esac

[[ -s "$OUT" ]] || { echo "capture produced no output (cancelled?)" >&2; exit 2; }

echo "$OUT"
