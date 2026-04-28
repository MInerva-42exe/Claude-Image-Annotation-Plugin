# Claude Image Annotation Plugin

Capture screenshots and apply visual annotations — arrows, text callouts, boxes, highlights, numbered markers, and privacy redaction — on Linux, all from the CLI. Plus batch conversion to WebP and bundling into PDFs for tutorials and bug reports.

Designed for screenshot-and-annotate workflows: documentation, tutorials, bug reports, and step-by-step guides.

## Originals-clean rule

This plugin **never modifies your source images**. Annotations land in `<dir>/annotated/<stem>_annotated<ext>`, redactions in `<dir>/redacted/<stem>_redacted<ext>`, WebP conversions in `<dir>/webp/<stem>.webp`. Your originals stay untouched unless you pass an explicit `--in-place` flag (where supported).

## Skills

- **install-deps** — run the bundled `setup-env.sh` to install ImageMagick, Pillow, img2pdf, cwebp, and the right screenshot backend for your desktop.
- **screenshot** — capture fullscreen, region, active window, or delayed. Auto-selects spectacle (KDE), grim+slurp (wlroots Wayland), or flameshot (fallback).
- **annotate** — apply arrows, boxes, text, callouts, highlights, and numbered markers via a JSON spec. Pillow-backed.
- **redact** — privacy-focused pixelate/blur/solid-fill of regions, with EXIF strip. Pixelation is the default and is non-recoverable.
- **capture-and-annotate** — one-shot orchestrator for "grab this and circle it" workflows.
- **batch-to-webp** — bulk-convert images to WebP, lossy or lossless, with originals untouched.
- **batch-to-pdf** — bundle annotated images into a single PDF (lossless via img2pdf when installed).

## Underlying tools

| Capability | Primary | Fallback |
|---|---|---|
| Annotation | Pillow (`scripts/annotate.py`) | — |
| Redaction | ImageMagick | — |
| Screenshot — KDE Plasma | spectacle | flameshot |
| Screenshot — wlroots Wayland | grim + slurp | flameshot |
| Image → PDF | img2pdf | ImageMagick |
| Image → WebP | cwebp | — |

Run the `install-deps` skill once to install whichever of these are missing for your distro and desktop.

## Installation

```bash
claude plugins marketplace add danielrosehill/Claude-Code-Plugins
claude plugins install image-annotation@danielrosehill
```

## License

MIT
