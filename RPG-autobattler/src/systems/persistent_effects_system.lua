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
-- Zones: an area ability with zone_duration leaves its circle on the
-- ground. Every zone_interval seconds the zone pulses: each unit of the
-- side it affects (enemies for damage, allies for healing) standing
-- inside takes zone_power damage or healing, and the zone's effect (a
-- slow, say) is put on it or renewed. Zones last their full time even if
-- the caster dies. The first pulse comes one interval after the cast,
-- the instant part of the cast having just landed.
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
        zones = {},              -- list of active zones
        next_id = 1,
        stats = {added = 0, refreshed = 0, ticks = 0, expired = 0, cleansed = 0,
                 damage_dealt = 0, healing_done = 0,
                 zones_added = 0, zone_pulses = 0, zone_hits = 0, zones_expired = 0}
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

-- {{{ PersistentEffectsSystem:add_zone
-- spec: {x, y, radius, duration, interval, effect ("damage" or "heal"),
-- power, damage_type, team (the caster's), status (an effect spec for
-- AbilityEffectSystem:add_effect, or nil), visual, name}. Returns the zone.
function PersistentEffectsSystem:add_zone(caster, spec)
    local zone = {
        id = self.next_id,
        name = spec.name or "zone",
        caster = caster,
        team = spec.team or 0,
        x = spec.x, y = spec.y,
        radius = spec.radius,
        effect = spec.effect or "damage",
        power = spec.power or 0,
        damage_type = spec.damage_type or "magical",
        status = spec.status,
        interval = spec.interval or PersistentEffectsSystem.DEFAULT_INTERVAL,
        duration = spec.duration,
        remaining = spec.duration,
        until_pulse = spec.interval or PersistentEffectsSystem.DEFAULT_INTERVAL,
        visual = spec.visual
    }
    self.next_id = self.next_id + 1
    table.insert(self.zones, zone)
    self.stats.zones_added = self.stats.zones_added + 1
    return zone
end
-- }}}

-- {{{ PersistentEffectsSystem:units_in_zone
-- Living units of the side the zone affects, standing inside it, in a
-- steady order.
function PersistentEffectsSystem:units_in_zone(zone)
    local em = self.entity_manager
    local inside = {}
    local radius_sq = zone.radius * zone.radius
    for _, entity in ipairs(em:get_entities_with_components({"position", "health", "team"})) do
        if Unit.is_alive(em, entity) then
            local is_enemy = em:get_component(entity, "team").player_id ~= zone.team
            if is_enemy == (zone.effect ~= "heal") then
                local pos = em:get_component(entity, "position")
                local dx, dy = pos.x - zone.x, pos.y - zone.y
                if dx * dx + dy * dy <= radius_sq then
                    table.insert(inside, entity)
                end
            end
        end
    end
    table.sort(inside, function(a, b) return a.id < b.id end)
    return inside
end
-- }}}

-- {{{ PersistentEffectsSystem:pulse_zone
function PersistentEffectsSystem:pulse_zone(zone)
    self.stats.zone_pulses = self.stats.zone_pulses + 1
    local cue_source = {visual_effect = zone.visual}
    for _, entity in ipairs(self:units_in_zone(zone)) do
        self.stats.zone_hits = self.stats.zone_hits + 1
        if zone.power > 0 then
            self:apply_tick({kind = zone.effect, caster = zone.caster, target = entity, per_tick = zone.power,
                damage_type = zone.damage_type, visual = zone.visual})
        end
        if zone.status and self.effect_system then
            self.effect_system:add_effect(zone.caster, entity, zone.status,
                zone.effect == "heal" and "buff" or "debuff", cue_source)
        end
    end
end
-- }}}

-- {{{ PersistentEffectsSystem:update_zones
function PersistentEffectsSystem:update_zones(dt)
    local still = {}
    for _, zone in ipairs(self.zones) do
        local time = math.min(dt, zone.remaining)
        zone.remaining = zone.remaining - time
        zone.until_pulse = zone.until_pulse - time
        while zone.until_pulse <= 1e-9 do
            self:pulse_zone(zone)
            zone.until_pulse = zone.until_pulse + zone.interval
        end
        if zone.remaining > 1e-9 then
            table.insert(still, zone)
        else
            self.stats.zones_expired = self.stats.zones_expired + 1
        end
    end
    self.zones = still
end
-- }}}

-- {{{ PersistentEffectsSystem:get_zones
-- The zones on the ground, for drawing: {x, y, radius, effect, fraction}.
function PersistentEffectsSystem:get_zones()
    local found = {}
    for _, zone in ipairs(self.zones) do
        table.insert(found, {x = zone.x, y = zone.y, radius = zone.radius, effect = zone.effect, name = zone.name,
            fraction = zone.duration > 0 and zone.remaining / zone.duration or 0})
    end
    return found
end
-- }}}

-- {{{ PersistentEffectsSystem:process_ability_activation
-- Adds the ability's over-time effects to each target, at the strength
-- the cast was planned at, and its zone when it leaves one.
function PersistentEffectsSystem:process_ability_activation(event)
    local ability = event.ability
    local share = (event.plan and event.plan.effect_power) or 1
    if (ability.zone_duration or 0) > 0 and event.center then
        local team = self.entity_manager:get_component(event.caster, "team")
        local status
        if ability.zone_modifiers or ability.zone_flat_modifiers then
            status = {
                name = ability.zone_effect_name,
                modifiers = ability.zone_modifiers or {},
                flat_modifiers = ability.zone_flat_modifiers or {},
                duration = ability.zone_effect_duration
            }
        end
        self:add_zone(event.caster, {
            name = ability.name,
            x = event.center.x, y = event.center.y,
            radius = ability.area_radius,
            duration = ability.zone_duration,
            interval = ability.zone_interval,
            effect = ability.area_effect,
            power = ability.zone_power * share,
            damage_type = ability.damage_type,
            team = team and team.player_id or 0,
            status = status,
            visual = ability.visual_effect
        })
    end
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
    self:update_zones(dt)
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
