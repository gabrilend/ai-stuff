# Issue 520: A Map's Own Script Runs

**Phase:** 3/4 (JASS and runtime), carried into the Phase 5 viewer
**Type:** Implementation
**Priority:** High
**Dependencies:** 309 (lexer, parser, transpiler), 518 (interface), 519 (combat)

---

## Current Behavior

The JASS lexer, parser and transpiler (309) have unit tests, but the real
maps' scripts crash the lexer (15 of 16) or produce Lua that won't load (1
of 16). The runtime (Phase 3, `src/runtime/`) is a singleton with no
waits (`TriggerSleepAction` is a stub). The viewer finds units by
searching the script's text for `CreateUnit` calls with literal positions;
triggers, timers, quests, dialogs and chat commands never run.

## Intended Behavior

A WC3-style trigger system in Lua that runs a map's own `war3map.j`,
transpiled automatically: `config()`, `main()`, and from then on its
triggers, timers and waits, on the game from 519. Also a measurement of
how automatic the transpiling can be.

| Part | What | Where |
|------|------|-------|
| 520a | Every test map's script transpiles and loads | `src/jass/lexer.lua`, `parser.lua`, `transpiler.lua` |
| 520b | The VM: environment, threads with waits, triggers, events, timers, accounting | `src/jass/vm.lua` |
| 520c | Natives, and our own Blizzard.j functions | `src/jass/natives/{core,world,interface,bj}.lua` |
| 520d | The game hosts the script: units it makes, kills, hides, changes hands; alliances | `src/demo/wc3map/{game,combat,scene}.lua` |
| 520e | The interface shows it: messages, chat, dialogs, timer windows, multiboards, quests, Esc | `src/ui/wc3/script_ui.lua`, `hud.lua`, `demo/wc3map/main.lua`, `render/scene_viewer.c` |

## Acceptance Criteria

- [x] All 16 test maps: lex, parse, transpile and load with no errors
- [x] All 16 run `config()` and `main()` and two game minutes with no errors and no missing names
- [x] Every function any of the 16 scripts calls from outside is provided (703 of 703)
- [x] `+` and `/` are typed when transpiling for every operation in the 16 maps
- [x] Waits keep their thread's event responses (a thread's `GetTriggerUnit()` after `TriggerSleepAction`)
- [x] DAoW 5.4b on the game: the script makes the units, tells its story, shows its game-mode dialog, answers chat commands
- [x] `test_jass_vm.lua`: 28 tests; full suite passes
- [x] The viewer, rendered unattended: messages, timer window, dialog, chat

## Implementation Notes

**Date:** 2026-09-29

### How automatic can a transpiler be?

For the language, completely: nothing in the 62,856 lines of the 16
maps' scripts needed a hand edit. What it takes is below.

| Layer | Automatic? | What it took |
|-------|-----------|--------------|
| Syntax to Lua | Yes, 16 of 16 | Lexer and parser fixes, and two output changes (520a) |
| Types for `+` and `/` | Yes, 5,745 of 5,745 operations | The natives' return types and Blizzard.j's variable types, handed to the transpiler |
| Semantics (waits, event responses, handles, integer division, array defaults) | Yes, in the VM | Written once for every map |
| The API: 703 functions the scripts call from outside | No: hand-written, once | 553 behave, 150 knowingly do nothing (sound, camera, fog, floating text) |

