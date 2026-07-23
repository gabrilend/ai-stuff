# 03-cataloger.lua — info

The generation half's workhorse. A **script**, not a module (nothing requires
it), so the generation half stays sealed off from viewing.

## Invocation

    TAPESTRY_DIR=<dir> luajit src/03-cataloger.lua <root>

Walks one `<root>`, writes a shard to `tmp/catalog-<root-tag>.jsonl`. `run.sh`
starts one per configured root, in parallel.

## How it works

- Enumerates with `find <root> -xdev -type f -print0` and reads timestamps with
  `stat --printf '%W\t%Y\t%s\t%n\0'`. `stat` is in the pipeline because **find
  cannot emit birth time (`%W`)** — and birth time is the "created" date.
- `-xdev` keeps the walk on one filesystem (never crosses into another root's
  drive).
- Records are NUL-terminated, so paths containing tabs/newlines survive; the
  path is everything after the third tab.
- Birth time `0`/unknown → `created` falls back to `modified` and the record is
  flagged `created_is_fallback = true` (counted and reported, never silent).
- Each record is stamped with `kind` (media dispatch) and `excluded` (exclusion
  matcher).

## Output

One JSON-lines record per file (see `docs/datapath-catalog.md`). stderr from
find/stat (e.g. permission denied) is left visible on purpose.
