<!-- written by Claude (Opus 5.5), 2026-10-10, for phase 0 (the CAD viewer): what this file offers to other files. Read this instead of the source unless chasing a bug. -->
# 010-the-viewer

The LÖVE window (issue 005). Reads input/, opens a window, reads the CAD file, draws every frame into an off-screen canvas (multisampled, own depth buffer) and shows the canvas; writes output/goodbye on closing. Screenshots save the canvas, never the screen, so they are right even when the window is covered.

| Offers | |
|---|---|
| `load(arguments)` | { project folder, [CAD file], run options } |
| `update`, `draw`, `mousemoved`, `real_wheelmoved`, `keypressed`, `resize`, `filedropped`, `quit` | LÖVE callbacks (wired in main.lua); real input is ignored (and counted) in a scripted run |
| `wheelmoved(x, y)` | the wheel handler scripted runs use |
| `drag(button, dx, dy)` | the shared mouse handler: button 1 turns the model around its pillar (side to side only), 2 tilts the view (up and down only) |
| `slide_at_edges(seconds)` | the mouse resting within edge_margin_pixels of an edge slides the pillar across the floor (sideways, away, nearer), not while a button is held or the mouse is outside the window |
| `VIEWS` | view name → function drawing the shape: lit, edges, parts, depth, normals, annotated |
| `hue_to_colour(hue)` | {r,g,b} for the parts view |

| `go_to_station(index)` | stands the camera at one of the shape's stations (issue 008) |
| `write_coverage(name)` | writes tmp/shared-memory/coverage-<file>.txt: each part's share of each station's picture |

Keys: Esc close, f fit, v next view, w edges, u up axis, space spin, h hide panel, n next station, o back outside. The window keeps its set size unless window_resizable is true. Run options: `--key S NAME`, `--drag S DX DY` (turn), `--tilt S DY`, `--mouse S X Y` (where the mouse rests, for edge sliding), `--wheel S N`, `--screenshot S` (one picture per view to tmp/shared-memory/screenshot-<file>-[<station>-]<view>.png, then close), `--views NAME,NAME`, `--stations` (pictures at every station, and coverage: each part's pixels counted in the parts view, matched within 2 shades per channel). A shape with a filling is hazed with distance in the lit look only.
