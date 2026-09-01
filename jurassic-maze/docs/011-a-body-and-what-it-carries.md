# A Body And What It Carries

A body is an integer. It is not a table, it is not an object, and there is
nowhere in the program you can hold one in your hand.

## Flat arrays, one per field

The body store is **one table of flat arrays**, not an array of tables. Every
body's x position lives in one contiguous array of doubles; every body's
locomotion kind lives in one contiguous array of small integers. Body number 12
is the twelfth entry of each.

| Array | Type | What it holds |
| --- | --- | --- |
| `alive` | 0 or 1 | whether this slot is in use |
| `generation` | integer | bumped every time the slot is reused |
| `kind` | small integer | which creature this is — a row of the creature table |
| `locomotion` | small integer | which row of [the locomotion table](012-locomotion-is-a-dispatch-table.md) moves it |
| `x`, `y` | doubles, in cells | where it is, to a fraction of a cell |
| `z` | double, in layers | how high it is. Equal to its stance's layer when standing; larger while falling. |
| `vx`, `vy`, `vz` | doubles, cells per second | velocity. Zero for anything that does not roll. |
| `cell` | integer | `x + y * width`, rounded. The stance's cell. |
| `layer` | small integer | the surface it is standing on. The stance's layer. |
| `facing` | 0 to 3 | which way it is pointed |
| `radius` | double, in cells | how wide it is, for collision |
| `body_height` | small integer, in layers | how much headroom it needs |
| `health` | double | for the phases that have fighting in them |
| `team` | small integer | zero means it belongs to nobody |
| `intent` | small integer | what the decide pass concluded it wants |
| `intent_cell` | integer | where it wants to be, if the intent has a destination |
| `partner` | integer | the body it is currently paired with — an opponent, a mount, a rider — or zero |
| `partner_generation` | integer | the partner's generation at the moment it was recorded |
| `timer` | double, seconds | how long the current state has been going on |

Two reasons for arrays instead of records, and the second is the one that
decides it:

1. The move pass touches six fields out of twenty-two. An array of tables drags
   the other sixteen through the processor's cache alongside them. Flat arrays
   touch six arrays and nothing else.
2. **Slicing a flat array across a thread pool is a pair of integer bounds.**
   Slicing an array of tables is a pointer chase into wherever the allocator
   happened to put each one. Since the entire simulation is the same arithmetic
   repeated over many independent bodies, the storage has to be the shape the
   pool wants before the pool can exist at all.

## Allocated once

The store is allocated at world creation to a fixed capacity and never grows.
Running out is an error with a message, not a reallocation. A simulation that
quietly grows its arrays is a simulation that quietly stops fitting in cache, and
the frame rate falls off a cliff for reasons that look like nothing.

Ids come off a **free list** and are recycled. Every slot carries a
**generation** counter that is bumped when the slot is reused, so a stale id can
be caught being stale rather than silently addressing whoever moved in.

That is what `partner_generation` is for. A fencer holds the id of its opponent.
The opponent dies, its slot is recycled, and a newly spawned little guy takes it.
Without the generation, the fencer is now duelling a stranger who has no idea. The
only sanctioned way to follow a stored id is to check the generation first, and
the check is one comparison.

## Nothing is ever nil

Empty is the integer zero, and zero is a sentinel with a meaning: body zero does
not exist and never will, so `partner == 0` reads as "nobody" without ambiguity.

A nil check is a question about whether some earlier code did its job. That
question belongs in a validator that runs once at load time, not in the inner
loop, asked every tick, about a condition that should be impossible.

## Where they are, spatially

Asking "who is near this body" by walking every body is fine for forty and
disastrous for four thousand. The store keeps a **bucket per cell**: a count
array and an offset array, rebuilt each tick by the `index` pass in two sweeps —
one to count how many bodies are in each cell, one to place them.

Two sweeps and two preallocated arrays, no lists, no tables, nothing allocated.
The `meet` pass then looks at a body's own bucket and its eight neighbours, which
is a bounded amount of work per body regardless of how many bodies there are.

## The creature table

`kind` is a row index into a table in `assets/`. That table holds every number
that distinguishes one creature from another — radius, height, speed, health,
which locomotion it uses, what colour it is drawn.

**Every balance number in this project is in that table and in no document.** A
document that restates a speed is a document that will be wrong the first time
somebody tunes it. Documents name the field; the table holds the value; and
tuning is recorded in `docs/balance-updates.md` as it happens.

## Related documents and tools

- [The tick](010-the-tick.md) — the passes that sweep these arrays
- [Locomotion is a dispatch table](012-locomotion-is-a-dispatch-table.md)
- [Standing somewhere and going elsewhere](004-standing-somewhere-and-going-elsewhere.md) — what `cell` and `layer` mean
