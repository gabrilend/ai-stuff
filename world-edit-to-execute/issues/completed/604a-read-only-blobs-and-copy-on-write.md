# Issue 604a: Read-Only Stored Files, Edited Copy-on-Write

**Phase:** 6
**Type:** Implementation
**Priority:** Medium
**Dependencies:** 604 (deduplication), 605 (storage manager)
**Blocks:** —

---

## Current Behavior

Every map and asset pack in the player data folder is a folder of links
into one store (`blobs/`, issue 604), where each file is kept once. The
stored files were ordinary writable files, so an editor opening a pack's
texture through its link and saving it would change the one stored copy:
every other map and pack that shared that texture would change with it,
and the store's name for it (its hash) would no longer match its bytes.

Found while building hot-reload (606, decision 9).

## Intended Behavior

Decided by Ritz on 2026-11-02: stored files become read-only. Editing one
through a pack's link first makes a private copy for that pack
(copy-on-write), so one edit can't change other maps or packs.

## Acceptance Criteria

- [x] A newly stored file is read-only
- [x] A store made earlier can be made read-only
- [x] One file, or every file of a map or pack, can be made its own copy
      to edit; the stored file and every other link to it are unchanged
- [x] An ordinary user's editor writing through a link is refused
- [x] A stored file nothing links to any more is still collected by `gc`

## Implementation Notes

**Date:** 2026-11-02

- **`src/assets/dedup.lua`:** a blob is made mode 0444 before it is
  renamed into place. `store:unshare(dest)` replaces a link into the store
  with a private copy of its bytes (mode 0644), written beside it and
  renamed over the link (so the link itself is replaced, never the blob),
  and drops its reference. `store:protect()` makes blobs that are still
  writable read-only and counts them.
- **`src/assets/storage.lua`:** `S:edit(kind, name[, path])` unshares one
  file, or every link in a map or pack; `S:protect()`.
- **`src/cli/storage.lua`:** `edit map|pack NAME [PATH]` (prints the paths
  to open in the editor) and `protect`.
- **`src/tests/test_storage.lua`** (now 67): a stored file is 0444; edit
  makes one pack's file a 0644 copy, the stored file and two maps sharing
  it are unchanged after writing the copy and the store still verifies;
  the copy counts as the pack's own bytes; editing again does nothing;
  edit with no path takes every remaining link; gc collects once nothing
  links; edit refuses a missing map, a path outside the folder, a missing
  file and a link leading outside the store; protect fixes an older
  writable blob and counts it; the tool's `edit` and `protect`; and, run
  as the unprivileged `nobody` when the test runs as root, reading through
  a link works and writing through it is refused.

### Decisions made while building

1. **The copy is made by asking, not by catching the editor's write.** An
   outside editor writes straight to the file system; nothing in the
   engine sees that write before it lands. The read-only mode makes such
   a write fail (for an ordinary user), and `storage.lua edit` makes the
   private copy to open instead. Hot-reload watches that copy like any
   other plain file in a pack.
2. **Root isn't stopped by the mode.** `verify()` still reports a blob
   whose bytes no longer match its name.
3. **The copy replaces the link in place** (same path, same name), so the
   loader, hot-reload and the map's own references find it with no
   change; it counts among the pack's unique bytes from then on.
4. **Old stores are fixed by `protect`, not on every open.** Opening a
   store stays one read of two small files; `protect` is one `find`.
5. **`gc` is unchanged:** removing a file needs its folder writable, not
   the file, so read-only blobs are collected as before.
