# 1-004 — Ordering Engine (Chronological)

## Phase 1: The Thread

## Current Behavior

The catalog is an unordered array. There is no notion of "walk it oldest to
newest."

## Intended Behavior

An engine that turns the catalog into an **ordering** — an array of catalog
indices in the order you should walk them. It never copies or moves records; it
returns indices.

Phase 1 implements the **chronological** ordering:

- sort key: `created` (birth) or `modified` (mtime), chosen by config/command
- direction: ascending (oldest first) or descending (newest first)
- excluded records may be included or filtered depending on the caller; the
  navigator's default browse walk filters them, but a "full timeline" view can
  ask for all of them (excluded-but-referenced-chronologically).

The same module declares the seams for the Phase 2 orderings — `similar` and
`different` — so the navigator can call `ordering_engine:build(mode)` uniformly.
Until Phase 2 data exists, `similar` and `different` **return the chronological
ordering and log a warning** that they fell back; the ordering is never silently
wrong.

## Suggested Implementation Steps

1. `engine.chronological(records, {field, direction, include_excluded})`
   → array of indices, stable-sorted.
2. `engine.build(records, mode, opts)` — dispatch table on `mode`
   (`chronological` / `similar` / `different`), not an if-else ladder.
3. `similar` / `different` entries: if no similarity data is loaded, warn and
   delegate to `chronological`.

## Related

- `src/05-ordering-engine.lua` (implementation)
- Phase 2 issues 2-004 (similar), 2-005 (different) fill in the seams
- neocities `src/diversity-chaining.lua` (the different-walk algorithm)

## Metadata

- Status: In progress
- Phase: 1
- Blocks: 1-006
