# 603 — The Focused Filter's Controls

| | |
| --- | --- |
| Phase | 6 — The Tome |
| Blocked by | 602 |
| Blocks | 701 |
| Reads | [the tome](../docs/007-the-tome.md) |
| Open questions | — |

## Current behavior

Chips show which filters are active. None can be adjusted.

## Intended behavior

Beneath the chip row, the full controls for **whichever chip was last clicked**.

| Control | What it does |
| --- | --- |
| angle | turns the filter's hatching, freely, at any time |
| mode | behind-always, interwoven, or top-always — [504](504-the-three-modes-and-the-order.md) |
| its own parameters | whatever this filter alone needs |

Exactly one filter's controls are shown. Adjusting two means clicking between
them, which is the price of the top region staying a fixed height.

### The angle is a real control, not a setting

Turning a filter's hatching is something you do **while looking at the map**, to
separate it from another filter it is crossing. So the map must update as the
control moves, continuously, not on release — otherwise you cannot see what you
are adjusting.

That makes it a dial or a drag rather than a typed number, though the number
should be shown, because "forty-seven degrees" is a thing worth being able to
reproduce.

### The hour is here too, and it is not a filter's parameter

Above the chips sits **the hour**, which belongs to no filter.

It was originally the shade filter's parameter. Then the whereabouts equation
turned out to read it as well — see [701](701-the-hour-is-global.md) — and a value
two unrelated systems consult belongs to neither. It sits above them all.

The mistake is worth recording because it is easy to make again: the moment a
second, unrelated consumer appears for a value, its home is wrong. It was not
wrong when written; it became wrong.

### What else lives up here

Map controls that belong to no filter: the switch for the glow's aiming behaviour
from [508](508-the-glow-flips-to-aiming.md), and whatever else is about looking
rather than about a particular question.

They sit near the map because they affect the map — the principle from
[601](601-three-regions.md).

## Suggested implementation steps

1. Render controls for the focused filter only, in a fixed layout so the same
   control is always in the same place.
2. Bind the angle to a continuous drag, updating the map every frame, and show the
   number.
3. Mode as a small selector with three options, labelled in words as well as
   distinguished by position.
4. Render filter-specific parameters generically from the filter's declared list,
   so a new filter needs no new interface code.
5. Put the hour above the chips, and the map-wide switches with it.
6. Test that turning the angle re-weaves live against another active filter.

## Related documents and tools

- [The tome](../docs/007-the-tome.md)
- [The day and the curve](../docs/008-the-day-and-the-curve.md)
