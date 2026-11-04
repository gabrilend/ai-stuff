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

## How each viewer shows a change

| Viewer | Screen | A mark becomes | Notes |
|---|---|---|---|
| Lua window | desktop window on kuvalu | the voice's colour behind the cells, fading with age. New words are drawn arriving over the old ones | the recommended viewer |
| terminal view | any terminal on kuvalu | the voice's colour, in a few brightness steps by age, using standard colour codes | no animation |
| HTML page | a browser | CSS colour and a transition | the remote-access viewer |
| Android app | phone | colour fading with age | |
| Apple Watch app | watch | colour | the smallest screen; whether the canvas size should follow it is an open question |

A `word` mark is drawn stronger than a `sentence` mark, so the exact
changed words stand out inside their changed sentence.

A screen smaller than the canvas shows an error naming both sizes. It does
not crop or rewrap.

## What each viewer counts

The desktop viewers write a goodbye receipt: versions received, versions
drawn, seconds run. They take `--screenshot SECONDS`, `--key SECONDS NAME`
and `--replay FOLDER` (draw a history folder instead of the live canvas), so
a test can drive them without a person.
