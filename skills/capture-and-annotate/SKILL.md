---
name: capture-and-annotate
description: One-shot orchestrator — capture a screenshot and immediately draw annotations on it (arrows, boxes, highlights, text, callouts, numbered markers). Use this whenever the user wants a capture AND markup in the same breath: "screenshot this and box the login button", "grab the active window and put a 1 on the error dialog", "capture a region and label it Step 1", "screenshot the sidebar and point an arrow at the settings gear". Also use when the user describes the target in words rather than pixel coordinates — this skill identifies the target visually from the capture. Do NOT use when the user wants the unannotated capture kept as a file (run the screenshot skill to a real path, then the annotate skill), or when annotating an image that already exists on disk (use the annotate skill alone).
---

# Capture and Annotate

Capture and markup in one turn, leaving no intermediate file for the user to manage.

The reason this is its own skill rather than "run screenshot, then run annotate" is the coordinate problem: annotation coordinates are in the captured image's space, so they cannot be known until after the capture. Chaining the two skills naively forces a round trip through the user in the middle. This skill closes that gap by **looking at the capture** and deriving coordinates from it.

## Script contract

Both scripts live at the plugin root, not in this skill's folder.

### `scripts/screenshot.sh <mode> [output_path]`

Modes: `full`, `region`, `window`, `delay:N` (N in seconds).

Prints the output path on success. Exits **2** when the capture produced nothing — the usual cause is the user cancelling a region selection. Exits 1 for an unsupported mode/backend combination or a missing backend.

Backend support is uneven, and the wrapper picks the backend from the environment. This matters because `window` is the mode users ask for most:

| Mode       | spectacle (KDE) | grim (wlroots)   | flameshot (fallback) |
| ---------- | --------------- | ---------------- | -------------------- |
| `full`     | yes             | yes              | yes                  |
| `region`   | yes             | yes (needs slurp)| **ignores your path**|
| `window`   | yes             | exits 1          | exits 1              |
| `delay:N`  | yes             | yes (sleep)      | yes                  |

Two consequences worth knowing before you promise the user a result:

- **`window` only works on KDE/spectacle.** On other backends it exits 1. If the user asks for the active window and the backend isn't spectacle, say so and offer `region` instead rather than letting the script fail.
- **`flameshot:region` ignores the output path you pass.** It saves under flameshot's own naming into the parent directory, so your temp path will not exist afterwards and this skill's flow will break. Prefer `full` on flameshot, or tell the user the fallback backend can't do a targeted region capture into a chosen file.
- `delay:N` internally rewrites the mode to `full`, so there is no delayed region or delayed window capture.

### `scripts/annotate.py --input IN --spec SPEC.json [--output OUT] [--in-place]`

`--spec` is a **path to a JSON file**, not an inline JSON string. Write the spec to a temp file next to the capture.

The top-level key is `operations` (not `annotations`). Supported types, with their real field names:

```json
{
  "operations": [
    {"type": "arrow",     "from": [x,y], "to": [x,y], "color": "red", "width": 4},
    {"type": "box",       "xy": [x,y,w,h], "color": "red", "width": 3, "fill": null},
    {"type": "text",      "xy": [x,y], "content": "...", "color": "red", "size": 24, "background": true},
    {"type": "callout",   "target": [x,y], "label": [x,y], "content": "...", "color": "red", "size": 20},
    {"type": "highlight", "xy": [x,y,w,h], "color": "yellow", "opacity": 96},
    {"type": "marker",    "xy": [x,y], "number": 1, "color": "red", "radius": 18}
  ]
}
```

Four traps in this schema, each of which produces a wrong image rather than an error:

- **`box` and `highlight` take `[x, y, width, height]`, not two corners.** Deriving a box from a bounding box means `[x1, y1, x2-x1, y2-y1]`.
- **There is no `circle` type.** Users ask to "circle" things constantly — that's the plugin's own headline phrasing — but the annotator can't draw one. Translate "circle X" to a `box` around X, or to a `marker` when the user wants a numbered badge. Say which you used, so the user isn't surprised by a rectangle.
- **Unknown types are skipped with a warning on stderr and exit code 0.** A typo'd or invented type produces a clean-looking success with nothing drawn. Validate every `type` against the six above *before* running, and check stderr for `warn: unknown op type` after.
- **Coordinates are not bounds-checked.** Off-image annotations draw silently into nothing.

Also note: `text` with `background: true` (the default) renders the glyphs in **black** and uses `color` only for the box outline. For coloured text, pass `background: false`.

