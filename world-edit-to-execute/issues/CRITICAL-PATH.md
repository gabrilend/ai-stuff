# Critical Path

**Rewritten:** 2026-09-26, after a read-only audit of every open issue file.
The January version tracked the AzerothCore plan, Phase 7 and the threading
rewrite; it is in git history (`git log -p -- issues/CRITICAL-PATH.md`).
**Location:** `issues/CRITICAL-PATH.md` (also reachable as `docs/critical-path.md`,
a symlink)

This document holds four things, and only these:

1. **The path**: which lines of work are moving, and what each is waiting on.
2. **Decisions** that shape more than one issue, with where each was recorded.
3. **Open questions** that block or reshape issues, until they are answered.
4. **Known debt and drift**: bugs left in the code on purpose, and documents
   that disagree with the code.

Counts of done and open issues are not copied here, because they go stale.
Run the dashboard instead:

```bash
lua /home/ritz/programming/ai-stuff/scripts/progress-dashboard.lua /mnt/mtwo/programming/ai-stuff/world-edit-to-execute -m
```

To find issues that disagree with each other (one-sided links, orphans,
reused numbers):

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
**Source:** Issue 500, the wow-chat addon (github.com/gabrilend/wow-chat)

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
- Reference implementation: the wow-chat addon, read from
  github.com/gabrilend/wow-chat rather than vendored here (the local copy under
  `libs/` was removed 2026-08-04; it was a read-only reference, and keeping a
  second copy of a published repository only invited the two to drift)
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

**Decision:** Lazy deletion: each entry carries the g it was pushed with,
and entries whose g is out of date are skipped when popped. Ties on f go to
the higher g. No heap index to maintain; ghost entries are bounded by the
number of path improvements. Reversible if decrease-key is wanted later.
**Decided by:** Claude, implementing Bounty B01 (for owner review)
**Date:** 2026-09-29
**Implementation:** Bounty B01 (`issues/completed/B01-the-phantom-priority.md`)

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
**Status:** Resolved 2026-09-29 by lazy deletion. The stale priorities also
made A* return longer-than-shortest paths; see the B01 implementation notes.

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

## 1. The Path

Phases 1-4 (parsing, data model, triggers and JASS, runtime) are built. The
work now moves along four lines, and two of them wait mostly on the owner
watching a demo.

```
 THE CROWD AND ITS THREADING DESIGNS
 units path around units (405f) ──▶ the same crowd on every threading design (515k)
   built; waits on the owner          steps 1-3 committed; step 4 (films, report,
   watching it                         page) in progress, uncommitted

 THE NETWORK
 gameplay messages, server inside ──▶ crossing armies over the network (804)
 the client (803)                      built; waits on the owner watching it
   steps 1-4 built; step 5 (a refused
   order cancels the local guess)
   needs the client-side prediction
   from 515d ─────────────────────────┐
                                      ▼
 THE CERAMIC RENDER ENGINE            
 predict locally, snap to the ─┐
 server's correction (515d)    ├──▶ measured against the hand-written
 a growing asset table (515e) ─┘     thread pool (515f): the verdict that decides
                                     whether the render code ever moves to the
                                     shared thread-pool library (802)

 STOCK DATA FOR CONVERTED MAPS
 game-version layers (112b) ──▶ the converter refuses a map whose stock table
   built; its hunt for the        is unchecked (112, its last box)
   missing versions (Q-5)       older patch program shapes (112d), and the
                                published-values cross-check (112e), beside it
```

Everything else is either not started and not blocking (Phases 6, 9, W, the
map browser) or needs rewriting before it can start (section 4).

---

## 2. Decisions

Newest first. Each names where it was recorded, so the reasoning can be read
in full there.

