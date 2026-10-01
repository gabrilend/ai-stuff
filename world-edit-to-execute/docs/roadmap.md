# World Edit to Execute - Roadmap

**Mission:** Build a modern game engine that executes Warcraft III custom maps (.w3x/.w3m) like an emulator reads ROMs - preserving the legacy of custom map creativity while replacing proprietary Blizzard assets with community-created alternatives.

---

## Current Focus

Live per-phase counts (instead of numbers written here that go stale):

```bash
lua /home/ritz/programming/ai-stuff/scripts/progress-dashboard.lua /mnt/mtwo/programming/ai-stuff/world-edit-to-execute -m
```

### Phase W: WoW Client Bridge (planned 2026-09-23)

A lettered side phase that uses the owner's WoW 3.3.5a client as an alternate
host for WC3 maps, a local model source, and a reference to test our engine
against, then replaces its models one at a time. It does not reorganise
phases 1-10. See the Phase W section below and `docs/wow-client-bridge.md`.

### Phase 5 (Rendering) in progress

The vertical slice (508), render profiler (511) and threading rewrite (512,
513) are done. The ceramic render path (515) is in progress: the game's
backend on the ceramic engine, C boxes building each frame's page, and raylib
drawing it on one thread. Reading and drawing real WC3 models is planned
(116, 117, 516). The January plan for a Lua renderer interface with terrain,
sprite, UI and minimap sub-issues (501-507) was replaced by the vertical
slice's split (C draws, Lua writes render slots); on 2026-09-26 eight of
those issues were retired (`issues/superseded/`) and the rest re-cut for the
page: terrain, unit overlays, camera, interface and minimap, each saying
what goes into the page and what the renderer draws.

### ⚡ Architectural Pivot (2026-01-07)

**Decision:** Abandoned AzerothCore integration in favor of pure WC3 engine.

**Reason:** Complexity misalignment with core preservation mission. See `docs/postmortem-azerothcore-integration.md` for full analysis.

**Path Forward:**
- **Pure WC3 Engine** - Direct .w3x execution, ROM emulator legal precedent
- **Community Assets** - Replace Blizzard IP with open alternatives
- **LAN Multiplayer** - No Battle.net dependency
- **Target:** First playable Tower Defense map in 6 months

**Architecture:** See `docs/wc3-engine-architecture.md` for complete design.

---

### Phase 4 Complete

All core runtime systems implemented:
- Game loop (62.5 ticks/sec)
- Entity Component System
- Pathfinding (A*, movement types)
- Unit movement and collision
- Resource management
- Player state and alliances

**Next:** Phase 5 (Rendering) - Build visual system with Raylib

---

### Recently Completed (2026-01-02)

**Issue 016: Attribute System** - Complete attribute getter/setter system with:
- Dispatch-based getters/setters with O(1) access
- Modifier stacks (flat, percent, multiplier)
- Derived attributes with formula-based calculation
- WC3 and WoW attribute configurations (WoW support for potential future use)
- Cross-system mapping (extensibility)
- 352 passing tests across 8 test files

---

### Design Decisions Made (2025-12-29)

See `issues/CRITICAL-PATH.md` for full details:
- **Renderer:** Raylib (simple, modern, cross-platform)
- **Coordinates:** WC3-style (Y-up, center origin)
- **Architecture:** Pure WC3 engine (standalone, no server dependency)

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

