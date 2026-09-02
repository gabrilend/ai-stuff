# 910 — Naming Is the One Place Words Touch the World

| | |
| --- | --- |
| Phase | 9 — The Scene |
| Blocked by | 815, 816, 907 |
| Blocks | — |
| Reads | [the scene](../docs/010-the-scene.md) |
| Open questions | — |

## Current behavior

An axis is minted by a spark or a forcing, and arrives without a name. The scaffold
fails loudly rather than substituting a placeholder, so nothing can proceed.

## Intended behavior

**The narrator names it, and the name is a real change to the city.**

> it applies an axis to it that might be "ashen" or "consumed" - both of those
> reflect a different spirit, and the spirit is generated on-the-fly because we
> never know how something will be until we mix it up and see

Two names for the same burning are **two different spirits**. Which one arrives is
not knowable in advance; it comes out of the mixing. So an axis is never a label
sitting on top of a number — **the naming is the event**.

### This is the exception to everything in 907

[907](907-the-narrator-is-a-viewer.md) says the narrator renders nothing back, and
that is true of every other thing it does. Not this. A new name entering the
vocabulary means a new **filter** — an axis and a filter are the same record — which
gets a colour and an angle from
[816](816-a-minted-axis-needs-a-colour-and-an-angle.md) and is hatched across the
map from then on.

**So naming is generation and describing is viewing, and the same thing does both.**
They must be separate call sites, separately named, with a comment at each saying
which side of the line it is on. An exception that is not marked becomes the rule
within a year.

### What constrains a name

It has to work as a filter's name in the tome's chip row, which is small — see
[602](602-the-chip-row.md). And the colour rule requires that the name carry the
meaning on its own, since colour may never carry a fact the words do not.

A name is therefore short, concrete, and about the thing rather than about the
event that made it. *Ashen*, not *burned by someone in the night*.

### It must be stable

The same name must never be minted twice as two different axes, and an axis's name
never changes once minted. A renamed axis would silently become a different filter
and every reading of it in history would be attached to the wrong thing.

## Suggested implementation steps

1. Give the narrator a second entry point for naming, distinct from the one that
   produces prose, and comment both with which side of the generation-viewing line
   they sit on.
2. Take the mixing that produced the axis as the input — what met what, in what
   place, under what circumstances.
3. Check the result against every existing axis name and reject a collision rather
   than merging two different things under one word.
4. Record the minting in the actor's history per
   [905](905-history-is-append-only.md), with the name and what it came out of.
5. Fail loudly if the narrator is unavailable at minting time. There is no
   placeholder name that would be honest.
6. Test that a name, once minted, is never rewritten by any later operation.

## Related documents and tools

- [The scene](../docs/010-the-scene.md)
- [815 — forcing a closed thing open](815-forcing-a-closed-thing-open.md) — one source of a minting
- [816 — a minted axis needs a colour and an angle](816-a-minted-axis-needs-a-colour-and-an-angle.md) — what else a new axis needs
