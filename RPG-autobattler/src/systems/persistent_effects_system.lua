-- {{{ Persistent effects system
-- Damage and healing over time. An ability with damage_over_time or
-- heal_over_time leaves an effect on each target that ticks every
-- over_time_interval seconds for over_time_duration seconds, after its
-- instant part lands.
--
--   damage over time  each tick deals its damage through the target's
--                     armor or magic resist ("true" ignores both);
--                     it counts as a debuff, so cleanse removes it
--   heal over time    each tick heals up to full
--
-- The first tick comes one interval after the effect lands, so a 5 s
-- effect ticking every second ticks five times. Casting the same effect
-- on a target that has it replaces it: the time starts again, and it
-- keeps the stronger tick. Different effects stack. Effects end early
-- when their target dies.
--
-- Made with an AbilityEffectSystem, it attaches itself so that the effect
-- system hands it each activation and a heal's cleanse also clears
-- damage over time; and it reports its ticks through that system, so
-- damage, healing, deaths and cues are counted in one place.
local PersistentEffectsSystem = {}
PersistentEffectsSystem.__index = PersistentEffectsSystem

local Unit = require("src.entities.unit")
local DamageAbility = require("src.components.abilities.damage_ability")

PersistentEffectsSystem.DEFAULT_DURATION = {damage = 5, heal = 8}
PersistentEffectsSystem.DEFAULT_INTERVAL = 1

-- {{{ PersistentEffectsSystem:new
function PersistentEffectsSystem:new(entity_manager, effect_system)
    local system = {
        name = "persistent_effects",
        enabled = true,
        entity_manager = entity_manager,
        effect_system = effect_system,
        effects = {},            -- list of active over-time effects
        next_id = 1,
        stats = {added = 0, refreshed = 0, ticks = 0, expired = 0, cleansed = 0,
                 damage_dealt = 0, healing_done = 0}
    }
    setmetatable(system, self)
    if effect_system then
        effect_system.persistent = system
    end
    return system
end
-- }}}

-- {{{ PersistentEffectsSystem:is_enabled
function PersistentEffectsSystem:is_enabled()
    return self.enabled
end
-- }}}

-- {{{ PersistentEffectsSystem:find
function PersistentEffectsSystem:find(target, name)
    for index, effect in ipairs(self.effects) do
        if effect.target == target and effect.name == name then
            return effect, index
        end
    end
    return nil
end
-- }}}

-- {{{ PersistentEffectsSystem:add
-- kind is "damage" or "heal". spec: {name, per_tick, duration, interval,
-- damage_type}. Returns the effect.
function PersistentEffectsSystem:add(caster, target, kind, spec)
    if not Unit.is_alive(self.entity_manager, target) or (spec.per_tick or 0) <= 0 then
        return nil
    end
    local name = spec.name or (kind .. "_over_time")
    local duration = spec.duration or PersistentEffectsSystem.DEFAULT_DURATION[kind]
    local interval = spec.interval or PersistentEffectsSystem.DEFAULT_INTERVAL

    local existing = self:find(target, name)
    if existing then
        existing.remaining = duration
        existing.until_tick = interval
        existing.per_tick = math.max(existing.per_tick, spec.per_tick)
        existing.caster = caster
        self.stats.refreshed = self.stats.refreshed + 1
        return existing
    end

    local effect = {
        id = self.next_id,
        name = name,
        kind = kind,
        caster = caster,
        target = target,
        per_tick = spec.per_tick,
        interval = interval,
        duration = duration,
        remaining = duration,
        until_tick = interval,
        damage_type = spec.damage_type or "physical",
        visual = spec.visual
    }
    self.next_id = self.next_id + 1
    table.insert(self.effects, effect)
    self.stats.added = self.stats.added + 1
    return effect
end
-- }}}

-- {{{ PersistentEffectsSystem:add_damage_over_time
function PersistentEffectsSystem:add_damage_over_time(caster, target, per_tick, duration, interval, damage_type, name)
    return self:add(caster, target, "damage", {per_tick = per_tick, duration = duration, interval = interval,
        damage_type = damage_type, name = name})
end
-- }}}

-- {{{ PersistentEffectsSystem:add_heal_over_time
function PersistentEffectsSystem:add_heal_over_time(caster, target, per_tick, duration, interval, name)
    return self:add(caster, target, "heal", {per_tick = per_tick, duration = duration, interval = interval, name = name})
end
-- }}}

-- {{{ PersistentEffectsSystem:process_ability_activation
-- Adds the ability's over-time effects to each target, at the strength
-- the cast was planned at.
function PersistentEffectsSystem:process_ability_activation(event)
    local ability = event.ability
    local share = (event.plan and event.plan.effect_power) or 1
    for _, target in ipairs(event.targets) do
        if (ability.damage_over_time or 0) > 0 then
            self:add(event.caster, target.entity, "damage", {
                name = ability.name .. "_dot",
                per_tick = ability.damage_over_time * share,
                duration = ability.over_time_duration,
                interval = ability.over_time_interval,
                damage_type = ability.damage_type,
                visual = ability.visual_effect
            })
        end
        if (ability.heal_over_time or 0) > 0 then
            self:add(event.caster, target.entity, "heal", {
                name = ability.name .. "_hot",
                per_tick = ability.heal_over_time * share,
                duration = ability.over_time_duration,
                interval = ability.over_time_interval,
                visual = ability.visual_effect
            })
        end
    end
end
-- }}}

-- {{{ PersistentEffectsSystem:apply_tick
function PersistentEffectsSystem:apply_tick(effect)
    local em = self.entity_manager
    self.stats.ticks = self.stats.ticks + 1
    local fake_ability = {visual_effect = effect.visual}
    if effect.kind == "damage" then
        local stats = self.effect_system and self.effect_system:stats_of(effect.target) or nil
        local amount = DamageAbility.reduce(effect.per_tick, effect.damage_type, 0, stats)
        local dealt
        if self.effect_system then
            dealt = self.effect_system:deal_damage(effect.caster, effect.target, amount, fake_ability)
        else
            local health = em:get_component(effect.target, "health")
            dealt = math.min(amount, health.current_hp)
            Unit.damage_unit(em, effect.target, amount)
        end
        self.stats.damage_dealt = self.stats.damage_dealt + dealt
    else
        local healed
        if self.effect_system then
            healed = self.effect_system:heal(effect.caster, effect.target, effect.per_tick, fake_ability)
        else
            local health = em:get_component(effect.target, "health")
            healed = math.min(effect.per_tick, health.max_hp - health.current_hp)
            Unit.heal_unit(em, effect.target, effect.per_tick)
        end
        self.stats.healing_done = self.stats.healing_done + healed
    end
end
-- }}}

-- {{{ PersistentEffectsSystem:update
function PersistentEffectsSystem:update(dt)
    local em = self.entity_manager
    local still = {}
    for _, effect in ipairs(self.effects) do
        local alive = Unit.is_alive(em, effect.target)
        if alive then
            local time = math.min(dt, effect.remaining)
            effect.remaining = effect.remaining - time
            effect.until_tick = effect.until_tick - time
            -- A long frame can hold more than one tick.
            while effect.until_tick <= 1e-9 and Unit.is_alive(em, effect.target) do
                self:apply_tick(effect)
                effect.until_tick = effect.until_tick + effect.interval
            end
        end
        if alive and Unit.is_alive(em, effect.target) and effect.remaining > 1e-9 then
            table.insert(still, effect)
        else
            self.stats.expired = self.stats.expired + 1
        end
    end
    self.effects = still
end
-- }}}

-- {{{ PersistentEffectsSystem:cleanse
-- Removes a target's over-time effects of a kind ("damage" or "heal"),
-- or both when kind is nil. Returns how many were removed.
function PersistentEffectsSystem:cleanse(target, kind)
    local kept, removed = {}, 0
    for _, effect in ipairs(self.effects) do
        if effect.target == target and (kind == nil or effect.kind == kind) then
            removed = removed + 1
        else
            table.insert(kept, effect)
        end
    end
    self.effects = kept
    self.stats.cleansed = self.stats.cleansed + removed
    return removed
end
-- }}}

-- {{{ PersistentEffectsSystem:get_effects_on
-- The over-time effects on a target, for drawing and debugging.
function PersistentEffectsSystem:get_effects_on(target)
    local found = {}
    for _, effect in ipairs(self.effects) do
        if effect.target == target then
            table.insert(found, {
                name = effect.name,
                kind = effect.kind,
                per_tick = effect.per_tick,
                remaining = effect.remaining,
                fraction = effect.duration > 0 and effect.remaining / effect.duration or 0
            })
        end
    end
    return found
end
-- }}}

return PersistentEffectsSystem
-- }}}
