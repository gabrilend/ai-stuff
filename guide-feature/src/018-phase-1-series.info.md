# 018-phase-1-series — info

The scripted series the phase 1 demo plays (issue 108): six rounds of three
voices editing one 40x6 canvas. Each round is listed as short edits (`put`
text at a place, `erase` cells) made on a base version. `arrivals` turns a
round into the canvases the voices would send: whole from-voice canvases
(102), named `<sender>-<unix time>-<random>` (302), with times that rise
through the series.

    local series = dofile(DIR .. "/src/018-phase-1-series.lua")
    series.arrivals(round, versions, latest)   -- { name, text, rows, base, ... }
    series.ROUNDS, series.SETTINGS, series.WIDTH, series.HEIGHT

A base is `"latest"` (the newest version when the round starts) or a
version's number. The bases' rows come from the caller (the demo reads them
from the blitter's log), so the series never predicts what the blitter will
do.

The rounds, in order:
1. A voice writes three sentences onto the empty canvas.
2. Two single-word edits on the same version: a word replaced, and a word
   erased. The second lands on a canvas newer than its base.
3. `kitten` over `cat` cuts `sat`, which is blanked whole. Another voice on
   the same base erased `sat`, which is a conflict.
4. A voice still on version 2 writes `dog` over `cat`. `dog` cuts `kitten`,
   and the `sat` its old copy still had is not brought back.
5. An oversized canvas, which is refused.
6. A turn that changes nothing, then a last new line.
