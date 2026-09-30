# Issue 515: Threaded Demo Crashes on Its First Frame

**Phase:** 5
**Type:** Implementation
**Priority:** High
**Dependencies:** 513 (threading architecture demo)

---

## Current Behavior

`src/render/run` (the phase 5 demo) builds, loads a map through Lua, opens
its window, and then crashes with a segmentation fault on the first frame:

```
Thread 1 "threaded_demo" received signal SIGSEGV
render_chunks_parallel (mesh=...) at main.c:573
    Color col = { COLOR_PALETTE[ci][0], ...
```

`create_cube_mesh(2.0f, 0.2f)` meant to cut the cube into 10 x 10 x 10 =
1000 chunks, but it stepped through each axis by adding 0.2 to a float.
The sum reaches 0.99999994 instead of 1.0, which is still below the edge,
so every axis took an eleventh step: 11^3 = 1331 chunks, the last layer a
sliver sticking out past the cube's faces. `g_chunk_states` holds
`MAX_CHUNKS` = 1024 entries. `render_chunks_parallel` (bounded only by
`MAX_CHUNK_TASKS` = 2048) and `find_chunk_at_ray` (not bounded) read
entries 1024-1330 past its end, took a garbage `color_index`, and indexed
`COLOR_PALETTE` with it.

Whether it crashed depended on what memory lay past the array, so it could
run on one machine and crash on another. Seen on Ubuntu 24.04, gcc 13,
raylib 5.5.

## Intended Behavior

The cube has exactly 1000 chunks, its solid shell is one chunk thick on
every side, and no loop reads `g_chunk_states` past its end.

## Suggested Implementation Steps

1. Count chunks per axis with an integer (`lroundf(size / chunk)`), and
   place each chunk at `-half + index * chunk`
2. Decide "surface" by index (first or last on any axis), not by comparing
   floats
3. Bound the two unbounded `g_chunk_states` reads by `MAX_CHUNKS`

## Acceptance Criteria

- [x] Log reads "Created mesh with 1000 chunks"
- [x] The demo runs without crashing (30 s under Xvfb)
- [x] The HUD reads 488/1000 solid chunks: the one-thick shell of a
      10-cube (1000 - 8^3)
- [x] Builds with `-Wall` without warnings

## Implementation Notes

**Date:** 2026-09-29

Changed `src/render/main.c`: `create_cube_mesh` counts and places chunks
by integer index, the surface test uses indices, and
`render_chunks_parallel` and `find_chunk_at_ray` stop at `MAX_CHUNKS`.

The float comparisons had also made the shell uneven: two layers thick on
the low side of each axis (-0.8 compared equal to `-half + chunk`) and only
the protruding sliver on the high side. The shell is now one layer on
every side.

Checked by building against raylib 5.5, running under Xvfb for 30 seconds
and taking screenshots: the map terrain (DAoW 5.4b), the four Lua
entities, the chunked cube and the HUD all draw. Before the change the
same build crashed on the first frame every run.
