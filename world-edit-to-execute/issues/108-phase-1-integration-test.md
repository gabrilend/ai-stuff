# Issue 108: Phase 1 Integration Test and Demo

**Phase:** 1 - Foundation
**Type:** Test / Demo
**Priority:** Required (Phase Gate)
**Dependencies:** All Phase 1 issues (101-107)

---

## Current Behavior

Individual components exist but have not been tested together.
No demonstration of Phase 1 capabilities exists.

---

## Intended Behavior

A comprehensive integration test that:
- Verifies all Phase 1 components work together
- Tests against all .w3x files in assets/
- Produces a visual/statistical demonstration
- Documents any issues or limitations discovered
- Creates the Phase 1 demo script per project conventions

---

## Suggested Implementation Steps

1. **Create test suite**
   ```
   src/tests/
   └── phase1_test.lua
   ```

2. **Implement integration tests**
   ```lua
   -- phase1_test.lua
   -- Integration tests for Phase 1: File Format Parsing

   local DIR = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
   package.path = DIR .. "/src/?.lua;" .. package.path

   local Map = require("data")
   local mpq = require("mpq")

   local function test_all_maps()
       local maps_dir = DIR .. "/assets"
       local results = {}

       for _, filename in ipairs(list_files(maps_dir, "%.w3[xm]$")) do
           local path = maps_dir .. "/" .. filename
           local result = { name = filename, success = true, errors = {} }

           -- Test MPQ opening
           local archive, err = mpq.open(path)
           if not archive then
               result.success = false
               table.insert(result.errors, "MPQ open failed: " .. err)
           else
               -- Test file listing
               local files = archive:list()
               result.file_count = #files

               -- Test essential file extraction
               for _, required in ipairs({"war3map.w3i", "war3map.w3e"}) do
                   local data, err = archive:extract(required)
                   if not data then
                       table.insert(result.errors, "Extract failed: " .. required)
                   end
               end

               archive:close()
           end

           -- Test full map loading
           local map, err = pcall(Map.load, path)
           if not map then
               result.success = false
               table.insert(result.errors, "Map.load failed: " .. tostring(err))
           else
               result.map_name = map:get_display_name()
               result.dimensions = map.width .. "x" .. map.height
               result.player_count = #map.players
           end

           table.insert(results, result)
       end

       return results
   end
   ```

3. **Create demo script**
   ```
   issues/completed/demos/
   └── phase1_demo.lua
   ```

   ```lua
   #!/usr/bin/env lua
   -- phase1_demo.lua
   -- Demonstrates Phase 1 capabilities: WC3 map file parsing

   local DIR = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
   package.path = DIR .. "/src/?.lua;" .. package.path

   local Map = require("data")

   print("╔══════════════════════════════════════════════════════════════╗")
   print("║         WC3 Map Parser - Phase 1 Demo                        ║")
   print("║         File Format Parsing Complete                         ║")
   print("╚══════════════════════════════════════════════════════════════╝")
   print()

   -- Load and display info for each map
   local maps_dir = DIR .. "/assets"
   local maps = list_files(maps_dir, "%.w3[xm]$")

   print(string.format("Found %d map files in assets/", #maps))
   print()

   for i, filename in ipairs(maps) do
       local path = maps_dir .. "/" .. filename
       local map = Map.load(path)

       print(string.format("┌─ Map %d: %s ─┐", i, filename))
       print(string.format("│ Name: %s", map:get_display_name()))
       print(string.format("│ Author: %s", map.author))
       print(string.format("│ Size: %dx%d tiles", map.width, map.height))
       print(string.format("│ Tileset: %s", map.tileset))
       print(string.format("│ Players: %d", #map.players))

       -- Show player details
       for _, player in ipairs(map.players) do
           print(string.format("│   [%d] %s (%s)", player.id, player.name, player.race))
       end

       -- Terrain statistics
       local terrain = map.terrain
       local stats = terrain:get_statistics()
       print(string.format("│ Terrain: %d water tiles, %d cliff tiles",
           stats.water_tiles, stats.cliff_tiles))
       print(string.format("│ Height range: %.1f to %.1f",
           stats.min_height, stats.max_height))

       print("└" .. string.rep("─", 60) .. "┘")
       print()
   end

   -- Summary statistics
   print("═══════════════════════════════════════════════════════════════")
   print("PHASE 1 CAPABILITIES DEMONSTRATED:")
   print("  ✓ MPQ archive parsing and file extraction")
   print("  ✓ Map info (w3i) parsing")
   print("  ✓ String table (wts) resolution")
   print("  ✓ Terrain (w3e) parsing with height/texture data")
   print("  ✓ Unified Map data structure")
   print("  ✓ CLI metadata dump tool")
   print("═══════════════════════════════════════════════════════════════")
   ```

