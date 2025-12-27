# Issue 407d: Player State Transitions

**Phase:** 4 - Runtime
**Type:** Feature
**Priority:** High
**Parent:** 407-create-player-state-management.md
**Dependencies:** 407a (player data structure), 407b (player queries), 402 (ECS for owner component)

---

## Current Behavior

After 407a, players have a `state` field initialized to "active", but there
are no functions to transition players between states (defeated, victorious,
left) or handle the side effects of these transitions.

---

## Intended Behavior

Implement player state transition functions that:
- Mark players as defeated, victorious, or left
- Handle side effects (what happens to their units)
- Fire appropriate events for other systems to react
- Prevent invalid transitions
- Integrate with ECS to handle owned entities

Player states:
- `active`: Player is in the game
- `defeated`: Player lost (units destroyed, base destroyed, etc.)
- `victorious`: Player won
- `left`: Player disconnected (multiplayer)

---

## Suggested Implementation Steps

1. **Add event callback storage**
   ```lua
   -- {{{ Event callbacks
   -- Callbacks for state change events
   local event_callbacks = {
       player_defeated = {},
       player_victorious = {},
       player_left = {},
       player_state_changed = {},
   }

   -- {{{ function player.on
   -- Register a callback for an event
   function player.on(event_name, callback)
       if event_callbacks[event_name] then
           table.insert(event_callbacks[event_name], callback)
       end
   end
   -- }}}

   -- {{{ local function fire_event
   local function fire_event(event_name, ...)
       local callbacks = event_callbacks[event_name]
       if callbacks then
           for _, cb in ipairs(callbacks) do
               cb(...)
           end
       end
   end
   -- }}}
   -- }}}
   ```

2. **Implement set_state function**
   ```lua
   -- {{{ function player.set_state
   -- Change player state with validation
   -- Returns success, error_message
   function player.set_state(slot, new_state)
       local p = players[slot]
       if not p then
           return false, "Player not found"
       end

       local old_state = p.state

       -- Validate transition
       if old_state == new_state then
           return true  -- No change needed
       end

       -- Prevent transitions from terminal states
       if old_state == PLAYER_STATE.DEFEATED or
          old_state == PLAYER_STATE.VICTORIOUS or
          old_state == PLAYER_STATE.LEFT then
           return false, "Cannot transition from terminal state: " .. old_state
       end

       -- Validate new state
       if new_state ~= PLAYER_STATE.ACTIVE and
          new_state ~= PLAYER_STATE.DEFEATED and
          new_state ~= PLAYER_STATE.VICTORIOUS and
          new_state ~= PLAYER_STATE.LEFT then
           return false, "Invalid state: " .. tostring(new_state)
       end

       p.state = new_state
       fire_event("player_state_changed", slot, old_state, new_state)

       return true
   end
   -- }}}
   ```

3. **Implement defeat function**
   ```lua
   -- {{{ function player.defeat
   -- Mark a player as defeated and handle their units
   -- options = { destroy_units = true, transfer_to = nil }
   function player.defeat(slot, options)
       options = options or {}

       local p = players[slot]
       if not p then
           return false, "Player not found"
       end

       if p.state ~= PLAYER_STATE.ACTIVE then
           return false, "Player is not active"
       end

       -- Mark as defeated
       p.state = PLAYER_STATE.DEFEATED

       -- Handle owned entities (requires ECS integration)
       if player._handle_defeated_units then
           player._handle_defeated_units(slot, options)
       end

       -- Fire events
       fire_event("player_defeated", slot)
       fire_event("player_state_changed", slot, PLAYER_STATE.ACTIVE, PLAYER_STATE.DEFEATED)

       -- Check if game should end (done in 407e)
       if player._check_victory_conditions then
           player._check_victory_conditions()
       end

       return true
   end
   -- }}}
   ```

