# Balance Updates

Append-only. Every time a number is turned, it gets a line here saying what it
was, what it became, and why. Nothing is ever edited out of this file — a wrong
change that was later reverted is more informative than a file that shows only
the changes that stuck.

This is not for features. A feature gets an issue file. This is for knobs.

---

## The first values

Every number below was chosen before anything ran, which means every one of them
is a guess. They are recorded here so that the first time somebody tunes one,
there is something to compare against.

### Maze parameters

| Knob | Value | Why this and not something else |
| --- | --- | --- |
| `width`, `depth` | 129 | Odd, so the room lattice at odd coordinates fits exactly with a wall rim on all four sides. 129 is 2×64+1. |
| `layers` | 12 | The reference picture has roughly eight terraces; twelve leaves room for staircases between them without hitting the 32-layer ceiling. |
| `terrace_count` | 40 | Enough piled slabs that the landscape is not obviously rectangles. |
| `terrace_size` | 8 to 40 cells | The small end is a plinth, the large end is most of a quadrant. |
| `terrace_rise` | 2 layers | One slab lifts a region by exactly the height of a wall, so a slab edge is a wall. |
| `centre_bias` | 0.6 | Slabs cluster toward the middle, so the thing is taller in the centre like the picture. Zero would be uniform. |
| `wall_rise` | 2 layers | One layer above the climb limit. The cheapest a wall can be while still being a wall. |
| `climb_limit` | 1 layer | Not a knob. `wall_rise` was chosen against it. |
| `braid` | 0.15 | Fifteen percent of closed links reopened. A perfect maze has no loops and a chase on it has a known ending. |
| `stair_attempts` | 200 | Generous. Running out is an error, not a fallback. |

### The ball

| Knob | Value | Why |
| --- | --- | --- |
| `gravity` | 22 cells per second squared | Tuned so a ball takes about a second to cross a wide terrace under slope. Not real gravity; cells are not metres. |
| `roll_friction` | 1.4 per second | A ball on flat ground stops in a couple of seconds rather than drifting forever. |
| `restitution` | 0.35 | Stone, not rubber. |
| `bounce_floor` | 0.6 cells per second | Below this a bounce is set to zero. Without it a ball performs several hundred invisible bounces a second forever. |
| `radius` | 0.34 cells | Comfortably under half a cell, so a ball fits down a one-cell corridor with clearance on both sides. |
| `max_speed` | 9 cells per second | One tick at this speed moves 0.15 cells, well under the radius. This is what stops a ball tunnelling through a wall, and it is the reason the timestep is fixed. |
| `rest_seconds` | 4 | How long a ball sits still before the aquarium takes it away and drops a new one in at the top. |

### The little guy

| Knob | Value | Why |
| --- | --- | --- |
| `step_seconds` | 0.42 | One cell per step. Slow enough to read as walking rather than sliding. |
| `reverse_weight` | 0.15 | An unweighted random walk goes back and forth across two cells and looks broken. This makes turning around unlikely but never impossible — a body in a dead end must be able to. |
| `drop_limit` | 2 layers | It may go down further than it can come up, which is what lets a maze have pits in it. |
| `search_budget` | 4000 surfaces | An abandoned search is counted in the report, never silently swallowed. |
| `notice_seconds` | 1.5 | How long two bodies must both be idle before they might idle together. |

### The camera

| Knob | Value | Why |
| --- | --- | --- |
| `dwell_seconds` | 8, adjustable 1 to 60 | A stakeout long enough that something wanders through. The slider was asked for by name. |
| `boredom_seconds` | 12 | After this, a subject that has done nothing stops being the subject. |
| `ease` | 0.12 per tick | How fast the pan catches up to a followed body. Snapping is unwatchable; too slow and the subject leaves the frame. |

---

## Turning the terraces into a mound that reads as one

Everything above was guessed before anything ran. This is the first pass of
turning them against what actually came out on screen.

### Scattered rectangles → nested slabs

| Knob | Was | Now |
| --- | --- | --- |
| `terrace_count` | 40 | 7 |
| `terrace_size` | 8 to 40, one range | replaced by `terrace_max` 122 and `terrace_min` 16 |
| `centre_bias` | 0.6 | removed; `terrace_wander` 0.22 replaces it |
| `outcrops` | — | 14, new |

Forty rectangles of random position and size, biased toward the middle, produced
**noise rather than terraces**. Every rectangle edge is a height change, the
edges land everywhere, and each room ends up at however many rectangles happen to
cover it. On screen it read as a field of separate cubes at a hundred different
heights — a city, not a maze — and the corridors stopped being legible because
the walls flanking any one of them were all different heights.

