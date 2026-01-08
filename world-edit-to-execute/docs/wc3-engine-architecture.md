# WC3 Engine Architecture

**Status:** Active Design Document
**Created:** 2026-01-07
**Purpose:** Pure Warcraft III custom map engine architecture

---

## Mission Statement

> Build a modern game engine that executes Warcraft III custom maps (.w3x/.w3m) like an emulator reads ROMs - preserving the legacy of custom map creativity while replacing proprietary Blizzard assets with community-created alternatives.

**Core Principles:**
1. **Emulation, not transformation** - Execute WC3 maps as they were designed
2. **Community assets** - Replace Blizzard IP with open alternatives
3. **Legal precedent** - Follow ROM emulator legal philosophy
4. **Accessibility** - Modern platforms, easy installation, LAN multiplayer
5. **Preservation** - Keep the garden of WC3 custom maps alive

---

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                  WC3 Custom Map (.w3x / .w3m)                   │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  MPQ Archive Contents:                                   │  │
│  │  • war3map.w3i    (map info)                            │  │
│  │  • war3map.w3e    (terrain)                             │  │
│  │  • war3mapUnits.doo (units/buildings)                   │  │
│  │  • war3map.j      (JASS script)                         │  │
│  │  • war3map.wtg    (GUI triggers)                        │  │
│  │  • war3map.wts    (trigger strings)                     │  │
│  │  • war3map.doo    (doodads/destructibles)              │  │
│  │  • war3map.w3r    (regions)                             │  │
│  │  • war3map.w3c    (cameras)                             │  │
│  │  • war3map.w3s    (sounds)                              │  │
│  │  • war3map.shd    (shadow map)                          │  │
│  └──────────────────────────────────────────────────────────┘  │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Phase 1-2: Map Parser                        │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  • MPQ extraction                          ✅ COMPLETE   │  │
│  │  • W3I parsing (map metadata)              ✅ COMPLETE   │  │
│  │  • WTS parsing (trigger strings)           ✅ COMPLETE   │  │
│  │  • W3E parsing (terrain)                   ✅ COMPLETE   │  │
│  │  • DOO parsing (doodads)                   ✅ COMPLETE   │  │
│  │  • Units.doo parsing (units/heroes)        ✅ COMPLETE   │  │
│  │  • W3R/W3C/W3S parsing (regions/cams/sfx)  ✅ COMPLETE   │  │
│  │  • Object editor data (w3u/w3a/w3t)        ✅ COMPLETE   │  │
│  └──────────────────────────────────────────────────────────┘  │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                   Phase 3: JASS Execution                       │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  • JASS → Lua transpiler                   PENDING       │  │
│  │  • WC3 native function library             PENDING       │  │
│  │  • Trigger event system                    PENDING       │  │
│  │  • GUI trigger → JASS conversion           PENDING       │  │
│  └──────────────────────────────────────────────────────────┘  │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                   Phase 4: Game Runtime                         │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Game Loop (62.5 ticks/sec)                              │  │
│  │  ├─ Entity Component System (units, buildings, items)    │  │
│  │  ├─ Pathfinding (A*, collision avoidance)                │  │
│  │  ├─ Resource management (gold, lumber, food)             │  │
│  │  ├─ Combat system (damage, armor, attacks)               │  │
│  │  ├─ Ability system (hero skills, item effects)           │  │
│  │  ├─ Trigger execution (Lua VM)                           │  │
│  │  └─ Player input (selection, commands, camera)           │  │
│  └──────────────────────────────────────────────────────────┘  │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                  Phase 5: Rendering System                      │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Raylib Backend (OpenGL/Vulkan)                          │  │
│  │  ├─ Terrain rendering (heightmap, textures)              │  │
│  │  ├─ Model rendering (units, buildings, doodads)          │  │
│  │  ├─ Animation system (attack, walk, death)               │  │
│  │  ├─ Particle effects (spells, explosions)                │  │
│  │  ├─ UI rendering (HUD, portraits, minimap)               │  │
│  │  └─ Dual-camera system:                                  │  │
│  │     • WC3 Tactical (top-down RTS)         [Default]      │  │
│  │     • 3D Adventure (over-shoulder view)   [F5 toggle]    │  │
│  └──────────────────────────────────────────────────────────┘  │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                Community Asset Packs (Replacements)             │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  User-provided assets replace Blizzard IP:              │  │
│  │  • Models (.obj, .gltf)    → Replace .mdx units         │  │
│  │  • Textures (.png, .jpg)   → Replace .blp textures      │  │
│  │  • Sounds (.ogg, .wav)     → Replace .mp3 audio         │  │
│  │  • Icons (.png)            → Replace ability icons      │  │
│  │                                                          │  │
│  │  Asset packs installed to: ~/.wc3-engine/assets/        │  │
│  │  Fallback: Simple placeholder models (cubes, spheres)   │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Data Flow: From .w3x to Playable Game

