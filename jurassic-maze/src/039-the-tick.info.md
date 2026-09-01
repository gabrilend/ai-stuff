# 039-the-tick

A fixed sixtieth of a second, and the table of passes it walks. Also where a
world is assembled.

Read this page rather than the source, and read
[the tick](../docs/010-the-tick.md) before either.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `new_world(root, params, scene)` | | the maze, the streams, the bodies, the rows and the report, assembled once |
| `tick(world, measure)` | optional timing table | one whole step |
| `advance(world, elapsed, measure)` | real seconds | spends them in whole ticks; returns how many ran |
| `spawn_one(world, kind_index)` | | one body, somewhere it can stand, or nil |
| `populate(world)` | | brings the aquarium up to its target |
| `TICK`, `MAX_CATCHUP`, `PASSES` | | |

## The world

| Field | What it is |
| --- | --- |
| `store` | the stone |
| `bodies` | the flat arrays |
| `streams` | the named generators |
| `rows` | the locomotion dispatch table |
| `creatures` | the creature table, this world's own copy |
| `report`, `counters` | what the run produced |
| `floor`, `by_height`, `highest` | where a body may be put down, collected once |
| `floor_blocks`, `block_size`, `blocks_x`, `blocks_y` | floor cells bucketed into coarse blocks, so "somewhere near here" is a draw rather than a search |
| `meet` | what any two creature kinds do when they meet |
| `paths`, `path_length`, `path_at`, `errand_cell`, `errand_layer`, `replanned`, `arrived` | one stored path per body, and where along it. Beside the store rather than in it, because a path is a list and the store is flat arrays. |
| `modules` | the loaded modules, so passes do not reload them |
| `targets` | how many of each kind to keep alive |

`floor` and `by_height` exist because the spawn pass would otherwise pick random
cells and reject the ones that are wall — and on a maze that is sixty percent
stone, that is most of them.

## The passes

`move`, `meet`, `spawn`, `index`. An array of `{name, fn, parallel}` rows walked
in order, not a function with four calls in it.

`meet` is the only one with `parallel` false, and it is also one of the cheapest.
That is by design rather than by luck: a pass that has to touch shared state was
kept small precisely so that it could be the one that does not scale.

Three things fall out, and the third is the reason: adding a pass is adding a
row; timing every pass is a loop around the walk rather than pieces of timing
code; and **a pass can be removed without editing the tick** — the ball phase
does not need `meet` or `resolve`, and leaving them out is removing rows rather
than threading a flag through a function.

`parallel` is stated rather than inferred. Inferring it means being silently
wrong about it once, at which point the simulation stops being deterministic and
nobody knows when it started.

## The timestep is fixed and the engine's is not

One tick is one sixtieth of a second of simulated time, always. `advance`
accumulates the engine's real elapsed time and spends it in whole ticks; that is
the only place the two meet.

A variable timestep makes a ball that clears a gap at sixty frames a second fall
into it at thirty, and every seed in every bug report then means something
different on every machine.

`MAX_CATCHUP` caps the accumulator. If the window was dragged for two seconds the
loop does not try to run a hundred and twenty ticks in one frame — it discards
the excess and the simulation is simply behind. Trying to catch up is the spiral
of death: the catch-up takes longer than real time, which produces more to catch
up on.

## Spawning

Balls are drawn toward the top of the maze, because a ball that begins at the
bottom has nowhere to roll and the descent is the whole point. Walkers are drawn
from anywhere, so a crowd is spread rather than all arriving in one corner.

A spawn that would land on top of somebody is retried a few times and then
**skipped and counted**. The population recovers next tick, and a maze whose
spawn points are all blocked should arrive as a number rather than as an aquarium
that slowly empties.

Top-ups are capped at a few per tick, so a mass removal does not produce a mass
arrival in the same frame — which looks like the maze blinking.
