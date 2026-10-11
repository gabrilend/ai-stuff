# 005 — The CAD viewer

**Phase:** 0 — Tools
**Blocked by:** 001, 002, 003, 004
**Blocks:** 006
**Related documents:** docs/datapath-cad-viewer.md

## Current Behavior
Built and working: `src/006-read-any-cad-file.lua`, `007-read-the-input.lua`,
`008-say-goodbye.lua`, `009-the-orbit-camera.lua`, `010-the-viewer.lua`,
`main.lua`, `conf.lua`, the `view-cad` script, `scripts/run-tests` (window
tests included). The window has no multisampling: under dwm, a multisampled
window's screenshot read back black below its first rows (confirmed with a
five-line LÖVE program), so the receipt now counts pure-black pixels in the
screenshot and the test fails on any. Waiting on the open question below.

## Intended Behavior
A LÖVE window that opens a CAD file (STL, OBJ or glTF, chosen by a dispatch
table on the file's ending) and draws it in 3D, lit, with depth:
- **orbit** with the left mouse button, **pan** with the right, **zoom** with
  the wheel; `f` fits the whole shape in view; `space` turns it slowly.
- `w` shows the triangle edges (wireframe); `u` changes which axis is up;
  `h` hides the panel of figures.
- a panel of figures: file, format, parts (with colour), triangle count,
  degenerate triangles, size along each axis, load time, frames per second.
- a file dropped onto the window replaces the shape.

Reading and drawing stay apart: the file is read into a shape record
(issue 001) before the viewer sees it, and the camera's arithmetic lives in
its own file that runs without LÖVE so it can be tested.

The program reads `input/viewer-settings.lua` first (window size, field of
view, colours) and writes `output/goodbye` last: when it ended, the file it
showed, triangles, parts, frames drawn, seconds run. Run options drive it
without a person: `--key SECONDS NAME`, `--drag SECONDS DX DY` and
`--screenshot SECONDS` (saved to tmp/shared-memory/, then it quits).

## Suggested Implementation Steps
1. `src/006-read-any-cad-file.lua`: ending → reader dispatch table.
2. `src/007-read-the-input.lua`, `src/008-say-goodbye.lua`.
3. `src/009-the-orbit-camera.lua`: yaw, pitch, distance, target → view and
   projection matrices; fit-to-bounds.
4. `src/010-the-viewer.lua`, `src/main.lua`, `src/conf.lua`; `view-cad`
   script in the project folder.
5. Tests: camera fit keeps every corner of the bounds on screen; a scripted
   run writes a goodbye receipt and a screenshot.

## Open questions
1. Reading uses one thread. Binary STL's fixed 50-byte records could be
   split across workers; worth it once a model is large enough to wait on?
