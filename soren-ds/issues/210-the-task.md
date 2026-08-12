# 210 — The task

## Current behavior

**The claim produces a complete set of values with nowhere to put
them.**

## Intended behavior

**One run of one station, made concrete. A task is created the moment a
station's inputs are all present, and destroyed by the core that ran
it.**

| field | type | meaning |
|---|---|---|
| call | function pointer | the box to run |
| station | `int` | which station produced it, so delivery knows where to look |
| exit | `int` | for an iterator, which exit was assigned. Decided at claim time. |
| in | the claimed bytes | one value per input port |
| out | the returned bytes | where the return value lands |

**One allocation, sized exactly for this box, freed with one call.** A
task for a two-integer box holds two integers and an integer. Not a
maximum-sized buffer, not a union of every type in the program. The
sizes are known before the task exists, because they come from the
box's own parameter types.

```
   one allocation:

   ┌────────┬────────┬──────────┬──────────┬──────────┐
   │ call   │ station│ exit     │ in bytes │ out bytes│
   └────────┴────────┴──────────┴──────────┴──────────┘
   ◀───────── header ───────────▶◀──── sized per box ─▶
```

**The values inside a task are copies.** This is what makes two runs of
one station safe, and it also means a task is entirely self-contained:
once built, it depends on nothing that another core can change.

**The exit is decided at claim time, not at run time.** An iterator's
cursor advances during the claim and the exit it landed on is recorded
here. The box function never sees it. Two tasks assembled a moment
apart therefore carry different exits and cannot collide no matter
which finishes first. Inert until the routing kinds land in phase 3,
but the field belongs here so that phase 3 is a change to routing
rather than a change to this structure.

### Where the memory comes from

The allocator hands out 4 KB pages. A task is perhaps forty-eight bytes
and there are millions of them. Going to the page allocator per task
would waste a page each time and put a bitmap scan on the hottest path
in the system.

**Blocks, by size class, on per-core free lists.**

```
   203 gives a core a page
            │
            ▼
   ┌────────────────────────────────────────┐
   │ 64 │ 64 │ 64 │ 64 │ 64 │ 64 │ ...      │  one page, cut into
   └────────────────────────────────────────┘  blocks of one class
      │
      ▼
   core 0's free list for the 64-byte class ──→ ─→ ─→

   take = pop the head.  no lock, no atomic, no other core.
```

| operation | cost |
|---|---|
| build a task | pop the head of your own list |
| free a task you built | push onto your own list |
| free a task another core built | push onto **that** core's returns list |
| your list is empty | cut a fresh page from 203 into blocks |

**A task is very often freed by a core other than the one that built
it** — that is the normal case, since building happens on the
delivering core and freeing happens on the running core. It goes back
to the core that owns the page it came from, by way of that core's
returns list, drained on that core's next allocation. One core writes,
one core reads, and no page ever belongs to two owners.

**The allocation is not on the contended path.** It happens after the
claim has released everything it touched, so a slow allocation delays
one task rather than holding up every core trying to reach that
station.

## Suggested implementation steps

1. The task struct and the exact-size layout, with one function that
   computes the size for a given box.
2. Size classes — a small set of powers of two — and the mapping from a
   computed size to a class. A box whose task exceeds the largest class
   is an error at placement time, not at run time.
3. Per-core free lists and the page-cutting path, sitting on 203.
4. The returns list, and draining it at the top of every allocation so
   a returned block is reused before a page is cut.
5. Construction, called after the claim, taking the claimed values and
   the station.
6. Destruction, called by the core that ran it, after delivery.
7. A test that a task built from a station holds byte-identical copies,
   and that changing the station's ports afterwards does not change
   them.
8. A test that runs long enough for blocks to circulate between all
   four cores, asserting the totals balance and no block is ever on two
   lists.

## Open questions

- *Should a foreign free just keep the block instead of returning it?*
  It is simpler — a core frees onto its own list regardless of where
  the block came from — and it costs nothing per free. What it costs
  instead is drift: over a long run, blocks accumulate on whichever
  core frees more than it builds, and the others keep cutting fresh
  pages. On a device that runs for days, drift is the one that matters.
  Returns lists are the choice here, and the simpler version is worth
  measuring once so the decision is recorded rather than assumed.
- *How many size classes?* Too few wastes bytes per task; too many
  means each core holds a page per class and the pages sit mostly
  empty. Four or five is the usual answer and the right number is
  visible from the box library once phase 3 exists.
- *Is a free list good enough, or should tasks be preallocated per
  station?* Preallocating removes the allocator from the path entirely
  and makes the memory bounded and knowable — genuinely attractive on a
  device. It costs the ability to have more runs of one station in
  flight than were allocated for, which means a station running out
  either refuses or waits, and waiting is the thing this design will
  not do.

## Blocked by

203, 207, 208, 209.

## Blocks

211, 215.

## Related

- [203 — Memory each core owns](203-memory-each-core-owns.md), where
  the pages come from
- [209 — The readiness check and the claim](209-the-readiness-check-and-the-claim.md),
  where the values come from
- [211 — The delivery walk](211-the-delivery-walk.md), which builds and
  pushes these
