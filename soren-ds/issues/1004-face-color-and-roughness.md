# 1004 — Face color and roughness

## Current behavior

Faces exist (1003) but they're untextured — rendered only as
edge outlines. The modeller doc calls for color and roughness
chosen through the radial menu.

## Intended behavior

A face's appearance is two values: a color (from a fixed
palette of 64 colors at launch) and a roughness (a normalised
0.0–1.0 scalar describing how matte or shiny the face is).

Selection flow:

1. The user moves the cursor to a placed vertex that belongs to
   the face they want to edit. Pressing `Y` (the "commit face"
   button from 1003 with no pending face active) cycles through
   the faces this vertex belongs to, highlighting one at a time.
2. With a face highlighted, the user opens the drawer. The
   drawer's radial menu (506) is configured for face
   properties: directions correspond to color categories,
   face buttons pick the specific color within the category.
3. A second mode on the radial menu — entered with the L
   trigger held — switches the picks to roughness selection.
4. The selected value applies immediately. The face's render
   updates next frame.

Vertices themselves have no color or roughness — they have no
surface to paint. The user editing properties always operates
through a face.

The color palette is the same 64-color palette the paint
program uses by default (extended from paint's 16 by adding
finer gradients between adjacent colors).

## Suggested implementation steps

1. The 64-color palette table.
2. `face_set_color(face, color_index)`.
3. `face_set_roughness(face, roughness_float)`.
4. The drawer content sub-map for face editing — uses the
   radial-menu chord box (506) with a custom lookup table.
5. The L-trigger mode switch between color and roughness.

## Related documents

- `docs/010-modeller.md`.
- `docs/004-input-model.md`.

## Blocked by

506, 608, 1003.

## Blocks

1005.
