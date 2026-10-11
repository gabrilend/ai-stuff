<!-- written by Claude (Opus 5.5), 2026-10-10: what this file offers to other files. Read this instead of the source unless chasing a bug. -->
# 022-the-ceramic-host.c

The render thread's calls into the engine. Compiled only appended to serac's emitted construction code (in place of its main), so it sees the boxes' types; an editor opening it alone will report unknown types.

| Call | Does |
|---|---|
| `ceramics_set_fold(strength, tiers, hub, edge, figure)` | the fold and figure scale the boxes use |
| `ceramics_set_size_keep(keep)` | the size law: 0 far things shrink, 1 full size (the slant view); set only between steps |
| `ceramics_set_far_pole(tiers)` | where the foes' pole is, in tiers from ours; haulers walk on that sphere |
| `ceramics_side_radius(r)` | the lap radius on the sphere at tier distance r (for the tests) |
| `ceramics_set_section(index, r, angle, radius)` | one color-coded section (0..7) |
| `ceramics_start(workers, units, cubes, seed)` | builds the map, starts the workers, prepares one batch of chunk requests per stage (chunks of 32); 0 or -1 |
| `ceramics_set_world(units_front, units_back, cubes_front, cubes_back)` | where the blocks are this step |
| `ceramics_hand_in(stage, step_seconds)` | hands a stage's chunks in as one batch; returns how many, or -1 |
| `ceramics_landed(stage)`, `ceramics_chunks(stage)` | how many have landed; how many there are (never waits) |
| `ceramics_stop()` | stops the workers |
| `ceramics_error()` | why the last call refused |
| `ceramics_run_inline(stage, dt, reversed)`, `ceramics_set_counts(...)`, `ceramics_move_reference(...)` | for tests: a stage on the calling thread, in order or reversed; the C motion alone |
