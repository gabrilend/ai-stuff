# storage.lua

What the player's maps and asset packs take up, and clearing them out
(issue 605). Built on `dedup.lua` (issue 604): each map and pack is a folder
of links into the store.

## Layout of the player data folder

| Path | Holds |
|------|-------|
| `blobs/` | the store (`dedup.lua`) |
| `maps/<name>/` | a map's files |
| `asset-packs/<name>/` | an asset pack's files |
| `last-used` | one line per map or pack: kind, name, time (seconds since 1970) |

## Functions

| Function | Takes | Gives |
|----------|-------|-------|
| `storage.open(folder)` | the player data folder (default: `player_data.folder` of the project) | a manager |
| `S:put(kind, name, path, bytes)` | `"map"` or `"pack"`, its name, a relative path inside it, the bytes | the hash; stored once, linked in, marked used |
| `S:put_file(kind, name, path, file)` | the same, from a file | the hash |
| `S:touch(kind, name, when)` | when it was used (default now) | — |
| `S:names(kind)` | a kind | the names, sorted |
| `S:info(kind, name)` | one map or pack | its info (below), or nil when it has no folder |
| `S:list(kind)` | a kind | the info of each |
| `S:overview()` | — | `{total_bytes, naive_bytes, savings_bytes, savings_percent, shared_bytes, blob_count, orphan_count, orphan_bytes, maps, packs}` |
| `S:delete(kind, name)` | one map or pack | the bytes freed (its unique bytes; its own blobs go at the next `gc()`) and its info; or nil and a message |
| `S:gc()` | — | blobs removed, bytes freed |
| `S:orphans()` | — | the hashes `gc()` would remove |
| `storage.size(n)` | bytes | `"512 B"`, `"1.5 KB"`, `"450 MB"` |

A name is one folder (no `/`, not `.` or `..`); a path inside is relative
and never leaves it. Anything else is an error.

## Info of a map or pack

| Field | Meaning |
|-------|---------|
| `total_bytes` | each different file it holds, once, plus its plain files |
| `unique_bytes` | the part no other map, pack or link uses and nothing pins: what deleting it frees |
| `shared_bytes` | `total_bytes - unique_bytes`: stays after a delete |
| `file_count`, `blob_count` | its files; the different stored files among them |
| `plain_bytes` | files in its folder that aren't links (its own) |
| `broken_links` | links to nothing stored |
| `last_used` | time, or nil |

`overview().shared_bytes` is the stored files two or more maps and packs use.
