--[[
Player State Management

Manages runtime player data, initialized from w3i map info.
Players are indexed by slot (0-15) with slot 15 reserved for neutral.

Provides:
- Player data structure (slot, name, type, race, team, state)
- Initialization from w3i parsed data
- Basic accessors (get, exists, count)
- Query functions (get_all, get_active, get_by_type, get_by_team)
- Alliance management (set_alliance, get_alliance, is_ally, is_enemy)
- Local player tracking for UI/camera perspective
- Constants for player types, states, races, and alliance flags
]]

local player = {}

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

-- Maximum player slots (0-15 = 16 slots)
local MAX_PLAYERS = 16

-- Alliance flags (407c)
-- Note: Alliances are asymmetric - A->B can differ from B->A
local ALLIANCE_FLAG = {
    PASSIVE = "passive",                        -- Don't auto-attack this player's units
    HELP_REQUEST = "help_request",              -- Show help requests from this player
    HELP_RESPONSE = "help_response",            -- Respond to help requests from this player
    SHARED_XP = "shared_xp",                    -- Share experience with this player
    SHARED_SPELLS = "shared_spells",            -- Can target with beneficial spells
    SHARED_VISION = "shared_vision",            -- See what this player sees
    SHARED_CONTROL = "shared_control",          -- Can control this player's units
    SHARED_ADVANCED_CONTROL = "shared_advanced_control",  -- Full control including sell/destroy
    RESCUABLE = "rescuable",                    -- This player's units can be rescued
    SHARED_VICTORY = "shared_victory",          -- Share victory/defeat with this player
}
-- }}}

-- {{{ Internal state
local players = {}  -- slot_id -> player data table
local local_player_slot = 0  -- For UI/camera (407f)
-- }}}

-- {{{ local function create_player
-- Create a new player data structure with default values.
-- @param slot Player slot number (0-15)
-- @param name Display name
-- @param player_type Player type (human, computer, neutral, rescuable)
-- @param race Player race (human, orc, undead, nightelf, random, neutral)
-- @return Player data table
local function create_player(slot, name, player_type, race)
    return {
        slot = slot,
        name = name or ("Player " .. (slot + 1)),
        color = slot,  -- Default: color matches slot
        type = player_type or PLAYER_TYPE.HUMAN,
        race = race or RACE.HUMAN,
        team = 0,
        state = PLAYER_STATE.ACTIVE,
        alliances = {},  -- Populated by 407c
        controller = nil,  -- AI controller reference
        -- Start position from w3i (optional)
        start_x = nil,
        start_y = nil,
        -- Team name from force (optional)
        team_name = nil,
    }
end
-- }}}

-- {{{ local function map_player_type
-- Map w3i player type to our constants.
-- @param w3i_type Type from w3i (integer or string)
-- @return PLAYER_TYPE constant
local function map_player_type(w3i_type)
    -- String types (from w3i parser)
    if w3i_type == "human" then return PLAYER_TYPE.HUMAN end
    if w3i_type == "computer" then return PLAYER_TYPE.COMPUTER end
    if w3i_type == "neutral" then return PLAYER_TYPE.NEUTRAL end
    if w3i_type == "rescuable" then return PLAYER_TYPE.RESCUABLE end

    -- Integer types (raw values)
    if w3i_type == 0 then return PLAYER_TYPE.NEUTRAL end  -- Neutral in some formats
    if w3i_type == 1 then return PLAYER_TYPE.HUMAN end
    if w3i_type == 2 then return PLAYER_TYPE.COMPUTER end
    if w3i_type == 3 then return PLAYER_TYPE.RESCUABLE end

    return PLAYER_TYPE.HUMAN  -- Default fallback
end
-- }}}

-- {{{ local function map_race
-- Map w3i race to our constants.
-- @param w3i_race Race from w3i (integer or string)
-- @return RACE constant
local function map_race(w3i_race)
    -- String types (from w3i parser)
    if w3i_race == "human" then return RACE.HUMAN end
    if w3i_race == "orc" then return RACE.ORC end
    if w3i_race == "undead" then return RACE.UNDEAD end
    if w3i_race == "night_elf" or w3i_race == "nightelf" then return RACE.NIGHTELF end
    if w3i_race == "random" then return RACE.RANDOM end
    if w3i_race == "neutral" then return RACE.NEUTRAL end

    -- Integer types (raw values)
    if w3i_race == 0 then return RACE.HUMAN end
    if w3i_race == 1 then return RACE.ORC end
    if w3i_race == 2 then return RACE.UNDEAD end
    if w3i_race == 3 then return RACE.NIGHTELF end
    if w3i_race == 4 then return RACE.RANDOM end

    return RACE.HUMAN  -- Default fallback
end
-- }}}

