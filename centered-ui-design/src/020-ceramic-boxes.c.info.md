<!-- written by Claude (Opus 5.5), 2026-10-10: what this file offers to other files. Read this instead of the source unless chasing a bug. -->
# 020-ceramic-boxes.c

The world's work as ceramic boxes (C), run by soramech's engine on its worker threads. Each box takes a chunk and writes only that chunk's own records, so chunks run in any order with the same result.

| Box | Takes | Gives | Does |
|---|---|---|---|
| `unit_chunk` | `chunk_req {chunk, first, last}` (ints) | `chunk_done {chunk, count}` | each unit thinks (wander; fetch the nearest free cuboid; carry it to its color's section; set it down) and moves (the twin of 006) |
| `cuboid_chunk` | the same | the same | each cuboid: claimed by the lowest-numbered unit fetching it; carried in front of its carrier; stacked in its section when set down; reappears elsewhere after resting |

World by pointer (set by the host, 022): `ceramics_units_front/back`, `ceramics_cubes_front/back`, counts, step seconds, seed, the fold, the figure scale, the sections. Records: `unit_record` (16 floats) and `cuboid_record` (12 floats), matching 005. Tuning knobs at the top (walk pace, reach, resting time).

Haulers walk on the sphere (issue 214): steering splits the way to a target into outward tiers and sideways sphere distance (the lap radius at the walker's tier times the angle), and walks it at a steady pace in tiers per second; reach and arriving in a section are measured in tiers. So the walk is the same under every view, and on the map far walkers cross sideways fast and outward densely. Sizes on the map (carried and stacked cuboids) follow the size law.
