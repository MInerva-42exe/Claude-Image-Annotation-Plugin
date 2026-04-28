---
name: screenshot
description: Capture a screenshot on Linux — fullscreen, region, active window, or delayed. Auto-selects the best backend for the session (spectacle on KDE, grim+slurp on wlroots Wayland, flameshot as fallback). Saves to a user-specified path or a sensible default.
---

# Screenshot

Capture a screenshot from the CLI and save it to a file path. Used standalone or as the first step of `capture-and-annotate`.

## Inputs

- `mode`: `full` (default) | `region` | `window` | `delay:N` (delay N seconds, then full)
- `output`: absolute path. Default: `~/Pictures/Screenshots/<ISO-timestamp>.png` — create the directory if missing.

## Backend selection

Detect once per invocation:

1. If `XDG_CURRENT_DESKTOP` contains `KDE` and `spectacle` is on PATH → use spectacle.
2. Else if `XDG_SESSION_TYPE=wayland` and `grim` is on PATH → use grim (+ slurp for region).
3. Else if `flameshot` is on PATH → use flameshot.
4. Else → tell the user to run the `install-deps` skill.

## Backend commands

### spectacle (KDE)

```bash
# fullscreen, no GUI, save and exit
spectacle -b -n -o "$OUTPUT"
# region
spectacle -b -n -r -o "$OUTPUT"
# active window
spectacle -b -n -a -o "$OUTPUT"
# delayed fullscreen
spectacle -b -n -d "$N" -o "$OUTPUT"
```

### grim + slurp (Wayland)

```bash
# fullscreen
grim "$OUTPUT"
# region (interactive selection)
grim -g "$(slurp)" "$OUTPUT"
# active window — derive geometry from the compositor
# KDE: kdotool getactivewindow → kdotool getwindowgeometry
# Hyprland: hyprctl activewindow -j | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"'
# Sway: swaymsg -t get_tree | jq ...
# delayed: sleep N && grim "$OUTPUT"
```

### flameshot (fallback)

```bash
# fullscreen, headless
flameshot full -p "$(dirname "$OUTPUT")" -r > "$OUTPUT"
# region requires GUI:
flameshot gui -p "$(dirname "$OUTPUT")"
# delayed
flameshot full -d $((N*1000)) -p "$(dirname "$OUTPUT")" -r > "$OUTPUT"
```

Note: flameshot writes its own filename when using `-p`; redirect raw bytes via `-r` to control the output path exactly.

## Output

Confirm the file exists and is non-empty, then report the absolute path. If the backend printed nothing and the file is missing or zero bytes (common when the user cancelled a region selection), say so plainly — do not retry silently.

## Edge cases

- Wayland + GNOME: `grim` is unlikely to work (Mutter does not implement wlr-screencopy). Fall back to `flameshot` or tell the user.
- Multi-monitor: spectacle and grim capture all outputs by default; pass `-o <name>` to grim or use spectacle's `-m` for a single monitor.
- Headless sessions: capture is impossible without a display — report and stop.
