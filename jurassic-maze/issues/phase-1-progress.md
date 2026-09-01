# Phase 1 — The Stone

**All eight issues complete.** A seed produces a maze, the validator says it is
one connected piece, and the same seed produces the same maze twice.

| Issue | |
| --- | --- |
| [101](completed/101-a-column-is-one-integer.md) | a column is one integer |
| [102](completed/102-surfaces-are-a-bit-trick.md) | surfaces are a bit trick |
| [103](completed/103-randomness-comes-from-named-streams.md) | randomness comes from named streams |
| [104](completed/104-the-terraces-are-piled-rectangles.md) | the terraces are piled rectangles |
| [105](completed/105-the-maze-is-a-spanning-tree-over-rooms.md) | the maze is a spanning tree over rooms |
| [106](completed/106-staircases-are-cut-not-built.md) | staircases are cut, not built |
| [107](completed/107-four-answers-to-may-i-move.md) | four answers to "may I move" |
| [108](completed/108-the-validator-refuses-a-broken-maze.md) | the validator refuses a broken maze |

Run `./run-tests` for the invariants and `./run-maze --describe` for one maze's
numbers. No number from a run is quoted here; they change with the parameters and
a document that restates them is a document that goes stale.

## The journey, and what it taught

The phase's plan survived contact with the screen almost intact. Four things did
not, and each one was found by something specific rather than by reading.

### The maze looked like a city, and the fix was in a different pass entirely

The first mound rendered as a field of individual cubes at a hundred different
heights. Nothing was wrong with the renderer. The terrace pass piled forty
rectangles of random size and position, and **overlapping rectangles do not make
terraces, they make noise** — every edge is a height change, the edges land
everywhere, and a corridor whose two flanking walls are different heights stops
reading as a corridor.

Nested slabs, each smaller than the last, make the edges few and long. Within one
slab every wall is the same height. That is the entire difference between a city
and a maze, and it is one pass, and it was invisible in every number the
validator produced.

**What it taught:** the numbers said the maze was fine, and it was fine — it was
just not the thing in the picture. Some properties only a picture can check, and
the screenshot flag exists because of this.

### The wrong end of the pipeline

Staircases were originally cut into the finished maze, which is what the
reference picture looks like: every flight in it is a gash cut into the side of a
block. As an *algorithm* it is a disaster. A flight lands correctly and drops the
room it passes through three layers below the corridor that room belonged to,
severing whatever was reachable only through it. It joins two pieces and breaks a
third; the count does not fall; it is rejected. Six hundred flights per maze
built and thrown away, terraces left unreachable, and the generator blaming its
own parameters while its diagnosis reported hundreds of perfectly good places to
put a staircase.

Four fixes were tried against that symptom before the cause was right: verifying
each cut, keeping several candidates per pair, steering by stranded floor rather
than by piece count, and giving the flight an explicit target. Every one of them
was a real improvement and none of them was the answer.

The answer was to move the pass. Place the flights **before** the maze is carved
and let the maze be carved around them — at which point a flight costs nothing at
all, because a run of rooms whose heights step by two is *already* a staircase
once the realise pass fills in the links between them.

**What it taught:** four improvements in a row that each help and none of which
fix it is a signal about the shape of the pipeline, not about the quality of the
attempts.

### Three measurements that were of the wrong thing

Each of these made the generator report something confidently false.

- **Flooding through every cell** to measure floor connectivity joins two
  terraces by any chain of wall tops that happens to run between them at
  climbable heights — a route along the tops of the walls, which nothing can
  reach and nothing would take. The generator then cut no staircase, believing
  there was nothing to join.
- **Counting pieces** rejects a repair flight that joins two and severs a third,
  which is most of them. Counting *floor stranded outside the biggest piece*
  falls whenever a flight brings in more than it strands.
- **One-way reachability** is not an equivalence relation. A body drops two
  layers and climbs one, so a pit is reachable from above and not from below, and
  a flood fill gives different answers depending where it started. The validator
  built on it called a maze broken or whole depending on array order.

**What it taught:** every one of these was a plausible-sounding measurement that
answered a slightly different question than the one being asked. The tell in all
three was a number that was stable, confident, and did not move when the thing it
claimed to measure did.

### One line about the sky

`headroom` counted air only as far as the last layer, treating the top of the
array as a ceiling. A surface at the world's highest layer therefore reported no
headroom, so nothing could step onto it, so the staircase that reached it was
severed, so the maze validated as two pieces.

The check exists for ceilings that do not exist yet — nothing in the project has
one until the delve — so it had never once returned anything but the right
answer, and it was the last place anybody would look.

**What it taught:** a check written early against a case that does not arise yet
is still a check that can be wrong, and it will be wrong silently for as long as
the case does not arise.

## What is worth carrying into phase 2

- Screenshots are a test. Two of the four findings above were invisible to every
  number and obvious in one frame.
- When a failure keeps moving under successive fixes, the pass order is suspect.
- A measurement is worth writing down as carefully as an algorithm. Three of
  these bugs were arithmetic that worked perfectly on the wrong quantity.
