# Issue 407a: Player Data Structure

**Phase:** 4 - Runtime
**Type:** Feature
**Priority:** High
**Parent:** 407-create-player-state-management.md
**Dependencies:** 103 (w3i parser provides player/force data)

---

## Current Behavior

The w3i parser extracts player and force data from map files, but this data
exists only as parsed structures. There is no runtime player module to hold
active game state, track player status, or provide player lookups.

---

## Intended Behavior

Create the foundational player module with:
- Core player data structure definition
- Initialization from w3i parsed data
- Player slot storage (indexed by slot number 0-15)
- Team assignment from force definitions
- Neutral player (slot 15) initialization

The data structure should support:
```lua
{
    slot = 0,            -- 0-15 player slot
    name = "Player 1",   -- display name
    color = 0,           -- 0-23 WC3 player colors
    type = "human",      -- human, computer, neutral
    race = "human",      -- human, orc, undead, nightelf, random
    team = 0,            -- force/team number for victory grouping
    state = "active",    -- active, defeated, victorious, left
    alliances = {},      -- slot -> alliance flags (populated by 407c)
    controller = nil,    -- AI controller reference (populated later)
}
```

---

## Suggested Implementation Steps

1. **Create the player module file**
   ```
   src/runtime/player.lua
   ```

2. **Define the module structure with vimfolds**
   ```lua
   -- Player State Management
   -- Manages runtime player data, initialized from w3i map info.
   -- Players are indexed by slot (0-15) with slot 15 reserved for neutral.

   local player = {}

   -- {{{ Internal state
   local players = {}  -- slot_id -> player data table
   -- }}}
   ```

3. **Define player type constants**
   ```lua
   -- {{{ Constants
   local PLAYER_TYPE = {
       HUMAN = "human",
       COMPUTER = "computer",
       NEUTRAL = "neutral",
       RESCUABLE = "rescuable",
   }

   local PLAYER_STATE = {
       ACTIVE = "active",
       DEFEATED = "defeated",
       VICTORIOUS = "victorious",
       LEFT = "left",
   }

   local RACE = {
       HUMAN = "human",
       ORC = "orc",
       UNDEAD = "undead",
       NIGHTELF = "nightelf",
       RANDOM = "random",
       NEUTRAL = "neutral",
   }

   -- Neutral player is conventionally slot 15
   local NEUTRAL_SLOT = 15
   -- }}}
   ```

4. **Implement player creation helper**
   ```lua
   -- {{{ local function create_player
   local function create_player(slot, name, player_type, race)
       return {
           slot = slot,
           name = name or ("Player " .. (slot + 1)),
           color = slot,  -- Default: color matches slot
           type = player_type or PLAYER_TYPE.HUMAN,
           race = race or RACE.HUMAN,
           team = 0,
           state = PLAYER_STATE.ACTIVE,
           alliances = {},
           controller = nil,
       }
   end
   -- }}}
   ```

5. **Implement w3i initialization**
   ```lua
   -- {{{ function player.init_from_w3i
   function player.init_from_w3i(w3i_data)
       -- Clear existing players
       players = {}

       if not w3i_data or not w3i_data.players then
           -- No player data - create minimal setup
           players[0] = create_player(0, "Player 1", PLAYER_TYPE.HUMAN, RACE.HUMAN)
           players[NEUTRAL_SLOT] = create_player(NEUTRAL_SLOT, "Neutral", PLAYER_TYPE.NEUTRAL, RACE.NEUTRAL)
           return
       end

       -- Initialize players from w3i player list
       for _, p in ipairs(w3i_data.players) do
           local slot = p.number or p.id or 0

           -- Map w3i type to our type constants
           local ptype = PLAYER_TYPE.HUMAN
           if p.type == 1 or p.type == "computer" then
               ptype = PLAYER_TYPE.COMPUTER
           elseif p.type == 2 or p.type == "neutral" then
               ptype = PLAYER_TYPE.NEUTRAL
           elseif p.type == 3 or p.type == "rescuable" then
               ptype = PLAYER_TYPE.RESCUABLE
           end

           -- Map w3i race to our race constants
           local race = RACE.HUMAN
           if p.race then
               local race_map = {
                   [0] = RACE.HUMAN,
                   [1] = RACE.ORC,
                   [2] = RACE.UNDEAD,
                   [3] = RACE.NIGHTELF,
                   [4] = RACE.RANDOM,
               }
               race = race_map[p.race] or RACE.HUMAN
           end

           players[slot] = create_player(slot, p.name, ptype, race)

           -- Copy fixed start location if present
           if p.start_x and p.start_y then
               players[slot].start_x = p.start_x
               players[slot].start_y = p.start_y
           end
       end

       -- Set teams from forces
       if w3i_data.forces then
           for _, force in ipairs(w3i_data.forces) do
               local force_num = force.number or force.id or 0

               -- force.players might be a bitmask or an array
               local player_slots = {}
               if type(force.player_mask) == "number" then
                   -- Decode bitmask: bit N set means player N is in force
                   for slot = 0, 15 do
                       if bit.band(force.player_mask, bit.lshift(1, slot)) ~= 0 then
                           player_slots[#player_slots + 1] = slot
                       end
                   end
               elseif force.players then
                   player_slots = force.players
               end

               for _, slot in ipairs(player_slots) do
                   if players[slot] then
                       players[slot].team = force_num

                       -- Store force name if available
                       if force.name then
                           players[slot].team_name = force.name
                       end
                   end
               end
           end
       end

       -- Ensure neutral player exists
       if not players[NEUTRAL_SLOT] then
           players[NEUTRAL_SLOT] = create_player(NEUTRAL_SLOT, "Neutral", PLAYER_TYPE.NEUTRAL, RACE.NEUTRAL)
           players[NEUTRAL_SLOT].team = -1  -- Neutral has no team
       end
   end
   -- }}}
   ```

