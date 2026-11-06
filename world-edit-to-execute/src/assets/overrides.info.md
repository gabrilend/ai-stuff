# overrides.lua

A player's own models in place of the ones a map asks for (issue 504),
seen only on their machine. A set of overrides is one plain text file, so it
can be passed to another player as it is. The file is data: it is read line
by line and nothing in it runs.

## The file

```
wete-overrides 1
# a comment
name<TAB>Grim footmen
override<TAB>Units\Human\Footman\Footman<TAB>sha256:<64 hex><TAB>scale=1.2<TAB>tint=255,200,200
```

| Line | Fields (tab-separated) | Types |
|------|------------------------|-------|
| first | `wete-overrides 1` | the format's name and version (integer) |
| `name` | the set's name | string, once at most |
| `override` | model path; file; options | string (no tab or line break); `sha256:` + 64 lower-case hex; `key=value` each |

| Option | Value | Default | Meaning |
|--------|-------|---------|---------|
| `scale` | number above 0 | 1 | multiplied with the unit's own scale |
| `tint` | `R,G,B`, whole numbers 0–255 | `255,255,255` | multiplied with the unit's own tint |
| `team_colour` | `on` or `off` | `on` | whether the replacement's team-colour textures take the owner's colour |
| `map` | `sha256:` + 64 hex (the map file's hash) | every map | only on that map |

Paths match whatever their case, slashes, leading slash or extension
(`.mdx`, `.mdl`, none). On one map, its own override wins over one for every
map. The same path twice for one scope is refused.

## Functions

| Function | Takes | Gives |
|----------|-------|-------|
| `parse(text, source)` | the file's text; a name for messages | a set, or nil and a list of `"source:line: problem"` (every problem) |
| `write(set)` | a set | the file's text (options at their defaults left out) |
| `load(path)` | a file | a set; an empty set when the file isn't there; raises listing the problems when it is but is wrong |
| `save(set, path)` | a set; a file | the path; written beside it, then renamed into place |
| `file_for(root)` | the project folder | `<player data>/overrides.txt` (`assets/player_data.lua`) |
| `merge(sets)` | sets, highest priority first | the merged set; conflicts `{path, map, kept, dropped}` (set names, or "set N") |
| `new(name)` | optional name | an empty set |
| `key(path)` | a model path | the form paths are compared in |
| `set:add(entry)` | `{path, file, scale?, tint?, team_colour?, map?}` | the entry (replacing one for the same path and scope), or nil and a reason |
| `set:remove(path, map)` | a path; a map hash or nil (every map) | true when there was one |
| `set:lookup(path, map)` | a path; the map's hash or nil | the entry, or nil |
| `set:count()` | — | the number of overrides |

An entry: `path`, `key`, `file`, `map` (nil for every map), `scale`, `tint`
(`{r, g, b}`), `team_colour` (boolean), `line` (where it was read).
