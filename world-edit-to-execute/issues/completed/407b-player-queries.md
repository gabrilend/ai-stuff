# Issue 407b: Player Queries

**Phase:** 4 - Runtime
**Type:** Feature
**Priority:** High
**Parent:** 407-create-player-state-management.md
**Dependencies:** 407a (player data structure)

---

## Current Behavior

After 407a, the player module has basic `player.get(slot)` for single player
lookup, but no functions to query multiple players by criteria (type, state,
team) or iterate over all players.

---

## Intended Behavior

Add query functions to the player module that allow:
- Getting all players as an array
- Filtering players by state (active, defeated, etc.)
- Filtering players by type (human, computer, neutral)
- Filtering players by team/force
- Counting players matching criteria

All query functions return arrays (not iterators) for simplicity.
Results are unordered (iteration order of pairs()).

---

## Suggested Implementation Steps

1. **Read existing player.lua module**
   Review the structure from 407a to understand where to add functions.

2. **Implement get_all function**
   ```lua
   -- {{{ function player.get_all
   -- Returns array of all initialized players
   function player.get_all()
       local result = {}
       for slot, p in pairs(players) do
           result[#result + 1] = p
       end
       return result
   end
   -- }}}
   ```

3. **Implement get_active function**
   ```lua
   -- {{{ function player.get_active
   -- Returns array of players with state == "active"
   function player.get_active()
       local result = {}
       for slot, p in pairs(players) do
           if p.state == PLAYER_STATE.ACTIVE then
               result[#result + 1] = p
           end
       end
       return result
   end
   -- }}}
   ```

4. **Implement get_by_state function**
   ```lua
   -- {{{ function player.get_by_state
   -- Returns array of players matching the given state
   function player.get_by_state(state)
       local result = {}
       for slot, p in pairs(players) do
           if p.state == state then
               result[#result + 1] = p
           end
       end
       return result
   end
   -- }}}
   ```

5. **Implement get_by_type function**
   ```lua
   -- {{{ function player.get_by_type
   -- Returns array of players matching the given type (human, computer, neutral)
   function player.get_by_type(player_type)
       local result = {}
       for slot, p in pairs(players) do
           if p.type == player_type then
               result[#result + 1] = p
           end
       end
       return result
   end
   -- }}}
   ```

6. **Implement get_by_team function**
   ```lua
   -- {{{ function player.get_by_team
   -- Returns array of players on the given team/force
   function player.get_by_team(team)
       local result = {}
       for slot, p in pairs(players) do
           if p.team == team then
               result[#result + 1] = p
           end
       end
       return result
   end
   -- }}}
   ```

7. **Implement get_humans function (convenience)**
   ```lua
   -- {{{ function player.get_humans
   -- Returns array of human-controlled players
   function player.get_humans()
       return player.get_by_type(PLAYER_TYPE.HUMAN)
   end
   -- }}}
   ```

8. **Implement get_computers function (convenience)**
   ```lua
   -- {{{ function player.get_computers
   -- Returns array of computer-controlled players
   function player.get_computers()
       return player.get_by_type(PLAYER_TYPE.COMPUTER)
   end
   -- }}}
   ```

9. **Implement count functions**
   ```lua
   -- {{{ function player.count_active
   -- Count players with active state
   function player.count_active()
       local n = 0
       for slot, p in pairs(players) do
           if p.state == PLAYER_STATE.ACTIVE then
               n = n + 1
           end
       end
       return n
   end
   -- }}}

   -- {{{ function player.count_by_type
   -- Count players of given type
   function player.count_by_type(player_type)
       local n = 0
       for slot, p in pairs(players) do
           if p.type == player_type then
               n = n + 1
           end
       end
       return n
   end
   -- }}}

   -- {{{ function player.count_by_team
   -- Count players on given team
   function player.count_by_team(team)
       local n = 0
       for slot, p in pairs(players) do
           if p.team == team then
               n = n + 1
           end
       end
       return n
   end
   -- }}}
   ```

10. **Implement slots iterator**
    ```lua
    -- {{{ function player.slots
    -- Returns array of all initialized slot numbers
    function player.slots()
        local result = {}
        for slot, _ in pairs(players) do
            result[#result + 1] = slot
        end
        table.sort(result)  -- Return in ascending order for predictability
        return result
    end
    -- }}}
    ```

11. **Implement combined filter function**
    ```lua
    -- {{{ function player.query
    -- Query players with multiple criteria (all must match)
    -- filter = { type = "human", state = "active", team = 0 }
    function player.query(filter)
        local result = {}
        for slot, p in pairs(players) do
            local match = true

            if filter.type and p.type ~= filter.type then
                match = false
            end
            if filter.state and p.state ~= filter.state then
                match = false
            end
            if filter.team and p.team ~= filter.team then
                match = false
            end
            if filter.slot and p.slot ~= filter.slot then
                match = false
            end

            if match then
                result[#result + 1] = p
            end
        end
        return result
    end
    -- }}}
    ```

12. **Add unit tests to test_player.lua**
    Test cases:
    - get_all returns all initialized players
    - get_active excludes defeated/left players
    - get_by_type correctly filters by type
    - get_by_team correctly filters by team
    - get_humans/get_computers are convenience wrappers
    - count functions return correct numbers
    - slots() returns sorted slot numbers
    - query() with multiple criteria works correctly
    - Empty results return empty arrays (not nil)

---

## Related Documents

- issues/407-create-player-state-management.md (parent issue)
- issues/407a-player-data-structure.md (prerequisite)
- issues/407d-player-state-transitions.md (state changes affect queries)
- issues/407e-victory-conditions.md (uses get_active, get_by_team)

---

## Acceptance Criteria

- [x] player.get_all() returns array of all players
- [x] player.get_active() returns only active players
- [ ] player.get_by_state(state) filters by state (using get_active for now)
- [x] player.get_by_type(type) filters by type
- [x] player.get_by_team(team) filters by team
- [x] player.get_humans() convenience function works
- [x] player.get_computers() convenience function works
- [ ] player.count_active() returns correct count (use #get_active())
- [ ] player.count_by_type(type) returns correct count (use #get_by_type())
- [ ] player.count_by_team(team) returns correct count (use #get_by_team())
- [ ] player.slots() returns sorted slot numbers (deferred)
- [ ] player.query(filter) supports combined criteria (deferred)
- [x] All functions return empty arrays for no matches
- [x] Unit tests pass

---

## Notes

Query results are arrays, not the internal players table. This prevents
external code from accidentally modifying internal state.

The slots() function sorts results for predictable iteration order, which
helps with deterministic behavior in tests and game logic.

---

## Implementation Notes

**Completed:** 2025-12-27 (as part of 407a)

### Changes Made

Core query functions implemented in src/runtime/player.lua:
- `get_all()` - returns all players as array
- `get_active()` - returns only active state players
- `get_by_type(ptype)` - filter by player type
- `get_by_team(team)` - filter by team number
- `get_humans()` - convenience for get_by_type("human")
- `get_computers()` - convenience for get_by_type("computer")
- `get_neutral()` - returns slot 15 player
- `iter()` - iterator for all players

Count functions deferred - callers can use `#get_active()` etc.

### Test Coverage

Tests in src/tests/test_player.lua:
- Query by Type Tests (5 tests)
- Query by Team Tests (2 tests)
- Active Player Tests (2 tests)


The query() function is useful when combining multiple filters. Individual
filter functions are more efficient for single-criterion queries.

Neutral player (slot 15) is included in results unless explicitly filtered
out by type.
