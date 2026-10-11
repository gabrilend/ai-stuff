<!-- written by Claude (Opus 5.5), 2026-10-10, for phase 0 (the CAD viewer): what this file offers to other files. Read this instead of the source unless chasing a bug. -->
# 010-the-viewer

The LÖVE window (issue 005). Reads input/, opens a window (no multisampling: it breaks screenshots under dwm), reads the CAD file, draws it lit from the camera and from above with both sides of every surface lit, writes output/goodbye on closing.

| Offers | |
|---|---|
| `load(arguments)` | { project folder, [CAD file], run options } |
| `update`, `draw`, `mousemoved`, `wheelmoved`, `keypressed`, `resize`, `filedropped`, `quit` | LÖVE callbacks (wired in main.lua) |
| `drag(button, dx, dy)` | the shared mouse handler: button 1 turns, 2 slides |
| `take_screenshot()` | saves tmp/shared-memory/screenshot-<file>.png, counts black pixels, then closes |

Keys: Esc close, f fit, w edges, u up axis, space spin, h hide panel. Run options: `--key S NAME`, `--drag S DX DY`, `--pan S DX DY`, `--wheel S N`, `--screenshot S`. A dropped file replaces the shape; if it cannot be read the reason is shown on screen and the old shape stays.
