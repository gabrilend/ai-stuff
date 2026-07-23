# 1-003 — Catalog Store & Merge

## Phase 1: The Thread

## Current Behavior

Each scanner process writes its own shard for one root. Nothing assembles them
into a single catalog, and nothing loads a catalog back for viewing.

## Intended Behavior

The seam between the two halves of the system. This module:

- **Merges** the per-root shards (`tmp/catalog-*.jsonl`) into one catalog at
  `assets/catalog.jsonl`.
- **Loads** that catalog back into an array of records for the viewing half.

This file is the *only* thing generation and viewing share. Generation writes it;
viewing reads it; neither calls the other's code. An error while scanning cannot
reach the navigator, because the navigator only ever sees `catalog.jsonl`.

## Suggested Implementation Steps

1. `store.merge_shards(tmp_dir, out_path)` — concatenate every
   `catalog-*.jsonl` shard, counting total records and how many were flagged
   `excluded` or `created_is_fallback` for the run report.
2. `store.load(path)` — read `catalog.jsonl` into an array of record tables.
3. Keep JSON handling in `libs/01-utils.lua`; this module only orchestrates.

## Related

- `src/04-catalog-store.lua` (implementation)
- `libs/01-utils.lua` (JSON encode/decode)

## Metadata

- Status: In progress
- Phase: 1
- Blocks: 1-004, 1-006
