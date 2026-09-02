# 912 — A Missing Narrator Fails Loudly

| | |
| --- | --- |
| Phase | 9 — The Scene |
| Blocked by | 907 |
| Blocks | — |
| Reads | [the scene](../docs/010-the-scene.md), [the shape of the code](../docs/011-the-shape-of-the-code.md) |
| Open questions | **20** — when the narrator runs |

## Current behavior

The narrator is the only part of this design that reaches outside the machine. When
it is unavailable, nothing says what should happen.

## Intended behavior

**Say so, loudly, and show the scene record.** Never invent text quietly, and never
substitute a canned sentence.

[The shape of the code](../docs/011-the-shape-of-the-code.md) states the rule this
follows from:

> Where a fallback genuinely exists it must announce itself every time it is used,
> and an issue file must exist to remove it. A fallback nobody has noticed is a bug
> that has been running for months.

A generic sentence standing in for a narration is exactly that kind of bug. It
reads like prose, it is indistinguishable from a real narration at a glance, and
the city would appear to be telling you about itself while saying nothing.

### Showing the record is the honest fallback

The scene record is complete enough to narrate from
([902](902-a-scene-record.md)), which means it is complete enough to **read**. Who
was there, what was in play, what moved. It is not prose and it should not pretend
to be — a reader seeing fields rather than sentences knows exactly what has
happened.

That is the difference between a fallback that announces itself and one that
hides.

### It is not an error state

The city runs headless by design ([907](907-the-narrator-is-a-viewer.md)), so an
absent narrator is a **degraded view**, not a broken simulation. Nothing stops, no
axis fails to move, and no scene is lost. Only the words are missing, and they were
always the disposable half.

### Naming is the exception, again

A missing narrator at **minting** time is different, and it is a hard stop. There
is no placeholder name that would be honest, because the name *is* the axis — see
[910](910-naming-is-the-one-place-words-touch-the-world.md). Failing loudly there
means refusing to mint, not minting something called *unnamed*.

## Suggested implementation steps

1. Detect unavailability at the boundary and report it once per session with what
   happened, why, and what to run — not once per scene, which is noise.
2. Render the scene record into the text pane in place of prose, visibly formatted
   as a record.
3. Keep simulating. Nothing about the city depends on the words.
4. Refuse to mint an axis without a name, and say so.
5. Test the whole degraded path: a day simulated with the narrator unreachable
   must produce identical city state and a visible notice.

## Related documents and tools

- [The scene](../docs/010-the-scene.md)
- [The shape of the code](../docs/011-the-shape-of-the-code.md) — announcing fallbacks
- [910 — naming is the one place words touch the world](910-naming-is-the-one-place-words-touch-the-world.md) — where absence is a hard stop
- [Open questions](../docs/013-open-questions.md) — question 20
