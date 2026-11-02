# fallback.lua

What is drawn when an asset is missing, and the wire-frame debug view of a
map (issue 602). Built as data (geometry kit primitives and a list of
labels), so it is tested without a window; painted by the renderer's
geometry painting (`render.geo_*`) and its 2D text (`render.ui_text`).

## Functions

| Function | Takes | Gives |
|----------|-------|-------|
| `fallback.new(opts)` | `loader` (an `assets.loader`), `overlay`, `force`, `has_model(obj)` | a fallback |
| `F:build(scene)` | `{terrain, objects, regions, cameras, waypoints}` in WC3 units | `{prims, labels, lines, drawn = {kind -> n}, skipped}` |
| `F:texture(path, kind)` | a texture path | the loader's texture and source, or a checkerboard placeholder and `"fallback"` |
| `F:model(path)` | a model path | the loader's model and source, or nil and `"fallback"` |
| `F:is_active(path)` | a path | true when forced, the loader missed it, or a placeholder was handed out for it |
| `F:register(kind, fn)` | a kind, `fn(obj, ctx)` (nil: the built-in again) | draws that kind your own way |
| `F:set_debug_overlay(on)` / `F:force_wireframe(on)` | boolean | ids and coordinates on labels / wire-frame for everything |
| `fallback.kind_of(obj)` | an object | its kind (below) |
| `fallback.color_for(kind or obj)` | | `{r, g, b}` |
| `fallback.texture(kind, size)` | | a checkerboard `{width, height, rgba, placeholder = true}` |
| `fallback.blank(w, h)` | tiles | a flat terrain for a blank map, centred on 0 |
| `fallback.emit(out, render, dynamic, ground)` | a build | primitives painted (through `geometry/kit.lua`) |
| `fallback.draw_labels(labels, render, to_screen, size)` | labels, and `viewer.to_screen` | labels drawn (those behind the camera skipped) |

## Shapes

| Kind | Colour | Shape | Letter |
|------|--------|-------|--------|
| unit | blue | box | U |
| flyer | cyan | box at fly height, a line to the ground, a cross there | U |
| building | brown | large box | B |
| hero | gold (a type id starting with a capital) | box | H |
| item | purple | small box | I |
| tree | green | trunk and three legs (/\|\\) | — |
| doodad | grey | asterisk | — |
| region | orange | dashed outline | its name |
| camera | red | box, a line down, a line to its target | C, its name |
| waypoint | yellow | diamond on the ground | its name |
| selected | green | a second, thicker box | — |
| terrain | dark grey | a line per tile edge at the ground's height, wider where higher; vertex dots up to 65 by 65 vertices | — |

A line is one quad, `fallback.LINE` (6) wide: flat for lines along the
ground, upright (facing south) for vertical ones. `terrain.every = N`
draws every Nth line for a large map.

`ctx` (for `register`) has `line(p, q, color, width)`, `wire_box(x, y, z,
len, wid, hgt, yaw, color, width)`, `box(...)`, `dashed(p, q, color)`,
`label(x, y, z, text, color)` and `ground_at(x, y)`.

The demo, `src/demo/fallback/main.lua`, shows every shape in the scene
viewer; it has not been seen on a screen yet.
