--[[
Gathering Professions System (Issue 702b)

Handles gathering resources from world nodes: mining ore, picking herbs,
skinning corpses, chopping trees, fishing. Integrates with professions (702a).

Core concepts:
- Gatherable nodes: World entities with gatherable component
- Gathering flow: Channel action, yield calculation, skill-up
- Node depletion: Nodes have limited gathers, respawn after time
- Profession integration: Skill requirements, tools, progression

Usage:
    local gathering = require("runtime.systems.gathering")
    local ecs = require("runtime.ecs")

    -- Create a gatherable node
    local node = gathering.create_node({x=100, y=200}, "copper_vein", {
        yield_min = 1,
        yield_max = 3,
    })

    -- Entity gathers from node
    gathering.start_gather(entity, node)
]]

-- {{{ Configuration
local DIR = arg and arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path
-- }}}

local ecs = require("runtime.ecs")
local events = require("runtime.events")

local gathering = {}

-- ============================================================================
-- Constants
-- ============================================================================

-- {{{ RESOURCE_TYPE
-- Types of gatherable resources.
gathering.RESOURCE_TYPE = {
    MINERAL = "mineral",    -- Mining
    PLANT = "plant",        -- Herbalism
    CORPSE = "corpse",      -- Skinning
    WOOD = "wood",          -- Lumberjacking
    WATER = "water",        -- Fishing
}
-- }}}

-- {{{ GATHER_STATE
-- State of an ongoing gather action.
gathering.STATE = {
    IDLE = "idle",
    GATHERING = "gathering",
    INTERRUPTED = "interrupted",
}
-- }}}

-- ============================================================================
-- Event Constants
-- ============================================================================

-- {{{ Gathering events
gathering.EVENT = {
    GATHER_START = 400,
    GATHER_SUCCESS = 401,
    GATHER_FAILED = 402,
    GATHER_INTERRUPTED = 403,
    NODE_DEPLETED = 404,
    NODE_RESPAWNED = 405,
    RARE_FIND = 406,  -- Bonus resource proc
}
-- }}}

-- ============================================================================
-- Component Definitions
-- ============================================================================

-- {{{ GATHERABLE_DEFAULTS
-- Gatherable node component attached to world entities.
local GATHERABLE_DEFAULTS = {
    resource_type = nil,            -- One of RESOURCE_TYPE
    profession_required = nil,      -- Profession ID (e.g., "mining")
    skill_required = 1,             -- Minimum skill to gather

    -- Yield
    resource_id = nil,              -- Item ID produced
    yield_min = 1,                  -- Minimum yield per gather
    yield_max = 1,                  -- Maximum yield per gather

    -- Bonus drops
    bonus_chance = 0,               -- Chance for extra/rare drop (0.0-1.0)
    bonus_resource = nil,           -- Bonus item ID

    -- Node state
    remaining_gathers = 1,          -- Times can be gathered before depletion
    max_gathers = 1,                -- Original gather count (for respawn)
    depleted = false,               -- Is node currently depleted?
    respawn_time = 0,               -- Seconds to respawn (0 = never)
    respawn_at = 0,                 -- Timestamp when node respawns

    -- Requirements
    tool_required = nil,            -- Tool item ID required, nil = hands

    -- Skill progression
    gives_skillup = true,
    skillup_max = 100,              -- Stop giving skill after this level

    -- Channeling
    channel_time = 0,               -- Seconds to gather (0 = instant)
}
-- }}}

-- {{{ GATHERING_STATE_DEFAULTS
-- Gathering state component attached to entities that gather.
local GATHERING_STATE_DEFAULTS = {
    state = "idle",                 -- idle, gathering, interrupted
    target_node = nil,              -- Node entity being gathered from
    gather_start_time = 0,          -- When gather started
    gather_end_time = 0,            -- When gather will complete
    progress = 0,                   -- 0.0 to 1.0
}
-- }}}

