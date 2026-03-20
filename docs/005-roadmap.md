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
| 9     | Dynamic Systems     | 11/19    | 2           | 6        | 0       |

**Overall: 154/167 issues complete (92%)**

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

**Team C - Track Movers (3 issues)**
- 902e: Intersection path selection
- 902f: Back and forth motion
- 902g: Track ball interaction

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
  901f - Ball crushing (Phase 9) - uses 221e stress system
  901h - Parallel rotor updates (Phase 9) - follows ball/particle pattern
  902e - Intersection path selection (Phase 9)
  902f - Back and forth motion (Phase 9)
  902g - Track ball interaction (Phase 9) - uses 221e stress system
  902h - Parallel mover updates (Phase 9) - follows ball/particle pattern
```

### In Progress

Currently being worked on:

```
  837  - Closed polygon detection (Phase 8) - testing phase
  901  - Rotor system (Phase 9) - parent issue, 6/8 sub-issues done
  902  - Track mover system (Phase 9) - parent issue, 4/8 sub-issues done
```

### Parallelization Priority

901h and 902h can be implemented together:
- Both follow the same task pattern (prepare → submit → wait_all)
- Rotor and mover updates write to disjoint object sets
- Can share a single sync point before ball physics
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

### Phase 9: Dynamic Systems (In Progress)

**Complete (11):** 901a, 901b, 901c, 901d, 901e, 901g, 902a, 902b, 902c, 902d, 903

**In Progress:**
- 901 - Rotor system (parent)
- 902 - Track mover system (parent)

**Awaiting Work (6):**
- 901f - Ball crushing [UNBLOCKED]
- 901h - Parallel rotor updates [NEW]
- 902e - Intersection path selection [UNBLOCKED]
- 902f - Back and forth motion [UNBLOCKED]
- 902g - Track ball interaction [UNBLOCKED]
- 902h - Parallel mover updates [NEW]

**Blocked (0):** None

---

## Recommended Team Assignments

For maximum parallelization with 4 teams:

| Team | Primary Focus | Issues | Est. Complexity |
|------|---------------|--------|-----------------|
| A - Infrastructure | Config + Parallelization | 113, 901h, 902h | Low-Medium |
| B - Physics | Ball behavior | 222, 901f | Medium-High |
| C - Track Movers | Complete track system | 902e, 902f, 902g | Medium |
| D - UI/Editor | Polish and tools | 837 (finish), 409, 840 | Medium |

### Team A - Infrastructure
- **113**: Config file self-edit with validation (quick win)
- **901h**: Parallel rotor updates (follows existing pattern)
- **902h**: Parallel mover updates (same pattern as 901h)
- *Note: 901h and 902h can share implementation approach*

### Team B - Physics
- **222**: Trajectory history for stuck ball detection
- **901f**: Ball crushing mechanics (builds on 221e stress system)
- *Note: Both involve ball state tracking*

### Team C - Track Movers
- **902e**: Intersection path selection
- **902f**: Back and forth motion
- **902g**: Track ball interaction (needs 901f crushing shared code)
- *Note: Sequential dependencies, but can start 902e/f in parallel*

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

**Remaining open issues:** 13
- 10 awaiting work (can start now)
- 3 in progress (837, 901, 902)
- 0 blocked

At current velocity (~8 issues/sprint): ~2 sprints to completion.

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
