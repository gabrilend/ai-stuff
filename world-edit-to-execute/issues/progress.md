# Project Progress

## Current Phase: 2 - Data Model (Game Objects)

**Status:** In Progress (7/8 Complete)

---

## Phase Summary

| Phase | Name | Status | Issues |
|-------|------|--------|--------|
| A | Infrastructure Tools (Shared) | Issues Created | 0/7 |
| 0 | Tooling/Infrastructure | In Progress | 18/19 |
| 1 | Foundation - File Format Parsing | **Completed** | 12/12 |
| 2 | Data Model - Game Objects | In Progress | 7/8 |
| 3 | Logic Layer - Triggers and JASS | Issues Created | 0/9 |
| 4 | Runtime - Basic Engine Loop | Issues Created | 0/8 |
| 5 | Rendering - Visual Abstraction | Planned | - |
| 6 | Asset System - Community Content | Planned | - |
| 7 | Gameplay - Core Mechanics | Planned | - |
| 8 | Multiplayer - Network Layer | Planned | - |
| 9 | Polish - Tools and UX | Planned | - |

---

## Phase A Issues (Infrastructure Tools)

| ID | Name | Status | Dependencies |
|----|------|--------|--------------|
| A01 | Git history prettifier | Pending | None |
| A02 | Phase progress dashboard | Pending | None |
| A03 | Unified test runner | Pending | None |
| A04 | Issue validator | Pending | None |
| A05 | Documentation index updater | Pending | None |
| A06 | Parser coverage report | Pending | None |
| A07 | Phase A integration test | Pending | A01-A06 |

### Design Philosophy

Phase A tools are **project-abstract** and live in the shared scripts directory:
- Location: `/home/ritz/programming/ai-stuff/scripts/`
- Symlinked into projects: `src/cli/<tool>`
- Usable as both CLI tools and sourceable libraries

### Dependency Graph

```
No dependencies (all independent except A07)
 │
 ├──▶ A01 Git History Prettifier
 ├──▶ A02 Progress Dashboard
 ├──▶ A03 Test Runner
 ├──▶ A04 Issue Validator
 ├──▶ A05 TOC Updater
 ├──▶ A06 Parser Coverage
 │
 └──▶ A07 Integration Test (depends on A01-A06)
```

---

## Phase 0 Issues (Tooling)

| ID | Name | Status | Dependencies |
|----|------|--------|--------------|
| 001 | Fix issue-splitter output handling | **Completed** | None |
| 002 | Add streaming queue to issue-splitter | **Completed** | 001 |
| 002a | Add queue infrastructure | **Completed** | None (within 002) |
| 002b | Add producer function | **Completed** | 002a |
| 002c | Add streamer process | **Completed** | 002a |
| 002d | Add parallel processing loop | **Completed** | 002a, 002b, 002c |
| 002e | Add streaming config flags | **Completed** | 002d |
| 003 | Execute analysis recommendations | **Completed** | 001 |
| 004 | Redesign interactive mode interface | **Completed** | None |
| 004a | Create TUI core library | **Completed** | None |
| 004b | Implement checkbox component | **Completed** | 004a |
| 004c | Implement multistate toggle | **Completed** | 004a, 004b |
| 004d | Implement input components | **Completed** | 004a |
| 004e | Build menu navigation system | **Completed** | 004b, 004c, 004d |
| 004f | Integrate TUI into issue-splitter | **Completed** | 004a-e |
| 005 | Migrate TUI library to shared libs | **Completed** | 004 |
| 006 | Rename analysis sections for promoted roots | **Completed** | 003 |
| 007 | Add auto-implement via Claude CLI | **Completed** | None |
| 010 | Debug TUI integration analysis | Pending | 004 |
| 011 | TUI history insert on run | Pending | 004 |
| 012 | Interactive verdict review mode | Pending | 003, 004 |