4. **Implement set_victorious function**
   ```lua
   -- {{{ function player.set_victorious
   -- Mark a player as victorious
   function player.set_victorious(slot)
       local p = players[slot]
       if not p then
           return false, "Player not found"
       end

       -- Can set victorious from any non-terminal state
       if p.state == PLAYER_STATE.VICTORIOUS then
           return true  -- Already victorious
       end

       if p.state == PLAYER_STATE.DEFEATED or p.state == PLAYER_STATE.LEFT then
           return false, "Cannot set defeated/left player as victorious"
       end

       p.state = PLAYER_STATE.VICTORIOUS

       fire_event("player_victorious", slot)
       fire_event("player_state_changed", slot, PLAYER_STATE.ACTIVE, PLAYER_STATE.VICTORIOUS)

       return true
   end
   -- }}}
   ```

5. **Implement leave function**
   ```lua
   -- {{{ function player.leave
   -- Handle player leaving (disconnection)
   -- options = { destroy_units = false, transfer_to = "ally" }
   function player.leave(slot, options)
       options = options or {}

       local p = players[slot]
       if not p then
           return false, "Player not found"
       end

       if p.state ~= PLAYER_STATE.ACTIVE then
           return false, "Player is not active"
       end

       p.state = PLAYER_STATE.LEFT

       -- Handle owned entities
       if player._handle_left_units then
           player._handle_left_units(slot, options)
       end

       fire_event("player_left", slot)
       fire_event("player_state_changed", slot, PLAYER_STATE.ACTIVE, PLAYER_STATE.LEFT)

       -- Check victory conditions
       if player._check_victory_conditions then
           player._check_victory_conditions()
       end

       return true
   end
   -- }}}
   ```

6. **Implement ECS integration hooks**
   ```lua
   -- {{{ ECS integration
   -- These functions are set by the ECS module when loaded

   -- {{{ function player.set_ecs
   -- Set the ECS module reference for entity operations
   function player.set_ecs(ecs_module)
       player._ecs = ecs_module
   end
   -- }}}

   -- {{{ player._handle_defeated_units
   -- Called when a player is defeated
   player._handle_defeated_units = function(slot, options)
       local ecs = player._ecs
       if not ecs then return end

       -- Find all entities owned by this player
       -- (Requires owner component query from 402)
       local entities = ecs.query_by_component("owner")
       if not entities then return end

       for _, entity in ipairs(entities) do
           local owner = ecs.get_component(entity, "owner")
           if owner and owner.player_id == slot then
               if options.destroy_units ~= false then
                   ecs.destroy_entity(entity)
               elseif options.transfer_to then
                   -- Transfer to specified player
                   owner.player_id = options.transfer_to
               end
           end
       end
   end
   -- }}}

   -- {{{ player._handle_left_units
   -- Called when a player leaves
   player._handle_left_units = function(slot, options)
       local ecs = player._ecs
       if not ecs then return end

       local entities = ecs.query_by_component("owner")
       if not entities then return end

       for _, entity in ipairs(entities) do
           local owner = ecs.get_component(entity, "owner")
           if owner and owner.player_id == slot then
               if options.transfer_to == "ally" then
                   -- Find first active ally
                   local allies = player.get_allies(slot)
                   for _, ally in ipairs(allies) do
                       if ally.state == PLAYER_STATE.ACTIVE then
                           owner.player_id = ally.slot
                           break
                       end
                   end
               elseif options.transfer_to == "neutral" then
                   owner.player_id = NEUTRAL_SLOT
               elseif options.destroy_units then
                   ecs.destroy_entity(entity)
               end
           end
       end
   end
   -- }}}
   -- }}}
   ```

7. **Implement is_active convenience function**
   ```lua
   -- {{{ function player.is_active
   -- Check if player is active
   function player.is_active(slot)
       local p = players[slot]
       return p and p.state == PLAYER_STATE.ACTIVE
   end
   -- }}}
   ```

8. **Implement is_playing convenience function**
   ```lua
   -- {{{ function player.is_playing
   -- Check if player is still in game (active or victorious)
   function player.is_playing(slot)
       local p = players[slot]
       if not p then return false end
       return p.state == PLAYER_STATE.ACTIVE or p.state == PLAYER_STATE.VICTORIOUS
   end
   -- }}}
   ```

