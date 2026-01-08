# WC3 to AzerothCore Data Conversion Pipeline

**Status:** Design Document
**Created:** 2026-01-07
**Purpose:** Define how WC3 map data converts to AzerothCore format

---

## Pipeline Overview

```
.w3x File → Parse → Convert → Export → AC Server

[INPUT]      [P1-3]  [NEW]    [NEW]    [DEPLOY]
```

| Stage | Input | Output | Phase |
|-------|-------|--------|-------|
| Parse | `MyMap.w3x` | Lua tables | 1-3 (DONE) |
| Convert | Lua tables | SQL + files | NEW |
| Export | SQL + files | Deployed server | NEW |
| Deploy | Server files | Running AC | Manual/scripted |

---

## Conversion Modules

### Module 1: Terrain Conversion (w3e → .map/.adt)

**Input:** Parsed terrain data (from Phase 1, issue 105)

**WC3 Terrain Structure:**
```lua
terrain = {
  tileset = "Lordaeron Summer",
  size = {width = 64, height = 64},  -- tiles
  tiles = {
    [1][1] = {
      height = 2.5,           -- Ground level
      texture_id = "Lgrd",    -- Grass dirt
      flags = 0x0001,         -- Pathable
      water_level = 0,
      cliff_level = 0
    },
    -- ... 64x64 grid
  }
}
```

**AzerothCore Map Format (.adt):**
```
worldserver/maps/999/
├── 999.wdt          # World Definition Table (map bounds)
└── 999_32_32.adt    # Map tile (each is 533.33 yards²)
    ├── MHDR         # Header
    ├── MCIN         # Chunk index
    ├── MCNK [256]   # Terrain chunks (16x16 grid)
    │   ├── vertices[145]  # Height map (9x9 + 8x8)
    │   ├── normals[145]   # Lighting
    │   ├── texture_layers[4]  # Texture blending
    │   └── liquid         # Water data
    └── MTEX         # Texture file names
```

**Conversion Algorithm:**
```lua
function convert_terrain(wc3_terrain)
  local map_id = allocate_map_id()  -- e.g., 999
  local output_dir = "worldserver/maps/" .. map_id .. "/"

  -- Calculate .adt tile count
  local wc3_width = wc3_terrain.size.width
  local wc3_height = wc3_terrain.size.height
  local tiles_x = math.ceil(wc3_width / 16)  -- ADT tiles are 16x16 chunks
  local tiles_y = math.ceil(wc3_height / 16)

  -- Write WDT (world definition)
  write_wdt(output_dir .. map_id .. ".wdt", tiles_x, tiles_y)

  -- Convert each ADT tile
  for ty = 0, tiles_y-1 do
    for tx = 0, tiles_x-1 do
      local adt = create_adt()

      -- Fill MCNK chunks (16x16 per tile)
      for cy = 0, 15 do
        for cx = 0, 15 do
          local wc3_x = tx * 16 + cx
          local wc3_y = ty * 16 + cy

          if wc3_x < wc3_width and wc3_y < wc3_height then
            local wc3_tile = wc3_terrain.tiles[wc3_y][wc3_x]
            local chunk = adt.chunks[cy * 16 + cx]

            -- Height conversion
            chunk.vertices = interpolate_heights(wc3_tile.height, 145)

            -- Texture conversion
            chunk.texture_layers = {
              {texture_id = map_texture(wc3_tile.texture_id), alpha = 255}
            }

            -- Water/cliff
            if wc3_tile.water_level > 0 then
              chunk.liquid.height = wc3_tile.water_level * WC3_TO_WOW_SCALE
            end
          end
        end
      end

      write_adt(output_dir .. map_id .. "_" .. tx .. "_" .. ty .. ".adt", adt)
    end
  end

  return map_id
end
```

**Texture Mapping:**
WC3 uses 4-character texture IDs, WoW uses texture file paths.

```lua
TEXTURE_MAP = {
  -- Lordaeron Summer
  ["Ldrt"] = "tileset/lordaeron/dirt.blp",
  ["Lgrd"] = "tileset/lordaeron/grass.blp",
  ["Lgrs"] = "tileset/lordaeron/grass_short.blp",

  -- Ashenvale
  ["Adrt"] = "tileset/ashenvale/dirt.blp",
  ["Agrs"] = "tileset/ashenvale/grass.blp",

  -- Barrens
  ["Bdrt"] = "tileset/barrens/desert.blp",

  -- ... (full mapping in data file)

  -- Fallback for unmapped
  ["????"] = "tileset/generic/placeholder.blp"
}
```