**Tool Location:** `/home/ritz/programming/ai-stuff/scripts/issue-splitter.sh`
(Symlinked from `src/cli/issue-splitter.sh`)

---

## Phase 1 Issues

| ID | Name | Status | Dependencies |
|----|------|--------|--------------|
| 101 | Research WC3 file formats | **Completed** | None |
| 102 | Implement MPQ archive parser | **Completed** | 101 |
| 102a | Parse MPQ header structure | **Completed** | 101 |
| 102b | Parse MPQ hash table | **Completed** | 102a |
| 102c | Parse MPQ block table | **Completed** | 102a, 102b |
| 102d | Implement file extraction | **Completed** | 102a, 102b, 102c |
| 103 | Parse war3map.w3i (map info) | **Completed** | 102 |
| 104 | Parse war3map.wts (trigger strings) | **Completed** | 102 |
| 105 | Parse war3map.w3e (terrain) | **Completed** | 102, 103 |
| 106 | Design internal data structures | **Completed** | 103, 104, 105 |
| 107 | Build CLI metadata dump tool | **Completed** | 106 |
| 108 | Phase 1 integration test | **Completed** | 101-107 |

### Dependency Graph

```
101 Research
 │
 └──▶ 102 MPQ Parser
      ├── 102a Header
      │    └──▶ 102b Hash Table
      │         └──▶ 102c Block Table
      │              └──▶ 102d Extraction
      │
      ├──▶ 103 w3i Parser
      ├──▶ 104 wts Parser
      └──▶ 105 w3e Parser
           │
           └──▶ 106 Data Structures
                │
                └──▶ 107 CLI Tool
                     │
                     └──▶ 108 Integration Test
```

---

## Phase 2 Issues

| ID | Name | Status | Dependencies |
|----|------|--------|--------------|
| 201 | Parse war3map.doo (doodads/trees) | **Completed** | 102 |
| 202 | Parse war3mapUnits.doo (units/buildings) | **Completed** | 102, 201 |
| 202a | Parse unitsdoo header and basic fields | **Completed** | 201 |
| 202b | Parse unitsdoo item drops | **Completed** | 202a |
| 202c | Parse unitsdoo abilities | **Completed** | 202a |
| 202d | Parse unitsdoo hero data | **Completed** | 202a |
| 202e | Parse unitsdoo random/waygate | **Completed** | 202a |
| 203 | Parse war3map.w3r (regions) | **Completed** | 102 |
| 204 | Parse war3map.w3c (cameras) | **Completed** | 102 |
| 205 | Parse war3map.w3s (sounds) | **Completed** | 102 |
| 206 | Design game object types | In Progress | 201-205 |
| 206a | Create gameobjects module structure | Pending | None |
| 206b | Implement Doodad class | Pending | 206a, 201 |
| 206c | Implement Unit class | **Completed** | 206a, 202 |
| 206d | Implement Region class | Pending | 206a, 203 |
| 206e | Implement Camera class | Pending | 206a, 204 |
| 206f | Implement Sound class | Pending | 206a, 205 |
| 206g | Finalize module and documentation | Pending | 206b-f |
| 207 | Build object registry system | In Progress | 206 |
| 207a | Core registry class | **Completed** | 206 |
| 207b | Filtering and iteration | Pending | 207a |
| 207c | Spatial index | **Completed** | None |
| 207d | Spatial integration | **Completed** | 207a, 207c |
| 207e | Map integration | **Completed** | 207a |
| 207f | Registry tests | Pending | 207a-207e |
| 208 | Phase 2 integration test | Pending | 201-207 |

### Dependency Graph

```
Phase 1 Complete (102 MPQ Parser)
 │
 ├──▶ 201 doo Parser (doodads/trees)
 │     └──▶ 202 Units.doo Parser
 │
 ├──▶ 203 w3r Parser (regions)
 │
 ├──▶ 204 w3c Parser (cameras)
 │
 └──▶ 205 w3s Parser (sounds)
       │
       └──▶ 206 Game Object Types
            │
            └──▶ 207 Object Registry
                 │
                 └──▶ 208 Integration Test
```

