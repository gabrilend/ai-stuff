# 404 — Cats See Faces In The Field

| | |
| --- | --- |
| Phase | 4 — Seeing it |
| Blocked by | 402, 102 |
| Blocks | 405, 406 |
| Files | `src/025-the-scenery.lua` |
| Reads | `docs/art-direction.md` |

## Current behavior

Built in `src/025-the-scenery.lua`: ground and darker margin, stones,
grass, puddles, fences, clouds with ears, and stone cat faces (eyes with
pupils, a pink nose, grass whiskers), placed outside the deployment rows.
Tested in tests/034-seeing-it.lua; seen in every screenshot.

## Intended behavior

The scenery for a battle is built once from the battle's seed (`scenery`
stream) and its region kind: a ground plane in the region's colour, with a
darker margin past the field's edges; scattered stones, grass tufts, puddles
(swamp park), fences (prairie); a sky colour gradient; and **cat faces**:

- stone clusters: two eye stones, a smaller nose stone below between them,
  and grass-tuft whiskers either side;
- clouds with two ear bumps, drifting slowly;
- shield rivets in a cat-face arrangement (drawn by the figures, 403).

The scenery is a list of (shape, matrix, colour, look) like a figure, built
once, drawn every frame. It carries no gameplay.

## Suggested implementation steps

1. Write the builder; place cat-face clusters at a configured count, outside
   the formations' starting cells.
2. Test: the same seed builds the same scenery; every cluster has its five
   parts.
