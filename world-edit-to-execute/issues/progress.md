# Project Progress

## Current Phase: 5 - Rendering (Visual Abstraction)

**Status:** Ready to Begin (Phase 4 Complete)

---

## Phase Summary

| Phase | Name | Status | Issues |
|-------|------|--------|--------|
| 0 | Tooling/Infrastructure | In Progress | 24/32 |
| 1 | Foundation - File Format Parsing | **Completed** | 13/13 |
| 2 | Data Model - Game Objects | **Completed** | 30/30 |
| 3 | Logic Layer - Triggers and JASS | **Completed** | 36/36 |
| 4 | Runtime - Basic Engine Loop | **Completed** | 34/34 |
| 5 | Rendering - Visual Abstraction | Issues Created | 0/55 |
| 6 | Asset System - Community Content | Issues Created | 0/8 |
| 7 | Gameplay - Core Mechanics | In Progress | 1/7 |
| 8 | Infrastructure Libraries | In Progress | 1/7 |
| 9 | World Editor | Issues Created | 0/12 |
| 10 | Polish - Tools and UX | Planned | - |

---

## Phase A Issues (Infrastructure Tools)

> **NOTE:** Phase A issues have been moved to the **delta-version** project.
>
> These tools are project-abstract infrastructure utilities living in `/home/ritz/programming/ai-stuff/scripts/`
> and managed by the delta-version meta-project.
>
> **See:** `/mnt/mtwo/programming/ai-stuff/delta-version/issues/` for Phase A tracking.
>
> **Existing tools:**
> - A01 (git-history.sh) - Git history prettifier ✓
> - A02 (progress-dashboard.lua) - Progress dashboard ✓
> - A03 (run-tests.sh) - Unified test runner ✓
> - A04-A07 - Tracked in delta-version

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
| 012 | Interactive verdict review mode | **Completed** | 003, 004 |
| 013 | Quest & bounty template system | **Completed** | None |
| 014 | Guild hero & shop system | **Completed** | 013 |
| 015 | WoW-style combat system | Pending | 014 |
| 016 | Attribute getter/setter system | **Completed** | 015, 014 |
| 016a | Core attribute registry | **Completed** | None |
| 016b | Dispatch table getters | **Completed** | 016a |
| 016c | Dispatch table setters | **Completed** | 016a |
| 016d | Modifier stack system | **Completed** | 016a, 016b, 016c |
| 016e | Derived attribute engine | **Completed** | 016a |
| 016f | WC3 attribute config | **Completed** | 016a, 016e |
| 016g | WoW attribute config | **Completed** | 016a, 016e |
| 016h | Cross-system mapping | **Completed** | 016f, 016g |
| 016i | Integration tests | **Completed** | 016a-016h |
| 017 | Unified currency/resource system | **Completed** | None |
| 017a | Currency registry and dispatch | **Completed** | None |
| 017b | Money bag component | **Completed** | 017a |
| 017c | Currency container component | **Completed** | 017a |
| 017d | Reputation system | **Completed** | 017a |
| 017f | Vendor transaction flow | **Completed** | 017a, 017b |
| 017g | WC3-WoW conversion | **Completed** | 017a, 017b |
| 017i | Tests and integration | **Completed** | 017a-017g |

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
| 109 | Implement PKWARE DCL decompression | **Completed** | 102d |
| 110 | Object data parsers | **Completed** | 102 |
| 111 | Cross-reference validation | **Completed** | 110, 202, 201 |

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
| 206 | Design game object types | **Completed** | 201-205 |
| 206a | Create gameobjects module structure | **Completed** | None |
| 206b | Implement Doodad class | **Completed** | 206a, 201 |
| 206c | Implement Unit class | **Completed** | 206a, 202 |
| 206d | Implement Region class | **Completed** | 206a, 203 |
| 206e | Implement Camera class | **Completed** | 206a, 204 |
| 206f | Implement Sound class | **Completed** | 206a, 205 |
| 206g | Finalize module and documentation | **Completed** | 206b-f |
| 207 | Build object registry system | **Completed** | 206 |
| 207a | Core registry class | **Completed** | 206 |
| 207b | Filtering and iteration | **Completed** | 207a |
| 207c | Spatial index | **Completed** | None |
| 207d | Spatial integration | **Completed** | 207a, 207c |
| 207e | Map integration | **Completed** | 207a |
| 207f | Registry tests | **Completed** | 207a-207e |
| 208 | Phase 2 integration test | **Completed** | 201-207 |
| 208a | Parser integration tests | **Completed** | 201-205 |
| 208b | Gameobject creation tests | **Completed** | 206, 208a |
| 208c | Registry integration tests | **Completed** | 207, 208b |
| 208d | Phase 2 demo script | **Completed** | 208a-c |

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
| 301 | Parse war3map.wtg (trigger definitions) | **Completed** | 102 |
| 301a | Parse WTG header and categories | **Completed** | 102 |
| 301b | Parse WTG variables | **Completed** | 301a |
| 301c | Parse WTG trigger metadata | **Completed** | 301b |
| 301d | Parse WTG ECA functions | **Completed** | 301c |
| 301e | Parse WTG parameters | **Completed** | 301d |
| 302 | Parse war3map.wct (custom text triggers) | **Completed** | 102, 301 |
| 303 | Parse war3map.j (JASS script) | **Completed** | 102 |
| 304 | Build JASS lexer | **Completed** | 303 |
| 304a | Lexer core infrastructure | **Completed** | 303 |
| 304b | Lexer keywords/identifiers/operators | **Completed** | 304a |
| 304c | Lexer literals | **Completed** | 304a |
| 304d | Lexer tests and validation | **Completed** | 304a-c |
| 305 | Build JASS parser | **Completed** | 304 |
| 305a | Parser infrastructure | **Completed** | 304 |
| 305b | Parse declarations | **Completed** | 305a |
| 305c | Parse expressions | **Completed** | 305a |
| 305d | Parse statements | **Completed** | 305a, 305c |
| 305e | Parser tests | **Completed** | 305a-d |
| 306 | Create JASS-to-Lua transpiler | **Completed** | 305 |
| 306a | Transpiler infrastructure | **Completed** | 305 |
| 306b | Transpile declarations | **Completed** | 306a |
| 306c | Transpile statements | **Completed** | 306a, 306d |
| 306d | Transpile expressions | **Completed** | 306a |
| 306e | Native function handling | **Completed** | 306a |
| 306f | Transpiler tests | **Completed** | 306a-e |
| 307 | Implement trigger framework | **Completed** | 306 |
| 307a | Trigger data structures | **Completed** | 306 |
| 307b | Trigger lifecycle API | **Completed** | 307a |
| 307c | Condition action system | **Completed** | 307a |
| 307d | Trigger context system | **Completed** | 307b, 307c |
| 308 | Build event dispatch system | **Completed** | 307 |
| 308a | Event registry core | **Completed** | 307 |
| 308b | Timer events | **Completed** | 308a |
| 308c | Region events | **Completed** | 308a |
| 308d | Unit events | **Completed** | 308a |
| 308e | Player events | **Completed** | 308a |
| 309 | Phase 3 integration test | **Completed** | 301-308 |
| 309a | Test trigger file parsing | **Completed** | 301-303 |
| 309b | Test JASS lexer | **Completed** | 304 |
| 309c | Test JASS parser | **Completed** | 305 |
| 309d | Test transpiler | **Completed** | 306 |
| 309e | Test trigger runtime | **Completed** | 307 |
| 309f | Test event dispatch | **Completed** | 308 |
| 309g | Phase demo | **Completed** | 309a-f |

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
| 401 | Implement game tick/update loop | **Completed** | Phase 2, Phase 3 |
| 401a | Core fixed timestep loop | **Completed** | None |
| 401b | Timer subsystem | **Completed** | 401a |
| 402 | Build entity component system | **Completed** | 401 |
| 402a | Entity manager | **Completed** | 401a |
| 402b | Component registry | **Completed** | 402a |
| 402c | Component queries | **Completed** | 402a, 402b |
| 402d | System registration | **Completed** | 402a |
| 402e | Define core WC3 components | **Completed** | 402a-d |
| 403 | Implement basic pathfinding | **Completed** | 401, 402, 105 |
| 403a | Build pathing grid | **Completed** | 105 |
| 403b | Implement A* algorithm | **Completed** | None |
| 403c | Coordinate conversion | **Completed** | 403a |
| 403d | Movement type support | **Completed** | 403a, 403b |
| 403e | Path smoothing | **Completed** | 403b |
| 404 | Create unit movement system | **Completed** | 401, 402, 403 |
| 404a | Core movement system | **Completed** | 401, 402 |
| 404b | Path following logic | **Completed** | 404a, 403 |
| 404c | Movement orders | **Completed** | 404b, 403 |
| 404d | Advanced movement behaviors | **Completed** | 404b, 404c |
| 405 | Implement basic collision detection | **Completed** | 401, 402, 404 |
| 405a | Collision primitives and shapes | **Completed** | None |
| 405b | Spatial hash grid | **Completed** | 405a |
| 405c | Collision queries | **Completed** | 405a, 405b |
| 405d | Movement collision integration | **Completed** | 404 |
| 405e | Projectile and picking | **Completed** | 405a, 405b |
| 406 | Build resource management system | **Completed** | 401, 402, 407 |
| 406a | Core resource storage | **Completed** | None |
| 406b | Spending validation | **Completed** | 406a |
| 406c | Food and harvesting | **Completed** | 406a, 402 |
| 407 | Create player state management | **Completed** | 401, 402 |
| 407a | Player data structure | **Completed** | 103 (w3i) |
| 407b | Player queries | **Completed** | 407a |
| 407c | Alliance management | **Completed** | 407a |
| 407d | Player state transitions | **Completed** | 407a |
| 407e | Victory conditions | **Completed** | 407c, 407d |
| 407f | Local player support | **Completed** | 407a |
| 408 | Phase 4 integration test | **Completed** | 401-407 |
| 408a | Unit tests - core systems | **Completed** | 401, 402, 403 |
| 408b | Unit tests - entity systems | **Completed** | 408a |
| 408c | Unit tests - player systems | **Completed** | 408a |
| 408d | Integration scenario | **Completed** | 408a-c |
| 408e | Visual demo | **Completed** | 408a-d |
| 409 | Frame-based pathfinding storage | **Completed** | 403, render-architecture |

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

