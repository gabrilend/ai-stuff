# 304 — Tiles before both eyes

**Phase:** 3 — The panel on its arm
**Blocked by:** 301, 302
**Related documents:** notes/vision (seventh round), docs/physics-check.md
(seventh round), input/descriptions/glasses.txt

## Current Behavior
The panel is one curved screen on one arm (301, 302). The glasses exist as
a described model with two whole rectangular lenses.

## Intended Behavior
The owner, seventh round: each spectacle lens is split into small
rectangles of one size, each the same shape as the lens (an N by N grid
keeps the lens's width-to-height ratio exactly). Each tile hangs from an
arm that branches from above (above is preferred, to keep the face clear;
below allowed), like a tree: one arm from the frame splits into sub-arms,
each sub-arm splitting again, until every tile has its own. The internal
laser etches each tile's light-activated (e-ink style) surface. The wearer
adds and removes tiles one at a time, on both eyes, and the two eyes always
hold the same element at the same angle and position, so the two pictures
fuse into one seen far away — red-dot-sight style, through ordinary
glasses. "nobody wants to wear binoculars on their face"

As a model: the glasses description extended with the grid of tiles and
the branching arms, built by ./describe, viewed in the viewer.

## Suggested Implementation Steps
1. Settle the open questions below (the first decides what a tile is).
2. The describing language gains what this needs: a grid ("split into 4 by
   4 tiles") and a place between two parts ("between", for an arm joining
   two sub-arms) — an extension of issue 007's vocabulary, with its tests.
3. A tool that writes the tiled glasses' description for a given grid and
   branching depth (descriptions of 16+ tiles and their arms are made by a
   tool, not by hand), then ./describe and the viewer.
4. Tile on/off per eye as data: { eye ("left"/"right"), row, column (whole
   numbers), present (boolean) }, both eyes kept equal by construction.

## Open questions
1. **What a tile is, given focus.** A flat etched tile 1–3 cm from the eye
   is inside the eye's near point (about 25 cm for most adults) and reads as
   a blur. A red-dot sight avoids this with a slightly curved partial
   mirror that sends the picture back as if from infinity — a mirror, not a
   lens, so it fits the design. Should each tile be a small curved partial
   mirror lit by the laser, rather than a flat e-ink surface to look at?
2. **How many tiles:** 2 by 2, 3 by 3, 4 by 4 per lens?
3. **Branching from above only**, or above and below?
