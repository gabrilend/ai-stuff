<!-- made by scripts/file-screenshot on 2026-10-10 22:37, from the
     game run as: run /mnt/mtwo/programming/ai-stuff/centered-ui-design --screenshot 18.5 -->

# 051 — lit-dots-in-the-morning

- **Picture:** 051-lit-dots-in-the-morning.png
- **Commit:** d4e5af531 2026-10-10 centered-ui-design: painted terrain for judging distance, and runs the person cannot nudge
- **Run:** `run --screenshot 18.5` (from /mnt/mtwo/programming/ai-stuff/centered-ui-design)
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

Compared with picture 050:
- changed: input/game-settings.lua
- changed: src/001-read-the-input.lua
- changed: src/007-seeding-the-units.lua
- changed: src/012-made-by-formula.lua
- changed: src/013-the-world-renderer.lua
- changed: src/014-the-dashboard.lua
- changed: src/016-the-game.lua
- changed: src/017-the-tests.test.lua
- changed: src/026-the-terrain.lua

Settings, before (<) and now (>):

```
<     -- painted terrain: how many splotches of earthy colour lie on the
<     -- ground, to see how the world reads at different distances (0: none)
<     terrain_splotch_count = 1500,
>     -- the land: "dots", its points drawn as round sprites lit by the sun on
>     -- an otherwise empty ground; or "map", the flat painted map (tier rings,
>     -- quadrants, sections). Switched in the settings menu too.
>     view_ground = "dots",
```

## What it shows

The land as lit dots at dawn (the sun on the horizon): the ground is
thousands of small round sprites, almost all in shadow, near black; only
the mesas' cliffs facing the rising sun glow orange in two arcs. Villagers
and cuboids stand on top, dimly lit.

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
