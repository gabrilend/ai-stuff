--[[
Death System (Issues 701a, 701b, 701c, 701d, 701e)

Provides death state management, corpse system, ghost system, resurrection
mechanics, and death events. This is the complete death/resurrection system.

Usage:
    local death = require("runtime.systems.death")

    -- Kill a unit
    death.kill(entity, killer, "damage")

    -- Check if dead
    if death.is_dead(entity) then
        local elapsed = death.time_since_death(entity)
    end

    -- Create corpse for dead unit
    local corpse = death.create_corpse(dead_entity)

    -- Create ghost for dead hero
    local ghost = death.create_ghost(dead_hero, corpse)

    -- Begin altar revival
    death.begin_altar_revival(altar, ghost)

    -- Query corpses
    local corpses = death.find_corpses_in_range(x, y, 500)

The death system:
- Registers the "dead" component
- Registers the "corpse" component (701e)
- Registers the "ghost" component (701c)
- Registers the "reviving" component (701d)
- Provides kill() API to mark entities as dead
- Provides corpse creation and decay system (701e)
- Provides ghost creation for heroes (701c)
- Provides altar revival with timer (701d)
- Fires EVENT_UNIT_DEATH and EVENT_HERO_DEATH events
- Fires EVENT_HERO_REVIVE_START and EVENT_HERO_REVIVED events (701d)
- Registers systems for death check, corpse decay, and revival
- Provides query functions for dead state, corpses, ghosts, and revival
]]

-- {{{ Configuration
local DIR = arg and arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path
-- }}}

local ecs = require("runtime.ecs")
local events = require("runtime.events")

local death = {}

-- ============================================================================
-- Constants
-- ============================================================================

-- {{{ Death cause constants
-- Why did the entity die? Affects event handling and cleanup.
death.CAUSE = {
    DAMAGE = "damage",     -- Normal combat damage
    SPELL = "spell",       -- Spell effect (Death Coil, etc.)
    TRIGGER = "trigger",   -- Map trigger killed unit
    REMOVE = "remove",     -- Removed from game (no events)
    DECAY = "decay",       -- Corpse decayed (cleanup)
    SUICIDE = "suicide",   -- Self-inflicted (Goblin Sappers)
}
-- }}}

-- {{{ Layer constants (for 701b integration)
-- Which world layer an entity exists on.
death.LAYER = {
    MORTAL = "mortal",
    SPIRIT = "spirit",
}
-- }}}

-- {{{ Decay time constants (701e)
-- How long corpses last before decaying completely.
-- Values in seconds, matching WC3 behavior.
death.DECAY_TIME = {
    HERO = 88,           -- Hero corpses last longest (for revival window)
    NORMAL = 60,         -- Standard units
    SUMMONED = 0,        -- Summoned units don't leave corpses
    MECHANICAL = 0,      -- Mechanical units don't leave corpses
    BUILDING = 0,        -- Buildings don't leave corpses
}

-- Fraction of decay time at which flesh becomes skeleton
death.SKELETON_THRESHOLD = 0.5
-- }}}

-- ============================================================================
-- Component Registration
-- ============================================================================

-- {{{ Register dead component
-- Tracks death state and metadata.
-- Added to entities when they die, removed when they revive.
local dead_registered = false
local function ensure_dead_component()
    if dead_registered then return end

    -- Check if already registered by another module
    if ecs.get_component_defaults("dead") then
        dead_registered = true
        return
    end

    ecs.register_component("dead", {
        death_time = 0,      -- Game time when died (from gameloop)
        killer = nil,        -- Entity ID that dealt killing blow
        cause = "damage",    -- Death cause from CAUSE constants
    })
    dead_registered = true
end
-- }}}

-- {{{ Register world_layer component (for 701b)
-- Tracks which layer an entity exists on.
-- Default is mortal; ghosts are in spirit layer.
local layer_registered = false
local function ensure_layer_component()
    if layer_registered then return end

    if ecs.get_component_defaults("world_layer") then
        layer_registered = true
        return
    end

    ecs.register_component("world_layer", {
        layer = "mortal",  -- "mortal" or "spirit"
    })
    layer_registered = true
end
-- }}}

-- {{{ Register corpse component (701e)
-- Tracks corpse state for decay and necromancy targeting.
local corpse_registered = false
local function ensure_corpse_component()
    if corpse_registered then return end

    if ecs.get_component_defaults("corpse") then
        corpse_registered = true
        return
    end

    ecs.register_component("corpse", {
        -- Decay timing
        decay_timer = 88.0,       -- Seconds remaining until decay complete
        decay_max = 88.0,         -- Original decay time (for progress bar)

        -- Targeting flags
        raiseable = true,         -- Can be targeted by Raise Dead
        cannibalizable = true,    -- Can be targeted by Cannibalize

        -- State
        flesh_remaining = true,   -- true = fresh corpse, false = skeleton
        raised = false,           -- Has been raised (prevents re-raise)

        -- Reference to original unit
        unit_type_id = nil,       -- Original unit's type ID (e.g., "hfoo")
        original_owner = nil,     -- Player ID who owned the unit
        original_entity = nil,    -- Entity ID of the dead unit (if still exists)

        -- Link for heroes (701c integration)
        linked_ghost = nil,       -- Ghost entity in spirit world
    })
    corpse_registered = true
end
-- }}}

-- {{{ Register ghost component (701c)
-- Tracks ghost state for hero revival.
local ghost_registered = false
local function ensure_ghost_component()
    if ghost_registered then return end

    if ecs.get_component_defaults("ghost") then
        ghost_registered = true
        return
    end

    ecs.register_component("ghost", {
        -- Links
        linked_corpse = nil,      -- Entity ID of corpse in mortal realm
        original_entity = nil,    -- Original unit's entity ID (for reference)
        original_data = {},       -- Preserved unit state for revival

        -- Ownership
        owner_player = nil,       -- Player ID who owns this ghost

        -- Movement (overrides)
        movement_speed = 400,     -- Ghosts move 50% faster than base

        -- Visibility
        visible_to_owner = true,  -- Owner can always see their ghost
        visible_to_allies = false, -- Allies cannot see by default
        visible_to_enemies = false, -- Enemies cannot see by default

        -- State
        at_altar = false,         -- Ghost has reached an altar
        revival_started = false,  -- Revival is in progress
    })
    ghost_registered = true
end
-- }}}

-- {{{ Register reviving component (701d)
-- Tracks altar revival state, attached to ghost during revival.
local reviving_registered = false
local function ensure_reviving_component()
    if reviving_registered then return end

    if ecs.get_component_defaults("reviving") then
        reviving_registered = true
        return
    end

    ecs.register_component("reviving", {
        altar = nil,              -- Entity ID of altar handling revival
        time_remaining = 0,       -- Seconds until revival completes
        time_total = 0,           -- Total revival time (for progress bar)
        gold_cost = 0,            -- Gold locked for this revival
        hero_level = 1,           -- Hero level at death (for formula)
    })
    reviving_registered = true
end
-- }}}

-- Initialize components on module load
ensure_dead_component()
ensure_layer_component()
ensure_corpse_component()
ensure_ghost_component()
ensure_reviving_component()

-- ============================================================================
-- Event Type Extensions
-- ============================================================================

