Looking at this issue, I can see it already contains a sub-issue analysis with a recommendation table. Let me evaluate whether that split is appropriate.

## My Assessment

The existing analysis is well-reasoned. This issue defines **5 distinct data types** serving different conceptual domains, plus cross-cutting validation logic. The issue itself warns that "changes to these types will ripple across the codebase" - this is precisely why splitting makes sense.

**Why splitting is appropriate:**
- Each type is conceptually independent (CharacterState doesn't depend on CombatEvent's design)
- Different domains: spatial math (WorldPosition) vs game mechanics (CombatEvent) vs messaging (ChatMessage)
- Smaller units allow targeted review and rollback when ripple effects occur
- Validation deserves isolation to ensure consistent patterns across all types

## Recommendation: Split into sub-issues

| ID | Name | Description |
|----|------|-------------|
| 401a | design-translated-packet | Define the universal packet wrapper structure with source/target game, packet type, confidence, and narrative flags |
| 401b | design-character-state | Define unified character representation with normalized stats and game-specific fallback data |
| 401c | design-combat-event | Define unified combat event structure for damage, heals, buffs, debuffs, and crowd control |
| 401d | design-world-position | Define unified coordinate system that maps between WoW and CoH spatial models |
| 401e | design-chat-message | Define unified communication event structure for cross-game chat translation |
| 401f | implement-type-validation | Create validation functions that enforce field presence, ranges, and enum values with loud failures |

**Note:** The existing analysis in the issue file is accurate - I'm confirming it rather than replacing it. One observation: 401d (WorldPosition) may be simpler than others since coordinate systems are relatively straightforward, but it still deserves isolation because spatial math errors are notoriously subtle and benefit from independent testing.
