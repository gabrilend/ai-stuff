# Critical Path Document

```
╔══════════════════════════════════════════════════════════════════╗
║                                                                  ║
║   📍 CRITICAL PATH - Decision Points & Open Questions            ║
║                                                                  ║
║   "The relevance of this document increases with use."           ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
```

**Last Updated:** 2026-01-07 (Architectural Pivot)
**Maintainer:** Project contributors
**Location:** `issues/CRITICAL-PATH.md` (symlinked to `docs/critical-path.md`)

---

## ⚡ Architectural Pivot (2026-01-07)

**Major Decision:** Abandoned AzerothCore integration in favor of pure WC3 engine.

**Reason:** Complexity misalignment with core preservation mission.

**Impact on This Document:**
- OQ-003 and OQ-004 decisions superseded by pivot
- Focus shifted to pure WC3 gameplay, LAN multiplayer, community assets
- Dual-view camera (WC3 tactical + 3D adventure) remains valid
- See `docs/postmortem-azerothcore-integration.md` for full analysis

---

## Purpose

This document tracks:
- **Open questions** requiring human decision before implementation
- **Design decisions** that affect multiple systems
- **Known blockers** preventing progress
- **Technical debt** that compounds if unaddressed
- **Cross-phase dependencies** that create bottlenecks

Items move through states: `OPEN` → `DECIDED` → `IMPLEMENTED` → `ARCHIVED`

---

## Priority Legend

| Priority | Meaning | Action Required |
|----------|---------|-----------------|
| 🔴 BLOCKING | Cannot proceed without resolution | Immediate decision needed |
| 🟠 HIGH | Affects multiple systems or phases | Decide before related work |
| 🟡 MEDIUM | Impacts quality or architecture | Decide within current phase |
| 🟢 LOW | Nice to have clarity | Decide when convenient |

---

## Open Questions

### OQ-001: Primary Renderer Target
**Priority:** 🟠 HIGH
**Affects:** Phase 5 (all rendering issues)
**Status:** DECIDED
**Source:** Issue 501

What rendering backend should be the primary target?

| Option | Pros | Cons |
|--------|------|------|
| Terminal/TUI | No dependencies, works everywhere | Limited visuals |
| LÖVE2D | Batteries-included, Lua-native | Requires installation |
| SDL2 | Lower level, more control | More code to write |
| **Raylib** | Simple, modern | Less Lua ecosystem |

**Decision:** Raylib - simple, modern C library with Lua bindings
**Decided by:** User
**Date:** 2025-12-29

---

### OQ-002: Coordinate System
**Priority:** 🟠 HIGH
**Affects:** Phase 5, pathfinding display, camera
**Status:** DECIDED
**Source:** Issue 501

Which coordinate system for rendering?

| Option | Description |
|--------|-------------|
| **WC3-style** | Y increases upward, isometric projection |
| Screen-style | Y increases downward, top-down orthographic |

**Decision:** WC3-style (Y-up) - matches game data, authentic feel
**Decided by:** User
**Date:** 2025-12-29

---

### OQ-003: Dual Camera Mode Strategy
**Priority:** 🟡 MEDIUM
**Affects:** Phase 5, overall architecture
**Status:** SUPERSEDED (2026-01-07 Pivot)
**Source:** Issue 500

**Original Decision (2025-12-29):** AzerothCore integration with dual-mode support.

**Current Decision (2026-01-07):** Pure WC3 engine with optional dual-camera system:
- **Default:** WC3 tactical camera (top-down RTS view)
- **Optional:** 3D adventure camera (over-shoulder exploration)
- **Toggle:** F5 key switches between camera modes
- **Focus:** Pure WC3 gameplay, no server dependency

**Decided by:** User
**Date:** 2026-01-07 (pivoted from 2025-12-29 decision)
**Architecture:** See `docs/wc3-engine-architecture.md`

---

### OQ-004: Development Priority
**Priority:** 🟡 MEDIUM
**Affects:** Feature prioritization, Phase 5-7
**Status:** SUPERSEDED (2026-01-07 Pivot)
**Source:** Issue 500

**Original Decision (2025-12-29):** Integrated WC3/WoW dual-mode approach.

**Current Decision (2026-01-07):** Pure WC3 engine priority:
1. **Phase 5:** Rendering (Raylib, WC3 tactical camera, basic 3D adventure camera)
2. **Phase 6:** Asset system (community-created packs, legal Blizzard IP replacement)
3. **Phase 7:** WC3 gameplay mechanics (death, professions, combat, abilities)
4. **Phase 8:** LAN multiplayer (no Battle.net dependency)