-- {{{ Add HERO_DEATH event if not present
-- EVENT_UNIT_DEATH = 20 already exists in events.lua
-- We add EVENT_HERO_DEATH for hero-specific triggers
if not events.EVENT.HERO_DEATH then
    events.EVENT.HERO_DEATH = 21
end

-- Add revival events (for 701d)
if not events.EVENT.HERO_REVIVE_START then
    events.EVENT.HERO_REVIVE_START = 22
end
if not events.EVENT.HERO_REVIVED then
    events.EVENT.HERO_REVIVED = 23
end
if not events.EVENT.UNIT_RESURRECTED then
    events.EVENT.UNIT_RESURRECTED = 24
end

-- Add decay event (for 701e)
if not events.EVENT.UNIT_DECAY then
    events.EVENT.UNIT_DECAY = 25
end
if not events.EVENT.CORPSE_RAISED then
    events.EVENT.CORPSE_RAISED = 26
end
-- }}}

-- ============================================================================
-- Query Functions
-- ============================================================================

-- {{{ death.is_dead
-- Check if an entity is dead (has dead component).
-- @param entity Entity ID to check
-- @return boolean true if entity is dead
function death.is_dead(entity)
    return ecs.has_component(entity, "dead")
end
-- }}}

-- {{{ death.is_alive
-- Check if an entity is alive (has stats, not dead).
-- @param entity Entity ID to check
-- @return boolean true if entity is alive
function death.is_alive(entity)
    if not ecs.entity_exists(entity) then
        return false
    end
    if death.is_dead(entity) then
        return false
    end
    -- Must have stats to be considered "alive"
    return ecs.has_component(entity, "stats")
end
-- }}}

-- {{{ death.time_since_death
-- Get time elapsed since entity died.
-- @param entity Entity ID to check
-- @return number seconds since death, or nil if not dead
function death.time_since_death(entity)
    local dead_comp = ecs.get_component(entity, "dead")
    if not dead_comp then
        return nil
    end

    -- Try to get current game time from gameloop
    local ok, gameloop = pcall(require, "runtime.gameloop")
    if ok and gameloop and gameloop.get_time then
        local current_time = gameloop.get_time()
        return current_time - dead_comp.death_time
    end

    -- Fallback: return death_time as elapsed (assumes time 0 start)
    return dead_comp.death_time
end
-- }}}

-- {{{ death.get_killer
-- Get the entity that killed this one.
-- @param entity Entity ID to check
-- @return entity ID of killer, or nil if not dead or no killer
function death.get_killer(entity)
    local dead_comp = ecs.get_component(entity, "dead")
    if not dead_comp then
        return nil
    end
    return dead_comp.killer
end
-- }}}

-- {{{ death.get_cause
-- Get the cause of death.
-- @param entity Entity ID to check
-- @return string death cause, or nil if not dead
function death.get_cause(entity)
    local dead_comp = ecs.get_component(entity, "dead")
    if not dead_comp then
        return nil
    end
    return dead_comp.cause
end
-- }}}

-- {{{ death.get_death_time
-- Get the game time when entity died.
-- @param entity Entity ID to check
-- @return number game time of death, or nil if not dead
function death.get_death_time(entity)
    local dead_comp = ecs.get_component(entity, "dead")
    if not dead_comp then
        return nil
    end
    return dead_comp.death_time
end
-- }}}

-- ============================================================================
-- Layer Functions (for 701b integration)
-- ============================================================================

-- {{{ death.get_layer
-- Get the world layer an entity is on.
-- @param entity Entity ID
-- @return string layer name ("mortal" or "spirit")
function death.get_layer(entity)
    local layer_comp = ecs.get_component(entity, "world_layer")
    if layer_comp then
        return layer_comp.layer
    end
    -- Default to mortal layer
    return death.LAYER.MORTAL
end
-- }}}

-- {{{ death.is_in_spirit_world
-- Check if entity is in the spirit world.
-- @param entity Entity ID
-- @return boolean true if in spirit world
function death.is_in_spirit_world(entity)
    return death.get_layer(entity) == death.LAYER.SPIRIT
end
-- }}}

-- {{{ death.is_in_mortal_world
-- Check if entity is in the mortal world.
-- @param entity Entity ID
-- @return boolean true if in mortal world
function death.is_in_mortal_world(entity)
    return death.get_layer(entity) == death.LAYER.MORTAL
end
-- }}}

-- {{{ death.send_to_spirit_world
-- Transition entity to spirit world layer.
-- @param entity Entity ID
-- @return boolean true if transition succeeded
function death.send_to_spirit_world(entity)
    if not ecs.entity_exists(entity) then
        return false
    end

    -- Add or update world_layer component
    local layer_comp = ecs.get_component(entity, "world_layer")
    if layer_comp then
        layer_comp.layer = death.LAYER.SPIRIT
    else
        ecs.add_component(entity, "world_layer", {
            layer = death.LAYER.SPIRIT,
        })
    end

    return true
end
-- }}}

-- {{{ death.return_to_mortal_world
-- Transition entity back to mortal world.
-- @param entity Entity ID
-- @return boolean true if transition succeeded
function death.return_to_mortal_world(entity)
    if not ecs.entity_exists(entity) then
        return false
    end

    local layer_comp = ecs.get_component(entity, "world_layer")
    if layer_comp then
        layer_comp.layer = death.LAYER.MORTAL
    else
        ecs.add_component(entity, "world_layer", {
            layer = death.LAYER.MORTAL,
        })
    end

    return true
end
-- }}}

-- ============================================================================
-- Action Functions
-- ============================================================================

-- {{{ death.kill
-- Mark an entity as dead and fire death events.
-- @param entity Entity ID to kill
-- @param killer Entity ID that killed this one (optional)
-- @param cause Death cause from CAUSE constants (default: "damage")
-- @return boolean true if entity was killed, false if already dead or invalid
function death.kill(entity, killer, cause)
    -- Validate entity
    if not ecs.entity_exists(entity) then
        return false
    end

    -- Already dead?
    if death.is_dead(entity) then
        return false
    end

    -- Must have stats to die (doodads don't die, they're destroyed)
    if not ecs.has_component(entity, "stats") then
        return false
    end

    -- Get current game time
    local death_time = 0
    local ok, gameloop = pcall(require, "runtime.gameloop")
    if ok and gameloop and gameloop.get_time then
        death_time = gameloop.get_time()
    end

    -- Add dead component
    ecs.add_component(entity, "dead", {
        death_time = death_time,
        killer = killer,
        cause = cause or death.CAUSE.DAMAGE,
    })

    -- Don't fire events for "remove" cause (silent removal)
    if cause == death.CAUSE.REMOVE then
        return true
    end

    -- Get position for event context
    local pos = ecs.get_component(entity, "position")
    local death_x = pos and pos.x or 0
    local death_y = pos and pos.y or 0

    -- Build event context
    local event_ctx = {
        unit = entity,
        triggering_unit = entity,
        dying_unit = entity,
        killing_unit = killer,
        killer = killer,
        cause = cause or death.CAUSE.DAMAGE,
        death_x = death_x,
        death_y = death_y,
    }

    -- Fire UNIT_DEATH event (exists in events.lua)
    events.fire(events.EVENT.UNIT_DEATH, event_ctx)

    -- Check if this is a hero and fire HERO_DEATH additionally
    local unit_type = ecs.get_component(entity, "unit_type")
    if unit_type and unit_type.is_hero then
        events.fire(events.EVENT.HERO_DEATH, event_ctx)
    end

    -- Also check for hero component (alternative way to identify heroes)
    if ecs.has_component(entity, "hero") then
        -- Only fire if we haven't already (avoid duplicate event)
        if not (unit_type and unit_type.is_hero) then
            events.fire(events.EVENT.HERO_DEATH, event_ctx)
        end
    end

    return true
end
-- }}}

