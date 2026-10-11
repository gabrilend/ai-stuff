<!-- written by Claude (Opus 5.5), 2026-10-10, for phase 0 (the CAD viewer): what this file offers to other files. Read this instead of the source unless chasing a bug. -->
# 010-the-viewer

The LÖVE window (issue 005). Reads input/, opens a window, reads the CAD file, draws every frame into an off-screen canvas (multisampled, own depth buffer) and shows the canvas; writes output/goodbye on closing. Screenshots save the canvas, never the screen, so they are right even when the window is covered.

| Offers | |
|---|---|
| `load(arguments)` | { project folder, [CAD file], run options } |
| `update`, `draw`, `mousemoved`, `real_wheelmoved`, `keypressed`, `resize`, `filedropped`, `quit` | LÖVE callbacks (wired in main.lua); real input is ignored (and counted) in a scripted run |
| `wheelmoved(x, y)` | the wheel handler scripted runs use |
| `drag(button, dx, dy)` | the shared mouse handler: button 1 turns, 2 slides |
| `VIEWS` | view name → function drawing the shape: lit, edges, parts, depth, normals, annotated |
| `hue_to_colour(hue)` | {r,g,b} for the parts view |

Keys: Esc close, f fit, v next view, w edges, u up axis, space spin, h hide panel. Run options: `--key S NAME`, `--drag S DX DY`, `--pan S DX DY`, `--wheel S N`, `--screenshot S` (one picture per view to tmp/shared-memory/screenshot-<file>-<view>.png, then close), `--views NAME,NAME`.
