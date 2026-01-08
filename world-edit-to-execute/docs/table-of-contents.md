# World Edit to Execute - Documentation

## Table of Contents

```
./
├── CLAUDE.md                   Project instructions for Claude Code
│
docs/
├── table-of-contents.md       (this file)
├── roadmap.md                  Project phases and milestones
├── critical-path.md → ../issues/CRITICAL-PATH.md  Decision points & open questions
├── render-architecture.md      Threading model, component slots, numeric encoding
├── render-system-multithreading.md  Pipeline stages, task submission, synchronization
├── binary-vector-frames.md     Quadrant voting, curve approximation, 3D rotations
├── azerothcore-integration-architecture.md  AzerothCore integration overview
├── client-architecture.md      Dual-protocol client, dual-view rendering
├── data-conversion-pipeline.md WC3 → AC data conversion
├── custom-ability-bridge.md    WC3 custom ability handling
├── phase-reorganization.md     Revised phase structure proposal
├── formats/                    File format specifications
│   ├── mpq-archive.md          MPQ archive format (with HM3W wrapper)
│   ├── w3i-map-info.md         Map info file format
│   ├── wts-trigger-strings.md  Trigger string table format
│   ├── w3e-terrain.md          Terrain/tileset data format
│   ├── pkware-dcl-compression.md  PKWARE DCL compression
│   └── unitsdoo.md               Unit/building placement format
│
src/
├── cli/
│   ├── issue-splitter.sh → /home/ritz/programming/ai-stuff/scripts/issue-splitter.sh
│   ├── quest-generator.lua    Quest/bounty documentation generator
│   └── guild-cli.lua          Hero & shop management CLI
├── mpq/                        MPQ archive parsing
│   ├── init.lua                Unified API (mpq.open, archive:extract)
│   ├── header.lua              Header parsing (incl. HM3W wrapper)
│   ├── hash.lua                Hash function and crypto table
│   ├── hashtable.lua           Hash table parsing and lookup
│   ├── blocktable.lua          Block table parsing
│   ├── extract.lua             File extraction with decompression
│   └── pkware.lua              PKWARE DCL decompressor
├── parsers/                    File format parsers
│   ├── w3i.lua                 Map info (name, players, forces)
│   ├── wts.lua                 Trigger strings (TRIGSTR resolution)
│   ├── w3e.lua                 Terrain (heights, textures, water)
│   ├── doo.lua                 Doodads/trees
│   ├── unitsdoo.lua            Units/buildings/heroes/items
│   ├── w3r.lua                 Regions
│   ├── w3c.lua                 Cameras
│   └── w3s.lua                 Sounds
├── gameobjects/                Game object type system (Issue 206)
│   ├── init.lua                Module exports
│   ├── doodad.lua              Doodad class
│   ├── unit.lua                Unit class (with hero/building detection)
│   ├── region.lua              Region class (with containment checks)
│   ├── camera.lua              Camera class (with eye position calc)
│   └── sound.lua               Sound class (with flag accessors)
├── registry/                   Object registry system (Issue 207)
│   ├── init.lua                ObjectRegistry class
│   └── spatial.lua             SpatialIndex for spatial queries
├── validation/                 Cross-reference validation (Issue 111)
│   └── init.lua                Validates references between map files
├── data/                       Unified Map class
│   └── init.lua                Map.load() integrates all parsers
├── guild/                      Hero & Shop System (Issue 014)
│   ├── init.lua                Module exports, persistence, JSON utils
│   ├── hero.lua                Hero class (stats, inventory, equipment)
│   ├── items.lua               Item system (types, rarity, effects)
│   └── shop.lua                Shop system (stock, transactions)
├── render/                     Rendering system (Phase 5)
│   ├── main.c                  Raylib demo - threaded cube renderer
│   └── run                     Build and run script
├── libs/attributes/            Attribute System (Issue 016)
│   ├── init.lua                Module exports (016a complete)
│   ├── schema.lua              Attribute types, flags, validation (016a complete)
│   ├── registry.lua            Schema storage, dependency graph (016a complete)
│   ├── getters.lua             Dispatch table getters [pending 016b]
│   ├── setters.lua             Dispatch table setters [pending 016c]
│   ├── modifiers.lua           Modifier stack system [pending 016d]
│   ├── derived.lua             Derived attribute engine [pending 016e]
│   ├── events.lua              Change event system [pending]
│   ├── mapping.lua             Cross-system attribute mapping [pending 016h]
│   └── configs/
│       ├── wc3.lua             WC3 attribute definitions [pending 016f]
│       └── wow.lua             WoW attribute definitions [pending 016g]
│
docs/templates/                 Quest & Bounty Templates
├── README.md                   Template system documentation
├── bounty-template.md          Boss monster bounty board template
├── quest-template.md           Individual quest entry template
├── quest-log-template.md       Full quest log template
├── guild-roster-template.md    Progress tracking roster template
└── example-spec.lua            Example specification for generator
│
notes/
├── vision                      Core project vision and philosophy
│
issues/
├── progress.md                 Overall phase progress tracking
├── CRITICAL-PATH.md            Decision points, open questions, tech debt
├── 001-fix-issue-splitter-output-handling.md
├── 002-add-streaming-queue-to-issue-splitter.md
├── 003-execute-analysis-recommendations.md
├── 004-redesign-interactive-mode-interface.md
├── 010-debug-tui-integration-analysis.md
├── 011-tui-history-insert-on-run.md
├── 012-interactive-verdict-review-mode.md
├── 101-research-wc3-file-formats.md
├── 102-implement-mpq-archive-parser.md
├── 102a-parse-mpq-header.md
├── 102b-parse-mpq-hash-table.md
├── 102c-parse-mpq-block-table.md
├── 102d-implement-file-extraction.md
├── 103-parse-war3map-w3i.md
├── 104-parse-war3map-wts.md
├── 105-parse-war3map-w3e.md
├── 106-design-internal-data-structures.md
├── 107-build-cli-metadata-dump-tool.md
├── 108-phase-1-integration-test.md
├── 201-parse-war3map-doo.md
├── 202-parse-war3map-units-doo.md
├── 203-parse-war3map-w3r.md
├── 204-parse-war3map-w3c.md
├── 205-parse-war3map-w3s.md
├── 206-design-game-object-types.md
├── 207-build-object-registry-system.md
├── 208-phase-2-integration-test.md
│   (Phase 8 issues maintained at /home/ritz/programming/ai-stuff/my-libs/issues/)
├── completed/                  Completed issue archive
│   └── demos/                  Phase completion demonstrations
```

