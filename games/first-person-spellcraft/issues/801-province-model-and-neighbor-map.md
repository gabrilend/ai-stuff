# 801 — Province model & the neighbouring-province map

> Phase 8, foundational. The taproot the rest of the Majesty layer grows from:
> the board of neighbouring provinces and the record that describes one.
> Datapath: [datapath-territory-majesty.md](../docs/datapath-territory-majesty.md)
> (Stage 1).

## Stats / meta
- **Phase:** 8 — Territory & Majesty Formula
- **Depends on:** nothing inside Phase 8. Reads a *handle* to each province's
  challenge from Phase 6 (the lair), but does not need Phase 6 finished to stand
  up the map — the handle may start empty and be filled later.
- **Blocks:** 802, 803, 804, 805, 806, 807 (everything in the phase).
- **Kind:** data structure + queries.

## Current Behavior
None of this exists yet. There is no notion of "a province," no map of
neighbours, no adjacency, no home domain. The game, at the end of Phase 7, knows
about a settlement and an economy, but the world stops at its own walls.

## Intended Behavior
There is a **territory map**: a home domain at the centre and a ring of
neighbouring provinces around it, joined by an **adjacency** relation. Adjacency
is bidirectional — if this province borders that one, that one borders this. The
map is iterable and can answer three questions: "give me this province," "give
me this province's neighbours," and "which provinces sit on my frontier" (i.e.
border the set I already control).

Each **province record** holds, by role:
- an **identity** — a stable id plus a human display name;
- its **neighbours** — the adjacency list (ids of bordering provinces);
- exactly **one relationship-state key** — a plain string the Phase-8 state table
  (802) will interpret; every province starts `unclaimed` until acted upon;
- a **challenge handle** — a reference to the lair/trial the Phase-6 Dungeon
  Master grew in this province; may be empty at map-build time;
- a **yield accumulator** — resources produced but not yet banked (806 drains it);
- a **kindness ledger** — a small history of how the player has treated this
  province (used by 805's manner-of-clear and by 807's union tally);
- a **reversion timer** — a countdown that only matters while `unclaimed` (804).

The province is a plain struct of primitives and small tables — no framework, no
inheritance. It should be cheap to hold hundreds of them in memory on the
handheld target.

## Suggested Implementation Steps
1. Write a **territory-map** module (Lua, LuaJIT-compatible). Give it a
   constructor that builds an empty map holding the home domain only.
2. Define the **province record** as a table of the fields listed above, with a
   small factory that fills sane defaults (`unclaimed`, empty neighbours, empty
   challenge handle, zeroed accumulator, empty ledger, reset timer). Fold each
   function with the project's vimfold + name-comment convention.
3. Add **register a province** and **bind two provinces as neighbours** — the
   bind writes the adjacency into *both* records so it can never be one-sided.
4. Add the three queries: **look up by id**, **iterate neighbours of a province**,
   **iterate the whole map**, and **frontier query** (provinces adjacent to any
   controlled province but not themselves controlled).
5. Seed the map from a definition file under `input/` rather than hardcoding a
   layout, honouring "the first thing a program should do is read the input/
   files." Keep the seed format a simple list of provinces + neighbour pairs.
6. Write the companion `*.info.md` black-box summary listing the map/province
   functions and their inputs/outputs.
7. Add a tiny test that builds a seed map, binds a few neighbours, and asserts
   adjacency is symmetric and the frontier query is correct. Tests are cheap.

## Related Documents / Tools
- Datapath: [datapath-territory-majesty.md](../docs/datapath-territory-majesty.md)
- Consumers: relationship states (802), yield profiles (803), the union which
  reads adjacency to know which provinces can coalesce (807).
- Challenge handle points into Phase 6:
  [datapath-dungeon-master.md](../docs/datapath-dungeon-master.md).
