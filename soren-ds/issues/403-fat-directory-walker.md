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

## Related documents

- `docs/011-filesystem.md`.

## Blocked by

402, 404.

## Blocks

405, 406, 407.
