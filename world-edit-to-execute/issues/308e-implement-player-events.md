# Issue 308e: Implement Player Events

**Phase:** 3 - Logic Layer
**Type:** Feature
**Priority:** High
**Parent Issue:** 308-build-event-dispatch-system.md
**Dependencies:** 308a-implement-event-registry-core

---

## Current Behavior

The event registry from 308a provides infrastructure for event→trigger bindings.
However, there are no player-related events - no way to trigger actions when
players chat, leave the game, or change alliances.

Currently:
- No TriggerRegisterPlayerEvent function
- No TriggerRegisterPlayerChatEvent function
- No event firing hooks for player actions
- No GetEventPlayerChatString, GetTriggerPlayer accessor functions

---

## Intended Behavior

A player event subsystem that provides:

1. **Player Event Registration APIs**:
   - `TriggerRegisterPlayerEvent(trigger, player, event_type)` - Specific player events
   - `TriggerRegisterPlayerChatEvent(trigger, player, message, exact_match)` - Chat events
   - `TriggerRegisterPlayerAllianceChange(trigger, player)` - Alliance changes

2. **Event Firing Hooks** - Called by future player/chat systems:
   - `events.player_chat(player, message)` - Fire PLAYER_CHAT
   - `events.player_left(player, reason)` - Fire PLAYER_LEAVE
   - `events.player_alliance_changed(player, other_player, alliance_type)` - Fire PLAYER_ALLIANCE_CHANGE

3. **Chat Event Filtering**:
   - No message filter: fires for any chat from player
   - Exact match: fires only if message equals filter exactly
   - Substring match: fires if message contains filter string

4. **Event Context Structures**:
   ```lua
   -- PLAYER_CHAT context
   {
       event_id = EVENT.PLAYER_CHAT,
       player = <chatting player>,
       triggering_player = <chatting player>,
       message = <chat message string>,
       matched_string = <matched portion if filtering>,
   }

   -- PLAYER_LEAVE context
   {
       event_id = EVENT.PLAYER_LEAVE,
       player = <leaving player>,
       triggering_player = <leaving player>,
       leave_reason = <reason constant>,
   }
   ```

5. **Context Accessor Functions**:
   - `GetTriggerPlayer()` - Player that triggered the event
   - `GetEventPlayerChatString()` - Full chat message
   - `GetEventPlayerChatStringMatched()` - Matched portion of message

---

## Suggested Implementation Steps

1. **Implement TriggerRegisterPlayerEvent function**
   ```lua
   -- {{{ TriggerRegisterPlayerEvent
   function runtime.TriggerRegisterPlayerEvent(trigger, player, event_type)
       return events.register(
           event_type,
           trigger,
           function(ctx)
               return ctx.player == player
           end
       )
   end
   -- }}}
   ```

2. **Implement TriggerRegisterPlayerChatEvent function**
   ```lua
   -- {{{ TriggerRegisterPlayerChatEvent
   -- player: specific player or nil for any player
   -- message: string to match or "" for any message
   -- exact_match: true for exact match, false for substring
   function runtime.TriggerRegisterPlayerChatEvent(trigger, player, message, exact_match)
       return events.register(
           events.EVENT.PLAYER_CHAT,
           trigger,
           function(ctx)
               -- Filter by player if specified
               if player and ctx.player ~= player then
                   return false
               end

               -- Filter by message if specified
               if message and message ~= "" then
                   if exact_match then
                       if ctx.message ~= message then
                           return false
                       end
                       ctx.matched_string = message
                   else
                       -- Substring match (case-sensitive)
                       local start_pos = ctx.message:find(message, 1, true)
                       if not start_pos then
                           return false
                       end
                       ctx.matched_string = message
                   end
               else
                   ctx.matched_string = ctx.message
               end

               return true
           end
       )
   end
   -- }}}
   ```

3. **Implement TriggerRegisterPlayerAllianceChange function**
   ```lua
   -- {{{ TriggerRegisterPlayerAllianceChange
   function runtime.TriggerRegisterPlayerAllianceChange(trigger, player)
       return events.register(
           events.EVENT.PLAYER_ALLIANCE_CHANGE,
           trigger,
           function(ctx)
               -- Fire if player is either side of the alliance change
               return ctx.player == player or ctx.other_player == player
           end
       )
   end
   -- }}}
   ```

