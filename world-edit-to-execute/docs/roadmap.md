# World Edit to Execute - Roadmap

A phased approach to building a WC3-compatible game engine with visual independence.

---

## Current Focus

### Phase 1 Progress: 6/12 complete

**Next Priority Issues:**

1. **103 - Parse war3map.w3i** (map metadata)
   - Player info, forces, fog settings
   - First content parser using MPQ API

2. **104 - Parse war3map.wts** (trigger strings)
   - String table with TRIGSTR resolution
   - Needed for localized content

3. **105 - Parse war3map.w3e** (terrain)
   - Tilepoints, height maps, textures
   - Foundation for rendering

**Available Tools:**
```bash
# Analyze issues with parallel processing
./src/cli/issue-splitter.sh --stream --parallel 3

# Auto-implement an issue
./src/cli/issue-splitter.sh -A -I

# Interactive mode with TUI
./src/cli/issue-splitter.sh -I
```

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

### Completed Features

- ✓ Issue splitter tool for automated analysis
- ✓ Direct output handling (no intermediate files)
- ✓ Execute mode for auto-generating sub-issues
- ✓ Streaming queue for parallel processing
- ✓ Checkbox-style TUI with vim keybindings
- ✓ Shared TUI library for cross-project reuse
- ✓ Analysis section renaming for promoted roots
- ✓ Auto-implement via Claude CLI

### Final Dependency Graph (All Complete)

```
001 ✓ ──┬──▶ 002 ✓ Streaming Queue
        │     ├── 002a ✓ Infrastructure ──┬──▶ 002b ✓ Producer
        │     │                           └──▶ 002c ✓ Streamer
        │     │                                │
        │     │         ┌──────────────────────┘
        │     │         ▼
        │     └── 002d ✓ Parallel Loop ──▶ 002e ✓ Config Flags
        │
        └──▶ 003 ✓ Execute Recommendations ──▶ 006 ✓ Rename Sections

004 ✓ TUI Redesign ──▶ 005 ✓ Migrate TUI Library

007 ✓ Auto-implement via Claude CLI
```

---

## Phase 1: Foundation - File Format Parsing

Establish the core ability to read and parse WC3 map archives.

- Parse MPQ archive structure (.w3m/.w3x containers)
- Extract embedded files from archive
- Parse war3map.w3i (map info)
- Parse war3map.wts (trigger strings)
- Parse war3map.w3e (terrain data)
- Create internal data structures for parsed content
- Build CLI tool to dump map metadata

---

## Phase 2: Data Model - Game Objects

Build the abstract representation layer for game entities.

- Parse war3map.doo (doodads/destructibles placement)
- Parse war3mapUnits.doo (unit/building placement)
- Parse war3map.w3r (regions)
- Parse war3map.w3c (cameras)
- Parse war3map.w3s (sounds)
- Create abstract Unit, Doodad, Region, Camera types
- Build object registry system

---

## Phase 3: Logic Layer - Triggers and JASS

Implement the scripting and trigger system.

- Parse war3map.wtg (trigger definitions)
- Parse war3map.wct (custom text triggers)
- Parse war3map.j (JASS script)
- Build JASS lexer/parser
- Create JASS-to-Lua transpiler
- Implement trigger condition/action framework
- Build event dispatch system

---

## Phase 4: Runtime - Basic Engine Loop

Create the game execution environment.

- Implement game tick/update loop
- Build entity component system
- Implement basic pathfinding (terrain-aware)
- Create unit movement system
- Implement basic collision detection
- Build resource management (gold/lumber abstraction)
- Create player state management

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
