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
