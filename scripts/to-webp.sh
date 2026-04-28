#!/usr/bin/env bash
# Batch-convert images to WebP. Originals are left untouched.
# Outputs to <dir>/webp/<stem>.webp unless --out-dir is supplied.
#
# Usage:
#   to-webp.sh [--quality N] [--lossless] [--out-dir DIR] FILE [FILE ...]
#   to-webp.sh --glob "*.png" [--quality N] [--out-dir DIR]

set -euo pipefail

QUALITY=85
LOSSLESS=0
OUT_DIR=""
GLOB=""
FILES=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --quality)  QUALITY="$2"; shift 2 ;;
    --lossless) LOSSLESS=1; shift ;;
    --out-dir)  OUT_DIR="$2"; shift 2 ;;
    --glob)     GLOB="$2"; shift 2 ;;
    *)          FILES+=("$1"); shift ;;
  esac
done

if [[ -n "$GLOB" ]]; then
  shopt -s nullglob
  for f in $GLOB; do FILES+=("$f"); done
  shopt -u nullglob
fi

[[ ${#FILES[@]} -gt 0 ]] || { echo "no input files" >&2; exit 2; }
command -v cwebp >/dev/null || { echo "cwebp not installed — run scripts/setup-env.sh" >&2; exit 1; }

OPTS=(-q "$QUALITY")
[[ $LOSSLESS -eq 1 ]] && OPTS=(-lossless)

CONVERTED=0 SKIPPED=0
for f in "${FILES[@]}"; do
  if [[ ! -f "$f" ]]; then
    echo "skip (not a file): $f" >&2; SKIPPED=$((SKIPPED+1)); continue
  fi
  D="$(dirname "$f")"; B="$(basename "$f")"; STEM="${B%.*}"
  OD="${OUT_DIR:-$D/webp}"
  mkdir -p "$OD"
  OUT="$OD/${STEM}.webp"
  cwebp "${OPTS[@]}" "$f" -o "$OUT" -quiet
  echo "$OUT"
  CONVERTED=$((CONVERTED+1))
done

echo "converted=$CONVERTED skipped=$SKIPPED" >&2
