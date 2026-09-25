# World Edit to Execute - Documentation

## Phases

Phases group related functionality; they are not a timeline.

| Phase | Name | Holds |
|-------|------|-------|
| 0 | Tooling/Infrastructure | Issue splitter, TUI library, attribute and currency systems |
| 1 | Foundation - File Format Parsing | MPQ archives, map info, strings, terrain, object data |
| 2 | Data Model - Game Objects | Doodads, units, regions, cameras, sounds, object registry |
| 3 | Logic Layer - Triggers and JASS | Trigger files, JASS lexer/parser, JASS → Lua, events |
| 4 | Runtime - Basic Engine Loop | Game loop, ECS, pathfinding, movement, collision, players |
| 5 | Rendering - Visual Abstraction | Raylib renderer, threading, terrain, UI, minimap |
| 6 | Asset System - Community Content | Asset packs, fallback visuals, storage, hot reload |
| 7 | Gameplay - Core Mechanics | (archived to `issues/archive/wow-mode-2026-01-08/`) |
| 8 | Multiplayer & Networking | Matchmaking, NAT traversal, lobby |
| 9 | World Editor | Terrain, objects, triggers, export |
| 10 | Polish - Tools and UX | Console, launcher, settings |
| A | Infrastructure tools | Tracked in the delta-version project |
| B, Q | Bug hunts, quest log | Gamified tracking documents |
| W | WoW Client Bridge | WoW 3.3.5a client as map host, model source, test reference; model replacement |
| X | Experimental | Design research |

Issue status: `issues/progress.md`, `issues/phase-W-progress.md`, or live counts with
`lua /home/ritz/programming/ai-stuff/scripts/progress-dashboard.lua <project> -m`.

## Tree

```
./
├── CLAUDE.md                        Project instructions for Claude Code
├── run-demo.sh                      Phase demo picker
│
notes/
├── vision                           Core project vision, legal philosophy
├── vision-2                         One line: interface with wow-chat
├── consideration-matching.md        Mapping design considerations to decisions
├── mpq-debug-notes.md               The debug scripts used for the MPQ extraction bug (102d)
├── thank-you.md                     A thank-you note (2025-12-16)
└── conversations/
    └── 2025-12-30-frame-encoding-dna.md   Frame encoding, DNA analogy
│
docs/
├── table-of-contents.md             (this file)
├── roadmap.md                       Phases, current focus, milestones
├── critical-path.md → ../issues/CRITICAL-PATH.md   Decision points, open questions
├── wc3-engine-architecture.md       Pure WC3 engine design (active)
├── postmortem-azerothcore-integration.md   Why the January AC design was archived (+ Phase W addendum)
├── wow-client-bridge.md             Phase W design: roles of the WoW client, scale, open questions
├── datapath-wc3-map-into-wow-client.md      W02: .w3x → ADT/MPQ/SQL/scripts → WoW client
├── datapath-wow-models-in-engine.md         W01/W03: WoW archives → model → WC3 behavior → frame
├── datapath-client-comparison-testing.md    W04: scenario → two clients → recordings → report
├── datapath-asset-forge.md                  W05/W06: select → search/generate → fit → keep → install
├── licensing-and-boundaries.md      Which licence covers each piece, where they touch, what combines
├── legal-implications.md            For readers: copyright vs licence agreements, stats, US vs EU, where risk sits
├── render-architecture.md           Threading model, component slots, numeric encoding
├── render-system-multithreading.md  Pipeline stages, task submission, synchronization
├── render-threading-v2.md           Target threading model (v2)
├── binary-vector-frames.md          Quadrant voting, curve approximation, 3D rotations
├── delta-guide.md                   Delta-version maintainer guide
├── formats/                         File format specifications
│   ├── mpq-archive.md               MPQ archive format (with HM3W wrapper)
│   ├── pkware-dcl-compression.md    PKWARE DCL compression
│   ├── w3i-map-info.md              Map info
│   ├── wts-trigger-strings.md       Trigger string table, TRIGSTR resolution
│   ├── w3e-terrain.md               Terrain: tilepoints, heights, textures, cliffs
│   ├── unitsdoo.md                  Unit/building placement
│   └── object-data.md               Object data files (w3u/w3a/w3t/…)
├── templates/                       Quest & bounty templates
│   ├── README.md, quest-template.md, quest-log-template.md,
│   ├── bounty-template.md, guild-roster-template.md, example-spec.lua
└── archive/
    └── azerothcore-2026-01-07/      Archived AC integration research (reference only)
        ├── README.md
        ├── azerothcore-integration-architecture.md
        ├── client-architecture.md
        ├── data-conversion-pipeline.md   (has a 2026-09-23 correction note)
        ├── custom-ability-bridge.md
        └── phase-reorganization.md
│
flopsopolies/                        Short reflective essays on the project (001-008)
│
archives/
└── 2026-01-07-wow-professions/      Archived WoW profession code and issues
│
src/
├── compat.lua                       Lua 5.1/LuaJIT ↔ 5.3+ compatibility
├── cli/                             mapdump, issue-splitter (symlink), quest-generator,
│                                    guild-cli, run-tests, save-conversation, private-sync
├── mpq/                             MPQ archive reading (header, hash, tables, extract, pkware)
├── parsers/                         w3i, wts, w3e, doo, unitsdoo, w3r, w3c, w3s, wtg, wct, j, object data
├── data/                            Map class integrating all parsers
├── gameobjects/                     Doodad, Unit, Region, Camera, Sound classes
├── registry/                        Object registry + spatial index
├── validation/                      Cross-reference validation between map files
├── jass/                            JASS lexer, parser, JASS → Lua transpiler
├── runtime/                         Game loop, ECS, pathfinding, collision, orders, players,
│                                    resources, triggers, events, timers, currency
├── libs/attributes/                 Attribute system (schema, getters, setters, modifiers,
│                                    derived, mapping, WC3/WoW configs)
├── guild/                           Hero & shop system
├── render/                          C + raylib renderer (threading, slots, terrain, input, UI, profiler)
├── render.lua                       Lua side of the renderer bridge
├── demo/                            Map renderer and testing-room demos
└── tests/                           Test suite (run with src/cli/run-tests.sh)
│
issues/                              Issue files (not listed here; see progress files)
├── progress.md                      Overall phase status
├── phase-W-progress.md              Phase W status
├── CRITICAL-PATH.md                 Decision points and tech debt
├── completed/demos/                 Phase demos (run through run-demo.sh)
├── analysis/                        Issue-splitter analysis archive
└── archive/wow-mode-2026-01-08/     Archived Warlord Mode / WoW-mechanics issues
```

## Tools

| Tool | Location | Description |
|------|----------|-------------|
| issue-splitter.sh | `src/cli/issue-splitter.sh` (symlink) | Issue analysis, sub-issue creation, auto-implementation |
| validate-issues | `/home/ritz/programming/ai-stuff/scripts/validate-issues` | Issue tree consistency, next free issue number |
| progress-dashboard.lua | `/home/ritz/programming/ai-stuff/scripts/progress-dashboard.lua` | Done/open counts per phase |
| mapdump.lua | `src/cli/mapdump.lua` | Dump a map's metadata |
| quest-generator.lua | `src/cli/quest-generator.lua` | Gamified task documentation generator |
| TUI library | `/home/ritz/programming/ai-stuff/scripts/libs/` | Shared terminal UI |

## Guides

(To be written as development proceeds: getting started, creating asset
packs, writing Lua scripts, contributing.)
