# Issue 101: Enemy Bestiary

## Phase
1 - Foundation Documents

## Current Behavior
Enemy types are briefly described in docs/02-setting.md with basic behavior patterns and counters. The descriptions are introductory, not comprehensive.

## Intended Behavior
A standalone bestiary document (docs/03-bestiary.md) should exist containing:
- Full visual description of each enemy
- Detailed behavior state machine
- Attack patterns with timing
- Audio/visual tells
- Counter strategies
- Relationship to timeline mechanics (how does saving someone from X enemy affect future runs?)

## Enemies to Document
1. Gargoyles (dive bombers)
2. Skeletons (endless infantry)
3. Nether-bats (flank assassins)
4. Festus the Aboleth (boss, bridge guardian)

## Suggested Implementation Steps
1. Create docs/03-bestiary.md
2. Document each enemy with consistent format
3. Include ASCII diagrams of attack patterns where helpful
4. Cross-reference with timeline save scenarios
5. Update docs/table-of-contents.md

## Related Documents
- docs/02-setting.md (contains initial enemy descriptions)
- docs/01-core-mechanics.md (timeline system context)

## Notes
The bestiary should feel like a field guide - practical knowledge a soldier would need to survive. Not lore-heavy, but survival-focused.
