# war3map.w3i - Map Info Format Specification

The war3map.w3i file contains map metadata displayed in lobby screens and used
during map initialization. This covers the Frozen Throne (TFT) format.

---

## Overview

The w3i file is a binary file with:
- Fixed header fields (version, saves, editor info)
- Variable-length strings (map name, author, description)
- Player slot definitions (up to 28 players)
- Force/team definitions (up to 8 forces)
- Technology and upgrade settings

---

## Data Types

| Type | Size | Description |
|------|------|-------------|
| int32 | 4 bytes | Little-endian signed integer |
| uint32 | 4 bytes | Little-endian unsigned integer |
| float32 | 4 bytes | IEEE 754 single precision |
| string | variable | Null-terminated UTF-8 |
| char(n) | n bytes | Fixed-length ASCII |

Strings support `TRIGSTR_XXX` placeholders resolved from war3map.wts.

---

## File Structure

### Header

| Offset | Type | Field | Description |
|--------|------|-------|-------------|
| 0x00 | int32 | FileVersion | Format version (25 = TFT, 18 = ROC) |
| 0x04 | int32 | MapSaves | Number of times map was saved |
| 0x08 | int32 | EditorVersion | World Editor version |
| 0x0C | string | MapName | Display name (supports TRIGSTR_) |
| var | string | MapAuthor | Author name |
| var | string | MapDescription | Description text |
| var | string | PlayersRecommended | Suggested player count text |

### Camera Bounds (floats)

| Field | Description |
|-------|-------------|
| CameraBounds[0-7] | 8 float32 values defining camera limits |
| CameraBoundsComplements[0-3] | 4 int32 margin values (A, B, C, D) |
| PlayableWidth | int32 - Playable area width (E) |
| PlayableHeight | int32 - Playable area height (F) |

Map dimensions: `width = A + E + B`, `height = C + F + D`

### Map Flags

| Field | Type | Description |
|-------|------|-------------|
| MapFlags | uint32 | Bitmask of map options |

#### Flag Values

| Flag | Value | Description |
|------|-------|-------------|
| HIDE_MINIMAP | 0x0001 | Hide minimap in preview screens |
| MODIFY_ALLY_PRIORITIES | 0x0002 | Modify ally priorities |
| MELEE_MAP | 0x0004 | Melee map (standard melee rules) |
| LARGE_NEVER_REDUCED | 0x0008 | Playable area was large, never reduced |
| MASKED_PARTIAL_VISIBLE | 0x0010 | Masked areas are partially visible |
| FIXED_PLAYER_SETTINGS | 0x0020 | Fixed player settings for forces |
| USE_CUSTOM_FORCES | 0x0040 | Use custom forces |
| USE_CUSTOM_TECHTREE | 0x0080 | Use custom tech tree |
| USE_CUSTOM_ABILITIES | 0x0100 | Use custom abilities |
| USE_CUSTOM_UPGRADES | 0x0200 | Use custom upgrades |
| PROPERTIES_OPENED | 0x0400 | Map properties opened at least once |
| SHOW_WAVES_CLIFF | 0x0800 | Show water waves on cliff shores |
| SHOW_WAVES_ROLLING | 0x1000 | Show water waves on rolling shores |
| UNKNOWN_2000 | 0x2000 | (Purpose unknown) |
| UNKNOWN_4000 | 0x4000 | (Purpose unknown) |
| UNKNOWN_8000 | 0x8000 | (Purpose unknown) |

### Additional Header Fields

| Field | Type | Description |
|-------|------|-------------|
| MainGroundType | char | Main tileset character (see below) |
| LoadingScreenIndex | int32 | Campaign loading screen preset (-1 = custom) |
| LoadingScreenPath | string | Custom loading screen model path |
| LoadingScreenText | string | Loading screen text |
| LoadingScreenTitle | string | Loading screen title |
| LoadingScreenSubtitle | string | Loading screen subtitle |
| GameDataSet | int32 | 0 = Default, 1 = Custom |
| PrologueScreenPath | string | Prologue screen path |
| PrologueScreenText | string | Prologue text |
| PrologueScreenTitle | string | Prologue title |
| PrologueScreenSubtitle | string | Prologue subtitle |