**Goal:** First playable Tower Defense map in 6 months.

**Decided by:** User
**Date:** 2026-01-07 (pivoted from 2025-12-29 decision)
**Architecture:** See `docs/wc3-engine-architecture.md`

---

### OQ-007: Window Management Strategy
**Priority:** 🟡 MEDIUM
**Affects:** Phase 5 (UI framework), Phase 6 (user experience)
**Status:** DECIDED
**Source:** Issue 500

How should UI panels and views be managed?

| Option | Description |
|--------|-------------|
| Fixed layout | Permanent panel positions |
| Dockable | Snap to edges, user arrangeable |
| **Breakout windows** | OS-managed or client-managed floating windows |
| Multi-monitor | Separate windows per display |

**Decision:** User-configurable with all options available:
- Picture-in-picture (overlay views)
- Split screen (side by side)
- Separate windows (multi-monitor support)

UI panels (chat, professions, inventory) can be:
- OS-managed: Window decorations, standard OS window behavior
- Client-managed: Software window management, drag within client

WC3 default: Permanent top/bottom panels, overlay menus (pause in single-player).
**Decided by:** User
**Date:** 2025-12-31
**Details:** See issue 500 "Decided Answers" section (D2)

---

### OQ-008: Camera Transition Architecture
**Priority:** 🟡 MEDIUM
**Affects:** Phase 5 (rendering), perspective switching
**Status:** DECIDED
**Source:** Issue 500, Issue 409

How should camera transitions between perspectives be implemented?

| Option | Description |
|--------|-------------|
| Interpolated | Smooth lerp between camera states |
| **Frame-based** | Binary vector arrays with timer-driven playback |
| Instant | Immediate cut between perspectives |

**Decision:** Frame-based binary vectors with mise en place threading.
- Transitions use frame arrays (per issue 409 encoding)
- Timer in thread pool drives playback
- Mise en place: duplicate data, parallel compute, rhythmic sync
- No mutexes - each thread owns its data copy
**Decided by:** User
**Date:** 2025-12-31
**Details:** See issue 500 "Decided Answers" section (D6)

---

### OQ-009: Chat System Architecture
**Priority:** 🟡 MEDIUM
**Affects:** Phase 5 (UI), both interface modes
**Status:** DECIDED
**Source:** Issue 500

How should chat be integrated across both perspectives?

| Option | Description |
|--------|-------------|
| WC3-style | Minimal chat, RTS-focused |
| **WoW-centric** | Full chat as primary interface |
| Hybrid | Different chat per mode |

**Decision:** WoW-centric first, minimal friction with game state.
- Native WoW protocol patterns
- Separate subsystem, not tied to game ticks
- Same chat panel works in both Warlord/Hero perspectives
- UI events, not gameplay events
**Decided by:** User
**Date:** 2025-12-31
**Details:** See issue 500 "Decided Answers" section (D7)

---

### OQ-010: Entity Spawning Architecture
**Priority:** 🟡 MEDIUM
**Affects:** Phase 5 (rendering), Phase 7 (gameplay)
**Status:** DECIDED
**Source:** Issue 500, libs/wow-chat

How should entities spawn in the world?

| Option | Description |
|--------|-------------|
| Static | Pre-placed entities on map load |
| **Player-centric** | Procedural spawning around each player |
| Hybrid | Static base + dynamic additions |

**Decision:** Player-centric spawning with periodic events.
- Empty base world (all static creatures removed)
- Periodic spawn systems: Mordaunts (21s), Travellers (210s), Treasure (120s)
- Same underlying events, different visual presentation per perspective
- Reference implementation: libs/wow-chat/
**Decided by:** User
**Date:** 2025-12-31
**Details:** See issue 500 "Decided Answers" section (D8)

---

### OQ-005: Ghost/Spirit World Mechanics
**Priority:** 🟢 LOW
**Affects:** Issue 701 (Death System)
**Status:** OPEN
**Source:** Issue 701

Detailed spirit world behavior:

1. Can enemies see ghost location? (Suggested: No)
2. Can ghosts have abilities? (WC3: No, WoW: Scouting)
3. What happens if hero dies during revival? (Suggested: Cancel, new death)
4. Can multiple corpses occupy same tile? (Suggested: Yes)

**Decision:** _pending_
**Decided by:** _pending_
**Date:** _pending_

---

### OQ-006: A* Priority Update Strategy
**Priority:** 🟢 LOW
**Affects:** Pathfinding performance (Issue 403, Bounty B01)
**Status:** OPEN
**Source:** Bounty B01

When a better path to an already-open node is found:

| Option | Description | Trade-off |
|--------|-------------|-----------|
| Decrease-key | Update priority in heap | Requires heap modification |
| Lazy deletion | Allow duplicates, skip closed | Uses more memory |

**Decision:** _pending_
**Decided by:** _pending_
**Date:** _pending_

---

## Decided Questions

_Move items here when decisions are made. Keep for reference._

### DQ-001: Example Template
**Priority:** 🟢 LOW
**Status:** DECIDED → IMPLEMENTED
**Source:** Example

**Question:** Example question?

**Decision:** Example answer
**Decided by:** Example person
**Date:** 2025-XX-XX
**Implementation:** Issue XXX

---

## Known Technical Debt

### TD-001: Phantom Priority (B01)
**Severity:** 🟡 MEDIUM
**Location:** `src/runtime/pathfinding/astar.lua:355-358`
**Impact:** Wasted pathfinding iterations on complex maps

A* doesn't update priority when better path to same node is found. Old entry remains in queue, causing duplicate processing.

**Resolution:** Implement decrease-key or lazy deletion (see OQ-006)
**Tracking:** Bounty B01

---

### TD-002: Eternal Timer (B02)
**Severity:** 🟡 MEDIUM
**Location:** `src/runtime/timers.lua:388-396`
**Impact:** Memory leak over long game sessions

Periodic timers are never cleaned from heap. Orphaned timers accumulate indefinitely.

**Resolution:** Timer ownership tracking, weak references, or max timer limit
**Tracking:** Bounty B02

---

### TD-003: Hivemind Component (B03)
**Severity:** 🟠 HIGH
**Location:** `src/runtime/ecs/component.lua:83-85`
**Impact:** Shared state between entities with table-valued defaults

Shallow copy of component defaults means table fields are shared across all entities. Modifying one entity's nested table affects all.

**Resolution:** Deep copy function for defaults, or factory functions
**Tracking:** Bounty B03

---

### TD-004: Floating Point Collinearity
**Severity:** 🟢 LOW
**Location:** `src/runtime/pathfinding/smooth.lua:80`
**Impact:** Path smoothing may miss collinear points

Direct `== 0` comparison for cross product. Should use epsilon threshold.

**Resolution:** `math.abs(cross) < EPSILON` with EPSILON ~= 1e-9
**Tracking:** Quest A1

---

### TD-005: Unpack Bounds Check
**Severity:** 🟡 MEDIUM
**Location:** `src/compat.lua:98-107`
**Impact:** Crash on truncated/malformed files

`unpack_uint32` doesn't check if data has enough bytes before reading.

**Resolution:** Bounds check, return nil/error on truncation
**Tracking:** Quest J1

---

## Incomplete Issue Families

### IF-001: Profession System (702)
**Status:** Partially created
**Blocking:** Nothing currently

| Sub-Issue | Status |
|-----------|--------|
| 702 (root) | ✓ Created |
| 702a (core component) | ✓ Created |
| 702b (gathering) | ✓ Created |
| 702c (crafting) | ✓ Created |
| 702d (recipes) | ✗ Not created |
| 702e (WoW-mode) | ✗ Not created |
| 702f (WC3-mode) | ✗ Not created |
| 702g (UI abstraction) | ✗ Not created |

**Action:** Create 702d-702g when beginning Phase 7

---

### IF-002: Collision System (405)
**Status:** 5/5 complete ✓
**Blocking:** None (completed)

| Sub-Issue | Status |
|-----------|--------|
| 405a (primitives) | ✓ Complete |
| 405b (spatial hash) | ✓ Complete |
| 405c (queries) | ✓ Complete |
| 405d (movement integration) | ✓ Complete (2025-12-30) |
| 405e (projectile/picking) | ✓ Complete |

**Action:** None - system complete with 277 collision tests

---

### IF-003: Phase 4 Integration (408) ✓ COMPLETE
**Status:** 5/5 complete
**Blocking:** None (completed)

| Sub-Issue | Status |
|-----------|--------|
| 408a (unit tests core) | ✓ Complete (2025-12-30) |
| 408b (unit tests entity) | ✓ Complete (2025-12-30) |
| 408c (unit tests player) | ✓ Complete (2025-12-31) |
| 408d (integration scenario) | ✓ Complete |
| 408e (visual demo) | ✓ Complete (2025-12-31) |

**Visual Demo Features:**
- Terminal-based animation with 60x20 grid display
- Units as colored circles (red/blue teams)
- Real-time movement at 62.5 ticks/sec
- Status bar with tick count and game time

---

### IF-004: Vertical Slice (508) ✓ COMPLETE
**Status:** 9/9 complete
**Blocking:** None (completed)

