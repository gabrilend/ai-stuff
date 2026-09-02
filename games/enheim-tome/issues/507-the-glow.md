# 507 — The Glow

| | |
| --- | --- |
| Phase | 5 — Filters and the Weave |
| Blocked by | 205, 504 |
| Blocks | 508, 703, 705 |
| Reads | [the map surface](../docs/002-the-map-surface.md) |
| Open questions | — |

## Current behavior

Nothing marks the selected place. You find out what is selected by reading the
tome.

## Intended behavior

Warm light lifting a place's interior, breathing slowly.

| Property | Value | Why |
| --- | --- | --- |
| **additive light** | not a coloured tint | a tint reads as one thing over harbour blue, another over slum brown, another over garden green; added light brightens all three the same |
| **breathing** | about thirty percent to full | so it reads as alive rather than as a static highlight |
| **period** | around two and a half seconds | slow enough to be breathing rather than blinking |
| **floor** | never below about thirty percent | so a glowing place never disappears |

The floor is the detail that makes it usable: a highlight that pulses to nothing
is one you keep losing, and one you have to wait for is one you distrust.

### It means exactly one thing

**This one.** That is the whole of its meaning, and it is used in more than one
place without ever meaning anything else:

- the place you have selected
- the place a swept time-curve is pointing at — see [705](705-sweeping-drives-the-hour.md)

Because it means one thing, nothing new had to be added to the map when the
question of *where you are* arrived: the whereabouts equation returns a block, and
that block glows. The map's four marks stayed four. See
[703](703-whereabouts-is-a-function.md).

**Resist giving it a second meaning.** The moment it also indicates danger, or
ownership, or anything else, it stops answering *which one* and the map loses its
only unambiguous mark.

### Where it sits in the order

Last, over the cage and every filter — [504](504-the-three-modes-and-the-order.md).
It must be visible whatever is drawn beneath, since its job is to answer a
question the person is asking right now.

### The tunables

Period, floor and warmth from `input/what-to-start-with`. Breathing rates are
felt rather than reasoned about, and a value that seems right in isolation often
reads as agitated once the rest of the interface is moving.

## Suggested implementation steps

1. Fill the selected place's shape — from the identity buffer or its boundary walk
   — with additive light.
2. Modulate intensity by a slow oscillation between the floor and full.
3. Draw after everything else on the map.
4. Take the shape from whichever level is selected, so glowing a district lights
   the district rather than one of its blocks.
5. Check by eye over the harbour, the slums and the terraced gardens that the same
   glow reads the same on all three — that is the test that additive was the right
   choice.

## Related documents and tools

- [The map surface](../docs/002-the-map-surface.md)
- [The day and the curve](../docs/008-the-day-and-the-curve.md)
