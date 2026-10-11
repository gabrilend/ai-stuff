# 005 — The CAD viewer

**Phase:** 0 — Tools
**Blocked by:** 001, 002, 003, 004
**Blocks:** 006, 008
**Related documents:** docs/datapath-cad-viewer.md

## Current Behavior
Built and working: `src/006-read-any-cad-file.lua`, `007-read-the-input.lua`,
`008-say-goodbye.lua`, `009-the-orbit-camera.lua`, `010-the-viewer.lua`,
`main.lua`, `conf.lua`, the `view-cad` script, `scripts/run-tests` (window
tests included). Every frame is drawn into a multisampled canvas; pictures
are saved from it in six views, with the camera on the receipt. The first
screenshots came back black because the owner was playing a game over the
window and they were read from the screen; this was first blamed on
multisampling, which was wrong. A second finding: the window takes keyboard
focus when it opens, so the owner's game keys reached it and turned the
model 10 degrees between two identical scripted runs; a scripted run now
listens to its script only, and counts the real input it ignored.
`scripts/file-screenshot` files every new picture in development-history/
(called by view-cad); the earlier pictures still in RAM were filed late,
with notes saying so. Waiting on the open questions below.

## Intended Behavior
A LÖVE window that opens a CAD file (STL, OBJ or glTF, chosen by a dispatch
table on the file's ending) and draws it in 3D, lit, with depth:
- **orbit** with the left mouse button, **pan** with the right, **zoom** with
  the wheel; `f` fits the whole shape in view; `space` turns it slowly.
- `w` shows the triangle edges (wireframe); `u` changes which axis is up;
  `h` hides the panel of figures; `v` steps through the views (below).
- a panel of figures: file, format, parts (with colour), triangle count,
  degenerate triangles, size along each axis, load time, frames per second,
  statements not read.
- a file dropped onto the window replaces the shape.

Reading and drawing stay apart: the file is read into a shape record
(issue 001) before the viewer sees it, and the camera's arithmetic lives in
its own file that runs without LÖVE so it can be tested.

**Pictures are taken from the program, not the screen.** Every frame is
drawn into an off-screen picture (a LÖVE canvas, multisampled, with its own
depth buffer) and that picture is shown in the window; a screenshot saves
the canvas, so it is right whether the window is visible, covered or on
another desktop. A screenshot saves one picture per **view** (filter):

| View | Shows |
|---|---|
| lit | the normal look |
| edges | lit, with every triangle's edges |
| parts | each part in one flat, distinct colour, no lighting |
| depth | near is light, far is dark |
| normals | the direction each surface faces, as colour |
| annotated | lit, with each part's name on a leader line and the overall box with its three lengths |

Every screenshot is kept: the `view-cad` script files each picture into
`development-history/` under the next number, beside a notes file (what
made it, what changed since the previous picture, and two sections — what
it shows, the story so far — for a person or Claude to fill in). A picture
byte-for-byte identical to one already filed is not filed twice: it is the
same picture.

The program reads `input/viewer-settings.lua` first (window size, field of
view, colours) and writes `output/goodbye` last: when it ended, the file it
showed, triangles, parts, frames drawn, seconds run, the pictures saved and
the share of each that is pure black. Run options drive it without a
person: `--key SECONDS NAME`, `--drag SECONDS DX DY`, `--pan SECONDS DX DY`,
`--wheel SECONDS NOTCHES`, `--screenshot SECONDS`, `--views NAME,NAME`.

## Suggested Implementation Steps
1. `src/006-read-any-cad-file.lua`: ending → reader dispatch table.
2. `src/007-read-the-input.lua`, `src/008-say-goodbye.lua`.
3. `src/009-the-orbit-camera.lua`: yaw, pitch, distance, target → view and
   projection matrices; fit-to-bounds; a point to the screen.
4. `src/010-the-viewer.lua`, `src/main.lua`, `src/conf.lua`; `view-cad`
   script in the project folder.
5. The canvas, the views as a dispatch table, the annotation layer.
6. `scripts/file-screenshot` (adapted from centered-ui-design's): numbered
   filing, source fingerprints, notes skeleton; called by `view-cad`.
7. Tests: camera fit keeps every corner of the bounds on screen; a scripted
   run writes a goodbye receipt and one picture per view, none black,
   while the window is covered.

## Open questions
1. Reading uses one thread. Binary STL's fixed 50-byte records could be
   split across workers; worth it once a model is large enough to wait on?
2. Every new picture is filed, so each code change adds dozens (the test and
   the demo take six views each). Keep all, or file only the demo's and
   hand-taken pictures? (Pictures the same as the last of their name are no
   longer filed again, which ends the repeats when nothing changed.)
