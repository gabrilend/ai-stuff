<!-- made by scripts/file-screenshot on 2026-10-10 23:27, from the
     game run as: run /mnt/mtwo/programming/ai-stuff/centered-ui-design --drag 22 400 990 1300 990 0.5 --wheel-with 23 a -3 --screenshot 25.0 -->

# 073 — lake-with-stronger-waves-half-a-second-later

- **Picture:** 073-lake-with-stronger-waves-half-a-second-later.png
- **Commit:** a6d830dee 2026-10-10 centered-ui-design: terrain circles shaded round their centres, from the owner's drawing
- **Run:** `run --drag 22 400 990 1300 990 0.5 --wheel-with 23 a -3 --screenshot 25.0` (from /mnt/mtwo/programming/ai-stuff/centered-ui-design)
- **Uncommitted at the time:**
  -  M src/005-unit-records.lua
  -  M src/013-the-world-renderer.lua
  -  M src/016-the-game.lua
  -  M src/017-the-tests.test.lua
  -  M src/020-ceramic-boxes.c
  -  M src/021-ceramics.map
  -  M src/022-the-ceramic-host.c
  -  M src/023-the-ceramic-host.lua
  -  M src/026-the-terrain.lua

## What changed

Compared with picture 072:
- no source or settings file changed (same program, different run or moment)


## What it shows

Half a second later: the deep-blue patches have moved across the lake —
the engine turning each water point by the passing waves.

## The story so far

After the circles took the owner's drawing (067-069), the owner named
them sheen-points (and bloxels for cubes), said each should record its own
sun-side and shade-side colour ("it's arbitrary, but should be recorded per
circle"), and that moving surfaces belong in the engine's shared memory,
where "we adjust the rotation to display a certain color". This cycle
gives every sheen-point two colours and adds a lake whose points the
ceramic engine turns each step by passing waves and the sun, in a third
stage beside the units and cuboids. The first waves were too gentle to see
(070-071); stronger ones show as dark ripples moving across (072-073).
