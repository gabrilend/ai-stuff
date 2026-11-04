# 401 — Every one in its place

## Current behavior

Nothing exists. Needs `301` for each object's shape.

## Intended behavior

**The picture shows exactly the right number of things, because the host
decides where each one goes before the image model draws anything.** The owner:
"we need to be sure to draw the correct amount of objects on screen and say
'this one goes here, that one goes there'."

Image models cannot count. Asked for "eleven sacks" they draw nine or fourteen.
So the count never reaches the image model as a number. Instead the frame is
divided into cells, one per object, and each cell is drawn with its own
prompt for one object (`402` turns the cells into ComfyUI area prompts). Eleven
cells give eleven sacks.

**The layout** — a pure function, no network, no ComfyUI:

- **in:** the count (number, may be fractional, e.g. 11.2); the frame's width
  and height in pixels (integers); the object's footprint aspect (number,
  width ÷ height, from the catalogue entry); the packing (string: `grid` or
  `hex`)
- **out:** a list of cells, one per object, each a table of:
  - `x`, `y`, `width`, `height` — integers, pixels, multiples of 8 (ComfyUI's
    area prompts work on the latent grid, which is the image divided by 8)
  - `fraction` — number; 1 for a whole object, less than 1 for the partial one
  - `clipped_edge` — string or absent: `right` or `bottom`, the frame edge the
    partial object sticks out past

**The partial object.** 11.2 sacks is eleven whole sacks and one fifth of a
sack. The fifth is drawn as a sack whose cell extends past the frame's edge so
that only about a fifth of it is visible: "half of a *whatever*, sticking off
the page". Cells left over at the end of the last row are empty — unused, the
background shows through.

**Packing.** `hex` (alternate rows shifted by half a cell) suits round and
piled things — marbles, apples, crocodiles lying in a heap; `grid` suits boxes,
sacks, cars, rooms. The catalogue entry says which (`301` gains a `packing`
field); bare-number objects the model chose get `hex` unless it says otherwise.

**The ceiling.** A cell smaller than a minimum size (a setting, in pixels)
cannot hold a recognisable object. When the count needs more cells than fit:

- for a measured quantity, that candidate is not drawable, and a larger
  reference object is offered instead (`301`'s drawable range is derived from
  this ceiling, not set separately)
- for a bare count (`9999`), objects are drawn in groups of a round number —
  each cell a crate of 100 marbles — and the sentence says so

**The cell list is also the description.** Each cell becomes a line of the
scene: "top row, third from left: one sack of flour". The same list can be
drawn as outlines on a blank image for checking without ComfyUI.

## Suggested implementation steps

1. `src/` — the layout module: count and frame in, cell list out. The list is
   allocated at full length first and each cell filled independently.
2. `src/` — an outline drawer: cell list in, PNG of boxes out (reuse the kanji
   project's PNG writer), for tests and the phase demo.
3. Tests: whole counts produce exactly that many cells with fraction 1;
   11.2 produces 11 whole cells and one with fraction 0.2 crossing an edge; no
   whole cell leaves the frame; no two cells overlap (grid) or overlap more than
   the hex allowance; counts past the ceiling are refused or grouped as above.

## Related

`docs/005-datapath-the-picture.md` · needs `301` · blocks `402`
