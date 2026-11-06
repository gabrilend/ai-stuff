<!-- made by scripts/build-info-pages from the comments in 002-util.lua; change the comments and rebuild, not this page -->
# 002-util


The handful of small things every other file needs: stopping loudly, the
arithmetic of angles and plain-number vectors, copying tables, and laying
the person's config.lua over the defaults.

Vectors are passed as two numbers, never as tables, so the simulation's
tick allocates nothing it does not have to.

## Functions other files call

| Name | Takes | What it does |
| --- | --- | --- |
| `M.die` | `fmt, ...` | Stops the program with a message that says which program is speaking. Used wherever the project prefers an error to a guess. |
| `M.clamp` | `v, lo, hi` | (no comment in the source) |
| `M.lerp` | `a, b, t` | (no comment in the source) |
| `M.sign` | `v` | (no comment in the source) |
| `M.wrap_angle` | `a` | Brings an angle into (-pi, pi], so the difference of two facings is the short way round. |
| `M.length` | `x, y` | (no comment in the source) |
| `M.distance` | `ax, ay, bx, by` | (no comment in the source) |
| `M.normalize` | `x, y` | A zero vector stays zero: "no direction" is a real answer for a soldier that wishes to stand still, not an error. |
| `M.bearing` | `ax, ay, bx, by` | The angle from a to b on the map: 0 is east, and angles grow clockwise on screen because map y grows southward. |
| `M.deep_copy` | `t` | (no comment in the source) |
| `M.sorted_keys` | `t` | Keys in a stable order, because iteration order of a hash part is not something a deterministic simulation may depend on. |
| `M.merge_strict` | `base, over, where` | Lays `over` onto `base` in place. A key in `over` that `base` does not have is an error naming its dotted path: a typo in config.lua must never quietly do nothing. Lists (the key tables) are replaced whole rather than merged, because a person rebinding keys means "these keys", not "these as well". |
| `M.load_data_file` | `path` | Runs a data file in an empty environment and returns what it returns. The file can compute (it is Lua) but can touch nothing outside itself. |
| `M.file_exists` | `path` | (no comment in the source) |
| `M.load_config` | `dir` | The defaults, with config.lua at the project root laid over them when it exists. No config.lua is the ordinary case: the defaults are the design. |
| `M.list_files` | `dir, suffix` | The names in a folder that end with a suffix, sorted. Uses ls because plain Lua cannot list a folder; a missing folder lists as empty, since every caller treats "no files" as "nothing to add". |

## Private helpers

| Name | Takes | What it does |
| --- | --- | --- |
| `is_list` | `t` | (no comment in the source) |
