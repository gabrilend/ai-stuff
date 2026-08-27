# 1205 -- The state is drawn back to you

**Phase:** 12, the table as it is actually played
**Blocked by:** [1204](1204-the-controls-are-a-dial-you-can-see.md)
**Blocks:** [1206](1206-the-phase-twelve-demo.md)
**Documents:** [the dynamic picture](../docs/012-the-dynamic-picture.md)

## Current behaviour

A dial with three positions and no way to see where it points.

## Intended behaviour

**A modal control scheme whose mode is invisible is a control scheme nobody can
hold in their head.**

The scheme this is taken from solves that, and the solution is the interesting
part. Every key that turns a dial also prints a tiny diagram:

```
conprint oX     conprint  ooX     conprint oX
conprint o|     conprint  o/      conprint o
conprint o                        conprint
```

Three lines of characters. `X` is where the order will land, `o` is you, and the
line between them is the direction and the length of it is the distance. It is
redrawn on every change, in the corner, and it is the entire user interface for a
state machine with two hundred and forty positions.

### This is the third time this project has done this

| Where | The artifact |
| --- | --- |
| [the engraving](../docs/018-the-record-log-is-an-engraving.md) | a file that is a picture and a database at once |
| [the sprite paintbrush](../docs/017-the-sprite-studio.md) | a closed set of moves that is also its own documentation |
| here | a control state that is also a picture of itself |

**The pattern is worth naming**, because it has now arrived three times from three
different directions: *make the state its own display.* Not a display derived
from the state — the same object, read two ways. A separate rendering of a mode
can disagree with the mode. A diagram that is drawn from the dials cannot.

### What it shows

The selection, as how many bodies and which. The direction, as where the mark
sits relative to you. The distance, as the length of the line. And the verb that
the action keys are currently bound to, because a scheme where `E` means *attack*
in one mode and *aggressive stance* in another has to say which.

### It belongs in the corner, not in a panel

Small, monospaced, and always there. A control readout that has to be opened is a
control readout nobody opens, and the whole point is that it can be read without
looking away from the map.

## Suggested implementation steps

1. Draw the three dials as a small character diagram, from the dial state
   directly rather than from a copy of it.
2. Redraw on every change, including the verb row.
3. Put it in the corner of the browser view, in the same monospaced style the
   action bar uses.
4. Write down the pattern -- *make the state its own display* -- where the other
   two instances of it are described.