4. **Implement player_chat fire hook**
   ```lua
   -- {{{ player_chat
   -- Called by chat system when player sends message
   function events.player_chat(player, message)
       events.fire(events.EVENT.PLAYER_CHAT, {
           event_id = events.EVENT.PLAYER_CHAT,
           player = player,
           triggering_player = player,
           message = message,
           chat_string = message,
           matched_string = nil,  -- Set by filter if matching
       })
   end
   -- }}}
   ```

5. **Implement player_left fire hook**
   ```lua
   -- {{{ player_left
   -- Called when player disconnects or leaves
   -- reason: "disconnect", "defeat", "victory", "kicked"
   function events.player_left(player, reason)
       events.fire(events.EVENT.PLAYER_LEAVE, {
           event_id = events.EVENT.PLAYER_LEAVE,
           player = player,
           triggering_player = player,
           leave_reason = reason or "disconnect",
       })
   end
   -- }}}
   ```

6. **Implement player_alliance_changed fire hook**
   ```lua
   -- {{{ player_alliance_changed
   -- Called when alliance between players changes
   -- alliance_type: "allied", "enemy", "neutral", etc.
   function events.player_alliance_changed(player, other_player, old_alliance, new_alliance)
       events.fire(events.EVENT.PLAYER_ALLIANCE_CHANGE, {
           event_id = events.EVENT.PLAYER_ALLIANCE_CHANGE,
           player = player,
           triggering_player = player,
           other_player = other_player,
           old_alliance = old_alliance,
           new_alliance = new_alliance,
       })
   end
   -- }}}
   ```

7. **Implement GetTriggerPlayer function**
   ```lua
   -- {{{ GetTriggerPlayer
   function runtime.GetTriggerPlayer()
       local ctx = events._current_context
       return ctx and ctx.triggering_player
   end
   -- }}}
   ```

8. **Implement GetEventPlayerChatString function**
   ```lua
   -- {{{ GetEventPlayerChatString
   function runtime.GetEventPlayerChatString()
       local ctx = events._current_context
       return ctx and ctx.chat_string or ""
   end
   -- }}}
   ```

9. **Implement GetEventPlayerChatStringMatched function**
   ```lua
   -- {{{ GetEventPlayerChatStringMatched
   function runtime.GetEventPlayerChatStringMatched()
       local ctx = events._current_context
       return ctx and ctx.matched_string or ""
   end
   -- }}}
   ```

10. **Implement GetPlayerLeaveReason function**
    ```lua
    -- {{{ GetPlayerLeaveReason
    function runtime.GetPlayerLeaveReason()
        local ctx = events._current_context
        return ctx and ctx.leave_reason
    end
    -- }}}
    ```

11. **Implement SubString helper for chat commands**
    ```lua
    -- {{{ SubString (BJ compatibility)
    -- WC3 SubString is 0-indexed, Lua string.sub is 1-indexed
    function runtime.SubString(s, start_index, end_index)
        if not s then return "" end
        -- Convert from 0-indexed to 1-indexed
        return s:sub(start_index + 1, end_index + 1)
    end
    -- }}}

    -- {{{ StringLength
    function runtime.StringLength(s)
        return s and #s or 0
    end
    -- }}}
    ```

12. **Write unit tests**
    - Create `src/tests/test_player_events.lua`
    - Test TriggerRegisterPlayerEvent fires for specified player
    - Test TriggerRegisterPlayerChatEvent with exact match
    - Test TriggerRegisterPlayerChatEvent with substring match
    - Test TriggerRegisterPlayerChatEvent with any player (nil)
    - Test TriggerRegisterPlayerChatEvent with any message ("")
    - Test player_chat fires PLAYER_CHAT
    - Test player_left fires PLAYER_LEAVE
    - Test player_alliance_changed fires PLAYER_ALLIANCE_CHANGE
    - Test GetTriggerPlayer returns correct player
    - Test GetEventPlayerChatString returns full message
    - Test GetEventPlayerChatStringMatched returns matched portion
    - Test chat matching is case-sensitive
    - Test SubString converts 0-indexed correctly

---

## Related Documents

- issues/308-build-event-dispatch-system.md (parent issue)
- issues/308a-implement-event-registry-core.md (dependency - event registry)
- issues/407-implement-player-state-management.md (player objects)
- src/runtime/events.lua (event registry)
- src/runtime/init.lua (runtime API)
- src/runtime/player.lua (player module)

---

## Acceptance Criteria

