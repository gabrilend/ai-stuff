# Issue 407c: Alliance Management

**Phase:** 4 - Runtime
**Type:** Feature
**Priority:** High
**Parent:** 407-create-player-state-management.md
**Dependencies:** 407a (player data structure)

---

## Current Behavior

After 407a, each player has an empty `alliances = {}` table, but there are
no functions to set, get, or query alliance status between players. The
force-based initial alliances from w3i are not applied.

---

## Intended Behavior

Implement a complete alliance system that:
- Defines all WC3 alliance flags (passive, vision, control, etc.)
- Allows setting/getting alliance flags between any two players
- Supports asymmetric alliances (A allied to B but not B to A)
- Provides convenience functions (is_ally, is_enemy)
- Initializes alliances from w3i force flags
- Fires events when alliances change

WC3 alliance flags:
- `passive`: Don't auto-attack this player's units
- `help_request`: Show help requests from this player
- `help_response`: Respond to help requests from this player
- `shared_xp`: Share experience with this player
- `shared_spells`: Can target this player's units with beneficial spells
- `shared_vision`: See what this player sees
- `shared_control`: Can control this player's units
- `shared_advanced_control`: Full control including selling/destroying
- `rescuable`: This player's units can be rescued
- `shared_victory`: Share victory/defeat with this player

---

## Suggested Implementation Steps

1. **Define alliance flag constants**
   ```lua
   -- {{{ Alliance flag constants
   local ALLIANCE_FLAG = {
       PASSIVE = "passive",
       HELP_REQUEST = "help_request",
       HELP_RESPONSE = "help_response",
       SHARED_XP = "shared_xp",
       SHARED_SPELLS = "shared_spells",
       SHARED_VISION = "shared_vision",
       SHARED_CONTROL = "shared_control",
       SHARED_ADVANCED_CONTROL = "shared_advanced_control",
       RESCUABLE = "rescuable",
       SHARED_VICTORY = "shared_victory",
   }

   -- Default alliance state for new relationships
   local DEFAULT_ALLIANCE = {
       [ALLIANCE_FLAG.PASSIVE] = false,
       [ALLIANCE_FLAG.HELP_REQUEST] = false,
       [ALLIANCE_FLAG.HELP_RESPONSE] = false,
       [ALLIANCE_FLAG.SHARED_XP] = false,
       [ALLIANCE_FLAG.SHARED_SPELLS] = false,
       [ALLIANCE_FLAG.SHARED_VISION] = false,
       [ALLIANCE_FLAG.SHARED_CONTROL] = false,
       [ALLIANCE_FLAG.SHARED_ADVANCED_CONTROL] = false,
       [ALLIANCE_FLAG.RESCUABLE] = false,
       [ALLIANCE_FLAG.SHARED_VICTORY] = false,
   }
   -- }}}
   ```

2. **Implement set_alliance function**
   ```lua
   -- {{{ function player.set_alliance
   -- Set an alliance flag from one player to another
   -- Note: Alliances are NOT symmetric - A->B can differ from B->A
   function player.set_alliance(from_slot, to_slot, flag, value)
       local p = players[from_slot]
       if not p then
           return false, "Source player not found"
       end

       if not players[to_slot] then
           return false, "Target player not found"
       end

       -- Initialize alliance table for target if needed
       if not p.alliances[to_slot] then
           p.alliances[to_slot] = {}
       end

       local old_value = p.alliances[to_slot][flag]
       p.alliances[to_slot][flag] = value

       -- Fire event if changed
       if old_value ~= value then
           -- Event will be handled by event system (407d or separate)
           if player._on_alliance_changed then
               player._on_alliance_changed(from_slot, to_slot, flag, value)
           end
       end

       return true
   end
   -- }}}
   ```

3. **Implement get_alliance function**
   ```lua
   -- {{{ function player.get_alliance
   -- Get an alliance flag from one player to another
   -- Returns false if not set or players don't exist
   function player.get_alliance(from_slot, to_slot, flag)
       local p = players[from_slot]
       if not p then return false end
       if not p.alliances[to_slot] then return false end
       return p.alliances[to_slot][flag] or false
   end
   -- }}}
   ```

