# Phase 10 Progress

## Phase Goal

Input refinements and dynamic stage expansion. Improve player control and add purchasable board extensions with new obstacle types.

## Issues

| ID   | Description                        | Status    |
|------|------------------------------------|-----------|
| 1001 | Reticle toggle mouse control       | Completed |
| 1002 | Stage system architecture          | Completed |
| 1003 | Dynamic world vertical expansion   | Completed |
| 1004 | Multi-row gate system              | Completed |
| 1005 | Ramp obstacle type                 | Completed |
| 1006 | Stage 2 ramp layout                | Completed |
| 1007 | Stage insertion animation          | Completed |
| 1008 | Next stage upgrade integration     | Completed |
| 1009 | Ball screen wrapping               | Completed |
| 1010 | Low-speed impact damage reduction  | Completed |

## Progress Summary

**Completed:** 10/10 issues (100%)
**Phase 10:** Complete

## Notes

Phase 10 combines two feature sets:

### Input Refinements (1001)
Toggle-based mouse control for the reticle, giving players deliberate control over spawn position.

### Dynamic Stage Expansion (1002-1008)
Major feature allowing players to purchase additional board stages at runtime:

**Architecture (1002-1003):**
- Stage abstraction encapsulating board sections
- Dynamic world height expansion
- Position shifting for existing content

**Gate System (1004):**
- Multiple gate rows between stages
- Value multipliers (2x for deeper stages)
- Visual differentiation for high-value gates

**Ramp Obstacles (1005-1006):**
- New diagonal obstacle type
- Redirects balls horizontally
- Stage 2 uses converging ramp pattern to funnel balls to center

**Integration (1007-1008):**
- Smooth animation when stages are purchased
- New upgrade menu option for stage purchases
- Physics paused during expansion animation

### Ball Physics Improvements (1009-1010)
Gameplay refinements for ball behavior:

**Screen Wrapping (1009):**
- Balls exiting bottom reappear at top (player balls)
- Balls exiting top reappear at bottom (adversary balls)
- Preserves position, velocity, and health through wrap

**Damage Scaling (1010):**
- Low-speed impacts deal minimal/no damage
- Threshold-based system for significant collisions only
- Prevents death from gentle bumps

## Implementation Summary

### Files Created
- `src/014-stage.h` - Stage, StageManager, GateRow structs
- `src/015-stage.c` - Stage system implementation
- `src/016-ramp.h` - Ramp obstacle type
- `src/017-ramp.c` - Ramp collision physics
- `src/018-expansion-anim.h` - Expansion animation state machine
- `src/019-expansion-anim.c` - Animation update and camera control

### Key Changes
- `src/010-upgrades.h/c` - Added UPGRADE_NEXT_STAGE with callback system
- `src/004-world.h/c` - Added StageManager pointer, expansion functions
- `src/006-ball.h/c` - Added expansion handling, ramp collision
- `src/001-main.c` - Stage purchase callback, animation integration, stage rendering

### Architecture Decisions
- Stage manager created lazily on first stage purchase
- Stages own their own obstacle arrays (pegs or ramps)
- Gate rows between stages have configurable multipliers
- Animation uses camera zoom and physics pause for visual clarity
- Ramp collision uses line-segment closest-point algorithm

## Dependencies

Phase 9 must be complete (parallel particle system provides stable foundation).

## Suggested Implementation Order

**Independent issues (can be done in any order):**
1. **1001** - Reticle toggle
2. **1009** - Ball screen wrapping
3. **1010** - Low-speed damage reduction

**Stage expansion (sequential):**
4. **1002** - Stage architecture (foundation)
5. **1005** - Ramp obstacle type (can parallel with 1003)
6. **1003** - World expansion (needs 1002)
7. **1004** - Gate system (needs 1002, 1003)
8. **1006** - Stage 2 layout (needs 1002, 1005)
9. **1007** - Animation (needs 1002, 1003)
10. **1008** - Upgrade integration (needs all above)
