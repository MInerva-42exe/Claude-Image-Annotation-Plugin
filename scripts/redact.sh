#!/usr/bin/env bash
# Redact rectangular regions of an image — pixelate (default), blur, or solid fill.
# Originals-clean rule: never writes in place. Always outputs to <dir>/redacted/<stem>_redacted<ext>
# unless --output is supplied.
#
# Usage:
#   redact.sh --input IN [--output OUT] [--method pixelate|blur|solid] \
#             --region X,Y,W,H [--region X,Y,W,H ...]

set -euo pipefail

INPUT="" OUTPUT="" METHOD="pixelate"
REGIONS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --input) INPUT="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    --method) METHOD="$2"; shift 2 ;;
    --region) REGIONS+=("$2"); shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -n "$INPUT" ]] || { echo "--input required" >&2; exit 2; }
[[ ${#REGIONS[@]} -gt 0 ]] || { echo "at least one --region required" >&2; exit 2; }

if [[ -z "$OUTPUT" ]]; then
  D="$(dirname "$INPUT")"; B="$(basename "$INPUT")"
  STEM="${B%.*}"; EXT="${B##*.}"
  mkdir -p "$D/redacted"
  OUTPUT="$D/redacted/${STEM}_redacted.${EXT}"
fi

ARGS=(magick "$INPUT" -strip)

for R in "${REGIONS[@]}"; do
  IFS=',' read -r X Y W H <<< "$R"
  case "$METHOD" in
    pixelate)
      B=$(( W < H ? W/8 : H/8 )); [[ $B -lt 16 ]] && B=16
      SX=$(( W / B )); SY=$(( H / B ))
      [[ $SX -lt 1 ]] && SX=1
      [[ $SY -lt 1 ]] && SY=1
      ARGS+=( '(' -clone 0 -crop "${W}x${H}+${X}+${Y}" -scale "${SX}x${SY}" -scale "${W}x${H}!" ')' -geometry "+${X}+${Y}" -composite )
      ;;
    blur)
      ARGS+=( '(' -clone 0 -crop "${W}x${H}+${X}+${Y}" -blur 0x20 ')' -geometry "+${X}+${Y}" -composite )
      ;;
    solid)
      ARGS+=( -fill black -draw "rectangle ${X},${Y} $((X+W)),$((Y+H))" )
      ;;
    *) echo "unknown method: $METHOD" >&2; exit 2 ;;
  esac
done

ARGS+=("$OUTPUT")
"${ARGS[@]}"
echo "$OUTPUT"
