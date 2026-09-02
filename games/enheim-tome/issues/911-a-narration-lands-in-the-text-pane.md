# 911 — A Narration Lands in the Text Pane

| | |
| --- | --- |
| Phase | 9 — The Scene |
| Blocked by | 606, 908 |
| Blocks | — |
| Reads | [the scene](../docs/010-the-scene.md), [the tome](../docs/007-the-tome.md) |
| Open questions | **21** — how long a narration is |

## Current behavior

Narrations are produced and go nowhere.

## Intended behavior

**The tome's scrolling text pane, and nowhere else.**

[The map surface](../docs/002-the-map-surface.md) forbids text on the painting
entirely — no labels, no tooltips, no place names. That is not a stylistic
preference: the painting is already at maximum visual density, and refusing text
means label collision never has to be solved at all.

So there is exactly one surface in this game that carries words, and this is more
of what goes on it. Nothing new is built; the pane from
[606](606-the-text-pane.md) already scrolls and already holds prose.

### Which narration, and when

A scene belongs to a place and an hour. The pane shows the narrations for **what
you have selected**, which is how everything else in the tome already works — see
[607](607-descending-to-a-person.md).

Since a scene exists only where something changed
([904](904-a-scene-exists-only-where-something-changed.md)), most places most of
the time have nothing to show, and the pane holds whatever else it holds. An empty
stretch is not a gap.

### How long is undecided

The pane is roughly 420 pixels wide. A sentence, a paragraph and a page are three
different games — the first is a log, the last is a novel nobody asked for. See
question 21.

What is already decided is the register. The rule that governed the old event
system survives its replacement, because it was never about events:

> Just keep it from becoming a massive story. People live in cities, so what?

A scene is two people in a bakehouse before dawn. The variety comes from there
being enormously many of them, not from any one being remarkable.

## Suggested implementation steps

1. Render narrations into the existing text pane. Add no new surface.
2. Show them for the selected place, ordered by hour, most recent first.
3. Read the length target from `input/what-to-start-with` so it can be changed
   without touching the source while question 21 is open.
4. Test that no narration text ever reaches the map pane, at any zoom or selection.

## Related documents and tools

- [The tome](../docs/007-the-tome.md)
- [606 — the text pane](606-the-text-pane.md) — the surface this fills
- [The map surface](../docs/002-the-map-surface.md) — why there is only one such surface
- [Open questions](../docs/013-open-questions.md) — question 21
