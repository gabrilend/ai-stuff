<!-- made by scripts/file-screenshot on 2026-10-10 22:34, from the
     game run as: run /mnt/mtwo/programming/ai-stuff/centered-ui-design --drag 24 1300 990 400 990 0.8 --click 27 280 968 --screenshot 27.3 -->

# 050 — hot-seat-spun-to-seat-two-and-pressed

- **Picture:** 050-hot-seat-spun-to-seat-two-and-pressed.png
- **Commit:** 0851eb669 2026-10-10 centered-ui-design: painted terrain for judging distance, and runs the person cannot nudge
- **Run:** `run --drag 24 1300 990 400 990 0.8 --click 27 280 968 --screenshot 27.3` (from /mnt/mtwo/programming/ai-stuff/centered-ui-design)
- **Uncommitted at the time:**
  -  M src/014-the-dashboard.lua
  -  M src/016-the-game.lua

## What changed

Compared with picture 049:
- commit: 6ecd6e142 -> 0851eb669
- changed: src/014-the-dashboard.lua
- changed: src/016-the-game.lua


## What it shows

Spun to seat 2 by a scripted drag, then seat 2's ADVANCE pressed with no
one named: seat 2's arch is in front and its named slot answers NAME
SOMEONE FIRST — the arch in front plays its seat. Seat 2's cyan section in
the middle, splotch terrain around it.

## The story so far

The painted splotches (042-049) turned out to be the first step of how
the owner wants terrain drawn: not a mesh of triangles and not a ground
texture, but "a completely empty canvas with invisible points", each point
carrying a height and a facing, drawn as a round sprite facing the camera
with one side bright and one dark, turned with the sun — "in the morning
one side of the "Warcraft The Barrens" style cliff is lit, and then as the
sun traverses the other side is bright". This cycle builds that: a land of
points with seeded mesas, one round relief picture for every sprite, nearer
sprites covering farther ones and hills hiding what is behind. The owner
also answered that an ally's arch spun to the front plays that seat
(hot-seat), now built (050). Still open: whether the mesas should become
part of the world that villagers walk, and the earlier questions.
