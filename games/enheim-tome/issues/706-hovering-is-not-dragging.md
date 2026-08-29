# 706 — Hovering Is Not Dragging

| | |
| --- | --- |
| Phase | 7 — The Day |
| Blocked by | 705 |
| Blocks | — |
| Reads | [the day and the curve](../docs/008-the-day-and-the-curve.md) |
| Open questions | — |

## Current behavior

Sweeping a curve drives the hour. Nothing distinguishes a deliberate sweep from
the pointer merely passing over.

## Intended behavior

**An accidental mouse-over must not throw the world about.**

The hour is now driven from several places — its own control and every visible
curve — and curves sit in the scrolling text pane among other things you might be
reaching for. A pointer crossing three pinned curves on its way to a button must
not drag the whole city through three different times of day on the way.

So: **the hour moves on a press-and-drag, and not on hover.**

### What hover does instead

Hovering a curve is not nothing — it should show *that this is sweepable*, and
where in the day the pointer is. But it reports rather than acts:

| | |
| --- | --- |
| **hover** | shows the hour under the pointer, and what that person is doing then, without changing the hour |
| **press and drag** | sets the hour, and everything follows |

That gives you a way to glance at a moment without committing to it, which is
useful in its own right — you can ask "what is she doing at four" without moving
the city and then having to put it back.

### Releasing does not restore

Once dragged, the hour stays where you left it. It is not a spring. You were
planning at that moment and are presumably still planning at it.

### The same care applies to the hour's own control

It is a slider at the top of the tome and it should not respond to the pointer
merely passing over it either, for the same reason.

## Suggested implementation steps

1. Track press state per curve; only set the hour while a press that began on that
   curve is held.
2. On hover without press, compute the hour under the pointer and show it, along
   with the doing at that hour, without touching the global value.
3. Continue a drag that has left the curve's bounds vertically, so a slightly
   wandering hand does not drop the sweep mid-motion.
4. End the drag on release, leaving the hour where it is.
5. Test that moving the pointer across three pinned curves without pressing leaves
   the hour and every filter untouched.

## Related documents and tools

- [The day and the curve](../docs/008-the-day-and-the-curve.md)
