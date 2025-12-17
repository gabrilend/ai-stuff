# Issue 407: Create Player State Management

**Phase:** 4 - Runtime
**Type:** Feature
**Priority:** High
**Dependencies:** 401, 402

---

## Current Behavior

Player data from w3i (names, races, forces) is parsed but there's no runtime
player state management. No concept of current player, alliances, or victory
conditions.

---

## Intended Behavior

A player management system that:
- Initializes players from w3i data
- Tracks player state (active, defeated, victorious)
- Manages alliances and diplomacy
- Provides player lookups (by slot, color, name)
- Supports human and AI player types
- Handles player defeat and victory conditions

---

## Suggested Implementation Steps

1. **Create player module**
   ```
   src/runtime/
   └── player.lua
   ```

2. **Define player data structure**
   ```lua
   local players = {}  -- slot_id -> player data

   local Player = {
       slot = 0,            -- 0-15
       name = "",
       color = 0,           -- 0-23 (WC3 player colors)

       type = "human",      -- human, computer, neutral
       controller = nil,    -- reference to AI controller if computer

       race = "human",      -- human, orc, undead, nightelf, random
       team = 0,            -- force/team number

       state = "active",    -- active, defeated, victorious, left

       -- Alliance flags (indexed by other player slot)
       alliances = {},      -- slot -> { ally, vision, control, etc. }
   }
   ```

3. **Initialize from w3i data**
   ```lua
   function player.init_from_w3i(w3i_data)
       players = {}

       for _, p in ipairs(w3i_data.players) do
           local slot = p.number
           players[slot] = {
               slot = slot,
               name = p.name,
               type = p.type,
               race = p.race,
               team = 0,  -- Set from forces
               state = "active",
               alliances = {},
           }
       end

       -- Set teams from forces
       for _, force in ipairs(w3i_data.forces) do
           for _, slot in ipairs(force.players) do
               if players[slot] then
                   players[slot].team = force.number

                   -- Set alliance flags from force settings
                   if force.flags.allied then
                       set_mutual_alliance(force.players, "ally", true)
                   end
                   if force.flags.share_vision then
                       set_mutual_alliance(force.players, "vision", true)
                   end
               end
           end
       end

       -- Initialize neutral player (slot 15 by convention)
       players[15] = {
           slot = 15,
           name = "Neutral",
           type = "neutral",
           race = "neutral",
           team = -1,
           state = "active",
           alliances = {},
       }
   end
   ```

4. **Player queries**
   ```lua
   function player.get(slot)
       return players[slot]
   end

   function player.get_all()
       local result = {}
       for slot, p in pairs(players) do
           result[#result + 1] = p
       end
       return result
   end

   function player.get_active()
       local result = {}
       for slot, p in pairs(players) do
           if p.state == "active" then
               result[#result + 1] = p
           end
       end
       return result
   end

   function player.get_by_type(player_type)
       local result = {}
       for slot, p in pairs(players) do
           if p.type == player_type then
               result[#result + 1] = p
           end
       end
       return result
   end
   ```

5. **Alliance management**
   ```lua
   local ALLIANCE_FLAGS = {
       passive = false,     -- Don't auto-attack
       help_request = false,
       help_response = false,
       shared_xp = false,
       shared_spells = false,
       shared_vision = false,
       shared_control = false,
       shared_advanced_control = false,
       rescuable = false,
       shared_victory = false,
   }

   function player.set_alliance(from_slot, to_slot, flag, value)
       local p = players[from_slot]
       if not p then return end

       p.alliances[to_slot] = p.alliances[to_slot] or {}
       p.alliances[to_slot][flag] = value

       fire_event("alliance_changed", from_slot, to_slot, flag, value)
   end

   function player.get_alliance(from_slot, to_slot, flag)
       local p = players[from_slot]
       if not p or not p.alliances[to_slot] then
           return false
       end
       return p.alliances[to_slot][flag] or false
   end

   function player.is_ally(slot_a, slot_b)
       if slot_a == slot_b then return true end
       return player.get_alliance(slot_a, slot_b, "passive") and
              player.get_alliance(slot_b, slot_a, "passive")
   end

   function player.is_enemy(slot_a, slot_b)
       return not player.is_ally(slot_a, slot_b)
   end
   ```

