# 205 — Workers and the run loop

## Current behavior

**Four cores stand at the gate with nothing on the other side of it.**

Each has a stack, an identity, memory it owns, and a ring it could read
from. None of them has a loop.

## Intended behavior

**A core becomes a worker by entering a loop it never leaves: take a
task, run it, deliver what it produced, free it, repeat.**

```
   ┌───────────────────────────────────────────────┐
   │                                               │
   ▼                                               │
  take a task                                      │
   │                                               │
   ├── nothing there ──→ sleep (206) ──→ woken ────┤
   │                                               │
   ├── got one                                     │
   │                                               │
   ▼                                               │
  call its box function                            │
   │                                               │
   ▼                                               │
  deliver the return value (211)                   │
   │                                               │
   ▼                                               │
  free the task ───────────────────────────────────┘
```

**The worker knows nothing about boxes.** It reads one field of a task
— the function to call — and calls it. Everything about what a task
*means*, which station produced it and where its output goes, lives on
the delivery path. This is not tidiness for its own sake: it means
nothing about a map can influence scheduling, so the map cannot
accidentally make the engine unfair.

**Each core carries a small context**, and it never moves:

| field | type | what it is for |
|---|---|---|
| number | `int` | which core this is; statistics, and whose stack is whose |
| stripes | pointer | this core's slice of the allocator (203) |
| inside | `int` | which station this core is currently running |
| ran | `long` | how many tasks this core has completed |
| asleep | flag | set while parked (206) |

The context is reached through a register the core keeps for exactly
this purpose, so a worker finds its own state without a lookup and
without any core reading another's.

**The `inside` field is one word, written once per task, and it is what
makes a crash nameable.** When something goes wrong on core 2, the
question anybody asks first is "doing what?" — and without this field
the answer is an address. With it, the answer is a station and
therefore a box and therefore a source file. It is also what 214 reads
when a box has to be removed.

**Two contexts must never share a cache line.** Core 0 bumping its own
`ran` counter would otherwise take the line away from core 1 on every
single task. The contexts are padded and aligned to a line each — the
same rule as 203's stripes, one level up, and the reason to state it
twice is that it is invisible in the source unless somebody wrote it
down.

**The gate from 202 opens once.** Between the cores existing and the
work beginning there is exactly one window, and that window is where
the first map is placed and its inputs are written. After that the loop
runs until the device is switched off.

## Suggested implementation steps

1. The worker context struct, padded to a cache line, one per core,
   allocated before the cores are released.
2. Store each core's context address in the per-core register during
   202's setup, and a small accessor that reads it back.
3. The run loop, with the empty-ring case left as an immediate retry
   for now — 206 replaces it with sleeping. Comment it as temporary,
   because a spinning core that ships is a core burning power forever.
4. Delivery is a call from inside the loop between running the task and
   freeing it (211), left as an empty hook until that issue lands.
5. A test that submits a known number of counting tasks and asserts
   every one ran exactly once, across all four cores.
6. A test that nothing runs before the gate opens.

## Open questions

- *Should `inside` be written on every task, or only in a debug
  build?* It is one store of one word against a task that is about to
  do far more than that, so the cost is almost certainly noise — but
  "almost certainly" is what measurements are for, and 215 is where it
  gets measured. The stronger argument for keeping it unconditional is
  that a crash you cannot name is worst precisely when it was not
  reproducible enough to re-run under a debug build.
- *What does a worker do if a box function never returns?* Nothing, and
  that is the honest answer: the engine's rule is that a box never
  blocks, and nothing enforces it. A box with an accidental infinite
  loop costs one core out of four, silently, forever. A watchdog that
  noticed would need to interrupt a core — which this design has
  otherwise carefully avoided. Worth its own issue rather than a
  half-answer here.

## Blocked by

202, 203, 204.

## Blocks

206, 211, 214.

## Related

- [204 — The task ring](204-the-task-ring.md), what this pops from
- [206 — Sleeping and waking](206-sleeping-and-waking.md), which
  replaces the temporary retry
- [211 — The delivery walk](211-the-delivery-walk.md), the hook in the
  middle of the loop
- [214 — When a box removes itself](214-when-a-box-removes-itself.md),
  which reads `inside`
