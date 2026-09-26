# 303 — Snapshots and confinement

The check after a turn that it changed only what it was allowed to
([005](../docs/005-datapath-the-hands.md), *confinement, twice*).

## Current Behavior

A turn could write anywhere and nobody would know.

## Intended Behavior

- **Snapshot** (list of root folders, excluded folders): every file under the
  roots → size, modification time, and SHA-256 when size or time is new since
  a previous snapshot given for reuse (so a second snapshot of an unchanged
  tree hashes nothing). Walks with the phase 2 walk (no skip table: every
  file counts), hashes in parallel with the thread pool pattern of 204.
- The case's `turns/` folder and `ledger` and `lock` are excluded — the
  machine itself writes them during a turn set.
- **Compare** (before, after, writable folders): every path created,
  changed or removed; each outside every writable folder is a breach entry
  (path and how it changed).
- **Charge** (changes, turns): each change inside a writable folder is
  given to the turn whose writable folder holds it most specifically; changes
  in a folder shared by all turns of the set are charged to the set.

## Suggested Implementation Steps

1. Snapshot and reuse. **Test:** unchanged tree → second snapshot computes
   zero hashes; a touched-but-unchanged file (new time, same bytes) is not a
   change.
2. Compare. **Test:** a create, a change, a removal, each inside and outside
   the writable list, reported exactly.
3. Charge. **Test:** two describe turns writing their own issue files are
   charged separately.

## Blocked by

- 103
- 201
- 301
