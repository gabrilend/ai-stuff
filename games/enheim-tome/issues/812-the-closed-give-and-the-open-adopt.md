# 812 — The Closed Give and the Open Adopt

| | |
| --- | --- |
| Phase | 8 — The Scaffold |
| Blocked by | 810, 811 |
| Blocks | 813, 814, 903 |
| Reads | [the scaffold](../docs/009-the-scaffold.md) |
| Open questions | — |

## Current behavior

A gathering can be computed and blended. Nothing decides who is changed by it.

## Intended behavior

One rule, and it is one line:

> **The closed broadcast. The open absorb.**

- **Open actors adopt the blend.** They become it.
- **Closed actors keep what they had**, and keep contributing it.

There is no pairwise table. A crossing is not between two people — it is a pool,
drained in one direction, with everybody present in it at once.

### Why there are no four cells

The obvious shape is a dispatch on two statuses: open-open, open-closed,
closed-open, closed-closed. That shape is wrong, and it is worth saying why so
nobody rebuilds it.

Exchange is **unconditional**. It is always happening between everything present,
and the status only sets direction. So there is nothing to dispatch on — you
compute one blend from everyone, and then each actor either takes it or does not.
Four cells would be four ways of writing the same two lines.

What *is* genuinely different is two closed actors with intent, and that is not
transfer at all. It is [813](813-two-closed-actors-make-an-arc.md).

### What this makes literal

[The places of the city](../docs/003-the-places-of-the-city.md) says its whole
design is one line from the vision: *the building is stone, and can't adjust
easily, meaning it's what roots people.*

Put this rule beside [810](810-open-and-closed-are-a-line-on-the-curve.md) and it
stops being figurative. Stone is closed, so it gives and never receives. A person
is open when at rest, and a person rests at home. **So the only hours anybody can
be changed at all are the hours spent inside a building broadcasting at them that
cannot be broadcast back at.** You become the architecture during the only hours
you are able to become anything.

That is the rigidity the whole game is about, and no rule was written to produce
it. It is two rules touching.

### And why most of the city never changes

A closed room does not adopt. Most buildings are closed all the time, so most
buildings hold their natural character forever and impose it on everyone who rests
in them. **Only a place that is open develops a nature at all** — which is what
makes [815](815-forcing-a-closed-thing-open.md) the significant act it is.

## Suggested implementation steps

1. Compute the blend once per gathering, from every actor present including the
   room and including each actor itself.
2. Assign the blend to every open actor; leave closed actors untouched.
3. Record what moved, per actor, per axis — that record is the input to phase 9
   and must exist before any words are asked for. See
   [the scene](../docs/010-the-scene.md).
4. Do not write a status-pair dispatch table. If one appears, the pooling rule has
   been misread.
5. Test that a closed actor's character is bit-identical before and after a
   gathering of any size.
6. Test that a lone person in a closed room moves exactly halfway toward it.

## Related documents and tools

- [The scaffold](../docs/009-the-scaffold.md)
- [811 — the gathering is one share of N plus one](811-the-gathering-is-one-share-of-n-plus-one.md)
- [The places of the city](../docs/003-the-places-of-the-city.md) — the stone that roots people
