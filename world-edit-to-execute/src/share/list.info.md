# list.lua

A shared map-and-model list (issue 609): the file a player sends so a
playmate can see their models for a map, and the sharer's half of the
exchange.

| Function | Takes | Gives |
|----------|-------|-------|
| `list.build(opts)` | `map` (the file), `map_name`, `pack` (a folder), `types` (`{id -> path in the pack}`), `author`, `created`, `sources` | the list, and the pack's files left out (not art or sound) |
| `list.encode(l)` | a list | its text (a Lua table, keys sorted; checked first) |
| `list.decode(text)` | text | the checked list, or nil and a message. **Never runs the text**: only `return` and a table of strings, numbers, booleans and tables are read |
| `list.parse(text)` / `list.serialize(t)` | | the same reader and writer, unchecked (the trust file uses them) |
| `list.check(l)` | a table | `l`, or an error naming the problem |
| `list.check_path(path)` | a logical path | its key (lower case, `/`), or nil and why: no `..`, not absolute, art or sound only |
| `list.missing(l, store)` | a list, a dedup store | the hashes the store lacks, each once |
| `list.bundle(l, pack, wanted, dir)` | the sharer's pack, the receiver's wanted hashes | copies those files into `dir`, named by hash; how many |
| `list.hash_file(path)` | a file | `"sha256:<hex>"` |

`list.ART` is what may be shared: `blp tga png dds jpg jpeg mdx mdl wav mp3
ogg flac`. Unit tables, scripts and the map's object files are refused, so
a list never changes how the game plays.

An entry is `{key, hash, size, sources, provenance_id}`; a key of four
letters or digits is a unit type, doodad or other object id, and its
`path` names the model it is drawn with.
