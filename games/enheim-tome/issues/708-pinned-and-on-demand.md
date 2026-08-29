# 708 — Pinned, and On Demand

| | |
| --- | --- |
| Phase | 7 — The Day |
| Blocked by | 704, 707 |
| Blocks | — |
| Reads | [the day and the curve](../docs/008-the-day-and-the-curve.md) |
| Open questions | — |

## Current behavior

Readable curves can be drawn. Nothing decides which are on screen.

## Intended behavior

**A few pinned, the rest on demand.**

You pin the handful of people you are actually thinking about into a small stack;
anyone else's curve opens singly when you ask for it.

### Why not the alternatives

**One at a time** would make comparison impossible, and comparison is the whole
value of sweeping — seeing who is idle at the moment this one is busy. A single
curve is a readout; several are an instrument.

**All of them** does not survive contact with a real acquaintance list. Fifty
people at thirty pixels each is fifteen hundred pixels of curves to scroll
through, in a pane four hundred wide, and the thing you wanted to compare is
never on screen with the thing you are comparing it to.

Pinning is the compromise that keeps the comparison and bounds the height.

### What it costs, stated

Pinning is a thing to manage, and **forgetting to unpin leaves stale people in
view** — someone you cared about last week taking up space while you work on
something else.

Worth softening: the stack should be easy to clear entirely, and pinned people
should be easy to see as a set rather than only as a column of curves.

### The stack is where sweeping pays off

With several pinned, dragging one curve moves the hour mark on all of them — see
[705](705-sweeping-drives-the-hour.md) — so one motion shows the whole pinned
group's morning at once.

That is the reason to build pinning at all, and it should be the arrangement that
gets tested: three or four curves, one drag, and whether the group reads as a
single moment.

### Order

The pinned set has an order and the person should control it, because comparing
two days is much easier when they are adjacent. Yourself first by default, since
your own day is the one you sweep against.

## Suggested implementation steps

1. A pinned list, ordered, held per current person — since acquaintance changes on
   switching, a pinned set belonging to somebody else is meaningless.
2. Pin and unpin from a person's entry in the tome.
3. Render the pinned stack together, sharing one hour mark.
4. Open an unpinned person's curve singly, with the option to pin it.
5. Provide clearing the whole stack in one act.
6. Test that four pinned curves fit and remain legible, and that one drag moves
   the mark on all four.

## Related documents and tools

- [The day and the curve](../docs/008-the-day-and-the-curve.md)
- [The tome](../docs/007-the-tome.md)
