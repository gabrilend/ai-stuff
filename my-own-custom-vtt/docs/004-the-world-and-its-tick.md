# The world and its tick

The server holds one world and advances it on a fixed heartbeat. This document
describes what "the world" is as bytes in memory, and what happens on each beat.

## The world is flat arrays

Not a tree of pointers. Not objects that own other objects. Every category of
thing is one contiguous block of records, and a reference to a thing is an
**index** into that block -- a `uint32_t`, not a pointer.

```
world
├── things      : an array of thing records          (see 005)
├── walls       : an array of segment records        (see 006)
├── lights      : an array of light records          (see 006)
├── regions     : an array of named areas            (see 008)
├── scopes      : an array of control scopes         (see 008)
├── viewers     : an array of connected participants (see 009)
└── memory      : one fog record per viewer          (see 007)
```

Three reasons this shape, in ascending order of how much they matter:

**Iteration is a walk.** Sight, movement, and the fog sweep all read every record
of one kind in order. A contiguous block means the memory prefetcher is correct
about what comes next, and the loop body can be the kind of thing that vectorises
or gets hand-written in assembly later without restructuring anything around it.

**Slicing across threads is arithmetic.** Splitting work for a thread pool is
"records 0 through 4999 are yours, 5000 through 9999 are mine". No traversal, no
locks to walk a structure, no question about who owns which node. The tick's
expensive passes are all shaped this way on purpose.

**Saving is a write.** A snapshot of the world is the arrays, written out. A
replay is a snapshot plus the commands that followed it. Neither needs a
serialiser that knows the shape of every type, because there are no pointers to
translate.

### Zero is a sentinel; nothing is ever nil

Index `0` of every array is a reserved empty record that means "nothing". A thing
standing on no region has `region = 0`. A wall belonging to no door has
`door = 0`. Code reads index 0, gets the empty record, and proceeds.

The alternative -- a null pointer and a check before every dereference -- asks, at
every single use site, whether some earlier code did its job. That question gets
asked ten thousand times a tick and answered "yes" ten thousand times, and the one
time the answer is "no" it is because of a bug somewhere else entirely. So the
question is asked once, in a validator that runs when the world is loaded and
after any structural change, and never again in a loop.

A validator failure names the record, the field, and the value. It does not
substitute a default. See the project's standing preference: a fallback is a
warning, and a warning is an error.

## The tick

The server advances the world on a fixed interval. Each beat runs a **dispatch
table** of passes, in order -- an array of function pointers, not a sequence of
calls in a function body, so that the order of the simulation is readable data
rather than something buried in code.

| # | Pass | What it does | Parallel? |
| --- | --- | --- | --- |
| 1 | **Intake** | Drain each viewer's socket. Validate, accept or refuse each command. | Per socket |
| 2 | **Intent** | Turn accepted commands into intended motion and intended actions. | Per scope |
| 3 | **Motion** | Advance everything that is moving. Resolve collisions with walls. | Per thing |
| 4 | **Rules** | Hand the ruleset its slice of the beat: timers, effects, whatever it asked for. | Ruleset's call |
| 5 | **Sight** | Recompute what each viewer can see, from each body they command. | Per viewer |
| 6 | **Memory** | Fold this beat's sight into each viewer's fog record. | Per viewer |
| 7 | **Outbound** | Build and send each viewer's filtered update. | Per viewer |

Adding a pass is adding a row. The order of the rows is the answer to every
"but does X happen before Y?" question, and it is one table to look at.

Four of the seven passes are shaped "per viewer" or "per thing", which is the
same statement as "these go to the thread pool". Sight is the expensive one and it
is embarrassingly parallel: each viewer's visibility depends on the walls and the
things, and on no other viewer.

### Buffer, then resolve

Nothing in a pass writes to something another instance of that same pass is
reading. Motion writes intended positions into a second array; a resolve step
commits them. Two things trying to enter the same square both write their
intent, and the resolve decides, so the outcome does not depend on which thread
got there first.

This is what makes the tick deterministic, and determinism is what makes a replay
mean anything. Same world, same commands, same seed, same result, on any machine
with any number of threads.

## Time, turns, and undoing

The tick is the heartbeat. The **turn** is a larger thing built out of ticks, and
it is a transaction: a snapshot at its head, and an undo.

**Nothing waits for it.** Play runs continuously — commands are accepted on every
beat and applied on the beat they arrive, and a turn boundary is where the world
is copied aside so somebody can come back to it. A turn is a place you can go back
to, and the number that decides how often one happens is called
`beats_between_checkpoints` for that reason.

That is a server concept, not a ruleset one, and the distinction is what keeps the
server ignorant of games. The server knows **a turn is a stretch that can be
undone**. It does not know what initiative is, what a round means, or whether
acting twice is legal.

Turns are described in full in
[the turn is a transaction](019-the-turn-is-a-transaction.md). What matters here
is the two properties they demand of the tick, both of which it already has:

**Simultaneous resolution** is [buffer-then-resolve](#buffer-then-resolve),
already the rule for every pass. Everyone's intentions are written down first and
settled afterwards, so nothing depends on whose packet arrived first.

**Rollback** is a snapshot at the head of each turn plus a deterministic replay
forward. Both already exist: a snapshot is a write, because the world is flat
arrays with no pointers; and a replay reproduces exactly, because the tick is
deterministic. Undo did not need a mechanism built for it. It needed two
mechanisms that were already there for other reasons to be pointed at each other.

That is the second time in this project that a decision made for one reason turned
out to be the whole of the answer to a different question. It is worth noticing
each time it happens -- see [strategems](../strategems/patterns-that-keep-working).

## Read next

- [The turn is a transaction](019-the-turn-is-a-transaction.md) -- what a turn
  actually is, and what undoing one does to everybody who already saw it happen.
- [A thing in the world](005-a-thing-in-the-world.md) -- the record that most of
  those arrays are made of.
- [Commands enter through one door](010-commands-enter-through-one-door.md) --
  what pass 1 is draining.
