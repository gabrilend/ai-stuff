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
