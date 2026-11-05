# Datapath: from the canvas to a person's eyes

Every viewer reads the canvas protocol (`docs/canvas-protocol.md`). No viewer
changes the characters. Each one only decides how marks look on its kind of
screen. The point of the marks: "This should enable users to skim, and see
the changed sections from all three."

## The path

    blitter
       │ version N
       ├──► tmp/shared-memory/canvas/current ──► terminal view   (kuvalu)
       │                                     └─► Lua window      (kuvalu)
       └──► canvas server (HTTP) ──► GET /canvas?after=N
                                       ├─► HTML page
                                       ├─► Android app
                                       └─► Apple Watch app
                                       (reachability: docs/network.md)

## The viewer-side reader (Lua)

Built on the canvas reader (`docs/canvas-format.md`), plus what viewers need
on top:

- a grid of cells, `H` rows by `W` columns, each cell a record of character
  (string, one code point) and mark (nothing, or a record of voice string,
  version whole number, and kind `word` or `sentence`);
- the age of each mark: the canvas version minus the mark's version (whole
  number), which viewers turn into faintness;
- the cells that changed since the previous version the viewer saw, so a
  viewer can draw the new words "writing over what was in that slot".

Built in `src/022-viewer.lua` (issue 202). It also gives the error a
screen too small should show, and each voice's colour order (its place in
the `voices:` header). A mark may also be of kind `orphan`, and `kuvalu`'s
marks have no place in that header. "Changed" means the character changed.
A change of mark alone is not listed, because a viewer draws every mark
afresh. With no previous version, or one of another size, every cell that
is not a space is new.

Every viewer, in any language, is checked against the same test canvases
and their expected answers, in `assets/test-canvases/` (its README gives
the format).

## How each viewer shows a change

| Viewer | Screen | A mark becomes | Notes |
|---|---|---|---|
| Lua window | desktop window on kuvalu | the voice's colour behind the cells, fading with age. New words are drawn arriving over the old ones | the recommended viewer |
| terminal view | any terminal on kuvalu | the voice's colour, in a few brightness steps by age, using standard colour codes | no animation |
| HTML page | a browser | CSS colour and a transition | the remote-access viewer |
| Android app | phone | colour fading with age | |
| Apple Watch app | watch | colour | the smallest screen; it gets a canvas of its own size, or in `smallest` mode sets the one canvas's size |

A `word` mark is drawn stronger than a `sentence` mark, so the exact
changed words stand out inside their changed sentence.

A screen smaller than the canvas shows an error naming both sizes. It does
not crop or rewrap.

The terminal view is built (issue 801, `src/070-terminal-view.lua`,
`scripts/terminal-view`): the colours and the age-to-step tables are in
`input/terminal-view`, and its reference screens in `assets/test-terminal/`.

## One canvas for each screen

Each watched screen gets a canvas made at its own size, so no canvas is
ever resized and no word is cut off by a moving edge (issue 205). The screen
mode, in `input/screens`, says how:

- `round`: one canvas per watched screen, refreshed one after another,
  largest first; a context change mid-round waits for the round to end;
- `asynchronous`: one canvas per watched screen, all at once, each turn on
  an endpoint of its own;
- `smallest`: one canvas, as narrow as the narrowest watched screen and as
  short as the shortest.

A screen whose own canvas is not made yet (it opened with a canvas cached
at another size) shows a loading animation until it is. In `smallest` mode
every viewer draws the canvas centred left to right and top to bottom, at
the largest letter size that fits its window and is no larger than its own
maximum; below its smallest readable size it shows the too-small error.
`viewer.layout` in `src/022-viewer.lua` works out the size and place; the
plan of canvases and turns is `src/028-screens.lua`.

## What each viewer counts

The desktop viewers write a goodbye receipt: versions received, versions
drawn, seconds run. They take `--screenshot SECONDS`, `--key SECONDS NAME`
and `--replay FOLDER` (draw a history folder instead of the live canvas), so
a test can drive them without a person.