## Phase 5 Issues

**Architecture:** See `docs/render-architecture.md` for threading model and component slots.

**Priority Path:** Issue 508 (Vertical Slice) provides fast-track to playable demo.

| ID | Name | Status | Dependencies |
|----|------|--------|--------------|
| 500 | Dual interface rendering considerations | Issues Created | None |
| 501 | Create abstract render interface | Issues Created | Phase 4 |
| 501a | Define renderer interface | Pending | None |
| 501b | Create renderer registry | Pending | 501a |
| 501c | Implement null renderer | Pending | 501a |
| 501d | Implement camera system | Pending | 501a |
| 501e | Create render events | Pending | 501a |
| 502 | Implement terrain rendering | Issues Created | 501, 105 |
| 502a | Core terrain renderer | Pending | 501 |
| 502b | Height visualization | Pending | 502a |
| 502c | Water rendering | Pending | 502a |
| 502d | Fog of war integration | Pending | 502a |
| 502e | Terrain optimization | Pending | 502a |
| 503 | Build sprite/placeholder system | Issues Created | 501 |
| 503a | Core sprite system | Pending | 501 |
| 503b | Unit visual mappings | Pending | 503a |
| 503c | Team colors selection | Pending | 503a |
| 503d | Health bars indicators | Pending | 503a |
| 503e | Facing direction | Pending | 503a |
| 504 | Create asset pack specification | Planned | 501 |
| 505 | Implement default visual mode | Issues Created | 501, 502, 503 |
| 505a | Default renderer backend | Pending | 501 |
| 505b | Wire render systems | Pending | 505a |
| 505c | Game view camera | Pending | 505a |
| 505d | Minimal UI | Pending | 505a, 506 |
| 505e | Input commands | Pending | 505a |
| 505f | Debug overlays | Pending | 505a |
| 506 | Build UI framework | Issues Created | 501 |
| 506a | UI component system | Pending | 501 |
| 506b | Layout system | Pending | 506a |
| 506c | Input handling | Pending | 506a |
| 506d | Core UI elements | Pending | 506a-c |
| 506e | Command button grid | Pending | 506c, 506d |
| 506f | Tooltip system | Pending | 506a, 506c |
| 507 | Create minimap renderer | Issues Created | 501, 502, 506 |
| 507a | Minimap module | Pending | 501 |
| 507b | Terrain texture | Pending | 507a |
| 507c | Unit dots | Pending | 507a |
| 507d | Camera viewport | Pending | 507a |
| 507e | Minimap interaction | Pending | 507a |
| 507f | Ping system | Pending | 507a |
| **508** | **Vertical slice testing room** | **Priority** | 501a |
| 508a | Threading infrastructure | **Completed** | 501a |
| 508b | Entity render slots | **Completed** | 508a |
| 508c | Lua-C bridge | **Completed** | 508b |
| 508d | Map integration | **Completed** | 508c |
| 508e | Input and selection | **Completed** | 508d |
| 508f | Movement orders | **Completed** | 508e |
| 508g | Minimal UI | **Completed** | 508d |
| 508h | Integration test | **Completed** | 508a-g |
| 508i | Fix chunk ray picking | **Completed** | 508b |
| 509 | Player-customizable visual effects | Issues Created | 503 |
| 509a | Character appearance data model | Pending | None |
| 509b | Effect color parameter system | Pending | 509a |
| 509c | Viewport preference system | Pending | 509a |
| 509d | WoW-Chat profile integration | Pending | 509c |
| 509e | Render pipeline integration | Pending | 509a |
| 510 | Dual perspective UI system | Issues Created | 506 |
| 510a | Warlord mode UI (RTS) | Pending | 506 |
| 510b | Hero mode UI (RPG) | Pending | 506 |
| 510c | Perspective switching | Pending | 510a, 510b |
| 510d | Shared UI components | Pending | 506 |
| 510e | UI state persistence | Pending | 510a-d |
| **511** | **Render system profiler** | **Issue Created** | 508a |
| 511a | Core timing infrastructure | Pending | 508a |
| 511b | Thread-safe recording | Pending | 511a |
| 511c | Overlay rendering | Pending | 511a |
| 511d | History buffer and graphs | Pending | 511c |
| 511e | File export | Pending | 511a |
| **512** | **3D rotation frames** | **Issue Created** | 409 |
| 512a | Core 3D frame encoding | Pending | 409 |
| 512b | Render system integration | Pending | 512a |
| 512c | Dynamic precision scaling | Pending | 512a |
| 512d | Convergence detection | Pending | 512a |
| 512f | v2 threading migration | **Completed** | 508a |
| **513** | **Threading architecture demo** | **Completed** | 512f |

### Dependency Graph

```
501 Render Interface (Raylib)
 │
 ├──▶ 502 Terrain ──────────────┐
 │                              │
 ├──▶ 503 Sprites ──────────────┼──▶ 505 Default Visual Mode
 │                              │
 ├──▶ 504 Asset Pack Spec       │
 │                              │
 └──▶ 506 UI Framework ─────────┼──▶ 507 Minimap
           │                    │
           └──▶ 510 Dual Perspective UI
                ├── 510a Warlord (RTS)
                └── 510b Hero (RPG)
                                │
                                └──▶ Phase 6 (Asset System)
```

### Design Decisions Made (2025-12-29)

Recorded in CRITICAL-PATH.md:
- **OQ-001:** Renderer backend = **Raylib**
- **OQ-002:** Coordinate system = **WC3-style (Y-up, isometric)**
- **OQ-003/004:** Integration = **API-driven** (shared data layer for WC3 + AzerothCore)

---

## Phase 6 Issues (Asset System)

| ID | Name | Status | Dependencies |
|----|------|--------|--------------|
| 601 | Asset loader and resolution | Pending | Phase 1 (MPQ), Phase 5 (render) |
| 602 | Wire-frame fallback renderer | Pending | Phase 5, 601 |
| 603 | Server asset download protocol | Pending | 601, 604 |
| 604 | Asset deduplication system | Pending | 601 |
| 605 | Local storage manager | Pending | 604 |
| 606 | Hot-reload system | Pending | 601, Phase 5 |
| 607 | File server application | Pending | 603, 604 |
| 608 | Phase 6 integration test | Pending | 601-607 |

### Overview

Phase 6 enables community content distribution:
- **Asset Loading:** Unified loader for textures, models, audio, UI from maps/servers
- **Wire-frame Fallback:** Debug rendering when assets are missing
- **Download Protocol:** Custom protocol for on-connect asset transfer
- **Deduplication:** Hash-based storage to prevent duplicate downloads
- **Storage Manager:** User control over per-server/map asset storage
- **Hot-Reload:** Development feature for asset iteration
- **File Server:** Standalone application for hosts to distribute assets