---

## Document Index

### Core Documents

| Document | Location | Description |
|----------|----------|-------------|
| CLAUDE.md | ./CLAUDE.md | Project instructions for Claude Code |
| Vision | notes/vision | Project philosophy, legal basis, and goals |
| Roadmap | docs/roadmap.md | Phased development plan |
| Progress | issues/progress.md | Current phase status |
| Critical Path | docs/critical-path.md | Decision points, open questions, tech debt |
| Render Architecture | docs/render-architecture.md | Threading model, component slots, numeric encoding |
| Binary Vector Frames | docs/binary-vector-frames.md | Quadrant voting, curve approximation, 3D rotations |

### Architecture Design Documents

**Created:** 2026-01-07 - AzerothCore integration architectural clarification

| Document | Location | Description |
|----------|----------|-------------|
| AzerothCore Integration | docs/azerothcore-integration-architecture.md | Overall system architecture, data flow, component ownership |
| Client Architecture | docs/client-architecture.md | Dual-protocol client, dual-view rendering, Phase 5 split (5A/5B/5C) |
| Data Conversion Pipeline | docs/data-conversion-pipeline.md | WC3 → AC conversion (terrain, units, items, triggers, etc.) |
| Custom Ability Bridge | docs/custom-ability-bridge.md | WC3 custom ability handling (Eluna vs C++ fork approach) |
| Phase Reorganization | docs/phase-reorganization.md | Revised phase structure, migration plan, impact analysis |

### Tools

| Tool | Location | Description |
|------|----------|-------------|
| issue-splitter.sh | src/cli/issue-splitter.sh (symlink) | Issue analysis, sub-issue creation, auto-implementation |
| quest-generator.lua | src/cli/quest-generator.lua | Gamified task documentation generator |
| TUI library | /home/ritz/.../scripts/libs/ | Shared terminal UI (checkbox, menu, input) |

### Phase 0 Issues (Tooling)

| Issue | Description | Status |
|-------|-------------|--------|
| 001 | Fix issue-splitter output handling | **Completed** |
| 002 | Add streaming queue to issue-splitter | **Completed** |
| 002a | Add queue infrastructure | **Completed** |
| 002b | Add producer function | **Completed** |
| 002c | Add streamer process | **Completed** |
| 002d | Add parallel processing loop | **Completed** |
| 002e | Add streaming config flags | **Completed** |
| 003 | Execute analysis recommendations | **Completed** |
| 004 | Redesign interactive mode interface | **Completed** |
| 004a | Create TUI core library | **Completed** |
| 004b | Implement checkbox component | **Completed** |
| 004c | Implement multistate toggle | **Completed** |
| 004d | Implement input components | **Completed** |
| 004e | Build menu navigation system | **Completed** |
| 004f | Integrate TUI into issue-splitter | **Completed** |
| 005 | Migrate TUI library to shared libs | **Completed** |
| 006 | Rename analysis sections for promoted roots | **Completed** |
| 007 | Add auto-implement via Claude CLI | **Completed** |
| 010 | Debug TUI integration analysis | Pending |
| 011 | TUI history insert on run | Pending |
| 012 | Interactive verdict review mode | Pending |
| 013 | Quest & bounty template system | **Completed** |
| 014 | Guild hero & shop system | **Completed** |
| 015 | WoW-style combat system | Pending |
| 016 | Attribute getter/setter system | In Progress |
| 016a | Core attribute registry | **Completed** |
| 016b | Dispatch table getters | Pending |
| 016c | Dispatch table setters | Pending |
| 016d | Modifier stack system | Pending |
| 016e | Derived attribute engine | Pending |
| 016f | WC3 attribute config | Pending |
| 016g | WoW attribute config | Pending |
| 016h | Cross-system mapping | Pending |
| 016i | Integration tests | Pending |