## Phase 0: Tooling/Infrastructure (In Progress)

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
├── mapping.lua      # Cross-system attribute mapping
└── configs/
    ├── wc3.lua      # WC3 attributes (STR/AGI/INT, heroes)
    └── wow.lua      # WoW attributes (extensibility demonstration)
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
└── conversion.lua   # Extensible currency mapping
```

**Sub-issues:** 017a-017i (8 complete)

---

## Phase 1: Foundation - File Format Parsing (In Progress)

The map file formats are read. Still open: the stock object tables and
their game-version layers (112, 112b, 112d, 112e), and the readers for WC3
models and textures (116, 117). Phase numbers group functionality rather
than mark time, so a foundation phase gaining new readers late is expected.

### Module Structure

```
src/
├── compat.lua           # Lua 5.1/LuaJIT ↔ Lua 5.3+ compatibility
├── mpq/                 # MPQ archives, read through StormLib since 114
│   ├── init.lua         # Unified API: mpq.open(), archive:extract()
│   ├── stormlib.lua     # LuaJIT binding to StormLib
│   ├── map_wrapper.lua  # The 512-byte HM3W header before a map
│   └── standard_names.lua # Names a map normally holds, for maps with no listfile
├── gamedata/            # Stock object tables by game version (112)
│   ├── chain.lua        # Which version's layers a map reads
│   ├── patch_layer.lua  # One patch's tables as a layer
│   ├── stock_rows.lua   # Route A: stock rows under a map's changed objects
│   └── route_b*.lua     # Route B: published values as a cross-check
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
| 110 | Object data parsers | 110a |
| 111 | Cross-reference validation | - |
| 112a, 112c | StormLib build script; Route A stock rows | (of 112) |
| 113 | Remaining MPQ compressions | - |
| 114 | Read maps through StormLib; the own MPQ reader retired | - |
| 115 | Balance history explorer | 115a-b |

### Open Issues

| ID | Name |
|----|------|
| 112 | Stock object tables, read two ways and cross-checked |
| 112b | Game-version layers, chosen per map |
| 112d | Older patch program shapes (1.01 to 1.20e) |
| 112e | Route B: published values as a cross-check |
| 116 | Read WC3 models (.mdx) |
| 117 | Read WC3 textures (BLP1, in the shared texture reader) |

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
│   ├── w3s.lua          # Sounds (SoundTable class)
│   ├── jpeg.lua         # JPEG, baseline and progressive (522)
│   ├── blp.lua          # BLP1 textures: JPEG and paletted (522)
│   ├── tga.lua          # TGA images (522)
│   ├── png.lua          # PNG images (522)
│   ├── mdx.lua          # MDX models, every chunk (522)
│   └── gltf.lua         # glTF/GLB models, in and out (522)
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
│   ├── transpiler.lua   # JASS-to-Lua transpilation
│   ├── vm.lua           # Runs a map's war3map.j: threads, waits, events, timers (520)
│   └── natives/         # common.j natives and our own Blizzard.j functions (520)
├── assets/              # Art: where it comes from and how it's drawn (522)
│   ├── init.lua         # The map's archive, then the install; which model a type uses
│   ├── gpu.lua          # MDX (and glTF) onto the renderer
│   ├── anim.lua         # Plays a model's sequences: nodes, matrix groups, part alphas (523)
│   ├── ground.lua       # Ground textures: tileset layers per cell, stand-in tilesets (526)
│   ├── tool.lua         # texture -> PNG, model -> GLB
│   └── comfy.lua        # ComfyUI workflows (comfyui/): write, check, export
├── ai/                  # Computer players (521)
│   ├── init.lua         # One AI per computer player: map-started, melee or filled in
│   ├── player.lua       # The mechanism: captains, counts, targets, fleeing, defending
│   ├── natives.lua      # The AI natives a map's .ai script runs on
│   ├── profile.lua      # The AI Editor's model (its tabs as a Lua table)
│   ├── editor_ai.lua    # Plays a profile
│   ├── melee.lua        # Default melee profiles per race
│   ├── faction.lua      # Profiles for custom-map factions; profile files
│   └── tool.lua         # luajit src/ai/tool.lua write MAP | check DIR
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

## Phase 4: Runtime - Basic Engine Loop ✓ COMPLETED

All 34 issues complete. Core game execution environment operational.

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

## Phase 5: Rendering - Visual Abstraction (In Progress)

Decisions and open questions: `issues/CRITICAL-PATH.md`. Counts: the
dashboard command under Current Focus.

