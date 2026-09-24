# Issue W02: Build WC3 Maps into the WoW Client

**Phase:** W - WoW Client Bridge
**Type:** Implementation (root; expected to split into W02a-W02g)
**Priority:** High
**Dependencies:** W01
**Builds on (completed):** terrain, doodad and unit parsers (phases 1-2), JASS → Lua transpiler (phase 3)
**Unlocks:** W04, W07

---

## Current Behavior

A `.w3x` map can be fully parsed (phases 1-3): terrain, doodads, units,
regions, cameras and triggers become Lua tables, and JASS becomes Lua. Nothing
turns that into anything the WoW client or AzerothCore can load.

A local AzerothCore server exists at `/mnt/mtwo/games/azeroth-core/azerothcore/`
with the `mod-eluna` Lua scripting module, server data already extracted in
`/mnt/mtwo/games/azeroth-core/data-files/`, and a 3.3.5a client with a wine
launch script at `/mnt/mtwo/games/azeroth-core/client/run`.

Earlier research exists in
`docs/archive/azerothcore-2026-01-07/data-conversion-pipeline.md`; it has one
known error (it puts ADT files on the server; see the datapath document).

## Intended Behavior

The owner picks a `.w3x` file, runs one command, and a few minutes later is
standing on that map inside the WoW client, with its terrain, trees, buildings
and units in place and its triggers running on the server. Every step is done
by tools, so rebuilding a map after a converter fix is the same one command.
Noggit (an open-source WoW map editor) is used to look at and touch up the
result, never as the only way to produce it.

Conversion is described stage by stage in
`docs/datapath-wc3-map-into-wow-client.md`; the scale rule (one WC3 tile = one
WoW terrain cell, 4.1667 yards) is explained in `docs/wow-client-bridge.md`.

## Suggested Implementation Steps

Planned sub-issues (to be confirmed through the issue-splitter's analyze →
review → execute flow):

| ID | Name | Dependencies | Description |
|----|------|--------------|-------------|
| W02a | terrain-to-adt-writer | W01 | WC3 terrain grid → one WDT + ADT files: heights (145 floats per chunk), ≤4 texture layers with 64×64 alpha maps, liquid, normals. Texture reduction rule with counted warnings. A WC3-ground-type → WoW-texture-path table kept as data per WC3 tileset |
| W02b | doodads-and-units-to-placements | W02a | Doodads → M2/WMO placement records in the ADT, through a WC3-type → WoW-model table (data file). Units → SQL rows for creature templates and spawns, one faction per WC3 force |
| W02c | map-registration-and-patch-mpq | W01, W02a | New rows in `Map.dbc`, `AreaTable.dbc`, `LoadingScreens.dbc` for the client (inside `patch-W.MPQ`) and the matching server-side copies |
| W02d | server-data-for-new-maps | W02c | Run AzerothCore's map, vmap and mmap extractors over the client plus `patch-W.MPQ`, only for the new map ids, and install the results |
| W02e | triggers-on-the-server | W02b | Transpiled triggers run in Eluna. A shim implements JASS natives with Eluna calls (unit creation, timers, region enter events, player resources). Unsupported natives are listed per map, not skipped silently |
| W02f | launcher-and-loader | W02c, W02d | Launcher: start authserver/worldserver, install `patch-W.MPQ` in the client's `Data/`, write `realmlist.wtf`, clear the client's creature/object cache (`Cache/WDB`), start `Wow.exe` under wine. Loader: pick a `.w3x`, run W02a-e, restart the worldserver (it reads map tables only at start), teleport the character to the WC3 start location |
| W02g | control-addon | W02e | A WoW client addon showing a WC3-style command card and resource bar. Orders reach the server as addon messages; "move here" uses a ground-targeted spell (the client's reticle is the only way an addon can give the server a ground position). Server scripts turn orders into creature movement |

Execution order:
`W02a → W02b → W02c → W02d → W02f` with `W02e` after `W02b`, and `W02g` last.

Tuning ("lots of tweaking") goes into `docs/balance-updates.md` as it happens,
not into new issues.

## Acceptance Criteria

- [ ] One WC3 map (the smallest DAoW map in `assets/`) converts with one command
- [ ] Noggit opens every written ADT without complaint, at the expected place
- [ ] The character can walk the map; ground height matches the WC3 height field within 0.5 yd at sampled points
- [ ] Trees, buildings and units stand where WC3 placed them (checked at sampled points)
- [ ] At least one timer trigger and one region-enter trigger run on the server
- [ ] Texture folds, unmapped doodads/units and unsupported natives are counted in a conversion report
- [ ] `patch-W.MPQ` and all generated files live in a build folder; nothing proprietary is committed

## Open Questions

1. Accept the scale rule 1 WC3 tile = 1 WoW cell?
2. Hero mode first (the player is the WC3 hero; nearly free) or RTS mode first (addon + ground-target spells; the 3.3.5a camera cannot look straight down, so this also needs either the server binding the player's view to a high "camera" object, or a patched client program)?
3. Which range of map ids is ours? (Must not collide with Blizzard's rows or other custom patches the owner uses.)
4. Custom units need a WoW model per WC3 unit type. Who fills the WC3 → WoW table first: a hand-seeded table for the melee races, or W05's forge?

## Related Documents

- `docs/wow-client-bridge.md`, `docs/datapath-wc3-map-into-wow-client.md`
- `docs/archive/azerothcore-2026-01-07/data-conversion-pipeline.md`, `custom-ability-bridge.md`
- `docs/formats/w3e-terrain.md`, `docs/formats/unitsdoo.md`
