# chooser.lua

Which model to draw for a model path: issue 516's stand-in chooser, reading
504's overrides, until W03's resolver replaces it.

Order: the player's override (its file read from the store), then the model
the map requests (the caller's function), then a placeholder. Each path is
chosen once and remembered until `clear()`.

## Functions

| Function | Takes | Gives |
|----------|-------|-------|
| `new(opts)` | `requested` (function: path → model or nil; may raise); `overrides` (a set); `store` (anything with `path(hash)`, such as `dedup.open`; needed when the set isn't empty); `map` (the map's hash, or nil); `read` (function: bytes, path → model; default `parsers.mdx.parse`) | a chooser; raises without `requested`, or with overrides and no store |
| `c:choose(path)` | a model path | the model (nil for a placeholder); its source, `"override"`, `"requested"` or `"placeholder"`; for an override, its look `{scale, tint, team_colour, file}` |
| `c:counts()` | — | `{override, requested, placeholder, override_failed}`: uses, not paths |
| `c:placeholders()` | — | `{path, reason}` once per path that ended on a placeholder, in the order met |
| `c:failed_overrides()` | — | `{path, reason}` once per path whose override couldn't be read |
| `c:report()` | — | the counts and both lists, as text |
| `c:clear()` | — | forgets the choices and both lists; the counts stay |

An override that can't be had (the store can't name it, doesn't have it,
or its bytes don't read as a model) falls back to the requested model, and
is listed and counted.
