# 005 - Project Roadmap

## Overview

The project is organized into 9 functional phases representing team workstreams.
Phases are NOT sequential - they can be worked on in parallel based on issue-level
dependencies. See `issues/phase-X-progress.md` for detailed status.

## Current Status Summary

| Phase | Theme               | Complete | In Progress | Awaiting | Blocked |
|-------|---------------------|----------|-------------|----------|---------|
| 1     | Core Infrastructure | 12/13    | 0           | 1        | 0       |
| 2     | World & Physics     | 26/27    | 0           | 1        | 0       |
| 3     | Feedback Systems    | 21/21    | 0           | 0        | 0       |
| 4     | Display             | 12/13    | 0           | 1        | 0       |
| 5     | Gameplay            | 11/11    | 0           | 0        | 0       |
| 6     | Competition         | 12/12    | 0           | 0        | 0       |
| 7     | Stages              | 11/11    | 0           | 0        | 0       |
| 8     | Editor              | 38/40    | 1           | 1        | 0       |
| 9     | Dynamic Systems     | 17/19    | 2           | 0        | 0       |

**Overall: 160/167 issues complete (96%)**

---

## Sprint Report

### Current Sprint Goals

**Team A - Infrastructure (3 issues)**
- 113: Config file self-edit and validation
- 901h: Parallel rotor updates
- 902h: Parallel mover updates

**Team B - Physics (2 issues)**
- 222: Trajectory history
- 901f: Ball crushing

**Team C - Track Movers (COMPLETE)**
- 902e: Intersection path selection ✓
- 902f: Back and forth motion ✓
- 902g: Track ball interaction ✓

**Team D - UI/Editor (3 issues)**
- 837: Finish polygon testing
- 409: Collapsible drawer UI
- 840: Editor grid density sliders

**Sprint Target:** 11 issues (ambitious but achievable)

### Previous Sprint Completed (10 issues)

- **221** - Ball sleep system complete (Phase 2) - all sub-issues done
- **221b** - Sleep transition logic (Phase 2)
- **221c** - Wake conditions (Phase 2)
- **221e** - Stress source distinction (Phase 2)
- **316** - Multiple gate scoring (Phase 3)
- **317** - GateRow scoring fix (Phase 3)
- **610** - Remove adversary board tinting (Phase 6)
- **612** - Adversary portal flow reversal (Phase 6)
- **901b** - Editor rotor placement tool (Phase 9)
- **901c** - Line rotation physics (Phase 9)
- **902b** - Editor track drawing tool (Phase 9)

### New Issues Added This Session

- **113** - Config file self-edit (Phase 1)
- **901h** - Parallel rotor updates (Phase 9)
- **902h** - Parallel mover updates (Phase 9)

---

## Parallelization Opportunities

### Immediate (No Blockers)

These issues can be picked up right now:

```
INFRASTRUCTURE:
  113  - Config file self-edit (Phase 1) - rename to ./config, add validation

PHYSICS TEAM:
  222  - Trajectory history (Phase 2) - overlap nudge for stuck balls

UI TEAM:
  409  - Collapsible drawer UI (Phase 4)
  840  - Editor grid density sliders (Phase 8)

DYNAMIC SYSTEMS TEAM:
  (All Phase 9 sub-issues complete - team reassigned)
```

### In Progress

Currently being worked on:

```
  837  - Closed polygon detection (Phase 8) - testing phase
  901  - Rotor system (Phase 9) - parent issue only (8/8 sub-issues done)
  902  - Track mover system (Phase 9) - parent issue only (8/8 sub-issues done)
```

### Parallelization Priority

901h and 902h already implemented:
- Both follow the same task pattern (prepare → submit → wait_all)
- Rotor and mover updates write to disjoint object sets
- Share a single sync point before ball physics
- Reference: ball/particle parallelization in src/007-ball.c, src/009-particles.c

---

## Phase Details

### Phase 1: Core Infrastructure

**Complete (12):** Build system, threadpool, parallel processing, compile-time config

**Awaiting Work:**
- 113 - Config file self-edit (rename config.txt, make executable with $EDITOR)

---

### Phase 2: World & Physics

**Complete (26):** World state, pegs, physics, wrap zones, sleep system (221 + all sub-issues), stress distinction

**Awaiting Work:**
- 222 - Trajectory history (partial) - overlap nudge for stuck balls

---

### Phase 3: Feedback Systems (Complete)

All 21 issues complete.

---

### Phase 4: Display

**Complete (12):** Scrolling, resize, reticle, panel UI, hide keybind, min width, background colors

**Awaiting Work:**
- 409 - Collapsible drawer UI

---

### Phase 5: Gameplay (Complete)

All 11 issues complete.

---

### Phase 6: Competition (Complete)

All 12 issues complete.

---

### Phase 7: Stages (Complete)

All 11 issues complete.

---

### Phase 8: Editor (In Progress)

**Complete (38):** Full editor, standalone app, materials selector, board standardization

**In Progress:**
- 837 - Closed polygon detection (testing with various shapes)

**Awaiting Work:**
- 840 - Editor grid density sliders

**Note:** 838 (board standardization) complete. 840 adds UI for grid density.

---

### Phase 9: Dynamic Systems (Near Complete)

**Complete (17):** 901a-h, 902a-h, 903

**In Progress:**
- 901 - Rotor system (parent) - all sub-issues complete
- 902 - Track mover system (parent) - all sub-issues complete

**Awaiting Work (0):** None

**Blocked (0):** None

**Note:** Parent issues 901 and 902 remain open for umbrella tracking only.

---

## Recommended Team Assignments

For maximum parallelization with 4 teams:

| Team | Primary Focus | Issues | Est. Complexity |
|------|---------------|--------|-----------------|
| A - Infrastructure | Config | 113 | Low |
| B - Physics | Ball behavior | 222 | Medium |
| C - Track Movers | COMPLETE | - | - |
| D - UI/Editor | Polish and tools | 837 (finish), 409, 840 | Medium |

### Team A - Infrastructure
- **113**: Config file self-edit with validation (quick win)
- *Note: 901h and 902h already complete*

### Team B - Physics
- **222**: Trajectory history for stuck ball detection
- *Note: 901f ball crushing already complete*

### Team C - Track Movers (COMPLETE)
- All sub-issues (902e, 902f, 902g) completed
- Team can be reassigned to help other tracks

### Team D - UI/Editor
- **837**: Finish polygon detection testing
- **409**: Collapsible drawer UI
- **840**: Editor grid density sliders
- *Note: Independent issues, can parallelize*

---

## Sprint Velocity

| Sprint | Completed | Phases Touched |
|--------|-----------|----------------|
| N-2    | 12        | 6              |
| N-1    | 7         | 3              |
| N      | 9         | 4              |

**Remaining open issues:** 7
- 4 awaiting work (113, 222, 409, 840)
- 3 in progress (837, 901, 902 - parents only)
- 0 blocked

At current velocity (~8 issues/sprint): ~1 sprint to completion.

---

## Phases Complete: 5/9 (56%)

- Phase 3: Feedback Systems
- Phase 5: Gameplay
- Phase 6: Competition
- Phase 7: Stages

---

## Future Considerations

### Optimization (not scheduled)
- Spatial partitioning for collision
- SIMD physics calculations
- Memory pool for ball allocation
- Target: 500+ balls at 60fps

### Potential New Features
- Sound system integration
- Additional obstacle types
- Multiplayer networking
- Mobile/touch support