### Design Decisions

- **Asset Source:** Maps (MPQ) and servers (directory-based), NOT overlay packs
- **Download:** Custom protocol, host-distributed (no centralized CDN)
- **Fallback:** Wire-frame/debug visuals, not placeholder textures
- **Hot-Reload:** Development-only feature

### Dependency Graph

```
601 Asset Loader ──┬──▶ 602 Wire-frame Fallback
                   │
                   └──▶ 604 Deduplication ──▶ 603 Download Protocol
                                          │
                                          └──▶ 607 File Server

                   └──▶ 605 Storage Manager

                   └──▶ 606 Hot-Reload

All ─────────────────────────────────────────▶ 608 Integration Test
```

---

## Phase 7 Issues

| ID | Name | Status | Dependencies |
|----|------|--------|--------------|
| 701 | Death and resurrection system | Issues Created | 402 (ECS) |
| 701a | Death state and events | Pending | 402 |
| 701b | Spirit world layer | Pending | 701a |
| 701c | Ghost form component | Pending | 701a |
| 701d | Resurrection mechanics | Pending | 701a |
| 701e | Corpse system | Pending | 701a |
| 702 | Profession system | In Progress | 402, 406 |
| 702a | Profession core component | **Completed** | 402 |
| 702b | Gathering professions | Pending | 702a |
| 702c | Crafting professions | Pending | 702a |
| 702d | Recipe system | Pending | 702a |
| 702e | WoW-mode configuration | Pending | 702a |
| 702f | WC3-mode configuration | Pending | 702a |
| 702g | Profession UI abstraction | Pending | 702a, 506 |

### Dependency Graph

```
701 Death System
 │
 ├──▶ 701a Death State ──▶ 701b Spirit World
 │                    └──▶ 701c Ghost Form
 │                    └──▶ 701d Resurrection
 │                    └──▶ 701e Corpses

702 Profession System
 │
 └──▶ 702a Core ──▶ 702b Gathering
              └──▶ 702c Crafting ──▶ 702d Recipes
              └──▶ 702e WoW Mode
              └──▶ 702f WC3 Mode
              └──▶ 702g UI (depends on 506)
```

### Design Philosophy

Both systems support dual WC3/WoW modes:
- **Death**: WC3 altar revival vs WoW graveyard run
- **Professions**: WC3 ability-based vs WoW skill 1-300

---

## Phase 8 Issues (Infrastructure Libraries)

> **Note:** Phase 8 issues are maintained externally at:
> `/home/ritz/programming/ai-stuff/my-libs/issues/`
>
> This allows the threadpool library to be self-contained and reusable across projects.

| ID | Name | Status | Location |
|----|------|--------|----------|
| 800 | Threadpool library extraction | In Progress | my-libs/issues/ |
| 800a | Core threadpool module | **Completed** | my-libs/issues/ |
| 800b | Sync module (watch list) | Pending | my-libs/issues/ |
| 800c | Updater module (self-evaluating) | Pending | my-libs/issues/ |
| 800d | Threadpool test suite | Pending | my-libs/issues/ |
| 800e | Render system migration | Pending | my-libs/issues/ |
| 800f | Windows support planning | Pending | my-libs/issues/ |

### Dependency Graph

```
800 Threadpool Library Extraction
 │
 └──▶ 800a Core Module ──▶ 800b Sync Module
                       └──▶ 800c Updater Module
                       └──▶ 800f Windows Planning
         │
         └──▶ 800d Test Suite ──▶ 800e Render Migration
```

### Design Philosophy

The threadpool library extracts the threading infrastructure from `src/render/threading.*`
into a reusable library at `/home/ritz/programming/ai-stuff/my-libs/threadpool/`.

Key features:
- **Modular architecture:** Core pool, sync, and updater are independently usable
- **Self-evaluating updaters:** Helpers spawn/terminate based on measured load
- **Ring buffer task lists:** Efficient task queuing with automatic relocation
- **POSIX-only initially:** Windows support documented for future work

---

## Phase 9 Issues (World Editor)

| ID | Name | Status | Dependencies |
|----|------|--------|--------------|
| 901 | Editor core framework | Pending | Phase 5, Phase 6 |
| 902 | Terrain editor | Pending | 901, 105 |
| 903 | Object placer | Pending | 901, 110, Phase 2 |
| 904 | Region and camera editor | Pending | 901, 203-204 |
| 905 | Trigger editor | Pending | 901, Phase 3 |
| 906 | Object editor | Pending | 901, 110 |
| 907 | Sound editor | Pending | 901, 205 |
| 908 | Import manager | Pending | 901, Phase 6 |
| 909 | AI editor | Pending | 901, Phase 4 |
| 910 | Campaign editor | Pending | 901, 911 |
| 911 | Map format and export | Pending | 901, Phase 1 |
| 912 | Phase 9 integration test | Pending | 901-911 |

### Overview

Full-featured World Editor with feature parity to WC3 World Editor:
- **Terrain Editor:** Height, textures, cliffs, water, blight
- **Object Placer:** Units, doodads, items, destructibles
- **Region/Camera Editor:** Regions, camera presets
- **Trigger Editor:** GUI + Lua code with bidirectional sync
- **Object Editor:** Modify unit/ability/item stats
- **Sound Editor:** 3D sounds, music, ambience
- **Import Manager:** Custom assets
- **AI Editor:** Computer player behavior
- **Campaign Editor:** Multi-map storylines
- **Map Format:** Unified format exporting to both WC3 and enhanced formats

### Key Design Decisions

- **Trigger Editor:** Full GUI parity + Lua text editing with bidirectional conversion
- **Map Format:** Unified .wex format supporting both WC3 and WoW modes
- **Export:** Outputs to both standard WC3 (.w3x) and unified format
- **Import Manager:** Depends on Asset Browser (Phase 6B)

### Dependency Graph

