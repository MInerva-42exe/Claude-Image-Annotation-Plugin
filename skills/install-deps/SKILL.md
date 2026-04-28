---
name: install-deps
description: Install the CLI tools this plugin depends on — ImageMagick, Pillow, img2pdf, cwebp, and at least one screenshot backend (spectacle, grim+slurp, or flameshot). Idempotent setup script that detects distro and desktop session and installs only what is missing.
---

# Install Dependencies

Use this skill the first time the user runs an annotation/screenshot/batch skill, or whenever a downstream skill reports a missing tool.

## Just run the script

The plugin ships an idempotent setup script — invoke it and report the output.

```bash
bash "$CLAUDE_PLUGIN_ROOT/scripts/setup-env.sh"
```

It detects:
- distro from `/etc/os-release` (apt / dnf / pacman supported)
- desktop session (`XDG_CURRENT_DESKTOP`, `XDG_SESSION_TYPE`)

…then installs only the missing tools from this set:
- `imagemagick` (binary `magick`) — annotation, redaction, PDF fallback
- `python3-pillow` — Pillow-based annotator
- `img2pdf` — lossless image → PDF
- `webp` / `libwebp-tools` (binary `cwebp`) — WebP conversion
- One screenshot backend matching the session: `spectacle` (KDE), `grim` + `slurp` (wlroots Wayland), `flameshot` (everywhere else / fallback)

## Behaviour rules

- Re-run anytime — it's idempotent and only installs what's missing.
- If `sudo` is unavailable or the distro is unsupported, the script prints what to install manually; relay that to the user.
- After running, list which screenshot backend(s) are now available so downstream skills know what to pick.