-- {{{ Register components
local function register_components()
    if not (ecs.component_exists and ecs.component_exists("gatherable")) then
        ecs.register_component("gatherable", GATHERABLE_DEFAULTS)
    end
    if not (ecs.component_exists and ecs.component_exists("gathering_state")) then
        ecs.register_component("gathering_state", GATHERING_STATE_DEFAULTS)
    end
end
-- }}}

-- ============================================================================
-- Lazy Loading
-- ============================================================================

-- {{{ get_professions
-- Lazy-load professions module to avoid circular dependency.
local _professions = nil
local function get_professions()
    if not _professions then
        _professions = require("runtime.systems.professions")
    end
    return _professions
end
-- }}}

-- ============================================================================
-- Helper Functions
-- ============================================================================

-- {{{ ensure_fresh_tables
-- Ensure the component has fresh tables (not inherited from defaults).
local function ensure_fresh_tables(comp, defaults)
    if rawget(comp, "_initialized") then
        return
    end

    for key, value in pairs(defaults) do
        if type(value) == "table" then
            rawset(comp, key, {})
        else
            rawset(comp, key, value)
        end
    end
    rawset(comp, "_initialized", true)
end
-- }}}

-- {{{ get_gathering_state
-- Get or create gathering state component for an entity.
local function get_gathering_state(entity_id)
    local comp = ecs.get_component(entity_id, "gathering_state")
    if comp then
        ensure_fresh_tables(comp, GATHERING_STATE_DEFAULTS)
    end
    return comp
end
-- }}}

-- {{{ get_gatherable
-- Get gatherable component for a node.
local function get_gatherable(node_id)
    local comp = ecs.get_component(node_id, "gatherable")
    if comp then
        ensure_fresh_tables(comp, GATHERABLE_DEFAULTS)
    end
    return comp
end
-- }}}

-- ============================================================================
-- Node Management
-- ============================================================================

-- {{{ gathering.create_node
-- Create a gatherable node in the world.
-- @param position Table {x, y} or nil
-- @param node_type Predefined node type ID or nil for custom
-- @param config Optional table to override defaults
-- @return Node entity ID
function gathering.create_node(position, node_type, config)
    local node = ecs.create_entity()
    ecs.add_component(node, "gatherable")

    local comp = get_gatherable(node)
    if not comp then
        return nil
    end

    -- Apply node type template if specified
    if node_type and gathering.NODE_TYPES[node_type] then
        local template = gathering.NODE_TYPES[node_type]
        for k, v in pairs(template) do
            rawset(comp, k, v)
        end
    end

    -- Apply config overrides
    if config then
        for k, v in pairs(config) do
            rawset(comp, k, v)
        end
    end

    -- Ensure max_gathers is set
    if not rawget(comp, "max_gathers") then
        rawset(comp, "max_gathers", comp.remaining_gathers or 1)
    end

    return node
end
-- }}}

-- {{{ gathering.is_node_available
-- Check if a node can be gathered from.
-- @param node_id Node entity ID
-- @return boolean, reason if not available
function gathering.is_node_available(node_id)
    local node = get_gatherable(node_id)
    if not node then
        return false, "Not a gatherable node"
    end

    if node.depleted then
        return false, "Node depleted"
    end

    if node.remaining_gathers <= 0 then
        return false, "Node exhausted"
    end

    return true
end
-- }}}

-- {{{ gathering.deplete_node
-- Mark a node as depleted (no more gathers).
-- @param node_id Node entity ID
-- @return true if depleted, false if doesn't respawn
function gathering.deplete_node(node_id)
    local node = get_gatherable(node_id)
    if not node then
        return false
    end

    node.depleted = true
    node.remaining_gathers = 0

    -- Schedule respawn if applicable
    if node.respawn_time > 0 then
        node.respawn_at = os.time() + node.respawn_time
    end

    events.fire(gathering.EVENT.NODE_DEPLETED, {
        node = node_id,
        respawn_time = node.respawn_time,
    })

    return node.respawn_time > 0
end
-- }}}

