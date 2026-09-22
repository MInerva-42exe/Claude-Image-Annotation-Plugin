#!/usr/bin/env python3
"""
Apply annotations to an image from a JSON spec. Uses Pillow only.

Usage:
  annotate.py --input IN --spec SPEC.json [--output OUT] [--in-place]

Originals-clean rule:
  By default, writes to <input_dir>/annotated/<stem>_annotated<ext> if --output is
  not given. Never overwrites the input unless --in-place is passed.

Spec format:
  {
    "operations": [
      {"type": "arrow",     "from": [x,y], "to": [x,y], "color": "red", "width": 4},
      {"type": "box",       "xy": [x,y,w,h], "color": "red", "width": 3, "fill": null},
      {"type": "text",      "xy": [x,y], "content": "...", "color": "red", "size": 24, "background": true},
      {"type": "callout",   "target": [x,y], "label": [x,y], "content": "...", "color": "red", "size": 20},
      {"type": "highlight", "xy": [x,y,w,h], "color": "yellow", "opacity": 96},
      {"type": "marker",    "xy": [x,y], "number": 1, "color": "red", "radius": 18},
    {"type": "circle",    "xy": [x,y], "radius": 40, "color": "red", "width": 4, "fill": null}
    ]
  }
"""
from __future__ import annotations
import argparse, json, math, os, sys
from pathlib import Path
from PIL import Image, ImageColor, ImageDraw, ImageFont

# First readable font wins. The old code hardcoded the DejaVu path, which only
# exists on Linux — on macOS and Windows every text/callout/marker op silently
# fell back to a tiny unscalable bitmap face with no CJK coverage.
# Override with ANNOTATE_FONT=/path/to/font.ttf
FONT_CANDIDATES = [
    os.environ.get("ANNOTATE_FONT", ""),
    # Linux
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
    # macOS — Hiragino first so CJK renders instead of boxing out
    "/System/Library/Fonts/Hiragino Sans GB.ttc",
    "/System/Library/Fonts/PingFang.ttc",
    "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
    "/System/Library/Fonts/Helvetica.ttc",
    # Windows
    "C:\\Windows\\Fonts\\arialbd.ttf",
]

_warned = False


def load_font(size: int):
    global _warned
    for path in FONT_CANDIDATES:
        if not path:
            continue
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            continue
    if not _warned:
        print("warn: no scalable font found; text will be tiny and CJK will not "
              "render. Set ANNOTATE_FONT=/path/to/font.ttf", file=sys.stderr)
        _warned = True
    return ImageFont.load_default()


def draw_arrow(draw: ImageDraw.ImageDraw, fr, to, color, width):
    fx, fy = fr; tx, ty = to
    draw.line([(fx, fy), (tx, ty)], fill=color, width=width)
    angle = math.atan2(ty - fy, tx - fx)
    head = max(12, width * 4)
    spread = math.radians(28)
    p1 = (tx - head * math.cos(angle - spread), ty - head * math.sin(angle - spread))
    p2 = (tx - head * math.cos(angle + spread), ty - head * math.sin(angle + spread))
    draw.polygon([(tx, ty), p1, p2], fill=color)


def draw_text_with_bg(draw, xy, content, color, size, background=True):
    font = load_font(size)
    x, y = xy
    bbox = draw.textbbox((x, y), content, font=font)
    if background:
        pad = 6
        draw.rectangle((bbox[0]-pad, bbox[1]-pad, bbox[2]+pad, bbox[3]+pad),
                       fill=(255, 255, 255, 230), outline=color)
    draw.text((x, y), content, fill=color if not background else "black", font=font)


def draw_callout(draw, target, label, content, color, size):
    draw.line([tuple(target), tuple(label)], fill=color, width=3)
    draw_text_with_bg(draw, label, content, color, size, background=True)


def draw_marker(draw, xy, number, color, radius):
    x, y = xy
    draw.ellipse((x-radius, y-radius, x+radius, y+radius), fill=color)
    font = load_font(int(radius * 1.1))
    s = str(number)
    bbox = draw.textbbox((0, 0), s, font=font)
    tw, th = bbox[2]-bbox[0], bbox[3]-bbox[1]
    draw.text((x - tw/2 - bbox[0], y - th/2 - bbox[1]), s, fill="white", font=font)


KNOWN_OPS = {"arrow", "box", "text", "callout", "highlight", "marker", "circle"}


def validate(ops: list) -> list:
    """Check every op up front. A bad spec should fail before anything is drawn,
    rather than producing a clean-looking image with annotations missing."""
    errors = []
    for i, op in enumerate(ops):
        t = op.get("type")
        if t is None:
            errors.append(f"operations[{i}]: missing 'type'")
        elif t not in KNOWN_OPS:
            errors.append(
                f"operations[{i}]: unknown type {t!r} "
                f"(known: {', '.join(sorted(KNOWN_OPS))})")
    return errors


def apply(img: Image.Image, ops: list) -> Image.Image:
    img = img.convert("RGBA")
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)

    for op in ops:
        t = op["type"]
        color = op.get("color", "red")
        if t == "arrow":
            draw_arrow(draw, op["from"], op["to"], color, op.get("width", 4))
        elif t == "box":
            x, y, w, h = op["xy"]
            draw.rectangle((x, y, x+w, y+h), outline=color,
                           width=op.get("width", 3), fill=op.get("fill"))
        elif t == "text":
            draw_text_with_bg(draw, op["xy"], op["content"], color,
                              op.get("size", 24), op.get("background", True))
        elif t == "callout":
            draw_callout(draw, op["target"], op["label"], op["content"],
                         color, op.get("size", 20))
        elif t == "highlight":
            x, y, w, h = op["xy"]
            opacity = int(op.get("opacity", 96))
            r, g, b = ImageColor.getrgb(color)[:3]
            draw.rectangle((x, y, x+w, y+h), fill=(r, g, b, opacity))
        elif t == "marker":
            draw_marker(draw, op["xy"], op["number"], color, op.get("radius", 18))
        elif t == "circle":
            x, y = op["xy"]
            r = op.get("radius", 40)
            draw.ellipse((x-r, y-r, x+r, y+r), outline=color,
                         width=op.get("width", 4), fill=op.get("fill"))

    return Image.alpha_composite(img, overlay).convert("RGB")


def default_output(input_path: Path) -> Path:
    out_dir = input_path.parent / "annotated"
    out_dir.mkdir(exist_ok=True)
    return out_dir / f"{input_path.stem}_annotated{input_path.suffix}"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", required=True)
    ap.add_argument("--spec", required=True)
    ap.add_argument("--output")
    ap.add_argument("--in-place", action="store_true")
    args = ap.parse_args()

    inp = Path(args.input).expanduser().resolve()
    spec = json.loads(Path(args.spec).expanduser().read_text())

    if args.in_place:
        out = inp
    elif args.output:
        out = Path(args.output).expanduser().resolve()
        out.parent.mkdir(parents=True, exist_ok=True)
    else:
        out = default_output(inp)

    ops = spec["operations"]
    errors = validate(ops)
    if errors:
        for e in errors:
            print(f"error: {e}", file=sys.stderr)
        sys.exit(1)

    img = Image.open(inp)
    result = apply(img, ops)
    result.save(out)
    print(out)


if __name__ == "__main__":
    main()
