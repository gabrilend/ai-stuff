# 005 - Project Roadmap

## Overview

The project is organized into 9 functional phases representing team workstreams.
Phases are NOT sequential - they can be worked on in parallel based on issue-level
dependencies. See `issues/phase-X-progress.md` for detailed status.

## Current Status Summary

| Phase | Theme               | Complete | Awaiting | Blocked |
|-------|---------------------|----------|----------|---------|
| 1     | Core Infrastructure | 12/12    | 0        | 0       |
| 2     | World & Physics     | 20/27    | 3        | 4       |
| 3     | Feedback Systems    | 16/20    | 4        | 0       |
| 4     | Display             | 8/12     | 3        | 1       |
| 5     | Gameplay            | 10/11    | 1        | 0       |
| 6     | Competition         | 9/11     | 2        | 0       |
| 7     | Stages              | 11/11    | 0        | 0       |
| 8     | Editor              | 36/39    | 3        | 0       |
| 9     | Dynamic Systems     | 0/17     | 5        | 12      |

---

## Parallelization Opportunities

### Immediate (No Blockers)

These issues can be picked up right now by different team members:

```
PHYSICS TEAM:
  221a - Sleep state tracking (Phase 2)
  221d - Soft collision response (Phase 2)
  222  - Trajectory history (Phase 2)

FEEDBACK TEAM:
  316  - Multiple gate scoring (Phase 3)
  317  - GateRow scoring bug (Phase 3)
  318  - Zone dispatch system (Phase 3) [solves 316+317]
  319  - Random ball colors (Phase 3)

UI TEAM:
  406  - Editor panel UI system (Phase 4)
  407  - Hide game UI keybind (Phase 4)
  408  - Minimum window width (Phase 4)

GAMEPLAY TEAM:
  507  - Adversary spawn toggle (Phase 5)
  609  - Separate player/adversary scores (Phase 6)
  610  - Remove adversary board tinting (Phase 6)

EDITOR TEAM:
  837  - Closed polygon detection (Phase 8)
  838  - Standardize board dimensions (Phase 8)
  839  - Material type selector (Phase 8)

DYNAMIC SYSTEMS TEAM:
  901a - Rotor data structure (Phase 9)
  902a - Track data structure (Phase 9)
  903  - Ball velocity statistics (Phase 9)
```

### After Dependencies Met

These unlock once their blockers complete:

```
After 221a:
  → 221b (Sleep transition logic)
  → 221c (Wake conditions)

After 221d:
  → 221e (Stress distinction) → unlocks 901f, 902g

After 406 + 408:
  → 409 (Collapsible drawer UI)

After 901a:
  → 901b, 901c, 901d (Editor tool, rotation, detection)

After 902a:
  → 902b, 902c, 902d (Editor tool, payload, physics)

After 901c + 901d:
  → 901e (Collision modes)

After 901e + 221e:
  → 901f (Ball crushing)

After 902d:
  → 902e, 902f (Intersection selection, back-and-forth)

After 902d + 221e:
  → 902g (Track ball interaction)
```

---

## Phase Details

### Phase 1: Core Infrastructure (Complete)

Foundation: build system, threadpool, parallel processing, config.

- Issues 101-112
- All complete

---

### Phase 2: World & Physics

World structure, ball physics, wrapping, sleep system.

**Complete (20):** World state, pegs, scoring, physics, collisions, wrap zones

**Awaiting Work:**
- 221a - Sleep state tracking
- 221d - Soft collision response
- 222  - Trajectory history

**Blocked:**
- 221b, 221c (by 221a)
- 221e (by 221d)

**Cross-Phase Impact:** 221e blocks 901f and 902g (crushing mechanics)

---

### Phase 3: Feedback Systems

Scoring, particles, visual feedback.

**Complete (16):** Scoring, particles, double-buffering, parallelization

**Awaiting Work (all independent):**
- 316 - Multiple gate scoring
- 317 - GateRow scoring bug
- 318 - Zone dispatch system
- 319 - Random ball colors

**Note:** 318 provides comprehensive solution for 316 and 317

---

### Phase 4: Display

Viewport, UI, reticle.

**Complete (8):** Scrolling, resize, reticle fixes

**Awaiting Work:**
- 406 - Editor panel UI system
- 407 - Hide game UI keybind
- 408 - Minimum window width

**Blocked:**
- 409 (by 406, 408)

---

### Phase 5: Gameplay

Spawn system, upgrades.

**Complete (10):** Auto-spawn, movable spawn, buffering, upgrade system

**Awaiting Work:**
- 507 - Adversary spawn toggle keybind

---

### Phase 6: Competition

Adversary AI, combat, portals.

**Complete (9):** Adversary board, AI, shared gates, damage system

**Awaiting Work:**
- 609 - Separate player/adversary scores
- 610 - Remove adversary board tinting

---

### Phase 7: Stages (Complete)

Stage system, dynamic expansion, ramps.

- Issues 701-711
- All complete

---

### Phase 8: Editor

Visual board editor with JSON storage.

**Complete (36):** Full editor functionality, standalone app, file management

**Awaiting Work (all independent):**
- 837 - Closed polygon detection and fill
- 838 - Standardize board dimensions
- 839 - Material type selector

---

### Phase 9: Dynamic Systems

Rotors, track movers, analysis tools.

**Entry Points (no blockers):**
- 901a - Rotor data structure
- 902a - Track data structure
- 903  - Ball velocity statistics

**Dependency Chain - Rotors:**
```
901a → 901b (editor tool)
     → 901c (rotation physics)
     → 901d (connected detection)
           ↓
         901e (collision modes)
           ↓
         901f (ball crushing) ← also needs 221e

901b → 901g (direction UI)
```

**Dependency Chain - Tracks:**
```
902a → 902b (editor tool)
     → 902c (payload detection)
     → 902d (following physics)
           ↓
         902e (intersection selection)
         902f (back-and-forth)
         902g (ball interaction) ← also needs 221e
```

---

## Recommended Team Assignments

For maximum parallelization with 4 developers:

| Developer | Primary Focus | Secondary |
|-----------|---------------|-----------|
| A | Phase 2 (221a/d, 222) | Phase 9 (903) |
| B | Phase 3 (318) | Phase 4 (406, 407) |
| C | Phase 8 (837, 839) | Phase 5/6 (507, 609) |
| D | Phase 9 (901a, 902a) | Phase 4 (408) |

After initial work completes, reassign based on unblocked issues.

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
