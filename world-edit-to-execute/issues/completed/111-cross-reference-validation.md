# Issue 111: Cross-Reference Validation

**Phase:** 1
**Type:** Implementation
**Priority:** Medium
**Dependencies:** 110 (Object data parsers), 202 (unitsdoo), 201 (doo)

---

## Current Behavior

Each parser validates its own file format independently, but there's no validation that references between files are correct. A malformed map could have:

- Unit placements referencing non-existent unit type IDs
- Doodad placements referencing ability IDs instead of doodad IDs
- Waygate destinations pointing to non-existent regions
- Item drops referencing unit IDs instead of item IDs
- Ability references in units pointing to non-existent abilities

These errors would only surface at runtime with cryptic failures.

## Intended Behavior

A validation system that checks cross-references between parsed files:

1. **Type ID validation** - Placement IDs exist in correct definition tables
2. **Type classification** - Objects are used in appropriate contexts (units in unit slots, items in item slots)
3. **Reference resolution** - Waygate destinations, sound references, etc. point to valid targets
4. **Warning vs Error** - Missing base game IDs are warnings (we don't have SLK data), missing custom IDs are errors

## Suggested Implementation Steps

1. [x] Create `src/validation/init.lua` module
2. [x] Implement unit placement validation (unitsdoo → w3u/objectdb)
3. [x] Implement doodad placement validation (doo → w3d/objectdb)
4. [x] Implement item drop validation (unitsdoo item_drops → w3t)
5. [x] Implement ability reference validation (unitsdoo abilities → w3a)
6. [x] Implement waygate destination validation (unitsdoo waygate → w3r)
7. [x] Implement region sound validation (w3r ambient_sound → w3s)
8. [x] Add type classification checks (detect misplaced object types)
9. [x] Create validation report format
10. [x] Add Map:validate() method
11. [x] Add tests

## Acceptance Criteria

- [x] Detects unit placements with invalid type IDs
- [x] Detects doodads placed with unit/item/ability IDs
- [x] Detects item drops referencing non-item IDs
- [x] Detects waygate destinations pointing to non-existent regions
- [x] Distinguishes warnings (base game IDs) from errors (custom IDs)
- [x] Provides clear report of all validation issues
- [x] All tests pass

## Cross-Reference Map

| Source File | Field | Target File | Validation |
|-------------|-------|-------------|------------|
| war3mapUnits.doo | type_id | war3map.w3u | Unit ID exists |
| war3mapUnits.doo | type_id | (heuristic) | First char uppercase = unit |
| war3map.doo | type_id | war3map.w3d | Doodad ID exists |
| war3mapUnits.doo | item_drops[].id | war3map.w3t | Item ID exists |
| war3mapUnits.doo | abilities[].id | war3map.w3a | Ability ID exists |
| war3mapUnits.doo | waygate_destination | war3map.w3r | Region creation_number exists |
| war3map.w3r | ambient_sound | war3map.w3s | Sound name exists |
| war3map.w3r | weather_id | (constants) | Valid weather ID |

## Type Classification Heuristics

WC3 uses naming conventions for object IDs:

| Pattern | Type | Examples |
|---------|------|----------|
| `[A-Z][a-z]{3}` | Unit/Hero | `Hpal`, `Edem`, `Ulic` |
| `[a-z]{4}` | Unit (non-hero) | `hfoo`, `ogru`, `ushd` |
| `[A-Z]{4}` | Ability | `AHhb`, `ANcl`, `AUan` |
| `[A-Z][0-9]{3}` | Custom | `H000`, `A001`, `I002` |
| `[a-z]{4}` starting with certain letters | Item | Items often start with certain prefixes |

Note: These are heuristics, not guarantees. The definitive check is which object data file contains the ID.

## API Design

```lua
local validation = require("validation")

-- Validate a loaded map
local report = validation.validate_map(map)

-- Report structure
report.errors    -- Critical issues (custom ID not found)
report.warnings  -- Possible issues (base game ID not in our data)
report.checked   -- Count of references checked
report.valid     -- Count of valid references

-- Individual validators
validation.validate_unit_placements(map)
validation.validate_doodad_placements(map)
validation.validate_item_drops(map)
validation.validate_waygates(map)

-- Map method
local report = map:validate()
if #report.errors > 0 then
    print("Map has validation errors:")
    for _, err in ipairs(report.errors) do
        print("  " .. err.message)
    end
end
```

## Related Files

- `src/parsers/objectdb.lua` - Object definition lookup
- `src/parsers/unitsdoo.lua` - Unit placements with references
- `src/parsers/doo.lua` - Doodad placements
- `src/parsers/w3r.lua` - Regions (waygate targets)
- `src/data/init.lua` - Map class (add validate method)

## Notes

### Base Game IDs

We don't currently parse the base game SLK files (UnitData.slk, AbilityData.slk, etc.), so we can't definitively validate base game IDs. The validator should:

1. Check objectdb first (custom/modified objects)
2. If not found and ID looks like a base game ID (no digits), emit warning
3. If not found and ID looks custom (contains digits like `H001`), emit error

### Future Enhancement

Once we have SLK parsing (Phase 6 asset system), we can upgrade warnings to errors for base game IDs too.

---

## Implementation Notes

**Completed:** 2025-12-31

### Files Created

- `src/validation/init.lua` - Main validation module (437 lines)
- `src/tests/test_validation.lua` - Comprehensive test suite (32 tests)

### Files Modified

- `src/data/init.lua` - Added `require("validation")` and `Map:validate()` method

### Design Decisions

1. **ValidationReport class** - Encapsulates errors, warnings, and statistics. Errors affect
   validity, warnings do not.

2. **Custom vs Base Game ID detection** - Uses pattern matching (`X###` = custom). Custom IDs
   not in objectdb are errors; base game IDs not in objectdb are warnings (we lack SLK data).

3. **Type classification heuristics** - `classify_id()` attempts to guess object type from ID
   format (e.g., `A###` = ability, `H###` = unit). Used for better error messages.

4. **Type mismatch detection** - When an ID exists in objectdb but is wrong type (e.g., using
   an ability ID for a unit placement), reports as `type_mismatch` error.

5. **Region sound validation** - Missing sounds are warnings, not errors, since sounds may
   reference external files.

### Test Coverage

All 32 unit tests pass, covering:
- Helper functions (`is_custom_id`, `classify_id`)
- ValidationReport class
- Unit placement validation (4 tests)
- Doodad placement validation (2 tests)
- Item drop validation (3 tests)
- Ability reference validation (2 tests)
- Waygate destination validation (3 tests)
- Region sound validation (3 tests)
- Integration tests (3 tests)
- Report formatting (2 tests)
