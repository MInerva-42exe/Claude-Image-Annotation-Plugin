---
name: redact
description: Privacy redaction — blur, pixelate, or solid-fill rectangular regions of an image to hide sensitive content (faces, names, tokens, IPs, PII). Headless via ImageMagick; safe defaults that prevent recoverable redaction.
---

# Redact

Hide sensitive regions of an image. Use this rather than `annotate` when the goal is privacy — the defaults here are tuned to make the redaction non-recoverable.

## Inputs

- `input`: absolute path to source image
- `output`: absolute path. Default: append `-redacted` to the input stem.
- `regions`: list of `{x, y, w, h, method?}`
  - `method`: `pixelate` (default) | `blur` | `solid`

## Why pixelate by default

Gaussian blur on text is reversible with deconvolution — pixelation with a coarse grid is not. Default the block size to `max(16, min(w,h)/8)` so even a small region collapses to ≤8 cells per side.

## ImageMagick recipes

Pixelate one region:

```bash
# block size B; scale down then back up with nearest-neighbour
magick "$INPUT" \
  \( -clone 0 -crop "${W}x${H}+${X}+${Y}" \
     -scale "$((W/B))x$((H/B))" \
     -scale "${W}x${H}!" \) \
  -geometry "+${X}+${Y}" -composite "$OUTPUT"
```

Blur one region:

```bash
magick "$INPUT" \
  \( -clone 0 -crop "${W}x${H}+${X}+${Y}" -blur 0x20 \) \
  -geometry "+${X}+${Y}" -composite "$OUTPUT"
```

Solid fill (most opaque, least subtle):

```bash
magick "$INPUT" -fill black \
  -draw "rectangle $X,$Y $((X+W)),$((Y+H))" "$OUTPUT"
```

Multiple regions: chain `\( ... \) -composite` clauses in one `magick` call so re-encoding only happens once.

## Behaviour rules

- Always write to a new file. Never offer "overwrite in place" for redaction — the user should keep the original somewhere safe (or explicitly delete it themselves).
- Strip EXIF on the output: append `-strip` to the magick command. Sensitive metadata (GPS, original timestamp, device) often survives visual redaction.
- After writing, report: output path, regions redacted, method used per region, and a one-line reminder that the original still contains the unredacted content.
- If the user asks to "blur a face/text" without coordinates, ask for the bounding box — this skill does not detect content automatically.
