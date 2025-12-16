# Issue 002: 3x3 Party Composition Grid Interface

## Current Behavior
No party composition system exists.

## Intended Behavior
Interactive 3x3 strategic grid with three balanced formation options: Circle Formation (7 enhanced units), Box with Aura (5 enhanced + 4 normal), and Box without Aura (9 normal units). All formations designed to be approximately equal in power. Grid provides visual feedback for formation types, aura coverage, and power balance indicators.

## Suggested Implementation Steps
1. Design 3x3 grid UI layout and visual style (Tron-inspired)
2. Implement grid data structure for tracking unit positions and formation types
3. Create drag-and-drop functionality for unit placement
4. Implement Circle vs Box formation detection system
5. Add aura unit identification and center position validation for Box formations
6. Create aura calculation system based on affected unit count
7. Implement aura persistence for Circle formations (maintains effect when units separate)
8. Add visual feedback for formation types and aura coverage areas
9. Create formation validation (Circle: exactly 7 units, Box: 1-9 units)
10. Add grid highlighting for Circle pattern vs Box arrangements
11. Create save/load functionality for party compositions and formation preferences

## Priority
High - Core gameplay mechanic

## Estimated Effort
2-3 weeks

## Dependencies
- Issue 001 (Project Setup)
- Basic unit system

## Related Documents
- docs/game-design.md
- docs/formation-aura-system.md
- notes/vision

## Technical Notes
- Support multiple formation strategies (9, 7, 5, 3, 1 unit configurations)
- Aura strength scales inversely with unit count
- Formation detection must be automatic and responsive
- Visual effects should clearly communicate aura coverage and strength

## Three Balanced Formation Types to Implement

### Circle Formation (7 units - Elite Mobile Force)
- Positions: 2 top, 3 middle, 2 bottom (cross pattern)
- All 7 units receive persistent aura
- Aura persists when units move apart
- Power Level: 7 enhanced units

### Box Formation with Aura (9 units - Mixed Force)
- Standard 3x3 grid with center aura unit
- 5 units receive aura (positions 2,4,5,6,8)
- 4 units normal effectiveness
- Power Level: 5 enhanced + 4 normal units

### Box Formation without Aura (9 units - Overwhelming Force)
- Standard 3x3 grid, any units
- No aura effects
- Maximum unit count flexibility
- Power Level: 9 normal units

## Power Balance Design
**Balanced Effectiveness Formula:**
7 enhanced units ≈ (5 enhanced + 4 normal) units ≈ 9 normal units

## Aura Scaling Mechanics
- Circle Formation: 7 units affected = 7x base aura power total
- Box Formation (with aura): 5 units affected = 5x base aura power total  
- Box Formation (without aura): 0 units affected = no aura power
- Individual units receive full base aura power (not diluted)
- **Strategic Parity**: All formations viable, choice based on preference not power

## Party Deployment System
- Parties deployed as complete units to battle zones
- Deployed parties adventure alongside nearby allied parties
- Formation benefits persist during deployment and adventuring
- Multiple party types can coordinate in larger engagements