# 1101 -- The paintbrush travels as numbers

**Phase:** 11, the second view and the documentation
**Blocked by:** phase 10 complete.
**Blocks:** [1102](1102-the-browser-draws-what-it-is-sent.md),
[1103](1103-a-second-view-in-a-terminal.md)
**Documents:** [the dynamic picture](../../docs/012-the-dynamic-picture.md),
[what a viewer may know](../../docs/009-what-a-viewer-is-allowed-to-know.md)

## Current behaviour

**Done.** `OP_LAYER` carries one layer -- which thing, which layer, the shape, the
colour, two offsets and a radius -- and the thing instruction gained a motion
slot. Seven numbers and one number; nothing else was needed.

The colour goes on the wire rather than the palette slot it came from, so a view
needs no palette and no lookup.

The offsets are signed bytes sent through unsigned slots, the same way a
coordinate is. A reader sign-extends; a reader that forgets draws every detail on
one side, which is loud rather than subtle.

The sprite is rebuilt in `059-outbound` from the two fields the thing already
carries, so nothing new is stored and a world file already holds everything
needed. It goes out through the same function that is the only thing allowed to
write a thing to a socket, after the same four gates -- **seeing what a goblin
looks like requires seeing the goblin**, which is not a new rule but the existing
one applied to a new field.

Two tests, and the second is the one worth having: a body wearing nothing sends
no appearance, counted as a *difference* rather than a flat count, because the
fixture's own things wear faces and a flat count would be measuring them.

### Measured, not assumed

Six instructions per visible thing per beat, twelve bytes each. In a generated
inn with four visible bodies that is about 265 bytes an update out of 3,200 --
between one and eight per cent depending on how much of the map is remembered.
The visibility fan is far larger. Reported by both the demo and the terminal
view rather than estimated here.

## Intended behaviour

A thing's appearance reaches the viewer, **as numbers on the existing wire**.

### Why numbers and not the other two options

The paintbrush is a closed set of moves and every one of them is a small integer:
at most six layers, each a shape, a colour, two offsets and a radius, plus one
motion for the whole sprite. So it fits the protocol this project already has.

| Alternative | Why not |
| --- | --- |
| Port the generator to JavaScript | A second implementation that must agree byte for byte, over 64-bit arithmetic JavaScript does not have without BigInt. Two generators that disagree produce two different pictures and no error anywhere. |
| Send the SVG text | The protocol has fixed-width numeric slots and no byte strings. Adding one is a large change to the single place that decides what a viewer may know. |

Sending the layers makes a view a **renderer of the paintbrush** rather than a
second copy of the generator. That is the same division the project uses
everywhere else: generate here, view there.

It also means the terminal view and the browser view get appearances from the
same instructions, which is what makes [1103](1103-a-second-view-in-a-terminal.md)
possible at all.

### The colour goes on the wire, not the palette slot

A layer names its colour directly. The view needs no palette and no lookup, and
a slot number would be a second thing to keep in step for no gain — the view is
not going to re-tint anything.

### It goes through the one door

The appearance is written by the same function that is the only thing allowed to
write a thing to a socket, after the same four gates. **Seeing what a goblin
looks like requires seeing the goblin**, and that is not a new rule — it is the
existing rule applied to a new field.

### Every update carries it

An update is the whole picture, not a difference, because that is what makes a
dropped update harmless. An appearance is part of the picture.

The cost is real and should be measured rather than assumed: six layer
instructions per visible thing per beat. Report it in the demo.

## Suggested implementation steps

1. A layer opcode in the outbound table, and a motion slot on the thing opcode.
2. `viewpoint_gather` and the outbound writer carry the sprite.
3. The sprite comes from the thing's own category and seed, so nothing new is
   stored and a world file already holds everything needed.
4. Test: a viewer who cannot see a thing is told nothing about its appearance,
   which is the existing gate test with a new field.
5. Measure the bytes and say the number.
