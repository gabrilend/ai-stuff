# World Edit to Execute - Roadmap

A phased approach to building a WC3-compatible game engine with visual independence.

---

## Current Focus

### Phase 3 In Progress: 1/9 complete (36 total with sub-issues)

**Completed:**
- ✓ **303** - Parse war3map.j (JASS script extraction)

**Next Priority Issues:**

1. **301 - Parse war3map.wtg** (trigger definitions)
   - GUI trigger structure, events, conditions, actions
   - 1 sub-issue: 301e (parameter parsing)

2. **302 - Parse war3map.wct** (custom text triggers)
   - Custom JASS code embedded in triggers

3. **304 - Build JASS lexer** (4 sub-issues)
   - Tokenization of JASS source code

**Available Tools:**
```bash
# Analyze issues with parallel processing
./src/cli/issue-splitter.sh --stream --parallel 3

# Auto-implement an issue
./src/cli/issue-splitter.sh -A -I

# Interactive mode with TUI
./src/cli/issue-splitter.sh -I

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

## Phase 0: Tooling/Infrastructure ✓ COMPLETED

All 18 issues completed. Development tools now available:

| Tool | Command | Description |
|------|---------|-------------|
| **Interactive Mode** | `-I` | TUI with checkbox selection, vim keybindings |
| **Streaming Mode** | `--stream` | Parallel processing with real-time output |
| **Execute Mode** | `-x` | Auto-create sub-issue files from analyses |
| **Implement Mode** | `-A` | Auto-implement issues via Claude CLI |
| **Review Mode** | `-r` | Review root issues with sub-issues |

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

## Phase 3: Logic Layer - Triggers and JASS (In Progress)

Implement the scripting and trigger system.

### Issue Breakdown

| ID | Name | Sub-Issues | Status |
|----|------|------------|--------|
| 301 | Parse war3map.wtg (trigger definitions) | 1 (301e) | Pending |
| 302 | Parse war3map.wct (custom text triggers) | - | Pending |
| 303 | Parse war3map.j (JASS script) | - | **Completed** |
| 304 | Build JASS lexer | 4 (304a-d) | Pending |
| 305 | Build JASS parser | 5 (305a-e) | Pending |
| 306 | Create JASS-to-Lua transpiler | 6 (306a-f) | Pending |
| 307 | Implement trigger framework | 4 (307a-d) | Pending |
| 308 | Build event dispatch system | - | Pending |
| 309 | Phase 3 integration test | 7 (309a-g) | Pending |

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

## Phase 4: Runtime - Basic Engine Loop (Issues Created)

Create the game execution environment. 8 root issues with 36 sub-issues.

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

## Phase 5: Rendering - Visual Abstraction

Build the rendering system with pluggable visuals.

- Create abstract render interface
- Implement terrain mesh generation from w3e data
- Build sprite/model placeholder system
- Create asset pack loader specification
- Implement default "wireframe/geometric" visual mode
- Build UI framework for game interface
- Create minimap renderer

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

## Phase 7: Gameplay - Core Mechanics

Implement essential WC3 gameplay systems.

- Unit stats and attributes
- Combat system (attack, damage, armor)
- Ability system framework
- Buff/debuff system
- Build queue and training
- Resource harvesting
- Fog of war

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