```
901 Editor Core ──┬──▶ 902 Terrain
                  ├──▶ 903 Object Placer
                  ├──▶ 904 Regions/Cameras
                  ├──▶ 905 Trigger Editor
                  ├──▶ 906 Object Editor
                  ├──▶ 907 Sound Editor
                  ├──▶ 908 Import Manager ──▶ (Phase 6B)
                  ├──▶ 909 AI Editor
                  ├──▶ 910 Campaign Editor ──▶ 911 Map Format
                  └──▶ 911 Map Format

All ──────────────────────────────────────▶ 912 Integration Test
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
  - **[2025-12-27] DEPRECATED:** `--continue` shares context system-wide, not per-process
    - Causes cross-contamination with user's other Claude Code sessions
    - Issue 012 created to remove all `--continue` usage
    - See: issues/012-remove-context-continuation.md (scripts project)
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
- **Issue 206e completed:** Implement Camera class
  - Updated src/gameobjects/camera.lua with full implementation
  - Eye position calculation using spherical coordinates (WC3 camera math)
  - Methods: get_eye_position(), get_target_position(), get_look_direction()
  - Utility: get_fov_radians(), has_local_rotations() for 1.31+ detection
  - 14 new Camera tests added to test_gameobjects.lua
  - 197/197 tests pass
- **Issue 206f completed:** Implement Sound class
  - src/gameobjects/sound.lua with full implementation
  - Flag accessors: is_looping(), is_3d(), is_music(), stops_out_of_range()
  - Volume/pitch: get_effective_volume(), get_effective_pitch() (handles -1 defaults)
  - 3D audio: get_min_distance(), get_max_distance(), get_cutoff_distance(), has_cone()
  - Fade rates: get_fade_in(), get_fade_out()
  - Channel: get_channel() returns number and name
  - Supports both table and numeric (legacy bitmask) flag formats
  - 22 Sound tests added to test_gameobjects.lua
  - 259/259 tests pass
- **Issue 206g completed:** Finalize module and documentation
  - Enhanced init.lua with comprehensive module documentation
  - Verified all 5 classes use consistent metatable pattern
  - Verified all classes have __tostring metamethod
  - Updated docs/table-of-contents.md with full src/ tree structure
  - Added gameobjects module, parsers, registry, and data modules to docs
  - Updated Phase 2 issue status list (all 206 sub-issues complete)
  - 259/259 tests pass
- **Issue 206 completed:** Design game object types (all sub-issues done)
- **Issue 207f completed:** Registry tests
  - Verified all existing tests cover 207 acceptance criteria
  - test_registry.lua: 71 tests (core ObjectRegistry)
  - test_spatial.lua: 75 tests (SpatialIndex)
  - test_spatial_integration.lua: 31 tests (registry-spatial integration)
  - test_data.lua: Map integration tests (16 maps pass)
  - Total: 190+ test assertions covering all registry functionality
  - Edge cases: empty registry, duplicate IDs, negative coords, cell boundaries
- **Issue 207 completed:** Build object registry system (all sub-issues done)
- **Issue 208a completed:** Parser integration tests
  - Created src/tests/test_phase2_integration.lua with 41 tests
  - All 5 parsers load from 16 test maps (226,232 doodads, 5 units)
  - Includes performance benchmarks (load < 0.3s, queries < 0.01s)
- **Issue 208d completed:** Phase 2 demo script
  - Demo script at issues/completed/demos/phase2_demo.lua
  - Bash runner at issues/completed/demos/run_phase2.sh
  - Updated run-demo.sh with Phase 2 option (COMPLETED_PHASES=2)
  - Both interactive and non-interactive modes work
  - 16/16 maps load, 226,237 total objects displayed
- **Issue 208b completed:** Gameobject creation tests
  - Created src/tests/test_208b_gameobject_creation.lua
  - Tests all 5 game object types (Doodad, Unit, Region, Camera, Sound)
  - Parser-like data structure validation and method testing
  - Real map data integration (22,133 doodads created from test map)
  - 66,492/66,492 assertions pass
- **Issue 208c completed:** Registry integration tests
  - Created src/tests/test_208c_registry_integration.lua
  - Tests complete registry workflow: population, lookup, filtering, spatial queries
  - Cross-reference validation (waygate→region, region→sound)
  - Real map integration with Map.load()
  - 69/69 assertions pass
  - Note: Unit is_building() heuristic has false positives (hfoo matches farm pattern)
- **Phase 2 Complete!** All 30 issues completed and moved to issues/completed/
  - Moved root issues 206, 207, 208 to completed directory
  - Updated acceptance criteria on all root issues
  - Added implementation notes summarizing work done
  - Phase 2 demo available via `./run-demo.sh 2`
- **Issue 303 completed:** Parse war3map.j (JASS script)
  - Created src/parsers/j.lua (JASS script extractor/analyzer)
  - Created src/tests/test_j.lua (64 tests, all pass)
  - Extracts JASS text, identifies sections (globals, functions)
  - Validates structure (balanced blocks, entry points)
  - Note: Test maps lack war3map.j (minimal maps) - used synthetic data
  - Key finding: Lua `%w` doesn't match underscores, use `[%w_]+` for JASS identifiers
- **Issue 301 completed:** Parse war3map.wtg (trigger definitions)
  - Created src/parsers/wtg.lua (1148 lines, full WTG parser)
  - Created 5 test files with 59 total tests, all pass:
    - test_wtg_header.lua (11 tests): header, categories
    - test_wtg_variables.lua (9 tests): variable definitions
    - test_wtg_triggers.lua (9 tests): trigger metadata
    - test_wtg_eca.lua (13 tests): ECA function trees
    - test_wtg_params.lua (17 tests): parameter parsing
  - Parses: header, categories, variables, triggers, ECA trees, parameters
  - Two-pass parsing: metadata-only (fast) or full ECA parsing
  - Helper functions: format_parameter(), validate_parameter()
  - Constants exported: ECA_TYPE, PARAM_TYPE, CATEGORY_TYPE, VARIABLE_TYPES
  - Note: All 16 test maps are protected (no war3map.wtg) - used synthetic data
  - Sub-issues 301a-301e all completed
- **Issue 302 completed:** Parse war3map.wct (custom text triggers)
  - Created src/parsers/wct.lua (~270 lines, WCT parser)
  - Created src/tests/test_wct.lua (17 tests, all pass)
  - Parses: version (0=RoC, 1=TFT), header comment, per-trigger custom text
  - Uses length-prefixed strings (NOT null-terminated)
  - Provides merge_with_wtg() to associate custom JASS with wtg triggers
  - Helper functions: get_custom_trigger_count(), format()
  - Note: All 16 test maps are protected (no war3map.wct) - used synthetic data
- **Issue 304c completed:** Lexer literals
  - Added ~210 lines to src/jass/lexer.lua
  - Created src/tests/test_lexer_literals.lua (53 tests)
  - Integer literals: decimal, hex (0x and $), octal
  - Real literals: standard (1.5), leading dot (.5), trailing dot (1.)
  - String literals with escape sequences (\n, \r, \t, \\, \")
  - Rawcode literals ('hfoo') - exactly 4 characters
  - is_hex_digit helper exported for reuse
  - All 137 lexer tests pass (28 core + 56 keywords + 53 literals)
- **Issue 304d completed:** Lexer tests and validation
  - Created src/tests/test_jass_lexer.lua (58 tests)
  - Created src/tests/fixtures/jass/ with 6 fixture files:
    - keywords.j, operators.j, literals.j, comments.j, edge_cases.j, real_script.j
  - Edge case tests, error message tests, position tracking tests
  - Integration tests with real JASS patterns
  - Performance tests (50k lines in 1.3s, well under 5s threshold)
  - All 195 lexer tests pass (58 comprehensive + 28 core + 56 keywords + 53 literals)
- **Issue 304 completed:** Build JASS lexer (all sub-issues done)
- **Issue 401a completed:** Core fixed timestep loop
  - Created src/runtime/gameloop.lua (~250 lines)
  - Created src/tests/test_gameloop.lua (69 tests, all pass)
  - 62.5 Hz tick rate (16ms), accumulator pattern
  - Functions: tick(), update(dt), pause/resume, set_speed, tick callbacks
- **Issue 401b completed:** Timer subsystem
  - Created src/runtime/timers.lua (~350 lines)
  - Created src/tests/test_timers.lua (73 tests, all pass)
  - Min-heap priority queue for O(log n) operations
  - WC3-compatible API: CreateTimer, TimerStart, Pause/Resume, Get queries
- **Issue 402a completed:** Entity manager (ECS core)
  - Created src/runtime/ecs/entity.lua (~180 lines)
  - Created src/runtime/ecs/init.lua (~45 lines)
  - Created src/tests/test_ecs_entity.lua (64 tests, all pass)
  - Entity creation/destruction with ID recycling (LIFO)
  - Lifecycle hooks for component integration
- **Issue 402b completed:** Component registry
  - Created src/runtime/ecs/component.lua (~240 lines)
  - Updated src/runtime/ecs/init.lua with component exports
  - Created src/tests/test_ecs_component.lua (99 tests, all pass)
  - Metatable inheritance for efficient defaults
  - Dual indexing for fast queries (by type and by entity)
  - Automatic cleanup on entity destruction via lifecycle hooks
- **Issue 305 completed:** Build JASS parser (all sub-issues done)
  - 305a: Parser infrastructure - tokenization wrapper, error recovery, AST builder
  - 305b: Parse declarations - type, globals, natives, functions
  - 305c: Parse expressions - literals, identifiers, binary/unary, function calls, array access
  - 305d: Parse statements - set, call, if/then/else, loop/exitwhen, return, local
  - 305e: Parser tests - unified test_parser.lua (57 tests), 305 total parser tests
  - Created src/jass/parser.lua (~800 lines, recursive descent parser)
  - Created src/jass/ast.lua (AST node types and constructor functions)
  - All parser tests pass: 57+56+19+64+109 = 305 tests
- **Issue 402c completed:** Component queries
  - Created src/runtime/ecs/query.lua (~270 lines)
  - Updated src/runtime/ecs/init.lua with 9 query exports
  - Created src/tests/test_ecs_query.lua (62 tests, all pass)
  - Iterator-based queries for memory efficiency
  - Multi-component queries with smallest-storage optimization
  - Filtering: with_value, with_predicate, without (exclusion)
- **Issue 402d completed:** System registration
  - Created src/runtime/ecs/system.lua (~294 lines)
  - Updated src/runtime/ecs/init.lua with 12 system exports
  - Created src/tests/test_ecs_system.lua (132 tests, all pass)
  - Priority-based execution (stable sort for same-priority)
  - Enable/disable individual systems or globally
  - Performance stats tracking (update_count, total_time, entity_count)
  - Total ECS tests: 357 (64 entity + 99 component + 62 query + 132 system)
- **Issue 402e completed:** Define core WC3 components
  - Created src/runtime/ecs/wc3_components.lua (~350 lines)
  - Created src/tests/test_wc3_components.lua (207 tests, all pass)
  - 14 components: position, stats, movement, owner, unit_type, selectable,
    abilities, buffs, hero, building, item, projectile, destructible, doodad
  - 7 helper functions: create_unit, create_hero, create_building, create_item,
    create_destructible, create_doodad, create_projectile
  - Total ECS + WC3 tests: 564
  - **402 ECS Complete!** All 5 sub-issues done
- **Issue 403a completed:** Build pathing grid
  - Created src/runtime/pathfinding/grid.lua (~300 lines)
  - Created src/runtime/pathfinding/init.lua (~50 lines)
  - Created src/tests/test_pathing_grid.lua (93 tests, all pass)
  - Converts w3e terrain data to pathing grid
  - Handles deep water, cliff edges, ramps, boundaries
  - Grid caching for performance
- **Issue 403b completed:** Implement A* algorithm
  - Created src/runtime/pathfinding/astar.lua (~300 lines)
  - Created src/tests/test_astar.lua (90 tests, all pass)
  - Priority queue (min-heap) for efficient open set operations
  - Three heuristics: Manhattan, Euclidean, Chebyshev
  - Optional diagonal movement with sqrt(2) cost
  - Custom can_pass callback for movement-type-specific logic
  - Performance: < 100ms for 128x128 grid with obstacles
- **Issue 403c completed:** Coordinate conversion
  - Created src/runtime/pathfinding/coords.lua (~270 lines)
  - Created src/tests/test_pathing_coords.lua (99 tests, all pass)
  - World-to-grid and grid-to-world conversion with tile center returns
  - Handles negative offsets (centered maps) correctly
  - Clamped conversion for finding nearest valid tile
  - Path conversion (path_to_world, path_to_grid)
  - Distance utilities (world, grid, tile conversion)
- **Issue 403d completed:** Movement type support
  - Created src/runtime/pathfinding/movement.lua (~300 lines)
  - Created src/tests/test_movement_types.lua (106 tests, all pass)
  - Six WC3 movement types: foot, horse, fly, float, hover, amphibious
  - Passability rules per type (flying bypasses all, ships need deep water, etc.)
  - make_can_pass() factory for A* integration
  - Custom type registration/unregistration
  - Added pathfinding.is_passable() and pathfinding.find_path_for_type()
- **Issue 403e completed:** Path smoothing
  - Created src/runtime/pathfinding/smooth.lua (~280 lines)
  - Created src/tests/test_path_smoothing.lua (64 tests, all pass)
  - Line-of-sight check using Bresenham's algorithm
  - Three smoothing methods: remove_collinear, smooth_path, smooth_greedy
  - Integrated into find_path_for_type() via smooth option
  - Total pathfinding tests: 452 (93 grid + 90 A* + 99 coords + 106 movement + 64 smoothing)
- **Issue 403 completed:** Implement basic pathfinding (all 5 sub-issues done)
- **Issue 306 in progress:** Create JASS-to-Lua transpiler
  - 306a: Transpiler infrastructure - context, emit, symbol tables - **COMPLETED**
  - 306b: Transpile declarations - globals, functions, natives - **COMPLETED**
  - 306c: Transpile statements - SET, CALL, IF, LOOP, EXITWHEN, RETURN - **COMPLETED**
  - 306d: Transpile expressions - literals, binary/unary, calls, arrays - **COMPLETED**
  - Created src/jass/transpiler.lua (~1200 lines)
  - Created src/tests/test_transpiler_stmt.lua (27 tests, all pass)
  - 306e: Native function handling - **COMPLETED**
    - BUILTIN_NATIVES list with ~170 common natives
    - load_natives() public API for common.j parsing
    - is_native() checks registry, map declarations, and builtins
    - Created src/tests/test_transpiler_native.lua (20 tests, all pass)
  - Remaining: 306f (transpiler tests)
- **Issue 307 completed:** Implement trigger framework (all sub-issues done)
  - 307a: Trigger data structures - Handle system, Trigger class
  - 307b: Trigger lifecycle - CreateTrigger, DestroyTrigger, Enable/Disable
  - 307c: Condition action system - TriggerAddCondition/Action, Evaluate, Execute
  - 307d: Trigger context system - Context stack, GetTriggeringTrigger, accessors
  - Created src/runtime/handles.lua (~120 lines)
  - Created src/runtime/triggers.lua (~180 lines)
  - Created src/runtime/context.lua (~130 lines)
  - 154 tests pass across 4 test files
- **Issue 308 completed:** Build event dispatch system (all 5 sub-issues done)
  - 308a: Event registry core - 30 EVENT constants, register/unregister/fire
  - 308b: Timer events - TriggerRegisterTimerEvent, CreateTimer, update_timers
  - 308c: Region events - enter/leave registration, GetEnteringUnit/GetLeavingUnit
  - 308d: Unit events - 13 fire hooks (death, damage, attack, spell, order, etc.)
  - 308e: Player events - chat filtering, alliance, SubString utility
  - Created src/runtime/events.lua (~700 lines)
  - 181 tests pass across 5 test files (308a-308e)
  - Complete WC3-compatible trigger→event binding system
- **Issue 407 in progress:** Create player state management
  - 407a: Player data structure - **COMPLETED**
    - Created src/runtime/player.lua (~350 lines)
    - Created src/tests/test_player.lua (39 tests, all pass)
    - PLAYER_TYPE, PLAYER_STATE, RACE constants
    - init_from_w3i() initializes from parsed w3i data
    - map_player_type(), map_race() for w3i value mapping
    - Teams assigned from force definitions
    - Neutral player (slot 15) always ensured
  - 407b: Player queries - **COMPLETED**
    - get_all(), get_active(), get_by_type(), get_by_team()
    - get_humans(), get_computers(), get_neutral()
    - iter() for player iteration
  - 407f: Local player support - **COMPLETED**
    - set_local(), get_local(), get_local_slot()
    - Foundation for UI/camera perspective
  - 407c: Alliance management - **COMPLETED**
    - ALLIANCE_FLAG constants (10 flags)
    - set_alliance(), get_alliance() for asymmetric alliances
    - set_mutual_alliance(), set_team_alliance() helpers
    - is_ally(), is_enemy(), has_vision(), can_control()
    - get_allies(), get_enemies() query functions
    - init_from_w3i applies force alliance flags
    - _on_alliance_changed event hook
    - 24 new tests (63 total player tests)
  - 407d: Player state transitions - **COMPLETED**
    - Event system (on, clear_events, fire_event)
    - set_state, defeat, set_victorious, leave functions
    - is_active, is_playing convenience functions
    - ECS integration hooks (_handle_defeated_units, _handle_left_units)
    - Victory condition hook (_check_victory_conditions)
    - 28 new tests (91 total player tests)
  - 407e: Victory conditions - **COMPLETED**
    - Game state tracking (started, ended, winning_team, end_reason)
    - check_victory_conditions() - team elimination detection
    - force_victory(), force_defeat(), defeat_team() for custom triggers
    - get_winning_players(), get_game_result() queries
    - game_over event with winner and reason
    - 21 new tests (112 total player tests)
  - **407 Complete!** All 6 sub-issues done
- **Issue 405a completed:** Collision primitives and shapes
  - Created src/runtime/collision/shapes.lua (~95 lines)
  - Created src/tests/test_collision_shapes.lua (99 tests)
  - Circle-circle, rect-rect, circle-rect, point-in-shape collision
  - Penetration depth and direction calculation
  - AABB overlap tests for broad-phase optimization
- **Issue 405b completed:** Spatial hash grid
  - Created src/runtime/collision/spatial.lua (~230 lines)
  - Created src/tests/test_spatial_hash.lua (61 tests)
  - O(1) broad-phase collision detection
  - Configurable cell size (default 256 world units)
  - Entity insertion, removal, movement tracking
  - get_nearby() and get_in_rect() queries
- **Issue 405c completed:** Collision queries
  - Created src/runtime/collision/init.lua (~820 lines)
  - Created src/tests/test_collision_queries.lua (50 tests)
  - query_radius(), query_rect(), query_point(), query_colliding()
  - Layer/mask filtering for collision groups
  - Priority sorting (units > buildings > projectiles)
  - ECS integration with position/collision components
- **Issue 405e completed:** Projectile hit detection and picking
  - Created src/tests/test_projectile_picking.lua (45 tests)
  - Projectile hit tracking for piercing projectiles
  - check_projectile_hit(), check_projectile_hits_all()
  - is_valid_target() with team/dead filtering
  - Entity picking: pick_at_point(), pick_in_rect(), pick_all_at_point()
  - Selection filtering (units/buildings selectable, projectiles not)
  - Total: 255 collision tests across 4 test files
- **Issue 404c completed:** Movement orders
  - Created src/runtime/orders/init.lua (~450 lines)
  - Created src/tests/test_orders.lua (74 tests)
  - orders.move(), orders.stop(), orders.hold() for movement commands
  - Order queuing for shift-click behavior
  - Order completion callbacks with success/failure detection
  - Order system runs after movement to detect completion
  - Lazy table initialization to prevent shared reference bugs
- **Issue 406a completed:** Core resource storage
  - Created src/runtime/resources.lua (~340 lines)
  - RESOURCE_TYPES: gold, lumber, food_used, food_cap
  - API: init_player, get, set, add, subtract, register_type
  - Event system: on, clear_events, resource_changed event
  - 37 tests pass
- **Issue 406b completed:** Spending validation
  - can_afford(player_id, cost) - validates affordability
  - spend(player_id, cost) - atomic spending (all-or-nothing)
  - refund(player_id, cost) - inverse of spend
  - Cost helpers: validate_cost, add_costs, multiply_cost
  - Food handled specially (spending increases food_used)
  - 25 new tests (62 total)
- **Issue 406c completed:** Food and harvesting
  - Food supply: add_food_supply, remove_food_supply
  - Food consumption: add_food_used, remove_food_used
  - Upkeep system: none (0-50), low (51-80), high (81+)
  - Harvesting: deposit_harvest with upkeep modifier for gold
  - Gold mine: deplete_gold_mine, get_mine_status (ECS integration)
  - Periodic income: set_income_rate, process_income
  - 27 new tests (89 total resource tests)
  - **406 Complete!** All 3 sub-issues done
- **Issue 404a completed:** Core movement system
  - Created src/runtime/systems/movement.lua (~300 lines)
  - SPEED constants (VERY_SLOW to MAX), PATHING_TYPE constants
  - Movement component with speed, path, turn_rate, interpolation fields
  - ECS system registration at priority 10
  - is_moving(), get_target(), get_effective_speed() queries
  - get_interpolated_position() for smooth rendering
  - 90 tests pass
- **Issue 404b completed:** Path following logic
  - Added update_facing() - rotates toward waypoint at turn_rate
  - Added update_movement() - moves along path, handles waypoint progression
  - Added movement.set_path() - sets path and target
  - Added distance helpers: distance_to_point, distance_to_next_waypoint, distance_to_target
  - Added time_to_destination() for ETA estimation
  - 49 tests in test_movement_path.lua, all pass
  - Total: 139 movement tests (90 core + 49 path)
- **Issue 404d completed:** Advanced movement behaviors
  - Created src/runtime/systems/avoidance.lua (~150 lines)
  - Created src/runtime/systems/formation.lua (~200 lines)
  - Created src/runtime/systems/prediction.lua (~200 lines)
  - Created src/tests/test_advanced_movement.lua (56 tests)
  - Local avoidance: separation-based steering for collision prevention
  - Formation movement: line, box, wedge, column formations
  - Movement prediction: predict_position, time_to_arrival, get_intercept_point
  - Added collision_radius to movement component defaults
  - Total: 269 movement tests (90 core + 49 path + 74 orders + 56 advanced)
  - **404 Unit Movement Complete!** All 4 sub-issues done
- **Issue 013 completed:** Quest & Bounty Template System
  - Created docs/templates/ directory with 5 templates:
    - bounty-template.md (boss monster bounty board format)
    - quest-template.md (individual quest entry format)
    - quest-log-template.md (full quest log container)
    - guild-roster-template.md (progress tracking roster)
    - example-spec.lua (spec file for generator)
  - Created src/cli/quest-generator.lua (~550 lines):
    - bounty command: Generate boss monster bounty boards
    - quest command: Generate individual quest entries
    - from-spec command: Generate quest logs from Lua specs
    - scan command: Find TODOs/FIXMEs and suggest quest candidates
  - Existing gamified artifacts:
    - issues/Q00-adventurer-quest-log.md (8 quests in 4 tiers)
    - issues/B01-B03 (3 boss monster bounties)
    - issues/GUILD-ROSTER.md (capability tracking)
  - Pattern designed for cross-project replication
- **Issue 014 completed:** Guild Hero & Shop System
  - Created src/guild/ module with 4 files:
    - hero.lua: Hero class (stats, inventory, equipment, capabilities)
    - items.lua: Item system (types, rarity, effects, registry)
    - shop.lua: Shop system (stock, transactions, discounts)
    - init.lua: Module exports, JSON persistence
  - Created src/cli/guild-cli.lua CLI tool:
    - Hero management: create, status, switch, list
    - Quest/bounty completion with XP/gold rewards
    - Shop browsing and item purchases
    - Inventory and equipment management
  - WC3-inspired mechanics:
    - 25-level progression with XP thresholds
    - 6-slot inventory, 3 equipment slots
    - 15+ predefined items with programming themes
    - 4 shops: merchant, armory, arcane, guild hall
  - Issue 015 created for WoW-style combat system (pending)
- **Issue 408d completed:** Phase 4 integration scenario
  - Updated test_phase4_integration.lua with correct API detection
  - Fixed function names: check_victory_conditions, shapes_collide, init_manual
  - Fixed init_manual array format (uses ipairs, needs {slot = n})
  - Updated movement simulation to use ECS-based systems
  - 51 integration tests, all pass
  - Identified remaining gaps: 404c (order_move) - now completed
  - 405d collision update: **Completed** (see below)
- **Issue 016 created:** Attribute getter/setter system
  - Root issue with architecture overview (dispatch tables, array indexes, config blocks)
  - 9 sub-issues covering full attribute system:
    - 016a: Core attribute registry (schemas, types, constraints)
    - 016b: Dispatch table getters (O(1) lookup, modifier application)
    - 016c: Dispatch table setters (validation, events, transactions)
    - 016d: Modifier stack system (flat/percent/multiplier types, source tracking)
    - 016e: Derived attribute engine (dependency graphs, lazy evaluation)
    - 016f: WC3 attribute config (STR/AGI/INT, hero classes, formulas)
    - 016g: WoW attribute config (primary/secondary stats, ratings, classes)
    - 016h: Cross-system mapping (parallel attributes, conversion formulas)
    - 016i: Integration tests (comprehensive test suite)
  - Designed for system-agnostic library usage across WC3 and WoW contexts
  - Supports equipment, buffs, auras, talents, and other modifier sources
- **Issue 501a completed:** Raylib rotating cube demo
  - Created src/render/main.c with pthread thread-pool architecture
  - Separate draw() and game() threads with mutex-protected shared state
  - Blue cube with Y rotation and X wobble, ground grid, HUD overlay
  - Based on template at /home/ritz/programming/c/games/template/
  - Build script: src/render/run
- **Issue 011 completed:** TUI history insert on run
  - Added -P/--print-command flag to issue-splitter.sh
  - Config file support: ~/.config/issue-splitter/config
  - Optional clipboard copy via COPY_TO_CLIPBOARD variable
- **CRITICAL-PATH.md created:** Decision points and open questions tracking
  - 6 open questions (OQ-001 through OQ-006)
  - 5 technical debt items (TD-001 through TD-005)
  - 3 incomplete issue families tracked
  - Symlinked to docs/critical-path.md
- **Phase 5 design decisions recorded:**
  - OQ-001: Raylib as primary renderer
  - OQ-002: WC3-style coordinates (Y-up, isometric)
  - OQ-003/004: API-driven integration (shared data layer)
- **Issue 701 created:** Death and resurrection system
  - Spirit world model, ghost form, altar revival
  - WC3 and WoW mode support
- **Issue 702 created:** Profession system (702, 702a-702c)
  - Core profession component and skill system
  - Gathering professions (mining, herbalism, skinning, lumber, fishing)
  - Crafting professions (blacksmithing, alchemy, engineering, etc.)
  - 702d-702g pending creation
- **Issue 510 created:** Dual perspective UI system
  - 510a: Warlord mode UI (RTS) - command grid, multi-select, control groups
  - 510b: Hero mode UI (RPG) - action bars, character panel, WASD
  - 510c: Perspective switching - camera lerp, UI morph
  - 510d: Shared UI components - minimap, chat, tooltips, alerts
  - 510e: UI state persistence - save/load layouts, keybinds
- **508b extended with interactive demo:**
  - Added UI slider system (Clock, Spin, Orbit R controls)
  - Added chunk state tracking (per-chunk color_index, destroyed flag)
  - Added particle system for destruction sparks
  - Added mouse ray picking for chunk selection (partial - 508i bug)
  - Left-click cycles chunk color (blue → green → red)
  - Right-click destroys chunk with colored spark particles
  - Orbit radius slider updates ground circle in real-time
- **Issue 508i created:** Fix chunk ray picking
  - Picking works on some cube faces but not others
  - Root cause: transform_chunk_to_world() doesn't match OpenGL pipeline
  - Suggested fixes: use raylib Matrix functions, or inverse-transform the ray
- **Issue 409 created:** Frame-based pathfinding storage
  - Integrates frame encoding from render-architecture.md into A* pathfinding
  - Paths stored as direction frame sequences (1 byte/step vs 16+ bytes)
  - ~14x compression for path storage
  - Curve analysis: decompose paths into directional spectra
  - Metaphor: A* exploration = riding roller coaster through idea-space
  - Probing outward, hitting boundaries, reversing with dampened momentum
- **Issue 017 completed:** Unified currency/resource system
  - Created src/runtime/currency/ module with 6 files:
    - registry.lua: Currency schema, dispatch tables, standing thresholds
    - init.lua: Unified API (get/set/add/spend/can_afford)
    - money_bag.lua: Physical coin storage (copper/silver/gold in bag slots)
    - currency_container.lua: Abstract currencies (honor, arena, justice, valor)
    - reputation.lua: Faction standings (Hated to Exalted)
    - conversion.lua: WC3↔WoW currency bridge (1 WC3 gold = 100 WoW copper)
    - vendor.lua: Coin-based shop transactions
  - 94 tests pass covering all currency modules
  - Sub-issues: 017a (registry), 017b (money_bag), 017c (container),
    017d (reputation), 017f (vendor), 017g (conversion), 017i (tests)
  - Enables cross-play between WC3 and WoW economies
  - Classic/Vanilla WoW baseline with 8 standing tiers and 14 honor ranks
- **Issue 409 completed:** Frame-based pathfinding storage
  - Created src/runtime/pathfinding/frames.lua (~340 lines):
    - Cardinal frames: NORTH=0x0F, SOUTH=0xF0, EAST=0xCC, WEST=0x33
    - Ordinal frames: NE=0x4C, NW=0x1C, SE=0xC4, SW=0xC1
    - Boundary frames: ORIGIN=0xFF (arrived), OVERSHOOT=0x00 (reverse)
    - frame_to_vector, vector_to_frame, path_to_frames, frames_to_path
    - Momentum structure with direction + count separation
    - ASCII visualization (↑↓←→↗↖↘↙○×)
  - Updated src/runtime/pathfinding/astar.lua:
    - find_path_frames() returns frame path directly from A*
    - path_to_frames() / frames_to_path() wrappers
    - path_to_ascii() for visualization
    - compare_paths() similarity metric
  - Updated src/runtime/orders/init.lua:
    - orders.move_frames() for frame choreography movement
    - orders.get_path_shape() returns ASCII art of current movement
    - orders.shapes table with preset patterns (CIRCLE, ZIGZAG, RETREAT)
  - Created src/tests/test_frames.lua: 67 tests, all pass
  - Key concept: Frame paths describe movement SHAPE not coordinates
    (position-independent, enables pattern matching and gesture recognition)
- **Issue 509 created:** Player-customizable visual effects
  - Character appearance (hair, skin, tattoos, jewelry) influences spell effects
  - Per-player viewport customization (self vs others effect appearance)
  - WoW-Chat profile integration for preference synchronization
  - Sub-issues: 509a (appearance model), 509b (effect colors), 509c (viewport prefs),
    509d (WoW-Chat integration), 509e (render pipeline integration)
- **Issue 306 verified and moved to completed:**
  - All 6 sub-issues complete (306a-306f)
  - 226 transpiler tests passing
  - JASS-to-Lua transpilation fully functional
- **Issue 508f completed:** Movement orders
  - Right-click handler in input.c calls Lua on_move_order(x, z, entity_ids)
  - Move marker visualization: expanding green circle with crosshair, 1s fade
  - Lua movement system: stores targets in _G.entity_targets, interpolates positions
  - Increased MAX_SLOTS from 1024 to 4096 (maps load 2000+ doodads)
  - Key fix: Create demo entities BEFORE map loading to avoid slot exhaustion
  - Demo: 4 colored cubes (Red/Blue/Green/Yellow), left-click select, right-click move
- **Issue 508g completed:** Minimal UI
  - Created ui.h/ui.c with UIState struct and rendering functions
  - Resource bar at top: Gold (gold), Lumber (brown), Food (color-coded), Time (MM:SS)
  - Selection panel at bottom: Unit name, count, HP bar with color gradient
  - 5 Lua bridge functions: ui_set_resources, ui_set_selection, ui_set_game_time, etc.
  - Lua on_selection_changed() updates UI when selection changes
  - Demo entities have named stats (Red Warrior 100HP, Blue Mage 80HP, etc.)
- **Issue 508h completed:** Integration test (Vertical Slice Proof)
  - Verified all 508a-g components work together
  - Current demo serves as integration test (inline Lua script)
  - Map loading: DAoW-5.4b with 481x481 terrain, 4091 doodads
  - Demo entities: 4 colored cubes with names and HP stats
  - Selection, movement, UI all functional
  - Threading architecture validated: Updater → Workers → Sync → Draw
  - **Vertical slice complete!** Architecture proven, ready for incremental development
- **Issue 508i completed:** Fix chunk ray picking
  - Root cause: Manual Rodrigues rotation didn't match Raylib's matrix functions
  - Fix: Replaced manual rotation with Raylib's MatrixRotate, MatrixScale, etc.
  - Added raymath.h include for Matrix functions
  - Used exact axis normalization: 0.57735026919 instead of 0.577
  - Chunk clicking now works correctly at all rotation angles
  - **Issue 508 fully complete!** All 9 sub-issues done
- **Issue 511 created:** Render system profiler
  - High-resolution per-thread timing (Updater, Workers, Sync, Draw, Lua)
  - Thread-safe sample recording with TLS buffers
  - Visual overlay with bar graphs and statistics
  - Rolling 2-second history for spike detection
  - F3 toggle, F4 file export
  - Sub-issues: 511a (timing), 511b (recording), 511c (overlay), 511d (history), 511e (export)
- **Issue 110 completed:** Object data parsers (all 8 sub-issues complete)
  - Created src/parsers/objectdata.lua (core parser, ~400 lines)
  - Created 7 type-specific parsers:
    - src/parsers/w3u.lua (units)
    - src/parsers/w3a.lua (abilities, uses level/column)
    - src/parsers/w3t.lua (items)
    - src/parsers/w3b.lua (destructibles)
    - src/parsers/w3d.lua (doodads, uses level/column)
    - src/parsers/w3h.lua (buffs)
    - src/parsers/w3q.lua (upgrades, uses level/column)
  - Created src/parsers/objectdb.lua (unified lookup, O(1) by ID)
  - Integrated with Map class (object_data field, accessor methods)
  - 117 tests pass: 23 core + 50 type-specific + 31 ObjectDatabase + 13 real map
  - 43,435 objects validated across 16 real map files
  - All 7 file types parse correctly (w3u/w3a/w3t/w3b/w3d/w3h/w3q)
- **Issue 111 completed:** Cross-reference validation
  - Created src/validation/init.lua (~440 lines)
  - Created src/tests/test_validation.lua (32 tests)
  - Validates: unit placements, doodad placements, item drops, abilities, waygates, sounds
  - Type classification: detects misplaced object types (e.g., ability ID used for unit)
  - Distinguishes warnings (base game IDs) from errors (custom IDs)
  - Added Map:validate() method for convenient access
  - **Phase 1 Complete!** All 13 issues finished
- **Issue 016a completed:** Core attribute registry
  - Created src/libs/attributes/ module (schema.lua, registry.lua, init.lua)
  - AttributeSchema class: type validation, range constraints, flag accessors
  - AttributeRegistry: dual lookup (id/index), dependency graph, topological order
  - Bulk registration, container creation with defaults, filtered listing
  - Updated src/compat.lua with pure Lua 5.1/5.2 bitwise fallbacks
  - 55 tests pass (test_attributes.lua)
- **Issue 016b completed:** Dispatch table getters
  - Created src/libs/attributes/getters.lua (~300 lines)
  - GETTERS/GETTERS_RAW dispatch tables built from registry
  - Modifier application: (base + flat) * (1 + percent/100) * multiplier
  - Derived attribute computation with dirty flag caching
  - get(), get_raw(), get_base(), get_many(), get_all(), get_modifier_breakdown()
  - mark_dirty() for cache invalidation, rebuild() for dynamic registration
  - 44 tests pass (test_getters.lua) - 99 total attribute tests
- **Issue 702a completed:** Profession core component
  - Created src/runtime/systems/professions.lua (~830 lines)
  - Configuration modes: WoW (2 primary slots, 1-300 skill), WC3 (unlimited, 1-5 levels, XP-based)
  - Skill difficulty colors: orange (100%), yellow (75%), green (25%), gray (0%)
  - Query functions: get_skill, get_max_skill, has_profession, get_known_recipes
  - Modification: learn_profession, forget_profession, add_skill, learn_recipe
  - Progression: try_skillup with difficulty-based chance
  - XP-based leveling for WC3 mode with automatic level-ups
  - Key fix: ECS metatable inheritance causes shared table references; fixed with ensure_fresh_tables()
  - 42 tests pass (test_professions.lua)
- **Issue 016c completed:** Dispatch table setters
  - Created src/libs/attributes/setters.lua (~400 lines)
  - SETTERS dispatch table with validation, events, dependent invalidation
  - set() with schema validation, clamp option, silent mode
  - set_raw() for bypassing validation (loading saved data)
  - set_many() for batch updates with single event
  - adjust() for delta operations, reset() for defaults
  - Transaction support with commit/rollback
  - Built-in event system: attribute_changed, attributes_changed, attributes_reset
  - 49 tests pass (test_setters.lua) - 148 total attribute tests
- **Issue 016d completed:** Modifier stack system
  - Created src/libs/attributes/modifiers.lua (~650 lines)
  - MOD_TYPE constants: FLAT, PERCENT, MULTIPLIER, OVERRIDE
  - Modifier class with source tracking, stacking, duration, conditions
  - add() with stacking logic, remove operations (by source/category)
  - clean_expired() for duration-based auto-removal
  - Query functions: get, get_all (with filters), count, has, list_sources
  - get_breakdown() for detailed tooltip info
  - Application order: (base + flat) * (1 + percent/100) * multiplier
  - Integration with getters: modifiers auto-invalidate derived attributes
  - 48 tests pass (test_modifiers.lua) - 196 total attribute tests
- **Issue 016e completed:** Derived attribute engine
  - Created src/libs/attributes/derived.lua (~675 lines)
  - Centralized orchestration layer for derived attribute management
  - Dependency graph utilities: get_all_dependents, get_all_dependencies, get_evaluation_order
  - Circular dependency detection: detect_cycle, validate_no_cycles (DFS-based)
  - Cache management: is_dirty, mark_dirty, invalidate_all, recompute, recompute_all
  - Debug/introspection: explain, get_dependency_tree, format_dependency_tree (ASCII art)
  - Formula helpers: create_formula for "sum", "weighted_sum", "max", "min", "product" patterns
  - 42 tests pass (test_derived.lua) - 238 total attribute tests
- **Issue 016f completed:** WC3 attribute config
  - Created src/libs/attributes/configs/wc3.lua (~580 lines)
  - Complete WC3 attribute system: primary stats, resources, combat, 12 derived stats
  - WC3-accurate formulas: 25 HP/str, 15 mana/int, armor = agi/3, etc.
  - 14 hero classes (Paladin, Archmage, Blademaster, etc.) with stat gains
  - XP table for levels 1-25 with progress queries
  - apply_hero_class(), level_up(), calculate_stats_at_level() APIs
  - 42 tests pass (test_wc3_config.lua) - 280 total attribute tests

---

## Next Steps

### Phase 2 Complete!

All Phase 2 (Data Model - Game Objects) issues are now complete.

Capabilities established:
- 5 additional parsers: doo (doodads), unitsdoo (units), w3r (regions), w3c (cameras), w3s (sounds)
- 5 game object classes: Doodad, Unit, Region, Camera, Sound
- ObjectRegistry with spatial indexing for efficient queries
- Map.load() populates registry from all parser outputs
- 226,237 total objects parsed from 16 test maps
- 41 integration tests, 259 game object tests, 190+ registry tests

### Phase 3 - Logic Layer: Triggers and JASS

Phase 3 in progress (7/9 root issues complete):

1. **301 - Parse war3map.wtg** (trigger definitions) - **COMPLETED**
   - Full WTG parser with 5 test files (59 tests)
   - Parses header, categories, variables, triggers, ECAs, parameters
2. **302 - Parse war3map.wct** (custom text triggers) - **COMPLETED**
   - WCT parser with 17 tests, merge_with_wtg helper
3. **303 - Parse war3map.j** (JASS script extraction) - **COMPLETED**
4. **304 - Build JASS lexer** (tokenization) - **COMPLETED**
   - 304a-304d: All sub-issues complete
   - Total: 195 lexer tests pass
5. **305 - Build JASS parser** (AST generation) - **COMPLETED**
   - 305a-305e: All sub-issues complete
   - Total: 305 parser tests pass
6. **306 - Create JASS-to-Lua transpiler** - In Progress (306f remaining)
   - 306a-306e: All core sub-issues complete
7. **307 - Implement trigger framework** (conditions/actions) - **COMPLETED**
   - 307a-307d: All sub-issues complete
   - Total: 154 tests (handles, triggers, context)
8. **308 - Build event dispatch system** - **COMPLETED**
   - 308a-308e: All sub-issues complete
   - Total: 181 tests (registry, timer, region, unit, player events)
9. **309 - Phase 3 integration test** - Next up

### Phase 4 - Runtime: Basic Engine Loop

Phase 4 in progress (7/8 root issues complete, 403 starting):

1. **401 - Game tick/update loop** - **COMPLETED**
   - 401a: Core fixed timestep loop - **COMPLETED**
   - 401b: Timer subsystem - **COMPLETED**
2. **402 - Entity component system** - **COMPLETED**
   - 402a: Entity manager - **COMPLETED**
   - 402b: Component registry - **COMPLETED**
   - 402c: Component queries - **COMPLETED**
   - 402d: System registration - **COMPLETED**
   - 402e: Define core WC3 components - **COMPLETED**
   - Total: 564 tests (entity, component, query, system, wc3_components)
3. **403 - Basic pathfinding** - **COMPLETED**
   - 403a: Build pathing grid - **COMPLETED** (93 tests)
   - 403b: Implement A* algorithm - **COMPLETED** (90 tests)
   - 403c: Coordinate conversion - **COMPLETED** (99 tests)
   - 403d: Movement type support - **COMPLETED** (106 tests)
   - 403e: Path smoothing - **COMPLETED** (64 tests)
   - Total: 452 pathfinding tests
4. **406 - Resource management** - **COMPLETED**
   - 406a: Core resource storage - **COMPLETED** (37 tests)
   - 406b: Spending validation - **COMPLETED** (62 tests total)
   - 406c: Food and harvesting - **COMPLETED** (89 tests total)
5. **407 - Player state management** - **COMPLETED**
   - 407a: Player data structure - **COMPLETED** (39 tests)
   - 407b: Player queries - **COMPLETED**
   - 407f: Local player support - **COMPLETED**
   - 407c: Alliance management - **COMPLETED** (63 tests total)
   - 407d: Player state transitions - **COMPLETED** (91 tests total)
   - 407e: Victory conditions - **COMPLETED** (112 tests total)
6. **404 - Unit movement system** - **COMPLETED**
   - 404a: Core movement system - **COMPLETED** (90 tests)
   - 404b: Path following logic - **COMPLETED** (49 tests)
   - 404c: Movement orders - **COMPLETED** (74 tests)
   - 404d: Advanced movement behaviors - **COMPLETED** (56 tests)
   - Total: 269 movement tests
7. **405 - Collision detection** - **COMPLETED** (5/5 sub-issues complete)
   - 405a: Collision primitives and shapes - **COMPLETED** (99 tests)
   - 405b: Spatial hash grid - **COMPLETED** (61 tests)
   - 405c: Collision queries - **COMPLETED** (50 tests)
   - 405e: Projectile and picking - **COMPLETED** (45 tests)
   - 405d: Movement collision integration - **COMPLETED** (22 tests)
   - Total: 277 collision tests
8. **408** - Pending (integration tests)

### Previous Phases

**Phase 0 Complete** - Tooling/Infrastructure (streaming queue via `--stream` flag)
**Phase 1 Complete** - Foundation: MPQ parsing, w3i/wts/w3e parsers, Map data structure
