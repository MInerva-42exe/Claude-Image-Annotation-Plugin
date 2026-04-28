# Claude Image Annotation Plugin

Capture screenshots and apply visual annotations — arrows, text callouts, boxes, highlights, numbered markers, and privacy redaction — on Linux, all from the CLI.

Designed for screenshot-and-annotate workflows: documentation, tutorials, bug reports, and step-by-step guides.

## Skills

- **install-deps** — install the underlying CLIs (ImageMagick, Pillow, spectacle / grim+slurp / flameshot) for the user's distro and desktop session.
- **screenshot** — capture fullscreen, region, active window, or delayed. Auto-selects the best backend (spectacle on KDE, grim+slurp on wlroots Wayland, flameshot as fallback).
- **annotate** — apply arrows, boxes, text, callouts, highlights, and numbered markers via ImageMagick (simple ops) or a generated Pillow script (rich/compound layouts).
- **redact** — privacy-focused pixelation/blur/solid-fill of rectangular regions, with EXIF strip and pixelation by default (non-recoverable).
- **capture-and-annotate** — orchestrator that captures and annotates in a single step for the common "grab this and circle it" workflow.

## Underlying tools

| Capability | Primary | Fallback |
|---|---|---|
| Annotation (shapes/text) | ImageMagick 7 | Pillow (Python) |
| Screenshot — KDE Plasma | spectacle | flameshot |
| Screenshot — wlroots Wayland | grim + slurp | flameshot |
| Screenshot — X11 | spectacle / flameshot | — |

Run the `install-deps` skill on first use to install whichever of these are missing.

## Installation

```bash
claude plugins marketplace add danielrosehill/Claude-Code-Plugins
claude plugins install image-annotation@danielrosehill
```

## License

MIT
