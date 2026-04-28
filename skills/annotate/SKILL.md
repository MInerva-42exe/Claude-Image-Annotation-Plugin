---
name: annotate
description: Apply annotations to an image — arrows, text callouts, boxes, highlights, numbered markers. Uses ImageMagick for simple shapes and a generated Pillow script for richer layouts (multi-line callouts, drop-shadow text, numbered markers from a JSON spec).
---

# Annotate

Apply visual annotations to an existing image file. Pick the backend per-operation — ImageMagick for one-shot shape/text overlays, Pillow for compound or computed layouts.

## Inputs

- `input`: absolute path to source image
- `output`: absolute path for annotated result (do not overwrite the input by default — append `-annotated` to the stem unless the user explicitly asks to overwrite)
- `operations`: ordered list. Each operation is one of:
  - `arrow`: `from_x, from_y, to_x, to_y, color, stroke_width`
  - `box`: `x, y, w, h, color, stroke_width, fill?`
  - `text`: `x, y, content, color, size, font?, background?`
  - `callout`: `target_x, target_y, label_x, label_y, content, color` — line + text bubble
  - `highlight`: `x, y, w, h, color, opacity` — translucent rectangle
  - `marker`: `x, y, number, color` — numbered circle (1, 2, 3 …) for step-by-step diagrams

Coordinates are pixels from top-left.

## ImageMagick path (simple ops)

For single shapes or text, prefer `magick` — fewer dependencies, fast, no temp files.

Arrow:

```bash
magick "$INPUT" -fill none -stroke "$COLOR" -strokewidth "$SW" \
  -draw "line $FX,$FY $TX,$TY" \
  -draw "polygon ..."  # arrowhead — compute three points from angle of (FX,FY)→(TX,TY)
  "$OUTPUT"
```

Compute the arrowhead: angle = `atan2(TY-FY, TX-FX)`, head length ≈ `4 * SW`, two flank points at `angle ± 0.5 rad` from the tip.

Box:

```bash
magick "$INPUT" -fill none -stroke "$COLOR" -strokewidth "$SW" \
  -draw "rectangle $X,$Y $((X+W)),$((Y+H))" "$OUTPUT"
```

Text:

```bash
magick "$INPUT" -fill "$COLOR" -pointsize "$SIZE" \
  -font "${FONT:-DejaVu-Sans-Bold}" \
  -annotate +$X+$Y "$CONTENT" "$OUTPUT"
```

Highlight (translucent rectangle):

```bash
magick "$INPUT" \
  \( -clone 0 -fill "$COLOR" -draw "rectangle $X,$Y $((X+W)),$((Y+H))" \) \
  -compose blend -define compose:args="$OPACITY" -composite "$OUTPUT"
```

Multiple operations: chain `-draw` clauses in a single `magick` call rather than re-encoding per step.

## Pillow path (rich ops)

For callouts, numbered markers, multi-line text with backgrounds, or batch operations from a JSON spec, generate a Python script and run it. Write the script to a temp file (`/tmp/annotate-<random>.py`), execute, then delete.

Skeleton:

```python
from PIL import Image, ImageDraw, ImageFont
import json, sys

img = Image.open(INPUT).convert("RGBA")
overlay = Image.new("RGBA", img.size, (0,0,0,0))
draw = ImageDraw.Draw(overlay)
font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", SIZE)

# marker: filled circle + centered number
draw.ellipse((x-r, y-r, x+r, y+r), fill=COLOR)
bbox = draw.textbbox((0,0), str(n), font=font)
tw, th = bbox[2]-bbox[0], bbox[3]-bbox[1]
draw.text((x-tw/2, y-th/2), str(n), fill="white", font=font)

# callout: line from target to label, then text with background pad
draw.line([(tx,ty),(lx,ly)], fill=COLOR, width=3)
pad = 6
tb = draw.textbbox((lx,ly), content, font=font)
draw.rectangle((tb[0]-pad, tb[1]-pad, tb[2]+pad, tb[3]+pad), fill=(255,255,255,230), outline=COLOR)
draw.text((lx,ly), content, fill="black", font=font)

Image.alpha_composite(img, overlay).convert("RGB").save(OUTPUT)
```

When the user supplies a JSON spec (`{"operations": [...]}`), accept it as `--spec spec.json` and iterate.

## Behaviour rules

- Never overwrite `input` unless the user explicitly says "overwrite" or "in place".
- Default colors: `red` for arrows/boxes, `yellow` for highlights, `red` filled for markers.
- Default font: `DejaVu-Sans-Bold` (always present on Debian/Ubuntu/Fedora). If the user's preferred font is missing, fall back and mention it.
- Text on busy backgrounds: add a translucent white rectangle behind the text by default unless `background: false`.
- Always print the output path on success, plus the operations applied.
