# Issue 208a: Parser Integration Tests

**Phase:** 2 - Data Model
**Type:** Test
**Priority:** Medium
**Dependencies:** 201, 202, 203, 204, 205
**Parent Issue:** 208-phase-2-integration-test

---

## Current Behavior

Individual parsers are tested in isolation with their own test files. There is no
unified test that validates all Phase 2 parsers work together when loading from
real MPQ archives.

---

## Intended Behavior

Create an integration test that loads all Phase 2 parsers from MPQ archives
and validates they work together on real map files.

```lua
local function test_all_parsers(map_path)
    local mpq = require("mpq")
    local doo = require("parsers.doo")
    local unitsdoo = require("parsers.unitsdoo")
    local w3r = require("parsers.w3r")
    local w3c = require("parsers.w3c")
    local w3s = require("parsers.w3s")

    local archive = mpq.open(map_path)

    local results = {
        doodads = doo.parse(archive:extract("war3map.doo")),
        units = unitsdoo.parse(archive:extract("war3mapUnits.doo")),
        regions = w3r.parse(archive:extract("war3map.w3r")),
        cameras = w3c.parse(archive:extract("war3map.w3c")),
        sounds = w3s.parse(archive:extract("war3map.w3s")),
    }

    archive:close()
    return results
end
```

---

## Suggested Implementation Steps

1. **Create test file structure**
   ```
   src/tests/
   └── test_phase2_integration.lua
   ```

2. **Implement parser loading tests**
   - Load each parser module
   - Extract corresponding file from MPQ
   - Parse and validate basic structure
   - Count objects parsed

3. **Handle optional files gracefully**
   - war3map.doo: Required (always has terrain doodads)
   - war3mapUnits.doo: May be empty (no preplaced units)
   - war3map.w3r: May be empty (no regions defined)
   - war3map.w3c: May be empty (no cameras)
   - war3map.w3s: May be empty (no sounds)

4. **Test across all 16 test maps**
   - Batch run on assets/*.w3x
   - Report per-map statistics
   - Aggregate totals

5. **Add timing metrics**
   - Measure extraction time
   - Measure parse time per file type
   - Report total load time

---

## Acceptance Criteria

- [ ] Test file created at src/tests/test_phase2_integration.lua
- [ ] All 5 parsers load successfully on test maps
- [ ] Optional files handled without errors
- [ ] Statistics reported for each map
- [ ] Tests pass on all 16 test maps
- [ ] Timing metrics included

---

## Notes

This is the foundation for Phase 2 integration testing. If parsers don't
integrate correctly, subsequent tests (208b, 208c, 208d) will fail.