-- {{{ gathering.respawn_node
-- Respawn a depleted node (restore gathers).
-- @param node_id Node entity ID
-- @return true if respawned
function gathering.respawn_node(node_id)
    local node = get_gatherable(node_id)
    if not node then
        return false
    end

    if not node.depleted then
        return false  -- Already active
    end

    node.depleted = false
    node.remaining_gathers = node.max_gathers
    node.respawn_at = 0

    events.fire(gathering.EVENT.NODE_RESPAWNED, {
        node = node_id,
    })

    return true
end
-- }}}

-- {{{ gathering.check_respawns
-- Check all nodes and respawn those whose time has come.
-- Call this periodically (e.g., every second).
-- @return Number of nodes respawned
function gathering.check_respawns()
    local now = os.time()
    local respawned = 0

    -- Iterate all entities with gatherable component
    -- Note: This is inefficient for large worlds - use spatial indexing
    for entity_id, comp in pairs(ecs.get_all_with_component("gatherable")) do
        if comp.depleted and comp.respawn_at > 0 and now >= comp.respawn_at then
            if gathering.respawn_node(entity_id) then
                respawned = respawned + 1
            end
        end
    end

    return respawned
end
-- }}}

-- {{{ gathering.get_node_info
-- Get information about a node.
-- @param node_id Node entity ID
-- @return Info table or nil
function gathering.get_node_info(node_id)
    local node = get_gatherable(node_id)
    if not node then
        return nil
    end

    local info = {
        resource_type = node.resource_type,
        resource_id = node.resource_id,
        profession = node.profession_required,
        skill_required = node.skill_required,
        remaining_gathers = node.remaining_gathers,
        max_gathers = node.max_gathers,
        depleted = node.depleted,
        respawns = node.respawn_time > 0,
    }

    if node.depleted and node.respawn_at > 0 then
        info.respawn_in = math.max(0, node.respawn_at - os.time())
    end

    return info
end
-- }}}

-- ============================================================================
-- Gathering Flow
-- ============================================================================

-- {{{ gathering.can_gather
-- Check if an entity can gather from a node.
-- @param entity_id Entity ID
-- @param node_id Node entity ID
-- @return boolean, error_message if false
function gathering.can_gather(entity_id, node_id)
    local professions = get_professions()

    -- Check node availability
    local available, err = gathering.is_node_available(node_id)
    if not available then
        return false, err
    end

    local node = get_gatherable(node_id)

    -- Check profession requirement
    if node.profession_required then
        if not professions.has_profession(entity_id, node.profession_required) then
            return false, "Profession not learned: " .. node.profession_required
        end

        -- Check skill level
        local skill = professions.get_skill(entity_id, node.profession_required)
        if not skill or skill < node.skill_required then
            return false, "Skill too low"
        end
    end

    -- Check tool requirement (simplified - needs inventory system)
    -- TODO: Integrate with inventory system for tool check

    return true
end
-- }}}

-- {{{ gathering.start_gather
-- Begin gathering from a node.
-- @param entity_id Entity ID
-- @param node_id Node entity ID
-- @return true on success, false and error on failure
function gathering.start_gather(entity_id, node_id)
    local state = get_gathering_state(entity_id)
    if not state then
        return false, "Entity cannot gather"
    end

    -- Already gathering?
    if state.state == gathering.STATE.GATHERING then
        return false, "Already gathering"
    end

    -- Can gather from this node?
    local can, err = gathering.can_gather(entity_id, node_id)
    if not can then
        return false, err
    end

    local node = get_gatherable(node_id)

    -- Calculate channel time
    local channel_time = node.channel_time or 0

    -- Update state
    local now = os.time()
    state.state = gathering.STATE.GATHERING
    state.target_node = node_id
    state.gather_start_time = now
    state.gather_end_time = now + channel_time
    state.progress = 0

    events.fire(gathering.EVENT.GATHER_START, {
        entity = entity_id,
        node = node_id,
        resource = node.resource_id,
        duration = channel_time,
    })

    -- If instant (channel_time = 0), complete immediately
    if channel_time <= 0 then
        return gathering.complete_gather(entity_id, node_id)
    end

    return true
end
-- }}}

