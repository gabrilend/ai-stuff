# 406 — read-path and write-path boxes

## Current behavior

Everything below the box layer exists (block driver, FAT, dir
walker, chain follower, path resolver). The runtime can answer
"is this path a file?" but apps cannot — there are no boxes that
expose the filesystem to them.

## Intended behavior

Two boxes join the library. Both are ordinary box sources — C
functions in the box source directory — so the generator picks them up
and writes their catalogue rows with everything the engine needs (301,
302). There is no table anybody adds to by hand:

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

Both are compiled into the kernel image, which is the ordinary path
for a box in this phase; from here on, a box written on the device
arrives by the same route through the same generator (409).

## Suggested implementation steps

1. `read_path_box()` — `path_resolve` + `chain_read`.
2. `write_path_box()` — temp-and-rename pattern using
   `chain_allocate`, `chain_write`, parent-dir-entry update,
   `chain_free` on the old.
3. Nothing to register — the generator finds them because of where
   they live.

## Open questions

- *What types carry a path and a file's bytes, when a box may pass no
  pointer?*
- *How are `offset` and `length` optional, when a station runs only once
  every port holds a value?*
- *Is the temporary file of step 2 needed?*
- *What does write-path do with a value that is itself a failed read?*

### Proposed answers (UNVERIFIED)

1. *Types?* `struct path` (256 characters, ended by a zero; FAT names
   are up to 255, and a launch path is a few directories of short names)
   and `struct file_bytes` (a status, the whole file's size, a length,
   and up to 4096 bytes: one page of a file). Both live in
   `src/boxes/082-files.c` with the boxes. Two small boxes, `text_path`
   and `path_join`, turn the 64-character `struct text` into a path and
   add a name to one, so a program can build a path from pieces.
2. *Optional ports?* Not as ports: the engine has no optional input, so
   there are two boxes. `read_path(path)` reads from the start, all of
   a file up to 4096 bytes; `read_slice(path, offset, length)` reads any
   4096 bytes or fewer. `file_size` in the answer says whether there is
   more.
3. *A temporary file?* No — the same atomicity with one fewer directory
   entry: the new contents go into clusters no name points at, the table
   is written, one block write points the name at them, and the old
   clusters are freed (405, `files_write`). A file and the directories on
   its way are made if missing.
4. *A failed read as the value?* Not written; its status is passed on.
   So a read wired straight into a write is a copy, and a copy whose
   source is missing leaves the destination as it was rather than
   emptying it.
5. *(new) What is refused and what is a status?* As 407 splits it: no
   card, no such file, a directory where a file was expected — statuses
   in the value (0 or a negative `fat_error` code). A path with no end in
   its 256 characters, deeper or longer than any path may be, a name FAT
   cannot hold, or a value claiming more than 4096 bytes — refusals, with
   the code without its sign as the detail.
6. *(new) A box that waits.* These boxes wait for the card and for its
   lock, which "a box never blocks" forbids everywhere else. The card is
   the only place the bytes are and docs/011 puts reading them in a box,
   so the six filesystem boxes are the stated exception. A whole file
   larger than 4096 bytes cannot yet be written by one box; the painter
   (810) is where that need first arrives.

## Related documents

- `docs/011-filesystem.md` — the box abstraction section.

## Blocked by

301, 302 (the generator that catalogues them), 401, 402, 403, 404,
405.

## Blocks

407 (similar shape, easier to write once these two land first),
408, 412.
