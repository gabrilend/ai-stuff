# 405 — Path resolution and symlinks

## Current behavior

The directory walker (403) opens a directory by its starting
cluster. Above it, the runtime wants to ask "give me the file at
`/programs/hello/meta.json`" — a full path, not a cluster
number. There is no code yet that turns a string path into a
directory entry.

## Intended behavior

`path_resolve(const char *path, dir_entry *out)` walks a slash-
separated path starting from the root directory. For each
component:

1. Open the current directory.
2. Find the entry whose name matches the component.
3. If the entry's first 8 bytes are the symlink magic header
   (`SOSYMLNK` per `011-filesystem.md`), read the rest of the
   file, treat its bytes as a new path, recurse on that path.
   Hop count is capped at 32 to detect cycles.
4. If the entry is a directory and there are more components,
   descend.
5. If the entry is a file and this is the last component, return
   it.
6. If the entry's kind doesn't match the path's intent, error.

The function returns the resolved directory entry or an error
code. Errors include: component not found, broken symlink chain,
cycle detected, path too long.

A second function, `path_parent(const char *path, dir_entry *out)`,
returns the directory entry of the path's parent — needed for
operations like `delete-path` that need to update the parent's
directory listing.

The symlink check is done at every component, not just the last.
A symlink in the middle of a path follows transparently.

## Suggested implementation steps

1. `path_split()` — helper that yields path components.
2. `path_resolve()` — the main loop.
3. `is_symlink(dir_entry *)` — magic-header check.
4. `follow_symlink(dir_entry *, char *resolved_out)` — read the
   link's target.
5. `path_parent()` — same algorithm, stops one short.

## Open questions

- *Where does the lock the FAT layer assumes live, and what holds the
  mounted card?*
- *Is a symlink's target relative to the root or to the link?*
- *What do ".", "..", doubled slashes and a missing leading slash mean?*
- *Does writing a file make the directories on its way?* The six boxes
  of 011 include no `make-directory`, yet `/settings/`, `/drawings/`
  and the rest have to come from somewhere.
- *How does a write stay whole if the card is pulled out part-way?*
- *What happens to a path too long, or too deep?*

### Proposed answers (UNVERIFIED)

1. *Lock and card?* `src/system/078-files.c` owns the one mounted
   volume and one spin lock, and every public call takes it; the FAT
   layer below assumes it is held. `files_start(owner)` mounts (again,
   if a card was changed), `files_stop()` writes back and lets go. Phase
   2's rule for spin locks is a bounded, short hold; a card operation is
   bounded but not short on the device, which is acceptable while only
   filesystem boxes take this lock and nothing on the delivery path
   waits for it. If a box ever stalls a core noticeably on it, the box
   moves to a worker of its own rather than the lock changing kind.
2. *Relative to what?* A target starting with `/` starts from the root;
   any other is relative to the directory the link is in, as POSIX does
   it. That is what makes `../drawings/cat.raw` mean what it says.
3. *The small syntax?* Every path starts from the root whether or not
   it begins with `/`; empty components and `.` are skipped; `..` steps
   back up the way the path came down, never above the root. Names
   compare without regard to case.
4. *Directories on the way?* Yes: `files_write` and `files_make_link`
   make missing directories, like `mkdir -p`, and `files_make_directory`
   exists for the boot-time tree of 408. Reading, listing, deleting and
   asking never make anything. A path with more components than
   `FILES_DEPTH` is refused before anything is made.
5. *Pulled out part-way?* The new contents go into clusters no entry
   names; the table is written so the card records them as taken; one
   block write points the name at them; only then are the old clusters
   freed. Interrupted before the switch, the old file is whole and a
   laptop's checker reclaims the orphaned clusters; after it, the new
   one is. Deletion removes the name before freeing its clusters, for
   the same reason. That is 406's temp-and-rename with one fewer entry.
   (Not yet tested by pulling a card: the twin's card has no way to fail
   a write part-way. A twin that can is the honest next test.)
6. *Too long, too deep?* A new error, `FAT_TOO_LONG`, for a path of
   1024 bytes or more (links spliced in), a name longer than FAT holds,
   or more than 64 directories deep.
7. *Links in the middle and at the end?* As the issue asks: every
   component is checked; the last one is followed for read, write, size,
   list and exists, and not for delete (the link itself is removed) or
   for making a link over it. More than 32 links in one resolution is
   `FAT_LOOP`, and `files_exists` answers 0 for a loop or a link to
   nothing. The issue's `path_parent` is not a separate function: one
   walk answers both the entry and the directory it is in.

## Related documents

- `docs/011-filesystem.md` — symlinks section.

## Blocked by

403, 404.

## Blocks

406, 407.