Seven slabs, each smaller than the last and roughly on top of it, gives long
edges and flat terraces. Within one slab every wall is the same height, so a
corridor reads as a channel between two long walls, which is what the reference
picture is. `terrace_wander` keeps them from being concentric, because perfectly
nested slabs read as a wedding cake.

### `terrace_rise` 2 → 4

At two layers, a terrace is reachable from the one below it by the single cell
between two rooms, so the maze never needs a staircase and never grows one. The
result was correct, connected, and had no staircases in it at all — which is
half of what the reference picture is made of.

At four, every terrace edge is a climb that a flight of steps has to be laid
into. The generator went from cutting zero staircases to laying about two
hundred.

### `layers` 12 → 24 → 32

Twelve layers with a rise of four gives three terraces. Thirty-two is the most a
column can hold, being a 32-bit integer, and it gives seven terraces with room
for the walls above the summit. This is the one knob that is at its ceiling; a
taller maze needs a different column type, not a bigger number.

### `LAYER_PIXELS` 7 → 10

How many pixels tall one stone layer is drawn. At seven the mound was almost
flat: the whole pile of terraces rose less than a tenth of the footprint's
projected height. Ten puts the wall-height-to-cell-width proportion where the
reference picture has it.

### `orphan_max` 40 → 120

A floor pocket smaller than this, that no staircase could reach, is filled in
rather than connected. Forty was too tight: hollows punched by the outcrops
routinely come out at sixty to a hundred and twenty cells, with no straight run
into them that does not sever more than it joins.

A hundred and twenty is about one and a half percent of the floor. The count of
what was filled is in every report, and a test asserts it stays under a twentieth
of the floor — because filling in everything it cannot connect is exactly how a
broken generator would hide.

### The staircase repair pass — `stair_rounds` 12, `stair_reach` 10, `stair_candidates` 8

These belong to the pass that now runs as a **check** rather than as the pass
that does the work, since the flights are laid before the maze is carved. On a
healthy maze it cuts nothing and none of these numbers matter. They are kept at
values that were enough when it *was* doing the work, so that the day it has to
again, it can.

---

## Phase four: turning a crowd into a crowd

### Populations: a count that needed to be a density

| Scene | Was | Now |
| --- | --- | --- |
| `balls` | 260 | 300 |
| `guys` | 200 | 700 |
| `both` | 180 + 140 | 260 + 480 |
| `crowd` | — | 1400, new |

The shared idle — two bodies standing about together, which is most of what phase
four is pointed at — fired **six times a minute** at two hundred walkers. Nothing
was broken. Two hundred bodies in eight thousand eight hundred floor cells is two
percent occupancy, and two of them are adjacent almost never.

Measured over thirty seconds on one maze:

| Walkers | Occupancy | Stood together |
| --- | --- | --- |
| 100 | 1.1% | 1 |
| 300 | 3.4% | 6 |
| 700 | 7.9% | 34 |
| 1400 | 15.8% | 119 |

`capacity` went from 2000 to 3000 to hold the largest of these.

### `crowd_weight` = 0.06, new

How much less likely a step into an occupied cell is. Never zero, and that is the
whole design of it: in a one-wide corridor with somebody coming the other way,
refusing outright means both of them stand there for the rest of the run.

At seven hundred walkers this took separations from twenty-two thousand a minute
to fifteen thousand. The remainder is genuine corridor traffic — two bodies in a
passage one cell wide, one of which has to give — and it resolves every time:
across every measured run, the count of overlaps that could *not* be resolved is
zero.

The claim that goes with it lasts the **journey**, not the tick. A step takes
twenty-five ticks at the walker's speed, so a one-tick claim leaves twenty-four
during which anybody may take the destination, which was where most of the rest
of the shoving came from.

### `errand_chance` = 0.02, new

Per arrival, a decision to go somewhere in particular rather than nowhere. A
wandering body never arrives, so nothing it does ever finishes and the camera has
no moment to notice.

The destination is a block or two away, not anywhere in the maze. A cell drawn
from the whole maze is a three-hundred-step journey costing five milliseconds to
plan — at seven hundred bodies that was most of the tick — and it is the wrong
journey anyway, because nobody watches a two-minute trek.

### `search_budget` 4000 → 2500

Local errands do not need it. A search that gives up is counted in the report and
across every measured run the count is zero.

### The idle rows, new

Six of them, with weights per creature kind. `breathe` is the default and is
weighted highest: a genuinely motionless body reads as a bug, because the eye
assumes something crashed, and a body whose drawn height moves by a twentieth of
a layer on a slow cycle reads as alive without anybody noticing why.

### The director's settings, new

`dwell_seconds` 8, adjustable 1 to 60 — the slider was asked for by name.
`boredom_seconds` 12. `ease` 0.10, adjustable 0.02 to 0.5: snapping a camera to a
body stepping between cells makes the whole maze jitter by a cell every step.
