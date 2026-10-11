# 101 — The program's doors: read input, write goodbye

**Phase:** 1 — The world beneath
**Blocked by:** None
**Blocks:** 102, 108, 201, 109, 209
**Related documents:** docs/architecture.md (Start and end, Reading order)

## Current Behavior

Mostly built (2026-10-10). `src/conf.lua` and `src/main.lua` are thin
doors; `src/001-read-the-input.lua` reads and checks `input/game-settings.lua`
(every field required, ranges checked, missing fields named);
`src/002-say-goodbye.lua` writes `output/goodbye` last. The root `run`
script rebuilds the RAM tiers and starts the game; `scripts/run-tests` runs
every `*.test.lua` under LuaJIT (31 checks, including a missing seed stopping
the program). Not built yet: the `--headless` mode (simulation with no
window).

## Intended Behavior

- `src/main.lua` and `src/conf.lua` exist because LÖVE demands those exact
  names. They are thin doors: `conf.lua` sets the window title and size;
  `main.lua` loads the indexed source files in order and hands LÖVE's
  callbacks to them. Neither holds game logic.
- The first indexed file reads `input/` — a plain Lua-table settings file
  (`input/game-settings.lua`: seed, team size, which seats are human, starting
  tier, tick rate). Any missing or malformed field stops the program with an
  error naming the field and the file. No defaults are invented.
- A headless mode (`--headless`, no window) runs only the simulation, for
  tests and balance runs.
- On exit, the last thing written is `output/goodbye` (date, seed, ticks run).
- Logs go to `tmp/shared-memory/`. The run script rebuilds the RAM tiers
  before anything writes there.
- A test runner (`scripts/run-tests`) runs every `*.test.lua` file under
  LuaJIT and reports pass/fail counts; it is run by every later issue.

## Suggested Implementation Steps

1. Create `src/conf.lua` and `src/main.lua` as doors; record in each a
   comment saying why they break the indexed-name rule.
2. Create `src/001-read-the-input.lua` (+ `.info.md`): load the settings
   table in a sandbox, check every field's presence and type.
3. Create `src/002-say-goodbye.lua`: write `output/goodbye`.
4. Create `run` at project root: hard-coded `DIR`, optional `DIR` argument,
   sources `scripts/libs/ensure-ram-tiers`, launches `love "${DIR}/src"`
   with `--headless` passed through.
5. Create `scripts/run-tests` and a first test proving a missing seed fails
   loudly.
6. Bump `.file-index-counter`.
