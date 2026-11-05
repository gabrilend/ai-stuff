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

*Now:* see Implementation Notes. Steps 1 and 2 are built: the coverage
report, the transpiled script and the shim's data in the build folder;
the shim's skeleton; and 574 natives (the most called ones: 95.5% of the
call sites across the 19 maps in `assets/`), each checked against the
project's runtime on a fake ALE. The unit types a script makes have
creature templates. Nothing has run on a real AzerothCore yet.

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
2. **The natives most called, on the fake.** Ranked by call sites across
   the maps in `assets/` (step 1's report), the next groups: units' state
   (life, death, owner, position, facing, flags, types, abilities),
   heroes, orders, unit events, groups and their enumerations, forces,
   players' slots and alliances, messages, chat and leave events, sounds,
   and Blizzard.j's arithmetic and conversions; each checked against the
   project's runtime as step 1's are. And the unit types only the script
   makes get creature templates, so a map without a unit file has no
   ghosts. **Built 2026-11-05** (Implementation Notes, step 2).
3. **The server's loader, and the real ALE.** An ALE script that loads
   the shim, a map's `map-data.lua` and `war3map.lua` when the server
   starts (or the map is created), and runs `config()` and `main()`. Check
   every row of `shim.ALE_USED` against mod-ale on the owner's machine and
   mark it checked or change it. Then the first run on AzerothCore: W02's
   acceptance line 5 (a timer trigger and a region-enter trigger run on
   the server). Needs W02d (the server's ground) for heights; works
   without it at z = 0. It also wires ALE's events the shim waits for:
   creature deaths (with their killer), and players' chat and leaving
   (`S:chat`, `S:player_event`) once W02g seats characters in WC3 slots.
4. **Units from WC3's data.** Creature templates carry WC3's hit points,
   mana, speed, acquire range and unit classes (structure, flying ...),
   read from the player's WC3 install at load time (W02's open question
   7); the shim's life and mana take them, and `IsUnitType` answers from
   them. ALE's creature events raise the events the shim registers but
   can't raise yet (attacked, damaged, spells, items, orders issued).
5. **Orders and movement.** Pathing on the server's navigation mesh
   (W02d's mmaps); attack-move, patrol and the rest as creature AI rather
   than one `MoveTo`; W02g sends players' orders the same way.
6. **Players' seats.** WoW characters seated in WC3 player slots:
   names, chat and leave events, messages, dialogs, quests, multiboards,
   floating text and sounds to the seated characters (W02g, and for the
   W client its own messages); `GetLocalPlayer` per seat.
7. **The mechanics.** Combat, abilities, items, the economy, research,
   construction: in ALE where it reaches, as an AzerothCore module where it
   doesn't. Likely its own sub-issues (W02e1 ...), one per mechanic, each
   checked against the runtime.
8. **The whole of every map.** Coverage of every name each map in
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
- [x] The natives most called are in the shim, each checked against the
      runtime on the same script: units' state, heroes, orders, unit
      events, groups, forces, players, alliances, messages, chat, sounds
      (step 2: 574 natives, 95.5% of the call sites across the 19 maps)
- [x] Every unit type a script makes by its rawcode has a creature
      template, so a map with no unit file makes creatures, not ghosts
      (step 2: DAoW-2.1's 1989 units in main() are all creatures)
- [ ] Every row of `shim.ALE_USED` checked against mod-ale on the owner's
      machine (step 3)
- [ ] A timer trigger and a region-enter trigger run on the owner's
      AzerothCore (W02's line 5; step 3)
- [ ] Every native the maps in `assets/` call is in the shim (step 8)

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

### Step 2: what was built (2026-11-05)

*Background work the coordinator asked for (branch
`claude/wete-w02e-natives-2`, on top of step 1's), with the same rules:
each decision below is the owner's to overturn.*

| File | Does |
|------|------|
| `server-side/ale/wc3shim/players.lua` | players' slots (name, controller, race, colour, team, start location), tech limits and research kept, the map's setup (`config()`), alliances and Blizzard.j's levels, forces and their enumerations, messages to players, chat and leave events (`S:chat`, `S:player_event`) |
| `server-side/ale/wc3shim/units.lua` | units' life (WC3's numbers, the fraction mirrored onto the creature), death, owner, position, facing, flags, unit types, ranges, abilities, timed life, `ReplaceUnitBJ`, waygates; heroes; orders; unit events (`S:unit_event`), deaths on the server seen at the look |
| `server-side/ale/wc3shim/groups.lua` | groups, `ForGroup`/`ForGroupBJ` and `GetEnumUnit`, the enumerations and Blizzard.j's group functions, `CreateNUnitsAtLoc`, group orders |
| `server-side/ale/wc3shim/sounds.lua` | sounds and music, kept as the runtime keeps them, each play handed to `opts.on_sound` |
| `server-side/ale/wc3shim/core.lua`, `world.lua` | Blizzard.j's arithmetic, `Convert*`, the for-loop index, random tables; rect functions, points in regions, the map's area, geometry; one look every 100 ms for rects and deaths |
| `server-side/ale/wc3shim/init.lua`, `fake_ale.lua` | nine more ALE calls (`shim.ALE_USED`, all unchecked), and the fake's creatures answer them (health, kill, teleport, facing, move, attack, stop, respawn) |
| `server-side/ale/wc3shim/covered.lua` | 574 natives in 19 groups (133 in 8 after step 1) |
| `src/wowbuild/creatures.lua` | `opts.script_types`: a template for each type only the script makes |
| `src/wowbuild/init.lua`, `triggers.lua` | the script scanned once, before the creatures, and the scan reused; `map-data.lua` gains the map's player names, the `TRIGSTR_` texts the script uses, the forces' alliances and the map's bounds |

### Step 2: checked

`luajit src/tests/test_wow_triggers.lua <project>`: 138 checks pass with
StormLib (step 1's 93, and 45 new).

- **Against the runtime, line by line**, two more made scripts on the VM's
  bare world and on the shim's fake ALE, every 20 ms:
  - units' state: life read, set and set by percent, mana, an owner
    changed (with its event, `GetChangingUnit` and the previous owner),
    position and facing set and turned toward a point, the flags kept on
    the unit, unit types, alliance and range tests, abilities added twice
    and removed, a hero's level raised (with its event), attributes,
    experience and skills, orders (move, stop, attack a unit, patrol, an
    unknown order, a paused unit's order), waygates, deaths by
    `KillUnit`, by life 0 and by timed life (with their events),
    `ReplaceUnitBJ` keeping the life fraction, a dead hero revived where
    asked;
  - groups, forces and players: enumerations in a rect, of a player, of a
    type, matching a filter, in range; `ForGroup` and `ForGroupBJ` with
    `bj_wantDestroyGroup`; `CreateNUnitsAtLoc` and the last group; group
    orders; forces enumerated with a filter and walked with `ForForce`;
    alliances by Blizzard.j's levels; slots, colour, team, tech limits,
    research, start locations; messages; chat (a match inside the text,
    an exact one, a player who didn't register) and a player leaving;
    sounds; Blizzard.j's arithmetic and geometry.
- **What the server sees**: a changed owner's faction on the creature;
  `SetUnitPosition` teleports it to map.lua's transform on the ground;
  `SetUnitFacing` turns it; WC3's life 50 of 100 is half the creature's
  health, and the server's damage comes back as WC3's life; `KillUnit` and
  life 0 kill it; a creature killed on the server fires the unit's death
  event at the next look, once, with no killer; `ReviveHero` respawns it;
  a move order walks it to the transform of its point, an attack order
  starts its attack on the target's creature, a stop stops it;
  `ReplaceUnitBJ` despawns the old one.
- **Players on the server**: a message to a force reaches every player in
  it through `opts.on_message` (player 0's are exactly the runtime's local
  player's); `TRIGSTR_` references are the map's words; an allied force's
  players start allied, an unallied force's and the neutrals don't; a
  player's name is the map's own.
- **ALE**: every call the fakes heard is in `shim.ALE_USED`.
- **The maps**: Master Crafters and DAoW-2.1 convert; their transpiled
  scripts run `main()` and ten seconds of timers on the shim with no
  error; main() makes as many units on the shim as on the runtime (all of
  them now: 327 and 1989); no ghosts; the script's own types' templates
  come after the placed ones, in Neutral Passive's faction, with entries
  in a row; `map-data.lua` has the map's bounds, players and forces'
  alliances; every player's gold after main() is the runtime's.

`test_wow_placements.lua` (72), `test_wow_registration.lua` (66),
`test_wow_terrain.lua` (70) and `test_jass_vm.lua` (28) pass; the full
suite fails only the two files that failed before step 1
(`test_net_hosted`, `test_unitsdoo`).

### Coverage today

After step 2 (2026-11-05); step 1's numbers before the arrow.

| Map | Natives called | Calls | Shim has | Of the calls | Lacks | Runtime lacks |
|-----|---------------:|------:|---------:|-------------:|------:|--------------:|
| Conquest-v8-fix | 222 | 7,923 | 40 -> 157 | 66.9% -> 92.4% | 65 | 6 |
| DAoW-2.1 | 458 | 11,710 | 80 -> 245 | 61.4% -> 92.1% | 213 | 0 |
| DAoW-5.2 | 277 | 23,328 | 50 -> 193 | 62.7% -> 96.7% | 84 | 0 |
| DAoW-5.3 | 333 | 19,417 | 55 -> 221 | 56.6% -> 96.7% | 112 | 0 |
| DAoW-5.4-PUBLIC-TEST-1 | 300 | 17,615 | 58 -> 195 | 58.8% -> 97.1% | 105 | 0 |
| DAoW-5.4a-PUBLIC-TEST-2 | 300 | 18,427 | 58 -> 195 | 58.7% -> 97.0% | 105 | 0 |
| DAoW-5.4b-PUBLIC-TEST | 303 | 19,852 | 58 -> 196 | 58.2% -> 96.7% | 107 | 0 |
| DAoW-5.4c (August) | 305 | 20,349 | 58 -> 196 | 57.9% -> 96.5% | 109 | 0 |
| DAoW-5.4c (July) | 306 | 20,918 | 58 -> 197 | 58.1% -> 96.5% | 109 | 0 |
| DAoW-5.4c (October) | 305 | 20,391 | 58 -> 196 | 57.9% -> 96.5% | 109 | 0 |
| DaoW-(HvA)-7.5 | 309 | 22,858 | 55 -> 213 | 59.1% -> 95.9% | 96 | 0 |
| DaoW-6.8-(HvA) | 310 | 21,927 | 55 -> 216 | 57.5% -> 95.8% | 94 | 0 |
| DaoW-6.93-(HvA) | 310 | 22,577 | 55 -> 216 | 57.6% -> 95.9% | 94 | 0 |
| Daow1.23.1B | 248 | 11,425 | 48 -> 179 | 55.9% -> 97.9% | 69 | 0 |
| Daow4.4 | 469 | 13,381 | 82 -> 256 | 63.5% -> 92.3% | 213 | 0 |
| Daow4.7.3 | 469 | 13,342 | 82 -> 255 | 62.8% -> 92.2% | 214 | 0 |
| Daow6.2 | 501 | 12,246 | 85 -> 271 | 55.2% -> 90.6% | 230 | 0 |
| Master-Crafters-Final-Conquest | 220 | 21,493 | 44 -> 147 | 62.5% -> 91.1% | 73 | 6 |
| War-in-the-Plaguelands-[24]-B6a | 214 | 26,069 | 49 -> 156 | 54.3% -> 97.3% | 58 | 5 |

Across the 19 maps, 745 distinct names; the shim has 368 of them (101
after step 1). Of all 345,248 call sites, 95.5% are now the shim's (58.9%
after step 1). The trigger plumbing and the unit and player natives are
most of every script; what's left is mostly what a player sees or a WC3
mechanic: items (`UnitAddItemToSlotById`, `CreateItemLoc`,
`WidgetDropItem` ...), floating text, special effects, cameras, quests,
dialogs, multiboards, timer windows, destructables (steps 6 and 7).
"Runtime lacks" are names the project's own runtime doesn't have either
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
    and step 6 decide how per-player code (`if GetLocalPlayer() == p`)
    runs, likely per seated character.

17. **Step 2's natives, by call sites** (2026-11-05). The groups the most
    call sites across the 19 maps fall in, after step 1's report: units'
    state, heroes, orders, unit events, groups, forces, players,
    alliances, messages, chat, sounds, and Blizzard.j's arithmetic. Left
    for later: items and the rest of WC3's mechanics (step 7), and what
    a player sees (dialogs, quests, multiboards, timer windows, floating
    text, special effects, cameras, fog: step 6 and W02g).
18. **Life is WC3's, on the unit; the creature shows its fraction.** A
    unit's life is kept in WC3's numbers (100 of 100, as the runtime's
    bare world, until templates carry WC3's hit points: step 4), and set
    onto the creature as a fraction of its health (`SetHealth`). When the
    server's combat changes the creature's health, the next read takes the
    fraction back. Life at 0.405 or less kills, as the runtime's.
19. **Deaths.** The script's (`KillUnit`, life 0, timed life) kill the
    creature (`Kill`) and fire their events at once, as the runtime's.
    The server's (its combat) are seen at the next look, every 100 ms
    while a death event is registered, with no killing unit; ALE's
    creature death event (step 3) would name it. One look serves the rects
    and the deaths.
20. **Kept on the unit, not on the creature**: mana, invulnerable, hidden,
    paused, acquire range, move speed, colour, user data, abilities,
    heroes' level, experience, attributes and skills, waygates. The
    script reads back what it set, as on the runtime; the server doesn't
    act on them yet (step 4 and the mechanics).
21. **Orders** are recorded as the runtime's bare world records them
    (`GetUnitCurrentOrder` reads them), and the creature is told: a move,
    patrol or attack-move walks it (`MoveTo`), an attack on a unit starts
    its attack on that unit's creature (`AttackStart`), stop and hold
    stop it (`MoveStop`). Spells, builds and training answer false, as
    the runtime's world without them.
22. **Unit types** answer what the shim can know: a hero is a type whose
    id starts with a capital letter (WC3's editor names custom heroes so;
    the runtime's `IsHeroUnitId`), dead is not alive, ground is every
    unit; the rest answer false, as on the runtime's bare world, until the
    templates carry WC3's unit data (step 4).
23. **A change of owner** sets the creature's faction to its new owner's
    (W02b's faction for that player) and the unit's colour to the owner's
    unless the script says not to, and fires its event for both players.
24. **Players' slots** start as the runtime's (0-11 playing, 12-15
    neutral; `opts.playing` names the playing ones), named as the map
    names them (`map-data.lua`'s players, from war3map.w3i), allied as the
    map's forces are (`map-data.lua`'s factions: an allied force's
    players, never the neutrals), as the runtime's game allies them.
25. **Messages go to every player they name.** The runtime shows a
    message only to its local player; a server has none, so the shim
    hands each player's to `opts.on_message(p, text, seconds)` (W02g sends
    it to the character seated there) and keeps the last 200. `TRIGSTR_`
    references are resolved from `map-data.lua`'s strings, which hold only
    the ones the script and the player names use.
26. **Chat and leaving come from outside**: `S:chat(player, text)` and
    `S:player_event(event, player)`, the runtime's own entry points, are
    what the loader calls (step 3), once W02g says which character sits
    in which slot. Nothing in the shim calls ALE for them.
27. **Sounds are the client's.** The shim keeps sounds and music as the
    runtime does and hands each play to `opts.on_sound(event)`; the
    server plays nothing.
28. **Enumerations walk the units the script knows** (made or adopted),
    reading each creature's position as it's tested; the server's other
    creatures aren't in them (open item 2).
29. **The map's area** (`GetPlayableMapRect`, `bj_mapInitialPlayableArea`)
    is the WC3 ground's, written into `map-data.lua`, as the runtime's
    game takes it; without it, the runtime's bare default.
30. **Ghost units: the types only the script makes get templates.**
    DAoW-2.1 has no unit file, so W02b made no templates and every unit
    its main() made was a ghost (1863, and 1989 once `CreateNUnitsAtLoc`
    and the rest were in). The converter now scans the script before the
    creatures and passes the rawcodes `CreateUnit` and the rest are given
    (`scan.created`) to `creatures.prepare`, which adds one template for
    each type no placed unit has: after the placed ones, so their entries
    don't move; in Neutral Passive's faction, since the shim gives each
    creature its owner's faction when it spawns it; with the same name,
    level and model lookup as a placed type (the fallback model where the
    model table has none). DAoW-2.1: 513 templates, 1989 creatures, no
    ghosts; Master Crafters: 60 more templates, its 11 ghosts now
    creatures. A type made from a variable stays a ghost (open item 9).

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

- **Deaths on the server** are seen up to 100 ms late, with no killing
  unit (`GetKillingUnit` is null); the runtime's world tells it at once.
- **Messages** reach every player named; the runtime shows only its local
  player's. `StartSoundForPlayerBJ` names its player in the event the
  hook hears; the runtime plays it only for its local player.
- **`GetPlayerTechCount`** of a unit type counts the player's living
  units of it, as the runtime's game does (its bare world answers 0).
- **`IsUnitType(u, UNIT_TYPE_HERO)`** is true for a capital-letter type;
  the runtime's bare world answers false (its game answers from its
  data).
- **Random natives** (`GroupPickRandomUnit`, `RandomDistChoose`,
  `GetRandomLocInRect` ...) draw from the server's Lua random state, so
  their sequence isn't the runtime's.

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
     `DespawnOrUnsummon(ms)`, `GetGUIDLow`;
   - step 2's: `Creature:GetHealth` / `GetMaxHealth` / `SetHealth(amount)`
     (whole numbers? may `SetHealth` reach 0?), `Creature:Kill(target)`
     (a creature killing itself: does it give loot or experience?),
     `NearTeleport(x, y, z, o)`, `SetFacing(o)`, `MoveTo(id, x, y, z)`
     (and its path-generating flag), `AttackStart(target)`, `MoveStop()`,
     `Respawn()` (where it respawns, and whether it keeps its guid).
2. **Creatures the script never names** (W02b's spawns that main()
   doesn't make, and anything the server spawns) don't enter regions yet.
   ALE has no map-wide creature list (from memory); the shim could take
   W02b's spawn list (`map-data.lua` has it) or `GetCreaturesInRange`
   around each rect. Step 3.
3. **A spawn that isn't on the map** when main() adopts it (AzerothCore
   loads a grid's creatures only when something is near, from memory)
   is adopted with no creature; the shim should look it up again later.
   Step 3.
4. **The Lua version ALE is built with** (LuaJIT, 5.1 or 5.2+) is
   unchecked; the shim loads the script with `setfenv` or `load`'s
   environment, whichever exists.
5. **How ALE loads files.** It runs every `.lua` under `lua_scripts/`
   (from memory); the shim's modules are harmless when run as scripts,
   but the loader (step 3) decides where they go and how `require` finds
   them.
6. **The 100 ms look** (rects, and deaths on the server) costs a read of
   every known unit's creature; with thousands of units (DAoW-2.1 makes
   1989 in main()) it may need the spatial grid the runtime's collision
   code has.
7. **Events registered but not raised yet** (step 2): attacked, damaged,
   spells, items, orders issued, training, construction, research,
   selection, a unit in range. Their triggers register and their
   response getters answer from the event's context, but nothing raises
   them until ALE's creature events do (steps 3 and 4).
8. **What the creature doesn't show yet** (step 2 keeps it on the
   unit): hidden, invulnerable, paused, acquire range, move speed, mana,
   colour, a hero's level and attributes. Each wants an ALE call
   (visibility, unit flags, speed, power: all from memory, none used yet)
   or a template field (step 4).
9. **Unit types the script makes from variables** (`CreateUnit(p,
   udg_Types[i], ...)`) can't be seen by the converter's scan and stay
   ghosts, counted in `S.unspawnable`. Neither map converted in the tests
   has one left; others may.
10. **Players' names on the server** are the map's (war3map.w3i) until
    W02g seats characters; then likely the character's (step 6).