6. **Player state transitions**
   ```lua
   function player.defeat(slot)
       local p = players[slot]
       if not p or p.state ~= "active" then return end

       p.state = "defeated"
       fire_event("player_defeated", slot)

       -- Destroy or transfer remaining units
       for entity in ecs.query_single("owner") do
           local owner = ecs.get_component(entity, "owner")
           if owner.player_id == slot then
               -- Option: destroy, transfer to neutral, or leave
               ecs.destroy_entity(entity)
           end
       end

       check_victory_conditions()
   end

   function player.set_victorious(slot)
       local p = players[slot]
       if not p then return end

       p.state = "victorious"
       fire_event("player_victorious", slot)
   end

   function player.leave(slot)
       -- For multiplayer - player disconnected
       local p = players[slot]
       if not p then return end

       p.state = "left"
       fire_event("player_left", slot)

       -- Could transfer units to ally or destroy
   end
   ```

7. **Victory condition checking**
   ```lua
   function check_victory_conditions()
       local active_teams = {}

       for slot, p in pairs(players) do
           if p.state == "active" and p.type ~= "neutral" then
               active_teams[p.team] = true
           end
       end

       local team_count = 0
       local winning_team = nil
       for team, _ in pairs(active_teams) do
           team_count = team_count + 1
           winning_team = team
       end

       if team_count == 1 then
           -- One team remaining - they win
           for slot, p in pairs(players) do
               if p.team == winning_team and p.state == "active" then
                   player.set_victorious(slot)
               end
           end
           fire_event("game_over", winning_team)
       elseif team_count == 0 then
           -- No one left - draw
           fire_event("game_over", nil)
       end
   end
   ```

8. **Local player (for UI)**
   ```lua
   local local_player_slot = 0

   function player.set_local(slot)
       local_player_slot = slot
   end

   function player.get_local()
       return players[local_player_slot]
   end

   function player.get_local_slot()
       return local_player_slot
   end
   ```

---

## Technical Notes

### WC3 Player Slots

- Slots 0-11: Standard player slots
- Slots 12-15: Reserved (neutral hostile, passive, victim, etc.)
- Slot 15: Typically neutral passive

### Player Colors

WC3 has 24 player colors (extended in Reforged). Color doesn't always match
slot number.

### Alliance Symmetry

Alliances in WC3 are NOT necessarily symmetric. Player A can be allied to
Player B without B being allied to A. This affects targeting and abilities.

### Force vs Team

Forces in w3i define initial alliances and victory conditions.
"Team" or "force number" groups players for shared victory.

### Fog of War

Vision sharing is tracked via alliances. The rendering system will use
`shared_vision` alliance flag to determine what each player can see.

---

## Related Documents

- issues/103-parse-war3map-w3i.md (player/force definitions)
- issues/406-build-resource-management-system.md (per-player resources)
- issues/402-build-entity-component-system.md (owner component)

---

## Acceptance Criteria

- [ ] Initialize players from w3i data
- [ ] Player state tracking (active, defeated, victorious)
- [ ] Alliance flags (passive, vision, control, etc.)
- [ ] Alliance queries (is_ally, is_enemy)
- [ ] Player defeat handling
- [ ] Victory condition checking
- [ ] Player queries (by slot, type, team)
- [ ] Local player for UI
- [ ] Alliance change events
- [ ] Neutral player support
- [ ] Unit tests for player operations

---

## Notes

The player system ties together many other systems:
- Ownership determines unit control and targeting
- Alliances affect combat and vision
- Resources are per-player
- Victory/defeat ends the game

Keep the API clean and focused. Complex diplomacy features can be added
later - start with the basics needed for standard melee games.

The distinction between "force" (w3i concept) and runtime alliances matters.
Forces set initial state, but alliances can change during gameplay via
triggers.
