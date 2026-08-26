# 1103 -- A second view, in a terminal

**Phase:** 11, the second view and the documentation
**Blocked by:** [1101](1101-the-paintbrush-travels-as-numbers.md)
**Blocks:** [1107](1107-the-phase-eleven-demo.md)
**Documents:** [the three programs](../../docs/002-the-three-programs.md)

## Current behaviour

**Done.** `102-watch` joins through the door, decodes the same instruction
stream, and draws to a character grid.

The same switch the browser has, in a different language, over the same numbers.
That is what "the same protocol" means when it is true rather than claimed.

It draws walls with the canvas from
[1002](1002-the-canvas-that-joins-its-own-lines.md) -- axis-aligned ones as
strokes so their corners join, diagonals as slashes, because strokes have no
diagonal and pretending otherwise produces junctions that are wrong in a way
somebody would have to squint at. Bodies are one glyph, chosen from the sprite's
own first layer, coloured with that layer's colour.

It says what it is not, at startup: it sends nothing, and a sprite is six layers
where a terminal has one character, so the drawing is reduced and the data is
not.

### The constraint held, and it found something

**No server change was needed to make the second view work.** One was needed
because of what it found.

The hello -- who you are and how big the world is -- was written once, when
somebody joined, into a buffer that `059-outbound` clears at the top of every
beat. It never arrived. The browser had been running for six phases without ever
receiving one; it defaulted to body zero, which is nothing, so it never
highlighted anybody's own body and nobody noticed.

A terminal cannot draw a map at all without the extent, so this found it in its
first run against a live server.

**That is a phase four defect, not a phase eleven requirement.** It is recorded
here because this is where it was found, and the fix is the protocol's own
principle applied consistently: an update is the whole picture, so anything that
must reach a viewer is *in* the update. Twenty-one bytes a beat, and it cannot go
missing again.

### One thing added to the server that is not a defect

`--place` and `--seed`. The server could only ever run the hand-built two-room
fixture, and two views watching an empty room is a poor demonstration of two
views. It generates now.

That is one line of `input/what-to-start-with` honoured out of seven, and open
question 16.1 is where the other six are written down.

## Intended behaviour

A second view that draws the same session in a terminal, **speaking the same
protocol, with no server changes at all.**

### That constraint is the entire point

If the terminal view needs one line of the server changed, the protocol was never
a protocol -- it was the browser's interface with extra steps. This is the
generate-then-view split tested at the last boundary, and it is the only test of
it that cannot be faked, because the second consumer is written months later by
somebody who was not in the room when the first one was.

**Any change the server needs is a bug in phase 4, not a requirement of phase 11.**
If one turns up, it gets written down as exactly that.

### It is a client, not a bridge

It knocks on the door itself and holds its own private port. It does not go
through the bridge, because the bridge exists to serve a browser and a terminal
does not need serving.

### What it draws

The walls it is allowed to know about, the things it can see, and its own
visibility fan -- the same three things the browser draws, from the same
instructions. Box-drawing characters for walls, a glyph per thing chosen from the
sprite's own first layer, and the fog as dimmed ground.

A sprite becomes a character and a colour. That is a lossy rendering of the
paintbrush and it is honest about being one: the terminal has one glyph where the
browser has six layers, so it draws the body and says so.

### It says what it is not

A view that silently cannot show something is a view that lies. Where the
terminal cannot render a thing -- a sprite with more layers than a character can
carry -- it is the drawing that is reduced, never the data, and the program says
so once at startup rather than pretending.

## Suggested implementation steps

1. Join through the door as a client, the way the bridge does.
2. Decode the same instruction stream.
3. Draw to a character grid -- the one from
   [1002](1002-the-canvas-that-joins-its-own-lines.md) already exists
   and already joins its own lines.
4. Colour with ANSI, and work without it.
5. Change nothing in the server. If something has to change, record it as a phase
   4 defect.