**Architecture:** See `docs/render-architecture.md` and `docs/wc3-engine-architecture.md` for:
- Threading model (Updater → Workers → Sync → Draw)
- ComponentSlot with mise en place setters (swap + free old in one motion)
- Directional bitfield numeric encoding (no division, no zero)
- Memory ownership (workers create/clean, render reads only)
- Dual-camera system (WC3 tactical + optional 3D adventure view)

### Issue Breakdown

| ID | Name | Sub-Issues | Status |
|----|------|------------|--------|
| 500 | Dual interface rendering considerations | - | Archived 2026-01-08 (WoW mode) |
| 501 | The page's format (re-cut) | 501c, 501d kept; 501a, 501b, 501e retired | Re-cut 2026-09-26: the page format, a headless renderer, the camera model |
| 502 | Terrain rendering | 5 (502a-e) | Re-cut 2026-09-26: built once per map as chunk meshes; colour grid built (508), heights, water, fog, chunking open |
| 503 | Everything drawn for a unit besides its model | 5 (503a-e) | Re-cut 2026-09-26: shapes and team colour built (508); model paths from object data, health bars, facing open |
| 504 | The model-override file's format | - | Re-cut 2026-09-26 (was: asset pack specification) |
| 505 | Implement default visual mode | 505c, 505f kept; the rest retired | Retired 2026-09-26: built by 508 instead; camera controls (505c) and debug overlays (505f) re-cut |
| 506 | WC3's game interface | 6 (506a-f) | Re-cut 2026-09-26: interface elements as items on the page (question Q-4 confirms) |
| 507 | Minimap | 6 (507a-f) | Re-cut 2026-09-26: terrain picture made once, dots and view box per frame |
| 508 | Vertical slice testing room | 9 (508a-i) | **Completed** |
| 509 | Player-customizable visual effects | 5 planned (509a-e) | Open |
| 510 | Dual perspective camera system | 5 (510a-e) | Archived 2026-01-08 (WoW mode) |
| 511 | Render profiler | 5 (511a-e) | **Completed** |
| 512 | Threading architecture rewrite | 6 (512a-f) | **Completed** |
| 513 | Threading architecture demo | - | **Completed** |
| 514 | 3D rotation frames | 4 planned (514a-d) | Open |
| 515 | Render graph on the ceramic engine | 11 (515a-k) | In progress |
| 516 | Draw WC3 models in the engine | - | Open |

### Priority Path: 508 Vertical Slice (completed)

Fast-track to playable demo, all done (508i fixed ray picking on chunked
terrain):
1. **508a** Threading infrastructure (C worker pool, sync thread)
2. **508b** Entity render slots (ComponentSlot, mise en place pattern)
3. **508c** Lua-C bridge (ECS ↔ render connection)
4. **508d** Map integration (terrain grid, doodads, units)
5. **508e** Input and selection (click, drag, Shift+click)
6. **508f** Movement orders (right-click to move)
7. **508g** Minimal UI (resources, selection panel)
8. **508h** Integration test (complete vertical slice)

It validated the architecture, and its split (C draws, Lua writes render
slots) became the architecture; the 501-507 plan is what now has to be
re-cut to fit it.

### Key Decisions (OQ-001 through OQ-004)

- **Renderer:** Raylib (simple, modern, cross-platform)
- **Coordinates:** WC3-style (Y-up, center origin, 128 units/tile)
- **Architecture:** Pure standalone engine (no server dependency)

### Dual Perspective Camera (Issue 510, archived 2026-01-08)

Archived with the WoW-mode issues (`issues/archive/wow-mode-2026-01-08/`).
Kept here as the record of the idea:

```
WC3 TACTICAL MODE (RTS)        3D ADVENTURE MODE (Optional)
┌─────────────────┐             ┌─────────────────┐
│ Command armies  │◀──F5 key──▶│ Explore maps    │
│ Bird's eye view │             │ Over-shoulder   │
│ QWER hotkeys    │             │ WASD movement   │
│ Click-select    │             │ Action bars     │
└─────────────────┘             └─────────────────┘
```

