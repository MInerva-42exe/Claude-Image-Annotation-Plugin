#!/usr/bin/env bash
# Backend-aware screenshot wrapper.
# Usage: screenshot.sh <full|region|window|window:PATTERN|delay:N> [output_path]
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

# window:PATTERN captures a named window with no click, by resolving its window
# id and handing that to screencapture -l. Plain "window" stays interactive.
WINDOW_PATTERN=""
if [[ "$MODE" == window:* ]]; then
  WINDOW_PATTERN="${MODE#window:}"
  MODE=window-id
fi

DELAY=0
if [[ "$MODE" == delay:* ]]; then
  DELAY="${MODE#delay:}"
  MODE=full
fi

pick_backend() {
  # macOS first: none of the Linux backends exist there, and screencapture is
  # always present, so probing for spectacle/grim/flameshot would only waste time.
  if [[ "$(uname)" == Darwin ]] && command -v screencapture >/dev/null; then
    echo screencapture; return
  fi
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

resolve_window_id() {
  python3 - "$1" <<'PYEOF'
import sys
try:
    from Quartz import (CGWindowListCopyWindowInfo,
                        kCGWindowListOptionOnScreenOnly, kCGNullWindowID)
except ImportError:
    sys.stderr.write("window:PATTERN needs pyobjc — pip3 install pyobjc-framework-Quartz\n")
    sys.exit(3)

pattern = sys.argv[1].lower()
matches = []
for w in (CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly, kCGNullWindowID) or []):
    if w.get("kCGWindowLayer", 0) != 0:      # skip dock, menu bar, desktop layers
        continue
    bounds = w.get("kCGWindowBounds") or {}
    if bounds.get("Width", 0) < 50 or bounds.get("Height", 0) < 50:
        continue
    owner = w.get("kCGWindowOwnerName") or ""
    title = w.get("kCGWindowName") or ""
    if pattern in owner.lower() or pattern in title.lower():
        area = bounds.get("Width", 0) * bounds.get("Height", 0)
        matches.append((area, w.get("kCGWindowNumber"), owner, title))

if not matches:
    sys.stderr.write("no on-screen window matching %r\n" % sys.argv[1])
    sys.exit(4)

matches.sort(reverse=True)          # largest match wins
_, wid, owner, title = matches[0]
if len(matches) > 1:
    sys.stderr.write("note: %d windows matched; using largest\n" % len(matches))
sys.stderr.write("matched: %s — %s\n" % (owner, title or "(untitled)"))
print(wid)
PYEOF
}

BACKEND="$(pick_backend)"
[[ "$BACKEND" == none ]] && {
  echo "no screenshot backend installed — run scripts/setup-env.sh" >&2
  exit 1
}

# Don't let set -e abort on the backend's own exit status: a cancelled capture
# makes most backends exit non-zero, and we want that reported as 2 (cancelled)
# via the emptiness check below, not as a generic 1.
set +e
case "$BACKEND:$MODE" in
  # -x silences the shutter; -T applies the delay; -o drops the window shadow so
  # the PNG has no translucent padding around it (harmless for full/region).
  screencapture:full)   screencapture -x -T "$DELAY" "$OUT" ;;
  screencapture:region) screencapture -x -i "$OUT" ;;
  # -w is click-to-pick-a-window, NOT "capture the frontmost window" the way
  # spectacle -a is. The user has to click the window they want.
  screencapture:window) screencapture -x -o -w "$OUT" ;;
  screencapture:window-id)
      WID="$(resolve_window_id "$WINDOW_PATTERN")" || exit 1
      screencapture -x -o -l "$WID" "$OUT" ;;

  spectacle:full)   spectacle -b -n -d "$DELAY" -o "$OUT" ;;
  spectacle:region) spectacle -b -n -r -o "$OUT" ;;
  spectacle:window) spectacle -b -n -a -o "$OUT" ;;

  grim:full)        [[ $DELAY -gt 0 ]] && sleep "$DELAY"; grim "$OUT" ;;
  grim:region)      command -v slurp >/dev/null || { echo "slurp not installed" >&2; exit 1; }; grim -g "$(slurp)" "$OUT" ;;
  grim:window)      echo "grim window mode not implemented in this wrapper — use region" >&2; exit 1 ;;

  # --raw writes the PNG to stdout so we control the filename. The previous
  # -p "$(dirname "$OUT")" let flameshot name the file itself, which meant
  # region captures never landed at "$OUT" at all.
  flameshot:full)   flameshot full -d "$((DELAY*1000))" --raw > "$OUT" ;;
  flameshot:region) flameshot gui --raw > "$OUT" ;;
  flameshot:window) echo "flameshot window mode not supported — use full or region" >&2; exit 1 ;;

  *:window-id) echo "window:PATTERN is macOS-only; use 'window' or 'region'" >&2; exit 1 ;;
  *) echo "unsupported mode '$MODE' for backend '$BACKEND'" >&2; exit 1 ;;
esac
CAP_RC=$?
set -e

# Emptiness wins over the backend's status: no file means the user cancelled,
# which callers distinguish from a real failure.
[[ -s "$OUT" ]] || { echo "capture produced no output (cancelled?)" >&2; exit 2; }
[[ $CAP_RC -eq 0 ]] || { echo "backend '$BACKEND' exited $CAP_RC" >&2; exit 1; }

echo "$OUT"
