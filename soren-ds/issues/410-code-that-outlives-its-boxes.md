# 410 — Code that outlives the boxes that used it

## Current behavior

**Every compile leaves a page of code behind and nothing ever takes one
away.**

Somebody editing a box all afternoon produces one page of executable
code and one catalogue row per save. The device is a handheld with fixed
memory and no swap, and the whole point of the authoring loop is that
saving is cheap enough to do constantly.

## Intended behavior

**Code is retired, swept, and freed — the same three steps that reclaim
an old set of arrows, by the same mechanism.**

Phase 2 built this for destination arrays (207) and deliberately built
it to be shared, because this is the same lifetime problem wearing
different clothes: something is being replaced while a core may be
inside it.

| | destination arrays | box code |
|---|---|---|
| what is replaced | a port's set of arrows | a page of executable code |
| who might be inside it | a core walking that port's destinations | a core running that box |
| when | during a delivery | earlier in the same task |

**One counter per core answers both.** It is bumped at the start and end
of a *whole* task — run the box, deliver, free — so it reads odd while a
core is inside one and even while it is not. That window covers being
inside a box and being inside a delivery walk, so there is one mechanism
rather than two that drift.

```
   retire   file the page, with a snapshot of all four counters
      │
   sweep    for each filed page, for each core:
      │       counter now even?          → not inside. passes.
      │       counter differs from snap? → finished the task it was in.
      │                                    passes.
      │       otherwise                  → still might be. leave it filed.
      ▼
   free     when all four pass
```

Nothing waits and nothing spins. A core with no work is asleep and
therefore even, so an idle device does not stall the sweep — which is
exactly what a scheme built on "wait for everyone to check in" would
deadlock against.

**The scrapyard owns a lock, against double-freeing rather than against
tearing.** Two things touch it — a sweep, and teardown — and only one is
obvious. Take the lock, confirm the page is still filed, unfile it, free
it, all under one hold, so a second arrival does not find it. The lock
is a leaf; nothing else may be acquired while holding it.

### Only unplaced code can ever be reclaimed

This is the part that reads as a disappointment and is worth stating
plainly rather than discovering.

**A station's box cannot be changed, and a station cannot be removed.**
An index is a position; reclaiming one means either a hole every walk
must skip or a renumbering that invalidates every arrow at once (207).
So a page of code stays reachable for as long as any station places that
box — which is forever, because the station stays in the table.

What this reclaims is therefore **the box that was compiled and then not
placed, or placed somewhere that was never wired**. Somebody saving
fifteen times while getting a box right produces fourteen of those, so it
is narrower than it sounds and still worth building. The alternative is
code accumulating forever in a device whose entire purpose is being
edited while it runs.

**There is no reference counting and no generation number.** The old
plan had both — a count incremented when a task started running a box
and decremented when it ended, plus a rule that the highest generation
always survives. The count is replaced by the per-core counters, which
cost one uncontended write instead of two contended ones on the hottest
path in the system. The generation rule is replaced by nothing, because
there are no generations: a rebuilt box is a different box with its own
catalogue row, and which one runs is decided by which station the arrows
point at (411).

**What is written down, and where.** The source, saved as the box comes
into existence (409), and a small record beside it: what it was called,
what the compiler said, when. Both live on the RAM-backed tier, with the
lifetime that implies — they survive a reload in the same session and
not a reboot, which is the same lifetime a log has and should be said
rather than implied.

## Suggested implementation steps

1. Widen phase 2's per-core counter from the delivery walk to the whole
   task, and confirm the destination sweep still passes with the wider
   window — it becomes freeable slightly later than it strictly must,
   which nothing measures.
2. Retire-don't-free for code pages first: file them, never sweep. Dull
   and correct.
3. The sweep, sharing the scrapyard the arrows already use.
4. A test that a box compiled, never placed, and retired has its page
   freed while a saturated device keeps running.
5. A test that a box some station places is **not** freed, ever, and
   that the sweep says why rather than silently skipping it.
6. A test that teardown racing a sweep frees each page exactly once —
   the double-free the lock exists for.

## Open questions

- *Should the device warn when unplaced code accumulates?* Fifteen saves
  in an afternoon is normal; fifteen hundred means something is looping.
  The counter is free and the threshold is a guess, which is the usual
  shape of a report that is worth having and hard to tune.
- *Can a station ever be reused for a rebuilt box?* Not under the rule
  above, and the rule is load-bearing. But the authoring loop would be
  much simpler if a station could be repointed, and the reason it cannot
  is that its inputs may hold values belonging to the old box's types.
  Worth revisiting only with that specific hazard in hand.

## Blocked by

207 (the mechanism this shares), 409.

## Blocks

411, 412.

## Related

- [207 — The station table](207-the-station-table.md), where retire,
  sweep and free were built and deliberately made shareable
- [409 — Compiling a box on the device](409-compile-pipeline.md)
- [411 — Replacing a box in a running program](411-replacing-a-box-in-a-running-program.md)