-- {{{ gathering.cancel_gather
-- Cancel an ongoing gather.
-- @param entity_id Entity ID
-- @return true if cancelled, false if not gathering
function gathering.cancel_gather(entity_id)
    local state = get_gathering_state(entity_id)
    if not state then
        return false
    end

    if state.state ~= gathering.STATE.GATHERING then
        return false
    end

    local node_id = state.target_node

    -- Reset state
    state.state = gathering.STATE.IDLE
    state.target_node = nil
    state.gather_start_time = 0
    state.gather_end_time = 0
    state.progress = 0

    events.fire(gathering.EVENT.GATHER_INTERRUPTED, {
        entity = entity_id,
        node = node_id,
    })

    return true
end
-- }}}

-- {{{ gathering.complete_gather
-- Complete a gather, yielding resources.
-- @param entity_id Entity ID
-- @param node_id Node entity ID
-- @return true on success, result table with yield info
function gathering.complete_gather(entity_id, node_id)
    local professions = get_professions()

    local state = get_gathering_state(entity_id)
    if not state then
        return false, "Entity cannot gather"
    end

    local node = get_gatherable(node_id)
    if not node then
        return false, "Node not found"
    end

    -- Calculate yield (based on skill and node)
    local base_yield = math.random(node.yield_min, node.yield_max)

    -- Bonus resource roll
    local bonus_yield = nil
    if node.bonus_chance > 0 and node.bonus_resource then
        if math.random() <= node.bonus_chance then
            bonus_yield = node.bonus_resource
            events.fire(gathering.EVENT.RARE_FIND, {
                entity = entity_id,
                node = node_id,
                resource = bonus_yield,
            })
        end
    end

    -- Try skill up
    local skilled_up = false
    if node.profession_required and node.gives_skillup then
        local skill = professions.get_skill(entity_id, node.profession_required)
        if skill and skill <= node.skillup_max then
            skilled_up = professions.try_skillup(entity_id, node.profession_required, node.skill_required)
        end
    end

    -- Decrement node gathers
    node.remaining_gathers = node.remaining_gathers - 1
    if node.remaining_gathers <= 0 then
        gathering.deplete_node(node_id)
    end

    -- Build result
    local result = {
        resource = node.resource_id,
        quantity = base_yield,
        bonus = bonus_yield,
        skilled_up = skilled_up,
    }

    -- Reset state
    state.state = gathering.STATE.IDLE
    state.target_node = nil
    state.gather_start_time = 0
    state.gather_end_time = 0
    state.progress = 1.0

    events.fire(gathering.EVENT.GATHER_SUCCESS, {
        entity = entity_id,
        node = node_id,
        resource = node.resource_id,
        quantity = base_yield,
        bonus = bonus_yield,
    })

    -- Note: Actual item creation depends on inventory system (406)
    return true, result
end
-- }}}

-- {{{ gathering.update_progress
-- Update gather progress (call each frame/tick).
-- @param entity_id Entity ID
-- @return Progress 0.0-1.0, or nil if not gathering
function gathering.update_progress(entity_id)
    local state = get_gathering_state(entity_id)
    if not state or state.state ~= gathering.STATE.GATHERING then
        return nil
    end

    local now = os.time()
    local total = state.gather_end_time - state.gather_start_time
    local elapsed = now - state.gather_start_time

    if total <= 0 then
        state.progress = 1.0
    else
        state.progress = math.min(1.0, elapsed / total)
    end

    return state.progress
end
-- }}}

-- {{{ gathering.is_gather_ready
-- Check if gather has finished and can be completed.
-- @param entity_id Entity ID
-- @return boolean
function gathering.is_gather_ready(entity_id)
    local state = get_gathering_state(entity_id)
    if not state or state.state ~= gathering.STATE.GATHERING then
        return false
    end

    return os.time() >= state.gather_end_time
end
-- }}}