---

## Phase 3 Issues

| ID | Name | Status | Dependencies |
|----|------|--------|--------------|
| 301 | Parse war3map.wtg (trigger definitions) | Pending | 102 |
| 302 | Parse war3map.wct (custom text triggers) | Pending | 102, 301 |
| 303 | Parse war3map.j (JASS script) | Pending | 102 |
| 304 | Build JASS lexer | Pending | 303 |
| 305 | Build JASS parser | Pending | 304 |
| 306 | Create JASS-to-Lua transpiler | Pending | 305 |
| 307 | Implement trigger framework | Pending | 306 |
| 308 | Build event dispatch system | Pending | 307 |
| 309 | Phase 3 integration test | Pending | 301-308 |

### Dependency Graph

```
Phase 1 Complete (102 MPQ Parser)
 │
 ├──▶ 301 wtg Parser (triggers)
 │     └──▶ 302 wct Parser (custom triggers)
 │
 └──▶ 303 j Extractor (JASS script)
       │
       └──▶ 304 JASS Lexer
            │
            └──▶ 305 JASS Parser
                 │
                 └──▶ 306 JASS-to-Lua Transpiler
                      │
                      └──▶ 307 Trigger Framework
                           │
                           └──▶ 308 Event Dispatch
                                │
                                └──▶ 309 Integration Test
```

---

## Phase 4 Issues

| ID | Name | Status | Dependencies |
|----|------|--------|--------------|
| 401 | Implement game tick/update loop | Pending | Phase 2, Phase 3 |
| 402 | Build entity component system | Pending | 401 |
| 403 | Implement basic pathfinding | Pending | 401, 402, 105 |
| 404 | Create unit movement system | Pending | 401, 402, 403 |
| 405 | Implement basic collision detection | Pending | 401, 402, 404 |
| 406 | Build resource management system | Pending | 401, 402, 407 |
| 407 | Create player state management | Pending | 401, 402 |
| 408 | Phase 4 integration test | Pending | 401-407 |

### Dependency Graph

```
Phase 2 & 3 Complete
 │
 └──▶ 401 Game Loop
      │
      └──▶ 402 ECS
           │
           ├──▶ 403 Pathfinding ──▶ 404 Movement ──▶ 405 Collision
           │
           └──▶ 407 Player State ──▶ 406 Resources
                │
                └──▶ 408 Integration Test
```

---

## Recent Activity

- Project initialized
- Vision document created with legal/emulator addendum
- Roadmap established
- Documentation structure created
- **Phase 1 issues created (12 total, 4 sub-issues)**
- Created issue-splitter.sh tool for automated issue analysis
- **Phase 0 tooling issues created (5 root issues for tool improvements)**
- Moved issue-splitter.sh to shared scripts directory with symlink
- **Issue 001 completed:** Fixed output handling, added --archive flag
- **Issue 002 sub-issues created:** 002a-002e for streaming queue implementation
- Fixed false-positive detection bug in has_subissue_analysis()
- **Issue 101 completed:** Research WC3 file formats
  - Created docs/formats/mpq-archive.md (including HM3W wrapper)
  - Created docs/formats/w3i-map-info.md
  - Created docs/formats/wts-trigger-strings.md
  - Created docs/formats/w3e-terrain.md
  - Validated against DAoW-2.1.w3x test map
- **Issue 102a completed:** Parse MPQ header structure
  - Created src/mpq/header.lua module
  - Created src/tests/test_header.lua
  - All 16 map files parse successfully
- **Issue 102b completed:** Parse MPQ hash table
  - Created src/mpq/hash.lua (crypto table, hash function, decryption)
  - Created src/mpq/hashtable.lua (parse, lookup)
  - Verified hash values against reference implementation
  - All 16 maps can lookup war3map.w3i