-- {{{ death.remove
-- Remove an entity without firing death events.
-- Used for cleanup, summon expiration, etc.
-- @param entity Entity ID to remove
-- @return boolean true if entity was removed
function death.remove(entity)
    if not ecs.entity_exists(entity) then
        return false
    end

    -- Mark as dead with "remove" cause (no events)
    death.kill(entity, nil, death.CAUSE.REMOVE)

    -- Actually destroy the entity
    ecs.destroy_entity(entity)

    return true
end
-- }}}

-- {{{ death.revive
-- Revive a dead entity at a position.
-- Removes dead component and restores to living state.
-- @param entity Entity ID to revive
-- @param x X position for revival (optional, uses current position)
-- @param y Y position for revival (optional, uses current position)
-- @param hp_percent HP to restore as fraction (0.0-1.0, default 1.0)
-- @return boolean true if entity was revived
function death.revive(entity, x, y, hp_percent)
    if not ecs.entity_exists(entity) then
        return false
    end

    -- Must be dead to revive
    if not death.is_dead(entity) then
        return false
    end

    -- Remove dead component
    ecs.remove_component(entity, "dead")

    -- Restore to mortal world
    death.return_to_mortal_world(entity)

    -- Update position if provided
    local pos = ecs.get_component(entity, "position")
    if pos then
        if x then pos.x = x end
        if y then pos.y = y end
    end

    -- Restore HP
    local stats = ecs.get_component(entity, "stats")
    if stats then
        hp_percent = hp_percent or 1.0
        hp_percent = math.max(0.01, math.min(1.0, hp_percent))  -- Clamp to valid range
        stats.hp = stats.hp_max * hp_percent
    end

    -- Fire resurrection event
    local revive_x = pos and pos.x or (x or 0)
    local revive_y = pos and pos.y or (y or 0)

    events.fire(events.EVENT.UNIT_RESURRECTED, {
        unit = entity,
        triggering_unit = entity,
        resurrected_unit = entity,
        revive_x = revive_x,
        revive_y = revive_y,
        hp_percent = hp_percent,
    })

    return true
end
-- }}}

-- ============================================================================
-- Death Check System
-- ============================================================================

-- {{{ Auto-death system
-- Runs each tick to check for entities with hp <= 0 and kill them.
-- Priority is low (runs after damage systems).
local function death_check_system(iter, dt)
    for entity, stats in iter do
        -- Skip if already dead
        if not ecs.has_component(entity, "dead") then
            -- Check if HP is at or below zero
            if stats.hp <= 0 then
                -- Kill with no specific killer (damage source should be tracked elsewhere)
                -- Note: Combat system should call death.kill() directly with killer info
                -- This is a fallback for cases where HP was reduced without combat tracking
                death.kill(entity, nil, death.CAUSE.DAMAGE)
            end
        end
    end
end

-- Register death check system
-- Priority 50 = runs after combat/damage systems but before cleanup
ecs.register_system(
    "death_check",
    {"stats"},
    death_check_system,
    {priority = 50}
)
-- }}}

-- ============================================================================
-- Utility Functions
-- ============================================================================