**Output:**
- `worldserver/maps/999/999.wdt`
- `worldserver/maps/999/999_XX_YY.adt` (multiple tiles)

---

### Module 2: Unit Conversion (doo → creature_template + creature)

**Input:** Parsed unit data (from Phase 2, issue 202)

**WC3 Unit Structure:**
```lua
units = {
  {
    id = "u001",
    type_id = "hfoo",      -- Footman
    position = {x = 1024, y = 2048, z = 0},
    rotation = 90,         -- degrees
    scale = 1.0,
    hp = 420,
    mp = 0,
    gold = 0,              -- Dropped gold
    level = 1,
    hero_level = 0,
    inventory = {},
    abilities = {},        -- Custom abilities
    player_owner = 0       -- Neutral
  },
  -- ... more units
}
```

**AzerothCore creature_template:**
```sql
INSERT INTO creature_template (
  entry, name, subname, minlevel, maxlevel,
  faction, npcflag, speed_walk, speed_run,
  scale, rank, dmgschool, DamageModifier,
  BaseAttackTime, RangeAttackTime, BaseVariance,
  unit_class, unit_flags, type, type_flags,
  Health_mod, Mana_mod, Armor_mod,
  AIName, ScriptName
) VALUES (
  90001,                    -- entry (auto-assigned)
  'Footman',                -- name
  'WC3 Unit',               -- subname
  1,                        -- minlevel
  1,                        -- maxlevel
  35,                       -- faction (Alliance)
  0,                        -- npcflag (not vendor/trainer/etc)
  1.0,                      -- speed_walk
  1.14286,                  -- speed_run
  1.0,                      -- scale
  0,                        -- rank (normal)
  0,                        -- dmgschool (physical)
  1.0,                      -- DamageModifier
  2000,                     -- BaseAttackTime (2s)
  0,                        -- RangeAttackTime
  1.0,                      -- BaseVariance
  1,                        -- unit_class (warrior)
  0,                        -- unit_flags
  7,                        -- type (humanoid)
  0,                        -- type_flags
  420.0,                    -- Health_mod (from WC3)
  1.0,                      -- Mana_mod
  1.0,                      -- Armor_mod
  'SmartAI',                -- AIName
  ''                        -- ScriptName (Eluna if custom)
);
```

**AzerothCore creature (spawn):**
```sql
INSERT INTO creature (
  guid, id, map, zoneId, areaId,
  position_x, position_y, position_z, orientation,
  spawntimesecs, curhealth, curmana
) VALUES (
  @GUID := @GUID + 1,      -- Auto-increment GUID
  90001,                   -- creature_template entry
  999,                     -- map ID (our converted map)
  0,                       -- zoneId (optional)
  0,                       -- areaId (optional)
  1024 * WC3_TO_WOW_COORD, -- position_x (scale conversion)
  2048 * WC3_TO_WOW_COORD, -- position_y
  get_height_at(1024, 2048), -- position_z (from terrain)
  90 * (3.14159/180),      -- orientation (degrees to radians)
  300,                     -- spawntimesecs (respawn timer)
  420,                     -- curhealth
  0                        -- curmana
);
```

**Conversion Script:**
```lua
function convert_units(wc3_units, map_id)
  local sql_template = {}
  local sql_spawn = {}
  local creature_entry = 90000  -- Starting entry ID for custom units

  for _, unit in ipairs(wc3_units) do
    creature_entry = creature_entry + 1

    -- Lookup unit stats from WC3 object data
    local unit_data = wc3_object_editor[unit.type_id]

    -- Generate creature_template
    table.insert(sql_template, string.format([[
      INSERT INTO creature_template (entry, name, minlevel, maxlevel,
        faction, Health_mod, Mana_mod, Armor_mod, AIName)
      VALUES (%d, '%s', %d, %d, %d, %.1f, %.1f, %.1f, '%s');
    ]],
      creature_entry,
      unit_data.name or unit.type_id,
      unit.level or 1,
      unit.level or 1,
      map_faction(unit.player_owner),
      unit.hp or unit_data.hp,
      unit.mp or unit_data.mp,
      unit_data.armor or 1.0,
      has_custom_ai(unit) and "SmartAI" or ""
    ))

    -- Generate creature spawn
    table.insert(sql_spawn, string.format([[
      INSERT INTO creature (guid, id, map, position_x, position_y, position_z,
        orientation, spawntimesecs)
      VALUES (@GUID := @GUID + 1, %d, %d, %.2f, %.2f, %.2f, %.2f, %d);
    ]],
      creature_entry,
      map_id,
      unit.position.x * WC3_TO_WOW_COORD,
      unit.position.y * WC3_TO_WOW_COORD,
      get_terrain_height(map_id, unit.position.x, unit.position.y),
      unit.rotation * (math.pi / 180),
      300  -- 5 minute respawn
    ))
  end

  return {
    template = table.concat(sql_template, "\n"),
    spawn = table.concat(sql_spawn, "\n")
  }
end
```