| Sub-Issue | Status |
|-----------|--------|
| 508a (threading infrastructure) | ✓ Complete |
| 508b (entity render slots) | ✓ Complete (2025-12-30) |
| 508c (Lua-C bridge) | ✓ Complete (2025-12-30) |
| 508d (map integration) | ✓ Complete (2025-12-30) |
| 508e (input and selection) | ✓ Complete (2025-12-30) |
| 508f (movement orders) | ✓ Complete (2025-12-31) |
| 508g (minimal UI) | ✓ Complete (2025-12-31) |
| 508h (integration test) | ✓ Complete (2025-12-31) |
| 508i (fix chunk ray picking) | ✓ Complete (2025-12-31) |

**Action:** None - vertical slice complete, architecture validated

---

### IF-005: Player Visual Customization (509)
**Status:** 0/5 complete
**Blocking:** Nothing currently (enhancement feature)

| Sub-Issue | Status |
|-----------|--------|
| 509 (root) | ✓ Created (2025-12-31) |
| 509a (character appearance data model) | ✗ Pending |
| 509b (effect color parameter system) | ✗ Pending |
| 509c (viewport preference system) | ✗ Pending |
| 509d (WoW-Chat profile integration) | ✗ Pending |
| 509e (render pipeline integration) | ✗ Pending |

**Dependencies:** 503 (sprite system), WoW-Chat integration (OQ-003/004)
**Action:** Create sub-issue files when beginning implementation

---

### IF-006: Threading Architecture Rewrite (512) ⚠️ PARTIAL
**Status:** 5/6 complete (unit tests pass, main.c integration pending)
**Blocking:** 512f blocks full completion

| Sub-Issue | Status |
|-----------|--------|
| 512 (root) | ✓ Complete (2026-01-01) |
| 512a (worker ring buffer) | ✓ Complete |
| 512b (updater load balancing) | ✓ Complete |
| 512c (self-evaluating updaters) | ✓ Complete |
| 512d (sync parallel scan) | ✓ Complete |
| 512e (integration testing) | ✓ Complete |
| 512f (main.c integration) | ✗ Pending |

**Implementation Summary:**
- Workers scale to CPU core count via sysconf(_SC_NPROCESSORS_ONLN)
- Ring buffer task-lists with WorkerTask function pointers
- Least-busy worker selection (O(N) scan)
- Helper updaters self-evaluate at 50% threshold (5ms)
- Sync thread uses watch list for parallel pointer swaps
- All 14 unit tests pass

**⚠️ Integration Gap:** main.c still uses old threading API. Old threading.h/c
temporarily restored. New API preserved in test_threading_v2.c.

**Documentation:** `docs/render-threading-v2.md`
**Action:** Create compatibility layer or migrate main.c (512f)

---

### IF-007: Render System Profiler (511) ✓ COMPLETE
**Status:** 5/5 complete
**Blocking:** None (completed)

| Sub-Issue | Status |
|-----------|--------|
| 511 (root) | ✓ Complete (2026-01-01) |
| 511a (core timing) | ✓ Complete |
| 511b (thread-safe recording) | ✓ Complete |
| 511c (overlay rendering) | ✓ Complete |
| 511d (history buffer/graphs) | ✓ Complete |
| 511e (file export) | ✓ Complete |

**Implementation Summary:**
- High-resolution timer via CLOCK_MONOTONIC
- Thread-local sample buffers (16 samples/thread)
- 120-frame rolling history (2 seconds)
- Overlay with timing bars and timeline graph
- F3 toggles overlay, F4 dumps to file

**Files:** `src/render/profiler.h`, `src/render/profiler.c`
**Action:** None - profiler complete

---

## Documentation Drift

### DD-001: Roadmap Outdated
**Severity:** 🟠 HIGH
**Location:** `docs/roadmap.md`

| Section | Says | Reality |
|---------|------|---------|
| Phase 3 | 1/9 complete | **9/9 complete** |
| Phase 4 | Future/planned | **28/30 complete** |
| Phase 7+ | Not mentioned | Issues 701, 702 exist |

**Action:** Update roadmap to reflect actual progress

---

## Cross-Phase Dependencies