Same map, different experience:
- Classic WC3 RTS controls (default)
- Optional immersive 3D adventure mode (F5 toggle)

---

## Phase 6: Asset System - Community Content (Issues Created)

8 issues created. Community-provided assets replace Blizzard IP.

**Legal Strategy:** ROM emulator precedent - engine distributed without proprietary assets, users provide community-created replacements.

### Issue Breakdown

| ID | Name | Description |
|----|------|-------------|
| 601 | Asset loader and resolution | Load models/textures from asset packs |
| 602 | Wire-frame fallback renderer | Debug visuals for missing assets |
| 603 | Fetch maps and models from public sites | Finds items on public hosting sites and downloads one when a player asks (HTTP) |
| 604 | Asset deduplication system | Content-addressed storage |
| 605 | Local storage manager | Per-pack tracking, cleanup UI |
| 606 | Hot-reload system | Development-time asset refresh |
| 607 | ~~File server application~~ | Retired 2026-09-26 (`issues/superseded/`): nothing is served over HTTP |
| 608 | Phase 6 integration test | End-to-end validation |
| 609 | Shared map-and-model list | A player shares their list; files pass between people over rmail |

### Design Decisions

- **Asset Source:** Community-created asset packs (legal alternative to Blizzard models)
- **Fallback Mode:** Wire-frame/placeholder rendering when assets missing
- **Pack Format:** Simple directory structure with manifest.json
- **Hot-Reload:** Development-only feature for asset iteration

### Asset Pack Structure

```
~/.wc3-engine/assets/
├── default-pack/               # Fallback placeholder pack
│   ├── models/
│   │   ├── units/
│   │   │   ├── human_footman.obj       # Simple placeholder
│   │   │   ├── orc_grunt.obj
│   │   │   └── ...
│   │   ├── buildings/
│   │   └── doodads/
│   ├── textures/
│   │   ├── terrain/
│   │   │   ├── grass.png
│   │   │   ├── dirt.png
│   │   │   └── ...
│   │   └── ui/
│   ├── sounds/
│   │   ├── units/
│   │   └── ambient/
│   └── manifest.json           # Asset ID mapping
│
└── community-fantasy-pack/     # User-installed high-quality pack
    ├── models/
    ├── textures/
    ├── sounds/
    └── manifest.json
```

### Storage Architecture

```
~/.wc3-engine/
├── blobs/                  # Deduplicated content-addressed storage
│   └── ab/ab3def789...     # SHA-256 hash as filename
└── packs/                  # Asset pack references
    ├── default/
    └── community-pack-1/
```

---

## Phase 7: Gameplay - Core Mechanics (Archived)

The death system (701) and profession system (702) were archived on
2026-01-08 with the WoW-mode issues (`issues/archive/wow-mode-2026-01-08/`);
only the core profession component (702a) was completed first. Issues 703-707
were planned but never written. WC3 gameplay mechanics (combat, abilities,
buffs, training, fog of war) have no live issues; when they come back they
start from this list. The rest of this section is the record of the plan.

7 root issues were planned for core WC3 gameplay systems.

**Focus:** Pure WC3 behavior - replicate original game mechanics faithfully.

### Issue Breakdown

| ID | Name | Sub-Issues | Status |
|----|------|------------|--------|
| 701 | Death and resurrection system | 5 (701a-e) | 701d complete |
| 702 | Profession system | 7 (702a-g) | Created |
| 703 | Combat system | - | Done as issues 519, 525 (`demo/wc3map/combat.lua`: stock stats, damage table in constants) |
| 704 | Ability system framework | - | Done as issue 529 (`demo/wc3map/abilities.lua`) |
| 705 | Buff/debuff system | - | Done as issue 529 (`demo/wc3map/buffs.lua`) |
| 706 | Build queue and training | - | Done as issue 521a (`demo/wc3map/production.lua`); economy 527, heroes 528 |
| 707 | Fog of war | - | Done as issue 524 (`demo/wc3map/vision.lua`) |

