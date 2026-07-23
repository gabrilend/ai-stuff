# 04-catalog-store.lua — info

The seam between the generation half (which writes shards) and the viewing half
(which reads the catalog). The **only** file both halves touch.

## External functions

- `merge_shards(tmp_dir, out_path) -> total` — concatenate every
  `catalog-*.jsonl` shard in `tmp_dir` into one catalog at `out_path`. Returns
  the record count. Warns if no shards are found.
- `load(path) -> records[]` — read `catalog.jsonl` into an array of record
  tables for the viewing half. A missing catalog is an error with a hint to run
  the scan; a single unparseable line is warned and skipped (partial data still
  makes a usable walk).

## Record shape

`{ path, created, modified, size, kind, excluded, created_is_fallback }` — see
`docs/datapath-catalog.md` for the authoritative field table.

## Note

Loading the whole catalog into memory is what lets the navigator jump to any
index instantly. A future issue can page it if a drive's catalog outgrows RAM.
