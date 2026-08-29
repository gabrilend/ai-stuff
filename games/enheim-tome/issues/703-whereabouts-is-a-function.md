# 703 — Whereabouts Is a Function

| | |
| --- | --- |
| Phase | 7 — The Day |
| Blocked by | 507, 701 |
| Blocks | 704 |
| Reads | [the day and the curve](../docs/008-the-day-and-the-curve.md) |
| Open questions | — |

## Current behavior

Nobody is anywhere.

## Intended behavior

Where a person is, is **a reading taken at a time** rather than a position the
game stores and moves.

```
   whereabouts(person, hour) → a block
                            or a description of what they are doing
```

### Why a function and not a stored position

Because it makes whereabouts the same shape as the shade filter — both are
readings of the hour — which is what lets one control move both together. And
because a stored position would need updating, which would mean something
advancing time, which the design does not have.

### Two kinds of answer, and neither needs a new mark on the map

When it returns **a block**, that block glows. The glow already means *this one*
and needs no new meaning — see [507](507-the-glow.md). **The map's four marks stay
four.**

This is worth dwelling on. *Where you are* looked like it would need a fifth thing
on a map that had been argued down to four. It turned out not to, because the
answer is a place and there was already a way to point at a place.

The rule that produced that: **before adding a mark, ask whether an existing one
already answers this.**

When it returns **a description of what they are doing** — the hour has landed
inside an activity rather than at a location — that is words, so it goes in the
tome's text pane and nowhere else.

### It is per person, like everything else

Different people, different days. So this composes with switching person: taking
somebody up changes where *you* are, because the equation is theirs. See
[510](510-switching-person-repaints.md).

### What the equation actually is

Mechanics, and not decided. This issue builds **the shape** — a function of person
and hour returning a place or a doing — against something simple, so that the
interface it feeds can be built and the real equation can be substituted without
anything downstream changing.

## Suggested implementation steps

1. Define the function's shape, returning either a place or a description.
2. Implement a placeholder — a handful of hand-written days for fixture people.
3. Have the map glow the block when the answer is a place.
4. Have the tome show the description when it is a doing.
5. Never cache the result across an hour change.
6. Test that moving the hour moves the glow, and that the case returning a doing
   glows nothing rather than glowing the last known place — which would be a
   quiet lie about where somebody is.

## Related documents and tools

- [The day and the curve](../docs/008-the-day-and-the-curve.md)
- [The map surface](../docs/002-the-map-surface.md)
