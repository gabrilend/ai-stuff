# 807c — Box diagrams

The third piece of 807: the `.txt` twin of the `.png` diagram (805c).

## Current Behavior

Built. `src/072-the-txt-canvas.lua`'s `box_diagram(diagram)` is the canvas
word `box-diagram`: `boxes` (`{name, text}`) drawn left to right in ASCII
lines, three rows each, and `arrows` (`{from, to, there, here}`) beneath
them, one lane each in the order given — a `|` down from the source box's
edge, the lane, an arrowhead `^` under the target box, `there` written on
the lane by the source end and `here` by the target end (the look's
`there-here` arrow). Measured in characters, so a box holding `café` lines
up like one holding `cafe`. Checked by
`tests/126-checking-box-diagrams.lua` against stored expected files in
`tests/fixtures/box-diagrams/`: a two-box diagram with one arrow, and three
boxes whose arrows cross and run backwards, both byte for byte. Done: `box_diagram`.

Decisions: ASCII lines, as docs/067's table says for the `.txt` end
("ascii lines and arrows"), not Unicode box-drawing characters. Boxes sit
in one row in the order given; the by-level layout is 805c's, for the
`.png` diagram, and the text one can follow it then. Each arrow end gets
its own column on its box's edge, so no two arrows ever share a line, and
the gap between boxes widens one column at a time until every lane holds
both labels clear of the verticals crossing it — the same diagram always
draws the same way. An arrow from a box to itself is refused: there is no
lane between two ends.

## Intended Behavior

Canvas word `box-diagram`: boxes drawn from line characters, arrows routed
between named boxes with a label at either end (`there — here`), the same
shape as the `.png` diagram but in text, measured in characters.

## Suggested Implementation Steps

1. The box-drawing primitive (corners, sides, measured in characters).
2. Arrow routing between two boxes with there/here labels. **Test:** a
   two-box diagram with one arrow matches a stored expected file byte for
   byte.

## Blocked by

- 807a