The transpiler is the easy part. The work is the API. A map script is
mostly calls (289,819 calls to outside functions in the 16 maps), and
those functions live in the game (common.j's natives) and in Blizzard.j.
Neither is in the maps or in this project; both are written here from
their documented behaviour. It's an emulator's BIOS: written once, then
every map runs.

### 520a: the transpiler, on real maps

A probe over the 16 test maps (`scripts\war3map.j` in each) found:

- **Lexer** (15 maps crashed):
  - 1-character rawcodes (`'d'`)
  - lines ending in a lone CR
  - strings that span lines
  - the `\b` and `\f` escapes
  - Two lexer tests encoded the old behaviour and were changed on purpose.
- **Parser:** `constant function` at the top level.
- **Transpiler, output that wouldn't load** (1 map):
  - More than 200 locals in one chunk. The new `scope = "env"` option emits globals and functions as names in an environment table, not Lua locals.
  - A `return` that isn't last in its block is now emitted as `do return x end`.
- **Transpiler, meaning:**
  - Integer literals written `$FF`, `0x` and `0`-octal are converted.
  - Lua keywords used as JASS names get a trailing `_`.
  - Call statements in env scope no longer take the `runtime.` prefix.
- **Types:** `expr_type` infers the type of an expression, so `+` becomes `..` for strings and `/` truncates for integers. `native_types` (function return types) and `global_types` (Blizzard.j variables) come from the VM's natives. An operation whose type is still unknown falls back to `__jass.add` or `__jass.idiv`; with the VM's types there are none left.

### 520b: the VM

`vm.new(world, opts)` provides:

- An environment: natives copied in, and the map's globals and functions
  land there when it loads.
- Unknown names, resolved by shape:
  - `ALL_CAPS` names are symbolic constants, each its own interned name.
  - `bj_` names are Blizzard.j variables.
  - Any other unknown name becomes a stub that does nothing and is counted in `V.missing`.

Threads:

- Every trigger action, timer callback and `ExecuteFunc` is a coroutine.
- Each carries its event context, so a wait doesn't lose `GetTriggerUnit()`.
- An error ends only its own thread (`V.errors`).

Events and timers:

- Events are registrations keyed by event name, filtered by player, unit, dialog or boolexpr.
- Rect enter/leave events are checked every 0.1 s for units that moved; a rect starts out knowing who is already inside it.
- Unit-in-range events are checked on the same clock.
- Timers can fire at most 50 times per tick, so a 0-period timer can't hang one.

The lobby (`apply_lobby`, run between `config()` and `main()`): the local
player, and `opts.humans`, are users; the other playing slots are computers.

### 520c: natives and Blizzard.j

What's written:

- 553 functions behave; 150 deliberately do nothing and are counted in `V.noops`.
- Hashtables and game caches.
- Our own versions of Blizzard.j's filters and its "last created" variables.
- Every Blizzard.j array a map may fill in: maps that inline InitBlizzard (DAoW does) write `bj_FORCE_PLAYER`, `bj_queuedExecTriggers` and others.

Order ids are from memory of the game.

Two behaviours are invented, not measured:

- `UnitId2String` gives the type id back, so the usual round trip through
  `GroupEnumUnitsOfType` finds the type. DAoW counts its control points
  that way: 96 of 149 to win, which is the 65% its own help text states.
- `EVENT_PLAYER_UNIT_CHANGE_OWNER` fires for both the old owner and the new
  one.

### 520d: the game hosts it

- `game.new(scene, { placed = false })` starts with no units, and `game.run_script()` runs the map's script, which makes them.
- DAoW 5.4b's script makes 4,379 units; the text search found 4,378.
- New calls: `game.spawn`, `game.remove`, `game.kill` and `game.damage`.
- Heroes wait to be revived instead of vanishing.
- Combat asks the script who is allied (`game.allied`) and leaves invulnerable and hidden units alone.
- `game.on_attack` gives the script its `EVENT_PLAYER_UNIT_ATTACKED`.
- Gold and lumber shown are the script's.
- Speed: about 0.9 s to transpile and load DAoW 5.4b's script (891 KB of JASS, 23,600 lines of Lua), 0.3 s for `main()`, and 120 game seconds headless in about 21 s. That is combat's 3 ms a tick; the VM adds little.

### 520e: what players see

`ui/wc3/script_ui.lua`:

- Messages, with WC3's `|c` colours and wrapping.
- A chat line: Enter to open and send, Backspace, Esc.
- Modal dialogs.
- Countdown windows and the first multiboard.
- Quests (F9) and the log (F12) come from the script.
- Esc tells the script the player skipped a cinematic.
- The Allies panel reads the script's alliances.
- Hidden units aren't drawn or picked.

Changes outside that file:

- `viewer.chars()` in `scene_viewer.c` gives typed text.
- `SCENE_ACTIONS` gains `chat:TEXT` and `dialog:N`.
- `WC3_SCRIPT=0` goes back to reading units from the script's text.

### Checked on DAoW 5.4b

In order:

- The intro tells the story over its first minute.
- At 78 s the host gets "Pick Game Mode: Normal | Roleplay | Conquest".
- A Conquest vote reports "(1/2)": the map requires `R2I(0.49 × humans) + 2` votes, so a lone player can't force it.
- At 100 s the map picks Normal itself.
- `-time` and `-income` answer.
- The "Income in:" window counts down.

### Not yet

- **No system yet** (the 150 no-op natives): sound, music, camera moves, fog of war, weather, special effects, floating text, cinematics.
- **Not used by the command card:** the script's tech limits (`SetPlayerTechMaxAllowed`) and unit abilities are kept, not applied.
- **Not simulated:**
  - Spells, research, training and item events. They register but never fire.
  - Waygates. They keep their destination but don't teleport.
- **Map doodads aren't destructable handles:** enumerating destructables finds none.
- **Computer players have no AI.**
- **Two runtimes:** the Phase-3 runtime (`src/runtime/{init,triggers,events,timers}.lua`) and this VM overlap. Its tests still pass. Folding one into the other is future work.