4. **Implement set_mutual_alliance helper**
   ```lua
   -- {{{ function player.set_mutual_alliance
   -- Set an alliance flag in both directions (symmetric)
   function player.set_mutual_alliance(slot_a, slot_b, flag, value)
       player.set_alliance(slot_a, slot_b, flag, value)
       player.set_alliance(slot_b, slot_a, flag, value)
   end
   -- }}}
   ```

5. **Implement team alliance helper**
   ```lua
   -- {{{ function player.set_team_alliance
   -- Set an alliance flag for all players in a list (mutual)
   function player.set_team_alliance(slots, flag, value)
       for i, slot_a in ipairs(slots) do
           for j, slot_b in ipairs(slots) do
               if slot_a ~= slot_b then
                   player.set_alliance(slot_a, slot_b, flag, value)
               end
           end
       end
   end
   -- }}}
   ```

6. **Implement is_ally function**
   ```lua
   -- {{{ function player.is_ally
   -- Check if two players are mutually allied (both have passive flag)
   -- A player is always allied with themselves
   function player.is_ally(slot_a, slot_b)
       if slot_a == slot_b then return true end

       -- Both must have passive flag set toward each other
       return player.get_alliance(slot_a, slot_b, ALLIANCE_FLAG.PASSIVE) and
              player.get_alliance(slot_b, slot_a, ALLIANCE_FLAG.PASSIVE)
   end
   -- }}}
   ```

7. **Implement is_enemy function**
   ```lua
   -- {{{ function player.is_enemy
   -- Check if two players are enemies (not mutually allied)
   function player.is_enemy(slot_a, slot_b)
       return not player.is_ally(slot_a, slot_b)
   end
   -- }}}
   ```

8. **Implement has_vision function**
   ```lua
   -- {{{ function player.has_vision
   -- Check if player A can see player B's units
   function player.has_vision(slot_a, slot_b)
       if slot_a == slot_b then return true end
       return player.get_alliance(slot_b, slot_a, ALLIANCE_FLAG.SHARED_VISION)
   end
   -- }}}
   ```

9. **Implement can_control function**
   ```lua
   -- {{{ function player.can_control
   -- Check if player A can control player B's units
   function player.can_control(slot_a, slot_b)
       if slot_a == slot_b then return true end
       return player.get_alliance(slot_b, slot_a, ALLIANCE_FLAG.SHARED_CONTROL)
   end
   -- }}}
   ```

10. **Update init_from_w3i to apply force alliances**
    Add to the existing init_from_w3i function after team assignment:
    ```lua
    -- Apply alliance flags from force settings
    if w3i_data.forces then
        for _, force in ipairs(w3i_data.forces) do
            local player_slots = {}
            -- ... (same slot extraction as before) ...

            local flags = force.flags or {}

            -- Allied forces share passive alliance
            if flags.allied then
                player.set_team_alliance(player_slots, ALLIANCE_FLAG.PASSIVE, true)
            end

            -- Allied victory means shared victory
            if flags.allied_victory then
                player.set_team_alliance(player_slots, ALLIANCE_FLAG.SHARED_VICTORY, true)
            end

            -- Shared vision
            if flags.share_vision then
                player.set_team_alliance(player_slots, ALLIANCE_FLAG.SHARED_VISION, true)
            end

            -- Shared control (rarely used in forces)
            if flags.share_control then
                player.set_team_alliance(player_slots, ALLIANCE_FLAG.SHARED_CONTROL, true)
            end

            -- Shared advanced control
            if flags.share_advanced_control then
                player.set_team_alliance(player_slots, ALLIANCE_FLAG.SHARED_ADVANCED_CONTROL, true)
            end
        end
    end
    ```

11. **Implement get_allies function**
    ```lua
    -- {{{ function player.get_allies
    -- Get array of all players allied to the given player
    function player.get_allies(slot)
        local result = {}
        for other_slot, p in pairs(players) do
            if player.is_ally(slot, other_slot) then
                result[#result + 1] = p
            end
        end
        return result
    end
    -- }}}
    ```

