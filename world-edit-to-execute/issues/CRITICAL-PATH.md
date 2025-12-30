# Critical Path Document

```
╔══════════════════════════════════════════════════════════════════╗
║                                                                  ║
║   📍 CRITICAL PATH - Decision Points & Open Questions            ║
║                                                                  ║
║   "The relevance of this document increases with use."          ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
```

**Last Updated:** 2025-12-30
**Maintainer:** Project contributors
**Location:** `issues/CRITICAL-PATH.md` (symlinked to `docs/critical-path.md`)

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

### OQ-003: Dual Interface Mode Strategy
**Priority:** 🟡 MEDIUM
**Affects:** Phase 5, overall architecture
**Status:** DECIDED
**Source:** Issue 500

How should Warcraft RTS mode and WoW-Chat mode coexist?

| Option | Description |
|--------|-------------|
| Runtime toggle | Switch during gameplay |
| Startup selection | Choose before launch |
| Separate builds | Different executables |
| Parallel views | Both visible simultaneously |
| **API-driven** | Data-driven integration layer |

**Decision:** API-style data-driven approach. WoW-chat integration is integral
to the process. AzerothCore integrates with world-edit-to-execute via shared
data APIs. Both systems consume the same underlying game state.
**Decided by:** User
**Date:** 2025-12-29

---

### OQ-004: Development Priority (WC3 vs WoW-Chat)
**Priority:** 🟡 MEDIUM
**Affects:** Feature prioritization, Phase 5-7
**Status:** DECIDED
**Source:** Issue 500

Which interface gets primary development focus?

| Option | Implication |
|--------|-------------|
| Warcraft first | RTS features before social features |
| Chat first | Social/text features before visual game |
| Parallel | Both developed simultaneously |
| Equal | Features alternate between modes |
| **Integrated** | Single data layer, multiple consumers |

**Decision:** Integrated approach - WoW-chat is not a separate mode but an
integral part of the system. Build the data/API layer that both WC3 visuals
and AzerothCore can consume. The engine becomes the shared truth.
**Decided by:** User
**Date:** 2025-12-29

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

### IF-003: Phase 4 Integration (408)
**Status:** 1/5 complete
**Blocking:** Phase 4 demo

| Sub-Issue | Status |
|-----------|--------|
| 408a (unit tests core) | ✗ Pending |
| 408b (unit tests entity) | ✗ Pending |
| 408c (unit tests player) | ✗ Pending |
| 408d (integration scenario) | ✓ Complete |
| 408e (visual demo) | ✗ Pending |

**Action:** Complete 408a-c, 408e for Phase 4 closure

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
    ├── Requires: OQ-001 (renderer target)
    ├── Requires: OQ-002 (coordinate system)
    └── Requires: OQ-003 (dual interface strategy)

Phase 7 (Gameplay)
    │
    ├── 701 (Death) requires: OQ-005 (ghost mechanics)
    └── 702 (Professions) requires: IF-001 completion

Phase 4 Completion
    │
    ├── Requires: IF-002 (405d collision)
    └── Requires: IF-003 (408 integration tests)
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

