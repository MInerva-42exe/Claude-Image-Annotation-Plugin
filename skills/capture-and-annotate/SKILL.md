---
name: capture-and-annotate
description: One-shot orchestrator — take a screenshot and immediately apply annotations. Combines the screenshot and annotate skills for the common "grab this region and draw an arrow at it" workflow.
---

# Capture and Annotate

Compose `screenshot` + `annotate` into one step. Use when the user says things like "screenshot this and circle X", "grab the active window and add a numbered marker at 200,300", or "capture a region and label it 'Step 1'".

## Inputs

- `screenshot_mode`: passed through to the `screenshot` skill (`full`, `region`, `window`, `delay:N`)
- `output`: final annotated image path. Default: `~/Pictures/Screenshots/<ISO-timestamp>-annotated.png`.
- `operations`: same shape as the `annotate` skill's `operations` list.

## Flow

1. Invoke the `screenshot` skill with `mode = screenshot_mode`. Save to a temp path: `/tmp/cap-<random>.png`.
2. Verify the temp file exists and is non-empty. If not (e.g. region selection cancelled), stop and report — do not produce an empty annotated file.
3. Invoke the `annotate` skill with `input = temp path`, `output = final path`, and the user-supplied operations.
4. Delete the temp file.
5. Report the final path and a summary of what was captured and annotated.

## Why orchestrate rather than call each skill manually

The user's coordinates for annotations are in the captured image's coordinate space, not the screen's. Doing this in one step makes that obvious — the user can say "draw an arrow at 400,300 in the screenshot" and the orchestrator wires it through correctly.

## Edge cases

- If the screenshot mode is `region`, the user picks the region interactively, so they cannot know exact pixel coordinates in advance. In that case, either:
  - Capture first, report the resulting image dimensions, and ask the user for coordinates before annotating, or
  - Accept relative descriptors like `center`, `top-left`, `bottom-right` in `operations` and translate to pixels after capture (centre → `w/2, h/2`, etc.).
- Keep the temp file on annotation failure so the capture isn't lost. Report the temp path so the user can retry the annotate step manually.
