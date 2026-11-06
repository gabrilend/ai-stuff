<!-- made by scripts/build-info-pages from the comments in 028-command-screen.lua; change the comments and rebuild, not this page -->
# 028-command-screen


The table between rounds, seen from above: the campaign map of regions in
clay and brick colours, each side's regions edged in its colour, the two
homes bannered, the front marked, and eight compass arrows around the
front (the ones leading off the map greyed). Below it, the perk cards.
If the chosen perk converts soldiers, the table asks whether the player is
to be one of them.

This is the one screen with words on it, because it is a table of choices
and not the battlefield. Everything is drawn in 2D; clicks are tested
against the same rectangles and circles the drawing used, kept in a list
of hit areas rebuilt every frame.

## Functions other files call

| Name | Takes | What it does |
| --- | --- | --- |
| `M.layout` | `w, h, map` | (no comment in the source) |
| `M.draw` | `match, w, h, fonts` | Returns the hit areas, which the front desk keeps for the next click. |
| `M.draw_result` | `match, w, h, fonts` | The banner over the battlefield at the end of a round. |
| `M.hit` | `hits, x, y` | The hit area under a point, or false. |

## Tables of rows

| Name | What it is |
| --- | --- |
| `PAPER` | (no comment in the source) |
| `INK` | (no comment in the source) |
| `DIM` | (no comment in the source) |

## Private helpers

| Name | Takes | What it does |
| --- | --- | --- |
| `region_rect` | `l, col, row` | (no comment in the source) |
| `draw_map` | `match, l, catalogue, team_colors, fonts` | (no comment in the source) |
| `draw_arrows` | `match, l, hits` | The compass around the front; each arrow is a hit area. |
| `draw_cards` | `match, w, h, hits, fonts` | (no comment in the source) |
