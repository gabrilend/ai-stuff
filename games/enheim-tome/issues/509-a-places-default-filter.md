# 509 — A Place's Default Filter

| | |
| --- | --- |
| Phase | 5 — Filters and the Weave |
| Blocked by | 501 |
| Blocks | — |
| Reads | [filters and the weave](../docs/006-filters-and-the-weave.md) |
| Open questions | **8** — how you change it from the interface |

## Current behavior

Selecting a place changes what the tome shows. It does not change how the map is
being looked at.

## Intended behavior

Every place carries the name of **a filter that switches on when it is selected**,
overridable per place.

### Why this is the strongest idea in the design

Because **each place teaches you how to look at it**.

Select the tannery row and it opens under trade. Select the terraced gardens and
it opens under shade. Select a block where something is wrong and it opens under
whatever is wrong there.

You are not choosing one lens and sweeping the city with it, which is what every
other map of this kind asks. The city hands you a lens per place, built from
whatever is most worth knowing there — and that is a form of authored knowledge
that costs one string per block.

### Overruling it is an act of insight

If a place opens under trade and you switch to shade, you have disagreed with the
city's own habit about itself. You knew something the place did not.

Whether the game **notices** that is a design question rather than a plumbing one,
and an interesting one: a record of where a person disagreed with the received
view of a place is close to a record of what they understand. Not decided.

### What it does not do

It does not turn other filters off. It switches its own on, into whatever mode it
declares, alongside whatever was already active. A person who has deliberately
arranged four filters should not lose that arrangement by clicking a block.

**Working ruling:** the default is added if absent and left alone if already
present; nothing is removed.

### Changing it

**Working ruling:** a button in the tome's pane that sets the currently focused
filter as this place's default. See open question 8.

### It applies at every level

A district may have one, a quadrant may have one. Since selection level follows
zoom — [408](408-the-zoom-picks-the-level.md) — selecting a district shows the
district's lens, which may be a wider question than any of its blocks would ask.

## Suggested implementation steps

1. Add the field to blocks, districts, quadrants and groups alike; absent is
   allowed and common.
2. On selection, if the place names a filter not currently active, activate it in
   its declared mode.
3. Remove nothing.
4. Add the set-as-default action to the button pane.
5. Test that selecting a place with a default activates exactly one filter and
   disturbs no other, and that selecting a place with none changes nothing.

## Related documents and tools

- [Filters and the weave](../docs/006-filters-and-the-weave.md)
- [Open questions](../docs/012-open-questions.md) — question 8
