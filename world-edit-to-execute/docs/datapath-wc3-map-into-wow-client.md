# Datapath: a WC3 map, played inside the WoW client

**Feature:** W02 (build WC3 maps into the WoW client)
**Status:** Designed, not built. Update this file when any W02 sub-issue changes the flow.

---

## The whole path

```
 map.w3x ──▶ [1 parse] ──▶ Map object (Lua tables, phases 1-3)
                              │
            ┌─────────────────┼──────────────────┬──────────────────┐
            ▼                 ▼                  ▼                  ▼
      [2 terrain]       [3 placements]     [4 registration]   [5 scripts]
      WDT + ADT files   M2/WMO placements   Map.dbc row,       transpiled Lua
                        (in the ADT) and    AreaTable row,      + native shim
                        SQL spawn rows      LoadingScreen row   for ALE
            │                 │                  │                  │
            └────────┬────────┘                  │                  │
                     ▼                           ▼                  ▼
              [6 pack] patch-W.MPQ  ◀────  client-side DBC   server-side:
                     │                                          SQL + lua_scripts/
                     ▼                                                │
              [7 server data] run AzerothCore's extractors            │
              over the client + patch → maps/ vmaps/ mmaps/ dbc/      │
                     │                                                │
                     └───────────────────┬────────────────────────────┘
                                         ▼
                              [8 launcher/loader]
                    start authserver + worldserver, install the patch,
                    write realmlist, clear the client cache, start Wow.exe
                    under wine, teleport the character onto the new map
                                         │
                                         ▼
                              [9 play] WoW client + control addon
```

## Stages

| # | Stage | Input (type) | Output (type) | Built in |
|---|-------|--------------|---------------|----------|
| 1 | Parse | `.w3x` path (string) | Map object: terrain grid, doodad table, unit table, regions, cameras, triggers (Lua tables) | Phases 1-3 (done) |
| 2 | Terrain | terrain grid: tilepoints (W+1)×(H+1), each with height (float, WC3 units), ground texture index (uint 0-15), cliff level (uint), water flag + level (float) | one WDT (which ADT tiles exist, 64×64 flag grid) + up to 16 ADTs, each 256 chunks of 145 height floats, ≤4 texture layers with 64×64 alpha maps (uint8), liquid blocks | W02a |
| 3 | Placements | doodad table (type id 4-char string, x/y/z float, facing radians, scale xyz); unit table (type id, owner player uint, position, facing) | doodads: M2/WMO placement records inside the ADT (`MDDF`/`MODF` blocks: file index, unique id uint32, position 3×float, rotation 3×float degrees, scale uint16 where 1024 = 1.0). Units: SQL rows for creature templates and spawns | W02b |
| 4 | Registration | map name, size, WC3 tileset | a new row in `Map.dbc` (map id uint32, directory string = folder under `World\Maps\`), rows for `AreaTable.dbc` and `LoadingScreens.dbc` | W02c |
| 5 | Scripts | JASS AST → Lua (phase 3 transpiler) | a Lua file per map for the server's ALE engine plus a shim that implements JASS natives (`CreateUnit`, `TriggerRegisterTimerEvent`, …) with ALE calls | W02e |
| 6 | Pack | files from 2-4 | `patch-W.MPQ` (an MPQ archive the client loads after its own patches, so its files win) | W02c |
| 7 | Server data | client `Data/` + the patch | `maps/*.map` (height + liquid grid the server uses for ground height), `vmaps/` (collision for line of sight), `mmaps/` (navigation mesh for creature pathing), `dbc/` | W02d |
| 8 | Launch/load | a chosen `.w3x`, launcher config (paths) | running server + client, character on the new map | W02f |
| 9 | Play | player input | orders to the server through the control addon | W02g |

## Where WC3 and WoW disagree (each is a conversion rule)

| WC3 has | WoW 3.3.5a has | Rule |
|---------|----------------|------|
| Tile 128 units | Cell 4.1667 yd | 1 tile = 1 cell (see `docs/wow-client-bridge.md`, Scale) |
| Up to 16 ground textures anywhere | ≤4 textures per 33-yard chunk | Keep the 4 that cover the most of the chunk; fold the rest into the nearest by colour. Every fold is counted and reported as a warning; strict mode stops on it |
| Cliffs are separate cliff meshes chosen by cliff level | Terrain is one height field | Raise the height field; optionally place a cliff M2 along the edge |
| Pathing from terrain + doodad pathing textures (`war3map.wpm`) | Server pathing from a navigation mesh built from geometry | Regenerate the mesh (stage 7); check a sample of WC3 pathable/unpathable cells against it |
| Units belong to players 0-23 and obey orders | Creatures belong to factions and follow AI scripts | Units become creatures with a faction per WC3 force; orders come from the control addon through the server |
| Triggers run in the game client | Only the server runs logic | Transpiled triggers run in the server's ALE engine |

## Correction to earlier research

The archived `data-conversion-pipeline.md` (January) places `.adt` files under
the *server's* `maps/` folder. The server never reads ADTs: the *client* reads
WDT/ADT from its MPQ archives, and the server reads its own `.map`, vmap and
mmap files, which AzerothCore's extractor tools produce *from* the client's
archives. That is why stage 7 runs the extractors after stage 6.
