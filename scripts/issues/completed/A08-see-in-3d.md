# Issue A08: See It in 3D

**Phase:** A - Infrastructure Tools
**Type:** Tool
**Priority:** Medium
**Status:** Completed 2026-10-10
**Dependencies:** None

---

## Why this exists

> can you also write a script or utility that takes a screenshot, describes in
> text how it wants to visualize it, then passes it to a 3d image generator
> that creates the object so that they can see it from a different
> perspective? then it just... makes whatever best represents that idea, and
> the llm can image recognition it. then, can you highly suggest that the
> global user's claude.md file has a line that says to use it everytime
> something visual is generated?

Something visual is made — a page, a game screen, a diagram. A language model
looks at a screenshot of it and sees one flat picture from one side. This
tool lets the model say, in a few lines of text, what it thinks the picture
*is* as an object in space, and then see that object from the front, the
side, above, and at an angle — so it can check its own understanding of the
picture, and the person can see the idea turned around.

## Current Behavior

Built: `scripts/see-in-3d` (shot, brief, render), its paintbrush document
`scripts/see-in-3d-paintbrush.md`, and `scripts/libs/see-in-3d-paintbrush.lua`,
`see-in-3d-render.lua`, `png-writer.lua`. Tests: `scripts/test-see-in-3d.sh`.
Used on its own example (a desk) and on a screenshot of the reading walk's
small-screen page (read as a watch face). No text-to-3D model is installed or
reachable, so the "3D generator" is this: the looking model writes the scene,
and a software renderer draws it.

Extended the same day with a gallery (`see-in-3d gallery`,
`scripts/libs/see-in-3d-gallery.lua`) and 25 examples in
`scripts/see-in-3d-examples/`, built in her stages and published as a private
page, "Seen From Four Sides".

## Intended Behavior

One command, `scripts/see-in-3d`, with three steps:

1. **shot** — a screenshot to a PNG: of the X desktop, or of a page or file
   opened in headless Firefox.
2. **brief** — prints what the model needs to write a scene: the
   screenshot's path, and the paintbrush (the closed list of words a scene
   may use).
3. **render** — a scene file in, one PNG contact sheet out: four views (front,
   right, top, three-quarter) in a 2×2 grid, each labelled; also each view
   alone, and the scene as an `.obj` model any 3D viewer opens.

**The paintbrush** is small and closed: `scene{what=...}`, `box`, `sphere`,
`cylinder`, `cone`, each with a position, size, turn, colour, and `glow` for
things that give off light. `glow` was added after the first real use: a
screenshot of a lit OLED screen came out grey, because every face was shaded
by the light, and a lit screen gives off light rather than reflecting it. A scene file
is Lua run in a sandbox holding only those words, so the language is the
parser. **The wall** refuses a bad scene before drawing anything: every
problem named with its shape and field, all reported together, each with the
nearest legal word. Defaults exist only where the paintbrush document
publishes them.

**The spine:** scene → wall → triangles (names resolved once) → a software
renderer (depth buffer, light from one side, a chequered floor at height 0
so height reads — first drawn under the lowest shape, which made a desk
floating at table height look as if it lay on the floor)
into flat arrays → a PNG encoder written here (stored deflate blocks,
CRC-32, Adler-32) → the file. The four views render in four worker
processes and are stitched in a fixed order. The same scene gives the same
bytes.

**Making and looking are separate:** the renderer writes files; the model (or
a person) looks at them with whatever reads a PNG. No pool or ratings yet:
these pictures are for checking an idea, made and looked at once.

**Light.** One key light from above and to the side so slopes read, a little
everywhere-light, and a soft light from the camera itself — added when white
web pages seen straight on came out mid-grey.

**The gallery.**

> can you create a gallery in HTML that displays some of these examples? Aim to
> have at least 25 as the total dataset, with 1 built first to ensure we have
> the page structure correct, then 3 to show how we can add more, then 8 to
> show two different compare and contrasts, then 25 to represent our quarter
> of perception space which should illuminate and align.

`see-in-3d gallery EXAMPLES-DIR [--out=DIR]` reads a folder of examples, each
a folder holding `scene.lua`, `note.txt` (title, picture path or none, the
stage it arrived in, an optional compare group, then what the views showed)
and usually `picture.png` (a scaled copy of the source). It renders every
scene at once, one process each, makes JPEG display copies with ImageMagick
(the stored PNGs are large; the page is only for looking), and writes one page
of drawing sheets: picture beside views, a title block, the note, the scene
folded away. Members of a compare group sit side by side. `stages.txt` beside
the examples puts her words for each stage under its heading.

The examples are read from this conversation's own pages, the
centered-ui-design development-history renders, three project images, and
two ideas in words. Left out on purpose: screenshots showing a home folder
listing or chat logs, a desktop of text, and someone else's comic — the page
may be shared. Three comparisons: one world through two cameras, one picture
from above read two ways (a board and an arena: identical from above,
different from every other side), and three pictures that read to one object.

What the 25 found about the paintbrush, as open limits rather than fixes: a
hole cannot be drawn (no cutting), glass cannot be drawn (no see-through
face), a ring is made of boxes and reads as dashes, lighting and time of day
can only be painted on, and a picture's camera, blur and moment are not part
of the object.

## Suggested Implementation Steps

1. Paintbrush document (`see-in-3d-paintbrush.md`) and sandbox, with the wall.
2. Shapes to triangles; `.obj` writer.
3. Renderer: camera per view, depth buffer, shading, ground grid, labels.
4. PNG encoder; round-trip test with a decoder written in the test.
5. The command: shot, brief, render; four worker processes.
6. Tests: wall errors (all at once, nearest word), byte-identical output,
   PNG round trip, a known scene's views differ in the expected way.
7. Gallery: note reader, page layout as drawing sheets, compare groups, stage
   words; build at 1, 3, 8 and 25 examples, looking at the page at the first
   and last.

## Decided against

- A text-to-3D model: none is installed or reachable; a small closed set of
  shapes written by the looking model says the idea, and can be read and
  corrected as text.
- ImageMagick or a PNG library for writing pictures: the encoder is short and
  ours (ImageMagick is used only to take desktop screenshots and, in the test,
  as a second reader).
- Asking the global CLAUDE.md to require this tool: a change to every session's
  instructions is the owner's to make; the line is offered in conversation.