**Coordinate Scaling:**
WC3 uses different coordinate system than WoW.

```lua
-- WC3: 128 units = 1 tile
-- WoW: 533.33 yards = 1 ADT tile = 16 chunks
-- Conversion factor
WC3_TO_WOW_COORD = (533.33 / 16) / 128  -- ≈ 0.26 yards per WC3 unit
```

**Output:**
- `output/MyMap_creatures_template.sql`
- `output/MyMap_creatures_spawn.sql`

---

### Module 3: Item Conversion (w3t → item_template)

**Input:** Parsed item data (WC3 object editor, Phase 2)

**WC3 Item Structure:**
```lua
items = {
  ["I000"] = {
    name = "Claws of Attack +6",
    description = "Increases attack damage by 6",
    icon = "BTNClawsOfAttack",
    class = "Permanent",
    gold_cost = 150,
    stats = {
      attack = 6
    },
    abilities = {},
    usable = false
  }
}
```

**AzerothCore item_template:**
```sql
INSERT INTO item_template (
  entry, class, subclass, name, displayid, Quality,
  BuyPrice, SellPrice, InventoryType, AllowableClass,
  stat_type1, stat_value1,
  bonding, RequiredLevel
) VALUES (
  50001,                     -- entry
  4,                         -- class (Armor - closest match)
  0,                         -- subclass (Miscellaneous)
  'Claws of Attack +6',      -- name
  12345,                     -- displayid (lookup icon)
  2,                         -- Quality (Uncommon - green)
  1500,                      -- BuyPrice (gold * 100 for copper)
  750,                       -- SellPrice
  0,                         -- InventoryType (Non-equippable)
  -1,                        -- AllowableClass (all)
  32,                        -- stat_type1 (ITEM_MOD_ATTACK_POWER)
  6,                         -- stat_value1
  1,                         -- bonding (Binds on Pickup)
  1                          -- RequiredLevel
);
```

**Stat Mapping:**
WC3 stats don't map 1:1 to WoW stats.

```lua
WC3_TO_WOW_STATS = {
  -- WC3 Stat → (WoW stat_type, multiplier)
  ["attack"] = {32, 1.0},           -- ITEM_MOD_ATTACK_POWER
  ["armor"] = {3, 1.0},             -- ITEM_MOD_ARMOR
  ["strength"] = {4, 1.0},          -- ITEM_MOD_STRENGTH
  ["agility"] = {3, 1.0},           -- ITEM_MOD_AGILITY
  ["intelligence"] = {5, 1.0},      -- ITEM_MOD_INTELLECT
  ["hp_regen"] = {8, 1.0},          -- ITEM_MOD_HEALTH_REGEN
  ["mp_regen"] = {6, 5.0},          -- ITEM_MOD_MANA_REGEN (scaled)
  ["move_speed"] = {37, 1.0},       -- ITEM_MOD_HASTE_MELEE_RATING
}
```

**Active Items (On-Use Effects):**
WC3 items with active abilities need Eluna scripts.

```lua
-- Example: WC3 "Scroll of Protection"
-- Effect: +2 armor to nearby allies for 60 seconds

-- Generated Eluna script
RegisterItemEvent(50002, ITEM_EVENT_ON_USE, function(event, player, item)
  local allies = player:GetPlayersInRange(50)  -- 50 yard radius
  for _, ally in ipairs(allies) do
    ally:AddAura(SPELL_ARMOR_BUFF, 60000)  -- 60 second duration
  end
  item:SetCount(item:GetCount() - 1)  -- Consume item
end)
```

**Output:**
- `output/MyMap_items.sql`
- `scripts/MyMap_item_scripts.lua` (for active items)

