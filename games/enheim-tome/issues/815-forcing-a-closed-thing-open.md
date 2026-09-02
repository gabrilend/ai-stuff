# 815 — Forcing a Closed Thing Open

| | |
| --- | --- |
| Phase | 8 — The Scaffold |
| Blocked by | 808, 810 |
| Blocks | 910 |
| Reads | [the scaffold](../docs/009-the-scaffold.md) |
| Open questions | — |

## Current behavior

A place that is closed stays closed forever, so most of the city can never develop
a nature at all. The only source of a new axis is two closed actors with intent.

## Intended behavior

**A closed thing can be made open by an act done to it, and the forcing itself
mints an axis.**

> if someone walks into a sacred grove and burns it down, then it forces the grove
> to enter the "open" state, and it applies an axis to it that might be "ashen" or
> "consumed"

```
the grove:   |   closed forever
                 ↓  burned
            |.|  forced
                 ↓
             O   open, and now it receives
                 ↓
             O   carrying an axis it never held
```

This is the second of the two ways an axis is minted, and the only one that needs
no second actor.

### The word is the thing, and it is generated rather than chosen

> both of those reflect a different spirit, and the spirit is generated on-the-fly
> because we never know how something will be until we mix it up and see

Two names for the same burning are **two different spirits**. Which one arrives is
not knowable in advance; it comes out of the mixing. So an axis is never a label
sitting on top of a number — **the naming is the event**, and it is the one place
where words touch the world. See [the scene](../docs/010-the-scene.md).

### Forcing is the most powerful act in the city, and nobody designed that

Impact runs inverse to how much of the day a thing spends open —
[810](810-open-and-closed-are-a-line-on-the-curve.md). Most buildings are closed
**all the time**. So in the limit, a thing that has never once been open has
unbounded impact the single time it is forced.

**The sacred grove is maximally consequential precisely because it had never
opened before.**

The arithmetic therefore hands the city a cheap violent path and an expensive
patient one, and says outright that the violent one works better. That was not put
there. It fell out of the impact ratio meeting *most buildings are closed*, and it
should be left alone rather than balanced away — it is the truest thing the model
says about a rigid city.

### It is also how a place develops a nature at all

Since a closed place never adopts, and most places are closed, forcing is the
mechanism by which the city's vocabulary can grow anywhere other than in its
already-open squares and markets. *Created on-demand for the developing nature of
the place* needs this ticket to have a mechanism at all.

## Suggested implementation steps

1. Define an act as something done to a closed actor, distinct from a gathering.
2. On forcing, flip the status to open and mark the actor as changing — the `(.)`
   and `|.|` glyphs from [810](810-open-and-closed-are-a-line-on-the-curve.md)
   exist for exactly this moment.
3. Mint an axis from the forcing and attach it. The name comes from phase 9; until
   then, fail loudly rather than substituting a placeholder word.
4. Record the minting in the actor's history — see
   [the scene](../docs/010-the-scene.md) — since a minting is one of the three
   kinds of entry.
5. Report the impact of a forcing as a measured number, so the claim that forcing
   a never-open thing is enormous can be checked rather than believed.
6. Test that a forced actor subsequently adopts blends it previously ignored.

## Related documents and tools

- [The scaffold](../docs/009-the-scaffold.md)
- [810 — open and closed are a line on the curve](810-open-and-closed-are-a-line-on-the-curve.md) — the impact ratio
- [The scene](../docs/010-the-scene.md) — where the name comes from