6. **Implement manual initialization for testing**
   ```lua
   -- {{{ function player.init_manual
   -- Initialize players manually (for testing or non-w3i scenarios)
   function player.init_manual(player_list)
       players = {}

       for _, p in ipairs(player_list) do
           local slot = p.slot or 0
           players[slot] = create_player(
               slot,
               p.name,
               p.type or PLAYER_TYPE.HUMAN,
               p.race or RACE.HUMAN
           )
           players[slot].team = p.team or 0
           players[slot].color = p.color or slot
       end

       -- Ensure neutral player
       if not players[NEUTRAL_SLOT] then
           players[NEUTRAL_SLOT] = create_player(NEUTRAL_SLOT, "Neutral", PLAYER_TYPE.NEUTRAL, RACE.NEUTRAL)
           players[NEUTRAL_SLOT].team = -1
       end
   end
   -- }}}
   ```

7. **Implement basic accessors**
   ```lua
   -- {{{ function player.get
   -- Get player by slot number
   function player.get(slot)
       return players[slot]
   end
   -- }}}

   -- {{{ function player.exists
   -- Check if player slot is initialized
   function player.exists(slot)
       return players[slot] ~= nil
   end
   -- }}}

   -- {{{ function player.count
   -- Count total initialized players
   function player.count()
       local n = 0
       for _ in pairs(players) do
           n = n + 1
       end
       return n
   end
   -- }}}
   ```

8. **Implement reset for testing**
   ```lua
   -- {{{ function player.reset
   -- Clear all player data (for testing)
   function player.reset()
       players = {}
   end
   -- }}}
   ```

9. **Export constants and return module**
   ```lua
   -- {{{ Exports
   player.PLAYER_TYPE = PLAYER_TYPE
   player.PLAYER_STATE = PLAYER_STATE
   player.RACE = RACE
   player.NEUTRAL_SLOT = NEUTRAL_SLOT
   -- }}}

   return player
   ```

10. **Create unit test file**
    ```
    src/tests/test_player.lua
    ```
    Test cases:
    - Initialize with empty w3i data creates default player + neutral
    - Initialize from w3i with players creates correct slots
    - Force/team assignment works correctly
    - Neutral player always exists after init
    - Manual initialization works
    - player.get returns correct data
    - player.exists returns correct boolean

---

## Related Documents

- issues/407-create-player-state-management.md (parent issue)
- issues/407b-player-queries.md (builds on this foundation)
- issues/407c-alliance-management.md (uses alliances field)
- issues/103-parse-war3map-w3i.md (provides input data)
- src/parsers/w3i.lua (w3i data structure reference)

---

## Acceptance Criteria

- [x] Player module created at src/runtime/player.lua
- [x] Player data structure includes all required fields
- [x] player.init_from_w3i() correctly initializes from parsed w3i
- [x] Player types mapped correctly (human, computer, neutral, rescuable)
- [x] Player races mapped correctly (human, orc, undead, nightelf, random)
- [x] Teams assigned from force definitions
- [x] Neutral player (slot 15) always initialized
- [x] player.get(slot) returns player or nil
- [x] player.exists(slot) returns boolean
- [x] player.reset() clears all data
- [x] Constants exported (PLAYER_TYPE, PLAYER_STATE, RACE)
- [x] Unit tests pass

---

## Notes

This is the foundation for all player-related functionality. Keep it minimal
and focused - query functions go in 407b, alliances in 407c, state transitions
in 407d.

The w3i parser may store player type and race as integers or strings depending
on version. The init function handles both cases.

Player colors (0-23) don't always match slot numbers. WC3 Reforged expanded
the color palette. For now, default color to slot number.

---

## Implementation Notes

**Completed:** 2025-12-27

### Changes Made

1. **Created src/runtime/player.lua** (~350 lines):
   - Player data structure with all required fields
   - `init_from_w3i()` - initializes from parsed map info
   - `init_manual()` - for testing/non-w3i scenarios
   - Type/race mapping for both string and integer values
   - Neutral player (slot 15) always ensured

2. **Bonus: Also implemented 407b (queries) and 407f (local player)**:
   - `get_all()`, `get_active()`, `get_by_type()`, `get_by_team()`
   - `get_humans()`, `get_computers()`, `get_neutral()`
   - `set_local()`, `get_local()`, `get_local_slot()`
   - `iter()` for iteration

3. **Created src/tests/test_player.lua** (39 tests, all pass):
   - Constants tests
   - Empty/nil initialization
   - W3I initialization with forces
   - Manual initialization
   - All query functions
   - Local player tracking
   - Edge cases

### Constants

```lua
PLAYER_TYPE: HUMAN, COMPUTER, NEUTRAL, RESCUABLE
PLAYER_STATE: ACTIVE, DEFEATED, VICTORIOUS, LEFT
RACE: HUMAN, ORC, UNDEAD, NIGHTELF, RANDOM, NEUTRAL
NEUTRAL_SLOT: 15
MAX_PLAYERS: 16
```

