-- {{{ Cooldown system
-- Keeps the timers that stop abilities firing again too soon. A full
-- mana bar is an ability's main pacing; cooldowns are an extra wait some
-- abilities have after firing, on top of refilling their bar.
--
-- Timers live in each unit's abilities component
-- (src/components/unit_abilities.lua), so there is one place to look:
--   cooldowns[i]           seconds left on ability i
--   cooldown_durations[i]  how long it was when it started (for drawing)
--   global_cooldown        seconds left before any ability may fire
-- This system starts them, counts them down and answers whether an
-- ability is waiting.
--
-- Kinds of cooldown:
--   ability   the ability's own `cooldown` seconds
--   global    every ability of the unit waits (set by the activation
--             system after each cast)
--   shared    abilities with the same `shared_cooldown` name also wait,
--             for SHARED_FRACTION of the time
-- Cooldown reduction shortens ability and shared cooldowns: the unit's
-- "cooldown_reduction" stat (from buffs, through the effect system's
-- get_stat) plus the ability's cooldown_reduction_bonus, at most
-- MAX_REDUCTION.
local CooldownSystem = {}
CooldownSystem.__index = CooldownSystem

CooldownSystem.MAX_REDUCTION = 0.75
CooldownSystem.SHARED_FRACTION = 0.5

-- {{{ CooldownSystem:new
-- options.stats: anything with get_stat(entity, name), such as the
-- AbilityEffectSystem, to read cooldown reduction from.
function CooldownSystem:new(entity_manager, options)
    options = options or {}
    local system = {
        name = "cooldowns",
        enabled = true,
        entity_manager = entity_manager,
        stats_source = options.stats,
        stats = {started = 0, shared = 0, time_saved = 0}
    }
    setmetatable(system, self)
    return system
end
-- }}}

-- {{{ CooldownSystem:is_enabled
function CooldownSystem:is_enabled()
    return self.enabled
end
-- }}}

-- {{{ CooldownSystem:reduction_for
-- The share of a cooldown taken off for this unit and ability, 0 to
-- MAX_REDUCTION.
function CooldownSystem:reduction_for(entity, ability)
    local reduction = ability.cooldown_reduction_bonus or 0
    if self.stats_source and self.stats_source.get_stat then
        reduction = reduction + self.stats_source:get_stat(entity, "cooldown_reduction")
    end
    return math.max(0, math.min(CooldownSystem.MAX_REDUCTION, reduction))
end
-- }}}

-- {{{ local function set_timer
-- Never shortens a timer that is already longer.
local function set_timer(container, index, seconds)
    container.cooldown_durations = container.cooldown_durations or {}
    if seconds > (container.cooldowns[index] or 0) then
        container.cooldowns[index] = seconds
        container.cooldown_durations[index] = seconds
    end
end
-- }}}

-- {{{ CooldownSystem:start
-- Starts ability `index`'s cooldowns after it fires, and the unit's
-- global cooldown of `global_seconds`. Returns the ability's own
-- cooldown after reduction.
function CooldownSystem:start(entity, container, index, global_seconds)
    local ability = container.abilities[index]
    local reduction = self:reduction_for(entity, ability)
    local seconds = (ability.cooldown or 0) * (1 - reduction)
    if seconds > 0 then
        set_timer(container, index, seconds)
        self.stats.started = self.stats.started + 1
        self.stats.time_saved = self.stats.time_saved + (ability.cooldown or 0) * reduction
    end

    if ability.shared_cooldown and seconds > 0 then
        for other_index, other in ipairs(container.abilities) do
            if other_index ~= index and other.shared_cooldown == ability.shared_cooldown then
                set_timer(container, other_index, seconds * CooldownSystem.SHARED_FRACTION)
                self.stats.shared = self.stats.shared + 1
            end
        end
    end

    if global_seconds and global_seconds > container.global_cooldown then
        container.global_cooldown = global_seconds
    end
    return seconds
end
-- }}}

-- {{{ CooldownSystem:is_on_cooldown
-- Returns whether ability `index` is waiting, which cooldown ("global" or
-- "ability"), and the seconds left.
function CooldownSystem:is_on_cooldown(container, index)
    if container.global_cooldown > 0 then
        return true, "global", container.global_cooldown
    end
    local remaining = container.cooldowns[index] or 0
    if remaining > 0 then
        return true, "ability", remaining
    end
    return false, "ready", 0
end
-- }}}

-- {{{ CooldownSystem:tick
-- Counts one unit's timers down.
function CooldownSystem:tick(container, dt)
    for index, remaining in ipairs(container.cooldowns) do
        if remaining > 0 then
            container.cooldowns[index] = math.max(0, remaining - dt)
        end
    end
    if container.global_cooldown > 0 then
        container.global_cooldown = math.max(0, container.global_cooldown - dt)
    end
end
-- }}}

-- {{{ CooldownSystem:update
function CooldownSystem:update(dt)
    for _, entity in ipairs(self.entity_manager:get_entities_with_component("abilities")) do
        self:tick(self.entity_manager:get_component(entity, "abilities"), dt)
    end
end
-- }}}

-- {{{ CooldownSystem:reset_all
-- Clears every timer of one unit, e.g. when a new round starts.
function CooldownSystem:reset_all(container)
    for index in ipairs(container.cooldowns) do
        container.cooldowns[index] = 0
    end
    container.global_cooldown = 0
end
-- }}}

-- {{{ CooldownSystem:get_status
-- One row per ability for drawing a cooldown sweep:
--   {index, remaining, fraction (1 just started, 0 ready), ready}
function CooldownSystem:get_status(container)
    local rows = {}
    for index in ipairs(container.abilities) do
        local remaining = container.cooldowns[index] or 0
        local duration = (container.cooldown_durations or {})[index] or 0
        rows[index] = {
            index = index,
            remaining = remaining,
            fraction = duration > 0 and remaining / duration or 0,
            ready = remaining <= 0 and container.global_cooldown <= 0
        }
    end
    return rows
end
-- }}}

return CooldownSystem
-- }}}