- **Issue 102c completed:** Parse MPQ block table
  - Created src/mpq/blocktable.lua
  - Key finding: All files in test maps are encrypted
  - All 16 maps parse successfully
- **Issue 004 completed:** Redesign interactive mode interface
  - Created TUI library stack in /home/ritz/programming/ai-stuff/scripts/libs/
    - tui.sh (core), checkbox.sh, multistate.sh, input.sh, menu.sh
  - Issue 004a-004f all completed
  - Integrated TUI into issue-splitter.sh with fallback to simple prompts
- **Issue 005 completed:** Migrate TUI library to shared libs
  - Already achieved via scripts/libs/ location (different path than spec)
  - Library accessible by all projects under ai-stuff/
- **Issue 006 completed:** Rename analysis sections for promoted roots
  - Added has_initial_analysis() detection function
  - Added rename_analysis_to_initial() to rename on promotion
  - Updated skip logic to respect both analysis types
- **Issue 102d completed:** Implement file extraction
  - Created src/mpq/extract.lua
  - Created src/tests/test_extract.lua
  - Uses Python3 zlib for decompression (temporary solution)
  - 15/16 test maps extract successfully
  - PKWARE DCL compression not yet implemented (1 test map affected)
- **Issue 007 completed:** Add auto-implement via Claude CLI
  - Added -A/--auto-implement flag to issue-splitter.sh
  - Invokes `claude --dangerously-skip-permissions` with issue content
  - Added "Implement" option to TUI interactive mode
  - Supports dry-run preview and confirmation prompts
- **Issue 002a completed:** Add queue infrastructure
  - Added Queue Configuration variables (QUEUE_DIR, QUEUE_COUNTER, STREAM_INDEX, STREAMER_PID)
  - Implemented setup_queue() and cleanup_queue() functions
  - Added EXIT/INT/TERM trap for cleanup
  - Created test file: src/tests/test_002a_queue_infrastructure.sh
- **Issue 002b completed:** Add producer function
  - Implemented queue_claude_response() function
  - Creates .output, .meta, and .ready files per queue slot
  - Handles timeout and failure states
  - Created test file: src/tests/test_002b_producer_function.sh
- **Issue 002c completed:** Add streamer process
  - Implemented stream_queue() consumer function
  - Displays outputs in order with formatted headers
  - Uses idle timeout for termination (subshell-safe)
  - Created test file: src/tests/test_002c_streamer_process.sh
- **Issue 102 completed:** Implement MPQ archive parser
  - Created src/mpq/init.lua (unified API)
  - Created src/tests/test_mpq.lua
  - API: mpq.open(), archive:has(), archive:extract(), archive:info(), archive:close()
  - 15/16 test maps work (1 uses unsupported PKWARE DCL)
- **Issue 002d completed:** Add parallel processing loop
  - Added PARALLEL_COUNT, STREAM_DELAY, STREAMING_MODE config
  - Implemented process_issue_parallel() for queue+append
  - Implemented parallel_process_issues() orchestrator
  - Uses wait -n for job slot management (requires Bash 4.3+)
  - Created test file: src/tests/test_002d_parallel_processing.sh
- **Issue 002e completed:** Add streaming config flags
  - Added --stream, --parallel, --delay flags to parse_args
  - Updated help text with new options
  - Modified main() for conditional parallel/sequential processing
- **Issue 002 completed:** Add streaming queue to issue-splitter (all sub-issues done)
- **Phase 0 completed:** Tooling/Infrastructure (18/18 issues)
- **Phase 2 issues created:** Data Model - Game Objects (8 issues)
  - 201: Parse war3map.doo (doodads/trees)
  - 202: Parse war3mapUnits.doo (units/buildings)
  - 203: Parse war3map.w3r (regions)
  - 204: Parse war3map.w3c (cameras)
  - 205: Parse war3map.w3s (sounds)
  - 206: Design game object types
  - 207: Build object registry system
  - 208: Phase 2 integration test
