# 102-watch

A second view of the same session, in a terminal.

## The constraint is the point

**It speaks the same protocol the browser does, and the server does not know the
difference.** If a terminal view needed one line of the server changed, then the
protocol was never a protocol — it was the browser's interface with extra steps.

This is the generate-then-view split tested at the last boundary, and it is the
only test of it that cannot be faked, because the second consumer is written
months later by somebody who was not in the room when the first one was.

It knocks on the door itself and holds its own private port. It does not go
through the bridge: the bridge exists to serve a browser, and a terminal does not
need serving.

## What it found

Writing it found a defect that had been in the project since phase four.

The hello — who you are and how big the world is — was written once, when
somebody joined, into a buffer that `059-outbound` clears at the top of every
beat. **It never arrived.** The browser had been running for six phases without
ever receiving one; it defaulted to body zero, which is nothing, so it simply
never highlighted anybody's own body and nobody noticed.

A terminal cannot draw a map at all without the extent, so this found it in its
first run against a live server. That is what a second consumer is for. It is a
phase four defect rather than a phase eleven requirement, and the fix is the
protocol's own principle applied consistently: an update is the whole picture, so
anything that must reach a viewer is *in* the update.

## What it is not

**It does not send commands.** It watches. A view that silently could not do
something would be a view that lies, so it says so at startup rather than leaving
somebody pressing keys at it.

## What it loses

A sprite is six layers and a terminal has one character per body. It draws the
body layer's shape as a glyph and its colour as the colour, and drops the rest.

| Shape | Glyph |
| --- | --- |
| circle | `o` |
| rect | `#` |
| triangle | `A` |
| ring | `0` |
| wearing nothing | `*` |

That is a lossy rendering of the paintbrush, and **it is the drawing that is
reduced, never the data** — the same instructions arrive here as arrive at the
browser.

## How it draws

Walls go onto the grid from [092-canvas](092-canvas.info.md), which already joins
its own lines. Axis-aligned walls are strokes, so their corners come out right; a
diagonal is drawn with slashes instead, because strokes have no diagonal and
pretending otherwise produces junctions that are wrong in a way somebody would
have to squint at.

Characters are about twice as tall as they are wide, so everything horizontal is
stretched by two. That is the one piece of arithmetic a terminal renderer has
that a pixel one does not.

The cursor is homed rather than the screen cleared, so the picture does not flash
every beat.

## Running it

| Invocation | Does |
| --- | --- |
| `102-watch 127.0.0.1 <door> <name>` | joins and draws until interrupted |
| `... --plain` | no colour, for a log rather than a screen |
| `... --beats N` | stops after N updates, which is what a demo needs |

It reports what it received: updates, bytes, and how many of those bytes were
appearances. Measured rather than assumed.

## Related

- [056-protocol](056-protocol.info.md) — the instructions it decodes
- [061-door](061-door.info.md) — how it joins
- [067-view.js](067-view.js) — the other view, the same switch in another language
- issue [1103](../issues/completed/1103-a-second-view-in-a-terminal.md)
