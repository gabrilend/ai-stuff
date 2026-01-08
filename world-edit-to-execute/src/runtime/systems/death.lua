--[[
Death System (Issues 701a, 701e)

Provides death state management, corpse system, death events, and query functions.
This is the foundation for the complete death/resurrection system.

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

    -- Query corpses
    local corpses = death.find_corpses_in_range(x, y, 500)

The death system:
- Registers the "dead" component
- Registers the "corpse" component (701e)
- Provides kill() API to mark entities as dead
- Provides corpse creation and decay system (701e)
- Fires EVENT_UNIT_DEATH and EVENT_HERO_DEATH events
- Registers a system to auto-kill entities when hp <= 0
- Provides query functions for dead state and corpses

Related issues:
- 701b: Spirit world layer
- 701c: Ghost form component
- 701d: Resurrection mechanics
- 701e: Corpse system (integrated)
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

-- Initialize components on module load
ensure_dead_component()
ensure_layer_component()
ensure_corpse_component()

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

return death
