# 074-the-drawn-body

Where a body is drawn when the picture is allowed weight: a second, softer position that chases the real one and that only the screen reads.

Read this file rather than the source. The source is for when one specific
function is misbehaving; this is for everything else.

## What it is for

Issue 709's second step. The honest picture draws a body a fraction of the way between
the two most recent frames, which has no state of its own, so a body that turns on
screen turns instantly. This gives every body a drawn place and a velocity, pulled
toward the honest position by a spring that is slightly too lively to settle at once:
it leans into a turn, runs a little past a stop, and comes back.

**It is off by default**, on the `i` key, because how lively the spring is was found by
arithmetic and not by looking (709, R2). The honest picture is the one to fall back to.

**Nothing but the screen reads it.** It is handed snapshots and writes only into its own
arrays. Every measurement, test and replay keeps reading where bodies really are.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `create(capacity, personal_space)` | | A drawn record: flat `x`, `y`, `vx`, `vy` and `followed` arrays, one slot per body. |
| `follow(drawn, id, target_x, target_y, seconds)` | | — Pulls one drawn body toward a target, then holds it within the lag limit. |
| `update(drawn, previous, newest, honest_x, honest_y, seconds, walking_pace)` | | — One frame for every live body: snap the ones that were placed, follow the rest. |
| `FREQUENCY`, `DAMPING`, `LAG_LIMIT` | *(numbers)* | The spring's swings per second, its damping ratio, and the lag limit as a fraction of personal space. |

The viewer calls `update` every frame whichever picture is showing, so that switching
to the weighted one starts from bodies already in motion rather than from every body
snapping at once.

## The rules

| Rule | Why |
| --- | --- |
| The spring is solved exactly over each frame, not stepped | A stepped spring swings differently at different frame rates; the target stands still for a frame, and a damped spring toward a fixed point has a closed-form answer. |
| The drawn body chases the **honest** position, not the raw frames | It then chases something that already moves smoothly, so the spring adds weight rather than smoothing ticks. |
| Never further than half a personal space from the honest position | A neighbour can stand one personal space away; a drawn body further off than half of that could appear beyond somebody it never passed. Held at the edge rather than snapped, with the outward velocity dropped. |
| Snaps when the body was not alive last frame, or was not followed last frame | Just born, or its slot was reused: it should not slide in from its previous occupant. |
| Snaps when the body moved further than one personal space in one tick | Nothing walks that far in a tick (the fastest gait covers under two paces), so it was put there: a spawn, a hero bought onto a tower, a guard placed by its post. This is 709's R3. |
| Snaps above walking pace | A frame then spans many ticks and the honest picture is already drawn unblended; weight across ticks that were never adjacent would be invented motion. |
| A damping of 0 or of 1 or more refuses to load | That is a spring that does not swing, or does not settle — a different spring, not a setting. |

## The numbers, and what they come to

Three swings a second at half the damping that would stop it dead. Drawn at sixty
frames a second, a body of speed 1.2 marching is trailed by about 1.6 paces and one
hurrying by about 2.2; a stop is overrun by 0.6 and 0.8 paces respectively, and the body
settles within two-thirds of a second. With the viewer driven headless through a match
and LÖVE stubbed out, the weighted position was never more than about four paces from
the honest one, well inside the nine the lag limit allows.
