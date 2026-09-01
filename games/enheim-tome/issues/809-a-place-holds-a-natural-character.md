# 809 — A Place Holds a Natural Character

| | |
| --- | --- |
| Phase | 8 — The Scaffold |
| Blocked by | 807, 808 |
| Blocks | 811 |
| Reads | [the scaffold](../docs/009-the-scaffold.md) |
| Open questions | — |

## Current behavior

Actors have characters. Every one of them starts empty, so nothing differs from
anything and no exchange can ever produce anything.

## Intended behavior

**Every place carries a character before anybody visits it**, made of physical
facts that do not move: on the water, in the willow's shadow, backed onto the
wall, steep, stone.

### This is the seed the entire system needs

Without it the design cannot start. Character flows from actor to actor, so if
every actor begins identical there is nothing to flow and nothing to strike sparks
against. Something has to differ first.

**The seed is geography.** Because places differ naturally, the people formed by
them differ on the morning the game opens — and not one person had to be authored
to make that true.

### It is what a place reverts toward, and what it keeps

A place's natural character is never lost and never overwritten. When a place is
open and adopts the blend of who is in it — see
[812](812-the-closed-give-and-the-open-adopt.md) — its natural character is one
share of that blend, so it persists at `1 / (N + 1)` forever rather than being
diluted away.

And since **most buildings are closed all the time**, most of them never adopt
anything at all. Their natural character is not a starting point they grow out of;
it is what they are, permanently, until something forces them open.

### It is authored, and it is the only thing here that is

The rest of the scaffold computes. This does not — natural character is read off
the painting by a person looking at it, which makes it part of the map bundle in
[312](312-a-map-is-a-bundle.md) and something
[309](309-the-coverage-report.md) counts.

That is a small authoring job and it should stay small. A place with no natural
character stated is a place nobody has looked at yet, not an error.

## Suggested implementation steps

1. Add natural character to the place record, in the same sparse-map form as
   [808](808-character-is-a-sparse-map-of-axes.md).
2. Keep it separate from accumulated character. They blend, but they are not the
   same field, because one is authored and one is derived.
3. Have the map bundle carry it and the coverage report count places without it.
4. Test that a closed place's character never drifts from its natural character,
   however many gatherings happen in it.

## Related documents and tools

- [The scaffold](../docs/009-the-scaffold.md)
- [312 — a map is a bundle](312-a-map-is-a-bundle.md) — where it is distributed
- [309 — the coverage report](309-the-coverage-report.md) — which counts it