12. **Implement get_enemies function**
    ```lua
    -- {{{ function player.get_enemies
    -- Get array of all players hostile to the given player
    function player.get_enemies(slot)
        local result = {}
        for other_slot, p in pairs(players) do
            if player.is_enemy(slot, other_slot) and p.type ~= PLAYER_TYPE.NEUTRAL then
                result[#result + 1] = p
            end
        end
        return result
    end
    -- }}}
    ```

13. **Export constants**
    ```lua
    player.ALLIANCE_FLAG = ALLIANCE_FLAG
    ```

14. **Add unit tests**
    Test cases:
    - set_alliance correctly sets flag
    - get_alliance returns correct value
    - get_alliance returns false for unset flags
    - set_mutual_alliance sets both directions
    - set_team_alliance sets all pairs
    - is_ally returns true for mutual passive
    - is_ally returns false if only one direction
    - is_ally returns true for same slot
    - is_enemy is inverse of is_ally
    - has_vision checks correct direction
    - can_control checks correct direction
    - init_from_w3i applies force alliance flags
    - get_allies returns correct list
    - get_enemies excludes neutrals

---

## Related Documents

- issues/407-create-player-state-management.md (parent issue)
- issues/407a-player-data-structure.md (prerequisite)
- issues/103-parse-war3map-w3i.md (force flags for initial alliances)
- src/parsers/w3i.lua (force flag parsing reference)

---

## Acceptance Criteria

- [x] ALLIANCE_FLAG constants defined
- [x] player.set_alliance(from, to, flag, value) works
- [x] player.get_alliance(from, to, flag) works
- [x] player.set_mutual_alliance() sets both directions
- [x] player.set_team_alliance() sets all pairs in list
- [x] player.is_ally() checks mutual passive flag
- [x] player.is_enemy() returns inverse of is_ally
- [x] player.has_vision() checks shared_vision flag
- [x] player.can_control() checks shared_control flag
- [x] init_from_w3i applies force alliance flags
- [x] player.get_allies(slot) returns allied players
- [x] player.get_enemies(slot) returns hostile players
- [x] Alliance change events can be hooked
- [x] Unit tests pass

---

## Notes

Alliances are asymmetric by design. This matches WC3 behavior where you can
set yourself as allied to someone without them reciprocating.

The `is_ally` function specifically checks mutual `passive` flag because
that's what determines auto-attack behavior. Other flags (vision, control)
are independent.

The neutral player (slot 15) is typically passive to everyone but doesn't
share vision or control. Neutral hostile (slot 12-14) may have different
defaults.

Force flags in w3i represent initial state. Triggers can change alliances
at runtime via SetPlayerAlliance native functions.

---

## Implementation Notes

**Completed:** 2025-12-27

### Changes Made

1. **Added ALLIANCE_FLAG constants to src/runtime/player.lua:**
   - PASSIVE, HELP_REQUEST, HELP_RESPONSE, SHARED_XP, SHARED_SPELLS
   - SHARED_VISION, SHARED_CONTROL, SHARED_ADVANCED_CONTROL
   - RESCUABLE, SHARED_VICTORY

2. **Alliance management functions:**
   - `set_alliance(from, to, flag, value)` - set asymmetric alliance
   - `get_alliance(from, to, flag)` - query alliance flag
   - `set_mutual_alliance(a, b, flag, value)` - symmetric alliance helper
   - `set_team_alliance(slots, flag, value)` - team-wide alliance helper

3. **Alliance convenience functions:**
   - `is_ally(a, b)` - checks mutual PASSIVE flag
   - `is_enemy(a, b)` - inverse of is_ally
   - `has_vision(a, b)` - checks if A can see B's units
   - `can_control(a, b)` - checks if A can control B's units
   - `get_allies(slot)` - returns array of allied players
   - `get_enemies(slot)` - returns array of hostile players (excludes neutral)

4. **Updated init_from_w3i:**
   - Applies force alliance flags (allied, allied_victory, share_vision)
   - Handles share_unit_control and share_adv_control

5. **Event hook:**
   - `player._on_alliance_changed` callback for alliance change notifications

### Test Coverage

Added 24 new tests to test_player.lua (now 63 total):
- Alliance constants (1 test)
- Set/get alliance (7 tests)
- Convenience functions (8 tests)
- Query functions (2 tests)
- W3I initialization (4 tests)
- Event hooks (2 tests)
