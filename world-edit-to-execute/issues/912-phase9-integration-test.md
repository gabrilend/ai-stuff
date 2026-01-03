# Issue 912: Phase 9 Integration Test

**Phase:** 9
**Type:** Testing
**Priority:** High
**Dependencies:** Issues 901-911

---

## Current Behavior

No integrated testing for the complete World Editor.

## Intended Behavior

A comprehensive integration test that validates the complete editor workflow:
1. All editor modules working together
2. Complete map creation workflow
3. Edit → Save → Load → Verify cycle
4. Export to all formats
5. Play-test integration

### Test Scenarios

#### Scenario 1: New Map Creation Workflow

```
1. Launch editor
2. Create new map (size, tileset selection)
3. Sculpt terrain (raise, lower, paint textures)
4. Place objects (units, doodads, items)
5. Create regions
6. Set up cameras
7. Create simple trigger
8. Save map
9. Close and reopen
10. Verify all data preserved
```

#### Scenario 2: Object Editing Workflow

```
1. Open Object Editor
2. Create custom unit from base
3. Modify stats (HP, damage, armor)
4. Add abilities
5. Set model and portrait
6. Place custom unit on map
7. Save and reload
8. Verify custom unit works
```

#### Scenario 3: Trigger Editor Workflow

```
1. Create new trigger
2. Add event (unit enters region)
3. Add condition (unit belongs to player 1)
4. Add action (display text)
5. Switch to code view
6. Modify code directly
7. Switch back to GUI view
8. Verify bidirectional sync
9. Save and test trigger
```

#### Scenario 4: Export Workflow

```
1. Load map with mixed WC3/WoW content
2. Export to WC3 format
3. Verify warnings for WoW-only features
4. Verify exported .w3x is valid
5. Load .w3x in original WC3 (if available)
6. Export to unified format
7. Verify all data preserved
```

#### Scenario 5: Play-Test Workflow

```
1. Create simple test map
2. Place player start
3. Place enemy units
4. Create victory trigger
5. Launch play-test
6. Play through scenario
7. Trigger victory condition
8. Verify play-test ends correctly
9. Return to editor with state intact
```

#### Scenario 6: Campaign Workflow

```
1. Create new campaign
2. Add two chapters
3. Set up hero persistence
4. Configure progression variables
5. Add cinematic
6. Export campaign
7. Load campaign
8. Verify all chapters accessible
9. Test progression between maps
```

### Test Structure

```
src/tests/
├── test_phase9_integration.lua    # Main integration test
├── editor/
│   ├── test_terrain.lua           # Terrain editing tests
│   ├── test_placer.lua            # Object placement tests
│   ├── test_triggers.lua          # Trigger editor tests
│   ├── test_objects.lua           # Object editor tests
│   ├── test_sounds.lua            # Sound editor tests
│   ├── test_imports.lua           # Import manager tests
│   ├── test_ai.lua                # AI editor tests
│   ├── test_campaign.lua          # Campaign editor tests
│   └── test_export.lua            # Map format tests
└── fixtures/
    ├── test_map.wex               # Pre-made test map
    └── reference_exports/         # Known-good exports for comparison
```

### Phase Demo

```bash
#!/bin/bash
# issues/completed/demos/run_phase9.sh

echo "=== Phase 9: World Editor Demo ==="
echo ""

# Launch editor with demo map
echo "Launching World Editor..."
lua src/editor/main.lua --demo

# The demo will:
# 1. Show editor UI
# 2. Demonstrate terrain editing
# 3. Show object placement
# 4. Open trigger editor
# 5. Create and run a simple trigger
# 6. Export to WC3 format
# 7. Display summary statistics

echo ""
echo "=== Phase 9 Demo Complete ==="
```

### Automated Test Suite

```lua
-- test_phase9_integration.lua

local function test_new_map_workflow()
    local editor = require("editor")

    -- Create new map
    local map = editor.new_map({
        name = "Test Map",
        size = {64, 64},
        tileset = "lordaeron_summer",
    })

    -- Terrain operations
    editor.terrain.raise(32, 32)
    assert(editor.terrain.get_height(32, 32) > 0)

    -- Object placement
    local unit = editor.placer.place("hfoo", 100, 100, {player = 1})
    assert(unit ~= nil)

    -- Save
    editor.save(map, "/tmp/test_map.wex")

    -- Load
    local loaded = editor.load("/tmp/test_map.wex")
    assert(loaded.name == "Test Map")

    -- Verify terrain preserved
    assert(editor.terrain.get_height(32, 32) > 0)

    -- Verify unit preserved
    local units = editor.placer.query_position(100, 100, 10)
    assert(#units == 1)

    return true
end

local function test_export_wc3()
    local mapfile = require("editor.mapfile")

    -- Load test map
    local map = mapfile.load("fixtures/test_map.wex")

    -- Export to WC3
    mapfile.export_wc3(map, "/tmp/test_export.w3x")

    -- Verify file structure
    local mpq = require("mpq")
    local archive = mpq.open("/tmp/test_export.w3x")

    assert(archive:has("war3map.w3i"))
    assert(archive:has("war3map.w3e"))
    assert(archive:has("war3mapUnits.doo"))

    archive:close()

    return true
end

-- Run all tests...
```

### Performance Benchmarks

```
EDITOR PERFORMANCE TARGETS
┌────────────────────────────────────────────────────────────┐
│ Operation                      Target       Measured       │
├────────────────────────────────────────────────────────────┤
│ New map creation               < 1s         _____          │
│ Load 256x256 map               < 3s         _____          │
│ Save 256x256 map               < 2s         _____          │
│ Export to WC3                  < 5s         _____          │
│ Terrain brush (60 fps)         16ms/frame   _____          │
│ Object placement               < 50ms       _____          │
│ Trigger validation             < 100ms      _____          │
│ Undo/redo operation            < 10ms       _____          │
└────────────────────────────────────────────────────────────┘
```

## Suggested Implementation Steps

1. Create test framework for editor modules
2. Implement Scenario 1 tests (new map workflow)
3. Implement Scenario 2 tests (object editing)
4. Implement Scenario 3 tests (trigger editing)
5. Implement Scenario 4 tests (export)
6. Implement Scenario 5 tests (play-test)
7. Implement Scenario 6 tests (campaign)
8. Create test fixtures
9. Implement performance benchmarks
10. Create phase demo script
11. Document test coverage

## Acceptance Criteria

- [ ] All 6 scenarios pass
- [ ] All editor modules have unit tests
- [ ] Performance benchmarks met
- [ ] Test fixtures are minimal and deterministic
- [ ] Phase demo runs successfully
- [ ] Export produces valid WC3 files
- [ ] Round-trip preserves all data
- [ ] Play-test launches and returns correctly

## Related Documents

- Issues 901-911 (components being tested)
- `issues/completed/demos/` (phase demo location)

## Notes

- Consider headless mode for CI testing
- May need mock for play-test (avoid launching full game)
- Compare exported files against known-good reference
- Performance tests should run on representative hardware
- Consider fuzz testing for file format robustness