-- {{{ function player.init_from_w3i
-- Initialize players from parsed w3i data.
-- @param w3i_data Parsed map info from w3i parser
function player.init_from_w3i(w3i_data)
    -- Clear existing players
    players = {}

    if not w3i_data or not w3i_data.players then
        -- No player data - create minimal setup
        players[0] = create_player(0, "Player 1", PLAYER_TYPE.HUMAN, RACE.HUMAN)
        players[NEUTRAL_SLOT] = create_player(NEUTRAL_SLOT, "Neutral", PLAYER_TYPE.NEUTRAL, RACE.NEUTRAL)
        players[NEUTRAL_SLOT].team = -1
        return
    end

    -- Initialize players from w3i player list
    for _, p in ipairs(w3i_data.players) do
        local slot = p.number or p.id or 0

        local ptype = map_player_type(p.type)
        local race = map_race(p.race)

        players[slot] = create_player(slot, p.name, ptype, race)

        -- Copy start location if present
        if p.start_x and p.start_y then
            players[slot].start_x = p.start_x
            players[slot].start_y = p.start_y
        end

        -- Copy fixed_start flag if present
        if p.fixed_start then
            players[slot].fixed_start = p.fixed_start
        end
    end

    -- Set teams from forces and apply alliance flags
    if w3i_data.forces then
        for force_idx, force in ipairs(w3i_data.forces) do
            local force_num = force.number or force.id or force_idx

            -- force.players is an array of slot numbers (decoded from player_mask)
            local player_slots = force.players or {}

            for _, slot in ipairs(player_slots) do
                if players[slot] then
                    players[slot].team = force_num

                    -- Store force name if available
                    if force.name then
                        players[slot].team_name = force.name
                    end
                end
            end

            -- Apply alliance flags from force settings
            -- Only apply to existing players in this force
            local valid_slots = {}
            for _, slot in ipairs(player_slots) do
                if players[slot] then
                    valid_slots[#valid_slots + 1] = slot
                end
            end

            local flags = force.flags or {}

            -- Allied forces share passive alliance (don't auto-attack)
            if flags.allied then
                player.set_team_alliance(valid_slots, ALLIANCE_FLAG.PASSIVE, true)
            end

            -- Allied victory means shared victory
            if flags.allied_victory then
                player.set_team_alliance(valid_slots, ALLIANCE_FLAG.SHARED_VICTORY, true)
            end

            -- Shared vision
            if flags.share_vision then
                player.set_team_alliance(valid_slots, ALLIANCE_FLAG.SHARED_VISION, true)
            end

            -- Shared unit control (rarely used in forces)
            if flags.share_unit_control then
                player.set_team_alliance(valid_slots, ALLIANCE_FLAG.SHARED_CONTROL, true)
            end

            -- Shared advanced control
            if flags.share_adv_control then
                player.set_team_alliance(valid_slots, ALLIANCE_FLAG.SHARED_ADVANCED_CONTROL, true)
            end
        end
    end

    -- Ensure neutral player exists
    if not players[NEUTRAL_SLOT] then
        players[NEUTRAL_SLOT] = create_player(NEUTRAL_SLOT, "Neutral", PLAYER_TYPE.NEUTRAL, RACE.NEUTRAL)
    end
    players[NEUTRAL_SLOT].team = -1  -- Neutral has no team
end
-- }}}

-- {{{ function player.init_manual
-- Initialize players manually (for testing or non-w3i scenarios).
-- @param player_list Array of player definition tables
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

        -- Optional fields
        if p.start_x then players[slot].start_x = p.start_x end
        if p.start_y then players[slot].start_y = p.start_y end
        if p.team_name then players[slot].team_name = p.team_name end
    end

    -- Ensure neutral player
    if not players[NEUTRAL_SLOT] then
        players[NEUTRAL_SLOT] = create_player(NEUTRAL_SLOT, "Neutral", PLAYER_TYPE.NEUTRAL, RACE.NEUTRAL)
        players[NEUTRAL_SLOT].team = -1
    end
end
-- }}}

-- {{{ function player.get
-- Get player by slot number.
-- @param slot Player slot (0-15)
-- @return Player data table or nil if not found
function player.get(slot)
    return players[slot]
end
-- }}}

-- {{{ function player.exists
-- Check if player slot is initialized.
-- @param slot Player slot (0-15)
-- @return true if player exists
function player.exists(slot)
    return players[slot] ~= nil
end
-- }}}

-- {{{ function player.count
-- Count total initialized players.
-- @return Number of initialized players
function player.count()
    local n = 0
    for _ in pairs(players) do
        n = n + 1
    end
    return n
end
-- }}}

-- {{{ function player.get_all
-- Get all initialized players.
-- @return Array of player data tables
function player.get_all()
    local result = {}
    for _, p in pairs(players) do
        result[#result + 1] = p
    end
    return result
end
-- }}}

-- {{{ function player.get_active
-- Get all active players (not defeated, victorious, or left).
-- @return Array of active player data tables
function player.get_active()
    local result = {}
    for _, p in pairs(players) do
        if p.state == PLAYER_STATE.ACTIVE then
            result[#result + 1] = p
        end
    end
    return result
end
-- }}}

-- {{{ function player.get_by_type
-- Get players of a specific type.
-- @param ptype Player type constant
-- @return Array of matching player data tables
function player.get_by_type(ptype)
    local result = {}
    for _, p in pairs(players) do
        if p.type == ptype then
            result[#result + 1] = p
        end
    end
    return result
end
-- }}}

-- {{{ function player.get_by_team
-- Get players on a specific team.
-- @param team_num Team number
-- @return Array of matching player data tables
function player.get_by_team(team_num)
    local result = {}
    for _, p in pairs(players) do
        if p.team == team_num then
            result[#result + 1] = p
        end
    end
    return result
end
-- }}}

-- {{{ function player.get_humans
-- Get all human-controlled players.
-- @return Array of human player data tables
function player.get_humans()
    return player.get_by_type(PLAYER_TYPE.HUMAN)
end
-- }}}

-- {{{ function player.get_computers
-- Get all computer-controlled players.
-- @return Array of computer player data tables
function player.get_computers()
    return player.get_by_type(PLAYER_TYPE.COMPUTER)
end
-- }}}

-- {{{ function player.get_neutral
-- Get the neutral player (slot 15).
-- @return Neutral player data table or nil
function player.get_neutral()
    return players[NEUTRAL_SLOT]
end
-- }}}

-- ============================================================================
-- Alliance Management (407c)
-- ============================================================================

-- {{{ function player.set_alliance
-- Set an alliance flag from one player to another.
-- Note: Alliances are NOT symmetric - A->B can differ from B->A.
-- @param from_slot Source player slot
-- @param to_slot Target player slot
-- @param flag ALLIANCE_FLAG constant
-- @param value Boolean value for the flag
-- @return true on success, false and error message on failure
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

    -- Fire event if changed (hook for event system)
    if old_value ~= value and player._on_alliance_changed then
        player._on_alliance_changed(from_slot, to_slot, flag, value)
    end

    return true
end
-- }}}

-- {{{ function player.get_alliance
-- Get an alliance flag from one player to another.
-- @param from_slot Source player slot
-- @param to_slot Target player slot
-- @param flag ALLIANCE_FLAG constant
-- @return Boolean value of the flag (false if not set or players don't exist)
function player.get_alliance(from_slot, to_slot, flag)
    local p = players[from_slot]
    if not p then return false end
    if not p.alliances[to_slot] then return false end
    return p.alliances[to_slot][flag] or false
end
-- }}}

-- {{{ function player.set_mutual_alliance
-- Set an alliance flag in both directions (symmetric).
-- @param slot_a First player slot
-- @param slot_b Second player slot
-- @param flag ALLIANCE_FLAG constant
-- @param value Boolean value for the flag
function player.set_mutual_alliance(slot_a, slot_b, flag, value)
    player.set_alliance(slot_a, slot_b, flag, value)
    player.set_alliance(slot_b, slot_a, flag, value)
end
-- }}}

-- {{{ function player.set_team_alliance
-- Set an alliance flag for all players in a list (mutual between all pairs).
-- @param slots Array of player slots
-- @param flag ALLIANCE_FLAG constant
-- @param value Boolean value for the flag
function player.set_team_alliance(slots, flag, value)
    for i = 1, #slots do
        for j = 1, #slots do
            if slots[i] ~= slots[j] then
                player.set_alliance(slots[i], slots[j], flag, value)
            end
        end
    end
end
-- }}}

-- {{{ function player.is_ally
-- Check if two players are mutually allied (both have passive flag).
-- A player is always allied with themselves.
-- @param slot_a First player slot
-- @param slot_b Second player slot
-- @return true if mutually allied
function player.is_ally(slot_a, slot_b)
    if slot_a == slot_b then return true end

    -- Both must have passive flag set toward each other
    return player.get_alliance(slot_a, slot_b, ALLIANCE_FLAG.PASSIVE) and
           player.get_alliance(slot_b, slot_a, ALLIANCE_FLAG.PASSIVE)
end
-- }}}

-- {{{ function player.is_enemy
-- Check if two players are enemies (not mutually allied).
-- @param slot_a First player slot
-- @param slot_b Second player slot
-- @return true if enemies
function player.is_enemy(slot_a, slot_b)
    return not player.is_ally(slot_a, slot_b)
end
-- }}}

-- {{{ function player.has_vision
-- Check if player A can see player B's units.
-- @param slot_a Viewer player slot
-- @param slot_b Target player slot
-- @return true if slot_a can see slot_b's units
function player.has_vision(slot_a, slot_b)
    if slot_a == slot_b then return true end
    -- A sees B if B shares vision with A
    return player.get_alliance(slot_b, slot_a, ALLIANCE_FLAG.SHARED_VISION)
end
-- }}}

-- {{{ function player.can_control
-- Check if player A can control player B's units.
-- @param slot_a Controller player slot
-- @param slot_b Target player slot
-- @return true if slot_a can control slot_b's units
function player.can_control(slot_a, slot_b)
    if slot_a == slot_b then return true end
    -- A controls B if B shares control with A
    return player.get_alliance(slot_b, slot_a, ALLIANCE_FLAG.SHARED_CONTROL)
end
-- }}}

-- {{{ function player.get_allies
-- Get array of all players allied to the given player.
-- @param slot Player slot
-- @return Array of allied player data tables
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

-- {{{ function player.get_enemies
-- Get array of all players hostile to the given player.
-- Excludes neutral player (slot 15).
-- @param slot Player slot
-- @return Array of enemy player data tables
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

-- ============================================================================
-- Local Player (407f)
-- ============================================================================

-- {{{ function player.set_local
-- Set the local player slot (for UI/camera purposes).
-- @param slot Local player slot
function player.set_local(slot)
    local_player_slot = slot
end
-- }}}

-- {{{ function player.get_local
-- Get the local player data.
-- @return Local player data table
function player.get_local()
    return players[local_player_slot]
end
-- }}}

-- {{{ function player.get_local_slot
-- Get the local player slot number.
-- @return Local player slot
function player.get_local_slot()
    return local_player_slot
end
-- }}}

-- {{{ function player.reset
-- Clear all player data (for testing).
function player.reset()
    players = {}
    local_player_slot = 0
end
-- }}}

-- {{{ function player.iter
-- Iterator for all players.
-- Usage: for slot, p in player.iter() do ... end
-- @return Iterator function
function player.iter()
    return pairs(players)
end
-- }}}

-- {{{ Exports
player.PLAYER_TYPE = PLAYER_TYPE
player.PLAYER_STATE = PLAYER_STATE
player.RACE = RACE
player.NEUTRAL_SLOT = NEUTRAL_SLOT
player.MAX_PLAYERS = MAX_PLAYERS
player.ALLIANCE_FLAG = ALLIANCE_FLAG

-- Internal for testing
player._create_player = create_player
player._map_player_type = map_player_type
player._map_race = map_race
-- }}}

return player
