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

---

## Phases five, six and seven

### The fencer's exchange

Both fencers strike each exchange rather than taking turns. `exchange_seconds`
0.55, `skill` 0.50 against `parry` 0.42 with `swing` 0.55 of luck on each,
`damage` 3.0 against `health` 14 — about eight exchanges to a decision, and about
one duel in eight ending with both of them falling.

`stalemate_seconds` 26 and `disengage_seconds` 4.0. The second of those is the
one that matters: **zero turns a series of duels into a melee**, which is the
other reading of open question 1, and it is the only number in the project whose
value is a decision about what the thing is rather than about how it feels.

### Plazas, new — and why the generator grew them

`plaza_count` 26 attempts, `plaza_min` 5, `plaza_max` 13, which comes out at
about a dozen clearings on a default maze.

They were added because **a body wider than one cell had nowhere to stand**. Nine
contiguous cells at one height do not occur in a maze of one-cell corridors:
ninety dinosaurs were spawned and fifty-seven never moved.

The first version flattened any cell within a wall's height of the clearing's
level, which quietly *moves floor* and severed a hundred and sixty-five cells on
some seeds. It now includes a cell only when it is already floor at exactly that
level, or when it is wall — so nothing that was floor ever changes height.

### The dinosaur

`radius` 1.0, which is a three-by-three footprint and is what makes all of the
above necessary. `step_seconds` 0.72 — half again slower than a little guy.
`sight_range` 26 cells and `sight_interval` 0.5 seconds, checked with a per-body
phase offset so the population does not all look at once.

`game_chance` 0.35 of a meeting becoming a game, `grace_seconds` 2.5 after a tag
so the roles do not swap back on the next tick, `give_up_distance` 34.

### Fire

`damage_per_second` 3.2, `spread_chance` 0.24 a second per flammable neighbour,
`spread_range` 1 cell — so a firebreak is a firebreak.

Flammability is per creature: a vine is 1.0 with 7 seconds of fuel, an automaton
0.85 with 9, a human 0.15 with 3, and stone is 0. The automaton being flammable
is the whole of what makes it solve itself, and it is a number rather than a rule.

### LuaJIT's trace cache — not a balance number, and the largest one

`maxtrace` 4000 and `maxmcode` 4096, raised from the defaults of 1000 and 512 at
world creation.

With the defaults, a run with two locomotion rows live overflows the cache and
flushes it forty-five times in three hundred ticks. Balls alone cost 1.8 seconds
a minute, walkers alone 1.0, and the two together **12.4** — each four times
slower purely for the other existing. Raising the limits took that scene to 1.3
and the test suite from thirty seconds to eleven.

It is recorded here because it is a number that was turned and it changed the
program's behaviour more than any other in the project.

---

## Four questions answered, and what the answers were worth

### `disengage_seconds` 4.0 → 0, for the fencer

**A released fencer re-engages immediately.** Open question 1 asked whether "swap
to a different target" was about the fencers or about the camera, and it was
about the fencers: a corridor becomes a running brawl and the camera never has to
move to keep watching one.

Measured over forty seconds of the `war` scene: 1421 duels at four seconds became
1813 at zero, with proportionally more deaths.

The number remains a knob and above zero it is the other behaviour, which still
has a test. It is the only number in the project whose value is a decision about
what the thing *is* rather than about how it feels.

### The delve's weapons and resistances, new

"Solve" was meant loosely, so the monsters are enemies with health and the cycle
between them became a table of nine multipliers.

| | blade | fire | blunt |
| --- | --- | --- | --- |
| golem | 0.20 | 0.00 | 1.00 |
| vine | 1.00 | 3.20 | 0.35 |
| automaton | 1.40 | 2.60 | 1.80 |

And the party: a **human** carries `fire` at 2.6 damage and reach 1; a
**dinosaur** carries `blunt` at 7.0 and **reach 2**. The reach is the field that
changes behaviour rather than numbers — it lets a dinosaur fight down a corridor
it cannot itself enter.

The multipliers were chosen so that neither party member alone answers all three
monsters: fire against a golem is exactly zero, and a hammer against a thicket is
0.35. A party of one kind is not a party.

Every monster's exchange numbers were set so that a fight lasts a few seconds
rather than a moment: a golem swings slowly (1.10s) and hard (9.0), a vine
quickly (0.75s) and feebly (1.6) but parries well (0.52) because there is a great
deal of it to cut through.

### `plaza_count` and the jungle

Open question 6 is answered: **there is no jungle.** Nothing outside the maze
ever. That does not change a number, and it is recorded here because it removes
a whole category of them from ever being needed.

### The palette

Open question 10 is answered: **keep the limestone.** No numbers changed. Every
colour in the project is still in one file and nothing else names one, so this
stays a one-file decision if it is ever revisited.

## The bouncer

A second ball, moving as a sphere against real geometry rather than as a point on
an interpolated height field. Same size as the ball; the numbers differ because
what they mean changed underneath them.

| Number | Value | Why |
| --- | --- | --- |
| `gravity` | 45 cells per second squared | The same as the ball's, and now the only force applied by hand. The ball also gets a separate acceleration along the sampled slope of the floor; this one gets nothing of the sort and runs downhill because the faces push it sideways. There is no `slope_gain` to multiply it by. |
| `roll_friction` | 0.55 per second | Applied only while something is pushing up on it, which is what makes it rolling resistance rather than air. The ball's is applied whenever it is "not airborne", and that is a height comparison rather than a contact. |
| `restitution` | 0.45 | The ball's 0.85 was chosen for a maze made entirely of walls, where a ball meets one within a cell or two of being dropped and needs to keep nearly all its energy to get anywhere. A mountainside is mostly open shelf; at 0.85 a sphere never settles. |
| `bounce_floor` | 0.6 cells per second | Below this a bounce is set to zero. Without it a settling sphere performs several hundred invisible bounces a second, each one a contact. |
| `max_speed` | 7.0 cells per second | One tick moves 0.117 cells, under a third of the radius. Load-bearing: a body that travels further than its own width between ticks can pass a face without ever being within a radius of it. |
| `rest_speed` | 0.30 cells per second | Horizontal speed below which it counts as stopped. Measured on the horizontal only, because a sphere settling on a tread still has a vertical component for a few ticks and counting it would keep resetting the timer of a ball that has plainly stopped. |
| `rest_seconds` | 3.5 | As the ball's. |
| `spawn_nudge` | 5.0 | The width of the random push it is dropped with, and the only thing that ever starts one. A sphere at rest on a level plate under straight-down gravity has nothing acting on it sideways at all; the first mountain, of broad flat shelves, held three hundred of them motionless for a minute. The ball's nudge of 2.0 is decoration on top of an interpolated slope that would have moved it anyway. |

Measured on the mountainside, nine hundred of them over thirty seconds: a mean
journey of 49 cells, 1674 reaching rest and being dropped in again at the top, and
the deepest descending twenty-one layers from summit to base. Run
`./run-maze --headless --map 070-the-mountainside --scene heap` for today's
numbers rather than trusting these.
