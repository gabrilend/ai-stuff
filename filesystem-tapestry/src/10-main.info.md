# 10-main.lua — info

The viewing half's entry point. A script. Bookends every session with the two
house-rule chores.

## Flow

1. `apply_overrides` — install any per-kind viewer overrides from config.
2. **First:** `read_input()` — scan `input/` for `key=value` lines
   (`mode=`, `field=`, `direction=`) that pre-set where the walk begins. Unknown
   lines are ignored; `input/` is scratch space, not a schema.
3. `store.load` the catalog (empty catalog → error with a hint to scan).
4. `navigator.run` the interactive walk.
5. **Last:** `write_goodbye(ending)` — record where the walk ended into
   `output/goodbye`.

## Invocation

    TAPESTRY_DIR=<dir> luajit src/10-main.lua

Normally launched via `./run.sh` (which also handles scanning).
