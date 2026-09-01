# Locomotion Is A Dispatch Table

Two different kinds of motion were asked for by name: **continuous with
momentum** for the balls, and **a walk on a graph, smoothed for the eye** for the
little guys. The instruction that came with them was to accommodate multiple.

So there is no "how bodies move" in this project. There is a table, and each row
is one way of moving.

## The table

    locomotion[kind] = {
        name        = "rolling",
        advance     = function(world, bodies, first, last, dt) ... end,
        parallel    = true,
        drop_limit  = infinity,
        needs       = { "vx", "vy", "vz" },
    }

| Field | What it is for |
| --- | --- |
| `name` | what the headless report calls this kind when it breaks down distance travelled |
| `advance` | moves **a range of bodies**, not one body. See below. |
| `parallel` | whether the range may be split across cores |
| `drop_limit` | how far this kind may descend before it is falling rather than stepping |
| `needs` | which arrays it reads or writes. Checked once at startup against what the store actually has. |

## Why `advance` takes a range and not a body

Because a per-body function forces the caller into a loop with an indirect call
inside it, once per body per tick, and because a range is what a thread pool
takes.

`advance(world, bodies, first, last, dt)` is handed a slice of the kind's
**roster** — a contiguous array of the body ids currently using this locomotion.
The pool splits that array into one chunk per core and calls `advance` once per
chunk. One indirect call per chunk per tick, rather than one per body, and the
work is already in the shape that parallelises.

The roster is contiguous even though the ids in it are scattered, and it is
maintained in constant time: a body changing locomotion is swap-removed from its
old roster and appended to its new one. Bodies change locomotion rarely — a
human mounting a dinosaur, a fencer being knocked down — so the roster is
maintained on the rare event rather than rebuilt on the common one.

## The rows

| Row | Motion | Who uses it |
| --- | --- | --- |
| `rolling` | continuous. A real velocity, gravity down the local slope, rebound off wall faces, and a fall off any ledge. | balls |
| `walking` | a step from surface to surface on the graph, taking a fixed time, with the drawn position interpolated between the two so the eye sees smooth motion. | little guys, fencers, humans |
| `striding` | walking, for a body wider than one cell. The same graph, but every cell of the body's footprint must be enterable. | dinosaurs |
| `lumbering` | striding, with the climb limit raised and the ability to break a wall rather than route around it. | stone golems |
| `creeping` | walking, but along walls rather than along floors. Ignores the drop limit entirely. | vine monsters |
| `carried` | none. The body's position is its carrier's, offset. It does not decide and it does not collide. | a human riding a dinosaur |
| `still` | none. A body that is fixed. | scenery that has to be a body for some reason |

Only the first two exist in the early phases. The rest are rows that will be
filled in, and they are listed here because **the shape of the table is the
design**: a new creature that moves in a new way is a new row and a new function,
and it cannot accidentally change how anything else moves, because there is
nowhere to put the change that would.

## Rolling and walking are not two settings of one system

This is the part worth being explicit about, because the tempting design is one
mover with a `smooth` flag on it, and that design is wrong.

**Rolling asks the stone a different question than walking does.** A walker asks
"may I go from this surface to that one" and gets one of four answers, from
[the movement rule](004-standing-somewhere-and-going-elsewhere.md). A roller
never asks that. It has a position that is not on any grid, it integrates a
velocity, and it collides against **wall faces** — the flat planes between an
open cell and a stone one — resolving the overlap and reflecting the velocity.
The four compass directions do not appear in it anywhere.

They also disagree about falling. A walker treats a three-layer drop as a wall
and routes around it. A roller treats the same three layers as a cliff and goes
over. Same stone, same tick, different answer, and neither is a special case of
the other.

Trying to unify them produces a function with two halves and a branch at the
top, which is a dispatch table with one row and worse ergonomics.

## What they do share

Three things, and they are shared as *functions the rows call*, not as behaviour
in a base class:

- **The stance.** Both keep `cell` and `layer` in agreement with where they
  actually are, because everything else in the program — the spatial buckets, the
  renderer's ordering, the meet pass — reads the stance and not the position.
- **Falling.** A body that has left its surface with nothing under it is falling,
  and falling is the same arithmetic for everybody: gain downward velocity,
  descend, find the highest surface below, land on it. A walker that walks off a
  ledge enters this and comes out the other side walking again.
- **Leaving the world.** The rim makes it impossible, and the check runs anyway,
  and it is loud. A body outside the footprint is a bug in whichever row let it
  get there, and the message names that row.

## Related documents and tools

- [Rolling with momentum](013-rolling-with-momentum.md) — the first row, in full
- [Walking the surface graph](014-walking-the-surface-graph.md) — the second
- [The tick](010-the-tick.md) — where the move pass sits
- [A body and what it carries](011-a-body-and-what-it-carries.md) — the arrays the rows write to