- [x] TriggerRegisterPlayerEvent fires for specified player
- [x] TriggerRegisterPlayerChatEvent fires on matching chat
- [x] Chat exact match mode works (full message equality)
- [x] Chat substring match mode works (contains string)
- [x] Chat filter nil player matches any player
- [x] Chat filter empty message matches any message
- [x] Player events (chat, leave, alliance) fire correctly
- [x] events.player_chat(player, message) fires PLAYER_CHAT
- [x] events.player_left(player, reason) fires PLAYER_LEAVE
- [x] events.player_alliance_changed fires PLAYER_ALLIANCE_CHANGE
- [x] GetTriggerPlayer returns triggering player
- [x] GetEventPlayerChatString returns full chat message
- [x] GetEventPlayerChatStringMatched returns matched portion
- [x] GetPlayerLeaveReason returns leave reason
- [x] Context data available during trigger execution
- [x] SubString uses 0-indexed WC3 convention
- [x] Unit tests pass for all player event operations

---

## Notes

Player chat events are the primary way WC3 maps implement chat commands.
The common pattern:

```lua
-- Register for "-spawn" command prefix
TriggerRegisterPlayerChatEvent(trig, Player(0), "-spawn", false)

-- In action:
local msg = GetEventPlayerChatString()
local cmd = SubString(msg, 7, StringLength(msg))  -- Everything after "-spawn "
-- Parse cmd for unit type...
```

The substring match (exact_match = false) uses Lua's plain string find,
not pattern matching. This matches WC3 behavior where "-spawn" matches
"-spawn orc" but patterns like ".*" are literal.

The matched_string field is set by the filter function. This is a slight
deviation from pure functional filters, but necessary for GetEventPlayerChatStringMatched
to work correctly. The filter modifies the context it receives.

Alliance changes can fire for both players involved. The filter checks if
either player matches the registered player, allowing a single trigger to
catch when a player's alliance changes regardless of which side initiated.

Leave reasons in WC3:
- PLAYER_GAME_RESULT_DISCONNECT (connection lost)
- PLAYER_GAME_RESULT_DEFEAT (defeated in game)
- PLAYER_GAME_RESULT_VICTORY (won the game)

We simplify to string constants: "disconnect", "defeat", "victory", "kicked"

---

## Implementation Notes

**Completed:** 2025-12-27

### Files Modified

| File | Description |
|------|-------------|
| `src/runtime/init.lua` | Added player event registration and context accessors |
| `src/runtime/events.lua` | Added 5 player event fire hooks |
| `src/tests/test_events_308e.lua` | Test suite with 33 tests |

### Functions Implemented

**Registration Functions (runtime):**
| Function | Description |
|----------|-------------|
| `TriggerRegisterPlayerEvent(trigger, player, event_type)` | Register for player events |
| `TriggerRegisterPlayerChatEvent(trigger, player, message, exact_match)` | Register for chat with filtering |
| `TriggerRegisterPlayerAllianceChange(trigger, player)` | Register for alliance changes |

**Fire Hooks (events):**
| Function | Description |
|----------|-------------|
| `player_chat(player, message)` | Fire PLAYER_CHAT |
| `player_left(player, reason)` | Fire PLAYER_LEAVE |
| `player_alliance_changed(player, other, old, new)` | Fire PLAYER_ALLIANCE_CHANGE |
| `player_defeated(player)` | Fire PLAYER_DEFEAT |
| `player_victorious(player)` | Fire PLAYER_VICTORY |

**Context Accessors (runtime):**
| Function | Description |
|----------|-------------|
| `GetEventPlayerChatString()` | Get full chat message |
| `GetEventPlayerChatStringMatched()` | Get matched portion |
| `GetPlayerLeaveReason()` | Get leave reason |

**String Utilities (runtime):**
| Function | Description |
|----------|-------------|
| `SubString(s, start, end)` | 0-indexed WC3 substring |
| `StringLength(s)` | String length |

### Design Notes

- Chat filters modify context to set `matched_string` - slight deviation from pure functional filters but required for accessor
- Player can be nil in TriggerRegisterPlayerChatEvent to match any player
- Empty message string matches any chat message
- Substring matching uses plain string find (not patterns) to match WC3 behavior
- Alliance change fires for either participant (initiator or other_player)
- Added player_defeated/player_victorious fire hooks beyond original spec

### Test Coverage

33 tests covering:
- TriggerRegisterPlayerEvent: 6 tests
- TriggerRegisterPlayerChatEvent: 8 tests
- Chat context accessors: 5 tests
- Player leave events: 3 tests
- Player alliance events: 3 tests
- Player defeat/victory: 2 tests
- String utilities: 3 tests
- Multiple triggers: 2 tests
- Chat command pattern: 1 test
