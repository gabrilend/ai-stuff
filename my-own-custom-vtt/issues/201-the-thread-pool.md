# 201 -- The thread pool

**Phase:** 2, the world can be seen
**Blocked by:** [102](102-the-world-is-flat-arrays.md)
**Blocks:** [203](203-the-angular-sweep.md), and every parallel pass in phase 3.
**Documents:** [the shape of the code](../docs/014-the-shape-of-the-code.md),
[the world and its tick](../docs/004-the-world-and-its-tick.md)

## Current behaviour

Nothing exists.

## Intended behaviour

One pool, built once at startup, sized from the machine. Work is handed to it as
**a range and a function**: records 0 through 4999, run this.

That is the entire interface, and it is that narrow on purpose. The world is flat
arrays, so every parallel pass in this project is "walk a contiguous span of
records". A pool that also offered task queues, futures, or work stealing would be
offering machinery for problems this project does not have.

### Why there are no locks inside a pass

Nothing in a parallel pass writes where another instance of the same pass reads.
That is [buffer-then-resolve](../docs/004-the-world-and-its-tick.md), and it is
established at the design level rather than defended at the code level.

The consequence is that the pool needs no lock primitives at all. It needs a way
to start N workers on N ranges and a way to wait until they are all finished.
Anything more is a sign that a pass was written wrongly.

**If a pass ever needs a mutex, the pass is the bug, not the pool.** That sentence
belongs in the source as a comment, because the first person to hit a race will
otherwise reach for a lock and it will work and the design will quietly be over.

### Sizing

From the machine, at startup, minus one so the operating system and the network
thread are not fighting the pool for the last core. Overridable from `input/`,
because a host running this on a machine that is also doing something else needs
to be able to say so.

A pool of one is a legal configuration and must work -- it is how the determinism
test in [307](307-the-world-hashes-itself.md) proves that thread count changes
nothing.

## Suggested implementation steps

1. Start the threads at startup and never create another. Thread creation during a
   tick is a stall nobody expects.
2. Implement the barrier -- start all, wait for all. This is the only
   synchronisation in the whole file.
3. Slice a range into as many spans as there are workers, with the remainder
   spread across the first few rather than piled on the last. A last worker with
   an extra thousand records is a barrier waiting on one thread.
4. Give it a single-threaded mode that runs the ranges in order on the calling
   thread. Not a fallback -- a deliberate mode used by tests, selected explicitly.
   Both modes must work and be tested, and neither is a degraded version of the
   other.
5. Write the companion `.info.md`.
6. Test: a pool of 1, 2, and many, all producing identical output on the same
   input. That test is the point of the file.

## Open question

[4.3](../docs/016-open-questions.md) -- how large can a table get? A table of six
and a table of thirty size this pool differently, because the expensive pass is
per-viewer.