-- {{{ gathering.get_gather_state
-- Get current gathering state for an entity.
-- @param entity_id Entity ID
-- @return State info table or nil
function gathering.get_gather_state(entity_id)
    local state = get_gathering_state(entity_id)
    if not state then
        return nil
    end

    local info = {
        state = state.state,
        node = state.target_node,
        progress = state.progress,
    }

    if state.state == gathering.STATE.GATHERING then
        local now = os.time()
        info.time_remaining = math.max(0, state.gather_end_time - now)
        info.time_total = state.gather_end_time - state.gather_start_time
    end

    return info
end
-- }}}

-- ============================================================================
-- Profession Definitions
-- ============================================================================

-- {{{ Gathering profession definitions
gathering.PROFESSION_DEFS = {
    mining = {
        id = "mining",
        name = "Mining",
        type = "gathering",
        resource_types = {"mineral"},
        tool = "mining_pick",
        tiers = {
            {skill = 1, nodes = {"copper_vein", "tin_vein"}},
            {skill = 65, nodes = {"silver_vein", "iron_deposit"}},
            {skill = 125, nodes = {"gold_vein", "mithril_deposit"}},
            {skill = 175, nodes = {"truesilver_deposit", "small_thorium"}},
            {skill = 250, nodes = {"rich_thorium_vein"}},
        },
    },
    herbalism = {
        id = "herbalism",
        name = "Herbalism",
        type = "gathering",
        resource_types = {"plant"},
        tool = nil,
        tiers = {
            {skill = 1, nodes = {"peacebloom", "silverleaf", "earthroot"}},
            {skill = 50, nodes = {"mageroyal", "briarthorn", "swiftthistle"}},
            {skill = 100, nodes = {"wild_steelbloom", "grave_moss"}},
            {skill = 150, nodes = {"goldthorn", "khadgars_whisker"}},
            {skill = 200, nodes = {"sungrass", "arthas_tears"}},
        },
    },
    skinning = {
        id = "skinning",
        name = "Skinning",
        type = "gathering",
        resource_types = {"corpse"},
        tool = "skinning_knife",
        level_formula = function(mob_level)
            return mob_level * 5
        end,
        yields = {
            beast = {"light_leather", "medium_leather", "heavy_leather", "thick_leather"},
            dragonkin = {"dragonscale"},
            demon = {"felcloth"},
        },
    },
    lumber = {
        id = "lumber",
        name = "Lumberjacking",
        type = "gathering",
        resource_types = {"wood"},
        tool = nil,
        gather_rate = function(skill_level)
            return 10 + skill_level
        end,
    },
    fishing = {
        id = "fishing",
        name = "Fishing",
        type = "gathering",
        resource_types = {"water"},
        tool = "fishing_pole",
        pool_bonus = 3,
        catch_table = function(skill_level, zone_level)
            -- Placeholder - would return weighted loot table
            return {
                {"raw_fish", 0.7},
                {"junk", 0.2},
                {"treasure", 0.1},
            }
        end,
    },
}
-- }}}

-- {{{ gathering.get_profession_def
-- Get the definition for a gathering profession.
-- @param profession_id Profession identifier
-- @return Definition table or nil
function gathering.get_profession_def(profession_id)
    return gathering.PROFESSION_DEFS[profession_id]
end
-- }}}

-- ============================================================================
-- Node Type Templates
-- ============================================================================

