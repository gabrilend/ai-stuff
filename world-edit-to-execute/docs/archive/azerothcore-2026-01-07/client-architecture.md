# Custom Client Architecture

**Status:** Design Document
**Created:** 2026-01-07
**Purpose:** Define the dual-protocol, dual-view game client

---

## Client Overview

The custom client is a game client that can:
1. **Connect to vanilla AzerothCore servers** (standard WoW protocol)
2. **Connect to WC3-enhanced AC servers** (WoW protocol + custom extensions)
3. **Render in WC3-style** (top-down tactical camera)
4. **Render in WoW-style** (third-person RPG camera)
5. **Switch between views on-the-fly** (F5 key toggle)

---

## Protocol Architecture

```
┌──────────────────────────────────────────────────────────┐
│              Custom Game Client                          │
│                                                          │
│  ┌────────────────────────────────────────────────────┐  │
│  │         Network Layer (Dual Protocol)              │  │
│  │                                                    │  │
│  │  ┌──────────────┐        ┌──────────────────┐     │  │
│  │  │ WoW Protocol │        │ Custom Protocol  │     │  │
│  │  │   Handler    │        │    (optional)    │     │  │
│  │  │              │        │                  │     │  │
│  │  │ • Auth       │        │ • WC3 metadata   │     │  │
│  │  │ • World      │        │ • Custom UI data │     │  │
│  │  │ • Chat       │        │ • Extensions     │     │  │
│  │  └──────┬───────┘        └────────┬─────────┘     │  │
│  │         │                         │               │  │
│  └─────────┼─────────────────────────┼───────────────┘  │
│            │                         │                  │
│  ┌─────────▼─────────────────────────▼───────────────┐  │
│  │          Game State Synchronization               │  │
│  │  • Entity positions, stats, inventory             │  │
│  │  • Map geometry, terrain                          │  │
│  │  • Combat events, spell casts                     │  │
│  └─────────┬─────────────────────────────────────────┘  │
│            │                                            │
│  ┌─────────▼─────────────────────────────────────────┐  │
│  │        Rendering Engine (Dual Camera)             │  │
│  │                                                    │  │
│  │  ┌───────────────┐       ┌───────────────┐        │  │
│  │  │ WC3 Renderer  │◀─F5──▶│ WoW Renderer  │        │  │
│  │  │ (Tactical)    │       │ (3rd Person)  │        │  │
│  │  └───────────────┘       └───────────────┘        │  │
│  └────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────┘
                         │
                         ▼
            ┌────────────────────────┐
            │   AzerothCore Server   │
            │   (WoW protocol only)  │
            └────────────────────────┘
```

---

## Phase 5 Reorganization: Client Development Phases

### Original Phase 5: "Rendering" (55 issues)

**Problem:** Assumes standalone engine, not client-server architecture

**Solution:** Split into 3 client-focused phases

### Phase 5A: Client Core & WoW Protocol (Issues 501-505, ~20 issues)

**Goal:** Basic client that can connect to vanilla AzerothCore

| Issue Range | Topic | Description |
|-------------|-------|-------------|
| 501 | Protocol Implementation | WoW auth, world, chat protocol |
| 502 | Map Rendering | Display AC terrain (.adt files) |
| 503 | Entity Rendering | Display units/NPCs from server |
| 504 | Asset System | Load models, textures from AC format |
| 505 | Basic UI | Minimal playable interface |

**Success Criteria:**
- ✅ Client connects to vanilla AzerothCore server
- ✅ Renders WoW-style 3rd person view
- ✅ Player can move, see other players
- ✅ Chat works

### Phase 5B: Dual-View Rendering (Issues 506-510, ~25 issues)

**Goal:** Add WC3-style tactical camera

| Issue Range | Topic | Description |
|-------------|-------|-------------|
| 506 | UI Framework | Layout system for both views |
| 507 | Minimap | Works in both WC3/WoW modes |
| 508 | Vertical Slice | Playable demo with view switching |
| 509 | Visual Customization | Player-chosen effects/themes |
| 510 | Dual Perspective UI | Mode-specific UI (RTS vs RPG) |

**Success Criteria:**
- ✅ F5 key switches between WC3/WoW camera
- ✅ UI adapts to current view mode
- ✅ Both views show same game state

