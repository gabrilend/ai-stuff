# 610 — The Interior Frame

| | |
| --- | --- |
| Phase | 6 — The Tome |
| Blocked by | 601, 607 |
| Blocks | — |
| Reads | [the tome](../docs/007-the-tome.md) |
| Open questions | — |

## Current behavior

Nothing shows the inside of anything.

## Intended behavior

A place for a staged view of a room to appear. **An empty frame for now** — nothing
generates interiors, and that is parked deliberately.

An interior is neither a mark on the map nor a line of text, so it needs a home of
its own. All three placements are valid and the player picks:

| Placement | What it costs |
| --- | --- |
| **in the scrolling pane** *(preferred)* | the map stays visible so you never lose your place, but at around 420 pixels wide it is a thumbnail of a room rather than a photograph |
| replacing the map pane | full size, tome untouched, but the city is gone while you are indoors |
| the whole window | biggest, and every control is gone while looking |

### Why build the frame before there is anything to put in it

Because where a picture goes changes the shape of the interface, and the shape of
the interface is what this phase is. Deciding it now, with three placements
supported and a preference set, means the generator — whenever it exists — has
somewhere to deliver to rather than prompting a redesign.

It also keeps the decision honest. Building it later, under pressure to show
something, is how a fourth region gets bolted onto a tome that was carefully
argued down to three.

### What such a view will have to show

Recorded so it is not lost by the time it matters — from
[the places of the city](../docs/003-the-places-of-the-city.md):

Built haphazardly, nothing like an apartment now. Railings and bannisters and
banners everywhere. **Vaulted ceilings, commonly twenty feet.** Wooden beams hung
from them on chains, and from those beams things arranged at whatever height you
please.

**The interior is used vertically.** A room here is not a floor plan with
furniture on it; it is a tall volume with things hanging in it at chosen heights.
Anything that generates one must start there or it will produce rooms from the
wrong century.

### What is parked, and the one thing already settled about it

Generation is a separate project, plausibly larger than this one, consuming this
one's output rather than being part of it.

Its one settled requirement: **build a model and render it from several angles,
rather than generating several pictures independently.** Independently generated
views of one room do not agree — the window moves, the chairs change number, the
person is dressed differently — while renders of one model agree by construction.
The same reasoning that made blocks faces of a shared network.

## Suggested implementation steps

1. Define an interior view as a rectangle plus a source of images, with nothing
   behind it yet.
2. Implement all three placements; make the placement a setting.
3. Default to the scrolling pane.
4. Show a plain, honest placeholder — not a spinner, not a fake room — so that
   "nothing has been generated" reads as itself.
5. Test that switching placement moves the frame and disturbs neither the map's
   view nor the tome's scroll.

## Related documents and tools

- [The tome](../docs/007-the-tome.md)
- [The places of the city](../docs/003-the-places-of-the-city.md)
- [Roadmap](../docs/012-roadmap.md) — what is deliberately absent
