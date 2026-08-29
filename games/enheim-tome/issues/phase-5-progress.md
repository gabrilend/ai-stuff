# Phase 5 — Filters and the Weave

Ways of looking at the city, drawn over it.

**Ten issues. None complete. Nothing has been built.**

| Issue | State |
| --- | --- |
| [501 — what a filter is](501-what-a-filter-is.md) | not started |
| [502 — a reading takes a person](502-a-reading-takes-a-person.md) | not started |
| [503 — nothing is a value](503-nothing-is-a-value.md) | not started |
| [504 — the three modes, and the order](504-the-three-modes-and-the-order.md) | not started |
| [505 — the weave](505-the-weave.md) | not started |
| [506 — hatching anchored to the ground](506-hatching-anchored-to-the-ground.md) | not started |
| [507 — the glow](507-the-glow.md) | not started |
| [508 — the glow flips to aiming](508-the-glow-flips-to-aiming.md) | not started — open question 3 |
| [509 — a place's default filter](509-a-places-default-filter.md) | not started — open question 8 |
| [510 — switching person repaints](510-switching-person-repaints.md) | not started |

## The change that cost one argument

A way of looking reads a place **for somebody**. That was always true and merely
unstated — the map was never the city, it was one person's picture of it — and
writing it down is the entire mechanism by which you can take up anybody in the
city and see what they see.

The discipline it demands: **no call may obtain a reading without naming whose it
is.** The moment one can, character switching is quietly gone and it is a long way
back.

## The subsystem that stopped existing

A reading may answer **nothing**, which is different from zero. Zero means known
to be low; nothing means no idea, and it draws as bare painting.

That deletes fog of war, discovery flags, confidence channels and greyed-out
unknown states — all of it. The trap it leaves behind is a cache initialised to
zero, after which every unvisited place claims to be known and low, and the map
lies in a way that looks entirely plausible.

## Why weaving and not stacking

Two hatchings stacked bury one; at three it is mud, and the buried filters are
still being drawn, which is worse than not drawing them because the person
believes they are seeing three things.

Weaving shares the **crossings** rather than ordering the **layers** — sum the
line indices at a crossing, modulo how many cross there, and that picks the
winner. Every filter gets an equal share of the overs, so it still reads at four.

## The tension left in the hatching

It must not swim when you pan, which means computing from painting coordinates. It
must stay legible at every zoom, which means spacing derived from screen pixels.
The resolution is locked during panning and breathing slightly during zooming —
the right way round, since panning is constant and zooming is occasional.
