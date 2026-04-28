---
name: install-deps
description: Install the CLI tools this plugin depends on — ImageMagick, Pillow, and at least one screenshot backend (spectacle, grim+slurp, or flameshot). Detects distro and desktop session, installs only what is missing, and verifies the install.
---

# Install Dependencies

Use this skill the first time the user runs an annotation or screenshot skill, or whenever a downstream skill reports a missing tool.

## What to install

Required:
- `imagemagick` — provides `magick` / `convert` for headless annotation
- Python 3 + `Pillow` — for richer scripted annotation (multi-line callouts, numbered markers)

Screenshot backends — install at least one appropriate to the user's session:
- **KDE Plasma** (X11 or Wayland): `kde-spectacle` (binary: `spectacle`)
- **wlroots / Wayland generic**: `grim` and `slurp`
- **GNOME / cross-desktop fallback**: `flameshot`

## Detection

1. Distro: `cat /etc/os-release` — branch on `ID` (`ubuntu`/`debian`/`fedora`/`arch`).
2. Session type: `echo $XDG_SESSION_TYPE` (`wayland` or `x11`).
3. Desktop: `echo $XDG_CURRENT_DESKTOP` (`KDE`, `GNOME`, `sway`, etc.).

## Install commands

Debian/Ubuntu:

```bash
sudo apt update
sudo apt install -y imagemagick python3-pil
# Pick screenshot backend(s):
sudo apt install -y kde-spectacle      # KDE
sudo apt install -y grim slurp         # wlroots / generic Wayland
sudo apt install -y flameshot          # cross-desktop fallback
```

Fedora: `sudo dnf install ImageMagick python3-pillow spectacle grim slurp flameshot`

Arch: `sudo pacman -S --needed imagemagick python-pillow spectacle grim slurp flameshot`

## Verify

After install, verify each tool resolves and prints a version:

```bash
magick --version | head -1
python3 -c "import PIL; print('Pillow', PIL.__version__)"
command -v spectacle && spectacle --version 2>&1 | head -1
command -v grim && grim -h 2>&1 | head -1
command -v flameshot && flameshot --version
```

Report which backends are now available; downstream skills will pick automatically.

## Behaviour rules

- Only install what is missing — check `command -v` first for each tool.
- Never run `apt install` without `-y` (non-interactive).
- If `sudo` is unavailable, print the exact commands the user should run and stop.
- Do not edit any system config beyond installing packages.