### Phase 5C: Custom Protocol Extensions (~10 new issues)

**Goal:** Support WC3-enhanced servers with custom data

**New Issues:**
- 513: Custom protocol design
- 514: WC3 metadata packets (custom abilities, map info)
- 515: Custom UI data (RTS-specific elements)
- 516: Protocol version negotiation
- 517: Fallback to vanilla mode

**Success Criteria:**
- ✅ Client detects server type (vanilla vs WC3-enhanced)
- ✅ Gracefully falls back to vanilla WoW mode on vanilla servers
- ✅ Uses extended protocol on WC3-enhanced servers

---

## Camera System Design

### WC3-Style Camera (Tactical View)

```
         ┌─────────────────────────┐
         │        Sky/Ceiling      │
         └─────────────────────────┘
                    ▲
                   ╱│╲   Isometric angle (45°)
                  ╱ │ ╲
                 ╱  │  ╲
                ╱   │   ╲
               ╱    │    ╲
              ╱     │     ╲
             ╱      │      ╲
            ╱       │       ╲
           ╱        │        ╲
          ╱         │         ╲
         ╱__________│__________╲
        └───────────┴───────────┘
              Game World
         (view from above, angled)

Controls:
  - WASD: Pan camera
  - Mouse wheel: Zoom in/out
  - Click-drag: Box select units
  - Right-click: Command units
```

**Implementation:**
- Camera at fixed height (e.g., 50 units above terrain)
- Rotation locked (or 90° increments only)
- FOV optimized for tactical overview

### WoW-Style Camera (3rd Person View)

```
                 Camera
                    ●───┐
                   ╱    │ 5-10 units back
                  ╱     │ 2-5 units up
                 ╱      │
                ╱       │
               ╱        ▼
              ●  ◀──── Player Character
             ╱│╲        (camera follows)
            ╱ │ ╲
    Terrain───┴───────────

Controls:
  - WASD: Move character
  - Mouse: Rotate camera
  - Scroll: Zoom in/out (to 1st person)
  - Click: Target enemy/NPC
```

