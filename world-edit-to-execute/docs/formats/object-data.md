# WC3 Object Data File Format

Binary format used for storing object modifications in World Editor.
All files share a common structure with minor variations.

## File Types

| Extension | Object Type | Base SLK | Has Level/Column |
|-----------|-------------|----------|------------------|
| w3u | Units | Units\UnitData.slk | No |
| w3t | Items | Units\ItemData.slk | No |
| w3b | Destructibles | Units\DestructableData.slk | No |
| w3d | Doodads | Doodads\Doodads.slk | Yes |
| w3a | Abilities | Units\AbilityData.slk | Yes |
| w3h | Buffs | Units\AbilityBuffData.slk | No |
| w3q | Upgrades | Units\UpgradeData.slk | Yes |

## Binary Structure

### File Header

```
int32       version         File format version (typically 2)
```

### Tables

Two tables follow the header:
1. **Original Table** - Modifications to existing Blizzard objects
2. **Custom Table** - User-created objects (with parent reference)

Each table has identical structure:

```
int32       count           Number of objects in this table
Object[count]               Array of object definitions
```

### Object Definition

```
char[4]     original_id     Base object ID (e.g., 'hfoo' for Footman)
char[4]     new_id          Custom ID (0x00000000 if original table)
int32       mod_count       Number of modifications
Modification[mod_count]     Array of field modifications
```

### Modification Entry

```
char[4]     field_id        Field being modified (e.g., 'uhpm' for hit points)
int32       var_type        Data type (see below)

-- Optional: Only for w3a, w3d, w3q (abilities, doodads, upgrades)
int32       level           Level/variation this applies to (0 = base)
int32       column          Data column (usually 0)

-- Value: Type-dependent
<value>     data            Actual modification value

char[4]     end_marker      Object ID that defined this (0x00000000 for original)
```

### Variable Types

| Type | Name | Value Format |
|------|------|--------------|
| 0 | int | int32 |
| 1 | real | float32 (IEEE 754) |
| 2 | unreal | float32 (clamped 0.0-1.0) |
| 3 | string | null-terminated UTF-8 |

Note: Types 4+ in older docs (bool, char, unitList, etc.) are stored as strings.

## Examples

### Original Table Entry (Modified Footman)

```
'hfoo'      original_id     Footman
0x00000000  new_id          (not custom)
2           mod_count       2 modifications

-- Modification 1: Hit Points
'uhpm'      field_id        Max HP field
0           var_type        int
800         data            New HP value
0x00000000  end_marker

-- Modification 2: Move Speed
'umvs'      field_id        Move speed field
1           var_type        real
350.0       data            New speed
0x00000000  end_marker
```

### Custom Table Entry (Custom Hero)

```
'Hpal'      original_id     Paladin (parent)
'H001'      new_id          Custom ID
3           mod_count

-- Modification 1: Name
'unam'      field_id        Name field
3           var_type        string
"Dark Knight\0"             Null-terminated
'H001'      end_marker      Defined by this object

-- etc.
```

## Common Field IDs

### Units (w3u)

| Field ID | Description | Type |
|----------|-------------|------|
| unam | Unit name | string |
| uhpm | Hit points max | int |
| umpm | Mana points max | int |
| umvs | Movement speed | real |
| uar1 | Attack 1 range | int |
| udmg | Attack 1 damage base | int |
| ucol | Collision size | real |
| ushu | Shadow image | string |
| uabi | Abilities (normal) | string |

### Abilities (w3a)

| Field ID | Description | Type |
|----------|-------------|------|
| anam | Ability name | string |
| aart | Icon path | string |
| acdn | Cooldown | real |
| amcs | Mana cost | int |
| aran | Cast range | real |
| adur | Duration | real |
| aher | Hero ability | int (bool) |
| alev | Levels | int |

### Items (w3t)

| Field ID | Description | Type |
|----------|-------------|------|
| unam | Item name | string |
| ugol | Gold cost | int |
| ulum | Lumber cost | int |
| uico | Icon path | string |
| uabi | Abilities | string |
| ucla | Class | string |

## References

- [WC3MapSpecification](https://github.com/ChiefOfGxBxL/WC3MapSpecification)
- [Luashine/wc3-file-formats](https://github.com/Luashine/wc3-file-formats)
- [XGM W3M/W3X Format Guide](https://xgm.guru/p/wc3/warcraft-3-map-files-format)
