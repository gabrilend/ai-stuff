# 005 - Project Roadmap

## Overview

The project is organized into 9 functional phases representing team workstreams.
Phases are NOT sequential - they can be worked on in parallel based on issue-level
dependencies. See `issues/phase-X-progress.md` for detailed status.

## Current Status Summary

| Phase | Theme               | Complete | In Progress | Awaiting | Blocked |
|-------|---------------------|----------|-------------|----------|---------|
| 1     | Core Infrastructure | 12/12    | 0           | 0        | 0       |
| 2     | World & Physics     | 25/27    | 1           | 1        | 0       |
| 3     | Feedback Systems    | 21/21    | 0           | 0        | 0       |
| 4     | Display             | 11/13    | 0           | 2        | 0       |
| 5     | Gameplay            | 11/11    | 0           | 0        | 0       |
| 6     | Competition         | 12/12    | 0           | 0        | 0       |
| 7     | Stages              | 11/11    | 0           | 0        | 0       |
| 8     | Editor              | 37/40    | 1           | 2        | 0       |
| 9     | Dynamic Systems     | 10/17    | 2           | 5        | 0       |

**Overall: 150/164 issues complete (91%)**

---

## Sprint Report

### Last Sprint Completed (9 issues across 4 phases)

- **221b** - Sleep transition logic (Phase 2)
- **221e** - Stress source distinction (Phase 2)
- **316** - Multiple gate scoring (Phase 3)
- **317** - GateRow scoring fix (Phase 3)
- **610** - Remove adversary board tinting (Phase 6)
- **612** - Adversary portal flow reversal (Phase 6)
- **901b** - Editor rotor placement tool (Phase 9)
- **901c** - Line rotation physics (Phase 9)
- **902b** - Editor track drawing tool (Phase 9)

### Phase 6: Competition - COMPLETE

All 12 issues done.

### New Issues Added

- **321** - Fragment direction duplication (Phase 3) - FRAG_TANGENT bug fix
- **413** - Background color options (Phase 4) - config/CLI color presets
- **840** - Editor grid density sliders (Phase 8)

---

## Parallelization Opportunities

### Immediate (No Blockers)

These issues can be picked up right now:

```
PHYSICS TEAM:
  221c - Wake conditions (Phase 2) [UNBLOCKED]
  222  - Trajectory history (Phase 2) - partial

FEEDBACK TEAM:
  319  - Random ball colors (Phase 3) - includes particle color integration
  321  - Fragment direction duplication (Phase 3) [NEW]

UI TEAM:
  409  - Collapsible drawer UI (Phase 4)
  413  - Background color options (Phase 4) [NEW]

EDITOR TEAM:
  838  - Remove redundant pixel data from JSON (Phase 8)
  840  - Editor grid density sliders (Phase 8) [NEW]

DYNAMIC SYSTEMS TEAM:
  901d - Connected object detection (Phase 9)
  901g - Direction config UI (Phase 9) [UNBLOCKED]
  902c - Mover payload detection (Phase 9)
  902d - Track following physics (Phase 9)
```

### In Progress

Currently being worked on:

```
  221  - Ball sleep system (Phase 2) - parent issue
  837  - Closed polygon detection (Phase 8) - testing phase
  901  - Rotor system (Phase 9) - parent issue
  902  - Track mover system (Phase 9) - parent issue
```

### After Dependencies Met

These unlock once their blockers complete:

```
After 901d:
  → 901e (Collision modes) - 901c already done

After 902d:
  → 902e (Intersection path selection)
  → 902f (Back and forth motion)
  → 902g (Track ball interaction) - 221e already done

After 901e:
  → 901f (Ball crushing) - 221e already done
```

---

## Phase Details

### Phase 1: Core Infrastructure (Complete)

All 12 issues complete.

---

### Phase 2: World & Physics (In Progress)

**Complete (24):** World state, pegs, physics, wrap zones, sleep state, soft collision, stress distinction

**In Progress:**
- 221 - Ball sleep system (parent)

**Awaiting Work:**
- 221c - Wake conditions [UNBLOCKED]
- 222 - Trajectory history (partial)

---

### Phase 3: Feedback Systems (Complete)

All 21 issues complete.

---

### Phase 4: Display

**Complete (11):** Scrolling, resize, reticle, panel UI, hide keybind, min width

**Awaiting Work:**
- 409 - Collapsible drawer UI
- 413 - Background color options [NEW]

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

**Complete (37):** Full editor, standalone app, materials selector

**In Progress:**
- 837 - Closed polygon detection (testing with various shapes)

**Awaiting Work:**
- 838 - Remove redundant pixel data from JSON
- 840 - Editor grid density sliders [NEW]

**Note:** 838 and 840 are complementary - fixed board size, calculated cell size.

---

### Phase 9: Dynamic Systems (In Progress)

**Complete (10):** 901a, 901b, 901c, 901d, 901e, 902a, 902b, 902c, 902d, 903

**In Progress:**
- 901 - Rotor system (parent)
- 902 - Track mover system (parent)

**Awaiting Work (5):**
- 901f - Ball crushing
- 901g - Direction config UI
- 902e - Intersection path selection [UNBLOCKED]
- 902f - Back and forth motion [UNBLOCKED]
- 902g - Track ball interaction [UNBLOCKED]

**Blocked (0):** None

---

## Recommended Team Assignments

For maximum parallelization with 4 developers:

| Developer | Primary Focus | Secondary |
|-----------|---------------|-----------|
| A | Phase 2: 221c | Phase 3: 319, 321 |
| B | Phase 9: 901f, 901g | Phase 4: 409, 413 |
| C | Phase 9: 902e, 902f, 902g | Phase 8: 840 |
| D | Phase 8: 837 (finish), 838 | - |

**Critical Path:** 901d → 901e → 901f and 902d → 902e/f/g

---

## Sprint Velocity

| Sprint | Completed | Phases Touched |
|--------|-----------|----------------|
| N-2    | 12        | 6              |
| N-1    | 7         | 3              |
| N      | 9         | 4              |

**Remaining open issues:** 18
- 10 awaiting work (can start now)
- 4 in progress
- 4 blocked

At current velocity (~8 issues/sprint): ~2 sprints to completion.

---

## Phases Complete: 6/9 (67%)

- Phase 1: Core Infrastructure
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