Also done in `demo/wc3map/`, outside the 70x numbering:
- spell art, effects, missiles and lightning (`effects.lua`, issues 530 and 538);
- construction, repair, helping and upgrades (`construction.lua`, 531, 534 and 535);
- building footprints (`footprint.lua`, 536);
- items and drops (`items.lua`, 532 and 537);
- shops and taverns (`shops.lua`, 533 and 539);
- computer players building, hiring, buying and casting (`ai/acts.lua`, 540).

### Death System (701)

```
[Living Unit] ──death──▶ [Corpse] ──decay──▶ ∅
      ▲                      │
      │                      │ soul
 resurrect                   ▼
      │              ┌─────────────┐
      └──────────────│ Spirit Realm│
                     │   [Ghost]   │
                     └─────────────┘
```

**WC3 Behavior:**
- Hero units → Altar of Kings/Altar of Storms revival
- Non-hero units → Permanent death, corpse decay
- Resurrection items (Scroll of Resurrection, etc.)

### Profession System (702)

**Note:** WC3-style ability-based professions (5 levels per skill).

| Profession | Input | Output |
|------------|-------|--------|
| Mining | Nodes | Ore, gems |
| Herbalism | Plants | Herbs |
| Blacksmithing | Bars | Weapons, armor |
| Alchemy | Herbs | Potions |
| Engineering | Parts | Gadgets |

---

## Phase 8: Multiplayer - Matchmaking & Networking (Issues Created)

9 issues created. Matchmaking server with lobby system, NAT traversal, and asset distribution.

**Focus:** Direct connections to the hosting player's server, with a
matchmaking server for discovery. The host's machine runs the one true
simulation; lockstep was dropped (2026-09-25, see
`docs/wc3-engine-architecture.md`, Multiplayer Strategy).

**Key Features:**
- Matchmaking server (game listing, lobby system)
- NAT traversal (UDP hole punching)
- Asset mirror (distribute community packs)
- Lobby UI (game browser, pre-game coordination)
- Direct game connections to the host's server (not relayed)

### Issue Breakdown

| ID | Name | Description | Dependencies |
|----|------|-------------|--------------|
| 801 | Matchmaking server | Root issue with full architecture | Phase 5, 6 |
| 801a | Protocol specification | Message types, wire format | None |
| 801b | Server core | Lobby registry, message routing | 801a |
| 801c | Client library | API for game integration | 801a, 801b |
| 801d | NAT traversal | UDP hole punching | 801a, 801b |
| 801e | Lobby UI | Game browser, lobby screen | 801c, Phase 5 |
| 801f | Asset mirror integration | Distribute common asset packs | 801b, Phase 6 |
| 801g | CLI server application | Run and monitor server | 801b, 801f |
| 801h | Integration tests | End-to-end testing | All 801 sub-issues |
| 802 | Render system moved onto the shared thread-pool library | Waits on 515f's verdict (question Q-6); rendering work filed under Phase 8 | my-libs threadpool |
| 803 | Gameplay messages, with the server inside the client | The host's simulation and the messages between it and players; steps 1-4 built | 401, 515c |
| 804 | Crossing armies, drawn from across the network | The crowd demo over the network; built, waiting on the owner's viewing | 405f, 803, 515c |

How the 801 family relates to 803 and to Phase W's servers is open
(`issues/CRITICAL-PATH.md`, question Q-1).

### Implementation Notes

**Network Architecture:**
- Client discovers games via matchmaking server
- NAT traversal establishes direct P2P connections
- Game traffic flows directly between each client and the host's server
  (not through the matchmaking server)
- Asset packs downloaded from mirror or host