-- {{{ Node type templates
-- Predefined node configurations for common resources.
gathering.NODE_TYPES = {
    -- {{{ Mining nodes
    copper_vein = {
        resource_type = "mineral",
        profession_required = "mining",
        skill_required = 1,
        resource_id = "copper_ore",
        yield_min = 1,
        yield_max = 3,
        bonus_chance = 0.05,
        bonus_resource = "rough_stone",
        remaining_gathers = 3,
        respawn_time = 300,
        channel_time = 3,
        skillup_max = 50,
    },
    iron_deposit = {
        resource_type = "mineral",
        profession_required = "mining",
        skill_required = 65,
        resource_id = "iron_ore",
        yield_min = 1,
        yield_max = 4,
        bonus_chance = 0.1,
        bonus_resource = "heavy_stone",
        remaining_gathers = 3,
        respawn_time = 300,
        channel_time = 3,
        skillup_max = 150,
    },
    mithril_deposit = {
        resource_type = "mineral",
        profession_required = "mining",
        skill_required = 125,
        resource_id = "mithril_ore",
        yield_min = 2,
        yield_max = 4,
        bonus_chance = 0.15,
        bonus_resource = "solid_stone",
        remaining_gathers = 4,
        respawn_time = 600,
        channel_time = 3,
        skillup_max = 225,
    },
    -- }}}

    -- {{{ Herbalism nodes
    peacebloom = {
        resource_type = "plant",
        profession_required = "herbalism",
        skill_required = 1,
        resource_id = "peacebloom",
        yield_min = 1,
        yield_max = 2,
        remaining_gathers = 1,
        respawn_time = 300,
        channel_time = 2,
        skillup_max = 50,
    },
    mageroyal = {
        resource_type = "plant",
        profession_required = "herbalism",
        skill_required = 50,
        resource_id = "mageroyal",
        yield_min = 1,
        yield_max = 3,
        remaining_gathers = 1,
        respawn_time = 300,
        channel_time = 2,
        skillup_max = 100,
    },
    -- }}}

    -- {{{ Skinning corpses
    wolf_corpse = {
        resource_type = "corpse",
        profession_required = "skinning",
        skill_required = 5,
        resource_id = "light_leather",
        yield_min = 1,
        yield_max = 1,
        remaining_gathers = 1,
        respawn_time = 0,  -- Corpses don't respawn
        channel_time = 2,
        tool_required = "skinning_knife",
    },
    -- }}}

    -- {{{ WC3 resources
    gold_mine = {
        resource_type = "mineral",
        profession_required = nil,  -- Any worker
        skill_required = 0,
        resource_id = "gold",
        yield_min = 10,
        yield_max = 10,
        remaining_gathers = 999999,  -- Effectively infinite
        respawn_time = 0,
        channel_time = 0,  -- Instant
    },
    tree = {
        resource_type = "wood",
        profession_required = nil,
        skill_required = 0,
        resource_id = "lumber",
        yield_min = 10,
        yield_max = 10,
        remaining_gathers = 1,
        respawn_time = 0,  -- Trees don't respawn
        channel_time = 0,
    },
    -- }}}
}
-- }}}

-- ============================================================================
-- Query Functions
-- ============================================================================

-- {{{ gathering.find_nearest_node
-- Find the nearest gatherable node of a type within range.
-- @param entity_id Entity ID
-- @param profession Profession ID to filter by
-- @param max_range Maximum distance
-- @return Node entity ID or nil
function gathering.find_nearest_node(entity_id, profession, max_range)
    -- Note: This requires position/spatial system
    -- Placeholder implementation returns nil
    -- TODO: Integrate with spatial query system
    return nil
end
-- }}}

-- {{{ gathering.get_nodes_in_range
-- Get all gatherable nodes within range.
-- @param position {x, y} position
-- @param radius Search radius
-- @param profession Optional profession filter
-- @return Array of node entity IDs
function gathering.get_nodes_in_range(position, radius, profession)
    -- Note: This requires spatial system
    -- Placeholder implementation returns empty array
    -- TODO: Integrate with spatial query system
    return {}
end
-- }}}

-- ============================================================================
-- Initialization
-- ============================================================================

-- {{{ gathering.init
-- Initialize the gathering system.
function gathering.init()
    register_components()
end
-- }}}

-- {{{ gathering.reset
-- Reset gathering system state (for testing).
function gathering.reset()
    -- Nothing to reset currently
end
-- }}}

return gathering
