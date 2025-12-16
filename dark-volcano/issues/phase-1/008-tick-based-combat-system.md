# Issue 008: Tick-Based Combat System

## Current Behavior
No combat system exists.

## Intended Behavior
Implement tick-based combat where damage is calculated as rates that slowly reduce enemy health. Visual animations are separate from calculations. Health displays as both hidden linear gradient and visible chunked "4 quarters to a heart" style.

## Suggested Implementation Steps
1. Design combat calculation system with damage rates
2. Implement health system with dual representations:
   - Hidden: Linear gradient health bar for calculations
   - Visible: Chunked health display (4 quarters per heart)
3. Create damage tick system that applies damage over time
4. Implement visual combat animations (separate from calculations)
5. Add final swing reconciliation between hidden/visible health
6. Create laser weapon visual effects (ricochet, explosion, reformation)
7. Implement collision detection for animation purposes
8. Add particle effects for visual appeal

## Priority
Medium - Core combat mechanic but depends on units and visual system

## Estimated Effort
4-5 weeks

## Dependencies
- Issue 001 (Project Setup)
- Issue 003 (Basic Unit System)
- Issue 005 (Tron Visual Style)

## Related Documents
- docs/technical-overview.md (lines 22-35: Combat system details)
- notes/technical-overview.md
- notes/vision (combat descriptions)

## Technical Notes
- Combat calculations are separate from visual animations
- Damage applied as rates, not instant hits
- Health reconciliation ensures smooth visual feedback
- Collision detection primarily for animation, not core mechanics
- Focus on visual spectacle while maintaining performance

## Acceptance Criteria
- Combat feels smooth and responsive
- Health system accurately represents damage taken
- Visual effects enhance combat without impacting performance
- Laser weapon mechanics work as described in vision
- Final swing properly reconciles health differences