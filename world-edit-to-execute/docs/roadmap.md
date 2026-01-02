# World Edit to Execute - Roadmap

A phased approach to building a WC3-compatible game engine with visual independence.

---

## Current Focus

### Phase 4 Nearly Complete: 31/34 issues done

**Remaining:**
- **405d** - Movement collision integration
- **408a-c** - Integration test sub-issues

**Phase 5 Ready:** 55 issues created, design decisions made

### Recently Completed (2026-01-02)

**Issue 016: Attribute System** - Complete attribute getter/setter system with:
- Dispatch-based getters/setters with O(1) access
- Modifier stacks (flat, percent, multiplier)
- Derived attributes with formula-based calculation
- WC3 and WoW attribute configurations
- Cross-system mapping (WC3 ↔ WoW conversion)
- 352 passing tests across 8 test files

### Design Decisions Made (2025-12-29)

See `issues/CRITICAL-PATH.md` for full details:
- **Renderer:** Raylib
- **Coordinates:** WC3-style (Y-up, isometric)
- **Integration:** API-driven (shared data layer for WC3 + AzerothCore)

**Available Tools:**
```bash
# Interactive mode with TUI
./src/cli/issue-splitter.sh -I

# Auto-implement an issue
./src/cli/issue-splitter.sh -A -I

# Run Phase demos
./run-demo.sh
```

---

## Phase A: Infrastructure Tools (Shared Libraries)

Cross-project development tools that live in the shared scripts directory.
Designed to be project-abstract and usable as both CLI tools and libraries.

| Tool | Script | Description |
|------|--------|-------------|
| **Git History** | `git-history.sh` | Generate per-phase commit logs |
| **Progress Dashboard** | `progress-dashboard.lua` | Visualize issue completion status |
| **Test Runner** | `test-runner.sh` | Unified test execution and reporting |
| **Issue Validator** | `issue-validator.sh` | Validate issue file format |
| **TOC Updater** | `update-toc.lua` | Auto-generate documentation index |
| **Parser Coverage** | `parser-coverage.lua` | Map file compatibility matrix |

**Design Principles:**
- Location: `/home/ritz/programming/ai-stuff/scripts/`
- Symlinked into projects: `src/cli/<tool>`
- Usable as CLI tools OR sourceable/requireable libraries
- Project-abstract configuration

---

## Phase 0: Tooling/Infrastructure (23/32 Complete)

Development infrastructure and shared systems.

### Issue Splitter Tools

| Tool | Command | Description |
|------|---------|-------------|
| **Interactive Mode** | `-I` | TUI with checkbox selection, vim keybindings |
| **Streaming Mode** | `--stream` | Parallel processing with real-time output |
| **Execute Mode** | `-x` | Auto-create sub-issue files from analyses |
| **Implement Mode** | `-A` | Auto-implement issues via Claude CLI |
| **Review Mode** | `-r` | Review root issues with sub-issues |

### Attribute System (Issue 016) ✓ COMPLETE

```
src/libs/attributes/
├── schema.lua       # Attribute type definitions
├── registry.lua     # Central attribute registry
├── getters.lua      # O(1) dispatch-based access
├── setters.lua      # Validated modification with events
├── modifiers.lua    # Buff/equipment modifier stacking
├── derived.lua      # Formula-based stat calculation
├── mapping.lua      # WC3 ↔ WoW conversion
└── configs/
    ├── wc3.lua      # WC3 attributes (STR/AGI/INT, heroes)
    └── wow.lua      # WoW attributes (TBC-era, ratings)
```

**Sub-issues:** 016a-016i (9 complete)
**Tests:** 352 passing across 8 test files

### Currency System (Issue 017) ✓ COMPLETE

```
src/runtime/currency/
├── init.lua         # Currency registry
├── money_bag.lua    # Gold/lumber container
├── container.lua    # Generic currency container
├── reputation.lua   # Faction reputation
├── vendor.lua       # Transaction flows
└── conversion.lua   # WC3 ↔ WoW currency mapping
```

**Sub-issues:** 017a-017i (8 complete)

---

## Phase 1: Foundation - File Format Parsing ✓ COMPLETED

All 12 issues completed. Core parsing infrastructure established.

### Module Structure

```
src/
├── compat.lua           # Lua 5.1/LuaJIT ↔ Lua 5.3+ compatibility
├── mpq/                 # MPQ archive system
│   ├── init.lua         # Unified API: mpq.open(), archive:extract()
│   ├── header.lua       # Header parsing (HM3W wrapper support)
│   ├── hash.lua         # Hash algorithm and crypto table
│   ├── hashtable.lua    # File lookup
│   ├── blocktable.lua   # Block table parsing
│   ├── extract.lua      # File extraction (zlib)
│   └── pkware.lua       # PKWARE DCL decompression
├── parsers/
│   ├── w3i.lua          # Map info (name, players, forces, fog)
│   ├── wts.lua          # Trigger strings (TRIGSTR_xxx)
│   └── w3e.lua          # Terrain (tilepoints, heights, textures)
├── data/
│   └── init.lua         # Map class integrating all parsers
├── cli/
│   └── mapdump.lua      # CLI metadata dump tool
└── tests/
    ├── test_mpq.lua
    ├── test_w3i.lua
    ├── test_wts.lua
    ├── test_w3e.lua
    ├── test_data.lua
    └── phase1_test.lua
```

