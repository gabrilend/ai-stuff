# dedup.lua

A content-addressed store (issue 604): each file is kept once, named by the
SHA-256 of its bytes, and maps or asset folders get symbolic links to it.
Hashing is the monorepo's own SHA-256 (`burner-of-down-things/src/015-sha-256.lua`),
loaded on first use. Linux and other POSIX systems only (links through the FFI).

## Layout of a store

| Path | Holds |
|------|-------|
| `ab/ab3def…` | a blob: the file's bytes, in a folder named by the hash's first two hex digits |
| `index` | one line per blob: hex, tab, size in bytes |
| `references` | one line per link made or released: hex (empty when released), tab, the link's path from the store |
| `pins` | hexes `gc()` keeps whatever links to them |
| `incoming/` | blobs being written; a finished one is renamed into place |

## Functions

| Function | Takes | Gives |
|----------|-------|-------|
| `dedup.open(folder)` | the store's folder (made if missing; `~/` is `$HOME`) | a store |
| `dedup.init(folder)` | as `open`; with no folder, `<player data>/blobs` | the store, kept as `dedup.default` for `dedup.store(...)` and the rest |
| `store:store(bytes)` | a string | `"sha256:<64 hex>"`, and `true` when it wasn't stored before |
| `store:store_file(path)` | a file, read in 64 KiB pieces | as `store`; an error if the file changed while it was copied |
| `store:exists(hash)` | a hash | true when the blob is on disk (one open of one path) |
| `store:path(hash)` | a hash | the blob's absolute path |
| `store:link(hash, dest)` | a stored hash, the link to make | DEST's absolute path; makes its folders; replaces a link, never a real file |
| `store:release(dest)` | a link made by `link` | true when it was a reference; the link is removed |
| `store:references(hash)` / `refcount(hash)` | a hash | the links that lead to it now (sorted) / how many |
| `store:list()` | — | every stored hash, oldest first, from the index |
| `store:refcounts()` | — | `{hex -> live links}` for every linked blob, in one pass |
| `store:orphans()` | — | the hashes `gc()` would remove now (no links, not pinned) |
| `store:stats()` | — | `{unique_blobs, total_references, storage_bytes, naive_bytes, savings_percent, pinned}` |
| `store:pin(hash)` / `unpin` / `pinned` | a hash | keep it from `gc()` / let it go / is it kept |
| `store:gc()` | — | blobs removed, bytes freed; forgets references whose links are gone and rewrites `index` and `references` |
| `store:verify()` | — | a list of `{hash, problem}` for blobs missing or no longer matching their hash |

A hash is `sha256:` and 64 lower-case hex digits; anything else is an error.

## Rules

- A reference counts while its link is in place and leads to the blob, so
  deleting a map's folder drops its references with no call.
- `naive_bytes` counts each blob once per link, and once when nothing links to
  it (it is still on disk); `savings_percent` is rounded, 0 for an empty store.
- Links and reference lines are relative to the store, so moving the whole
  player data folder keeps both.
- `gc()` runs only when called.