---

### Module 4: Doodad Conversion (doo → gameobject_template + gameobject)

**Input:** Parsed doodad data (Phase 2, issue 201)

**WC3 Doodad:**
```lua
doodads = {
  {
    id = "d001",
    type_id = "ATtr",      -- Tree (Ashenvale)
    position = {x = 512, y = 1024, z = 0},
    rotation = {x = 0, y = 0, z = 45},  -- degrees
    scale = {x = 1.0, y = 1.0, z = 1.0},
    variation = 1,
    life = 200             -- Destructible tree
  }
}
```

**AzerothCore gameobject_template:**
```sql
INSERT INTO gameobject_template (
  entry, type, displayId, name, IconName,
  size, Data0, Data1, Data2,
  AIName, ScriptName
) VALUES (
  60001,                   -- entry
  5,                       -- type (GAMEOBJECT_TYPE_GENERIC)
  191,                     -- displayId (tree model)
  'Ashenvale Tree',        -- name
  '',                      -- IconName
  1.0,                     -- size (scale)
  0,                       -- Data0 (open)
  0,                       -- Data1 (questId)
  0,                       -- Data2 (pageMaterial)
  '',                      -- AIName
  ''                       -- ScriptName
);
```

**Destructible Doodads:**
If `life > 0`, the doodad is destructible (like WC3 trees).

```lua
-- Eluna script for destructible objects
RegisterGameObjectEvent(60001, GAMEOBJECT_EVENT_ON_DAMAGED, function(event, go, attacker)
  local hp = go:GetInt32Value("hp")  -- Custom field
  hp = hp - attacker:GetTotalDamage()

  if hp <= 0 then
    -- Drop resources (wood for trees, gold for crates)
    if go:GetEntry() == TREE_ENTRY then
      attacker:ModifyCurrency(CURRENCY_LUMBER, 25)
    end

    -- Destroy object
    go:Despawn()
  else
    go:SetInt32Value("hp", hp)
  end
end)
```

**Output:**
- `output/MyMap_gameobjects.sql`
- `scripts/MyMap_doodad_scripts.lua`

---

### Module 5: Trigger Conversion (wtg/j → Eluna scripts)

**Input:** Parsed triggers (Phase 3, issues 301-302) + transpiled JASS (Phase 3, issue 306)

**WC3 Trigger (GUI):**
```
Trigger: Unit Dies
  Events:
    - Unit - A unit Dies
  Conditions:
    - (Dying unit) Equal to Footman 0001
  Actions:
    - Game - Display to (All players) the text: "The footman has fallen!"
    - Player - Add 100 to (Owner of (Dying unit)) Current gold
```

**Generated Eluna Script:**
```lua
-- Trigger: Unit Dies
-- Event: CREATURE_EVENT_ON_DIED

local footman_guid = 123456  -- Looked up from creature spawn

RegisterCreatureEvent(footman_guid, CREATURE_EVENT_ON_DIED, function(event, creature, killer)
  -- Condition: Dying unit is Footman 0001
  if creature:GetGUID() == footman_guid then
    -- Action: Display message
    BroadcastMessage("The footman has fallen!")

    -- Action: Add gold
    local owner = creature:GetOwner()  -- If creature is controlled
    if owner then
      owner:ModifyMoney(100 * 10000)  -- 100 gold (copper conversion)
    end
  end
end)
```

**JASS to Eluna:**
Already transpiled to Lua in Phase 3. Wrap in Eluna event handlers.

```lua
-- Original JASS (transpiled)
function Trig_Example_Actions()
  local u = GetTriggerUnit()
  KillUnit(u)
  DisplayTextToPlayer(GetLocalPlayer(), 0, 0, "Unit killed!")
end

-- Wrapped in Eluna
RegisterPlayerEvent(EVENT_PLAYER_COMMAND, function(event, player, command)
  if command == "killunit" then
    local target = player:GetSelection()
    if target then
      -- Call transpiled JASS function (adapted)
      target:Kill(player)
      player:SendBroadcastMessage("Unit killed!")
    end
  end
end)
```

**Periodic Triggers:**
WC3 has periodic event triggers (every N seconds).

