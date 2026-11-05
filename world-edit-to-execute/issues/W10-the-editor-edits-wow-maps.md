# Issue W10: The Editor Edits WoW Maps

**Phase:** W - WoW Client Bridge
**Type:** Implementation (root; to be split per editor)
**Priority:** High
**Dependencies:** W01 (read the WoW client's archives), W02 (WC3 maps into WoW's formats: its ADT/WDT writer, map registration, server data)
**Builds on:** the editor (Phase 9: 901 core, 902 terrain, 903 placer, 904 regions and cameras, 905 triggers, 906 objects, 907 sound, 908 imports, 909 AI, 910 campaigns, 911 map formats), the W client's C readers (`libwreaders.so`)
**Blocks:** none yet

---

## Origin

The owner, 2026-11-04: "We want to be able to use all of world-edit.exe's
functionality (all that is required to create WC3 maps) in World of
Warcraft's data formats as well. The idea is to create a unified engine /
client / editor that allows us to interact with both games as if they
were one."

And the same day, of this project: "It should be a map-editor for wc3
and World of Warcraft, sorta like Noggit except with the capability of
the world-edit.exe from warcraft3."

And, asked about WoW-only parts and Blizzard's own maps: "we will have
development pipelines for all proprietary assets. We are going to
completely re-make the game. World of Warcraft is the template, and from
it, we will create a system that creates games."

## Current Behavior

The editor opens, edits and saves WC3 maps only (`.w3x`/`.w3m`, and the
project's own map-project folders from 911c). WoW data reaches this
project one way: W02 converts a finished WC3 map into WoW's files (terrain
tiles, the map's registration, server rows and scripts). Nothing opens a
WoW map for editing, and nothing writes a change back into one.

## Intended Behavior

Every editor that makes a WC3 map also makes a WoW map, reading and
writing WoW's own formats, so a map author uses the same tools for both
games. Noggit edits WoW's ground and placements; this goes as far as
world-edit.exe goes: ground, objects, regions, cameras, triggers, object
data, sound, imports, AI, campaigns.

Each WC3 idea has a WoW counterpart the editor writes:

| WC3 (what the editor edits today) | WoW (what it writes for a WoW map) |
|-----------------------------------|------------------------------------|
| Ground: tilepoints, heights, cliffs, tile textures, water (`war3map.w3e`) | Terrain tiles (ADT): height grid per chunk, up to four texture layers with alpha maps, holes, liquids; the map's tile list (WDT) |
| Doodads (`war3map.doo`) | Small models placed in a tile (M2 doodads) |
| Buildings as doodads or units | Buildings placed in a tile (WMO) |
| Units placed (`war3mapUnits.doo`) | Creature spawns, rows in the server's database |
| Regions (`war3map.w3r`) | Areas (the area table) and area triggers |
| Cameras (`war3map.w3c`) | Camera paths, for cinematics |
| Triggers (`war3map.wtg`, `.wct`, JASS) | Server scripts (ALE Lua), as W02e writes them |
| Object data (units, items, abilities) | The server's creature, item and spell rows |
| Sounds (`war3map.w3s`) | Zone music and ambience, sound entries |
| Imports | Files the map's archive carries beside the stock game's |

Reading goes through the W client's C readers (one reader per format,
decided 2026-10-07); writing reuses W02's writers. Proprietary files stay
the user's: the editor reads the stock game from the user's own client and
never puts a Blizzard file into a map it writes (the owner, 2026-11-04:
"they aren't our files so we can't distribute them").

## Suggested Implementation Steps

1. Open a WoW map: its tile list, then each tile's ground, placements and
   liquids, through the W client's readers, into the editor's map structure.
2. The terrain editor (902) on ADT ground: raise, lower, smooth, paint
   texture layers with alpha, cut holes, place liquids.
3. The object placer (903) on M2 doodads and WMO buildings; creature spawns
   as the server's rows.
