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

## Related documents

- `docs/011-filesystem.md` — symlinks section.

## Blocked by

403, 404.

## Blocks

406, 407.