### Completed Issues

| ID | Name | Sub-Issues |
|----|------|------------|
| 101 | Research WC3 file formats | - |
| 102 | Implement MPQ archive parser | 102a-d (4) |
| 103 | Parse war3map.w3i (map info) | - |
| 104 | Parse war3map.wts (trigger strings) | - |
| 105 | Parse war3map.w3e (terrain) | - |
| 106 | Design internal data structures | - |
| 107 | Build CLI metadata dump tool | - |
| 108 | Phase 1 integration test | - |
| 109 | Implement PKWARE DCL decompression | - |

---

## Phase 2: Data Model - Game Objects ✓ COMPLETED

All 30 issues completed. Game object system fully implemented.

### Module Structure

```
src/
├── parsers/
│   ├── doo.lua          # Doodads/trees (DoodadTable class)
│   ├── unitsdoo.lua     # Units/buildings (UnitTable class)
│   ├── w3r.lua          # Regions (RegionTable class)
│   ├── w3c.lua          # Cameras (CameraTable class)
│   └── w3s.lua          # Sounds (SoundTable class)
├── gameobjects/
│   ├── init.lua         # Module documentation and exports
│   ├── doodad.lua       # Doodad class
│   ├── unit.lua         # Unit class (heroes, buildings, items)
│   ├── region.lua       # Region class
│   ├── camera.lua       # Camera class (eye position calculation)
│   └── sound.lua        # Sound class (3D audio, channels)
├── registry/
│   ├── init.lua         # ObjectRegistry class
│   └── spatial.lua      # SpatialIndex (grid-based queries)
└── tests/
    ├── test_doo.lua
    ├── test_unitsdoo.lua
    ├── test_w3r.lua
    ├── test_w3c.lua
    ├── test_w3s.lua
    ├── test_gameobjects.lua
    ├── test_registry.lua
    ├── test_spatial.lua
    ├── test_spatial_integration.lua
    └── test_phase2_integration.lua
```

### Completed Issues

| ID | Name | Sub-Issues |
|----|------|------------|
| 201 | Parse war3map.doo (doodads) | - |
| 202 | Parse war3mapUnits.doo (units) | 202a-e (5) |
| 203 | Parse war3map.w3r (regions) | - |
| 204 | Parse war3map.w3c (cameras) | - |
| 205 | Parse war3map.w3s (sounds) | - |
| 206 | Design game object types | 206a-g (7) |
| 207 | Build object registry system | 207a-f (6) |
| 208 | Phase 2 integration test | 208a-d (4) |

### Statistics
- 226,237 total objects parsed from 16 test maps
- 259 game object tests
- 190+ registry tests
- 41 integration tests

---

## Phase 3: Logic Layer - Triggers and JASS ✓ COMPLETED

All 36 issues completed. Full scripting and trigger system operational.

### Module Structure

```
src/
├── parsers/
│   ├── wtg.lua          # Trigger definitions (GUI triggers)
│   ├── wct.lua          # Custom text triggers
│   └── j.lua            # JASS script extraction
├── jass/
│   ├── lexer.lua        # JASS tokenization
│   ├── parser.lua       # JASS AST generation
│   └── transpiler.lua   # JASS-to-Lua transpilation
├── runtime/
│   ├── triggers/        # Trigger framework
│   │   ├── init.lua     # Trigger API
│   │   ├── handles.lua  # Handle management
│   │   └── context.lua  # Trigger context
│   └── events/          # Event dispatch
│       ├── init.lua     # Event registry
│       ├── timer.lua    # Timer events
│       ├── region.lua   # Region events
│       └── unit.lua     # Unit events
```

### Completed Issues

| ID | Name | Sub-Issues |
|----|------|------------|
| 301 | Parse war3map.wtg (trigger definitions) | 1 |
| 302 | Parse war3map.wct (custom text triggers) | - |
| 303 | Parse war3map.j (JASS script) | - |
| 304 | Build JASS lexer | 4 (304a-d) |
| 305 | Build JASS parser | 5 (305a-e) |
| 306 | Create JASS-to-Lua transpiler | 6 (306a-f) |
| 307 | Implement trigger framework | 4 (307a-d) |
| 308 | Build event dispatch system | 5 (308a-e) |
| 309 | Phase 3 integration test | 7 (309a-g) |

