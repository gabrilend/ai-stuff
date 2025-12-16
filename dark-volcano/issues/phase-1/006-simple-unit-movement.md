# Issue 006: Simple Unit Movement System

## Current Behavior
Units have no movement capabilities.

## Intended Behavior
Units can move around the game world with smooth interpolation, pathfinding, and Tron-style light trails. Movement should feel responsive and visually appealing.

## Suggested Implementation Steps
1. Implement basic point-to-point movement
2. Add movement speed calculations based on unit stats
3. Create pathfinding system for obstacle avoidance
4. Implement smooth movement interpolation
5. Add Tron-style light trail effects for moving units
6. Create movement state management (idle, moving, blocked)
7. Add click-to-move or WASD movement controls
8. Implement formation movement for party groups

## Priority
High - Required for party management and combat

## Estimated Effort
2-3 weeks

## Dependencies
- Issue 001 (Project Setup)
- Issue 003 (Basic Unit System)
- Issue 005 (Tron Visual Style) for light trails

## Related Documents
- docs/game-design.md
- notes/vision (movement and light trail references)

## Acceptance Criteria
- Units move smoothly between positions
- Pathfinding avoids obstacles
- Light trails enhance visual appeal
- Performance good with multiple moving units
- Controls feel responsive