4. **Create runner script**
   ```
   ./run-demo.sh
   ```

   ```bash
   #!/bin/bash
   # run-demo.sh
   # Runs phase demos for World Edit to Execute
   #
   # Usage: ./run-demo.sh [phase_number]
   # If no phase specified, prompts for selection.

   DIR="/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"

   # Override DIR if provided as argument
   if [[ "$1" =~ ^/ ]]; then
       DIR="$1"
       shift
   fi

   COMPLETED_PHASES=1  # Update as phases complete

   if [ -z "$1" ]; then
       echo "Available phase demos:"
       for i in $(seq 1 $COMPLETED_PHASES); do
           echo "  [$i] Phase $i"
       done
       echo
       read -p "Select phase (1-$COMPLETED_PHASES): " PHASE
   else
       PHASE=$1
   fi

   case $PHASE in
       1) lua "$DIR/issues/completed/demos/phase1_demo.lua" ;;
       *) echo "Phase $PHASE demo not available"; exit 1 ;;
   esac
   ```

5. **Write test report**
   Document results in the completed issue file before moving to completed/.

---

## Technical Notes

### Test Coverage

Phase 1 tests should verify:
- All 15 DAoW maps can be opened
- Essential files (w3i, w3e, wts) can be extracted
- No crashes or unhandled errors
- Reasonable memory usage
- Reasonable parse times

### Visual Demo

The demo should be runnable in a terminal and produce clear, formatted
output showing what Phase 1 accomplished. Use box-drawing characters
for visual appeal.

### Edge Cases to Test

- Very large maps (if any)
- Maps with unusual tilesets
- Maps with many players
- Maps with compressed vs uncompressed files

---

## Related Documents

- All Phase 1 issues (101-107)
- issues/progress.md (update with results)
- Global CLAUDE.md (demo conventions)

---

## Acceptance Criteria

- [ ] All test .w3x files pass integration tests
- [ ] Demo script runs without errors
- [ ] Demo produces formatted output showing:
  - Map metadata for each file
  - Player configurations
  - Terrain statistics
- [ ] run-demo.sh works with phase selection
- [ ] Any discovered issues documented as new tickets
- [ ] progress.md updated with Phase 1 completion

---

## Notes

This is the "phase gate" - Phase 1 is not complete until this issue passes.
Any failures here should generate new issue tickets, not be ignored.

The demo is also documentation - it shows future developers (and users)
what the project can do at this stage.

After this issue is complete:
1. Move all Phase 1 issues to issues/completed/
2. Update issues/progress.md
3. Create git tag: v0.1.0-phase1
4. Begin Phase 2 planning

---

## Sub-Issue Analysis

*Generated by Claude Code on 2025-12-16 00:23*

## Analysis: Issue 108 - Phase 1 Integration Test and Demo

This issue is a good candidate for splitting. It contains four distinct deliverables that can be implemented independently:

1. A test suite
2. A demo script
3. A runner script
4. Documentation/finalization tasks

### Recommended Sub-Issues

---

#### **108a-create-integration-test-suite**
**Name:** create-integration-test-suite  
**Description:** Create the test framework in `src/tests/phase1_test.lua` that exercises all Phase 1 components against the map files in `assets/`. Should test MPQ opening, file extraction, w3i/w3e/wts parsing, and the unified Map data structure. Produces a structured results table with pass/fail status and error details for each map.

**Dependencies:** None (but requires 101-107 to be implemented)

---

#### **108b-create-phase1-demo-script**
**Name:** create-phase1-demo-script  
**Description:** Create the visual demonstration script at `issues/completed/demos/phase1_demo.lua`. Uses box-drawing characters to display formatted output showing map metadata, player configurations, and terrain statistics for each map file. Demonstrates all Phase 1 capabilities in a user-friendly terminal presentation.

**Dependencies:** 108a (uses same underlying modules, benefits from test validation)

---

#### **108c-create-demo-runner-script**
**Name:** create-demo-runner-script  
**Description:** Create the `run-demo.sh` bash script in the project root that provides phase selection (interactive or via argument). Should follow project conventions with hardcoded `DIR`, argument override capability, and `-I` interactive mode flag per global CLAUDE.md requirements.

**Dependencies:** 108b (needs demo script to exist to run it)

---

#### **108d-run-tests-and-document-results**
**Name:** run-tests-and-document-results  
**Description:** Execute the integration test suite against all 15 DAoW maps, document any failures as new issue tickets, update `issues/progress.md` with Phase 1 completion status, and perform phase finalization: move completed issues to `issues/completed/`, create git tag `v0.1.0-phase1`.

**Dependencies:** 108a, 108b, 108c (all artifacts must exist and pass before finalization)

---

### Dependency Graph

```
108a (test suite)
  ↓
108b (demo script)
  ↓
108c (runner script)
  ↓
108d (run & document)
```

### Rationale for Split

- **108a** is the foundational testing work - purely technical, can be validated independently
- **108b** is presentation/demo focused - depends on same modules but different purpose
- **108c** is bash tooling - small and self-contained
- **108d** is the "gate" step - can only happen after everything else works

This split allows parallel work on 108a/108b if needed (they use same modules but produce different outputs), and clearly separates the "make it work" phase from the "document and finalize" phase.