| Date | Decision | Recorded in |
|------|----------|-------------|
| 2026-10-01 | **The custom client is a third project**, separate from this one and Everland Ghostsong, playing both; the two do most of the work on it. Its work starts this week and is not on this path. **One generation pipeline for both projects**, and generation plus the similarity score is the route meant to prove legality; the clean-room loop is optional. The score gains a 26-view camera ring, in-engine scenic photoshoots at server startup, region overlays and optional colour. | `docs/wow-client-bridge.md` (Decisions made), issue W05a |
| 2026-09-26 | **The January rendering plan is re-cut** (owner: "sure"). Eight issues describing a Lua renderer with swappable backends, or work the vertical slice already did, are retired to `issues/superseded/`. The other 32 are rewritten for the page split, each keeping its January design below as the record: the page's format and a headless renderer (501), the camera model (501d), terrain built once as chunk meshes (502), what is drawn for a unit besides its model (503), the override file's format (504), camera controls and debug overlays (505c, 505f), the interface as page items (506) and the minimap (507). Three that were mostly built stay open for their small gaps. | issues 501-507 |
| 2026-09-26 | **The editor saves `.w3x`, for now** ("We are already building compatibility for that system so we might as well"). **Player data lives in the project directory** by default, movable by a config file. **Model overrides are made through the game's UI**, not yet planned. | issues 911, 601, 516 |
| 2026-09-26 | A map with no weather holds four zero bytes in its weather code, and the map-info parser keeps them as read: correct data, not something to warn about (owner). The map-info test now prints the code escaped, so the test runner no longer sees raw null bytes. | `src/tests/test_w3i.lua` |
| 2026-09-26 | **Backend in ceramic, renderer in raylib, a page between them.** The owner: "We are building the backend in ceramic, and the renderer in raylib, with C being used (probably as soramech boxes) to create the 'page' that the renderer will draw from with a single thread to display on the screen." Readers that run once (such as the model reader) stay in Lua and hand their data to C, which keeps it for the map. | issues 515, 516, 116 |
| 2026-09-26 | **Draw the model the map asks for; players override it on their own machine; placeholders otherwise.** The owner: "use the models that the map requests. Even if they're stock. The user will build per-stock-model overrides that they can then have rendered on their end." This settles how the owner's earlier answer the same day applies in play: "use the models posted online rather than the ones in the game... use their models only when we are building in compatibility with their formats" (drawing what a map asks for is that compatibility). Stock models come from the player's own install; nothing Blizzard-made is shipped. WC3 textures are decoded by the same shared reader as WoW's. The WoW path's model chooser (W03) is the design for both systems; a stand-in is used until it exists. | issues 116, 117, 516, W03 |
| 2026-09-26 | **Fetching and browsing are split, generation from viewing.** Issue 603 is the fetcher: it finds maps and models on public hosting sites and downloads one over HTTP when a player asks. Issue 1001 is the catalogue: it shows what 603 found and never fetches. The file server (607) is retired; nothing in the project serves files. | issues 603, 1001, `issues/superseded/607-file-server-application.md` |
| 2026-09-26 | Files are still downloaded over HTTP from the public websites that host WC3 maps and models. rmail is for passing files between people; it does not replace fetching from those sites. | issue 603 |
| 2026-09-25 | **One host holds the truth; lockstep is dropped.** The host's machine runs the one simulation and every other player is its client. | `docs/wc3-engine-architecture.md` (Multiplayer Strategy), issue 803 |
| 2026-09-25 | The owner's personal details are never sent to an outside service unless the owner names that detail for that purpose. | `CLAUDE.md` (Privacy) |
| 2026-09-24 | MPQ archives are read through StormLib; the project's own reader was retired. | issue 114, `docs/formats/mpq-archive.md` |
| 2026-09-23 | **Assets pass between people over rmail**, "the only connection protocol for assets that I trust". 603's own transfer protocol is not built. | issue 609 |
| 2026-09-23 | **Stock unit and ability values come from the player's own WC3 install** at map load; nothing Blizzard-made is shipped. Community wikis are a cross-check only, never a source (their licence would bind the tables). | issue W02 (open question 4), issue 112 |
| 2026-09-23 | **Phase W: the WoW 3.3.5a client as an alternate host**, model source and test reference. Proprietary WoW files are read from the owner's client folder at run time and never committed. WC3 triggers run on the server through the ALE scripting engine (successor to Eluna, not script-compatible with it). | `docs/wow-client-bridge.md`, issues W01-W08 |
| 2026-09 | **The ceramic engine** is built as a second, measured render path beside the C renderer. Its one fixed rule: the host thread draws whatever state is present. The hand-written thread pool from issue 512 stays as the benchmark it must beat. | issue 515, `docs/render-architecture.md` |
| 2026-01-07 | **Pure WC3 engine; the AzerothCore integration was abandoned** (complexity against the preservation mission). Phase 7 and the WoW-mode issues were archived on 2026-01-08. Phase W (above) later brought the WoW client back as a *host*, not as the engine. | `docs/postmortem-azerothcore-integration.md`, `issues/archive/wow-mode-2026-01-08/` |
| 2026-01-02 | The renderer runs on the second threading design (a ring-buffer task pool); the first was removed, not wrapped. | `issues/completed/512f-main-integration.md` |
| 2025-12-31 | Camera transitions play back from frame arrays driven by a timer in the thread pool; each thread owns its copy of the data. | issue 409 |
| 2025-12-30 | **C draws; Lua writes render slots.** The vertical slice set this split: Lua never draws, it writes each unit's values into fixed slots and the draw thread only reads them. This replaced the plan for a Lua renderer interface with swappable backends (issues 501-507). | `issues/completed/508-vertical-slice-testing-room.md`, `docs/render-architecture.md` |
| 2025-12-29 | Coordinates are WC3-style, Y up, matching the game data. | this document's January version |
| 2025-12-29 | Raylib is the renderer. | this document's January version |

---

## 3. Open Questions

Each stays here until the owner answers it; then it moves to Decisions with
the answer and the date.

### Q-1: How do the three server routes relate?
**Reshapes:** 801 and its sub-issues, W02e, W08, 803

There are three ways a game can be hosted:
- the engine's own host inside a player's client (803), speaking this
  project's compact message records;
- AzerothCore with a shim that runs WC3 triggers as ALE scripts (W02e);
- our own server speaking the WoW client's protocol (W08), which W08 already
  calls the successor to the shim ("a stage-1 bridge only").

