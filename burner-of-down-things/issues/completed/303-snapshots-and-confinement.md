# 303 — Snapshots and confinement

The check after a turn that it changed only what it was allowed to
([005](../docs/005-datapath-the-hands.md), *confinement, twice*).

## Current Behavior

Built as `src/036-snapshots.lua`. `find` prints type, size, time, link target and path, NUL-separated; links are known by their target (`link:<target>`) and never followed, so a design's `tmp` link into RAM is never read through. Files over 64 MiB are known by size and time (`large:…`): a 943 MB git pack in a real source made a first snapshot take 14 s instead of 1.5 s. Charging uses the longest matching write prefix; a change no turn may write is a breach of the whole set, since turns running together cannot be told apart. Snapshots are kept in `turns/snapshot.tsv` so later runs hash almost nothing. Checked by tests/040.

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
