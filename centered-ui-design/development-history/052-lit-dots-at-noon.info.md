<!-- made by scripts/file-screenshot on 2026-10-10 22:37, from the
     game run as: run /mnt/mtwo/programming/ai-stuff/centered-ui-design --screenshot 24.5 -->

# 052 — lit-dots-at-noon

- **Picture:** 052-lit-dots-at-noon.png
- **Commit:** 0851eb669 2026-10-10 centered-ui-design: painted terrain for judging distance, and runs the person cannot nudge
- **Run:** `run --screenshot 24.5` (from /mnt/mtwo/programming/ai-stuff/centered-ui-design)
- **Uncommitted at the time:**
  -  M input/game-settings.lua
  -  M src/001-read-the-input.lua
  -  M src/007-seeding-the-units.lua
  -  M src/012-made-by-formula.lua
  -  M src/013-the-world-renderer.lua
  -  M src/014-the-dashboard.lua
  -  M src/016-the-game.lua
  -  M src/017-the-tests.test.lua
  - ?? src/026-the-terrain.lua

## What changed

Compared with picture 051:
- no source or settings file changed (same program, different run or moment)


## What it shows

Noon: the whole land lit, a dense field of round sprites in meadow green
and sand, each bright on its upper side; three mesas stand out as raised
plateaus of ochre sprites ringed by dark clay cliffs on their near sides —
the hills hide the ground behind them. Villagers carry cuboids across the
lowland; seat 1's stacked cuboids sit near the middle (the painted section
is gone with the painted map).

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
