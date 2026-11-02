# 403 — FAT directory walker

## Current behavior

The partition reader (402) gave the kernel a `fat_volume` that
knows where the root directory is. Reading directory entries to
find a file by name is a separate piece of work — and one that
needs to know how FAT lays out its 32-byte entries, long file
name (LFN) extensions, and end markers.

## Intended behavior

The walker exposes:

- `dir_open(fat_volume *, cluster)` — open a directory by its
  starting cluster. For the root, the volume's root cluster.
  Returns a directory handle.
- `dir_next_entry(handle, entry_out)` — read the next directory
  entry, skipping LFN extension slots after assembling the long
  name into the entry's `name` field. Returns false at the end
  of the directory.
- `dir_find(handle, name)` — convenience scan that calls
  `dir_next_entry` until it finds an entry whose name matches.
  Case-insensitive (FAT is case-insensitive by convention).
- `dir_close(handle)` — release the handle.

Directory entries carry: name, attributes (read-only, hidden,
system, directory, archive), the file's starting cluster, the
file's length in bytes. LFN entries that precede the actual
entry are assembled into the long name and the LFN slots are
consumed by the walker before returning the assembled entry.

Subdirectories are themselves files whose data is more directory
entries. Opening a subdirectory uses its starting cluster the
same way the root does.

The walker reads from the card via the chain follower (404) for
multi-cluster directories. Single-cluster directories (the common
case for our root) can read directly through the SD driver, but
the walker uses the chain follower unconditionally for
uniformity.

## Suggested implementation steps

1. `struct fat_dirent` (the on-disk shape) and `struct dir_entry`
   (the assembled in-memory shape).
2. `dir_open()`, `dir_next_entry()`, `dir_find()`, `dir_close()`.
3. LFN assembly: walk forward across LFN slots, build the name
   buffer, return when the regular entry follows.

## Open questions

- *A handle (`dir_open` / `dir_next_entry` / `dir_close`) or a walk?*
- *What happens to characters in a long name that are not ASCII?*
- *How is a short name chosen, so that no two entries share one?*
- *What dates go on an entry, with no clock brought up?*

### Proposed answers (UNVERIFIED)

1. *Handle or walk?* A walk: `fat_dir_walk` calls a visitor for every
   live entry, long names assembled, and stops when the visitor says so.
   There is no handle to allocate, keep, or forget to close, and
   `fat_dir_find` is a visitor on top of it. Adding, updating, removing
   and making directories are here too (`fat_dir_add`, `fat_dir_update`,
   `fat_dir_remove`, `fat_dir_make`), because the boxes of 406 and 407
   need nothing else from this layer.
2. *Characters past ASCII?* Each becomes `?` on the way in, and names
   the device writes are refused if they hold any. Everything the
   device itself writes is ASCII; a laptop's accented file name reads
   with question marks and cannot be found by its exact name. UTF-8 can
   come later without changing anything above this layer.
3. *Short names?* Up to six characters of the long name's base, `~N`,
   and up to three of its extension. The first version gathered only the
   first 64 short names in the directory before choosing, so a directory
   holding more than 64 names that shorten alike (a folder of messages,
   `message-0001.txt` onward) was given **duplicate short names** — a
   damaged directory to any laptop's checker. Now one pass over the whole
   directory marks which numbers in a window of 4096 are taken, and a
   second window is only looked at once all 4095 are; only entries of
   exactly the shape a chosen name would have can clash, so the check is
   exact. The test fills a directory with 200 such names and reads back
   200 distinct short names.
4. *Dates?* FAT's earliest, 1980-01-01, until a clock exists.
5. *(new)* **A directory whose chain loops** on a damaged card is walked
   to FAT's own limit of 65536 entries and then stops, and adding to it
   is refused, rather than either spinning forever.
6. *(new, a known cost)* A walk reads one block per 32-byte entry and
   finds each entry's cluster by walking the chain from the start, so a
   directory of n entries costs about n²/16 table steps. Nothing at
   launch keeps directories large enough for it to matter; a walk that
   reads a block once and keeps its place in the chain is the fix when
   one does.

## Related documents

- `docs/011-filesystem.md`.

## Blocked by

402, 404.

## Blocks

405, 406, 407.
