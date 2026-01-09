# AzerothCore Integration Architecture

**Status:** Design Document
**Created:** 2026-01-07
**Purpose:** Define how world-edit-to-execute integrates with AzerothCore

---

## Executive Summary

This project is **not a standalone game engine** - it is a **WC3 map data pipeline and custom client** that integrates with AzerothCore (WotLK private server). The goal is to allow WC3 custom maps to be played in WoW-style MMO format.

---

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     WC3 Custom Map (.w3x)                       │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐         │
│  │ Terrain  │  │  Units   │  │ Triggers │  │  JASS    │         │
│  │  (w3e)   │  │ (doo)    │  │  (wtg)   │  │   (j)    │         │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘         │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│            world-edit-to-execute (Parser + Bridge)              │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Phase 1-3: WC3 Map Parser                               │   │
│  │  • MPQ extraction                                        │   │
│  │  • Format parsing (w3i, w3e, doo, wtg, j, etc.)          │   │
│  │  • JASS transpilation (JASS → Lua)                       │   │
│  └────────────────────────┬─────────────────────────────────┘   │
│                           │                                     │
│  ┌────────────────────────▼─────────────────────────────────┐   │
│  │  Phase X: Data Conversion Pipeline (NEW)                 │   │
│  │  • Terrain → .map/.adt files (AC format)                 │   │
│  │  • Units → creature_template DB entries                  │   │
│  │  • Items → item_template DB entries                      │   │
│  │  • Triggers → Eluna Lua scripts                          │   │
│  │  • Doodads → gameobject_template entries                 │   │
│  └────────────────────────┬─────────────────────────────────┘   │
│                           │                                     │
│  ┌────────────────────────▼─────────────────────────────────┐   │
│  │  Phase Y: Custom Ability Bridge (NEW)                    │   │
│  │  • Parse WC3 custom abilities (object editor data)       │   │
│  │  • Generate Eluna hooks for custom logic                 │   │
│  │  • Runtime calculation for unsupported mechanics         │   │
│  │  • Bidirectional AC ↔ Bridge communication               │   │
│  └────────────────────────┬─────────────────────────────────┘   │
└───────────────────────────┼─────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                  AzerothCore Server (WotLK)                     │
│                  *** AUTHORITATIVE GAME STATE ***               │
│                                                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐           │
│  │   Database   │  │   World      │  │   Eluna      │           │
│  │  (creature,  │  │  Simulation  │  │  (custom     │           │
│  │   item,      │  │  (movement,  │  │   scripts)   │           │
│  │   map data)  │  │   combat)    │  │              │           │
│  └──────────────┘  └──────────────┘  └──────────────┘           │
└────────────────────────┬────────────────────────────────────────┘
                         │
              ┌──────────┴──────────┐
              ▼                     ▼
┌──────────────────────┐  ┌──────────────────────┐
│   Official WoW       │  │   Custom Dual-View   │
│   Client (WotLK)     │  │   Client (Phase 5)   │
│                      │  │                      │
│  • Standard WoW      │  │  • WoW protocol      │
│    protocol          │  │  • Custom protocol   │
│  • Connects to       │  │  • Dual rendering:   │
│    vanilla AC        │  │    - WC3-style view  │
│    servers           │  │    - WoW-style view  │
└──────────────────────┘  └──────────────────────┘
```

---

## Data Flow: From WC3 Map to Playable Server

### Step 1: Parse WC3 Map (Phases 1-3) ✅ COMPLETE

**Input:** `MyCustomMap.w3x` (MPQ archive)

**Process:**
- Extract MPQ files
- Parse terrain (w3e) → height map, texture layers, pathing
- Parse units/doodads (doo) → entity positions, types, properties
- Parse triggers (wtg) → event/condition/action trees
- Parse JASS (j) → transpile to Lua

**Output:** In-memory data structures (Lua tables)

### Step 2: Convert to AzerothCore Format (NEW PHASE)

**Input:** Parsed WC3 data structures

**Process:**
```lua
-- Terrain Conversion
wc3_terrain → generate_adt_files() → worldserver/maps/MyMap/
  • Height map → vertex heights in .adt
  • Textures → texture layer blending
  • Pathing → liquid/collision data

-- Unit Conversion
for each unit in parsed_units:
  if unit.is_hero:
    → creature_template (elite, boss flags)
  else:
    → creature_template (standard NPC)

  → creature (spawn location, guid)

  unit.abilities → spell_script_names (Eluna)
  unit.inventory → creature_loot_template

-- Item Conversion
wc3_item → item_template
  • Stats mapping (WC3 → WoW stat equivalents)
  • Icon → displayid lookup/custom
  • Effects → spell triggers (Eluna)

-- Trigger Conversion
wc3_triggers → Eluna Lua scripts
  • EVENT_UNIT_DEATH → RegisterUnitEvent(...)
  • Periodic timers → RegisterTimedEvent(...)
  • Region events → RegisterAreaTrigger(...)
```

**Output:**
- `worldserver/maps/999/` (map files)
- SQL: `creature_template`, `gameobject_template`, `item_template`
- Lua: `scripts/custom/MyMap_triggers.lua` (Eluna)

### Step 3: Custom Ability Bridge (NEW PHASE)

**Problem:** WC3 abilities don't map 1:1 to WoW spells

**Example:**
```
WC3: "Chain Lightning"
  - Bounces to 3 targets
  - 100/140/180 damage per level
  - 0.3 reduction per bounce

