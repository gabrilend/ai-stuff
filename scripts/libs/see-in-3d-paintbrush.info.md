# libs/see-in-3d-paintbrush.lua — info

The paintbrush's executable half and the wall (issue A08). Must say the same
as `see-in-3d-paintbrush.md`.

| | |
|---|---|
| `M.read(path)` | runs the scene file in a sandbox holding only `scene`, `box`, `sphere`, `cylinder`, `cone`; returns `{ what string, shapes = list of { kind string, line integer, fields table } }`, or nil and a list of every problem (strings: line, shape, field, what is wrong, nearest legal word) |
| `M.compile(scene)` | the model: flat arrays `px, py, pz` (numbers, three per triangle), `cr, cg, cb` (0–1, one per triangle), `glow` (boolean per triangle), `parts` (list of `{ name, first, last, color }`), `what` |
| `M.write_obj(model, path)` | the model as Wavefront `.obj` text, one object per shape |
| `M.shapes` | shape word → `{ required = field → kind, build }` |
| `M.common_fields`, `M.defaults` | fields every shape takes; the four published defaults (`at`, `turn`, `color`, `glow`) |

Turns apply about x, then y, then z, in degrees, then the shape moves to
`at`. Spheres and round shapes use 24 segments.
