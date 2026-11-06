# 503 — The Command Table

| | |
| --- | --- |
| Phase | 5 — Command and the round |
| Blocked by | 407, 502, 504 |
| Blocks | 601 |
| Files | `src/028-command-screen.lua` |

## Current behavior

Built in `src/028-command-screen.lua`, with the result banner drawn over
the field at the end of a round. Checked by scripted screenshot
(development-history/009).

## Intended behavior

Between rounds, the screen is a table seen from above: the campaign map of
regions in clay and brick (each region's ground colour, each side's owned
regions edged in its brick colour, the two homes marked with a banner), the
current front marked, and eight compass arrows around it, the illegal ones
(off the map) greyed.

Below the map: three perk cards drawn from the perk catalogue (the `perks`
stream, never offering a perk already taken more times than it allows). One
is picked by clicking. If the chosen perk affects a number of soldiers and
units of that kind are ready, the table asks "be one of them?" — Y or N.

Return begins the round. The command screen is the one screen with words on
it, because it is a table of choices, not the battlefield.

## Suggested implementation steps

1. Draw in 2D; hit-test the arrows and cards with plain rectangles and
   circles.
2. Check by scripted clicks and a screenshot.
