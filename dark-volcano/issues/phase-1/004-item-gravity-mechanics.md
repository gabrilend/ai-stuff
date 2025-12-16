# Issue 004: Item Gravity Mechanics

## Current Behavior
No item system or gravity mechanics exist.

## Intended Behavior
Items that are not actively held by a unit will sink into the ground at a rate of 2 inches per 10 seconds, eventually falling to the planet's core (dark volcano). Items must be actively carried or they will be lost.

## Suggested Implementation Steps
1. Design item base class with timer-based gravity
2. Implement simple countdown timer system (2 inches per 10 seconds)
3. Create item-unit attachment mechanics
4. Add visual effects for sinking items (gradual fade/sink animation)
5. Implement item pickup and drop functionality
6. Create "held item" status and visual indicators
7. Add despawn functionality when timer reaches zero
8. Implement automatic item dropping when unit dies/sleeps

## Priority
Medium - Unique core mechanic but not blocking

## Estimated Effort
2-3 weeks

## Dependencies
- Issue 001 (Project Setup)
- Issue 003 (Basic Unit System)

## Related Documents
- notes/vision (lines 82-96)
- docs/game-design.md
- docs/technical-overview.md (lines 45-47: simple timer-based gravity)
- notes/technical-overview.md

## Technical Notes
- Gravity is timer-based, not physics simulation
- Items despawn after timer expires (don't need complex physics)
- Focus on visual feedback rather than realistic physics
- Performance-optimized approach

## Acceptance Criteria
- Items sink when not held
- Units can pick up and carry items
- Visual feedback shows item status
- Performance acceptable with many items