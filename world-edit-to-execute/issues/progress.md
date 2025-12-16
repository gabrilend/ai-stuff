# Project Progress

## Current Phase: 1 - Foundation (File Format Parsing)

**Status:** In Progress (Issues Created)

---

## Phase Summary

| Phase | Name | Status | Issues |
|-------|------|--------|--------|
| 0 | Tooling/Infrastructure | In Progress | 11/17 |
| 1 | Foundation - File Format Parsing | In Progress | 5/12 |
| 2 | Data Model - Game Objects | Planned | - |
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
| 002 | Add streaming queue to issue-splitter | In Progress | 001 |
| 002a | Add queue infrastructure | Pending | None (within 002) |
| 002b | Add producer function | Pending | 002a |
| 002c | Add streamer process | Pending | 002a |
| 002d | Add parallel processing loop | Pending | 002a, 002b, 002c |
| 002e | Add streaming config flags | Pending | 002d |
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

**Tool Location:** `/home/ritz/programming/ai-stuff/scripts/issue-splitter.sh`
(Symlinked from `src/cli/issue-splitter.sh`)

---

## Phase 1 Issues

| ID | Name | Status | Dependencies |
|----|------|--------|--------------|
| 101 | Research WC3 file formats | **Completed** | None |
| 102 | Implement MPQ archive parser | Pending | 101 |
| 102a | Parse MPQ header structure | **Completed** | 101 |
| 102b | Parse MPQ hash table | **Completed** | 102a |
| 102c | Parse MPQ block table | **Completed** | 102a, 102b |
| 102d | Implement file extraction | **Completed** | 102a, 102b, 102c |
| 103 | Parse war3map.w3i (map info) | Pending | 102 |
| 104 | Parse war3map.wts (trigger strings) | Pending | 102 |
| 105 | Parse war3map.w3e (terrain) | Pending | 102, 103 |
| 106 | Design internal data structures | Pending | 103, 104, 105 |
| 107 | Build CLI metadata dump tool | Pending | 106 |
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

---

## Next Steps

### Phase 1 (Ready to Start)

1. **102 - Create unified MPQ API** (High Priority)
   - Create src/mpq/init.lua to tie all sub-modules together
   - Clean interface for opening archives and extracting files

2. **103 - Parse war3map.w3i** (Depends on 102)
   - Map metadata parsing

3. **104 - Parse war3map.wts** (Depends on 102)
   - Trigger strings parsing

### Phase 0 (Parallel Work)

4. **002 - Add streaming queue to issue-splitter**
   - 002a-002e sub-issues pending