### Step 1: Map Loading

```lua
-- User launches engine
$ wc3-engine play "path/to/map.w3x"

-- Engine loads map
local map = require("data").load("path/to/map.w3x")

-- Parsed data available:
print(map.info.name)              -- "Footmen Frenzy v4.2"
print(#map.terrain.tilepoints)    -- 10404 (96x96 + 12 boundary)
print(#map.units)                 -- 142 (starting units)
print(#map.triggers)              -- 87 (custom triggers)
```

### Step 2: JASS Transpilation

```lua
-- Read JASS script
local jass_code = map.archive:extract("war3map.j")

-- Transpile to Lua
local transpiler = require("jass.transpiler")
local lua_code = transpiler:convert(jass_code)

-- Load into Lua VM
local trigger_env = {}
load(lua_code, "war3map.lua", "t", trigger_env)()

-- Triggers now executable
trigger_env.InitTrig_Melee_Initialization()  -- Called on map start
```

### Step 3: Game Initialization

```lua
-- Create game instance
local game = require("runtime.game"):new(map)

-- Initialize players (1-12 slots)
for i = 1, map.info.player_count do
    game:add_player(i, "Player " .. i)
end

-- Spawn starting units
for _, unit_data in ipairs(map.units) do
    local unit = game:spawn_unit(
        unit_data.type_id,
        unit_data.position,
        unit_data.owner
    )

    -- Apply custom modifications (if any)
    if unit_data.hp ~= -1 then
        unit:set_hp(unit_data.hp)
    end
end

-- Execute map initialization triggers
game:run_trigger("map_init")

-- Start game loop
game:start()  -- 62.5 ticks/sec
```

### Step 4: Game Loop

```lua
-- Simplified game loop (actual: runtime/game.lua)
function game:start()
    local last_tick = os.clock()
    local tick_duration = 1.0 / 62.5  -- 16ms per tick

    while self.running do
        local now = os.clock()

        if now - last_tick >= tick_duration then
            -- Process input
            self:handle_input()

            -- Update game state
            self:update(tick_duration)

            -- Execute pending triggers
            self:process_triggers()

            -- Render frame
            self:render()

            last_tick = now
        end
    end
end
```

### Step 5: Rendering

```lua
-- Simplified render loop (actual: render/main.c with Raylib)
function game:render()
    -- Clear screen
    raylib.BeginDrawing()
    raylib.ClearBackground(raylib.BLACK)

    -- Setup camera
    raylib.BeginMode3D(self.camera)

    -- Render terrain
    self.terrain_renderer:draw(self.map.terrain)

    -- Render units
    for _, unit in ipairs(self.entities:get_all("unit")) do
        self.model_renderer:draw(unit.model, unit.position)
    end

    -- Render effects
    self.particle_system:draw()

    raylib.EndMode3D()

    -- Render UI
    self.ui_renderer:draw_hud()
    self.ui_renderer:draw_minimap()

    raylib.EndDrawing()
end
```

---

## Component Breakdown

### Parser System (Phases 1-2) ✅ COMPLETE

**Purpose:** Extract and parse all data from .w3x archive

**Modules:**
- `mpq/` - MPQ archive extraction (zlib decompression)
- `parsers/` - File format parsers (w3i, w3e, doo, wts, etc.)
- `gameobjects/` - Type system (Doodad, Unit, Region, etc.)
- `registry/` - Object registry with spatial indexing
- `data/` - Unified Map class