-- {{{ death.query_living
-- Query entities that are alive (have stats, not dead).
-- @param additional_components Additional components to require
-- @return iterator function
function death.query_living(additional_components)
    additional_components = additional_components or {}

    -- Always require stats for "living" entities
    local components = {"stats"}
    for _, comp in ipairs(additional_components) do
        components[#components + 1] = comp
    end

    -- Return filtered iterator
    return function()
        local results = {}
        for entity in ecs.query(unpack(components)) do
            if not death.is_dead(entity) then
                results[#results + 1] = entity
            end
        end
        return ipairs(results)
    end
end
-- }}}

-- {{{ death.count_living
-- Count living entities with specified components.
-- @param additional_components Additional components to require
-- @return number count of living entities
function death.count_living(additional_components)
    local count = 0
    for _ in death.query_living(additional_components)() do
        count = count + 1
    end
    return count
end
-- }}}

-- {{{ death.count_dead
-- Count dead entities.
-- @return number count of dead entities
function death.count_dead()
    local storage = ecs.get_component_storage("dead")
    if not storage then
        return 0
    end

    local count = 0
    for _ in pairs(storage) do
        count = count + 1
    end
    return count
end
-- }}}

-- ============================================================================
-- Corpse System (Issue 701e)
-- ============================================================================

-- {{{ Corpse-to-unit tracking
-- Maps corpse entities to their original unit entities (for hero revival)
local corpse_to_unit = {}
local unit_to_corpse = {}

-- {{{ death.reset_tracking
-- Clears internal tracking tables. Called automatically on ECS reset.
-- Should be called in tests between test cases.
function death.reset_tracking()
    corpse_to_unit = {}
    unit_to_corpse = {}
end
-- }}}
-- }}}

-- {{{ death.should_create_corpse
-- Determine if a unit should leave a corpse when it dies.
-- @param entity Entity ID of the dead unit
-- @return boolean true if corpse should be created
function death.should_create_corpse(entity)
    -- Must be a valid entity
    if not ecs.entity_exists(entity) then
        return false
    end

    -- Check unit_type for special cases
    local unit_type = ecs.get_component(entity, "unit_type")
    if unit_type then
        -- No corpse for summoned units
        if unit_type.is_summoned then
            return false
        end

        -- No corpse for buildings
        if unit_type.is_building then
            return false
        end
    end

    -- Default: create corpse for units with stats
    return ecs.has_component(entity, "stats")
end
-- }}}

-- {{{ death.get_decay_time
-- Get the decay time for a unit based on its type.
-- @param entity Entity ID of the dead unit
-- @return number decay time in seconds
function death.get_decay_time(entity)
    local unit_type = ecs.get_component(entity, "unit_type")

    if unit_type then
        -- Heroes get longest decay time
        if unit_type.is_hero then
            return death.DECAY_TIME.HERO
        end

        -- Summoned units get no decay (no corpse)
        if unit_type.is_summoned then
            return death.DECAY_TIME.SUMMONED
        end

        -- Buildings get no decay (no corpse)
        if unit_type.is_building then
            return death.DECAY_TIME.BUILDING
        end
    end

    -- Check for hero component as alternative hero detection
    if ecs.has_component(entity, "hero") then
        return death.DECAY_TIME.HERO
    end

    -- Default: normal unit decay time
    return death.DECAY_TIME.NORMAL
end
-- }}}

-- {{{ death.create_corpse
-- Create a corpse entity for a dead unit.
-- @param dead_entity Entity ID of the dead unit
-- @return corpse entity ID, or nil if corpse shouldn't be created
function death.create_corpse(dead_entity)
    -- Validate: entity must exist and be dead
    if not ecs.entity_exists(dead_entity) then
        return nil
    end

    if not death.is_dead(dead_entity) then
        return nil
    end

    -- Check if corpse should be created
    if not death.should_create_corpse(dead_entity) then
        return nil
    end

    -- Check if corpse already exists for this unit
    if unit_to_corpse[dead_entity] then
        return unit_to_corpse[dead_entity]
    end

    -- Get death position
    local pos = ecs.get_component(dead_entity, "position")
    local corpse_x = pos and pos.x or 0
    local corpse_y = pos and pos.y or 0
    local corpse_facing = pos and pos.facing or 0

    -- Get unit info
    local unit_type = ecs.get_component(dead_entity, "unit_type")
    local owner = ecs.get_component(dead_entity, "owner")

    -- Get decay time
    local decay_time = death.get_decay_time(dead_entity)

    -- Create corpse entity
    local corpse = ecs.create_entity()

    -- Add position component (corpse is in mortal world)
    ecs.add_component(corpse, "position", {
        x = corpse_x,
        y = corpse_y,
        z = 0,
        facing = corpse_facing,
    })

    -- Add corpse component
    ecs.add_component(corpse, "corpse", {
        decay_timer = decay_time,
        decay_max = decay_time,
        raiseable = true,
        cannibalizable = true,
        flesh_remaining = true,
        raised = false,
        unit_type_id = unit_type and unit_type.type_id or nil,
        original_owner = owner and owner.player_id or nil,
        original_entity = dead_entity,
        linked_ghost = nil,
    })

    -- Add selectable component (corpses can be targeted)
    ecs.add_component(corpse, "selectable", {
        selected = false,
        selection_scale = 0.75,  -- Smaller selection circle for corpses
        selection_priority = -1,  -- Lower priority than living units
        show_healthbar = false,
        show_manabar = false,
        can_select = true,
    })

    -- Track the relationship
    corpse_to_unit[corpse] = dead_entity
    unit_to_corpse[dead_entity] = corpse

    return corpse
end
-- }}}

-- {{{ death.create_corpse_at
-- Create a corpse at a specific position (for spawned corpses, Meat Wagon, etc.)
-- @param x X position
-- @param y Y position
-- @param unit_type_id Type ID of the unit this corpse represents (optional)
-- @param decay_time Custom decay time (optional, defaults to NORMAL)
-- @return corpse entity ID
function death.create_corpse_at(x, y, unit_type_id, decay_time)
    local corpse = ecs.create_entity()

    local actual_decay = decay_time or death.DECAY_TIME.NORMAL

    -- Add position component
    ecs.add_component(corpse, "position", {
        x = x or 0,
        y = y or 0,
        z = 0,
        facing = 0,
    })

    -- Add corpse component
    ecs.add_component(corpse, "corpse", {
        decay_timer = actual_decay,
        decay_max = actual_decay,
        raiseable = true,
        cannibalizable = true,
        flesh_remaining = true,
        raised = false,
        unit_type_id = unit_type_id,
        original_owner = nil,
        original_entity = nil,
        linked_ghost = nil,
    })

    -- Add selectable component
    ecs.add_component(corpse, "selectable", {
        selected = false,
        selection_scale = 0.75,
        selection_priority = -1,
        show_healthbar = false,
        show_manabar = false,
        can_select = true,
    })

    return corpse
end
-- }}}

-- {{{ death.get_corpse
-- Get the corpse entity for a dead unit.
-- @param dead_entity Entity ID of the dead unit
-- @return corpse entity ID, or nil if no corpse exists
function death.get_corpse(dead_entity)
    return unit_to_corpse[dead_entity]
end
-- }}}

-- {{{ death.get_corpse_unit
-- Get the original unit entity for a corpse.
-- @param corpse Entity ID of the corpse
-- @return unit entity ID, or nil if unknown
function death.get_corpse_unit(corpse)
    return corpse_to_unit[corpse]
end
-- }}}

-- {{{ death.is_corpse
-- Check if an entity is a corpse.
-- @param entity Entity ID
-- @return boolean true if entity has corpse component
function death.is_corpse(entity)
    return ecs.has_component(entity, "corpse")
end
-- }}}

-- {{{ death.is_raiseable
-- Check if a corpse can be raised by necromancy spells.
-- @param corpse Entity ID of the corpse
-- @return boolean true if corpse can be raised
function death.is_raiseable(corpse)
    local corpse_comp = ecs.get_component(corpse, "corpse")
    if not corpse_comp then
        return false
    end

    -- Already raised
    if corpse_comp.raised then
        return false
    end

    -- Check raiseable flag
    return corpse_comp.raiseable
end
-- }}}

-- {{{ death.is_fresh
-- Check if corpse still has flesh (not skeleton).
-- @param corpse Entity ID of the corpse
-- @return boolean true if flesh_remaining is true
function death.is_fresh(corpse)
    local corpse_comp = ecs.get_component(corpse, "corpse")
    if not corpse_comp then
        return false
    end

    return corpse_comp.flesh_remaining
end
-- }}}

-- {{{ death.get_decay_remaining
-- Get seconds remaining until corpse decays completely.
-- @param corpse Entity ID of the corpse
-- @return number seconds remaining, or nil if not a corpse
function death.get_decay_remaining(corpse)
    local corpse_comp = ecs.get_component(corpse, "corpse")
    if not corpse_comp then
        return nil
    end

    return corpse_comp.decay_timer
end
-- }}}

-- {{{ death.get_decay_progress
-- Get decay progress as fraction (0.0 = fresh, 1.0 = about to decay).
-- @param corpse Entity ID of the corpse
-- @return number 0.0-1.0 progress, or nil if not a corpse
function death.get_decay_progress(corpse)
    local corpse_comp = ecs.get_component(corpse, "corpse")
    if not corpse_comp then
        return nil
    end

    if corpse_comp.decay_max <= 0 then
        return 1.0
    end

    local elapsed = corpse_comp.decay_max - corpse_comp.decay_timer
    return math.min(1.0, math.max(0.0, elapsed / corpse_comp.decay_max))
end
-- }}}

-- {{{ death.raise_corpse
-- Mark a corpse as raised (prevents re-raising).
-- @param corpse Entity ID of the corpse
-- @param raiser Entity ID that raised the corpse (optional)
-- @return boolean true if corpse was successfully marked
function death.raise_corpse(corpse, raiser)
    local corpse_comp = ecs.get_component(corpse, "corpse")
    if not corpse_comp then
        return false
    end

    -- Already raised
    if corpse_comp.raised then
        return false
    end

    -- Mark as raised
    corpse_comp.raised = true

    -- Get position for event
    local pos = ecs.get_component(corpse, "position")
    local x = pos and pos.x or 0
    local y = pos and pos.y or 0

    -- Fire event
    events.fire(events.EVENT.CORPSE_RAISED, {
        event_id = events.EVENT.CORPSE_RAISED,
        corpse = corpse,
        raiser = raiser,
        unit_type = corpse_comp.unit_type_id,
        x = x,
        y = y,
    })

    return true
end
-- }}}

-- {{{ death.consume_corpse
-- Consume a corpse (for Cannibalize, etc.) and remove it.
-- @param corpse Entity ID of the corpse
-- @return boolean true if corpse was consumed
function death.consume_corpse(corpse)
    if not death.is_corpse(corpse) then
        return false
    end

    -- Clean up tracking
    local unit = corpse_to_unit[corpse]
    if unit then
        unit_to_corpse[unit] = nil
    end
    corpse_to_unit[corpse] = nil

    -- Destroy the corpse entity
    ecs.destroy_entity(corpse)

    return true
end
-- }}}

-- {{{ death.destroy_corpse
-- Remove a corpse without events (cleanup).
-- @param corpse Entity ID of the corpse
-- @return boolean true if corpse was destroyed
function death.destroy_corpse(corpse)
    return death.consume_corpse(corpse)
end
-- }}}

-- {{{ death.find_corpses_in_range
-- Find all corpses within a radius of a point.
-- @param x Center X coordinate
-- @param y Center Y coordinate
-- @param radius Search radius
-- @param filter Optional function(corpse) to filter results
-- @return array of corpse entity IDs
function death.find_corpses_in_range(x, y, radius, filter)
    local results = {}
    local radius_sq = radius * radius

    local storage = ecs.get_component_storage("corpse")
    if not storage then
        return results
    end

    for entity in pairs(storage) do
        local pos = ecs.get_component(entity, "position")
        if pos then
            local dx = pos.x - x
            local dy = pos.y - y
            local dist_sq = dx * dx + dy * dy

            if dist_sq <= radius_sq then
                -- Apply optional filter
                if not filter or filter(entity) then
                    results[#results + 1] = entity
                end
            end
        end
    end

    return results
end
-- }}}

-- {{{ death.count_corpses
-- Count all corpse entities.
-- @return number count of corpses
function death.count_corpses()
    local storage = ecs.get_component_storage("corpse")
    if not storage then
        return 0
    end

    local count = 0
    for _ in pairs(storage) do
        count = count + 1
    end
    return count
end
-- }}}

-- {{{ death.link_corpse_to_ghost
-- Link a corpse to a ghost entity (for hero revival).
-- @param corpse Entity ID of the corpse
-- @param ghost Entity ID of the ghost
-- @return boolean true if link was created
function death.link_corpse_to_ghost(corpse, ghost)
    local corpse_comp = ecs.get_component(corpse, "corpse")
    if not corpse_comp then
        return false
    end

    corpse_comp.linked_ghost = ghost
    return true
end
-- }}}

-- ============================================================================
-- Corpse Decay System (701e)
-- ============================================================================

-- {{{ Corpse decay system
-- Runs each tick to update corpse decay timers.
-- When decay completes, fires EVENT_UNIT_DECAY and removes corpse.
local function corpse_decay_system(iter, dt)
    local to_remove = {}

    for entity, corpse_comp in iter do
        -- Decrement decay timer
        corpse_comp.decay_timer = corpse_comp.decay_timer - dt

        -- Check for flesh-to-skeleton transition
        if corpse_comp.flesh_remaining then
            local progress = death.get_decay_progress(entity)
            if progress and progress >= death.SKELETON_THRESHOLD then
                corpse_comp.flesh_remaining = false
            end
        end

        -- Check for decay complete
        if corpse_comp.decay_timer <= 0 then
            -- Get position for event
            local pos = ecs.get_component(entity, "position")
            local x = pos and pos.x or 0
            local y = pos and pos.y or 0

            -- Fire decay event
            events.fire(events.EVENT.UNIT_DECAY, {
                event_id = events.EVENT.UNIT_DECAY,
                corpse = entity,
                unit_type = corpse_comp.unit_type_id,
                x = x,
                y = y,
            })

            -- Mark for removal (can't modify during iteration)
            to_remove[#to_remove + 1] = entity
        end
    end

    -- Remove decayed corpses
    for _, entity in ipairs(to_remove) do
        -- Clean up tracking
        local unit = corpse_to_unit[entity]
        if unit then
            unit_to_corpse[unit] = nil
        end
        corpse_to_unit[entity] = nil

        -- Destroy the entity
        ecs.destroy_entity(entity)
    end
end

-- Register corpse decay system
-- Priority 60 = runs after death system, before rendering
ecs.register_system(
    "corpse_decay",
    {"corpse"},
    corpse_decay_system,
    {priority = 60}
)
-- }}}

-- ============================================================================
-- Ghost System (Issue 701c)
-- ============================================================================

-- {{{ Ghost-to-unit tracking
-- Maps ghost entities to their original unit entities
local ghost_to_unit = {}
local unit_to_ghost = {}

-- Extend reset_tracking to clear ghost tables
local original_reset = death.reset_tracking
function death.reset_tracking()
    original_reset()
    ghost_to_unit = {}
    unit_to_ghost = {}
end
-- }}}

-- {{{ death.preserve_hero_data
-- Capture hero state for revival.
-- @param entity Entity ID of the hero
-- @return table preserved data structure
function death.preserve_hero_data(entity)
    local data = {}

    -- Get position
    local pos = ecs.get_component(entity, "position")
    if pos then
        data.death_x = pos.x
        data.death_y = pos.y
        data.death_facing = pos.facing
    end

    -- Get unit type
    local unit_type = ecs.get_component(entity, "unit_type")
    if unit_type then
        data.type_id = unit_type.type_id
        data.is_hero = unit_type.is_hero
    end

    -- Get owner
    local owner = ecs.get_component(entity, "owner")
    if owner then
        data.owner_player = owner.player_id
    end

    -- Get hero data
    local hero = ecs.get_component(entity, "hero")
    if hero then
        data.level = hero.level
        data.experience = hero.experience
        data.strength = hero.strength
        data.agility = hero.agility
        data.intelligence = hero.intelligence
        data.primary_attribute = hero.primary_attribute
        data.str_per_level = hero.str_per_level
        data.agi_per_level = hero.agi_per_level
        data.int_per_level = hero.int_per_level

        -- Preserve inventory (copy item entity IDs)
        data.inventory = {}
        if hero.inventory then
            for i, item in ipairs(hero.inventory) do
                data.inventory[i] = item
            end
        end
    end

    -- Get stats
    local stats = ecs.get_component(entity, "stats")
    if stats then
        data.hp_max = stats.hp_max
        data.mp_max = stats.mp_max
        data.hp_regen = stats.hp_regen
        data.mp_regen = stats.mp_regen
    end

    -- Get abilities
    local abilities = ecs.get_component(entity, "abilities")
    if abilities then
        data.ability_ids = {}
        for i, id in ipairs(abilities.ability_ids or {}) do
            data.ability_ids[i] = id
        end

        data.ability_levels = {}
        for id, level in pairs(abilities.levels or {}) do
            data.ability_levels[id] = level
        end

        data.ability_cooldowns = {}
        for id, cd in pairs(abilities.cooldowns or {}) do
            data.ability_cooldowns[id] = cd
        end
    end

    return data
end
-- }}}

-- {{{ death.create_ghost
-- Create a ghost entity for a dead hero.
-- @param dead_entity Entity ID of the dead hero
-- @param corpse_entity Entity ID of the corpse (optional)
-- @return ghost entity ID, or nil if ghost shouldn't be created
function death.create_ghost(dead_entity, corpse_entity)
    -- Validate: entity must exist and be dead
    if not ecs.entity_exists(dead_entity) then
        return nil
    end

    if not death.is_dead(dead_entity) then
        return nil
    end

    -- Only heroes get ghosts
    local unit_type = ecs.get_component(dead_entity, "unit_type")
    local is_hero = (unit_type and unit_type.is_hero) or ecs.has_component(dead_entity, "hero")
    if not is_hero then
        return nil
    end

    -- Check if ghost already exists for this unit
    if unit_to_ghost[dead_entity] then
        return unit_to_ghost[dead_entity]
    end

    -- Get death position
    local pos = ecs.get_component(dead_entity, "position")
    local ghost_x = pos and pos.x or 0
    local ghost_y = pos and pos.y or 0
    local ghost_facing = pos and pos.facing or 0

    -- Get owner
    local owner = ecs.get_component(dead_entity, "owner")
    local owner_player = owner and owner.player_id or nil

    -- Preserve hero data
    local original_data = death.preserve_hero_data(dead_entity)

    -- Create ghost entity
    local ghost = ecs.create_entity()

    -- Add position component (ghost starts at death location)
    ecs.add_component(ghost, "position", {
        x = ghost_x,
        y = ghost_y,
        z = 0,
        facing = ghost_facing,
    })

    -- Add ghost component
    ecs.add_component(ghost, "ghost", {
        linked_corpse = corpse_entity,
        original_entity = dead_entity,
        original_data = original_data,
        owner_player = owner_player,
        movement_speed = 400,
        visible_to_owner = true,
        visible_to_allies = false,
        visible_to_enemies = false,
        at_altar = false,
        revival_started = false,
    })

    -- Add to spirit world layer
    ecs.add_component(ghost, "world_layer", {
        layer = death.LAYER.SPIRIT,
    })

    -- Add movement component (ghosts can fly)
    ecs.add_component(ghost, "movement", {
        speed = 400,
        speed_modifier = 1.0,
        pathing_type = "fly",  -- Ghosts ignore terrain
    })

    -- Add selectable component (owner can select their ghost)
    ecs.add_component(ghost, "selectable", {
        selected = false,
        selection_scale = 1.0,
        selection_priority = 0,
        show_healthbar = false,
        show_manabar = false,
        can_select = true,
    })

    -- Add owner component
    ecs.add_component(ghost, "owner", {
        player_id = owner_player or 0,
    })

    -- Track the relationship
    ghost_to_unit[ghost] = dead_entity
    unit_to_ghost[dead_entity] = ghost

    -- Link corpse to ghost if provided
    if corpse_entity then
        death.link_corpse_to_ghost(corpse_entity, ghost)
    end

    return ghost
end
-- }}}

-- {{{ death.get_ghost
-- Get the ghost entity for a dead hero.
-- @param dead_entity Entity ID of the dead hero
-- @return ghost entity ID, or nil if no ghost exists
function death.get_ghost(dead_entity)
    return unit_to_ghost[dead_entity]
end
-- }}}

-- {{{ death.get_ghost_unit
-- Get the original unit entity for a ghost.
-- @param ghost Entity ID of the ghost
-- @return unit entity ID, or nil if unknown
function death.get_ghost_unit(ghost)
    return ghost_to_unit[ghost]
end
-- }}}

-- {{{ death.is_ghost
-- Check if an entity is a ghost.
-- @param entity Entity ID
-- @return boolean true if entity has ghost component
function death.is_ghost(entity)
    return ecs.has_component(entity, "ghost")
end
-- }}}

-- {{{ death.get_linked_corpse
-- Get the corpse entity linked to a ghost.
-- @param ghost Entity ID of the ghost
-- @return corpse entity ID, or nil if not linked
function death.get_linked_corpse(ghost)
    local ghost_comp = ecs.get_component(ghost, "ghost")
    if not ghost_comp then
        return nil
    end
    return ghost_comp.linked_corpse
end
-- }}}

-- {{{ death.get_original_data
-- Get the preserved hero data from a ghost.
-- @param ghost Entity ID of the ghost
-- @return table original data, or nil if not a ghost
function death.get_original_data(ghost)
    local ghost_comp = ecs.get_component(ghost, "ghost")
    if not ghost_comp then
        return nil
    end
    return ghost_comp.original_data
end
-- }}}

-- {{{ death.can_see_ghost
-- Check if a player can see a ghost.
-- @param viewer_player Player ID viewing
-- @param ghost Entity ID of the ghost
-- @return boolean true if player can see ghost
function death.can_see_ghost(viewer_player, ghost)
    local ghost_comp = ecs.get_component(ghost, "ghost")
    if not ghost_comp then
        return false
    end

    -- Owner visibility
    if viewer_player == ghost_comp.owner_player then
        return ghost_comp.visible_to_owner
    end

    -- Alliance check (simplified - assumes players with same team are allies)
    -- Full alliance system would require player module integration
    local viewer_owner = nil -- Would get from player system
    local ghost_owner = ghost_comp.owner_player

    -- For now, treat all non-owners as potential enemies
    -- In a full implementation, check alliance:
    -- if is_ally(viewer_player, ghost_owner) then
    --     return ghost_comp.visible_to_allies
    -- end

    return ghost_comp.visible_to_enemies
end
-- }}}

-- {{{ death.set_ghost_visibility
-- Set ghost visibility rules.
-- @param ghost Entity ID of the ghost
-- @param owner boolean owner can see
-- @param allies boolean allies can see
-- @param enemies boolean enemies can see
-- @return boolean true if visibility was set
function death.set_ghost_visibility(ghost, owner, allies, enemies)
    local ghost_comp = ecs.get_component(ghost, "ghost")
    if not ghost_comp then
        return false
    end

    if owner ~= nil then
        ghost_comp.visible_to_owner = owner
    end
    if allies ~= nil then
        ghost_comp.visible_to_allies = allies
    end
    if enemies ~= nil then
        ghost_comp.visible_to_enemies = enemies
    end

    return true
end
-- }}}

-- {{{ death.ghost_at_altar
-- Mark a ghost as having reached an altar.
-- @param ghost Entity ID of the ghost
-- @param altar Entity ID of the altar (optional, for future use)
-- @return boolean true if marked successfully
function death.ghost_at_altar(ghost, altar)
    local ghost_comp = ecs.get_component(ghost, "ghost")
    if not ghost_comp then
        return false
    end

    ghost_comp.at_altar = true
    return true
end
-- }}}

-- {{{ death.is_at_altar
-- Check if a ghost has reached an altar.
-- @param ghost Entity ID of the ghost
-- @return boolean true if at altar
function death.is_at_altar(ghost)
    local ghost_comp = ecs.get_component(ghost, "ghost")
    if not ghost_comp then
        return false
    end
    return ghost_comp.at_altar
end
-- }}}

-- {{{ death.destroy_ghost
-- Remove a ghost entity (on revival or timeout).
-- @param ghost Entity ID of the ghost
-- @return boolean true if ghost was destroyed
function death.destroy_ghost(ghost)
    if not death.is_ghost(ghost) then
        return false
    end

    -- Clean up tracking
    local unit = ghost_to_unit[ghost]
    if unit then
        unit_to_ghost[unit] = nil
    end
    ghost_to_unit[ghost] = nil

    -- Unlink from corpse if linked
    local ghost_comp = ecs.get_component(ghost, "ghost")
    if ghost_comp and ghost_comp.linked_corpse then
        local corpse_comp = ecs.get_component(ghost_comp.linked_corpse, "corpse")
        if corpse_comp then
            corpse_comp.linked_ghost = nil
        end
    end

    -- Destroy the entity
    ecs.destroy_entity(ghost)

    return true
end
-- }}}

-- {{{ death.count_ghosts
-- Count all ghost entities.
-- @return number count of ghosts
function death.count_ghosts()
    local storage = ecs.get_component_storage("ghost")
    if not storage then
        return 0
    end

    local count = 0
    for _ in pairs(storage) do
        count = count + 1
    end
    return count
end
-- }}}

-- ============================================================================
-- Resurrection Mechanics (Issue 701d)
-- ============================================================================

-- {{{ Revival tracking tables
-- Maps altar entities to their revival queues
local altar_revival_queue = {}  -- altar -> {ghost1, ghost2, ...}
local ghost_to_altar = {}       -- ghost -> altar being revived at

-- Extend reset_tracking for revival tables
local ghost_reset = death.reset_tracking
function death.reset_tracking()
    ghost_reset()
    altar_revival_queue = {}
    ghost_to_altar = {}
end
-- }}}

-- {{{ Revival formula constants (match WC3 behavior)
-- Base revival time in seconds: 55 + (level-1) * 5
-- Level 1: 55s, Level 5: 75s, Level 10: 100s
death.REVIVAL_BASE_TIME = 55
death.REVIVAL_TIME_PER_LEVEL = 5

-- Revival gold cost: level * 100
-- Level 1: 100g, Level 5: 500g, Level 10: 1000g
death.REVIVAL_GOLD_PER_LEVEL = 100
-- }}}

-- {{{ death.get_revival_time
-- Calculate revival time for a hero level.
-- @param hero_level Hero level (1-10+)
-- @return number seconds to revive
function death.get_revival_time(hero_level)
    hero_level = hero_level or 1
    hero_level = math.max(1, hero_level)  -- Minimum level 1
    return death.REVIVAL_BASE_TIME + (hero_level - 1) * death.REVIVAL_TIME_PER_LEVEL
end
-- }}}

-- {{{ death.get_revival_cost
-- Calculate revival gold cost for a hero level.
-- @param hero_level Hero level (1-10+)
-- @return number gold cost
function death.get_revival_cost(hero_level)
    hero_level = hero_level or 1
    hero_level = math.max(1, hero_level)  -- Minimum level 1
    return hero_level * death.REVIVAL_GOLD_PER_LEVEL
end
-- }}}

-- {{{ death.is_altar
-- Check if an entity is an altar (can revive heroes).
-- Looks for altar component or unit_type with is_altar flag.
-- @param entity Entity ID
-- @return boolean true if entity is an altar
function death.is_altar(entity)
    if not ecs.entity_exists(entity) then
        return false
    end

    -- Check for explicit altar component
    if ecs.has_component(entity, "altar") then
        return true
    end

    -- Check unit_type for is_altar flag
    local unit_type = ecs.get_component(entity, "unit_type")
    if unit_type and unit_type.is_altar then
        return true
    end

    return false
end
-- }}}

-- {{{ death.can_revive_at
-- Check if a ghost can be revived at an altar.
-- @param altar Entity ID of altar
-- @param ghost Entity ID of ghost
-- @return boolean success, string error_message
function death.can_revive_at(altar, ghost)
    -- Validate altar
    if not death.is_altar(altar) then
        return false, "not an altar"
    end

    -- Altar must be alive
    if death.is_dead(altar) then
        return false, "altar is dead"
    end

    -- Validate ghost
    if not death.is_ghost(ghost) then
        return false, "not a ghost"
    end

    -- Ghost must not already be reviving
    if ecs.has_component(ghost, "reviving") then
        return false, "already reviving"
    end

    -- Check ownership (altar and ghost must belong to same player)
    local altar_owner = ecs.get_component(altar, "owner")
    local ghost_comp = ecs.get_component(ghost, "ghost")

    if altar_owner and ghost_comp then
        if altar_owner.player_id ~= ghost_comp.owner_player then
            return false, "altar belongs to different player"
        end
    end

    return true, nil
end
-- }}}

-- {{{ death.get_altar_queue
-- Get the revival queue for an altar.
-- @param altar Entity ID of altar
-- @return array of ghost entity IDs being revived at this altar
function death.get_altar_queue(altar)
    return altar_revival_queue[altar] or {}
end
-- }}}

-- {{{ death.begin_altar_revival
-- Start revival process for a ghost at an altar.
-- @param altar Entity ID of altar
-- @param ghost Entity ID of ghost
-- @param gold_paid Gold already deducted (optional, for validation)
-- @return boolean success, string error_message
function death.begin_altar_revival(altar, ghost, gold_paid)
    -- Validate can revive
    local can_revive, err = death.can_revive_at(altar, ghost)
    if not can_revive then
        return false, err
    end

    -- Get ghost data for level info
    local ghost_comp = ecs.get_component(ghost, "ghost")
    local original_data = ghost_comp.original_data or {}
    local hero_level = original_data.level or 1

    -- Calculate time and cost
    local revival_time = death.get_revival_time(hero_level)
    local revival_cost = death.get_revival_cost(hero_level)

    -- Add reviving component to ghost
    ecs.add_component(ghost, "reviving", {
        altar = altar,
        time_remaining = revival_time,
        time_total = revival_time,
        gold_cost = gold_paid or revival_cost,
        hero_level = hero_level,
    })

    -- Mark ghost as revival started
    ghost_comp.revival_started = true

    -- Add to altar queue
    if not altar_revival_queue[altar] then
        altar_revival_queue[altar] = {}
    end
    altar_revival_queue[altar][#altar_revival_queue[altar] + 1] = ghost

    -- Track ghost->altar mapping
    ghost_to_altar[ghost] = altar

    -- Get altar position for event
    local altar_pos = ecs.get_component(altar, "position")
    local altar_x = altar_pos and altar_pos.x or 0
    local altar_y = altar_pos and altar_pos.y or 0

    -- Fire HERO_REVIVE_START event
    events.fire(events.EVENT.HERO_REVIVE_START, {
        event_id = events.EVENT.HERO_REVIVE_START,
        unit = ghost_comp.original_entity,
        ghost = ghost,
        altar = altar,
        time = revival_time,
        gold = revival_cost,
        altar_x = altar_x,
        altar_y = altar_y,
    })

    return true, nil
end
-- }}}

-- {{{ death.cancel_altar_revival
-- Cancel an in-progress altar revival.
-- @param ghost Entity ID of ghost being revived
-- @return boolean success, number gold_refund
function death.cancel_altar_revival(ghost)
    -- Must have reviving component
    local reviving = ecs.get_component(ghost, "reviving")
    if not reviving then
        return false, 0
    end

    local gold_refund = reviving.gold_cost
    local altar = reviving.altar

    -- Remove from altar queue
    if altar and altar_revival_queue[altar] then
        local queue = altar_revival_queue[altar]
        for i, g in ipairs(queue) do
            if g == ghost then
                table.remove(queue, i)
                break
            end
        end
        -- Clean up empty queue
        if #altar_revival_queue[altar] == 0 then
            altar_revival_queue[altar] = nil
        end
    end

    -- Clear tracking
    ghost_to_altar[ghost] = nil

    -- Remove reviving component
    ecs.remove_component(ghost, "reviving")

    -- Reset ghost state
    local ghost_comp = ecs.get_component(ghost, "ghost")
    if ghost_comp then
        ghost_comp.revival_started = false
    end

    return true, gold_refund
end
-- }}}

-- {{{ death.get_revival_progress
-- Get revival progress as fraction (0.0 = started, 1.0 = complete).
-- @param ghost Entity ID of ghost
-- @return number 0.0-1.0 progress, or nil if not reviving
function death.get_revival_progress(ghost)
    local reviving = ecs.get_component(ghost, "reviving")
    if not reviving then
        return nil
    end

    if reviving.time_total <= 0 then
        return 1.0
    end

    local elapsed = reviving.time_total - reviving.time_remaining
    return math.min(1.0, math.max(0.0, elapsed / reviving.time_total))
end
-- }}}

-- {{{ death.get_revival_time_remaining
-- Get seconds remaining until revival completes.
-- @param ghost Entity ID of ghost
-- @return number seconds remaining, or nil if not reviving
function death.get_revival_time_remaining(ghost)
    local reviving = ecs.get_component(ghost, "reviving")
    if not reviving then
        return nil
    end
    return reviving.time_remaining
end
-- }}}

-- {{{ death.is_reviving
-- Check if a ghost is currently being revived.
-- @param ghost Entity ID
-- @return boolean true if reviving
function death.is_reviving(ghost)
    return ecs.has_component(ghost, "reviving")
end
-- }}}

-- {{{ death.get_reviving_altar
-- Get the altar a ghost is being revived at.
-- @param ghost Entity ID of ghost
-- @return altar entity ID, or nil if not reviving
function death.get_reviving_altar(ghost)
    return ghost_to_altar[ghost]
end
-- }}}

-- {{{ death.complete_revival (internal)
-- Complete a revival, restoring the hero to life.
-- @param ghost Entity ID of ghost being revived
-- @return boolean success
local function complete_revival(ghost)
    local ghost_comp = ecs.get_component(ghost, "ghost")
    if not ghost_comp then
        return false
    end

    local reviving = ecs.get_component(ghost, "reviving")
    local altar = reviving and reviving.altar

    -- Get original hero entity
    local hero = ghost_comp.original_entity
    if not hero or not ecs.entity_exists(hero) then
        -- Hero entity was destroyed, can't revive
        death.destroy_ghost(ghost)
        return false
    end

    -- Get altar position for revival location
    local revive_x, revive_y
    if altar and ecs.entity_exists(altar) then
        local altar_pos = ecs.get_component(altar, "position")
        if altar_pos then
            revive_x = altar_pos.x
            revive_y = altar_pos.y
        end
    end

    -- Fallback to death position from original data
    local original_data = ghost_comp.original_data or {}
    if not revive_x then
        revive_x = original_data.death_x or 0
        revive_y = original_data.death_y or 0
    end

    -- Remove dead component from hero
    ecs.remove_component(hero, "dead")

    -- Return hero to mortal world
    death.return_to_mortal_world(hero)

    -- Update hero position
    local pos = ecs.get_component(hero, "position")
    if pos then
        pos.x = revive_x
        pos.y = revive_y
    end

    -- Restore hero stats from original data
    local stats = ecs.get_component(hero, "stats")
    if stats then
        -- Restore to full HP (can be customized with hp_percent in revive())
        stats.hp = stats.hp_max or original_data.hp_max or 100
        -- Restore mana to full as well
        stats.mp = stats.mp_max or original_data.mp_max or 0
    end

    -- Restore hero component data
    local hero_comp = ecs.get_component(hero, "hero")
    if hero_comp and original_data then
        -- Level and experience preserved through death
        -- Ability cooldowns may have ticked down during revival
        if original_data.inventory then
            hero_comp.inventory = original_data.inventory
        end
    end

    -- Clean up revival tracking
    if altar then
        if altar_revival_queue[altar] then
            local queue = altar_revival_queue[altar]
            for i, g in ipairs(queue) do
                if g == ghost then
                    table.remove(queue, i)
                    break
                end
            end
            if #altar_revival_queue[altar] == 0 then
                altar_revival_queue[altar] = nil
            end
        end
    end
    ghost_to_altar[ghost] = nil

    -- Fire HERO_REVIVED event
    events.fire(events.EVENT.HERO_REVIVED, {
        event_id = events.EVENT.HERO_REVIVED,
        unit = hero,
        altar = altar,
        revive_x = revive_x,
        revive_y = revive_y,
        ghost = ghost,
    })

    -- Clean up corpse if linked
    local linked_corpse = ghost_comp.linked_corpse
    if linked_corpse and ecs.entity_exists(linked_corpse) then
        death.destroy_corpse(linked_corpse)
    end

    -- Destroy ghost entity
    death.destroy_ghost(ghost)

    return true
end
-- }}}

-- {{{ death.revive_hero
-- Revive a dead hero instantly (spell-based resurrection).
-- Uses preserved data from ghost if available.
-- @param hero Entity ID of dead hero
-- @param x Revival X position (optional)
-- @param y Revival Y position (optional)
-- @param hp_percent HP to restore (0.0-1.0, default 1.0)
-- @return boolean success
function death.revive_hero(hero, x, y, hp_percent)
    if not ecs.entity_exists(hero) then
        return false
    end

    if not death.is_dead(hero) then
        return false
    end

    -- Check if there's a ghost for this hero
    local ghost = death.get_ghost(hero)

    -- If reviving at altar, cancel the altar revival
    if ghost and death.is_reviving(ghost) then
        death.cancel_altar_revival(ghost)
    end

    -- Get original data from ghost if available
    local original_data = nil
    if ghost then
        original_data = death.get_original_data(ghost)
    end

    -- Determine revival position
    local revive_x = x
    local revive_y = y
    if not revive_x and original_data then
        revive_x = original_data.death_x
        revive_y = original_data.death_y
    end
    if not revive_x then
        local pos = ecs.get_component(hero, "position")
        if pos then
            revive_x = pos.x
            revive_y = pos.y
        end
    end

    -- Remove dead component
    ecs.remove_component(hero, "dead")

    -- Return to mortal world
    death.return_to_mortal_world(hero)

    -- Update position
    local pos = ecs.get_component(hero, "position")
    if pos then
        if revive_x then pos.x = revive_x end
        if revive_y then pos.y = revive_y end
    end

    -- Restore HP
    local stats = ecs.get_component(hero, "stats")
    if stats then
        hp_percent = hp_percent or 1.0
        hp_percent = math.max(0.01, math.min(1.0, hp_percent))
        stats.hp = stats.hp_max * hp_percent
    end

    -- Get linked corpse before destroying ghost
    local linked_corpse = nil
    if ghost then
        linked_corpse = death.get_linked_corpse(ghost)
    end

    -- Fire resurrection event
    events.fire(events.EVENT.UNIT_RESURRECTED, {
        event_id = events.EVENT.UNIT_RESURRECTED,
        unit = hero,
        resurrected_unit = hero,
        revive_x = revive_x or 0,
        revive_y = revive_y or 0,
        hp_percent = hp_percent,
    })

    -- Clean up ghost if exists
    if ghost then
        death.destroy_ghost(ghost)
    end

    -- Clean up corpse if linked
    if linked_corpse and ecs.entity_exists(linked_corpse) then
        death.destroy_corpse(linked_corpse)
    end

    return true
end
-- }}}

-- {{{ death.revive_at_corpse
-- Revive a dead hero at their corpse location.
-- @param hero Entity ID of dead hero
-- @param hp_percent HP to restore (0.0-1.0, default 1.0)
-- @return boolean success
function death.revive_at_corpse(hero, hp_percent)
    if not death.is_dead(hero) then
        return false
    end

    -- Find corpse position
    local corpse = death.get_corpse(hero)
    local x, y

    if corpse then
        local pos = ecs.get_component(corpse, "position")
        if pos then
            x = pos.x
            y = pos.y
        end
    end

    -- Fall back to ghost's original data
    if not x then
        local ghost = death.get_ghost(hero)
        if ghost then
            local data = death.get_original_data(ghost)
            if data then
                x = data.death_x
                y = data.death_y
            end
        end
    end

    return death.revive_hero(hero, x, y, hp_percent)
end
-- }}}

-- ============================================================================
-- Revival System (701d)
-- ============================================================================

-- {{{ Revival countdown system
-- Runs each tick to update revival timers.
-- When timer hits 0, completes the revival.
local function revival_system(iter, dt)
    local to_complete = {}

    for entity, reviving in iter do
        -- Decrement timer
        reviving.time_remaining = reviving.time_remaining - dt

        -- Check for completion
        if reviving.time_remaining <= 0 then
            to_complete[#to_complete + 1] = entity
        end
    end

    -- Complete revivals (can't modify during iteration)
    for _, ghost in ipairs(to_complete) do
        complete_revival(ghost)
    end
end

-- Register revival system
-- Priority 65 = runs after corpse decay, handles revival completion
ecs.register_system(
    "revival",
    {"reviving"},
    revival_system,
    {priority = 65}
)
-- }}}

return death
