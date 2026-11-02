# 407 — list-directory, delete-path, path-exists, make-symlink boxes

## Current behavior

`read-path` and `write-path` (406) handle bytes-in and bytes-out
on a file. The other four box kinds from `011-filesystem.md` do
not yet exist: directory listing, deletion, existence check, and
symlink creation.

## Intended behavior

Four more boxes join the library, by the same route as 406's two —
ordinary C functions the generator finds and catalogues:

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

All four sit alongside `read-path` and `write-path`. The pattern
matches across all six: the box function is a thin wrapper that calls
the lower-level filesystem layer and surfaces success-or-error back
through its return value.

**A box that refuses rather than returning an error value** is the
other shape available now (214), and the six split between them: a
missing file is a result the caller may reasonably want to handle, so
it rides in the return value; a path that cannot be parsed at all is a
refusal.

## Suggested implementation steps

1. `list_directory_box()`, `delete_path_box()`,
   `path_exists_box()`, `make_symlink_box()`.
2. Nothing to register — the generator finds them by location.
3. The output bytes shape for the list-of-strings result —
   pinned now so consumers can parse it (length-prefix per name,
   null terminator per name, count prefix).

## Open questions

- *The list's layout — the issue's own third step.*
- *What happens to names that do not fit one value?*
- *Is `path-exists` ever an error?*

### Proposed answers (UNVERIFIED)

1. *Layout?* `struct name_list`: a status, a `count`, a `left_out`, the
   number of bytes `used`, then `count` names packed one after another,
   each as one byte giving its length, its characters, and a zero — the
   count prefix, length prefix and terminator the issue lists, in 4096
   bytes.
2. *Names that do not fit?* Listed up to the space, and counted in
   `left_out`, never dropped silently. A paged listing (an offset input,
   like `read_slice`) is the obvious next box when a directory first
   outgrows one value.
3. *path-exists an error?* Only a refusal for a path that cannot be a
   path. A link to nothing, links that loop, a file used as a directory
   on the way, and no card in the slot all answer 0.
4. *delete-path* removes a symlink itself, never its target; a directory
   with anything in it answers `FAT_NOT_EMPTY` as a status; asking to
   delete the root is refused.
5. *make-symlink* takes two paths; a relative target is relative to the
   link's directory. A link over an existing name answers `FAT_EXISTS`.

## Related documents

- `docs/011-filesystem.md`.

## Blocked by

301, 302, 403, 404, 405, 406 (for the bytes-output convention).

## Blocks

408, 412.
