# 104 - Identify Translatable Data Types

## Status
- Phase: 1
- Priority: Medium
- Dependencies: 101, 102, 103

---

## Current Behavior

The mapping matrix (103) will show what CAN be mapped, but does not
specify the actual Lua data structures that will carry translated data
through the system.

---

## Intended Behavior

Define the internal data types used by the translation layer:

1. **TranslatedPacket** - The universal container for cross-game data
2. **CharacterState** - Unified character representation
3. **CombatEvent** - Unified damage/heal/buff event
4. **WorldPosition** - Unified coordinate system
5. **ChatMessage** - Unified communication event

These types abstract away game-specific details so the LLM and
narrative systems can work with clean, predictable data.

---

## Suggested Implementation Steps

1. Design TranslatedPacket structure:
   ```lua
   -- Universal packet wrapper
   TranslatedPacket = {
     source_game = "wow" | "coh",
     target_game = "coh" | "wow",
     packet_type = "movement" | "combat" | "chat" | ...,
     timestamp = <unix_ms>,
     original_data = <raw_bytes>,
     translated_data = <table>,
     confidence = 0.0 - 1.0,  -- How reliable is this translation?
     narrative_needed = true | false,
   }
   ```

2. Design CharacterState for unified character view:
   ```lua
   CharacterState = {
     id = <unique_id>,
     name = <string>,
     -- Normalized stats (0-100 scale)
     health = <percent>,
     resource = <percent>,  -- mana/endurance/rage
     level = <number>,
     position = WorldPosition,
     -- Source-specific data preserved for fallback
     wow_data = <table> | nil,
     coh_data = <table> | nil,
   }
   ```

3. Design CombatEvent for ability/damage translation:
   ```lua
   CombatEvent = {
     actor = <character_id>,
     target = <character_id>,
     action_type = "damage" | "heal" | "buff" | "debuff" | "cc",
     amount = <number>,
     -- Semantic ability info for narrative
     ability_name = <string>,
     ability_school = "physical" | "fire" | "energy" | ...,
     -- Original game data
     source_ability_id = <number>,
   }
   ```

4. Create type validation functions:
   - Ensure all required fields present
   - Validate ranges and enums
   - Fail loudly on invalid data

5. Document type contracts in code comments:
   - Explain why each field exists
   - Note which fields are required vs optional

---

## Notes

These types are the "language" of the translation layer. Every
component (protocol handler, LLM, narrative system) must speak this
language. Changes to these types will ripple across the codebase,
so design carefully now.