- **Issue 103 completed:** Parse war3map.w3i (map info)
  - Created src/parsers/w3i.lua (full w3i parser)
  - Created src/compat.lua (Lua 5.3+/LuaJIT compatibility layer)
  - Created src/tests/test_w3i.lua
  - Updated all MPQ modules to use compat layer
  - 15/16 test maps parse successfully
  - Parses: map name, author, players, forces, flags, fog, weather
- **Issue 104 completed:** Parse war3map.wts (trigger strings)
  - Created src/parsers/wts.lua (StringTable class)
  - Created src/tests/test_wts.lua
  - 16/16 test maps parse successfully
  - TRIGSTR_xxx resolution working (e.g., TRIGSTR_199 → actual map name)
- **Issue 105 completed:** Parse war3map.w3e (terrain)
  - Created src/parsers/w3e.lua (Terrain class with Tilepoint data)
  - Created src/tests/test_w3e.lua
  - 15/16 test maps parse successfully
  - Full terrain data: heights, textures, water, cliffs, ramps
- **Issue 106 completed:** Design internal data structures
  - Created src/data/init.lua (unified Map class)
  - Created src/tests/test_data.lua
  - Map.load() integrates all parsers (w3i, wts, w3e)
  - 16/16 test maps load successfully
- **Issue 107 completed:** Build CLI metadata dump tool
  - Created src/cli/mapdump.lua
  - Supports text and JSON output formats
  - Components: info, strings, terrain, files, all
  - Interactive mode with -I flag
- **Issue 108 completed:** Phase 1 integration test
  - Created src/tests/phase1_test.lua (integration test suite)
  - Created issues/completed/demos/phase1_demo.lua (visual demo)
  - Created run-demo.sh (phase demo runner)
  - 15/16 test maps pass (1 uses PKWARE DCL - known limitation)
  - **Phase 1 Complete!**
- **Issue 203 completed:** Parse war3map.w3r (regions)
  - Created src/parsers/w3r.lua (region parser)
  - Created src/tests/test_w3r.lua (test suite)
  - Parses: bounds, names, creation numbers, weather, sounds, colors
  - Provides lookup by creation_number for waygate targeting
  - 16/16 test maps process (all happen to have no regions defined)
  - Synthetic data test validates all parsing logic
- **Issue 204 completed:** Parse war3map.w3c (cameras)
  - Created src/parsers/w3c.lua (camera parser)
  - Created src/tests/test_w3c.lua (test suite with synthetic data)
  - Created src/tests/check_file_presence.lua (debug utility)
  - Parses: target positions, angles, distances, FOV, clipping planes
  - Supports both standard and 1.31+ extended format (local rotations)
  - Provides lookup by camera name via by_name index
  - 16/16 test maps process (all happen to have no cameras defined)
  - 22/22 tests pass (6 synthetic + 16 map tests)
- **Issue 205 completed:** Parse war3map.w3s (sounds)
  - Created src/parsers/w3s.lua (sound definitions parser)
  - Created src/tests/test_w3s.lua (test suite with synthetic data)
  - Parses: variable names, file paths, EAX effects, flags, channels
  - Parses: volume, pitch, 3D distance params, cone params
  - Supports version 1 (TFT) and version 3 (Reforged) formats
  - Provides lookup by sound name via SoundTable class
  - 16/16 test maps process (all happen to have no sounds defined)
  - 10/10 tests pass (9 synthetic + 1 map batch test)
- **Phase 4 issues created:** Runtime - Basic Engine Loop (8 issues)
  - 401: Implement game tick/update loop (62.5 ticks/sec, timers)
  - 402: Build entity component system (ECS for all game objects)
  - 403: Implement basic pathfinding (A* on terrain grid)
  - 404: Create unit movement system (orders, path following)
  - 405: Implement basic collision detection (spatial hash)
  - 406: Build resource management system (gold, lumber, food)
  - 407: Create player state management (alliances, victory)
  - 408: Phase 4 integration test