**Status:** 12/12 Phase 1 issues complete, 8/8 Phase 2 issues complete

---

### JASS Execution System (Phase 3) - PENDING

**Purpose:** Execute WC3 map scripts (JASS or Lua)

**Approach:**

```lua
-- JASS → Lua transpiler
function transpile_jass(jass_code)
    -- Convert JASS syntax to Lua equivalents

    -- Example conversions:
    -- JASS: function InitTrig_Example takes nothing returns nothing
    -- Lua:  function InitTrig_Example()

    -- JASS: local unit u = CreateUnit(...)
    -- Lua:  local u = CreateUnit(...)

    -- JASS: call TriggerRegisterPlayerEvent(...)
    -- Lua:  TriggerRegisterPlayerEvent(...)

    -- JASS: if (condition) then ... endif
    -- Lua:  if condition then ... end

    return lua_code
end

-- Native function library (WC3 API)
wc3_natives = {
    CreateUnit = function(owner, unit_id, x, y, facing)
        return game:spawn_unit(unit_id, {x=x, y=y}, owner)
    end,

    KillUnit = function(unit)
        unit:kill()
    end,

    SetUnitPosition = function(unit, x, y)
        unit:move_to({x=x, y=y})
    end,

    -- ... ~400 more native functions
}
```

**Issues:**
- 301: JASS parser
- 302: JASS → Lua transpiler
- 303: WC3 native function library (~400 functions)
- 304: Trigger event system
- 305: GUI trigger → JASS converter
- 306: Periodic trigger execution
- 307: Unit tests for transpiler
- 308: Phase 3 integration test

---

### Game Runtime (Phase 4) - PARTIAL

**Purpose:** Execute game logic (60 FPS, deterministic)

**Current Status:**
- ✅ Game loop (62.5 ticks/sec)
- ✅ ECS (Entity Component System)
- ✅ Pathfinding (A* with collision)
- ✅ Resource management
- ⏳ Combat system (basic damage implemented)
- ⏳ Ability system (framework exists)
- ❌ Multiplayer synchronization (deferred)

**Architecture:**

```lua
-- Entity Component System
entities = {
    [unit_id] = {
        type = "unit",
        position = {x = 1024, y = 512},
        hp = 450,
        hp_max = 450,
        owner = 1,  -- Player 1
        state = "idle",
        movement = {
            target = nil,
            path = {},
            speed = 270  -- units/sec
        },
        combat = {
            damage_base = 12,
            damage_dice = 3,  -- 12-15 damage
            attack_speed = 1.5,
            armor = 2
        }
    }
}

-- Game loop
function game:update(dt)
    -- Update movement
    for _, entity in ipairs(self.entities:get_all("unit")) do
        if entity.movement.target then
            self:update_movement(entity, dt)
        end
    end

    -- Update combat
    for _, entity in ipairs(self.entities:get_all("unit")) do
        if entity.combat.target then
            self:update_combat(entity, dt)
        end
    end

    -- Update abilities (cooldowns, effects)
    self.ability_system:update(dt)

    -- Update triggers (periodic events)
    self.trigger_system:update(dt)
end
```

---

### Rendering System (Phase 5) - PENDING

**Purpose:** Visualize game state (terrain, units, UI)

**Technology:** Raylib (OpenGL/Vulkan backend)

**Dual-Camera System:**

```c
// WC3 Tactical Camera (default)
Camera3D camera_tactical = {
    .position = (Vector3){ 0.0f, 20.0f, -10.0f },  // High angle
    .target = (Vector3){ 0.0f, 0.0f, 0.0f },
    .up = (Vector3){ 0.0f, 1.0f, 0.0f },
    .fovy = 45.0f,
    .projection = CAMERA_PERSPECTIVE
};

// 3D Adventure Camera (F5 toggle)
Camera3D camera_adventure = {
    .position = (Vector3){ 0.0f, 2.0f, -5.0f },   // Behind unit
    .target = (Vector3){ 0.0f, 1.0f, 0.0f },      // Look forward
    .up = (Vector3){ 0.0f, 1.0f, 0.0f },
    .fovy = 60.0f,
    .projection = CAMERA_PERSPECTIVE
};

// F5 key toggles between modes
if (IsKeyPressed(KEY_F5)) {
    active_camera = (active_camera == &camera_tactical)
        ? &camera_adventure
        : &camera_tactical;
}
```