### Statistics
- 195 lexer tests, 305 parser tests
- 154 trigger tests, 181 event tests

### Sub-Issue Details

**304 - JASS Lexer (4 sub-issues):**
- 304a: Core infrastructure (token types, lexer state)
- 304b: Keywords, identifiers, operators
- 304c: Literals (strings, numbers, rawcodes)
- 304d: Tests and validation

**305 - JASS Parser (5 sub-issues):**
- 305a: Parser infrastructure (AST nodes, parser state)
- 305b: Parse declarations (globals, functions, types)
- 305c: Parse expressions
- 305d: Parse statements
- 305e: Parser tests

**306 - JASS-to-Lua Transpiler (6 sub-issues):**
- 306a: Transpiler infrastructure
- 306b: Transpile declarations
- 306c: Transpile statements
- 306d: Transpile expressions
- 306e: Native function handling
- 306f: Transpiler tests

**307 - Trigger Framework (4 sub-issues):**
- 307a: Trigger data structure
- 307b: Trigger lifecycle API
- 307c: Condition/action system
- 307d: Trigger context system

**309 - Integration Test (7 sub-issues):**
- 309a: Test trigger file parsing
- 309b: Test JASS lexer
- 309c: Test JASS parser
- 309d: Test transpiler
- 309e: Test trigger runtime
- 309f: Test event dispatch
- 309g: Phase demo

### Dependency Graph

```
301 wtg Parser ──▶ 302 wct Parser
                         │
303 j Extractor ✓ ───────┴──▶ 304 Lexer ──▶ 305 Parser ──▶ 306 Transpiler
                                                                 │
                                        307 Trigger Framework ◀──┘
                                                 │
                                        308 Event Dispatch
                                                 │
                                        309 Integration Test
```

---

## Phase 4: Runtime - Basic Engine Loop (31/34 Complete)

Core game execution environment. 8 root issues with 34 sub-issues total.

### Issue Breakdown

| ID | Name | Sub-Issues |
|----|------|------------|
| 401 | Implement game tick/update loop | 2 (401a-b) |
| 402 | Build entity component system | 6 (402a-f) |
| 403 | Implement basic pathfinding | 5 (403a-e) |
| 404 | Create unit movement system | 4 (404a-d) |
| 405 | Implement basic collision detection | 5 (405a-e) |
| 406 | Build resource management system | 3 (406a-c) |
| 407 | Create player state management | 6 (407a-f) |
| 408 | Phase 4 integration test | 5 (408a-e) |

### Sub-Issue Details

**401 - Game Loop (2 sub-issues):**
- 401a: Core fixed-timestep loop (62.5 ticks/sec)
- 401b: Timer subsystem

**402 - Entity Component System (6 sub-issues):**
- 402a: Entity manager
- 402b: Component registry
- 402c: Component queries
- 402d: System registration
- 402e: Core WC3 components
- 402f: Entity handles (optional)

**403 - Pathfinding (5 sub-issues):**
- 403a: Build pathing grid
- 403b: Implement A* algorithm
- 403c: Coordinate conversion
- 403d: Movement type support
- 403e: Path smoothing

**404 - Unit Movement (4 sub-issues):**
- 404a: Core movement system
- 404b: Path following logic
- 404c: Movement orders
- 404d: Advanced movement behaviors

**405 - Collision Detection (5 sub-issues):**
- 405a: Collision primitives and shapes
- 405b: Spatial hash grid
- 405c: Collision queries
- 405d: Movement collision integration
- 405e: Projectile and picking

**406 - Resource Management (3 sub-issues):**
- 406a: Core resource storage
- 406b: Spending validation
- 406c: Food and harvesting

**407 - Player State (6 sub-issues):**
- 407a: Player data structure
- 407b: Player queries
- 407c: Alliance management
- 407d: Player state transitions
- 407e: Victory conditions
- 407f: Local player support

**408 - Integration Test (5 sub-issues):**
- 408a: Unit tests - core systems
- 408b: Unit tests - entity systems
- 408c: Unit tests - player systems
- 408d: Integration scenario
- 408e: Visual demo

### Dependency Graph

```
401 Game Loop ──▶ 402 ECS ──┬──▶ 403 Pathfinding ──▶ 404 Movement ──▶ 405 Collision
                            │
                            └──▶ 407 Player State ──▶ 406 Resources
                                         │
                                         └──▶ 408 Integration Test
```

---

## Phase 5: Rendering - Visual Abstraction (Issues Created)

49+ issues created. Design decisions made (see CRITICAL-PATH.md).

**Architecture:** See `docs/render-architecture.md` for:
- Threading model (Updater → Workers → Sync → Draw)
- ComponentSlot with mise en place setters (swap + free old in one motion)
- Directional bitfield numeric encoding (no division, no zero)
- Memory ownership (workers create/clean, render reads only)

