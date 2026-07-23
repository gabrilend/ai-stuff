# 05-ordering-engine.lua — info

Turns the catalog into a **walk order** — a list of catalog positions, never a
copy of the records. Three walks; a dispatch table picks between them.

## External functions

- `build(records, mode, opts) -> order[]` — the one entry point. `mode` is
  `chronological`, `similar`, or `different`. Unknown modes error (never guess).
- `chronological(records, opts) -> order[]` — sort positions by `opts.field`
  (`created` / `modified`), `opts.direction` (`asc` / `desc`). `opts.include_
  excluded` decides whether junk-directory files appear. Ties break on path, so
  the walk is deterministic across runs.
- `nearest_neighbour_order(pool, seed, sim) -> order[]` — the "similar" walk:
  order the pool most→least similar to `seed`. **Phase 2 seam.**
- `diversity_chain(pool, seed, sim) -> order[]` — the "different" walk: greedy,
  at each step hop to the least-similar unvisited position. Faithful to neocities
  `diversity-chaining.lua`. **Phase 2 seam.**

## Phase-2 seam behaviour

`similar` / `different` look for `opts.similarity` — a provider `sim(i, j) ->
score in [0,1]` fed by policy embeddings. When it is **absent**, they log a
warning and delegate to `chronological`, so a meaning-walk is never silently
wrong: it either uses real similarity or tells you it could not.

`opts.seed` is the catalog position to start a meaning-walk from (the navigator
passes the file you are standing on).
