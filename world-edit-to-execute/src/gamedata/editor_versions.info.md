# editor_versions.lua

A data table, not a program: which game versions each World Editor build
belongs to. A map's `war3map.w3i` records the editor build that last saved
it; the game-data chain (`chain.lua`) looks the build up here to choose the
patch layer whose stock values the map was made against.

## Using it

```lua
local versions = require("gamedata.editor_versions")
local entry = versions[6059]   -- nil when the build isn't listed
```

`chain.open` reads this table itself; pass `editor_versions` in its options
to use a different table (tests do).

## Fields

The table is keyed by editor build (integer, e.g. `6059`). Each entry:

| Field | Type | Meaning |
|-------|------|---------|
| `from` | string | the oldest game version that shipped this build, e.g. `"1.24a"` |
| `to` | string | the newest, e.g. `"1.28.5"` |
| `evidence` | string | how the range is known, in words |

## Rules

- **Only entries with evidence.** Each range is read from the builds' own
  editors (each editor holds its build number as a constant it writes into
  every map it saves), cross-checked against a public list of patches. The
  public list is a cross-check only, never the source.
- **Newest in range.** The chain uses the newest layer it has built inside
  the range: the version the map's author most likely played.
- **No guessing.** A build with no entry, or a range with no built layer, is
  an error from the chain that names what to fetch.

The evidence behind each entry is written out in the file's header comment.
Issue: `issues/112b-game-version-layers-per-map.md`.