### Issue Breakdown

| ID | Name | Sub-Issues | Status |
|----|------|------------|--------|
| 500 | Dual interface rendering considerations | - | Design doc |
| 501 | Create abstract render interface | 5 (501a-e) | 501a complete |
| 502 | Implement terrain rendering | 5 (502a-e) | Created |
| 503 | Build sprite/placeholder system | 5 (503a-e) | Created |
| 504 | Create asset pack specification | - | Planned |
| 505 | Implement default visual mode | 6 (505a-f) | Created |
| 506 | Build UI framework | 6 (506a-f) | Created |
| 507 | Create minimap renderer | 6 (507a-f) | Created |
| **508** | **Vertical slice testing room** | **8 (508a-h)** | **Priority** |
| 510 | Dual perspective UI system | 5 (510a-e) | Created |

### Priority Path: 508 Vertical Slice

Fast-track to playable demo:
1. **508a** Threading infrastructure (C worker pool, sync thread)
2. **508b** Entity render slots (ComponentSlot, mise en place pattern)
3. **508c** Lua-C bridge (ECS ↔ render connection)
4. **508d** Map integration (terrain grid, doodads, units)
5. **508e** Input and selection (click, drag, Shift+click)
6. **508f** Movement orders (right-click to move)
7. **508g** Minimal UI (resources, selection panel)
8. **508h** Integration test (complete vertical slice)

This validates the architecture before completing 501-507 infrastructure.
A working demo proves the system; refinement comes after

### Key Decisions (OQ-001 through OQ-004)

- **Renderer:** Raylib (simple, modern, Lua bindings)
- **Coordinates:** WC3-style (Y-up, isometric projection)
- **Integration:** API-driven (shared data layer for WC3 visuals + AzerothCore)

### Dual Perspective UI (Issue 510)

```
WARLORD MODE (RTS)              HERO MODE (RPG)
┌─────────────────┐             ┌─────────────────┐
│ Command armies  │◀──F5 key──▶│ Control hero    │
│ Bird's eye view │             │ Third-person    │
│ QWER hotkeys    │             │ WASD movement   │
│ Click-select    │             │ Action bars 1-0 │
└─────────────────┘             └─────────────────┘
```

Same character, different experience:
- Thrall the Warchief (commanding the Horde)
- Thrall the Shaman (throwing lightning)

---

## Phase 6: Asset System - Community Content

Enable community visual packs and modding.

- Define asset pack manifest format
- Build asset resolution system (pack priority)
- Create default community asset pack structure
- Implement hot-reload for asset changes
- Build asset pack validator
- Create asset pack documentation/templates

---

## Phase 7: Gameplay - Core Mechanics (Issues Created)

7 root issues created with dual WC3/WoW mode support.

### Issue Breakdown

| ID | Name | Sub-Issues | Status |
|----|------|------------|--------|
| 701 | Death and resurrection system | 5 (701a-e) | Created |
| 702 | Profession system | 7 (702a-g) | Created |
| 703 | Combat system | - | Planned |
| 704 | Ability system framework | - | Planned |
| 705 | Buff/debuff system | - | Planned |
| 706 | Build queue and training | - | Planned |
| 707 | Fog of war | - | Planned |

### Dual Mode Philosophy

Each system supports both WC3 and WoW paradigms:

| System | WC3 Mode | WoW Mode |
|--------|----------|----------|
| Death | Altar revival, corpse decay | Graveyard run, spirit healer |
| Professions | Ability-based (5 levels) | Skill 1-300, trainers |
| Combat | Attack/armor types | Stats/ratings |

### Death System (701)

```
[Living Unit] ──death──▶ [Corpse] ──decay──▶ ∅
      ▲                      │
      │                      │ soul
 resurrect                   ▼
      │              ┌─────────────┐
      └──────────────│ SPIRIT WORLD│
                     │   [Ghost]   │
                     └─────────────┘
```

### Profession System (702)

| Profession | Input | Output |
|------------|-------|--------|
| Mining | Nodes | Ore, gems |
| Herbalism | Plants | Herbs |
| Blacksmithing | Bars | Weapons, armor |
| Alchemy | Herbs | Potions |
| Engineering | Parts | Gadgets |

---

## Phase 8: Multiplayer - Network Layer

Add networked play capability.

- Define network protocol
- Implement deterministic simulation
- Build lobby/game creation system
- Create replay recording
- Implement reconnection handling

---

## Phase 9: Polish - Tools and UX

Developer and player experience improvements.

- In-game console for Lua commands
- Debug visualization modes
- Performance profiling tools
- Map browser/launcher UI
- Settings and configuration UI
- Documentation and tutorials

---

## Future Considerations

- Custom map format extensions
- WebAssembly port for browser play
- Mobile platform support
- Steam Workshop integration
- AI opponent framework
