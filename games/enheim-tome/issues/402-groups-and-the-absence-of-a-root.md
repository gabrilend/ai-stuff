# 402 — Groups, and the Absence of a Root

| | |
| --- | --- |
| Phase | 4 — The Places |
| Blocked by | 401 |
| Blocks | 403 |
| Reads | [the places of the city](../docs/003-the-places-of-the-city.md) |
| Open questions | **11** — which structures are megastructures |

## Current behavior

The chain exists but has nothing at its outer end.

## Intended behavior

The top level is a **group**, and there are two kinds, which are peers:

- **the city** — everything inside the wall that is not a megastructure
- **each megastructure** — the great circular works, one group apiece

A group has no parent. **There is no single object that everything hangs from.**

### The city is a forest, not a tree

This is the part worth being deliberate about, because almost every hierarchy
anybody has written has a root, and the instinct to add one here is strong.

The megastructures are not contained by the city they sit in. They are their own
thing, quartered on their own terms, and a person in one of them is in *it*
rather than in the city. Giving them a shared parent called "everything" would be
inventing a place nobody lives in, purely so that a walk up the chain could
terminate somewhere tidy.

The walk terminates when the parent is absent. That is sufficient, and it is
already how [401](401-the-containment-chain-is-a-list.md) works.

### Which structures are megastructures is unconfirmed

Read off the painting, and **all of these are candidates rather than facts**:

| Candidate | Where |
| --- | --- |
| the amphitheatre | west bank, mid-frame — a clean oval ring |
| the ringed colonnade | east bank — concentric arcs around a golden tree |
| the domed rotunda | the promontory between the rivers |
| the western dome | far west peninsula |
| the great willow | north-west — not a building, but the largest circular thing on the map |

The last one is a real question rather than a detail: **can a tree be a group?**
It is enormous, it is circular, it dominates its quarter of the city, and people
certainly live beneath it. If a megastructure is "a great circular work with its
own society inside", the willow may qualify without being architecture at all.

See open question 11. Until it is settled, groups are created and named by hand
rather than assumed from a list.

## Suggested implementation steps

1. A group table: name, and a kind marking it as the city or as a megastructure.
2. No root, no implicit parent, and no function that returns "the containing
   group" for a group.
3. Creating, renaming and merging groups by hand in the tracing tool — merging
   because a candidate may turn out not to be a megastructure after all.
4. Test that walking the chain from a block inside a megastructure terminates at
   that megastructure and does not continue into the city.

## Related documents and tools

- [The places of the city](../docs/003-the-places-of-the-city.md)
- [Open questions](../docs/012-open-questions.md) — question 11