**Implementation:**
- Camera follows player entity
- Spring arm for smooth movement
- Collision detection (don't clip through walls)
- Zoom range: 1st person to far tactical

### Transition Animation (F5 Key)

```lua
function switch_camera_mode()
  if current_mode == "wc3" then
    -- Transition to WoW
    tween_camera({
      from = {height = 50, angle = 45, target = world_center},
      to = {height = 5, angle = 10, target = player_position},
      duration = 1.0,  -- 1 second transition
      easing = "ease_in_out"
    })
    current_mode = "wow"
  else
    -- Transition to WC3
    tween_camera({
      from = {height = 5, angle = 10, target = player_position},
      to = {height = 50, angle = 45, target = calculate_center()},
      duration = 1.0,
      easing = "ease_in_out"
    })
    current_mode = "wc3"
  end

  -- Update UI to match mode
  ui_manager:set_mode(current_mode)
end
```

---

## UI Modes

### Warlord Mode UI (WC3-style)

```
┌────────────────────────────────────────────────────────┐
│ [Gold: 1250] [Lumber: 800] [Food: 45/100]    [12:34]  │
├────────────────────────────────────────────────────────┤
│                                                        │
│                                                        │
│               TACTICAL BATTLEFIELD VIEW                │
│                                                        │
│                                                        │
├─────────────┬──────────────────┬───────────────────────┤
│  MINIMAP    │  UNIT PORTRAIT   │  COMMAND GRID         │
│  ┌────────┐ │  Footman         │  [Q][W][E][R]         │
│  │   ▲    │ │  HP: ████░ 80%   │  [A][S][D][F]         │
│  │  ●●●   │ │  Armor: 2        │  [Z][X][C][V]         │
│  └────────┘ │  Attack: 12-15   │  Selected: 12         │
└─────────────┴──────────────────┴───────────────────────┘
```

**Elements:**
- Resource bar (top) - Gold, lumber, food from AC database
- Main view - Tactical camera
- Minimap (bottom-left) - Overview
- Unit info (bottom-center) - Selected unit stats
- Command grid (bottom-right) - Abilities mapped to QWER/ASDF/ZXCV

**Data Binding:**
```lua
-- Resources from AzerothCore
resources.gold = player:GetMoney() / 10000  -- Copper to gold
resources.lumber = player:GetCurrency(CURRENCY_LUMBER)
resources.food = player:GetCurrency(CURRENCY_FOOD_USED) .. "/" ..
                 player:GetCurrency(CURRENCY_FOOD_CAP)

-- Unit info from selected entity
if selected_unit then
  portrait.name = selected_unit:GetName()
  portrait.hp = selected_unit:GetHealth()
  portrait.hp_max = selected_unit:GetMaxHealth()
  portrait.armor = selected_unit:GetArmor()
end

-- Abilities from spell book
for i, spell in ipairs(selected_unit:GetSpells()) do
  command_grid[i].icon = spell:GetIcon()
  command_grid[i].hotkey = HOTKEYS[i]
  command_grid[i].cooldown = spell:GetCooldown()
end
```

### Hero Mode UI (WoW-style)

```
┌──────────────────────────────────────────┬─────────────┐
│ [Portrait] Thrall       [Target] Ogre    │  MINIMAP    │
│ HP: ████████░ 2450/2800                  │  ┌────────┐ │
│ MP: ██████░░░ 800/1400                   │  │   ▲    │ │
│ XP: ██████░░░ Level 42                   │  │  ●     │ │
├──────────────────────────────────────────┤  └────────┘ │
│                                          ├─────────────┤
│                                          │  QUEST LOG  │
│         THIRD-PERSON CHARACTER VIEW      │  ○ Quest 1  │
│                                          │  ○ Quest 2  │
│                                          ├─────────────┤
│                                          │  BUFFS      │
│                                          │  [⚔][🛡]    │
├──────────────────────────────────────────┴─────────────┤
│  [1][2][3][4][5][6][7][8][9][0][-][=]  [Bags][Menu]   │
│  ACTION BAR 1                                          │
│  [Shift+1][Shift+2]...                                 │
└────────────────────────────────────────────────────────┘
```

**Elements:**
- Player frame (top-left) - HP, MP, XP
- Target frame (top-center) - Enemy/NPC you're attacking
- Minimap (top-right)
- Quest log (right panel)
- Buffs/debuffs (right panel)
- Action bars (bottom) - Abilities on 1-0, Shift+1-0, etc.

**Data Binding:**
```lua
-- Player stats from AzerothCore
player_frame.name = player:GetName()
player_frame.hp = player:GetHealth()
player_frame.hp_max = player:GetMaxHealth()
player_frame.mp = player:GetPower(POWER_MANA)
player_frame.mp_max = player:GetMaxPower(POWER_MANA)
player_frame.level = player:GetLevel()
player_frame.xp = player:GetXP()
player_frame.xp_max = player:GetXPForNextLevel()

-- Target from AC
if target then
  target_frame.name = target:GetName()
  target_frame.hp = target:GetHealth()
  target_frame.hp_max = target:GetMaxHealth()
  target_frame.level = target:GetLevel()
end

-- Action bars from spell book
for i = 1, 12 do
  local spell = player:GetSpellOnSlot(i)
  if spell then
    action_bar[i].icon = spell:GetIcon()
    action_bar[i].cooldown = spell:GetCooldown()
    action_bar[i].range = spell:IsInRange(target)
  end
end
```

---

## Network Protocol

### WoW Protocol (Always Active)

Client implements standard WotLK opcodes:

```cpp
// Authentication
CMSG_AUTH_SESSION       // Login with account
SMSG_AUTH_RESPONSE      // Server accepts/rejects

// World
CMSG_PLAYER_LOGIN       // Enter world with character
SMSG_UPDATE_OBJECT      // Entity state updates
CMSG_MESSAGECHAT        // Send chat message
SMSG_MESSAGECHAT        // Receive chat message

// Movement
CMSG_MOVE_*             // Client movement updates
SMSG_MOVE_*             // Server movement corrections

// Spells
CMSG_CAST_SPELL         // Client casts ability
SMSG_SPELL_GO           // Server confirms spell cast
```

**Implementation:** Use existing WoW client libraries
- C++: TrinityCore client library (adapted)
- Or: Reverse-engineer WotLK protocol (legal in many jurisdictions)

### Custom Protocol (Optional, WC3-Enhanced Servers)

**Negotiation:**
```
Client → Server: CMSG_CUSTOM_PROTOCOL_VERSION (version 1)
Server → Client: SMSG_CUSTOM_PROTOCOL_SUPPORT (version 1, supported features)
```

**Custom Opcodes:**
```cpp
// WC3 Metadata
CMSG_REQUEST_MAP_INFO         // Request WC3 map data
SMSG_MAP_INFO                 // Send map name, description, custom UI

// Custom Abilities
SMSG_CUSTOM_ABILITY_DATA      // WC3 ability tooltips, icons
SMSG_CUSTOM_ABILITY_CAST      // Non-standard spell effects

// RTS UI
SMSG_RESOURCE_UPDATE          // Lumber, food counts
SMSG_UNIT_SELECTION           // Multi-unit selection data
```

**Fallback Behavior:**
```lua
if server_supports_custom_protocol then
  enable_wc3_features()
  enable_dual_view_mode()
else
  -- Vanilla WoW mode only
  force_wow_camera()
  hide_wc3_ui_elements()
  show_warning("Connected to vanilla server - WC3 features disabled")
end
```

---

## Rendering Backend

**Technology:** Raylib (as per CRITICAL-PATH decision)

**Rationale:**
- Simple, modern OpenGL wrapper
- Cross-platform (Windows, Linux, Mac)
- Lua bindings available
- Good for both 2D UI and 3D world

**Architecture:**
```lua
-- Main render loop
function render_frame(delta_time)
  -- Update camera based on mode
  if current_mode == "wc3" then
    update_tactical_camera(delta_time)
  else
    update_third_person_camera(delta_time)
  end

  -- Render 3D world
  BeginMode3D(camera)
    render_terrain(map_data)
    render_entities(entities)
    render_effects(active_spells)
  EndMode3D()

  -- Render 2D UI
  if current_mode == "wc3" then
    render_warlord_ui()
  else
    render_hero_ui()
  end
end
```

---

## Asset Loading

### Vanilla AC Servers

Client loads assets from WoW game files:
```
Data/
├── terrain/         # .adt map files
├── dbc/             # Database cache
├── models/          # .m2 model files
├── textures/        # .blp texture files
└── sound/           # .mp3 audio files
```

### WC3-Enhanced Servers

**Problem:** Can't distribute Blizzard assets

**Solution:** Community asset packs
```
community-assets/
├── models/
│   ├── units/
│   │   ├── footman.obj
│   │   ├── grunt.obj
│   │   └── ...
│   └── buildings/
│       ├── townhall.obj
│       └── ...
├── textures/
│   ├── grass.png
│   ├── dirt.png
│   └── ...
└── manifest.json
```

**manifest.json:**
```json
{
  "pack_name": "Generic Fantasy Assets",
  "version": "1.0",
  "license": "CC-BY-SA",
  "mappings": {
    "hfoo": "models/units/footman.obj",
    "opeo": "models/units/grunt.obj",
    "Agol": "textures/gold_mine.png"
  }
}
```

Client downloads from server on first connect (Phase 6 feature).

---

## Success Criteria

Phase 5A (Client Core) is complete when:
- ✅ Client connects to vanilla AzerothCore
- ✅ Renders WoW-style 3rd person view
- ✅ Player movement works
- ✅ Chat functional
- ✅ Can attack NPCs

Phase 5B (Dual View) is complete when:
- ✅ F5 switches between WC3/WoW camera
- ✅ UI adapts to camera mode
- ✅ Both views display same game state

Phase 5C (Custom Protocol) is complete when:
- ✅ Detects server type
- ✅ Falls back gracefully on vanilla servers
- ✅ Uses extended features on WC3-enhanced servers

---

## Related Documents

- `docs/azerothcore-integration-architecture.md` - Overall system design
- `docs/data-conversion-pipeline.md` - Map conversion process
- `docs/phase-reorganization.md` - Revised phase structure

---

## Revision History

| Date | Change | Author |
|------|--------|--------|
| 2026-01-07 | Initial client architecture | Claude |
