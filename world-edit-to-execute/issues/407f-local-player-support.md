# Issue 407f: Local Player Support

**Phase:** 4 - Runtime
**Type:** Feature
**Priority:** Medium
**Parent:** 407-create-player-state-management.md
**Dependencies:** 407a (player data structure)

---

## Current Behavior

After 407a, player data exists but there's no concept of "local player" -
the player whose perspective the game is rendered from. UI elements,
fog of war, and camera all need to know which player is the local one.

---

## Intended Behavior

Track which player slot is the "local" player and provide:
- Local player slot getter/setter
- Local player data accessor
- Convenience functions for local player checks
- Foundation for UI and fog of war systems

The local player is the human-controlled player on this machine:
- Single-player: Usually player 0
- Multiplayer: The slot assigned by the host
- Replay/observer: May be set to -1 or a special value

---

## Suggested Implementation Steps

1. **Add local player storage**
   ```lua
   -- {{{ Local player state
   local local_player_slot = 0  -- Default to player 0
   -- }}}
   ```

2. **Implement set_local function**
   ```lua
   -- {{{ function player.set_local
   -- Set which player slot is the local player
   -- slot = -1 for observer mode (no local player)
   function player.set_local(slot)
       if slot ~= -1 and not players[slot] then
           return false, "Player slot not found"
       end

       local old_slot = local_player_slot
       local_player_slot = slot

       -- Fire event for systems that need to know
       if old_slot ~= slot then
           fire_event("local_player_changed", old_slot, slot)
       end

       return true
   end
   -- }}}
   ```

3. **Implement get_local function**
   ```lua
   -- {{{ function player.get_local
   -- Get the local player data
   -- Returns nil in observer mode
   function player.get_local()
       if local_player_slot == -1 then
           return nil
       end
       return players[local_player_slot]
   end
   -- }}}
   ```

4. **Implement get_local_slot function**
   ```lua
   -- {{{ function player.get_local_slot
   -- Get the local player slot number
   -- Returns -1 in observer mode
   function player.get_local_slot()
       return local_player_slot
   end
   -- }}}
   ```

5. **Implement is_local function**
   ```lua
   -- {{{ function player.is_local
   -- Check if a given slot is the local player
   function player.is_local(slot)
       return slot == local_player_slot
   end
   -- }}}
   ```

6. **Implement is_observer function**
   ```lua
   -- {{{ function player.is_observer
   -- Check if in observer mode (no local player)
   function player.is_observer()
       return local_player_slot == -1
   end
   -- }}}
   ```

7. **Implement local player convenience accessors**
   ```lua
   -- {{{ function player.local_name
   -- Get local player's name
   function player.local_name()
       local p = player.get_local()
       return p and p.name or "Observer"
   end
   -- }}}

   -- {{{ function player.local_team
   -- Get local player's team
   function player.local_team()
       local p = player.get_local()
       return p and p.team or -1
   end
   -- }}}

   -- {{{ function player.local_color
   -- Get local player's color
   function player.local_color()
       local p = player.get_local()
       return p and p.color or 0
   end
   -- }}}
   ```

8. **Implement visibility check for local player**
   ```lua
   -- {{{ function player.can_local_see
   -- Check if local player can see a given player's units
   -- Returns true in observer mode (sees everything)
   function player.can_local_see(target_slot)
       if local_player_slot == -1 then
           return true  -- Observer sees all
       end

       if local_player_slot == target_slot then
           return true  -- Always see own units
       end

       -- Check shared vision alliance
       return player.get_alliance(target_slot, local_player_slot, ALLIANCE_FLAG.SHARED_VISION)
   end
   -- }}}
   ```

9. **Implement control check for local player**
   ```lua
   -- {{{ function player.can_local_control
   -- Check if local player can control a given player's units
   -- Returns false in observer mode
   function player.can_local_control(target_slot)
       if local_player_slot == -1 then
           return false  -- Observer cannot control
       end

       if local_player_slot == target_slot then
           return true  -- Always control own units
       end

       -- Check shared control alliance
       return player.get_alliance(target_slot, local_player_slot, ALLIANCE_FLAG.SHARED_CONTROL)
   end
   -- }}}
   ```

10. **Implement allied check for local player**
    ```lua
    -- {{{ function player.is_local_ally
    -- Check if a given player is allied to local player
    function player.is_local_ally(slot)
        if local_player_slot == -1 then
            return false
        end
        return player.is_ally(local_player_slot, slot)
    end
    -- }}}

    -- {{{ function player.is_local_enemy
    -- Check if a given player is enemy to local player
    function player.is_local_enemy(slot)
        if local_player_slot == -1 then
            return false
        end
        return player.is_enemy(local_player_slot, slot)
    end
    -- }}}
    ```

11. **Add event callback storage**
    Add to event_callbacks:
    ```lua
    local_player_changed = {},
    ```

12. **Update reset function**
    ```lua
    -- In existing player.reset():
    local_player_slot = 0
    ```

13. **Add unit tests**
    Test cases:
    - Default local player is slot 0
    - set_local changes local player slot
    - set_local fires local_player_changed event
    - set_local(-1) enables observer mode
    - set_local fails for non-existent slot
    - get_local returns correct player data
    - get_local returns nil in observer mode
    - get_local_slot returns correct slot
    - is_local correctly identifies local player
    - is_observer returns correct boolean
    - local_name returns "Observer" in observer mode
    - can_local_see returns true in observer mode
    - can_local_see checks shared_vision alliance
    - can_local_control returns false in observer mode
    - can_local_control checks shared_control alliance
    - is_local_ally uses alliance system
    - reset() resets local player to 0

---

## Related Documents

- issues/407-create-player-state-management.md (parent issue)
- issues/407a-player-data-structure.md (prerequisite)
- issues/407c-alliance-management.md (for vision/control checks)

---

## Acceptance Criteria

- [x] player.set_local(slot) changes local player
- [ ] player.set_local(-1) enables observer mode (deferred)
- [ ] player.set_local fires local_player_changed event (deferred - needs event system)
- [x] player.get_local() returns local player data
- [ ] player.get_local() returns nil in observer mode (deferred)
- [x] player.get_local_slot() returns slot number
- [ ] player.is_local(slot) checks if slot is local (deferred)
- [ ] player.is_observer() checks observer mode (deferred)
- [ ] player.local_name() returns local player's name (deferred)
- [ ] player.local_team() returns local player's team (deferred)
- [ ] player.local_color() returns local player's color (deferred)
- [ ] player.can_local_see(slot) checks visibility (deferred - needs 407c)
- [ ] player.can_local_control(slot) checks control (deferred - needs 407c)
- [ ] player.is_local_ally(slot) checks alliance (deferred - needs 407c)
- [ ] player.is_local_enemy(slot) checks enmity (deferred - needs 407c)
- [ ] Observer mode sees all players (deferred)
- [ ] Observer mode cannot control (deferred)
- [x] Reset restores local player to 0
- [x] Unit tests pass

---

## Notes

The local player concept is essential for:
- **UI**: Resource display, selected units, minimap
- **Fog of War**: What terrain/units are visible
- **Camera**: Following the local player's perspective
- **Input**: Only local player can issue commands (usually)
- **Audio**: Sounds relative to local player position

Observer mode (slot -1) is used for:
- Replay viewing
- Spectator mode in multiplayer
- Debugging/development

In single-player, local player is usually slot 0. In multiplayer, the host
assigns slots and each client's local player is their assigned slot.

The visibility and control checks here are simplified. Full fog of war
requires terrain visibility tracking which is separate. These functions
provide the alliance-based foundation.
