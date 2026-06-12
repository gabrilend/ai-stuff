# 406 — read-path and write-path boxes

## Current behavior

Everything below the box layer exists (block driver, FAT, dir
walker, chain follower, path resolver). The runtime can answer
"is this path a file?" but apps cannot — there are no boxes that
expose the filesystem to them.

## Intended behavior

Two box descriptors get added to the table from 208:

- **`read-path`** — input port `path` (a string). Output is a
  bytes value with the entire file's contents. For files larger
  than the slot capacity, two additional input ports `offset`
  and `length` (both numeric, both optional) let the consumer
  read a slice. The function calls `path_resolve` to get the
  file's directory entry, then `chain_read` to pull the bytes
  into the output buffer.
- **`write-path`** — input ports `path` (string) and `value`
  (bytes). The function:
  1. Calls `path_resolve` on the parent directory.
  2. Picks a temporary name in the same directory (`.tmp-<rand>`).
  3. Creates the temporary file via `chain_allocate` and
     `chain_write`.
  4. Renames the temporary file on top of the destination —
     atomically by updating the parent directory entry in a
     single block write.
  5. Frees the old destination's chain if it existed.
  Output is a success-or-error enum value. A caller downstream
  of `write-path` sees either the new file or the old file,
  never a half-written one.

Both boxes are statically linked into the kernel image. Their
function pointers go into 208's descriptor table at
phase-4-build time.

## Suggested implementation steps

1. `read_path_box()` — `path_resolve` + `chain_read`.
2. `write_path_box()` — temp-and-rename pattern using
   `chain_allocate`, `chain_write`, parent-dir-entry update,
   `chain_free` on the old.
3. Descriptor entries for both.

## Related documents

- `docs/011-filesystem.md` — the box abstraction section.

## Blocked by

208, 401, 402, 403, 404, 405.

## Blocks

407 (similar shape, easier to write once these two land first),
408, 412.
