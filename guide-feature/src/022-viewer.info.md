# 022-viewer — info

The viewer-side canvas reader (issue 202), for the Lua viewers (801, 802)
and as the reference the other viewers are checked against. It follows only
`docs/canvas-protocol.md` and the canvas reader (102).

| Name | Type | Meaning |
|---|---|---|
| `read(text, source)` | function | a view: `version`, `width`, `height`, `voices`, `headers`, `record`, and `cells[row][column]` = `{ character, mark }`, where `mark` is nil or `{ voice, version, kind, age }`. It errors naming the line, and also refuses a mark newer than the canvas |
| `changed(view, previous)` | function | `{ row, column, was, now }` for each cell whose character differs, in reading order. With no previous view, or one of another size, every cell that is not a space, with `was` nil |
| `too_small(view, columns, rows)` | function | `"the canvas is 60x20; this screen is 40x12"`, or nil when it fits |
| `layout(view, window_width, window_height, letter)` | function | where to draw a canvas in a bigger window (205): `{ size, width, height, left, top }`, the largest whole letter size that fits and is no larger than `letter.max`, centred. `letter` is `{ across, down, max, min }` (a cell's width and height at letter size 1, in the viewer's unit). Nil and an error below `letter.min` |
| `colour_of(view, voice)` | function | the voice's place in the `voices:` header, or nil (`kuvalu`) |

Age is the canvas version minus the mark's version. Where mark lines
overlap, the later line wins. A change of mark alone is not a changed cell.

The test canvases and their expected answers are in `assets/test-canvases/`.
