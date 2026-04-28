---
name: screenshot
description: Capture a screenshot on Linux — fullscreen, region, active window, or delayed. Auto-selects the best backend for the session (spectacle on KDE, grim+slurp on wlroots Wayland, flameshot fallback). Saves to a user-specified path or a sensible default.
---

# Screenshot

Capture a screenshot from the CLI and save it to a file path. Used standalone or as the first step of `capture-and-annotate`.

## Just run the script

```bash
bash "$CLAUDE_PLUGIN_ROOT/scripts/screenshot.sh" <mode> [output_path]
```

`mode` is one of:
- `full` — full screen (default)
- `region` — interactive region selection
- `window` — active window
- `delay:N` — delay N seconds, then capture full screen

Default output path: `~/Pictures/Screenshots/<ISO-timestamp>.png` (directory auto-created).

The script picks the backend automatically:
1. `spectacle` if `XDG_CURRENT_DESKTOP` contains `KDE`
2. `grim` (+ `slurp` for region) if `XDG_SESSION_TYPE=wayland`
3. `flameshot` otherwise

If no backend is installed, it tells you to run the `install-deps` skill.

## Output

The script prints the absolute output path on success. Exit code 2 means capture produced no file (typically a cancelled region selection) — surface that to the user, do not silently retry.

## Edge cases

- **GNOME on Wayland**: `grim` does not work under Mutter; the script falls back to `flameshot` automatically.
- **Multi-monitor**: spectacle and grim capture all outputs by default. For a single monitor pass `-o <name>` to grim or `-m` to spectacle (extend the script if you need this regularly).
- **Headless sessions**: capture is impossible; report and stop.
