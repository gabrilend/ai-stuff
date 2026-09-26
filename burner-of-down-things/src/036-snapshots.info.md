# 036-snapshots.lua

Before-and-after pictures of folders, to catch a turn writing where it may
not. A **snapshot**: absolute path → `{ size (number), time (string),
hash (string) }`; `hash` is SHA-256, or `link:<target>` for a link, or
`large:<size>:<time>` for a file over `HASH_LIMIT` (64 MiB). A **change**:
`{ path, how = "created" | "changed" | "removed" }`.

| Function | In | Out |
|---|---|---|
| `take(project, roots, excluded, previous)` | paths table; folders; absolute paths to leave out; an earlier snapshot or nil | the snapshot, and how many files were hashed (reusing `previous` for unmoved files; hashing the rest on every core) |
| `compare(before, after)` | two snapshots | array of changes, by path; same bytes with a new time is not a change |
| `charge(changes, turns)` | changes; turn tables | `{ by_turn = {id → changes}, set = changes under a prefix several turns share, breaches = changes no turn may write }` |
| `save(path, snap)` / `load(path)` | | keeps a snapshot as a table file between runs; `load` gives nil when absent |