### Tileset Codes

| Code | Tileset |
|------|---------|
| A | Ashenvale |
| B | Barrens |
| C | Felwood |
| D | Dungeon |
| F | Lordaeron Fall |
| G | Underground |
| I | Icecrown |
| J | Dalaran Ruins |
| K | Black Citadel |
| L | Lordaeron Summer |
| N | Northrend |
| O | Outland |
| Q | Village Fall |
| V | Village |
| W | Lordaeron Winter |
| X | Dalaran |
| Y | Cityscape |
| Z | Sunken Ruins |

---

## TFT-Specific Fields (Version 25+)

### Fog Settings

| Field | Type | Description |
|-------|------|-------------|
| FogStyle | int32 | 0 = None, 1 = Linear, 2 = Exponential1, 3 = Exponential2 |
| FogStartZ | float32 | Fog start distance |
| FogEndZ | float32 | Fog end distance |
| FogDensity | float32 | Fog density (exponential modes) |
| FogColor | uint32 | BGRA color (BBGGRR00) |

### Environment Settings

| Field | Type | Description |
|-------|------|-------------|
| GlobalWeather | char(4) | Weather effect ID (e.g., "RAin", "SNow") |
| SoundEnvironment | string | Sound environment preset |
| LightEnvironment | char | Tileset for lighting (or 0x00 for default) |

### Colors

| Field | Type | Description |
|-------|------|-------------|
| WaterColor | uint32 | Custom water tint (BGRA) |

---

## Player Definitions

### Player Count Header

| Field | Type | Description |
|-------|------|-------------|
| MaxPlayers | int32 | Number of player slots defined |

### Player Slot Entry (repeated MaxPlayers times)

| Field | Type | Description |
|-------|------|-------------|
| PlayerNumber | int32 | Internal player ID (0-27) |
| PlayerType | int32 | See player types below |
| PlayerRace | int32 | See race types below |
| FixedStartPosition | int32 | 1 = fixed start, 0 = variable |
| PlayerName | string | Default player name |
| StartPositionX | float32 | Starting X coordinate |
| StartPositionY | float32 | Starting Y coordinate |
| AllyLowPriorities | uint32 | Low priority ally flags (bitmask) |
| AllyHighPriorities | uint32 | High priority ally flags (bitmask) |

#### Player Types

| Value | Type |
|-------|------|
| 1 | Human (user-controlled) |
| 2 | Computer (AI-controlled) |
| 3 | Neutral (passive, no player) |
| 4 | Rescuable (neutral until rescued) |

#### Race Types

| Value | Race |
|-------|------|
| 1 | Human |
| 2 | Orc |
| 3 | Undead |
| 4 | Night Elf |
| 5 | Selectable |

---

## Force Definitions

### Force Count Header

| Field | Type | Description |
|-------|------|-------------|
| MaxForces | int32 | Number of forces/teams defined |

### Force Entry (repeated MaxForces times)

| Field | Type | Description |
|-------|------|-------------|
| ForceFlags | uint32 | Force option flags |
| PlayerMask | uint32 | Bitmask of players in force |
| ForceName | string | Display name for force |

#### Force Flags

| Flag | Value | Description |
|------|-------|-------------|
| ALLIED | 0x0001 | Players in force are allied |
| ALLIED_VICTORY | 0x0002 | Allied victory enabled |
| SHARE_VISION | 0x0004 | Players share vision |
| SHARE_UNIT_CONTROL | 0x0008 | Players share unit control |
| SHARE_ADV_CONTROL | 0x0010 | Share advanced unit control |

---

## Upgrade Availability (TFT)

### Upgrade Count Header

