# Issue 065c: Chapters From History

**Status**: Completed 2026-10-10
**Parent**: 065-the-reading-walk.md
**Dependencies**: 065a
**Blocks**: 065d, 065h

## Current Behavior
Each stop carries `chapter`: the date and subject line of the commit that
first added its file, shown at the top of the stop in the walk.

## Intended Behavior
`git log --diff-filter=A --format=%as%x09%s -- <file>`, oldest entry, one query
per file inside the first-pass workers. A file never committed gets the
subject "not yet in history" — it is reported, not skipped.

## Suggested Implementation Steps
1. First commit per file in the stops worker.
2. Tests: the fixture commits one file and leaves the other uncommitted.