**Always pass `--output` explicitly.** Without it the annotator writes to `<input_dir>/annotated/<stem>_annotated<ext>` — and since the input here is a temp file, that means the result lands in the temp directory and gets lost. `--output` creates parent directories itself.

## Flow

1. **Capture to a temp path.** Use `mktemp` rather than `$RANDOM`, which is only 15 bits and collides:

   ```bash
   TMPDIR_C="$(mktemp -d -t cap-XXXXXXXX)"
   TMP="$TMPDIR_C/capture.png"
   bash "$CLAUDE_PLUGIN_ROOT/scripts/screenshot.sh" "$MODE" "$TMP"
   ```

2. **Check the exit code before going further.** The script already verifies the file is non-empty, so trust its status rather than re-testing:

   ```bash
   rc=$?
   if [ "$rc" -eq 2 ]; then echo "capture cancelled"; rm -rf "$TMPDIR_C"; exit 2; fi
   if [ "$rc" -ne 0 ]; then echo "capture failed (mode/backend unsupported?)"; rm -rf "$TMPDIR_C"; exit 1; fi
   ```

   On a cancelled capture, stop and tell the user. Do not proceed to annotation.

3. **Determine coordinates** — see below.

4. **Write the spec** to `"$TMPDIR_C/spec.json"`, using only the six supported types.

5. **Annotate to the final path:**

   ```bash
   python3 "$CLAUDE_PLUGIN_ROOT/scripts/annotate.py" \
     --input "$TMP" --spec "$TMPDIR_C/spec.json" --output "$FINAL"
   ```

   If stderr contains `warn: unknown op type`, the spec was wrong — fix it and rerun rather than reporting success.

6. **On success only**, `rm -rf "$TMPDIR_C"`. On failure, keep it — see *When things fail*.

7. **Report the final path, and look at the result.** Read the annotated image back and confirm the markers landed where intended. This is cheap and catches the `[x,y,w,h]` mistake, which otherwise ships a box in the wrong place.

## Determining coordinates

Prefer, in this order:

**1. Look at the image.** Read the capture and identify the target visually. "Box the login button" is fully answerable from the pixels — find the button, take its bounding box, convert to `[x, y, w, h]`. This is what makes the skill one-shot, and it should be the default path.

**2. Translate relative descriptors.** `center`, `top-left`, `bottom-right` and similar map to pixels once the image dimensions are known. Read dimensions from the capture rather than assuming the display resolution — region captures and HiDPI scaling both break that assumption.

**3. Use coordinates the user gave**, sanity-checked against the image bounds. Coordinates outside the captured area usually mean the user read screen coordinates rather than image coordinates. Say so rather than silently drawing off-image.

**4. Ask.** Only when visual identification is genuinely ambiguous — several plausible targets, or the user named something not visible in the capture. Report the image dimensions when asking, so the user has a frame of reference.

Never guess silently. If more than one candidate was plausible, say which one you marked.

## Output paths

If the user gives a path, use it. Otherwise default to `~/Pictures/Screenshots/<ISO-timestamp>-annotated.png`, matching `screenshot.sh`'s own default directory.

Because the capture is a temp file, deleting it after annotation loses nothing the user asked for. **If the user wants the unannotated capture kept too, don't use this skill** — run `screenshot` to a real path, then `annotate` against it. That path honours the plugin's originals-clean rule, writing to a sibling `annotated/` directory and leaving the capture untouched. This skill trades that guarantee for speed.

## When things fail

- **Exit 2 from the capture** — the user cancelled. Clean up, report, stop.
- **Exit 1 from the capture** — usually `window` on a non-spectacle backend, or no backend installed. Name the likely cause and suggest `region` or running the `install-deps` skill.
- **Annotation failed** — keep the temp directory and report its path, so the user can retry annotation alone. Re-capturing is destructive: transient UI state (a hover, an open menu, a toast) may be gone.
- **`warn: unknown op type` on stderr** — treat as a failure even though the exit code is 0.

## Examples

**"Screenshot the active window and circle the Save button"**
Check the backend supports `window` → capture → read the image, locate Save, take its bounding box → one `box` op in `[x,y,w,h]` form → annotate → report, noting that it's a box rather than a circle.

**"Grab a region and put a 1 and 2 on the two error rows"**
Capture in `region` mode → check exit code (the user may have hit Escape) → read the image, locate both rows → two `marker` ops → annotate → report which row got which number.

**"Screenshot this and label the top-right corner 'v2.1'"**
Capture → read dimensions → translate `top-right` to pixels with a sensible inset → one `text` op → annotate → report.
