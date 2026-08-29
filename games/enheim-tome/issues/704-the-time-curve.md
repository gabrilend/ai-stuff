# 704 — The Time-Curve

| | |
| --- | --- |
| Phase | 7 — The Day |
| Blocked by | 606, 703 |
| Blocks | 705, 707, 708 |
| Reads | [the day and the curve](../docs/008-the-day-and-the-curve.md) |
| Open questions | — |

## Current behavior

A person's whereabouts can be read at an hour. Nothing shows their day.

## Intended behavior

A person's day, plotted, in a small container: **roughly 225 by 30 pixels** —
about twice a scrollbar's width and a quarter as long — always horizontal.

```
┌───────────────────────┐
│  6   9  12  15  18    │
│ ▁▂▅███▆▃▂▁▂▄███▇▅▂▁   │
└───────────────────────┘
   busy ──── resting ──── busy
```

### The vertical axis is activity

High means busy, low means resting. Busy is busy regardless of kind: patrolling a
quarter, hauling grain sacks, and bent over old books all read as high.

**Rest is not idleness in this game.** People need it, and a curve pinned high all
day is telling you something about that person rather than showing an efficient
one.

### The dimensions decide what it can honestly say

Across, a whole day in 225 pixels is about **nine pixels an hour** — plenty for
sweeping.

Up, thirty pixels gives roughly **five activity levels** a person can actually
distinguish.

So the curve is **a shape, not a measurement**. You are meant to see the two humps
and the trough between them, not read a number off it. That is the right
resolution for what it is, and the interface should not pretend otherwise —
no gridlines implying precision the height cannot carry, no numeric readout of
activity.

### It is a scrubber and a readout at once

Sweeping along it drives the hour and lights where that person is — see
[705](705-sweeping-drives-the-hour.md). So the same object shows you the shape of
a day and lets you move through it, which is why it can be small: it is not
competing with anything for space, it *is* the control.

### Where it sits

In the scrolling text pane, with the person it belongs to. Several may be pinned —
see [708](708-pinned-and-on-demand.md).

## Suggested implementation steps

1. Sample the activity function across the day at the container's pixel width.
2. Draw as a filled area rather than a line — an area reads as quantity, a line
   reads as a value, and quantity is what this is.
3. Mark the hours faintly enough to orient without implying precision.
4. Show the current hour as a mark on every visible curve, so several curves read
   as one moment.
5. Keep the drawing independent of the sweeping, so a curve can be shown without
   being interactive.
6. Test at the real dimensions that a two-humped day is legible and that five
   distinct activity levels can be told apart.

## Related documents and tools

- [The day and the curve](../docs/008-the-day-and-the-curve.md)