- **Phase 3 issues created:** Logic Layer - Triggers and JASS (9 issues)
  - 301: Parse war3map.wtg (trigger definitions)
  - 302: Parse war3map.wct (custom text triggers)
  - 303: Parse war3map.j (JASS script extraction)
  - 304: Build JASS lexer (tokenization)
  - 305: Build JASS parser (AST generation)
  - 306: Create JASS-to-Lua transpiler
  - 307: Implement trigger framework (conditions/actions)
  - 308: Build event dispatch system
  - 309: Phase 3 integration test
- **Phase A issues created:** Infrastructure Tools - Shared Libraries (7 issues)
  - A01: Git history prettifier (per-phase commit logs)
  - A02: Phase progress dashboard (issue status visualization)
  - A03: Unified test runner (aggregate test execution)
  - A04: Issue validator (check issue file format)
  - A05: Documentation index updater (auto-generate TOC)
  - A06: Parser coverage report (compatibility matrix)
  - A07: Phase A integration test
- **Issue 109 completed:** Implement PKWARE DCL decompression
  - Created src/mpq/pkware.lua (pure Lua decompressor, ~470 lines)
  - Updated src/mpq/extract.lua with expected_size parameter
  - Supports Binary and ASCII compression modes
  - Supports 4/5/6 bit dictionary sizes
  - Key fix: Use expected output size from block table (not all streams have end marker)
  - **16/16 test maps now pass** (Daow6.2.w3x previously failed)
- **Issue 011 created:** TUI history insert on run
  - Enhancement: TUI exits with command in history instead of executing
  - User can press "up" to recall and re-run without re-entering TUI
  - Enables "command discovery" workflow (learn CLI via TUI, then use directly)
- Added --session (-S) flag to issue-splitter.sh
  - Reuses Claude context across issues (faster, avoids re-reading project files)
  - Uses `claude --continue` for sequential processing
  - Added --expert (-E) for explicit fresh context per issue (default behavior)
  - Session mode auto-disabled when using --stream (parallel incompatible)
- **Issue 201 completed:** Parse war3map.doo (doodads/trees)
  - Created src/parsers/doo.lua (DoodadTable class with spatial queries)
  - Created src/tests/test_doo.lua (9 synthetic + 16 map tests)
  - 16/16 test maps parse successfully (226,232 doodads total)
  - Supports version 7 (42 bytes/entry) and version 8 (50 bytes/entry)
  - Fixed FFI segfault in compat.lua (disabled FFI, use manual byte unpacking)
  - Special doodads section differs between v7 (item drops) and v8 (fixed entries)
- **Issue 202a completed:** Parse unitsdoo header and basic fields
  - Created src/parsers/unitsdoo.lua (609 lines, UnitTable class)
  - Created src/tests/test_unitsdoo.lua (79 tests)
  - 5/16 test maps contain war3mapUnits.doo, all parse successfully
  - Skip functions for variable-length sections (202b-e will implement these)
  - Fixed hero detection to exclude random unit placeholders (YY* prefix)
- **Issue 202b completed:** Parse unitsdoo item drops
  - Replaced skip_item_drops with parse_item_drops
  - Returns structured item_drops with table_pointer and sets array
  - Added COMMON_ITEMS lookup table for item names
- **Issue 202c completed:** Parse unitsdoo abilities
  - Replaced skip_abilities with parse_abilities
  - Returns array of abilities with id, autocast (bool), level
  - Format output shows units with modified abilities
  - 94/94 tests pass
- **Issue 202d completed:** Parse unitsdoo hero data
  - parse_hero_data extracts hero level, stat bonuses, inventory
  - is_hero detects heroes via capital first letter in type ID
  - Hero inventory stored by slot (0-5) with COMMON_ITEMS lookup
  - Format output shows hero stats and inventory
  - 94/94 tests pass