WoW: Spell ID 421 "Chain Lightning" exists but:
  - Different damage formula
  - Different bounce mechanics
  - May not match WC3 behavior
```

**Solution: Hybrid Approach**

Option A: **Eluna Script Generation** (simple abilities)
```lua
-- Generated from WC3 object editor data
RegisterSpellCast(function(event, caster, target, spell)
  if spell:GetEntry() == CUSTOM_CHAIN_LIGHTNING then
    local damage = 100 + (caster:GetLevel() * 40)
    local bounces = 3
    -- Implement WC3 chain lightning logic
    DoChainLightning(caster, target, damage, bounces, 0.3)
  end
end)
```

Option B: **AC Fork + Custom Spell System** (complex abilities)
- Fork AzerothCore
- Add `CustomSpell` class with WC3-style ability engine
- Patch spell casting to delegate to custom system
- More performant, more maintenance

**Recommendation:** Start with Option A, migrate to Option B if performance critical

### Step 4: Deploy and Play

**Server Setup:**
```bash
# 1. Import converted data
mysql acore_world < MyMap_creatures.sql
mysql acore_world < MyMap_items.sql
cp -r maps/999 worldserver/maps/

# 2. Install Eluna scripts
cp MyMap_triggers.lua worldserver/lua_scripts/

# 3. Restart server
./worldserver
```

**Client Connection:**
- Official WoW client connects via standard protocol
- Custom dual-view client adds WC3-style camera option

---

## Component Ownership

| Component | Owner | Notes |
|-----------|-------|-------|
| Player position | AzerothCore | Server authoritative |
| Combat calculation | AzerothCore | Spell system + Eluna |
| Movement pathfinding | AzerothCore | Built-in navmesh |
| Resource tracking | AzerothCore | Gold, items in DB |
| Chat system | AzerothCore | Standard WoW channels |
| Custom abilities | Eluna scripts | Generated from WC3 data |
| Map geometry | AC .map files | Converted from w3e |
| Trigger logic | Eluna scripts | Transpiled from WTG/JASS |
| Visual rendering | Client | WC3-style or WoW-style |

**Phase 4 Runtime Re-evaluation:**

What we built in Phase 4 that's now redundant:
- ❌ Resource management → AzerothCore has this
- ❌ Player state → AzerothCore has this
- ❓ ECS → Keep for client-side prediction?
- ❓ Pathfinding → Keep for client preview, server uses AC navmesh
- ✅ Game loop → Still needed for conversion tools/editor

---

## Open Questions

### OQ-AC-001: Fork or Pure Eluna?

**Question:** Should we fork AzerothCore for deep integration, or stay pure Eluna scripts?

| Approach | Pros | Cons |
|----------|------|------|
| **Pure Eluna** | Easy updates, no fork maintenance | Performance limits, can't modify core |
| **AC Fork** | Full control, better performance | Must merge upstream, maintenance burden |

**Recommendation:** Start pure Eluna, fork only if we hit hard limits.

### OQ-AC-002: Map Instance Model

**Question:** How do WC3 maps relate to WoW zones?

**Option A: One Map = One Continent**
```
WC3 "Lost Temple" → Continent ID 999
  - All terrain converted to single .adt grid
  - Players teleport in like entering a dungeon
```

**Option B: One Map = Instanced Dungeon**
```
WC3 "Tower Defense" → Dungeon Instance
  - Fresh copy per game session
  - Like WoW dungeons (Deadmines, etc.)
```

**Recommendation:** Option B - instances make more sense for game sessions

### OQ-AC-003: Hero Persistence

**Question:** Do WC3 heroes persist like WoW characters?

**WC3 Behavior:** Heroes die, revive at altar, keep XP/items
**WoW Behavior:** Characters persist across sessions

**Proposal:**
- WC3 map session = temporary instance
- Hero state saved in character DB between sessions
- Like WoW raid lockouts, keep progress per map

### OQ-AC-004: Client Protocol - Dual or Single?

**Question:** Does custom client speak ONLY WoW protocol, or custom protocol too?

**Option A: WoW Protocol Only**
```
Custom Client → (WoW protocol) → AzerothCore
  - Must fit all data into WoW packet structures
  - Limited by WoW client capabilities
```

**Option B: Dual Protocol**
```
Custom Client → (WoW protocol) → AzerothCore (game state)
Custom Client → (Custom protocol) → Bridge Server (extra data)
  - WC3-specific data via separate channel
  - More flexible, more complex
```

**Recommendation:** Option A initially - keep it simple

---

## Success Criteria

The architecture is successful when:

1. ✅ A WC3 custom map (.w3x) can be parsed
2. ✅ Map data is converted to AC-compatible formats
3. ✅ An AzerothCore server can load the converted map
4. ✅ A WoW client can connect and see the map geometry
5. ✅ Units/NPCs spawn at correct WC3 positions
6. ✅ Basic triggers work (via Eluna scripts)
7. ✅ Custom dual-view client can render WC3-style view
8. ✅ Players can switch between WC3/WoW camera modes

---

## Related Documents

- `docs/client-architecture.md` - Custom client design
- `docs/data-conversion-pipeline.md` - WC3 → AC conversion
- `docs/custom-ability-bridge.md` - Handling WC3 abilities
- `docs/phase-reorganization.md` - Revised phase structure

---

## Revision History

| Date | Change | Author |
|------|--------|--------|
| 2026-01-07 | Initial architecture document | Claude |
