# 065-the-way-in

The screen before the match: a menu that picks a file and then gets out of the way.

Read this file rather than the source. The source is for when one specific
function is misbehaving; this is for everything else.

## What it is for

The front door. It draws a title, a short line of setting, and a column of
choices — play, scenarios, settings, out — and when one is clicked it **returns a
description of what was chosen**. It does not start anything itself.

That is the whole design, and it is the one rule this file exists to keep. A menu
feels like the thing that owns the game, which makes it the easiest place in the
project to cross the line the viewing layer is drawn on. It holds no world, no
match parameters, nothing half-built; the viewer in `050-the-viewer` receives the
choice and builds from it, through the same two functions the command line uses.

The second rule is that **every path this screen offers is reachable without it**.
`./run-prototype play`, `./run-scenario <name>`, and the batch runner all start a
game with nobody at the keyboard, thousands of times. A menu that cannot be
bypassed acquires a second start-up path that nobody tests, and the two drift.
So the environment variable `HLM_START` takes `match` or `scenario:<name>` and
calls the same functions the mouse does.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `M.load` | none | nothing — builds the four fonts, once, after the window exists |
| `M.begin` | `root` (string, absolute path to the project) | a fresh menu state table |
| `M.draw` | `state` | nothing — draws the current page and refills the hot-rectangle list |
| `M.mousemoved` | `state`, `x`, `y` (numbers, window pixels) | nothing — records what is under the cursor |
| `M.mousepressed` | `state`, `x`, `y` | `nil`, or a choice table (below) |
| `M.keypressed` | `state`, `key` (string) | nothing — escape goes back a page, or quits from the top |

`M.colours` is written from outside, by the viewer, before the first draw: it is
the commander colour table out of `053-commander-table`, so the settings page can
show each colour's shape without this file reaching for the catalogue itself.

### The two constants

| Name | Value | Meaning |
| --- | --- | --- |
| `M.MENU` | 1 | the menu is up and the world, if any, is not being ticked |
| `M.PLAYING` | 2 | a match or scenario is running and this file draws nothing |

The viewer stores one of these in `state.screen` and reads it at the top of both
its update and its draw. There is no third value and no transition state — the
menu is either in front of everything or entirely absent.

## Data structures it owns

### The menu state, from `M.begin`

| Field | Type | Meaning |
| --- | --- | --- |
| `screen` | integer | `M.MENU` or `M.PLAYING`. The viewer writes this; the menu reads it. |
| `root` | string | The project directory, kept so the scenario list can be re-read. |
| `page` | string | `"top"`, `"scenarios"`, or `"settings"` — which column is drawn. |
| `scenarios` | array of string | Directory names under `scenarios/`, sorted, read once at `M.begin`. |
| `shape_override` | table, colour index → shape name | A player's own choice of shape per resource colour. Empty means the catalogue's shape. |
| `hovering_kind` | string or nil | The kind of choice under the cursor, for the highlight. |
| `hovering_detail` | string or nil | Its name, so two scenarios do not light up together. |
| `hot` | array of hot rectangle | Rebuilt every draw. |

### A hot rectangle

The menu has no widget objects. Each frame, drawing a choice appends the rectangle
it just drew to `state.hot`, and the mouse handlers walk that list. The list is
cleared at the top of every draw, so a page that is not drawn cannot be clicked —
which is the whole of the "you cannot click through a page" logic.

| Field | Type | Meaning |
| --- | --- | --- |
| `kind` | string | `"play"`, `"scenario"`, `"page"`, `"shape"`, or `"quit"`. |
| `x`, `y`, `w`, `h` | numbers | Window pixels. |
| `name` | string, optional | The scenario or page named by this rectangle. |
| `colour` | integer, optional | Which resource colour a shape-cycling rectangle belongs to. |

### A choice, returned from `M.mousepressed`

Two shapes only, and both are read by `love.mousepressed` in `050-the-viewer`:

| Choice | Meaning |
| --- | --- |
| `{start = "match"}` | build an ordinary match |
| `{start = "scenario", name = <string>}` | build a match, then load that described world on top of it, held |

`nil` means the click did something local — turned a page, cycled a shape, quit —
and the viewer should do nothing.

## Related

- [The window and the two snapshots](../issues/701-the-window-and-the-two-snapshots.md)
- [The way in](../issues/707-the-way-in.md)
- [The viewing layer](../docs/017-the-viewing-layer.md)
- `050-the-viewer` — receives the choice and builds from it
- `063-the-gate` — loads the described world a scenario choice names