```lua
-- WC3: Periodic Event - Every 30 seconds
-- Action: Spawn a unit at region X

CreateLuaEvent(function()
  -- Get spawn position from region
  local region = REGIONS["SpawnPoint"]
  local x, y, z = region.x, region.y, region.z

  -- Spawn creature
  local creature = SpawnCreature(ENTRY_FOOTMAN, MAP_ID, x, y, z, 0)
  creature:SetFaction(FACTION_ALLIANCE)

  BroadcastMessage("A footman has been spawned!")
end, 30000, 0)  -- 30 seconds, repeat indefinitely
```

**Output:**
- `scripts/MyMap_triggers.lua`

---

## Coordinate & Unit Conversions

### Coordinate Systems

**WC3 Coordinate System:**
- Origin (0, 0) at map center
- X-axis: West (-) to East (+)
- Y-axis: South (-) to North (+)
- Units: 128 units per tile

**WoW Coordinate System:**
- Origin varies per continent
- X-axis: South (-) to North (+)  ← **SWAPPED**
- Y-axis: West (-) to East (+)    ← **SWAPPED**
- Units: Yards

**Conversion Formula:**
```lua
function wc3_to_wow_coords(wc3_x, wc3_y, map_offset_x, map_offset_y)
  -- Axis swap + scale + offset
  local wow_x = map_offset_x + (wc3_y * WC3_TO_WOW_COORD)
  local wow_y = map_offset_y + (wc3_x * WC3_TO_WOW_COORD)
  return wow_x, wow_y
end

-- Map offset puts WC3 (0,0) somewhere in WoW world
-- For custom maps, center at (0, 0) in new continent
```

### Unit Scaling

**Time:**
- WC3: Game time (customizable, e.g., 12 hours = 1 real hour)
- WoW: 1 hour game time = 1 real minute
- **No conversion needed** - Use WC3 time for consistency

**Damage/HP:**
- WC3: Lower numbers (Footman = 420 HP, 12 damage)
- WoW: Higher numbers (Level 1 = ~100 HP, ~10 damage)
- **Conversion:** Multiply by 1.0 (keep WC3 values for balance)

**Speed:**
- WC3: Base = 270
- WoW: Base walk = 2.5 yards/sec
- **Conversion:** WC3_speed / 270 * 2.5

---

## Automation: Conversion Tool

**CLI Tool:**
```bash
./wc3-to-ac-converter \
  --input MyCustomMap.w3x \
  --output /path/to/azerothcore \
  --map-id 999 \
  --map-name "My Custom Map"
```

**What it does:**
1. Parses .w3x using Phase 1-3 code
2. Runs all conversion modules
3. Generates SQL files
4. Generates Eluna scripts
5. Copies map files to AC directories
6. Outputs instructions for deployment

**Output Structure:**
```
output/MyCustomMap/
├── sql/
│   ├── 01_map_definition.sql         # DBC entries
│   ├── 02_creature_templates.sql
│   ├── 03_creature_spawns.sql
│   ├── 04_gameobject_templates.sql
│   ├── 05_gameobject_spawns.sql
│   ├── 06_item_templates.sql
│   └── 99_apply_all.sql              # Master import script
├── scripts/
│   ├── MyCustomMap_triggers.lua
│   ├── MyCustomMap_items.lua
│   └── MyCustomMap_doodads.lua
├── maps/
│   └── 999/
│       ├── 999.wdt
│       └── 999_*.adt
└── README.txt                        # Deployment instructions
```

---

## Deployment Checklist

1. **Import SQL:**
   ```bash
   mysql -u root -p acore_world < output/MyCustomMap/sql/99_apply_all.sql
   ```

2. **Copy map files:**
   ```bash
   cp -r output/MyCustomMap/maps/* /opt/azerothcore/worldserver/maps/
   ```

3. **Copy Eluna scripts:**
   ```bash
   cp output/MyCustomMap/scripts/* /opt/azerothcore/worldserver/lua_scripts/
   ```

4. **Restart server:**
   ```bash
   systemctl restart acore-worldserver
   ```

5. **Test:**
   - Connect with WoW client
   - Teleport to new map: `.go xyz [coordinates] 999`
   - Verify terrain loads
   - Verify NPCs spawn
   - Test triggers

---

## Related Documents

- `docs/azerothcore-integration-architecture.md` - Overall architecture
- `docs/client-architecture.md` - Custom client design
- `docs/custom-ability-bridge.md` - Handling custom WC3 abilities

---

## Revision History

| Date | Change | Author |
|------|--------|--------|
| 2026-01-07 | Initial conversion pipeline design | Claude |
