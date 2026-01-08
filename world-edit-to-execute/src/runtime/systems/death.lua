--[[
Death System (Issue 701a)

Provides death state management, death events, and query functions.
This is the foundation for the complete death/resurrection system.

Usage:
    local death = require("runtime.systems.death")

    -- Kill a unit
    death.kill(entity, killer, "damage")

    -- Check if dead
    if death.is_dead(entity) then
        local elapsed = death.time_since_death(entity)
    end

The death system:
- Registers the "dead" component
- Provides kill() API to mark entities as dead
- Fires EVENT_UNIT_DEATH and EVENT_HERO_DEATH events
- Registers a system to auto-kill entities when hp <= 0
- Provides query functions for dead state

Related issues:
- 701b: Spirit world layer
- 701c: Ghost form component
- 701d: Resurrection mechanics
- 701e: Corpse system
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

-- Initialize components on module load
ensure_dead_component()
ensure_layer_component()

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

return death