**Rendering Pipeline:**

1. **Terrain** - Heightmap mesh with texture splatting
2. **Models** - Units/buildings/doodads (community-provided .obj/.gltf)
3. **Animations** - Skeletal animation (attack, walk, death cycles)
4. **Particles** - Spells, explosions, environmental effects
5. **UI** - HUD, portraits, minimap, tooltips

---

### Asset System (Phase 6) - NEW

**Purpose:** Replace Blizzard proprietary assets with community alternatives

**Asset Pack Structure:**

```
~/.wc3-engine/assets/
├── default-pack/               # Fallback placeholder pack
│   ├── models/
│   │   ├── units/
│   │   │   ├── human_footman.obj       # Simple cube soldier
│   │   │   ├── orc_grunt.obj           # Green cube warrior
│   │   │   └── ...
│   │   ├── buildings/
│   │   └── doodads/
│   ├── textures/
│   │   ├── terrain/
│   │   │   ├── grass.png
│   │   │   ├── dirt.png
│   │   │   └── ...
│   │   └── ui/
│   ├── sounds/
│   │   ├── units/
│   │   └── ambient/
│   └── manifest.json           # Asset ID mapping
│
└── community-fantasy-pack/     # User-installed high-quality pack
    ├── models/
    ├── textures/
    ├── sounds/
    └── manifest.json

# manifest.json example
{
    "name": "Default Placeholder Pack",
    "version": "1.0.0",
    "mappings": {
        "hfoo": "models/units/human_footman.obj",     # WC3 unit ID → model
        "ogru": "models/units/orc_grunt.obj",
        "Asac": "textures/abilities/sacrifice.png"    # Ability ID → icon
    }
}
```

**Asset Loading:**

```lua
-- Load asset packs
local asset_manager = require("assets")
asset_manager:load_pack("default-pack")
asset_manager:load_pack("community-fantasy-pack")  -- Overrides defaults

-- Resolve WC3 unit ID to model
local footman_model = asset_manager:get_model("hfoo")
-- Returns: ~/.wc3-engine/assets/community-fantasy-pack/models/units/human_footman.obj

-- Fallback to default if not found
local obscure_unit = asset_manager:get_model("n00B")
-- Returns: ~/.wc3-engine/assets/default-pack/models/units/placeholder.obj
```

---

## Coordinate Systems

**WC3 Coordinates:**
```
Origin: Center of map
X-axis: West (-) to East (+)
Y-axis: South (-) to North (+)
Units: 128 units per tile
Example: 96x96 map = -6144 to +6144 in each axis
```

**Engine Coordinates (kept identical):**
```
No conversion needed - we use WC3's coordinate system directly
```

**Rendering Coordinates (Raylib 3D):**
```
WC3 (x, y) → Raylib (x, terrain_height, z)
  where z = -y (invert Y for 3D "forward" direction)

Example:
  WC3 unit at (1024, -512)
  → Raylib position (1024, get_height(1024, -512), 512)
```

---

## Legal Strategy

### ROM Emulator Precedent

**Key Legal Principles:**
1. **Emulation is legal** (Sony v. Connectix, 2000)
2. **No copyrighted code** - We write our own engine
3. **No proprietary assets** - Users supply replacements
4. **Requires original files** - Users must own WC3 for .w3x maps

**Our Approach:**
- Engine distributed **without** any Blizzard assets
- Users install community asset packs (legally created)
- Users load their own .w3x maps (from legally owned WC3)
- Like Dolphin (GameCube emulator) or PCSX2 (PS2 emulator)

**Asset Packs (Community-Created):**
- Fantasy models (swords, armor, castles) - original art
- Generic sounds (footsteps, explosions) - public domain
- Placeholder textures (grass, dirt, stone) - CC0 licensed

