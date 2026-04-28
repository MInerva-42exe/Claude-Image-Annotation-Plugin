#!/usr/bin/env bash
# Batch images into a single PDF. Preserves order from the command line / glob expansion.
# Originals are not modified. Prefers img2pdf (lossless, no re-encode for JPEGs);
# falls back to ImageMagick.
#
# Usage:
#   to-pdf.sh --output OUT.pdf FILE [FILE ...]
#   to-pdf.sh --output OUT.pdf --glob "annotated/*.png"

set -euo pipefail

OUTPUT=""
GLOB=""
FILES=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output) OUTPUT="$2"; shift 2 ;;
    --glob)   GLOB="$2"; shift 2 ;;
    *)        FILES+=("$1"); shift ;;
  esac
done

[[ -n "$OUTPUT" ]] || { echo "--output required" >&2; exit 2; }

if [[ -n "$GLOB" ]]; then
  shopt -s nullglob
  for f in $GLOB; do FILES+=("$f"); done
  shopt -u nullglob
fi

[[ ${#FILES[@]} -gt 0 ]] || { echo "no input files" >&2; exit 2; }

mkdir -p "$(dirname "$OUTPUT")"

if command -v img2pdf >/dev/null; then
  img2pdf --output "$OUTPUT" "${FILES[@]}"
elif command -v magick >/dev/null; then
  magick "${FILES[@]}" "$OUTPUT"
else
  echo "neither img2pdf nor magick installed — run scripts/setup-env.sh" >&2
  exit 1
fi

echo "$OUTPUT"
