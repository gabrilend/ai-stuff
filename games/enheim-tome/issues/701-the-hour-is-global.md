# 701 — The Hour Is Global

| | |
| --- | --- |
| Phase | 7 — The Day |
| Blocked by | 603 |
| Blocks | 702, 703, 705 |
| Reads | [the day and the curve](../docs/008-the-day-and-the-curve.md) |
| Open questions | — |

## Current behavior

Filters have their own parameters. Time, where it exists at all, would be one of
them.

## Intended behavior

**One number, shared, belonging to no filter.**

### The mistake this corrects

The hour began as the shade filter's parameter, which was entirely reasonable: the
shade filter needed an hour and nothing else did.

Then the whereabouts equation turned out to read it too — where a person is, is a
function of the hour, see [703](703-whereabouts-is-a-function.md). **A value two
unrelated systems consult belongs to neither of them.**

Worth recording as a pattern, because it will happen again: the moment a second,
unrelated consumer appears for a value, its home is wrong. It was not wrong when
it was written; it became wrong.

### What it buys, being one thing

Drag the hour and the great willow's shadow swings across the north-west district
while everybody slides along their own day, in one motion. One control, several
truths moving together.

Had it stayed a filter's parameter, the shade would move and the people would not,
and the city would be visibly incoherent in a way nobody could fix without this
change.

### Where it lives

At the top of the tome, **above** the chip row — see
[603](603-the-focused-filters-controls.md). Above rather than among, because it
outranks every filter and is not one of them.

### What still belongs to a filter

Genuinely private parameters. If the shade filter wants a haze factor that nothing
else reads, that stays its own. The test is not "is it a number" but "does
anything else consult it".

### It is a position in a day, not a running clock

The hour does not advance by itself. **The time is only ever now** — see
[702](702-the-world-advances-on-a-move.md) — and moving the hour is consulting a
model rather than travelling. That is why this issue is about a value rather than
about a clock.

## Suggested implementation steps

1. Hold the hour in one place, above filters, alongside the current person.
2. Pass it to every reading that wants it, the same way the person is passed —
   explicitly, never fetched from ambient state.
3. Render its control above the chips.
4. Have any change to it invalidate the caches of readings that consulted it, and
   only those.
5. Test that moving the hour changes both the shade filter's hatching and a
   person's reported whereabouts, from the single control.

## Related documents and tools

- [The day and the curve](../docs/008-the-day-and-the-curve.md)
- [Filters and the weave](../docs/006-filters-and-the-weave.md)