| Field | Type | Description |
|-------|------|-------------|
| UpgradeCount | int32 | Number of upgrade entries |

### Upgrade Entry

| Field | Type | Description |
|-------|------|-------------|
| PlayerMask | uint32 | Affected players bitmask |
| UpgradeID | char(4) | 4-char upgrade ID |
| UpgradeLevel | int32 | Level affected |
| Availability | int32 | 0 = Unavailable, 1 = Researched, 2 = Available |

---

## Tech Availability (TFT)

### Tech Count Header

| Field | Type | Description |
|-------|------|-------------|
| TechCount | int32 | Number of tech entries |

### Tech Entry

| Field | Type | Description |
|-------|------|-------------|
| PlayerMask | uint32 | Affected players bitmask |
| TechID | char(4) | 4-char tech ID |

---

## Random Unit Tables (TFT)

### Table Count Header

| Field | Type | Description |
|-------|------|-------------|
| RandomTableCount | int32 | Number of random unit tables |

### Random Table Entry

| Field | Type | Description |
|-------|------|-------------|
| TableNumber | int32 | Table ID |
| TableName | string | Table display name |
| PositionCount | int32 | Number of positions |

### Position Entry (repeated PositionCount times)

| Field | Type | Description |
|-------|------|-------------|
| PositionType | int32 | Position category |
| UnitIDCount | int32 | Number of possible units |
| UnitID[] | char(4)[] | Array of unit IDs |
| ChancePercent[] | int32[] | Percentage for each unit |

---

## Random Item Tables (TFT)

### Table Count Header

| Field | Type | Description |
|-------|------|-------------|
| RandomItemTableCount | int32 | Number of random item tables |

### Random Item Table Entry

| Field | Type | Description |
|-------|------|-------------|
| TableNumber | int32 | Table ID |
| TableName | string | Table display name |
| ItemSetCount | int32 | Number of item sets |

### Item Set Entry

| Field | Type | Description |
|-------|------|-------------|
| ItemCount | int32 | Items in set |
| ItemID[] | char(4)[] | Array of item IDs |
| ChancePercent[] | int32[] | Percentage for each |

---

## Reading Sequence

```lua
-- {{{ read_w3i
local function read_w3i(data)
    local pos = 1
    local map = {}

    -- Header
    map.version = read_int32(data, pos); pos = pos + 4
    map.saves = read_int32(data, pos); pos = pos + 4
    map.editor_version = read_int32(data, pos); pos = pos + 4

    -- Strings
    map.name, pos = read_string(data, pos)
    map.author, pos = read_string(data, pos)
    map.description, pos = read_string(data, pos)
    map.players_recommended, pos = read_string(data, pos)

    -- Camera bounds (8 floats)
    map.camera_bounds = {}
    for i = 1, 8 do
        map.camera_bounds[i] = read_float32(data, pos); pos = pos + 4
    end

    -- Camera complements (4 ints)
    map.margins = {}
    for i = 1, 4 do
        map.margins[i] = read_int32(data, pos); pos = pos + 4
    end

    map.playable_width = read_int32(data, pos); pos = pos + 4
    map.playable_height = read_int32(data, pos); pos = pos + 4

    -- Flags
    map.flags = read_uint32(data, pos); pos = pos + 4

    -- Tileset
    map.tileset = data:sub(pos, pos); pos = pos + 1

    -- ... continue reading remaining fields

    return map
end
-- }}}
```

---

## References

- [WC3MapSpecification - GitHub](https://github.com/ChiefOfGxBxL/WC3MapSpecification)
- [W3X Files Format - 867380699.github.io](https://867380699.github.io/blog/2019/05/09/W3X_Files_Format)
- [W3M and W3X Files Format - wc3c.net](http://www.wc3c.net/tools/specs/index.html)
- [WC3MapTranslator - GitHub](https://github.com/ChiefOfGxBxL/WC3MapTranslator)
