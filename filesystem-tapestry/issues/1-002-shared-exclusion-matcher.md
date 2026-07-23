# 1-002 — Shared Exclusion Matcher

## Phase 1: The Thread

## Current Behavior

The scanner would treat a `.git` object, a `node_modules` tree, and a video the
same. Walking `next`/`previous` through a cache directory is useless, but there
is no notion of "unimportant" paths.

## Intended Behavior

A matcher that answers one question — *should this path be excluded from the
walk?* — built by reading the **shared, unified `.gitignore`** that the
delta-version project already maintains across every project on these drives, at
`/mnt/mtwo/programming/ai-stuff/.gitignore`. We do not keep our own copy of
"what to ignore"; there is one source of truth, and we read it at runtime.

Rules honoured from the gitignore file:

- Blank lines and `#` comments are skipped.
- A trailing `/` marks a directory pattern.
- A leading `/` anchors to a path root; otherwise the pattern may match any
  path segment.
- `*` matches within a path segment; `**` matches across segments.
- A leading `!` is a negation (un-ignore) and is applied after positive matches.

**Excluded is not dropped.** The matcher only labels; the scanner still writes a
record for the excluded file (with `excluded = true`). Excluded files remain in
the chronological catalog and are only skipped by the navigator's browse walk.

The path to the shared gitignore is configurable (`config.exclusion_source`) so
the tool still works if that file moves, and a **missing source is a flagged
warning** — the tool runs with an empty exclusion set and says so, rather than
silently excluding nothing as if that were intended.

## Suggested Implementation Steps

1. Parse the gitignore into a list of `{ pattern, is_dir, anchored, negate }`.
2. Compile each pattern to a Lua pattern or a segment test; cache compiled forms.
3. Expose `matcher:is_excluded(path)` returning a boolean, applying negations
   last.
4. On a missing/unreadable source, log a warning and return a matcher that
   excludes nothing.

## Related

- `libs/02-exclusion.lua` (implementation)
- delta-version `scripts/generate-unified-gitignore.sh` (produces the source)
- `docs/datapath-catalog.md` §3

## Metadata

- Status: In progress
- Phase: 1
- Blocks: 1-001 (scanner stamps `excluded`)
