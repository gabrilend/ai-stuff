# 208 — The panel under the picture

## Current behavior

A finished picture is 768 pixels square and says nothing. The meaning of the
character it hides exists in the card beside it, in the gallery page that links
to it, and in the pool companion — all of them text files that stay behind the
moment somebody saves the picture, sends it, or prints it.

The stroke-order arrows solved the same problem for stroke order: a separate
transparent sheet, laid over the picture by whatever shows it, never burned into
what the pool keeps. This does the same thing for meaning, with one difference
that changes the geometry.

## Intended behavior

**The picture does not shrink and it does not get written on. The image grows.**

The panel is its own image, the same width as the picture and sitting below it.
Joined, they are 768 by 1152 — two to three, which is the shape of a playing
card, which is what a flashcard is. Every pixel the model drew survives at the
size it was drawn.

```
  +---------------------------+
  |                           |
  |         the picture       |   768 x 768, untouched
  |                           |
  +---------------------------+
  | ~~~~~~~~~~~~~~~~~~~~~~~~~ |
  | ~                       ~ |
  | ~        R E S T        ~ |   goldenrod on black
  | ~     day off, retire    ~ |
  | ~        キュウ           ~ |
  | ~   人 person  木 tree   ~ |
  | ~~~~~~~~~~~~~~~~~~~~~~~~~ |
  +---------------------------+
```

`src/026a-the-panel-under-the-picture.lua`, beside the arrow sheet, because it
shares that file's machinery entirely: four surfaces for three colours and a
transparency, the outline pass, and the rule that an annotation is drawn once
and composited by whatever wants it.

**Black ground, goldenrod letters, a border of yellow squiggles.** The border is
`~` repeated end to end around all four edges — the glyph `107` writes by hand
because no archive carries it. It is drawn as lettering rather than as a
rectangle, which is the entire point of having an alphabet: the frame is made of
the same marks the words are.

The yellow is the one already in `input/settings.lua` under `arrows.colour`, so
the border, the arrows and the gallery's accent are one colour and stay one
colour. The letters are goldenrod, which is darker and warmer than that yellow —
the border reads as the edge of the card and the words read as the words.

**Every line is centred across the panel, and the block of lines is centred down
it.** Not ranged left. A card with one gloss and a card with three both look
composed, which ragged text against a fixed left margin does not.

**The panel is drawn per character, not per rendering.** It depends only on the
record — nothing in it knows which picture it will sit under, or whether any
picture exists at all. Six renderings of 休 share one panel. A run that drew the
panel per picture would draw the same lettering six times and keep six copies of
it.

**It can be drawn before any picture exists**, and that is deliberate and is the
same trick `048` uses. The panel joins to the field as readily as to a finished
picture — same width, same alignment — so the whole thing is testable on a
machine with no graphics card in it, which is the machine this project is
written on.

**What fits is decided here and what did not fit is counted.** `207` hands over
more lines than a panel can hold for a character with six components. The panel
takes them in rank order until the vertical space runs out, and the number left
out goes into the card the way `206` records an arrow that had to give up. A
panel that quietly shows three of six pieces is a panel that says a character
has three pieces.

**Nothing here reads a record.** It takes a caption from `207` and turns it into
ink. The split is the same one everywhere else in this project: something
decides what is true, something else decides what it looks like, and neither
does both.

### What it offers

| | |
|---|---|
| a panel | one caption, drawn, as the four surfaces `017` writes |
| a joined image | a picture and a panel, as one taller picture |
| what did not fit | lines dropped, and why |

**Joining reads a picture back rather than re-drawing it.** `017a` already reads
a PNG — it exists because the only way to know a compressor is right is to
decompress what it wrote. So joining is: read the picture, ask for the panel,
write a taller file. The picture does not have to be regenerated, re-encoded
from a surface somebody kept in memory, or found in the run that made it. Any
picture and any panel can be joined at any later time by anything holding both
paths.

**When arrows are wanted too, they go over the picture region only.** The arrow
sheet is 768 square and describes where the strokes are; sliding it down into
the panel would put arrows on the lettering.

## Suggested implementation steps

1. **The geometry first, on the field rather than on a picture.** A panel under
   a field, written to disk, for a character with two pieces and one with six.
   Everything after this is adjusting numbers, and the numbers cannot be
   adjusted before there is something to look at.

2. **The border.** It is the piece most likely to look wrong: a squiggle that
   tiles cleanly along a horizontal run has to turn a corner, and the wave has
   to come out of the corner in phase or the border will look like it was cut
   from wallpaper by somebody in a hurry.

3. **The settings block**, named `panel`, holding at least: the panel's height
   at `field.resolution`, the ground colour, the letter colour, the border
   colour, the border glyph's size, the padding, the gap between lines, and the
   size of each rank of line. Every one of them lands in
   `docs/balance-updates.md` the first time it is turned.

   Three of them are already decided and are here so nobody has to guess:
   the ground is black, `{ 0, 0, 0 }`; the letters are goldenrod, which is
   `{ 0.855, 0.647, 0.125 }` in the fractions this project's colours are written
   in; the border is `arrows.colour`, referred to rather than copied, because a
   second copy of a colour is a colour that will be changed in one place.

4. **Wire it into `030-make-one-kanji` and `031-make-them-all`**, which already
   write `field.png`, `field-thumb.png` and `arrows.png` into a character's
   folder. `panel.png` joins them, and the card names it the way it names the
   others — file, size in bytes, lines drawn, lines dropped.

5. **Tests in `027-test-the-meaning`**: that a joined image is exactly as tall
   as its two parts and that the picture half is byte-identical to what went in;
   that a six-piece character reports what it dropped; that the panel is
   readable at `field.thumbnail` — which is not a test a program can pass, so
   what the test does is write the thumbnail where a person will see it.

## Open questions

**How tall the panel should be.** Half the picture makes a two-to-three card and
holds about six lines at sizes that survive a thumbnail. Whether six is enough
for a character with six components and three glosses is a thing to look at.

**Whether the panel should be one height for every character**, or should grow
for a character with more to say. A fixed height makes a set of cards that stack;
a variable one wastes nothing. Fixed is assumed here, without much confidence.

## Related

`206` — the sheet, the outline trick and the count-what-you-dropped rule.
`107` — the alphabet, the squiggle, and the measuring this needs.
`207` — the words this draws.
`017`, `017a` — writing a picture and reading one back.
`413` — where the panels end up.