**Gameplay networking:** server-authoritative, not lockstep (decided
2026-09-25). No deterministic simulation across machines is needed. The
gameplay messages (states, orders, corrections, waiting for a silent
player) are issue 803, built offline first, the simulation playing the
server inside the client.

---

## Phase 9: World Editor (Issues Created)

12 issues created. Full-featured map editor with WC3 World Editor parity.

**Goal:** Allow creation of new WC3-compatible maps.

### Issue Breakdown

| ID | Name | Description | Status (2026-09-30) |
|----|------|-------------|--------|
| 901 | Editor core framework | Window, viewport, undo/redo, shortcuts | Done (`src/editor/`, `src/render/run-editor`) |
| 902 | Terrain editor | Height, textures, cliffs, water | First pass: raise, lower, smooth, flatten, paint, water, cliffs, blight |
| 903 | Object placer | Units, doodads, items, destructibles | First pass: doodads, placed and script units |
| 904 | Region and camera editor | Regions, camera presets | First pass: the script's rects moved and resized; 904b: cameras, new regions |
| 905 | Trigger editor | GUI + Lua with bidirectional sync | 905a: blocks written as JASS, the map's own triggers edited as code; 905b: triggers as Lua, both views edit |
| 906 | Object editor | Modify unit/ability/item stats | First pass: fields, custom types, all 7 kinds |
| 907 | Sound editor | 3D sounds, music, ambience | First pass (907a): the script's sounds and music, new sounds for triggers |
| 908 | Import manager | Custom asset management | First pass (908a): files named, checked, imported, renamed, deleted |
| 909 | AI editor | Computer player behavior | First pass (909a): AI Editor profiles edited, saved into the map |
| 910 | Campaign editor | Multi-map storylines | |
| 911 | Map format and export | Standard .w3x export | 911a: WC3 files written back, copies saved in place; 911b: new maps from scratch; 911c: map projects (.wex) |
| 912 | Phase 9 integration test | Full editor workflow testing | 912a: one new map through every part of the editor, saved, reopened, played |

### Key Features

- **Trigger Editor:** Full GUI parity with WC3, plus Lua code editing
  - Bidirectional conversion: edit in GUI or code, changes sync
  - Lua is the canonical format, GUI is a view
- **Map Format:** Standard .w3x format (WC3 compatible)
- **Campaign Editor:** Multi-map storylines with hero persistence

### Dependency Graph

```
901 Editor Core ──┬──▶ 902 Terrain
                  ├──▶ 903 Object Placer
                  ├──▶ 904 Regions/Cameras
                  ├──▶ 905 Trigger Editor
                  ├──▶ 906 Object Editor
                  ├──▶ 907 Sound Editor
                  ├──▶ 908 Import Manager
                  ├──▶ 909 AI Editor
                  ├──▶ 910 Campaign ──▶ 911 Map Format
                  └──▶ 911 Map Format
                             │
All ─────────────────────────▶ 912 Integration Test
```

---

## Phase 10: Polish - Tools and UX (Planned)

Developer and player experience improvements.

**Focus:** Make the engine accessible and enjoyable.

### Planned Features

- In-game console for Lua commands
- Debug visualization modes
- Performance profiling tools
- Map browser/launcher UI (issue 1001: a catalogue of freely posted maps and models, read from what issue 603 fetches, instead of bundling any)
- Settings and configuration UI
- Documentation and tutorials
- Asset pack browser
- Community integration

---

## Phase W: WoW Client Bridge (Issues Created)

A side phase, lettered so phases 1-10 keep their numbers. It connects the
engine to the World of Warcraft 3.3.5a client that AzerothCore serves. Design
and reasoning: `docs/wow-client-bridge.md`. Progress: `issues/phase-W-progress.md`.

