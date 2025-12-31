# Issue 407e: Victory Conditions

**Phase:** 4 - Runtime
**Type:** Feature
**Priority:** High
**Parent:** 407-create-player-state-management.md
**Dependencies:** 407a (player data structure), 407b (player queries), 407d (player state transitions)

---

## Current Behavior

After 407d, players can be marked as defeated or victorious, but there's no
automatic detection of when the game should end. Victory conditions must be
checked manually and there's no game-over handling.

---

## Intended Behavior

Implement victory condition checking that:
- Detects when only one team remains active
- Marks all players on the winning team as victorious
- Handles draws (no teams remaining)
- Fires game-over events
- Integrates with player defeat flow

Victory models:
- **Team elimination**: Last team with active players wins
- **Custom conditions**: Triggers can call victory functions directly

---

## Suggested Implementation Steps

1. **Add game state tracking**
   ```lua
   -- {{{ Game state
   local game_state = {
       started = false,
       ended = false,
       winning_team = nil,
       end_reason = nil,  -- "elimination", "custom", "draw"
   }

   -- {{{ function player.start_game
   -- Mark the game as started (enables victory checking)
   function player.start_game()
       game_state.started = true
       game_state.ended = false
       game_state.winning_team = nil
       game_state.end_reason = nil
   end
   -- }}}

   -- {{{ function player.is_game_started
   function player.is_game_started()
       return game_state.started
   end
   -- }}}

   -- {{{ function player.is_game_ended
   function player.is_game_ended()
       return game_state.ended
   end
   -- }}}

   -- {{{ function player.get_game_result
   function player.get_game_result()
       return {
           ended = game_state.ended,
           winning_team = game_state.winning_team,
           end_reason = game_state.end_reason,
       }
   end
   -- }}}
   -- }}}
   ```

2. **Implement team counting**
   ```lua
   -- {{{ local function count_active_teams
   -- Count how many distinct teams have active players
   -- Returns: team_count, teams_table (team_id -> true)
   local function count_active_teams()
       local active_teams = {}

       for slot, p in pairs(players) do
           if p.state == PLAYER_STATE.ACTIVE and
              p.type ~= PLAYER_TYPE.NEUTRAL then
               active_teams[p.team] = true
           end
       end

       local count = 0
       for _ in pairs(active_teams) do
           count = count + 1
       end

       return count, active_teams
   end
   -- }}}
   ```

3. **Implement victory condition checker**
   ```lua
   -- {{{ function player.check_victory_conditions
   -- Check if victory conditions are met
   -- Called automatically after player defeat/leave
   function player.check_victory_conditions()
       -- Don't check if game hasn't started or has already ended
       if not game_state.started or game_state.ended then
           return false
       end

       local team_count, active_teams = count_active_teams()

       if team_count == 1 then
           -- One team remaining - they win
           local winning_team = nil
           for team, _ in pairs(active_teams) do
               winning_team = team
               break
           end

           player._declare_winner(winning_team)
           return true

       elseif team_count == 0 then
           -- No teams remaining - draw
           player._declare_draw()
           return true
       end

       -- Game continues
       return false
   end
   -- }}}

   -- Hook this function to be called by 407d
   player._check_victory_conditions = player.check_victory_conditions
   ```

4. **Implement winner declaration**
   ```lua
   -- {{{ local function player._declare_winner
   function player._declare_winner(team)
       game_state.ended = true
       game_state.winning_team = team
       game_state.end_reason = "elimination"

       -- Mark all players on winning team as victorious
       for slot, p in pairs(players) do
           if p.team == team and p.state == PLAYER_STATE.ACTIVE then
               p.state = PLAYER_STATE.VICTORIOUS
               fire_event("player_victorious", slot)
           end
       end

       fire_event("game_over", {
           winner = team,
           reason = "elimination",
       })
   end
   -- }}}
   ```

5. **Implement draw declaration**
   ```lua
   -- {{{ local function player._declare_draw
   function player._declare_draw()
       game_state.ended = true
       game_state.winning_team = nil
       game_state.end_reason = "draw"

       fire_event("game_over", {
           winner = nil,
           reason = "draw",
       })
   end
   -- }}}
   ```

6. **Implement force victory (for custom triggers)**
   ```lua
   -- {{{ function player.force_victory
   -- Force a specific player/team to win (for custom victory conditions)
   function player.force_victory(slot_or_team, is_team)
       if game_state.ended then
           return false, "Game already ended"
       end

       game_state.ended = true
       game_state.end_reason = "custom"

       if is_team then
           -- Team victory
           local team = slot_or_team
           game_state.winning_team = team

           for slot, p in pairs(players) do
               if p.team == team and p.state == PLAYER_STATE.ACTIVE then
                   p.state = PLAYER_STATE.VICTORIOUS
                   fire_event("player_victorious", slot)
               elseif p.state == PLAYER_STATE.ACTIVE then
                   p.state = PLAYER_STATE.DEFEATED
                   fire_event("player_defeated", slot)
               end
           end
       else
           -- Single player victory
           local slot = slot_or_team
           local p = players[slot]
           if not p then
               return false, "Player not found"
           end

           game_state.winning_team = p.team
           p.state = PLAYER_STATE.VICTORIOUS
           fire_event("player_victorious", slot)

           -- Defeat all other active players
           for other_slot, other_p in pairs(players) do
               if other_slot ~= slot and other_p.state == PLAYER_STATE.ACTIVE then
                   other_p.state = PLAYER_STATE.DEFEATED
                   fire_event("player_defeated", other_slot)
               end
           end
       end

       fire_event("game_over", {
           winner = game_state.winning_team,
           reason = "custom",
       })

       return true
   end
   -- }}}
   ```