**NOT Included:**
- Blizzard .mdx models
- Blizzard .blp textures
- Blizzard voice lines
- Warcraft lore/names (we use generic: "Warrior" not "Footman")

---

## Multiplayer Strategy

### Phase 1: LAN Multiplayer

**No Battle.net dependency** - local network only

```lua
-- Host game
$ wc3-engine host "path/to/map.w3x" --port 6112

-- Join game
$ wc3-engine join 192.168.1.100:6112
```

**Architecture:**
- Lockstep synchronization (deterministic simulation)
- Command protocol (actions only, not state)
- Host is authoritative for trigger execution
- Players sync inputs every tick

**Future:** Optional relay server for internet play (not Battle.net)

---

## Success Criteria

The engine is successful when:

### Minimum Viable Product (MVP)

1. ✅ Can parse any .w3x map
2. ✅ Can extract all game data (terrain, units, triggers)
3. ⏳ Can execute JASS scripts
4. ⏳ Can render terrain with placeholder textures
5. ⏳ Can spawn units with placeholder models
6. ⏳ Can select units and issue move commands
7. ⏳ Can play a simple melee map start-to-finish
8. ⏳ Community can install custom asset packs

**Target:** 3-4 months from now

### Vertical Slice: Tower Defense Map

**Goal:** Play one complete TD map (e.g., Element TD, Gem TD)

**Requirements:**
- ✅ Parse TD map successfully
- ⏳ Execute wave spawn triggers
- ⏳ Towers can attack creeps
- ⏳ Damage calculations work
- ⏳ Gold/lumber economies function
- ⏳ Victory/defeat conditions trigger
- ⏳ Can play from start to end

**Target:** 6 months from now

### Full Engine (1.0 Release)

1. ✅ All WC3 map formats supported
2. ✅ JASS execution 99% compatible
3. ✅ LAN multiplayer functional
4. ✅ Asset pack system with 3+ community packs
5. ✅ Runs on Windows, Linux, macOS
6. ✅ Can play top 20 popular custom maps
7. ✅ Map editor integration (load from World Editor)

**Target:** 12 months from now

---

## Open Questions

### OQ-WC3-001: JASS Transpilation vs Native Execution?

**Question:** Should we transpile JASS → Lua, or build a native JASS interpreter?

**Option A: Transpile JASS → Lua**
- Pros: Leverage LuaJIT performance, easier debugging
- Cons: Subtle syntax differences, potential edge cases

**Option B: Native JASS Interpreter**
- Pros: 100% compatibility, exact WC3 behavior
- Cons: More work, slower than LuaJIT

**Recommendation:** Start with transpilation (faster iteration), fall back to native if needed

---

### OQ-WC3-002: Model Format for Asset Packs?

**Question:** What 3D model format should community asset packs use?

**Options:**
- `.obj` - Simple, widely supported, no animations
- `.gltf` - Modern, animations, PBR materials
- Both (asset manager handles both)

**Recommendation:** Both - .obj for simple static models, .gltf for animated units

---

### OQ-WC3-003: Terrain Rendering Approach?

**Question:** How to render WC3 terrain heightmaps efficiently?

**Option A: Dynamic Mesh**
- Generate mesh from heightmap at load time
- Pros: Flexible, can modify terrain
- Cons: More complex

**Option B: Static Mesh**
- Pre-generated mesh, baked lighting
- Pros: Faster rendering
- Cons: Can't modify terrain dynamically

**Recommendation:** Option A - WC3 maps can modify terrain via triggers

---

## Related Documents

- `notes/vision` - Project philosophy and legal basis
- `docs/roadmap.md` - Phase breakdown and timeline
- `issues/CRITICAL-PATH.md` - Key decisions and open questions
- `docs/render-architecture.md` - Rendering system details
- `docs/postmortem-azerothcore-integration.md` - Why we chose pure WC3 engine

---

## Revision History

| Date | Change | Author |
|------|--------|--------|
| 2026-01-07 | Initial pure WC3 engine architecture | Claude |

---

*"Preserve the garden. Honor the creativity. Keep the maps alive."*
