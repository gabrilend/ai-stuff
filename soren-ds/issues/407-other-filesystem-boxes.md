# 407 — list-directory, delete-path, path-exists, make-symlink boxes

## Current behavior

`read-path` and `write-path` (406) handle bytes-in and bytes-out
on a file. The other four box kinds from `011-filesystem.md` do
not yet exist: directory listing, deletion, existence check, and
symlink creation.

## Intended behavior

Four more box descriptors get added to 208's table:

- **`list-directory`** — input port `path` (string), output is a
  list-of-strings value containing the names of every entry in
  the directory. A non-existent directory is a hard error, not
  an empty list. The function calls `path_resolve` to get the
  directory entry, opens it with `dir_open`, walks entries with
  `dir_next_entry`, collects names into the output buffer.
- **`delete-path`** — input port `path` (string), output is a
  success-or-error enum value. The function resolves the parent
  directory, finds the target's entry, frees its cluster chain
  with `chain_free`, removes the directory entry from the
  parent's listing. A non-empty directory is a hard error — the
  caller must walk and delete contents first.
- **`path-exists`** — input port `path` (string), output is a
  bool. The function calls `path_resolve` and translates the
  result to true (found) or false (not found, but the path is
  otherwise valid).
- **`make-symlink`** — input ports `link_path` (string) and
  `target_path` (string), output is a success-or-error value.
  The function creates a regular file at `link_path` whose
  contents are the symlink magic header (`SOSYMLNK`) followed
  by `target_path` as a null-terminated string. Subsequent path
  resolutions through `link_path` will follow the link per 405.

All four boxes are statically linked alongside `read-path` and
`write-path`. The pattern matches across all six: the box
function is a thin wrapper that calls the lower-level FS layer
and surfaces success-or-error back through the output value.

## Suggested implementation steps

1. `list_directory_box()`, `delete_path_box()`,
   `path_exists_box()`, `make_symlink_box()`.
2. Descriptor entries for each.
3. The output bytes shape for the list-of-strings result —
   pinned now so consumers can parse it (length-prefix per name,
   null terminator per name, count prefix).

## Related documents

- `docs/011-filesystem.md`.

## Blocked by

208, 403, 404, 405, 406 (for the bytes-output convention).

## Blocks

408, 412.