7. **Implement force defeat (for custom triggers)**
   ```lua
   -- {{{ function player.force_defeat
   -- Force a specific player to lose (triggers normal defeat flow)
   function player.force_defeat(slot)
       return player.defeat(slot)
   end
   -- }}}
   ```

8. **Implement team elimination helper**
   ```lua
   -- {{{ function player.defeat_team
   -- Defeat all active players on a team
   function player.defeat_team(team)
       local defeated_count = 0

       for slot, p in pairs(players) do
           if p.team == team and p.state == PLAYER_STATE.ACTIVE then
               p.state = PLAYER_STATE.DEFEATED
               fire_event("player_defeated", slot)
               defeated_count = defeated_count + 1
           end
       end

       -- Victory check will happen after all defeats
       player.check_victory_conditions()

       return defeated_count
   end
   -- }}}
   ```

9. **Implement get_winning_players**
   ```lua
   -- {{{ function player.get_winning_players
   -- Get array of victorious players (after game end)
   function player.get_winning_players()
       if not game_state.ended then
           return {}
       end

       local result = {}
       for slot, p in pairs(players) do
           if p.state == PLAYER_STATE.VICTORIOUS then
               result[#result + 1] = p
           end
       end
       return result
   end
   -- }}}
   ```

10. **Update reset function**
    ```lua
    -- In existing player.reset():
    game_state = {
        started = false,
        ended = false,
        winning_team = nil,
        end_reason = nil,
    }
    ```

11. **Add game_over event callback storage**
    Add to event_callbacks table:
    ```lua
    game_over = {},
    ```

12. **Add unit tests**
    Test cases:
    - check_victory_conditions does nothing before game start
    - check_victory_conditions does nothing after game end
    - Single team remaining triggers victory
    - Victorious players marked correctly
    - No teams remaining triggers draw
    - force_victory ends game immediately
    - force_victory marks losers as defeated
    - force_defeat triggers normal defeat flow
    - defeat_team defeats all players on team
    - game_over event fires with correct info
    - get_winning_players returns victorious list
    - get_game_result returns correct state
    - Victory check integrates with player.defeat

---

## Related Documents

- issues/407-create-player-state-management.md (parent issue)
- issues/407a-player-data-structure.md (prerequisite)
- issues/407b-player-queries.md (prerequisite)
- issues/407d-player-state-transitions.md (prerequisite, calls check)

---

## Acceptance Criteria

- [x] player.start_game() enables victory checking
- [x] player.is_game_started() returns game start state
- [x] player.is_game_ended() returns game end state
- [x] player.check_victory_conditions() detects single-team victory
- [x] player.check_victory_conditions() detects draw
- [x] Winning team players marked as victorious
- [x] game_over event fires on game end
- [x] player.force_victory() ends game with custom winner
- [x] player.force_defeat() triggers defeat flow
- [x] player.defeat_team() defeats all on team
- [x] player.get_winning_players() returns victorious list
- [x] player.get_game_result() returns game state
- [x] Victory check called after player defeat/leave
- [x] Game state resets with player.reset()
- [x] Unit tests pass

---

## Notes

Victory conditions are only checked when the game has started and hasn't
ended. This prevents false positives during initialization.

The team-based victory model assumes players on the same team share victory.
This matches WC3's force-based victory (shared_victory flag from w3i).

Custom victory triggers can call force_victory directly to end the game
without going through the normal elimination process. This is needed for
maps with special win conditions (capture the flag, assassination, etc.).

The game_over event provides both the winning team and the reason. UI/audio
systems can hook this to show victory/defeat screens and play appropriate
sounds.

draw detection happens when all players are defeated or left, which can
occur in simultaneous elimination scenarios or if all players disconnect.

---

## Implementation Notes

**Completed:** 2025-12-27

### Changes Made

1. **Added game_state internal storage to src/runtime/player.lua:**
   - `started`: Boolean for game start
   - `ended`: Boolean for game end
   - `winning_team`: Winning team number (nil for draw)
   - `end_reason`: "elimination", "custom", or "draw"

2. **Game lifecycle functions:**
   - `start_game()` - enables victory checking
   - `is_game_started()` - returns game start state
   - `is_game_ended()` - returns game end state
   - `get_game_result()` - returns {ended, winning_team, end_reason}

3. **Victory detection:**
   - `check_victory_conditions()` - team elimination detection
   - `count_active_teams()` helper - counts non-neutral active teams
   - `declare_winner()` helper - marks team as victorious
   - `declare_draw()` helper - ends game with no winner

4. **Custom victory functions:**
   - `force_victory(slot_or_team, is_team)` - end game with custom winner
   - `force_defeat(slot)` - alias for defeat()
   - `defeat_team(team)` - defeat all players on team

5. **Query functions:**
   - `get_winning_players()` - returns array of victorious players

6. **Event system:**
   - Added `game_over` event to event_callbacks
   - Event fires with `{winner, reason}` data

7. **Integration:**
   - `_check_victory_conditions` hook called by defeat/leave (407d)
   - `reset()` clears game_state and re-hooks victory check

### Test Coverage

Added 21 new tests to test_player.lua (now 112 total):
- Victory condition checking (5 tests)
- force_victory (4 tests)
- force_defeat (1 test)
- defeat_team (2 tests)
- game_over events (2 tests)
- get_winning_players (2 tests)
- get_game_result (1 test)
- start_game (1 test)
- reset (1 test)
- Integration (2 tests)
