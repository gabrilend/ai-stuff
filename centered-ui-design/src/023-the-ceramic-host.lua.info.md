<!-- written by Claude (Opus 5.5), 2026-10-10: what this file offers to other files. Read this instead of the source unless chasing a bug. -->
# 023-the-ceramic-host.lua

The FFI binding to the ceramic library (built by scripts/build-ceramics into tmp/tmp/ceramic/).

| Offers | Takes | Gives |
|---|---|---|
| `load(project_dir)` | | the library; an error naming the build script if it is not built |
| `start(library, world)` | fold, figure_scale, sections, workers, unit_count, cuboid_count, seed | a host |
| `advance(host, step_seconds_waiting, set_world)` | | finished (a step has wholly landed: swap the blocks), began (a step went in); `host.just_handed_in` for the cuboid stage. Never waits. |
| `stop(host)` | | lets a stage in flight land, then stops |

`set_size_keep(host, keep)`: asks for a size law (0 shrink far out, 1 full size); it reaches the engine at the start of the next step. `start` also hands the engine the size law and the foes' pole from the fold.

A step is now three stages: units, cuboids, then the moving sheen-points. `set_sun(host, x, y, z)`: the sun for the water, taken at the start of the next step. `start` takes `sheen_count` in its world.
