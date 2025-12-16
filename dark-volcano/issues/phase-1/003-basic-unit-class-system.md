# Issue 003: Basic Unit Class System

## Current Behavior
No unit classes exist in the system.

## Intended Behavior
Implement 3-5 starter FFTA-inspired classes with distinct stats, abilities, and visual styles. Each unit should have Tron-aesthetic styling.

## Suggested Implementation Steps
1. Design base unit class architecture
2. Implement starter classes: Knight, Black Mage, Thief, Cleric, Archer
3. Create unit stat system (HP, attack, defense, speed, magic)
4. Design basic visual representations with Tron styling
5. Implement class-specific passive abilities
6. Create unit factory/spawning system
7. Add unit data serialization for save/load

## Priority
High - Required for grid system and combat

## Estimated Effort
2-3 weeks

## Dependencies
- Issue 001 (Project Setup)

## Related Documents
- docs/unit-classes.md
- docs/game-design.md

## Acceptance Criteria
- 5 distinct unit classes implemented
- Each class has unique stats and visual style
- Units can be instantiated and placed in game world
- Class data properly serialized