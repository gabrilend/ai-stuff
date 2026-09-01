# 806 — Houses Fill In Forever

> **Superseded.** Kept for the record rather than deleted &mdash; see
> [phase 8 progress](../phase-8-progress.md) for what replaced it and why, and
> [the scaffold](../../docs/009-the-scaffold.md) for the design that stands now.
>
> The writing campaign this plans does not exist. Twenty to forty thousand house
> facts were priced at two to four years, and none of them are needed.

| | |
| --- | --- |
| Phase | 8 — Events, and What Is Known |
| Blocked by | 805 |
| Blocks | — |
| Reads | [the scaffold](../../docs/009-the-scaffold.md) |
| Open questions | — |

## Current behavior

Every block has an event. Houses have none.

## Intended behavior

**A house with no event yet simply has nothing hidden in it.** Not an error, not a
gap, not a placeholder. The game is complete without them and deepens with them,
for as long as anybody keeps writing.

### Why this is the only version that ships

Twenty to forty thousand house events is two to four years of unbroken writing.
Waiting on that would mean nobody plays for years, including the author — and an
author who has not played their own game for two years is an author who stops.

Filling in forever means the game is playable in months and keeps getting denser
for a decade. Nothing is ever blocked on the writing.

### The cost, stated honestly

Early on, most houses are empty of secrets, and **that emptiness is visible**.

It looks exactly like a city you have not finished learning — which is close
enough to the intended feeling that it may not read as a gap at all. But it is a
real cost and should not be waved away: a player who searches five houses and
finds nothing in any of them has learned something about the corpus rather than
about the city.

That argues for **the first houses written being clustered**, so that at least
some neighbourhoods are dense from the start and the texture of a fully written
quarter exists to be found, rather than a thin scatter everywhere that is
uniformly disappointing.

### What must never happen

**Nothing may treat an absent event as an error, a warning, or a to-do.** Not the
validator, not the coverage report's exit code, not any check that could fail a
build.

The coverage report counts them as *work remaining*, which is a different thing
from work *outstanding* — one is a plan, the other is a debt. Over a decade, a
tool that nags about forty thousand missing items is a tool somebody turns off,
and with it goes the reporting that made the campaign legible.

### The same shape appears elsewhere

Buildings' own facts fill in on identical terms — see
[406](../406-a-building-and-its-facts.md). So does naming intersections.

That is worth naming as the project's general posture on hand-authored content:
**a place with nothing recorded is a place nobody has looked into yet.** The city
is always partly unwritten, and the program must be comfortable with that
permanently rather than treating it as a state to be escaped.

## Suggested implementation steps

1. Confirm every query tolerates a house, building or block with no events, and
   returns absence rather than an empty structure that reads as zero — see
   [503](../503-nothing-is-a-value.md).
2. Extend the worklist from [805](805-one-event-per-block.md) to houses, ordered
   to cluster within a building and then within a block.
3. Report house coverage as remaining work with a projected rate, never as a
   failure.
4. Ensure no check anywhere fails on an absent house event.
5. Test that a city with block events and no house events plays identically to one
   with both, apart from what is found.

## Related documents and tools

- [the scaffold](../../docs/009-the-scaffold.md)
- [The places of the city](../../docs/003-the-places-of-the-city.md)
