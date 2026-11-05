# 202 — The viewer-side canvas reader

phase 2, the canvas for viewers

## Current behavior

The canvas reader (102) gives rows and a list of mark runs.

## Intended behavior

What the Lua viewers need on top, described in `docs/datapath-viewers.md`:

- a cell grid, each cell a character (string) and a mark (nothing, or voice
  string, version whole number, kind `word` or `sentence`);
- each mark's age (canvas version minus mark version, a whole number);
- given the previous version a viewer drew, the cells that changed, so a
  viewer can animate new words writing over old ones.

It is written against `docs/canvas-protocol.md` and the canvas reader only,
so the other viewers (HTML, Android, watch) can be checked against its
answers on the same test canvases.

## Suggested implementation steps

1. Grid, ages, changed cells.
2. A small folder of test canvases with the expected grids, kept for the
   other viewers' tests too.

## Related documents

- `docs/datapath-viewers.md`
- `docs/canvas-protocol.md`

## Blocked by

102, 201.

## Blocks

206, 801, 802.

## Decisions (2026-11-05; each the owner's to overturn)

1. **A view is `cells[row][column] = { character, mark }`**, where the mark
   is nil or `{ voice, version, kind, age }`. The age is kept on the mark,
   so a viewer never works it out itself.
2. **`orphan` marks are passed through**, though `docs/datapath-viewers.md`
   names only `word` and `sentence`: the canvas format allows them, and a
   viewer draws them dim. **`kuvalu`'s marks** have no place in the
   `voices:` header, so `colour_of` gives nil and the viewer picks its own
   colour.
3. **A mark newer than its canvas is refused**, naming its line, like any
   other malformed line. Its age would be below zero.
4. **Where mark lines overlap, the later line wins.** The blitter never
   writes overlapping lines, but a reader in any language must agree.
5. **"Changed" means the character changed.** A change of mark alone isn't
   listed, because each version's marks are drawn afresh. With no previous
   version, or one of another size (205: one canvas per screen size), every
   cell that is not a space counts as new.
6. **`too_small` gives the error text** the protocol asks for, naming both
   sizes ("the canvas is 60x20; this screen is 40x12").
7. **The shared test canvases are in `assets/test-canvases/`**, each with an
   `.expected` file in a line format any language can read: decimal code
   points, one cell a line, `changed` lines against a named previous
   version, `refused LINE` for a canvas that must be refused. The README
   there gives the format.
   - There are six: empty; the kitten and dog example made by the real
     blitter steps; marks of several ages with an orphan, a `kuvalu` mark
     and two-byte characters; a mark from the future; a row too wide.
   - The `.expected` files were written from the reader's answers and
     checked by hand, cell by cell. The test holds the reader to them, and
     checks the kitten and dog canvases against the real change finder,
     blit and marks.

## Implementation notes (2026-11-05)

- `src/022-viewer.lua`: `read`, `changed`, `too_small`, `colour_of`.
- `assets/test-canvases/`: the six canvases, their answers and a README.
- `src/023-test-viewer.lua`: 25 pass.
- Mutation checks were each caught:
  - the age wrong;
  - marks from the future allowed;
  - the wrong line named;
  - spaces counted as new;
  - the height not compared;
  - the rows of a screen not checked;
  - colours off by one;
  - every cell counted as changed.

  A default for a missing cell was dead code (the canvas reader pads every
  row), and was removed.
- `docs/datapath-viewers.md` and `docs/canvas-protocol.md` point to the
  reader and the test canvases. `.file-index-counter` is at 023.

**Needs the owner's machine:** nothing. The viewers that use this are
801-803 and 901-902.
