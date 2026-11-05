# Issue W02e: Triggers on the Server

**Phase:** W - WoW Client Bridge
**Type:** Sub-issue of W02
**Priority:** High (this is the rules engine for WC3 maps in the W client, decided 2026-09-23)
**Dependencies:** W02b (the creatures the triggers act on), W02c (the map id, factions and map.lua's transform the scripts use)
**Blocks:** W02g (orders reach the server and become creature movement), W02's acceptance line 5 (a timer trigger and a region-enter trigger run on the server)

---

## Current Behavior

*As written (2026-11-04, before this issue's work):* W02a-W02c's converter
(`src/wowbuild/`, `src/cli/wow-convert.lua`) writes a map's ground, its
placements and units, and its registration. Its script (`war3map.j`) is
not touched. The project's own runtime (`src/jass/vm.lua`, issue 520)
already runs any map's `war3map.j` in the editor and the converter's
process: it transpiles it (`src/jass/transpiler.lua`, "env" scope), loads
it into an environment of natives written in Lua (`src/jass/natives/`,
Blizzard.j's functions included), and counts every name it lacks. Nothing
runs a script on AzerothCore, and nothing says which natives a map needs
there.

*Now:* see Implementation Notes. Step 1 is built: the coverage report,
the transpiled script and the shim's data in the build folder, and the
shim's skeleton with its first natives, checked against the project's
runtime on a fake ALE. Nothing has run on a real AzerothCore yet.

## Intended Behavior

A converted map's triggers run on the server, in ALE (AzerothCore's Lua
engine, `mod-ale`):

- **The script is transpiled by the converter** (the same transpiler and
  native types the project's runtime uses), and written into the build
  folder for the server.
- **A shim implements JASS natives with ALE's calls**: timers and waits on
  ALE's timed events, units as creatures, regions checked against the
  creatures' positions, players' resources kept per WC3 player. Blizzard.j's
  functions are implemented too, since no map carries them.
- **Every native a map calls that the shim lacks is listed per map**, in
  the build folder, before the map reaches a server, and counted again
  when it runs. Nothing is skipped silently.
- **The project's own runtime is the reference.** Each native does what
  the runtime's native of the same name does; the same scripts run
  through both and are compared.
- **Every WC3 mechanic eventually** (scope widened 2026-10-07: combat,
  orders, pathing, economy, abilities): in ALE where ALE reaches, and in a
  server patch where it doesn't. The owner: "We might be able to implement
  those in Lua ALE? But patches are fine too."
- **The shim and any server module live in their own folder under AGPL
  v3**, because they run inside AzerothCore (AGPL v3) and ALE (GPL v3)
  (`docs/licensing-and-boundaries.md`).

## Suggested Implementation Steps

1. **The native-coverage report and the shim's skeleton.** List every
   native each map in `assets/` calls, with the project's own parser; say
   which the shim covers; write the report into the build folder from
   `wow-convert.lua`. Build the shim's skeleton (threads, waits, events,
   the script's environment, the missing-native count) and a first group
   of natives (timers, unit creation at a point, player gold and lumber,
   region enter) against a fake ALE, and check them against the project's
   runtime on the same calls. **Built 2026-11-04** (Implementation Notes).
2. **The server's loader, and the real ALE.** An ALE script that loads
   the shim, a map's `map-data.lua` and `war3map.lua` when the server
   starts (or the map is created), and runs `config()` and `main()`. Check
   every row of `shim.ALE_USED` against mod-ale on the owner's machine and
   mark it checked or change it. Then the first run on AzerothCore: W02's
   acceptance line 5 (a timer trigger and a region-enter trigger run on
   the server). Needs W02d (the server's ground) for heights; works
   without it at z = 0.
3. **Templates for the units triggers make.** The converter adds a
   creature template for every type the script makes
   (`unit_types_without_template` in the report: DAoW-2.1 makes 513, all
   by its script, none placed) and every owner it makes them for. Then
   units' state: life and mana, owner changes, kills and death events
   (ALE's creature events), with the runtime as reference.
4. **Orders and movement.** `IssuePointOrder` and the rest as creature
   movement (W02g sends players' orders the same way). Pathing is the
   server's navigation mesh (W02d's mmaps).
5. **Groups, forces, alliances, players' events.** Unit groups and their
   enumerations, forces, alliances as faction relations, chat and leave
   events from the WoW characters seated in WC3 player slots, text and
   dialogs to players (as messages to their characters, and for the W
   client as its own messages).
6. **The mechanics.** Combat, abilities, items, the economy, research,
   construction: in ALE where it reaches, as an AzerothCore module where it
   doesn't. Likely its own sub-issues (W02e1 ...), one per mechanic, each
   checked against the runtime.
7. **The whole of every map.** Coverage of every name each map in
   `assets/` calls; a harness that replays a map in the runtime and on the
   shim (the real server, or the fake) for minutes and compares their
   event logs.

## Acceptance Criteria

- [x] Every native each map in `assets/` calls is listed, with call
      sites, whether the shim has it and what the runtime does with it
      (19 maps, 745 distinct names)
- [x] `wow-convert.lua` writes the report into the build folder
      (`server/triggers/<dir>/natives-report.lua`) and counts it in
      `conversion-report.lua` and its summary
- [x] The shim lives in its own folder (`server-side/`) with the AGPL v3
      text, and requires nothing outside it; the converter reads only its
      list of natives, as data
- [x] Timers, waits, timer events, units made at a point, gold and lumber
      and region enter/leave do what the runtime does on the same script
      (a fake ALE against the VM, line by line, within one update)
- [x] Two maps' transpiled scripts load on the shim and run `main()`
      without an error; every native stubbed at run time is in the
      report's list; main() adopts every unit W02b placed
- [ ] Every row of `shim.ALE_USED` checked against mod-ale on the owner's
      machine (step 2)
- [ ] A timer trigger and a region-enter trigger run on the owner's
      AzerothCore (W02's line 5; step 2)
- [ ] Every native the maps in `assets/` call is in the shim (step 7)

## Notes

- *Splitter.* Written by hand from W02's table row in the project's issue
  style, as W02a, W02b and W02c were. The issue-splitter reads numbered
  issue ids only (W02a's Notes say where).

## Implementation Notes

*2026-11-04, background work the owner asked for (branch
`claude/wete-w02e-triggers`, on top of W02c's). The owner said to answer
the open questions and record the answers as decisions; each one below is
the owner's to overturn.*

### What was built

| File | Does |
|------|------|
| `server-side/LICENSE` | the GNU AGPL v3, the repository's own text |
| `server-side/README.md` | what runs inside the server, and the boundary with the rest |
| `server-side/ale/wc3shim/init.lua` | `shim.new(ale, data, opts)`; threads, waits, events, the script's environment; counted stand-ins for missing natives; `S:load`, `S:run_main`, `S:report`; `shim.ALE_USED`, the ALE calls it makes |
| `server-side/ale/wc3shim/core.lua` | numbers and strings, triggers, boolexprs, timers (ALE one-shot events), waits, timer events |
| `server-side/ale/wc3shim/world.lua` | players' gold, lumber and other states with the state event, units made at a point as creatures (adopting W02b's spawns), locations, rects, regions entered and left |
| `server-side/ale/wc3shim/covered.lua` | data: the 133 natives the shim implements, in 8 groups |
| `server-side/ale/wc3shim/fake_ale.lua` | ALE's calls as the shim uses them, in plain Lua: a clock moved by world updates, timed events, one map, creatures; a call it doesn't know raises |
| `src/wowbuild/triggers.lua` | the converter's side: reads the script, scans its calls, the coverage report, transpiles, writes `map-data.lua` |
| `src/wowbuild/init.lua` | `read_map` reads the script; `convert` calls `triggers.build`; the report and summary count it |
| `src/cli/wow-convert.lua` | passes the project folder (the shim's list is read from it) |
| `src/tests/test_wow_triggers.lua` | the tests (below) |
| `src/jass/vm.lua`, `src/jass/natives/bj.lua` | two fixes in the reference, found on the way (below) |

Build folder, added to W02a-W02c's, one folder a map:

| Path | Holds | Read by |
|------|-------|---------|
| `server/triggers/<dir>/war3map.lua` | the script transpiled ("env" scope, the runtime's native types) | the shim, on the server |
| `server/triggers/<dir>/map-data.lua` | map id, map.lua's transform, W02b's templates, factions and spawns, the script's global names, typed stand-ins, the runtime's constants (data) | the shim |
| `server/triggers/<dir>/natives-report.lua` | every native the script calls, with call sites, the shim's group, the runtime's answer (`does`, `no-op`, `missing`); the names the shim lacks; the types the script makes with no template; natives the map declares (data) | the owner; later steps |

### Checked

`luajit src/tests/test_wow_triggers.lua <project>`: 93 checks pass with
StormLib present. Without it, 49 pass and the maps' part is skipped.

- **The boundary.** Every file in `server-side/ale/wc3shim/` says its
  licence and requires nothing outside the folder; `server-side/LICENSE`
  is the repository's AGPL v3 text; `covered.lua` names exactly the
  natives the shim installs, and the runtime has every one of them.
- **Against the runtime, line by line.** Three made scripts run on the VM
  (a bare world ticked every 20 ms) and on the shim (the fake ALE updated
  every 20 ms); a test-only `Log` native records what each did and when.
  Same lines, in the same order, within one update (100 ms for the region
  check):
  - timers: periodic and one-shot, paused and resumed, time left and
    elapsed, `GetExpiredTimer`; periodic and one-shot timer events; a
    trigger disabled from its own action; `TriggerSleepAction` and
    `PolledWait`; integer division in a resumed thread; a periodic timer
    of 0 runs every 20 ms;
  - gold and lumber: set, adjusted (Blizzard.j's, which count gathered
    resources), `ConvertedPlayer`; `TriggerRegisterPlayerStateEvent` fires
    once when gold reaches its mark; each change heard by the hook W02g's
    resource bar will use;
  - units and regions: a unit made at a point, at a location (keeping
    `GetLastCreatedUnit`); walked into a rect and out of it (enter by
    `TriggerRegisterEnterRectSimple`, leave by a region); a unit already
    standing in the rect when it's registered doesn't enter it.
- **The creatures.** A unit made at a point is a creature of its
  template's entry, at map.lua's transform of its point, on the server's
  ground (z = 0 and counted where there is none), facing WC3's 90 degrees
  as WoW's orientation 0, not saved to the database. An owner whose type
  has no template of its faction gets the type's template and its own
  faction. A type with no template is a ghost, counted. `GetUnitX/Y` read
  the creature back in WC3 units; `RemoveUnit` despawns it.
- **W02b's spawns.** During main(), a `CreateUnit` where a spawn of the
  same type and owner stands takes that creature; elsewhere, or later, it
  spawns a new one.
- **ALE.** Every ALE call the shim made is in `shim.ALE_USED`, and every
  row there is marked unchecked.
- **The report** on a made script: the script's own functions aren't
  natives, call sites counted, covered or not, the runtime's answer,
  natives the map declares, types made with no template.
- **The maps in `assets/`**: every one has a script, and every script
  parses. Two are converted (`Master-Crafters-Final-Conquest`,
  `DAoW-2.1`): the report is data and counts the natives; `map-data.lua`
  has map.lua's id and transform and W02b's templates and spawns; the
  transpiled script loads on the shim and runs `main()` and ten seconds
  of timers with no error; every native stubbed at run time is in the
  report's list; main() adopts all 316 of Master Crafters' placed units;
  main() makes as many units on the shim as on the runtime through the
  natives the shim has (316; 1863 for DAoW-2.1); every player's gold
  after main() is the runtime's.

`test_wow_placements.lua` (72), `test_wow_registration.lua` (66),
`test_wow_terrain.lua` (70), `test_jass_vm.lua` (28), `test_economy.lua`
(30) and `test_resources.lua` (89) pass. The W client's readers weren't
built here, so the registration and terrain tests skip their parts.

### Coverage today

| Map | Natives called | Calls | Shim has | Of the calls | Lacks | Runtime lacks |
|-----|---------------:|------:|---------:|-------------:|------:|--------------:|
| Conquest-v8-fix | 222 | 7,923 | 40 | 66.9% | 182 | 6 |
| DAoW-2.1 | 458 | 11,710 | 80 | 61.4% | 378 | 0 |
| DAoW-5.2 | 277 | 23,328 | 50 | 62.7% | 227 | 0 |
| DAoW-5.3 | 333 | 19,417 | 55 | 56.6% | 278 | 0 |
| DAoW-5.4-PUBLIC-TEST-1 | 300 | 17,615 | 58 | 58.8% | 242 | 0 |
| DAoW-5.4a-PUBLIC-TEST-2 | 300 | 18,427 | 58 | 58.7% | 242 | 0 |
| DAoW-5.4b-PUBLIC-TEST | 303 | 19,852 | 58 | 58.2% | 245 | 0 |
| DAoW-5.4c (August) | 305 | 20,349 | 58 | 57.9% | 247 | 0 |
| DAoW-5.4c (July) | 306 | 20,918 | 58 | 58.1% | 248 | 0 |
| DAoW-5.4c (October) | 305 | 20,391 | 58 | 57.9% | 247 | 0 |
| DaoW-(HvA)-7.5 | 309 | 22,858 | 55 | 59.1% | 254 | 0 |
| DaoW-6.8-(HvA) | 310 | 21,927 | 55 | 57.5% | 255 | 0 |
| DaoW-6.93-(HvA) | 310 | 22,577 | 55 | 57.6% | 255 | 0 |
| Daow1.23.1B | 248 | 11,425 | 48 | 55.9% | 200 | 0 |
| Daow4.4 | 469 | 13,381 | 82 | 63.5% | 387 | 0 |
| Daow4.7.3 | 469 | 13,342 | 82 | 62.8% | 387 | 0 |
| Daow6.2 | 501 | 12,246 | 85 | 55.2% | 416 | 0 |
| Master-Crafters-Final-Conquest | 220 | 21,493 | 44 | 62.5% | 176 | 6 |
| War-in-the-Plaguelands-[24]-B6a | 214 | 26,069 | 49 | 54.3% | 165 | 5 |

Across the 19 maps, 745 distinct names; the shim has 101 of them. A
fifth to a sixth of each map's names, but more than half its call sites:
the trigger plumbing (`GetTriggerUnit`, `Player`, `Condition`,
`GetLastCreatedUnit`, `CreateUnit`) is most of every script. "Runtime
lacks" are names the project's own runtime doesn't have either
(`EnumItemsInRectBJ`, `PauseAllUnitsBJ`, `GetUnitRallyPoint` ...); they
need a reference first.

### Decisions

1. **The folder.** `server-side/` at the project's top, with
   `LICENSE` (AGPL v3) and `README.md`; the shim in
   `server-side/ale/wc3shim/`. A later C++ AzerothCore module goes beside
   it (`server-side/module/`). It requires nothing outside the folder; the
   converter reads one file from it (`covered.lua`) in an empty
   environment, as data; the tests load both sides, which is where they
   meet. What the converter writes for the server is program output.
2. **The shim reimplements; it doesn't reuse the runtime.** The runtime
   (`src/jass/`) would otherwise run inside the server, and would have to
   stay AGPL v3 forever. So the shim is its own code, written to do what
   the runtime does, and the tests compare the two. The same goes for
   Blizzard.j: the shim implements its functions, as the runtime does
   (`bj.lua`); nothing of Blizzard's is read or shipped.
3. **ALE's API is taken as a table** (on the server, `_G`), with ALE's own
   names, so the shim reads as ALE code and the fake can stand in for it.
   Every name the shim uses is a row of `shim.ALE_USED`, and the fake
   implements exactly those and raises on anything else. All rows are
   from memory and marked `checked = false`.
4. **Timers are one-shot events.** Each run of a timer, a wait and the
   region check is one `CreateLuaEvent(fn, ms, 1)`, scheduling the next;
   a periodic timer schedules its next run from when the last was *due*,
   so it doesn't drift. Pause cancels the event and keeps the time left.
   This leans on the fewest ALE semantics (no repeat counts, no changing
   a running event's delay). A wait or timer of 0 goes through ALE's
   queue at 1 ms; a periodic timer of timeout 0 repeats every 20 ms (the
   runtime fires it once a tick).
5. **The script is transpiled by the converter**, with the runtime's
   native types (so integer and real division and `+` on strings come
   out as the runtime's), and the server gets Lua. The transpiler and
   parser never run in the server.
6. **The report counts every name called and not defined** by the
   script: common.j's natives and Blizzard.j's functions alike (neither is
   in the map). Call sites are counted statically; the shim counts calls
   at run time (`S.missing`) as the runtime does. Each name carries the
   runtime's answer: `does`, `no-op` (the runtime deliberately does
   nothing: sound, camera, fog), or `missing`.
7. **A missing native's stand-in answers its type's zero.** For a native
   the shim lacks that answers an integer, a real or a string (the
   runtime's types), the stand-in returns 0 or "" (`map-data.lua`'s
   `stubs`), else nil. Without it, `GetCameraMargin(...) + x` in main()
   ended every map's main() at its first line. Still counted.
8. **Constants come with the map's data.** The runtime's constants with
   plain values (`PLAYER_NEUTRAL_PASSIVE` = 15, `bj_PI` ...) are written
   into `map-data.lua`, so the shim and the runtime agree by construction;
   every other ALL_CAPS name is its own name, as in the runtime.
9. **Units are creatures; their owner is a faction.** CreateUnit spawns
   the template W02b wrote for the type and the owner's faction; else
   the type's first template with the owner's faction set on the
   creature (`SetFaction`); else a ghost (a handle with a position and no
   creature), counted in `S.unspawnable`, so the script goes on. A
   trigger's creature is spawned unsaved (`save = false`), so it isn't
   written to the world database and doesn't come back at a restart.
10. **main() adopts W02b's spawns.** WC3 places a map's units from its own
    main() (Master Crafters' 316 `CreateUnit` calls), and the server has
    already spawned the same units from `server/world.sql`. While main()
    first runs (before its first wait), a `CreateUnit` of the same type
    and owner within 1 WC3 unit of a spawn takes that creature
    (`Map:GetWorldObject`) instead of making a second. Later calls always
    spawn. Each spawn is adopted once.
11. **Positions are WC3's on the script's side.** The shim converts with
    map.lua's `wc3_to_wow` and its inverse; a unit is read back from its
    creature only when the creature moved, so a unit standing where it
    was put keeps its point exactly. Facing: WC3's degrees from east to
    WoW's radians from north (minus 90 degrees), as W02b's placements.
12. **Ground height** comes from the server's map (`Map:GetHeight`).
    Where it has none (until W02d writes the map's `.map` files) a
    creature stands at z = 0, counted in `S.counts.no_ground`. A height
    below -100000 is taken as none (the server's INVALID_HEIGHT, -200000,
    from memory).
13. **Players' states live in the shim**, per WC3 player slot (0-15),
    with the runtime's state names. A WC3 player isn't a WoW character,
    and lumber has no WoW counterpart, so the character's money is left
    alone. `opts.on_player_state(p, key, value)` hears each change: W02g's
    resource bar (an addon message to the seated character, or the W
    client's own) hangs there.
14. **Regions are checked every 100 ms**, as the runtime's rects are:
    every unit the shim knows (made or adopted) is read from its creature,
    and a unit whose position or life changed is tested against every
    watched rect. Creatures the script never named (spawned by the
    server and not adopted) aren't seen yet; see open question 2.
15. **Each map has its own trigger folder** in the build folder
    (`server/triggers/<dir>/`), since a build folder holds several maps.
16. **The local player** (`GetLocalPlayer`) is player 0 on the server, as
    the runtime's default. On a server there is no local player; W02g
    and step 5 decide how per-player code (`if GetLocalPlayer() == p`)
    runs, likely per seated character.

### Found on the way (fixed in the reference too)

- `TriggerRegisterPlayerStateEvent` with a `LIMIT_OP_...` constant (the
  name scripts use) fell back to "equal" in the runtime: it compared the
  constant's name against `GREATER_THAN_OR_EQUAL` and the rest. Both now
  take the name with or without `LIMIT_OP_` (`src/jass/vm.lua`).
- Blizzard.j's `SetPlayerStateBJ` and `AdjustPlayerStateBJ` counted
  gathered gold and lumber under a key `GetPlayerState` never read
  (`gathered_gold` against `gold_gathered`). Both now count it where
  `PLAYER_STATE_GOLD_GATHERED` reads it (`src/jass/natives/bj.lua`).

### Known differences from the runtime

- **Timer reads inside another timer.** The runtime counts timers down
  tick by tick, one after another, so a timer read inside an earlier
  timer's callback in the same tick still shows the last tick's time left
  (1.720 where 1.700 is due). The shim reads the clock. The tests compare
  reals within one tick.
- **Events due at the same moment.** The runtime fires timers due in the
  same tick in the order they were made; the fake fires events in the
  order they come due, then the order they were scheduled. How ALE orders
  events due in the same world update is unchecked.

### Left open and unchecked

1. **ALE's API, every row of `shim.ALE_USED`**, is from memory. Check
   each against AzerothCore's `mod-ale` on the owner's machine (its API
   docs, which follow Eluna's, and `src/LuaEngine/methods/` and
   `LuaFunctions.cpp`), and the local checkout, which is still
   `mod-eluna` (W02's note; ALE replaces it and isn't script-compatible).
   In particular:
   - `CreateLuaEvent(fn, delay_ms, repeats)`: the argument order, whether
     1 means once, the callback's arguments, whether a delay of 0 is
     allowed, and how often events run (each world update?);
   - `GetCurrTime` / `GetTimeDiff` as milliseconds;
   - `PerformIngameSpawn`'s argument list (spawn type, entry, map,
     instance, x, y, z, o, save, despawn time, phase) and what a despawn
     time of 0 means for an unsaved creature;
   - `GetMapById(id, instance)`, and whether a global event may touch a
     map's creatures (AzerothCore updates maps on several threads; ALE may
     need its map-thread state, or `MapUpdate.Threads = 1`);
   - `Map:GetWorldObject(GetUnitGUID(low, entry))` for W02b's spawns, and
     whether a creature's low guid equals its database guid;
   - `Map:GetHeight(x, y)`'s answer where the server has no ground;
   - `Creature:GetX/GetY/GetZ/GetO`, `IsAlive`, `SetFaction`,
     `DespawnOrUnsummon(ms)`, `GetGUIDLow`.
2. **Creatures the script never names** (W02b's spawns that main()
   doesn't make, and anything the server spawns) don't enter regions yet.
   ALE has no map-wide creature list (from memory); the shim could take
   W02b's spawn list (`map-data.lua` has it) or `GetCreaturesInRange`
   around each rect. Step 2.
3. **A spawn that isn't on the map** when main() adopts it (AzerothCore
   loads a grid's creatures only when something is near, from memory)
   is adopted with no creature; the shim should look it up again later.
   Step 2.
4. **The Lua version ALE is built with** (LuaJIT, 5.1 or 5.2+) is
   unchecked; the shim loads the script with `setfenv` or `load`'s
   environment, whichever exists.
5. **How ALE loads files.** It runs every `.lua` under `lua_scripts/`
   (from memory); the shim's modules are harmless when run as scripts,
   but the loader (step 2) decides where they go and how `require` finds
   them.
6. **The 100 ms region check** costs a read of every known unit's
   position; with thousands of units (DAoW-2.1 makes 1863 in main())
   it may need the spatial grid the runtime's collision code has.
