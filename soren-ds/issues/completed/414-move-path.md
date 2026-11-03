# 414 — move-path: a large file appears all at once

## Current behavior

`append-path` (413) builds a file larger than one 4096-byte value, one
append at a time. Each append is whole, but the file between appends is
the appends so far: a reader of `/drawings/cat` while the painter saves
it sees a half-saved drawing. docs/011 already tells apps how to avoid
that ("write to a temporary path and rename on top of the destination"),
but there is no box that renames, so no program can.

## Intended behavior

- **`move-path`** — input ports `from` and `to` (two paths). The file at
  `from` takes the name `to`, replacing any file that had it, and making
  any directories on the way. Output is 0 or a negative code.
- A large file is built under a name of its own and moved over the name
  readers use. A reader, or a card pulled out part-way, finds the old file
  or the whole new one at `to`.
- A symlink at either end is moved, or replaced, as itself: the name
  moves, not what it leads to (as `rename` does on a laptop).
- A directory is neither moved nor replaced; the status says so.

Underneath, `files_move` (078) keeps the order that makes it safe to
interrupt:

1. The old name is removed. Its short entry goes before its long-name
   pieces (`fat_dir_remove` now removes in that order everywhere), so an
   interruption leaves pieces that belong to nothing, which readers skip,
   never the file living on under a short name the card made up.
2. The new name is pointed at the chain: one block write onto an entry
   that is there, or a new entry.
3. A replaced file's clusters are freed and the table written.

Interrupted after step 1, the chain belongs to no name: the destination is
as it was, and the space is lost until `fsck.fat` finds it. There is no
moment when two names share one chain.

## Suggested implementation steps

1. `fat_dir_remove`: the short entry first, then the long-name pieces.
2. `files_move(from, to)` under the card's lock.
3. `move_path(from, to)` in `src/boxes/082-files.c`.
4. Test: moves to new names, onto files, onto and of links, refused
   directories and the root, the same file spelt twice, a long name's
   slots all freed; the card pulled after every block of two kinds of
   move; the box after three appends.

## Open questions

- *Which goes first, the old name or the new?*
- *What if the new name cannot be written?*
- *Follow links, or move them?*
- *Directories?*
- *What does move-path answer?*

### Proposed answers (UNVERIFIED)

1. *Old name first.* New-name-first leaves, when interrupted, two names
   on one chain; the next delete of the temporary name would free the
   bytes the destination still points at, which corrupts the very file the
   move was meant to protect. Old-name-first risks only the temporary file
   (its chain becomes lost space, and the program builds it again). Test
   094 catches the other order: pulled at the right block, the two names
   share a chain.
2. *Put the old name back.* A failure that is not the card's (a
   directory full to FAT's limit) re-adds the old name in the slots it
   just gave up, so the file is where it was and the status says why. A
   card that fails is a card that fails; nothing more is written to it.
3. *Move them*, as a laptop's rename does. Following would make
   "replace the link `latest` with this file" impossible to say.
4. *Not moved, not replaced.* Moving a directory means rewriting its
   `..` entry, and replacing one means deciding what happens to what is in
   it. No app needs either yet (docs/011: add surface when an app needs
   it).
5. *0 or a negative code*, as `write-path` and `append-path`, so any of
   them can feed the same consumer. A path that cannot be a path is
   refused, as for every filesystem box.

## What happened

Built as described. Test 094 (27 checks) on the twin: pulled after every
one of a replacing move's 21 blocks and a long-named, new-directory
move's 49, the destination was always old or moved, never torn; the two
names never shared a chain; and no file was ever left under a name the
card made up. Removing long-name pieces before the short entry (the old
order) fails that last check; adding the new name before removing the old
fails the second.

## Related documents

- `docs/011-filesystem.md` — "Journaling", and the box abstraction.
- `issues/completed/413-append-path.md` — why a file is built in pieces.

## Blocked by

405, 406, 413.

## Blocks

810 (the painter saves a drawing that appears all at once), 412.
