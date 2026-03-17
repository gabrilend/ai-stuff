# Phase 10 Progress

## Phase Goal

Input refinements and dynamic stage expansion. Improve player control and add purchasable board extensions with new obstacle types.

## Issues

| ID   | Description                        | Status    |
|------|------------------------------------|-----------|
| 1001 | Reticle toggle mouse control       | Completed |
| 1002 | Stage system architecture          | Pending   |
| 1003 | Dynamic world vertical expansion   | Pending   |
| 1004 | Multi-row gate system              | Pending   |
| 1005 | Ramp obstacle type                 | Pending   |
| 1006 | Stage 2 ramp layout                | Pending   |
| 1007 | Stage insertion animation          | Pending   |
| 1008 | Next stage upgrade integration     | Pending   |
| 1009 | Ball screen wrapping               | Completed |
| 1010 | Low-speed impact damage reduction  | Completed |

## Progress Summary

**Completed:** 3/10 issues (30%)
**Phase 10:** In Progress

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
