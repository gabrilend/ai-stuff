# 413 — append-path: a file larger than one value

## Current behavior

`write-path` (406) replaces a file's contents with one value, and one
value holds at most 4096 bytes (`FILE_CHUNK`). `read-slice` reads any
file 4096 bytes at a time, but nothing writes one that way: a file larger
than 4096 bytes can be read by a program and never written by one. 406
noted it and named the painter (810) as where the need first arrives; a
saved drawing is far larger than one value.

## Intended behavior

The cap stays where it is. A value is a page of a file, and growing it
would make every value of the type that size wherever it travels. A file
of any size is instead **built from several writes, each within the
cap**:

- **`append-path`** — input ports `path` (a path) and `value` (the same
  `struct file_bytes` read-path answers and write-path takes). The value's
  bytes are added to the end of the file. A missing file is made, with any
  directories on its way, exactly as write-path makes one; through a
  symlink, the target grows; a directory is a status in the value.
- Each append is whole or not at all. A reader, or a card pulled out
  part-way, finds the file as it was before the call or with every new
  byte after it, never some of them.
- A read-slice wired into an append-path copies a file of any size, one
  slice per run.

Underneath, `files_append` (078) and `fat_chain_append` (077) keep the
same order every write on the card keeps: bytes first, into places no
name reaches; the table next; the name's one block last.

1. The new bytes fill the spare room at the end of the file's last
   cluster. No byte of the file is there, so nothing a reader sees moves.
2. What does not fit goes into new clusters, written and then recorded in
   the table as taken while still nobody's.
3. The new clusters are linked after the last one, and the table written
   again.
4. One block write gives the directory entry its new size. Until this
   step the file is its old self.

Stopped after step 3, the card holds a file whose chain is longer than
its size. A laptop's `fsck.fat` trims the extra clusters, and so does the
next append, which lets go of any cluster past the one holding the file's
last byte before it adds anything.

## Suggested implementation steps

1. `fat_chain_cut(v, first, size)`: keep the clusters `size` bytes need,
   free the rest.
2. `fat_chain_append(v, first, size, bytes, length)`: the four steps
   above, short of the size.
3. `files_append(path, bytes, length)` under the card's lock: locate as
   `files_write` does, append and write the size, or on any failure cut the
   chain back to the old size.
4. `append_path(path, value)` in `src/boxes/082-files.c`.
5. Test: appends inside and across clusters on one-sector and eight-sector
   clusters; a large file from many appends; through a link; a directory;
   a full card; a card left by an interrupted append; two threads at once;
   the box placed in a map; a copy in slices.

## Open questions

- *A mode on write-path, or a box of its own?*
- *What does append-path answer?*
- *Is a file built from many appends written atomically as a whole?*
- *What does an append do on a full card?*
- *Is rewriting the block that holds the file's old end safe?*

### Proposed answers (UNVERIFIED)

1. *A mode or a box?* A box of its own, `append_path`. The engine has no
   optional input and no flag that is not a port; a mode would be a third
   port every writer had to wire, and a `write-path` that might append
   would read the same in a map as one that replaces. docs/011 says
   anything beyond the six boxes is a new box added when an app needs it;
   the painter is that app.
2. *What does it answer?* 0 or a negative code, exactly as `write_path`,
   so either can feed the same consumer. A failed read as the value is not
   appended and its status is passed on, so a copy loop whose source runs
   out stops growing the destination rather than adding nothing silently.
   A value claiming more than 4096 bytes is refused, as for write-path.
3. *Atomic as a whole?* No. Each append is; between appends the file is
   the appends so far. A program that wants a large file to appear all at
   once builds it under another name and moves it over the old one, as
   docs/011 has apps do. There is no box that renames a file yet: that is
   the next thing the painter needs, and it is not built here. *(414
   builds it: `move-path`.)*
4. *A full card?* `FAT_NO_SPACE` in the value, and the file and the free
   space as they were: the clusters taken for it are given back before the
   answer.
5. *The block holding the old end?* It is read and written back with the
   file's own bytes in it unchanged and new bytes after them. A card that
   tears a single block write could lose what was in that block; the
   directory entry's update in every write already takes that same risk,
   and the alternative (copying the last cluster and relinking) moves file
   bytes a reader can see, which is worse.

6. *(new) How is "whole or not at all" shown, rather than argued?* The
   twin can take its card out part-way through a write:
   `twin_card_pull_after(n)` lets `n` more blocks land (a write of several
   blocks landing only partly) and then fails every read and write, as a
   card leaving the slot would; `twin_card_blocks_written()` counts what an
   operation costs. Test 093 runs each kind of write once to count its
   blocks, then again with the card pulled after every one of those counts,
   mounting afresh each time: replacing a file (53 blocks), appending across
   clusters (42), appending inside the last cluster (3), and making a file
   in two directories that are not there (62). Every time the file is old
   or new and never torn, every interrupted write said it failed, and the
   card takes the next append with a chain exactly its size. Moving the
   size write ahead of the chain, or letting a table write's failure pass
   unreported, each fails the test. The pull is the twin's alone; the
   device's card cannot be told to fail.

## Related documents

- `docs/011-filesystem.md` — the box abstraction section, and
  "Journaling".
- `issues/completed/406-read-write-path-boxes.md` — the 4096-byte value.

## Blocked by

405, 406.

## Blocks

810 (the painter saves a drawing larger than one value), 412.
