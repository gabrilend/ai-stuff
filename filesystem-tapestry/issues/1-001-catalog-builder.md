# 1-001 — Catalog Builder

## Phase 1: The Thread

## Current Behavior

Nothing records the creation and modification dates of the files on the user's
data drives. The information exists in the filesystem (ext4 birth time + mtime)
but there is no catalog of it.

## Intended Behavior

A scanner that, given a single **root** directory, walks every regular file
beneath it and emits one record per file capturing the two dates that matter and
enough metadata to view and order the file later.

Record shape (see `docs/datapath-catalog.md` for the authoritative field table):

- `path` — absolute path
- `created` — birth time (`stat %W`), epoch seconds
- `modified` — mtime (`stat %Y`), epoch seconds
- `size` — bytes
- `kind` — media class derived from extension (video/audio/image/text/doc/other)
- `excluded` — did the path match the shared exclusion list (issue 1-002)
- `created_is_fallback` — true when birth time was unavailable and modified time
  was substituted (a flagged fallback, never silent)

The scanner takes **one root** and writes a **shard** to the RAM tmp directory.
Roots are independent, so the run script (see `run.sh`) launches one scanner
process per configured root — the walk across the five drives is parallel, not a
single thread grinding through them in sequence.

The scanner stays on one filesystem (`find -xdev`) so it does not cross a mount
point and double-walk another root's drive.

## Suggested Implementation Steps

1. Enumerate files and read both timestamps in one pass. `find <root> -xdev
   -type f -print0` piped to `stat --printf '%W\t%Y\t%s\t%n\0'` gets birth time,
   mtime, size, and path per file. Birth time is the reason `stat` is used
   rather than `find -printf` alone — `find` cannot emit crtime. Records are
   NUL-terminated so paths containing tabs or newlines survive.
2. For each record, classify `kind` by extension via the media dispatch table
   (issue 1-005) and test `excluded` via the exclusion matcher (issue 1-002).
3. When `%W` is `0` or `-`, set `created = modified` and `created_is_fallback =
   true`, and count how many times this happened so the run can report it.
4. Write the shard as JSON-lines to `tmp/catalog-<root-tag>.jsonl`.

## Related

- `src/03-cataloger.lua` (implementation)
- `libs/02-exclusion.lua`, `libs/08-media-dispatch.lua` (dependencies)
- `docs/datapath-catalog.md` (record shape)

## Metadata

- Status: In progress
- Phase: 1
- Blocks: 1-003 (merge needs shards), 1-004 (ordering needs the catalog)
