# Project Progress

## Current Phase: 1 - Foundation (File Format Parsing)

**Status:** In Progress (Issues Created)

---

## Phase Summary

| Phase | Name | Status | Issues |
|-------|------|--------|--------|
| 0 | Tooling/Infrastructure | **Completed** | 18/18 |
| 1 | Foundation - File Format Parsing | In Progress | 11/12 |
| 2 | Data Model - Game Objects | Issues Created | 0/8 |
| 3 | Logic Layer - Triggers and JASS | Planned | - |
| 4 | Runtime - Basic Engine Loop | Planned | - |
| 5 | Rendering - Visual Abstraction | Planned | - |
| 6 | Asset System - Community Content | Planned | - |
| 7 | Gameplay - Core Mechanics | Planned | - |
| 8 | Multiplayer - Network Layer | Planned | - |
| 9 | Polish - Tools and UX | Planned | - |

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
| 108 | Phase 1 integration test | Pending | 101-107 |

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
| 201 | Parse war3map.doo (doodads/trees) | Pending | 102 |
| 202 | Parse war3mapUnits.doo (units/buildings) | Pending | 102, 201 |
| 203 | Parse war3map.w3r (regions) | Pending | 102 |
| 204 | Parse war3map.w3c (cameras) | Pending | 102 |
| 205 | Parse war3map.w3s (sounds) | Pending | 102 |
| 206 | Design game object types | Pending | 201-205 |
| 207 | Build object registry system | Pending | 206 |
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

---

## Next Steps

### Phase 1 (Final Issue)

1. **108 - Phase 1 integration test** (High Priority)
   - Validate all parsers work together
   - Create demo showing Phase 1 capabilities
   - Final issue to complete Phase 1

### Phase 0 Complete

All Phase 0 (Tooling/Infrastructure) issues are now complete.
The streaming queue system is available via `--stream` flag.
