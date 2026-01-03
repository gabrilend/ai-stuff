# Issue 906: Object Editor

**Phase:** 9
**Type:** Implementation
**Priority:** Critical
**Dependencies:** 901 (Editor core), 110 (Object parsers)

---

## Current Behavior

Object definitions can be parsed (w3u, w3a, w3t, etc.) but not created or modified.

## Intended Behavior

Full object editing with feature parity to WC3 Object Editor:

### Object Types

| Tab | File | Description |
|-----|------|-------------|
| **Units** | w3u | Heroes, creeps, buildings |
| **Items** | w3t | Equipable/usable items |
| **Abilities** | w3a | Active and passive abilities |
| **Buffs** | w3h | Buff/debuff effects |
| **Upgrades** | w3q | Researchable upgrades |
| **Doodads** | w3d | Decorative objects |
| **Destructibles** | w3b | Breakable objects |

### Editor Layout

```
┌─────────────────────────────────────────────────────────────────────┐
│ [Units] [Items] [Abilities] [Buffs] [Upgrades] [Doodads] [Destruct] │
├──────────────────────────────┬──────────────────────────────────────┤
│ OBJECT TREE                  │ FIELD EDITOR                         │
│                              │                                      │
│ ▶ Human                      │ ┌──────────────────────────────────┐ │
│   ├─ Footman                 │ │ Custom Footman                   │ │
│   ├─ Knight                  │ │ Based on: Footman (hfoo)        │ │
│   └─ ★ Custom Footman       │ └──────────────────────────────────┘ │
│ ▶ Orc                        │                                      │
│   ├─ Grunt                   │ COMBAT                               │
│   └─ Raider                  │ ┌──────────────────────────────────┐ │
│ ▶ Custom (4)                 │ │ Hit Points Base:    [800____]   │ │
│   ├─ ★ Super Hero           │ │ Hit Points Regen:   [0.25___]   │ │
│   ├─ ★ Custom Footman       │ │ Mana:               [0______]   │ │
│   ├─ ★ Boss Creep           │ │ Attack 1 - Damage:  [15_____]   │ │
│   └─ ★ Mega Tower           │ │ Attack 1 - Cooldown:[1.35___]   │ │
│                              │ │ Armor:              [3______]   │ │
│ Filter: [____________]       │ └──────────────────────────────────┘ │
│                              │                                      │
│ [New Custom] [Copy] [Paste]  │ STATS                                │
│                              │ ┌──────────────────────────────────┐ │
│                              │ │ Movement Speed:     [270____]   │ │
│                              │ │ Collision Size:     [32_____]   │ │
│                              │ │ Acquisition Range:  [600____]   │ │
│                              │ └──────────────────────────────────┘ │
│                              │                                      │
│                              │ ABILITIES                            │
│                              │ ┌──────────────────────────────────┐ │
│                              │ │ ├─ Attack (hfoo)                │ │
│                              │ │ ├─ Defend                       │ │
│                              │ │ └─ [+ Add Ability]              │ │
│                              │ └──────────────────────────────────┘ │
│                              │                                      │
│                              │ [Reset Field] [Reset All]            │
└──────────────────────────────┴──────────────────────────────────────┘
```

### Field Categories

```
UNIT FIELD CATEGORIES
┌────────────────────────────────────┐
│ ○ All Fields                       │
│ ● Combat                           │
│ ○ Stats                            │
│ ○ Pathing                          │
│ ○ Sound                            │
│ ○ Art                              │
│ ○ Text                             │
│ ○ Abilities                        │
│ ○ Tech Tree                        │
└────────────────────────────────────┘

ABILITY FIELD CATEGORIES (per level)
┌────────────────────────────────────┐
│ Level: [1 ▼] [2] [3] [4] [5]      │
├────────────────────────────────────┤
│ ○ All Fields                       │
│ ● Data                             │
│ ○ Stats                            │
│ ○ Art                              │
│ ○ Text                             │
└────────────────────────────────────┘
```

### Custom Object Creation