### Phase 8 Issues (Infrastructure Libraries)

> Issues maintained externally at: `/home/ritz/programming/ai-stuff/my-libs/issues/`

| Issue | Description | Status |
|-------|-------------|--------|
| 800 | Threadpool library extraction | In Progress |
| 800a | Core threadpool module | **Completed** |
| 800b | Sync module (watch list) | Pending |
| 800c | Updater module (self-evaluating) | Pending |
| 800d | Threadpool test suite | Pending |
| 800e | Render system migration | Pending |
| 800f | Windows support planning | Pending |

### Phase 1 Issues (File Format Parsing) - **COMPLETED**

| Issue | Description | Status |
|-------|-------------|--------|
| 101 | Research WC3 file formats | **Completed** |
| 102 | Implement MPQ archive parser | **Completed** |
| 102a | Parse MPQ header structure | **Completed** |
| 102b | Parse MPQ hash table | **Completed** |
| 102c | Parse MPQ block table | **Completed** |
| 102d | Implement file extraction | **Completed** |
| 103 | Parse war3map.w3i (map info) | **Completed** |
| 104 | Parse war3map.wts (trigger strings) | **Completed** |
| 105 | Parse war3map.w3e (terrain) | **Completed** |
| 106 | Design internal data structures | **Completed** |
| 107 | Build CLI metadata dump tool | **Completed** |
| 108 | Phase 1 integration test | **Completed** |
| 110 | Object data parsers (w3u/w3a/w3t/etc.) | **Completed** |
| 111 | Cross-reference validation | **Completed** |

### Phase 2 Issues (Data Model - Game Objects)

| Issue | Description | Status |
|-------|-------------|--------|
| 201 | Parse war3map.doo (doodads/trees) | **Completed** |
| 202 | Parse war3mapUnits.doo (units/buildings) | **Completed** |
| 202a | Parse unitsdoo header and basic fields | **Completed** |
| 202b | Parse unitsdoo item drops | **Completed** |
| 202c | Parse unitsdoo abilities | **Completed** |
| 202d | Parse unitsdoo hero data | **Completed** |
| 202e | Parse unitsdoo random/waygate | **Completed** |
| 203 | Parse war3map.w3r (regions) | **Completed** |
| 204 | Parse war3map.w3c (cameras) | **Completed** |
| 205 | Parse war3map.w3s (sounds) | **Completed** |
| 206 | Design game object types | **Completed** |
| 206a | Create gameobjects module structure | **Completed** |
| 206b | Implement Doodad class | **Completed** |
| 206c | Implement Unit class | **Completed** |
| 206d | Implement Region class | **Completed** |
| 206e | Implement Camera class | **Completed** |
| 206f | Implement Sound class | **Completed** |
| 206g | Finalize module and documentation | **Completed** |
| 207 | Build object registry system | In Progress |
| 207a | Core registry class | **Completed** |
| 207b | Filtering and iteration | **Completed** |
| 207c | Spatial index | **Completed** |
| 207d | Spatial integration | **Completed** |
| 207e | Map integration | **Completed** |
| 207f | Registry tests | Pending |
| 208 | Phase 2 integration test | Pending |

### Technical Documentation

| Document | Description | Status |
|----------|-------------|--------|
| mpq-archive.md | MPQ archive format with HM3W wrapper, encryption, compression | Created |
| w3i-map-info.md | Map info: metadata, players, forces, fog settings | Created |
| wts-trigger-strings.md | Trigger string table format and TRIGSTR resolution | Created |
| w3e-terrain.md | Terrain: tilepoints, height maps, textures, cliffs | Created |
| pkware-dcl-compression.md | PKWARE DCL compression algorithm | Created |
| unitsdoo.md | Unit/building placement format | Created |

### Guides

(To be added as development progresses)

- Getting Started
- Creating Asset Packs
- Writing Lua Scripts
- Contributing