```
Phase 5 (Rendering)
    │
    ├── Requires: OQ-001 (renderer target) ✓ DECIDED
    ├── Requires: OQ-002 (coordinate system) ✓ DECIDED
    ├── Requires: OQ-003 (dual interface strategy) ✓ DECIDED
    ├── Requires: OQ-007 (window management) ✓ DECIDED
    ├── Requires: OQ-008 (camera transitions) ✓ DECIDED
    ├── Requires: OQ-009 (chat system) ✓ DECIDED
    ├── Requires: OQ-010 (entity spawning) ✓ DECIDED
    │
    ├── 508 (Vertical Slice) ✓ COMPLETE
    │   └── 9/9 complete, architecture validated
    │
    ├── 509 (Visual Customization)
    │   ├── Requires: 503 (sprite system)
    │   └── Requires: OQ-003/004 (WoW-Chat integration)
    │
    ├── 510 (Dual Perspective UI)
    │   ├── Requires: 506 (UI Framework)
    │   └── Informs: OQ-008/009 implementation
    │
    └── 512 (Threading Architecture Rewrite) - CRITICAL
        ├── Replaces: 508a (prototype threading)
        ├── Target: 100Hz (10ms) tick rate
        └── See: docs/render-threading-v2.md

Phase 7 (Gameplay)
    │
    ├── 701 (Death) requires: OQ-005 (ghost mechanics)
    └── 702 (Professions) requires: IF-001 completion

Phase 4 Completion
    │
    ├── IF-002 (405 collision) ✓ COMPLETE
    └── IF-003 (408 integration tests) ✓ COMPLETE
```

---

## Archived Decisions

_Move fully implemented decisions here for historical record._

---

## How to Use This Document

### Adding a New Question
1. Assign next available OQ-XXX number
2. Set priority based on blocking impact
3. List affected issues/phases
4. Provide options with trade-offs
5. Leave decision fields as `_pending_`

### Recording a Decision
1. Fill in Decision, Decided by, Date fields
2. Change Status to DECIDED
3. When implemented, move to "Decided Questions" section
4. Reference implementing issue

### Tracking Technical Debt
1. Assign next available TD-XXX number
2. Include exact file:line location
3. Describe impact clearly
4. Link to tracking issue (Quest/Bounty)

### Review Cadence
- Review BLOCKING items: immediately
- Review HIGH items: before starting affected phase
- Review MEDIUM items: weekly
- Review LOW items: monthly
- Prune ARCHIVED items: quarterly

---

## Change Log

| Date | Change | Author |
|------|--------|--------|
| 2025-12-29 | Initial creation from issue review | Claude |
| 2025-12-29 | Decided OQ-001 (Raylib), OQ-002 (WC3 Y-up), OQ-003/004 (API-driven integration) | User |
| 2025-12-30 | Completed 405d (movement collision integration), 508b (entity render slots) | Claude |
| 2025-12-30 | Completed 408a (unit tests core), 408b (unit tests entity) | Claude |
| 2025-12-30 | Completed 508c (Lua-C bridge) - LuaJIT compatible | Claude |
| 2025-12-30 | Completed 508d (map integration) - terrain grid, doodads, real map loading | Claude |
| 2025-12-30 | Completed 508e (input and selection) - mouse tracking, ray picking, box select | Claude |
| 2025-12-31 | Added IF-005 for issue 509 (player visual customization) | Claude |
| 2025-12-31 | Updated IF-004 to include 508i bug fix issue (5/9 complete) | Claude |
| 2025-12-31 | Updated cross-phase dependencies with completion status markers | Claude |
| 2025-12-31 | Completed 508f (movement orders) - right-click move, green marker | Claude |
| 2025-12-31 | Issue audit: moved 51 completed issues to issues/completed/ | Claude |
| 2025-12-31 | Expanded OQ-003/004 with full emulation architecture details | User/Claude |
| 2025-12-31 | Added OQ-007 (window management strategy) - breakout windows decided | User/Claude |
| 2025-12-31 | Added OQ-008 (camera transitions) - frame-based with mise en place | User/Claude |
| 2025-12-31 | Added OQ-009 (chat system) - WoW-centric, minimal friction | User/Claude |
| 2025-12-31 | Added OQ-010 (entity spawning) - player-centric periodic events | User/Claude |
| 2025-12-31 | Cloned libs/wow-chat as reference implementation | Claude |
| 2025-12-31 | Created issue 512 (threading architecture rewrite) | Claude |
| 2025-12-31 | Created docs/render-threading-v2.md (target architecture spec) | Claude |
| 2025-12-31 | Added IF-006 for threading rewrite, updated cross-phase deps | Claude |
| 2026-01-01 | Completed 512a-512e (threading v2), discovered main.c integration gap | Claude |
| 2026-01-01 | Created 512f to track main.c threading migration | Claude |
| 2026-01-01 | Restored old threading API temporarily for render demo | Claude |
| 2026-01-01 | Completed 511 (render profiler) - full implementation | Claude |
| 2026-01-01 | Added IF-007 for profiler, updated IF-006 status to PARTIAL | Claude |

