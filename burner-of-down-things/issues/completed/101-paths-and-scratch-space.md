# 101 — Paths and scratch space

Everything the machine does is relative to one folder. This issue fixes that
folder, the launcher that sets it, and the RAM scratch space logs go to.

## Current Behavior

Built. `machine` at the project root holds `DIR`, takes an absolute folder as an optional first argument, refuses a folder without `src/019-the-machine.lua`, refuses when LuaJIT is missing, rebuilds the RAM tiers with the house helper, and runs `src/019-the-machine.lua`. `src/013-paths.lua` builds every path from `DIR` and sets the module search path (project `src/`, `libs/`, the effil build folder). `.gitignore` carries `cases/` and `output/goodbye`. Checked by tests/025 running the launcher against a copy of the project.

## Intended Behavior

- A root script `machine` (bash) with the project folder written at its top
  as `DIR`, overridable by a first argument that is an existing folder. It
  makes sure the RAM scratch tiers exist (the house library
  `ensure-ram-tiers`), then runs the Lua entry point with LuaJIT, passing
  `DIR` and the remaining arguments.
- A Lua module of paths: given `DIR`, returns the absolute paths every other
  module uses — `src/`, `cases/`, the scratch folder `tmp/shared-memory/`, the
  shared Lua libraries folder — so no other module builds a path from a
  string it made up.
- The module search path is set once, in the entry point, from `DIR`: the
  project's `src/` and `libs/`, and the thread library's build folder.
- `cases/` is in `.gitignore` ([003](../docs/003-datapath-the-case-and-the-ledger.md)).

| Decision | What each path leads to |
|---|---|
| `DIR` does not contain `src/` | The launcher refuses, naming `DIR`: it is not this project |
| LuaJIT is not installed | Refused, naming it. No fallback to another Lua: the house forbids 5.4 syntax and the thread library is built for LuaJIT |

## Suggested Implementation Steps

1. `machine` launcher with `DIR`, the argument override, the tiers call.
   **Test:** run from `/` with and without the override; both reach the
   entry point with the right `DIR`.
2. The paths module. **Test:** every returned path is absolute and starts
   with `DIR`.
3. `.gitignore` gains `cases/`.

## Blocked by

None.

## Related documents and tools

- `/mnt/mtwo/programming/ai-stuff/scripts/libs/ensure-ram-tiers`
- [012 — The commands](../docs/012-the-commands.md)