4. Regions and cameras (904) as areas, area triggers and camera paths.
5. Triggers (905) saved as server scripts.
6. The object editor (906) on the server's creature, item and spell rows.
7. Sound (907), imports (908), AI (909), campaigns (910) in turn.
8. Save: ADT/WDT through W02's writers, server rows and scripts beside them.
9. Test Map (913) on a WoW map: the same button, the same W client.

Each step is its own sub-issue (W10a, W10b, ...) when it begins.

## Acceptance Criteria

- [ ] A WoW map opens in the editor and is drawn by its Lua renderer.
- [ ] Ground edited, objects placed and a trigger written in a WoW map
      are saved, and the W client shows the result through Test Map.
- [ ] A WoW map saved without changes is byte for byte the map that was
      opened.
- [ ] No file the editor writes holds a Blizzard file's bytes.

## Open Questions

1. **One map, both games?** Can one map hold WC3 parts and WoW parts at
   once (a WC3 map placed into a WoW zone, say), or is each map one game's,
   with conversion between them?
2. ~~**WoW-only parts with no WC3 counterpart**~~ Answered 2026-11-04: in
   scope. Every proprietary asset gets a development pipeline (the owner,
   quoted under Origin), so sky and light per zone, building interiors
   and their portals, flight paths and phasing each get an editor here.
   The question as asked: new editors, or out of scope for now?
3. ~~**Editing Blizzard's own maps.**~~ Answered 2026-11-04: the game is
   remade, with WoW as the template ("World of Warcraft is the template,
   and from it, we will create a system that creates games"). The editor
   opens Blizzard's maps from the user's own client as templates to learn
   from and build on; what the project makes and ships are its own maps.
   The question as asked: is editing them in place allowed, or does an
   edit always save as a new map with only the changed tiles, so no
   Blizzard tile is redistributed?

## Related Documents

- `docs/wow-client-bridge.md` ("2026-11-04: the editor keeps its own
  renderer; Test Map opens the W client")
- `issues/W02-build-wc3-maps-into-the-wow-client.md` (the writers)
- `issues/913-test-map-opens-the-w-client.md`
- W client: `/mnt/mtwo/games/azeroth-core/custom-client/docs/003-asset-formats.md`
  (WoW's file formats)

## Sub-Issues

- *2026-11-05:* `W10a-the-wow-layer-of-a-map.md`: step 1, and the
  keeping half of step 8. A map project keeps WoW maps under
  `wow/World/Maps/<dir>/` byte for byte, beside its WC3 part (question
  1: one map holds both games); the editor lists them and reads every
  tile through the W client's reader into data for its tools. Its own
  open questions are answered there as dated decisions.
- *2026-11-05:* `W10b-the-terrain-editor-on-wow-tiles.md`: step 2
  without its window, and the ground half of step 8. Raise, lower,
  smooth, flatten, paint (new layers and textures) and holes on a WoW
  map's tiles as plain Lua; an edited tile written back by patching its
  own bytes (an unedited tile is the file read, byte for byte); the
  editor's strokes, undo and project save on a picked WoW map. Its open
  questions are answered there as dated decisions.
- *2026-11-05:* `W10c-far-view-and-water-on-wow-tiles.md`: step 2's
  "place liquids", and the far view's half of step 8. The WDL is
  patched from the edited tiles (far heights, whole-chunk holes). Water
  can be put on and dried off a WoW map's tiles, and the tile's MH2O is
  written again; parts not touched by an edit keep their bytes. Depths
  follow moved ground. The editor's `water` and `dry` strokes work on a
  WoW map. Its open questions are answered there as dated decisions.
- *2026-11-05:* `W10d-tiles-from-the-wdt-added-and-taken-off.md`: the
  tile list read from the WDT through the W client's `wdt_read`. Tiles
  can be added (flat, or meeting their neighbours) and taken off: the
  save writes the tile, patches its MAIN flag in place and updates the
  WDL, with undo. Flowing water (vertex formats 1 and 3) keeps its format
  and picture positions through an edit. Its open questions are answered
  there as dated decisions.