9. **Implement clear_events for testing**
   ```lua
   -- {{{ function player.clear_events
   -- Clear all event callbacks (for testing)
   function player.clear_events()
       for event_name, _ in pairs(event_callbacks) do
           event_callbacks[event_name] = {}
       end
   end
   -- }}}
   ```

10. **Add unit tests**
    Test cases:
    - set_state changes state correctly
    - set_state fires player_state_changed event
    - set_state prevents transition from terminal states
    - defeat marks player as defeated
    - defeat fires player_defeated event
    - defeat triggers victory condition check
    - set_victorious marks player as victorious
    - set_victorious fails for defeated players
    - leave marks player as left
    - leave fires player_left event
    - is_active returns correct boolean
    - is_playing returns true for active/victorious
    - Event callbacks are invoked with correct arguments
    - ECS integration handles entity destruction (mock ECS)
    - ECS integration handles entity transfer (mock ECS)

---

## Related Documents

- issues/407-create-player-state-management.md (parent issue)
- issues/407a-player-data-structure.md (prerequisite)
- issues/407b-player-queries.md (prerequisite for get_allies)
- issues/407c-alliance-management.md (for ally transfer)
- issues/407e-victory-conditions.md (calls check function)
- issues/402-build-entity-component-system.md (ECS for unit ownership)

---

## Acceptance Criteria

- [x] player.set_state(slot, state) changes state with validation
- [x] Terminal states (defeated, victorious, left) cannot transition
- [x] player.defeat(slot) marks player as defeated
- [x] player.defeat triggers unit handling (destroy/transfer)
- [x] player.set_victorious(slot) marks player as winner
- [x] player.leave(slot) handles disconnection
- [x] player.is_active(slot) checks active state
- [x] player.is_playing(slot) checks active or victorious
- [x] player.on(event, callback) registers event handlers
- [x] player_defeated event fires on defeat
- [x] player_victorious event fires on victory
- [x] player_left event fires on leave
- [x] player_state_changed event fires on any change
- [x] ECS integration handles owned entities (via hooks)
- [x] Unit tests pass

---

## Notes

The ECS integration is loosely coupled. The player module stores a reference
to the ECS module (set via player.set_ecs) and calls methods on it when
needed. This allows the player module to work standalone for testing.

Terminal states are defeat, victory, and left. Once a player reaches one of
these states, they cannot transition again. This prevents bugs where a
defeated player could somehow become active again.

The _check_victory_conditions function is set by 407e. It's called after
any player leaves the game to determine if the game should end.

Unit transfer on leave has several options:
- Transfer to ally: Give units to first active ally
- Transfer to neutral: Make units neutral
- Destroy: Remove all units
- None: Leave units orphaned (not recommended)

---

## Implementation Notes

**Completed:** 2025-12-27

### Changes Made

1. **Event system added to src/runtime/player.lua:**
   - `event_callbacks` table for player_defeated, player_victorious, player_left, player_state_changed
   - `fire_event()` helper to invoke callbacks
   - `player.on(event, callback)` to register handlers
   - `player.clear_events()` to reset handlers (for testing)

2. **State transition functions:**
   - `set_state(slot, new_state)` - with validation, terminal state protection
   - `defeat(slot, options)` - marks defeated, fires events, calls hooks
   - `set_victorious(slot)` - marks victorious, idempotent
   - `leave(slot, options)` - handles disconnection

3. **Convenience functions:**
   - `is_active(slot)` - checks if player is in active state
   - `is_playing(slot)` - checks if active or victorious (still in game)

4. **ECS integration hooks (loosely coupled):**
   - `player._handle_defeated_units` - called on defeat with options
   - `player._handle_left_units` - called on leave with options
   - `player._check_victory_conditions` - called after defeat/leave (set by 407e)

5. **Reset updated:**
   - Clears event callbacks via `clear_events()`
   - Clears ECS and victory hooks

### Test Coverage

Added 28 new tests to test_player.lua (now 91 total):
- State transition tests (5 tests)
- Defeat function tests (5 tests)
- Victory function tests (4 tests)
- Leave function tests (4 tests)
- Convenience state check tests (7 tests)
- Event system tests (3 tests)