```
CREATE CUSTOM OBJECT
┌────────────────────────────────────────────────┐
│ Base Object: [Footman (hfoo) ▼]               │
│                                                │
│ New ID: [x000]  (auto-generated)              │
│ Name:   [Custom Footman_______]               │
│                                                │
│ ○ Create as copy (inherit all fields)        │
│ ● Create as modification (inherit on read)   │
│                                                │
│                      [Create] [Cancel]        │
└────────────────────────────────────────────────┘
```

### Field Types

| Type | Editor Widget |
|------|---------------|
| **Integer** | Number input |
| **Real** | Decimal input |
| **Unreal** | Decimal 0-1 input |
| **String** | Text input |
| **Unit ID** | Object picker |
| **Ability ID** | Ability picker |
| **Model Path** | File browser |
| **Icon Path** | Icon picker |
| **Sound Path** | Sound picker |
| **Boolean** | Checkbox |
| **Flags** | Multi-checkbox |

### API Design

```lua
local object_editor = require("editor.objects")

-- Get object definition
local footman = object_editor.get("hfoo")

-- Create custom object
local custom = object_editor.create_custom({
    base = "hfoo",
    id = "x000",  -- Auto-generated if not provided
    name = "Custom Footman",
})

-- Modify field
object_editor.set_field(custom, "uhpm", 800)  -- Hit points
object_editor.set_field(custom, "udmg", 25)   -- Damage

-- Get field (with inheritance)
local hp = object_editor.get_field(custom, "uhpm")

-- Reset field to base value
object_editor.reset_field(custom, "uhpm")

-- Get all modified fields
local mods = object_editor.get_modifications(custom)

-- Check if field is modified
local is_custom = object_editor.is_modified(custom, "uhpm")

-- Level-based fields (abilities, upgrades)
object_editor.set_field(ability, "Ocl1", 100, {level = 1})  -- Mana cost level 1
object_editor.set_field(ability, "Ocl1", 80, {level = 2})   -- Mana cost level 2

-- Object tree
local tree = object_editor.get_tree("units")
-- Returns: {originals = {...}, custom = {...}, by_race = {...}}

-- Copy/paste
object_editor.copy(custom)
local pasted = object_editor.paste()

-- Delete custom
object_editor.delete(custom)

-- Search/filter
local results = object_editor.search("footman")
```

### Object ID System

```
OBJECT IDS
┌────────────────────────────────────┐
│ Original objects: 4-char string   │
│   e.g., "hfoo" (Human Footman)    │
│                                    │
│ Custom objects: x### or similar   │
│   e.g., "x000", "H001", etc.      │
│                                    │
│ Custom objects store parent ID    │
│   for inheritance                  │
└────────────────────────────────────┘
```

## Suggested Implementation Steps

1. Create `src/editor/objects/` module structure
2. Implement object tree view (originals + custom)
3. Implement field editor panel
4. Implement field type widgets (int, real, string, etc.)
5. Implement custom object creation dialog
6. Implement field inheritance (read from parent if not modified)
7. Implement level-based fields for abilities/upgrades
8. Implement copy/paste functionality
9. Implement search/filter
10. Implement field reset (to base value)
11. Integrate with object parsers (w3u, w3a, etc.)
12. Integrate with undo/redo
13. Create tests

## Acceptance Criteria

- [ ] All 7 object types editable
- [ ] Object tree shows originals and custom objects
- [ ] Custom objects creatable from any base
- [ ] All field types have appropriate editors
- [ ] Modified fields visually distinguished
- [ ] Field inheritance works correctly
- [ ] Level-based fields work for abilities/upgrades
- [ ] Copy/paste objects works
- [ ] Search/filter works
- [ ] Reset field/reset all works
- [ ] All operations support undo/redo

## Related Documents

- `src/parsers/w3u.lua` - Unit modifications
- `src/parsers/w3a.lua` - Ability modifications
- `src/parsers/objectdata.lua` - Core parser
- `src/parsers/objectdb.lua` - Object database
- Issue 110 - Object data parsers

## Notes

- Field IDs are 4-character codes (e.g., "uhpm" for unit hit points)
- Modified fields typically shown in different color
- Consider "diff view" showing only modified fields
- May want "compare objects" feature
- Field tooltips should explain what each field does
- Some fields are interdependent (changing one affects another's valid range)
