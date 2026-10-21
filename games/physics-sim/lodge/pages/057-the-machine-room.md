# The Machine Room

Down the stairs, behind the counter. This is the part the project was
started for: the [vision](../../notes/vision) asks for "a custom threadpool
architecture for parallel ball physics processing" before it asks for a
single peg.

## The pool of workers

When the game starts it counts the processor's cores and keeps one back for
itself; on the machine these pictures were taken on, 12 cores became **11
worker threads**. The count is held between 2 and 16 whatever the machine,
and if the cores cannot be counted at all it says so and uses 4. The workers
sit waiting on a shared queue of 64 slots.

A job on the queue is two things: **a function to run, and a pointer to the
data it runs on**. That is the whole interface. The workers do not know
whether they are moving a ball, a spark, or a spinning arm; they take a job,
call the function with the data, and take the next one.

Two counters keep it honest. The queue has a lock and two signals ("there is
work", "there is room"), so a worker sleeps when there is nothing to do and
the game sleeps when the queue is full. A second lock guards a count of jobs
not yet finished; when it reaches zero it wakes whoever is waiting for the
batch to end. That waiting is the **barrier** between one kind of work and
the next. Issues 102, 106, 108 and 109 built these, in that order.

## Why the physics needs no locks

Every ball exists twice: once in the **current** list, which everyone reads,
and once in the **next** list, which each job writes to, only at its own
ball's slot. A worker working out ball 37 reads any ball it likes from
current, to see what it might hit, and writes only to slot 37 of next. No two
jobs ever write the same place, and nobody writes the place everyone reads,
so nothing needs to be locked while the physics runs.

When every job in the batch is done, the two lists swap names. Next becomes
current; the old current becomes the blank page for the following frame.

The sparks work the same way (issues 308 to 312): their own pair of lists,
their own batch, their own swap.

## One frame, in order

1. Read the keyboard and mouse.
2. **Spinning arms and track movers**, one job each (issues 901h and 902h);
   wait for all of them.
3. **Every ball**, one job each; wait for all of them.
4. Turn what the balls reported (scores, hits, deaths) into sparks, ripples
   and broken pieces.
5. **Every spark and piece**, one job each; wait; swap.
6. Swap the ball lists.
7. Drop new balls, at the new positions.
8. Draw everything from the current lists.

Three barriers a frame. The order matters: the arms move first, so the balls
collide with where the arms *are* this frame, not where they were.

## What the running game says about itself

The panel in the top corner reports three numbers about this room every
frame: frames per second, the milliseconds spent in steps 3 to 6, and the
number of worker threads. Across the first ten pictures in the development
history ([the busiest of them](../../development-history/008-second-look-at-42s.png)),
with 7 to 68 balls on the boards, the game held **60 frames a second**
and spent **between 0.23 and 1.35 milliseconds** on physics in a frame, out
of the 16.7 milliseconds a frame has. The [vision](../../notes/vision)
asked for "smooth 60fps rendering with 100+ balls"; the numbers say the
room has a great deal of headroom, but no picture has yet been taken with
a hundred balls in play, so that line is not yet shown, only likely.

## The quieter machinery

- **Sleeping balls** (issues 221a to 221e). A pile of balls in a V-shaped
  bucket used to build up pressure and burst. Now a ball that has been still
  for long enough sleeps: it stops pushing on the balls beneath it but can
  still be hit. The rule, in the issue's own words: "Balls at rest don't have
  weight, but do have mass."
- **Two kinds of stress** (issue 221e). Pressure from still geometry is
  ignored; pressure from moving geometry adds up, and a ball caught between
  a spinning arm and a wall past a threshold is crushed (issue 901f).
- **A spatial hash for slow balls** (issue 222). Balls moving slowly are
  sorted into grid cells, so overlapping neighbours can be nudged apart by
  looking at a handful of cells instead of every other ball.
- **Settings baked in at build time** (issues 112 and 113). Capacities,
  limits and the background colour live in the `config` file at the project
  root, which opens itself in your editor when run and is turned into a C
  header when the game is compiled. Today: room for 1024 balls and 1024
  sparks.

The full design is in [the thread pool document](../../docs/002-threadpool-design.md)
and [the architecture overview](../../docs/001-architecture-overview.md).