- **Issue 202e completed:** Parse unitsdoo random/waygate data
  - Added decode_random_level for level char decoding ('0'-'9', 'A'-'Z')
  - Replaced skip_random_unit with parse_random_unit
  - Distinguishes "YYU" (random unit) from "YYI" (random item) prefixes
  - Format output shows random info and active waygate destinations
  - 139/139 tests pass (all 5 202 sub-issues complete)
- **Issue 207 sub-issues created:**
  - 207a: Core registry class (storage, add_*, lookup)
  - 207b: Filtering and iteration (get_heroes, each_*, filter)
  - 207c: Spatial index (standalone grid-based spatial queries)
  - 207d: Spatial integration (connect spatial index to registry)
  - 207e: Map integration (populate registry from Map.load)
  - 207f: Registry tests (comprehensive test suite)
- **Issue 206 split into sub-issues:** Design game object types
  - 206a: Create gameobjects module structure
  - 206b-f: Implement Doodad, Unit, Region, Camera, Sound classes
- **Issue 207a completed:** Core registry class
  - Created src/registry/init.lua (ObjectRegistry class)
  - Type-specific storage arrays with by_creation_id and by_name indexes
  - Supports parser output (creation_number field)
  - 48/48 tests pass
- **Issue 207c completed:** Spatial index
  - Created src/registry/spatial.lua (SpatialIndex class)
  - Grid-based spatial indexing with configurable cell size
  - query_radius, query_rect, query_point methods
  - 75/75 tests pass
- **Issue 207d completed:** Spatial integration
  - Integrated SpatialIndex with ObjectRegistry
  - enable_spatial_index(), get_objects_in_radius(), get_objects_in_region()
  - Auto-indexing of doodads/units when spatial enabled
  - 31/31 new tests pass
- **Issue 207e completed:** Map integration
  - Updated src/data/init.lua with Phase 2 parser requires and ObjectRegistry
  - Map.load() now populates registry with doodads, units, regions, cameras, sounds
  - Added convenience methods: get_unit, get_doodad, get_region, get_camera, get_sound
  - Updated format() and info() to include registry statistics
  - Added 5 registry tests to test_data.lua, all pass
  - Added diagnostic scripts: check_map_files.lua, check_registry_stats.lua
  - 226,232 doodads and 5 units loaded across 16 test maps
- **Issue 206c completed:** Implement Unit class
  - Created src/gameobjects/unit.lua (full Unit class implementation)
  - Created src/tests/test_unit.lua (68 tests, all pass)
  - Type detection: is_hero(), is_building(), is_item(), is_random(), is_waygate()
  - Hero methods: get_hero_level(), get_hero_stats(), get_inventory()
  - Additional: has_item_drops(), has_modified_abilities(), __tostring()
  - Note: is_building() uses heuristic (proper detection needs object data lookup)

---

## Next Steps

### Phase 1 Complete!

All Phase 1 (Foundation - File Format Parsing) issues are now complete.

Capabilities established:
- MPQ archive parsing with file extraction
- Map info (w3i), string table (wts), terrain (w3e) parsing
- Unified Map data structure
- CLI tool for map inspection

### Phase 2 - Data Model: Game Objects

1. ~~**201 - Parse war3map.doo** (doodads/trees)~~ ✓
2. ~~**202 - Parse war3mapUnits.doo** (units/buildings)~~ ✓
   - 202a-202e all complete (header, items, abilities, hero data, random/waygate)
3. ~~**203 - Parse war3map.w3r** (regions)~~ ✓
4. ~~**204 - Parse war3map.w3c** (cameras)~~ ✓
5. ~~**205 - Parse war3map.w3s** (sounds)~~ ✓
6. **206 - Design game object types**
7. **207 - Build object registry system**
8. **208 - Phase 2 integration test**

### Phase 0 Complete

All Phase 0 (Tooling/Infrastructure) issues are now complete.
The streaming queue system is available via `--stream` flag.
