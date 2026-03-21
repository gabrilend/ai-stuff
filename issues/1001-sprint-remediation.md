# 1001 - Sprint Remediation

## Status: Open

## Problem

After several Phase 9 sprints without review, the physics simulator has accumulated multiple interconnected bugs affecting all major systems:

1. Strange textures painted all over the place
2. Player balls don't spawn (adversary balls work)
3. Balls hitting invisible obstacles
4. Obstacles in wrong places (physics positions differ from render positions)
5. Lines all over the place that don't belong
6. Wrap zones not working (adversary balls not removed from top)
7. Particle effects broken (only left side, multiple spawns)
8. Window resize affects ball physics (balls don't shift with table)

## Root Cause

The primary root cause appears to be a **coordinate system mismatch** introduced during Phase 9 development. Multiple systems calculate positions differently:

- Grid-to-pixel conversion in `main.c` uses `grid_to_pixel_x/y`
- Polygon manager uses `obj->col * cell_size + cell_size / 2.0f`
- Adversary board flip formula `grid_rows - obj->row` has off-by-one error
- Slot manager positions may have drifted from actual usage

## Related Documentation

- `docs/sprint-remediation-report.md` - Full investigation report
- `issues/completed/837-closed-polygon-detection-and-fill.md`
- `issues/completed/901-rotor-system.md`
- `issues/completed/902-track-mover-system.md`

## Sub-Issues

| ID | Description | Status |
|----|-------------|--------|
| 1001a | Player ball spawn failure | Closed (Not a Bug) |
| 1001b | Coordinate system unification | Complete |
| 1001c | Adversary board flip formula | Complete |
| 1001d | Debug rendering cleanup | Complete |
| 1001e | Wrap zone positioning | Needs Testing |
| 1001f | Particle effect positioning | Needs Testing |
| 1001g | Polygon fill alignment | Complete (merged with 1001b) |
| 1001h | Window resize affects physics | Complete |

## Intended Behavior

After remediation, the game should:

1. Spawn player balls when SPACE is pressed
2. Render all objects at their collision positions
3. Have no spurious visual artifacts (lines, textures)
4. Wrap balls correctly at screen boundaries
5. Trigger particle effects at correct positions for all gates

## Suggested Implementation Steps

1. Fix player spawning first (critical functionality)
2. Unify coordinate system across all modules
3. Fix adversary flip formula
4. Disable debug rendering by default
5. Fix wrap zone position calculations
6. Fix particle effect positioning
7. Integration test full ball lifecycle

## Testing Criteria

- [ ] Player balls spawn when SPACE is pressed
- [ ] Adversary balls spawn and move correctly
- [ ] No invisible obstacles
- [ ] All pegs/lines render at correct positions
- [ ] No spurious lines or textures
- [ ] Balls wrap at screen edges correctly
- [ ] Particle effects trigger at all gate zones
- [ ] Particle effects trigger only once per gate passage

## Notes

- Begin with quick diagnostic prints to identify exact failure points
- The slot manager is the source of truth for vertical positioning - verify first
- Many issues may resolve once coordinate system is unified