The first and third both run this project's own simulation as the one
authority and differ only in the wire format. If they are one simulation
with two front ends, the matchmaking protocol (801a) should reuse 803's
message layer instead of defining its own, and NAT traversal (801d) serves
only the open-client route.

### Q-4: Where do the missing render features go?
**Reshapes:** the rewrites from Q-3

- Does the UI framework (506) live in C next to the existing panel code, or
  in Lua writing into a buffer the C side draws? Given the split decided on
  2026-09-26 (section 2), the likely answer is: its per-frame layout is
  written into the page by C boxes, and the renderer draws it. Still to be
  confirmed by the owner.
- ~~Do terrain, unit and minimap features target the current C renderer,
  the ceramic path, or both?~~ Answered 2026-09-26: the backend is ceramic,
  the renderer is raylib, and C boxes build the page the renderer draws
  (section 2).

### Q-5: What closes the hunt for the remaining patch versions?
**Blocks:** 112b's completion

~~May the patch programs be downloaded?~~ Already done (the owner,
2026-09-26: "I thought we already downloaded most of them?"): layers are
built for 23 Frozen Throne versions and 20 Reign of Chaos versions
(`wc3-installs/patch-layers/`, `patch-layers-roc/`). What remains is 112b's
standing hunt ("hunt down every patch you can find"): the English Frozen
Throne versions 1.10, 1.12, 1.13, 1.15-1.18, 1.28.0-1.28.3 and 1.29.0, and
some Reign of Chaos ones, found on no mirror so far. Does 112b stay open
until they turn up, or does the hunt move to an issue of its own so 112b
can close on what is built?

### Q-6: Is the thread-pool library move (802) kept?
**Depends on:** 515f

The ceramic engine's plan keeps the hand-written pool as its benchmark. 802
would replace that pool with the shared library. Wait for 515f's verdict, or
retire 802 now?

### Q-7: Are the guild files still live?
**Affects:** `GUILD-ROSTER.md`, `Q00-adventurer-quest-log.md`,
`B01-the-phantom-priority.md`

The roster lists two bounties as unclaimed that are completed. The quest log's
paths still resolve. The bounty's bug is real (debt D-1). Keep them as the
way newcomers find work, or archive them and make D-1 an ordinary bugfix?

### Q-8: Phase 7 leftovers from before the pivot
**Affects:** ghost and spirit rules

The archived death system asked four questions about the spirit world (can
enemies see a ghost, can ghosts use abilities, what if the hero dies while
reviving, can corpses share a tile). They were never answered and are parked
with the archived issues. Kept here only so they are not mistaken for
answered if death rules come back.

---

## 4. Known Debt

Bugs knowingly left in the code. Each names the line as of 2026-09-26.

### D-1: A better path does not move a queued point forward
**Where:** `src/runtime/pathfinding/astar.lua`, around lines 355-358
**Tracking:** bounty B01

When the pathfinder finds a shorter route to a point already waiting in its
queue, it records the shorter distance but leaves the point at its old place
in the queue. The point is then taken out later than it should be, and the
search does extra work. The two standard remedies: move the point up in the
heap (a heap that can find and re-sort one entry), or push it a second time
and skip stale copies when they come out (costs memory).

### D-2: Straight-line test compares to exactly zero
**Where:** `src/runtime/pathfinding/smooth.lua`, line 80

Path smoothing drops a middle point when three points are in line, by
testing the cross product for exactly zero. With fractional coordinates,
rounding makes that rare, so some straight runs keep points they could drop.
Remedy: compare against a small threshold.

### D-3: Reading four bytes without checking there are four
**Where:** `src/compat.lua`, the LuaJIT branch of the 32-bit readers (around
line 168)

On LuaJIT the readers take four bytes without checking the data is long
enough. A truncated file fails on arithmetic with a missing value, which
names the wrong cause. Remedy: check the length and raise an error that says
the file is truncated and where.

Fixed since the January version: the timer that was never removed (bounty B02)
and the component defaults shared by every entity (bounty B03; each entity
now gets its own deep copy).

---

## 5. Documentation Drift

Places where a document disagrees with the code or with another document.

| Where | Says | Reality |
|-------|------|---------|
| `issues/progress.md` | only Phase W has a per-phase progress file | the dashboard warns for every other phase |
| 911, 912 | export to `.wowmap` and "both modes" | WoW mode was dropped; the editor saves `.w3x` (decided 2026-09-26); the design text is rewritten when Phase 9 starts |
| 601, `docs/wc3-engine-architecture.md`, `docs/roadmap.md` | player data in `~/.world-edit-engine/` or `~/.wc3-engine/` | player data lives in the project directory, movable by a config file (decided 2026-09-26); the paths wait on the folder's name inside the project |

---

## How to Use This Document

- **A new question** goes into section 3 with what it reshapes or blocks and
  the options as they stand. Write it into the affected issue too.
- **An answer** moves the question to section 2, with the date and the file
  where the reasoning is written down.
- **New debt** goes into section 4 with the file and line, and why it was
  left.
- **Drift** goes into section 5 when found, and comes out when fixed.
- **The path** in section 1 is redrawn whenever an issue on it completes.
