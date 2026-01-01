# Issue 110: Object Data Parsers

**Phase:** 1
**Type:** Implementation
**Priority:** Critical
**Dependencies:** 102 (MPQ parser)

---

## Current Behavior

We can extract object placement files (war3mapUnits.doo) which tell us WHERE objects are placed, but not WHAT they are. Unit stats, abilities, items, and other object definitions are stored in separate modification files that we don't parse:

- war3map.w3u - Unit modifications
- war3map.w3t - Item modifications
- war3map.w3a - Ability modifications
- war3map.w3b - Destructible modifications
- war3map.w3d - Doodad modifications
- war3map.w3h - Buff modifications
- war3map.w3q - Upgrade modifications

Without these parsers, we can only place generic objects without knowing their stats, abilities, or behavior.

## Intended Behavior

Parse all object data files to extract:

1. **Unit definitions** - Stats, abilities, models, sounds
2. **Ability definitions** - Costs, cooldowns, effects, targets
3. **Item definitions** - Stats, abilities, costs
4. **Other objects** - Destructibles, doodads, buffs, upgrades

Objects should be queryable by ID with full stat access.

## Suggested Implementation Steps

1. [x] Create core parser for shared binary format (110a)
2. [x] Implement unit parser (w3u) (110b)
3. [x] Implement ability parser (w3a) (110c)
4. [x] Implement item parser (w3t) (110d)
5. [x] Implement remaining parsers (w3b, w3d, w3h, w3q) (110e)
6. [x] Create ObjectDatabase for lookup by ID (110f)
7. [x] Integrate with gameobjects module (110g)
8. [x] Add comprehensive tests (110h)

## Sub-Issues

| ID | Name | Priority | Dependencies |
|----|------|----------|--------------|
| 110a | Core object data parser | Critical | None |
| 110b | Unit definitions (w3u) | Critical | 110a |
| 110c | Ability definitions (w3a) | Critical | 110a |
| 110d | Item definitions (w3t) | High | 110a |
| 110e | Other objects (w3b/d/h/q) | Medium | 110a |
| 110f | ObjectDatabase lookup | High | 110b-e |
| 110g | Gameobjects integration | High | 110f, 206 |
| 110h | Tests and validation | High | 110a-g |

## Acceptance Criteria

- [x] All 7 object file types parseable
- [x] Object modifications correctly applied to base objects
- [x] Custom objects inherit from parents
- [x] Level-based modifications work for abilities/upgrades
- [x] ObjectDatabase provides O(1) lookup by ID
- [x] Gameobjects have access to their full definitions
- [x] All tests pass

## Technical Notes

### Binary Format (Shared)

All object data files share a common structure:

```
int32       version         (typically 2)
Table       original        (modifications to Blizzard objects)
Table       custom          (user-created objects)

Table:
  int32     count
  Object[count]

Object:
  char[4]   original_id
  char[4]   new_id          (0x00000000 if original)
  int32     mod_count
  Modification[mod_count]

Modification:
  char[4]   field_id
  int32     var_type        (0=int, 1=real, 2=unreal, 3=string)
  [int32    level]          (only w3a, w3d, w3q)
  [int32    column]         (only w3a, w3d, w3q)
  <value>   data            (type-dependent)
  char[4]   end_marker
```

### Uses Level/Column

- w3a (abilities) - Per-level stats
- w3d (doodads) - Variations
- w3q (upgrades) - Per-level bonuses

### Common Field IDs

See `docs/formats/object-data.md` for field ID reference.

## Related Files

- `docs/formats/object-data.md` - Format specification
- `src/parsers/unitsdoo.lua` - Unit placement parser (uses object IDs)
- `src/gameobjects/unit.lua` - Unit class (needs stat access)

## References

- [WC3MapSpecification](https://github.com/ChiefOfGxBxL/WC3MapSpecification)
- [Luashine/wc3-file-formats](https://github.com/Luashine/wc3-file-formats)

## Implementation Notes

### Completed (2025-12-31)

Implemented all 7 object data parsers with comprehensive test coverage (73 tests total):

**Core Parser (110a):**
- `src/parsers/objectdata.lua` - Shared binary format parser
- Handles version 1/2 formats, all 4 variable types
- ObjectDataTable class with get/has/get_modification methods
- 23 core tests in `src/tests/test_objectdata.lua`

**Type-Specific Parsers (110b-e):**
- `src/parsers/w3u.lua` - Units (no level/column)
- `src/parsers/w3a.lua` - Abilities (uses level/column)
- `src/parsers/w3t.lua` - Items (no level/column)
- `src/parsers/w3b.lua` - Destructibles (no level/column)
- `src/parsers/w3d.lua` - Doodads (uses level/column for variations)
- `src/parsers/w3h.lua` - Buffs (no level/column)
- `src/parsers/w3q.lua` - Upgrades (uses level/column)

Each parser provides:
- Field ID mappings (friendly names to 4-char codes)
- Reverse mappings for display
- Type-specific helper methods (get_combat_stats, get_costs, etc.)

**Test Coverage:**
- 50 type-specific tests in `src/tests/test_object_parsers.lua`
- Tests use synthetic binary data generators
- All tests pass with LuaJIT

**ObjectDatabase (110f):**
- `src/parsers/objectdb.lua` - Unified database aggregating all parsers
- O(1) lookup by ID across all object types
- Provides: get, has, get_stat, get_type, get_all_stats, is_custom, get_parent_id
- load_from_archive() loads all available object files from MPQ
- 31 tests in `src/tests/test_objectdb.lua`

**Map Integration (110g):**
- Added objectdb require and object_data field to Map class
- objectdb.load_from_archive() called during Map.load()
- Map accessor methods: get_object_definition, get_object_stat, get_object_type, has_object_definition
- Updated info() to include object_definition_counts
- Updated format() to display Object Definitions section
- Integration test added to `src/tests/test_data.lua`

**Real Map Validation (110h):**
- `src/tests/test_110h_real_maps.lua` - Tests against 16 real map files
- Validates all 7 object file types load correctly
- Statistics across all test maps:
  - 43,435 total modified objects
  - 14,579 units, 12,171 abilities, 8,328 doodads
  - 4,231 destructibles, 1,735 upgrades, 1,198 buffs, 1,193 items
  - 18,024 custom objects (all have parent IDs)
  - All 43,195 object IDs validated as 4-char strings
- 13 tests covering: archive loading, map integration, stat access, type classification

**ISSUE COMPLETE** - All 8 sub-tasks implemented and tested