| ID | Name | Role of the WoW client |
|----|------|------------------------|
| W01 | Read the WoW client's archives (MPQ chain, DBC, BLP, M2; MPQ writer) | Foundation |
| W02 | Build WC3 maps into the WoW client (terrain → ADT, placements, map registration, server data, triggers in ALE (Eluna's successor), launcher + loader, control addon) | Alternate host |
| W03 | Show WoW models with WC3 unit behavior (model resolver, WC3 animation timing, skinning, replay) | Model source |
| W04 | Compare the real client against the open client (scripted server scenes, recording, image statistics, vision-LLM notes) | Reference |
| W05 | Asset forge: find or generate a replacement model (licensed search, ComfyUI image-to-3D) | Replacing it |
| W05a | Similarity-to-original score (the forge's progress measure) | Replacing it |
| W05b | Borrowed skeleton and animation sets | Replacing it |
| W05c | "Default client compatible" seal | Replacing it |
| W05d | Clean-room loop: describe, build, check (the default route for every replacement) | Replacing it |
| W05e | Body-structure fit check and body-plan standards | Replacing it |
| W06 | Restyle every model in one theme (e.g. "neopunk"; GPU batch) | Replacing it |
| W07 | Phase W demo | Capstone |
| W08 | Our own server, speaking the same protocol (design research; decides the licence of the whole stack) | Replacing the server |

```
W01 ──┬──▶ W02 ──┬──▶ W04 ──┬──────────────▶ W08
      │          │          │
      └──▶ W03 ──┼──▶ W05 (a-e) ──┼──▶ W06 ──▶ W07
                 └────────────────┘
```

W07's dependencies in its issue file name W02-W06 only; whether W05a-e and
W08 belong in the demo is still to be written into it.

Datapaths: `docs/datapath-wc3-map-into-wow-client.md`,
`docs/datapath-wow-models-in-engine.md`,
`docs/datapath-client-comparison-testing.md`, `docs/datapath-asset-forge.md`.

---

## Success Milestones

### Minimum Viable Product (6 months)

1. ✅ Can parse any .w3x map
2. ✅ Can extract all game data (terrain, units, triggers)
3. ✅ Can execute JASS scripts
4. ⏳ Can render terrain with placeholder textures
5. ⏳ Can spawn units with placeholder models
6. ⏳ Can select units and issue move commands
7. ⏳ Can play a simple melee map start-to-finish
8. ⏳ Community can install custom asset packs

### Vertical Slice: Tower Defense Map (6-8 months)

**Goal:** Play one complete TD map (e.g., Element TD, Gem TD)

**Requirements:**
- ✅ Parse TD map successfully
- ⏳ Execute wave spawn triggers
- ⏳ Towers can attack creeps
- ⏳ Damage calculations work
- ⏳ Gold/lumber economies function
- ⏳ Victory/defeat conditions trigger
- ⏳ Can play from start to end

### Full Engine 1.0 (12 months)

1. ✅ All WC3 map formats supported
2. ✅ JASS execution 99% compatible
3. ✅ LAN multiplayer functional
4. ✅ Asset pack system with 3+ community packs
5. ✅ Runs on Windows, Linux, macOS
6. ✅ Can play top 20 popular custom maps
7. ✅ Map editor integration (load from World Editor)

---

## Future Considerations

- Custom map format extensions
- WebAssembly port for browser play
- Mobile platform support (Android/iOS)
- AI opponent framework
- Steam integration (if legally viable)
- Map workshop/sharing platform

---

## Design Documents

For detailed architecture information, see:

- **`docs/wc3-engine-architecture.md`** - Pure WC3 engine design (active)
- **`docs/postmortem-azerothcore-integration.md`** - AC integration pivot analysis
- **`docs/wow-client-bridge.md`** - Phase W design (WoW client as host, model source, reference)
- **`docs/render-architecture.md`** - Threading model, component slots
- **`docs/binary-vector-frames.md`** - Quadrant voting, curve approximation
- **`notes/vision`** - Project philosophy and legal basis

---

*"Preserve the garden. Honor the creativity. Keep the maps alive."*
