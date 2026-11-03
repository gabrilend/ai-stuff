-- {{{ Ability effect system
-- Carries out what an activated ability does. The activation system
-- (src/systems/ability_activation_system.lua) hands it each activation
-- event through process_ability_activation(event).
--
-- By ability type:
--   damage  each target takes the ability's damage at the planned
--           strength, after the caster's attack and the target's armor or
--           magic resist. A "projectile" delivery travels instead, and
--           hits up to `pierce` enemies on its path.
--   heal    each target heals up to full; the caster heals its
--           self_heal_ratio share; cleanse removes the target's debuffs.
--   buff,   each target gains a named effect for its duration: stat
--   debuff  modifiers, and possibly stun or silence. Recasting refreshes
--           it, or adds a stack up to max_stacks when stacking is "stack".
--   area    each target in the circle takes damage or healing, weaker
--           toward the edge.
--
-- Effects live in an "effects" component on the target:
--   {active = {name -> effect}, base_speed}
-- and stats in an optional "stats" component of base values (armor,
-- magic_resist, attack, healing_power). get_stat() combines the two;
-- speed modifiers change the unit's moveable speed directly.
--
-- The system doesn't draw or play anything. It keeps cues for a renderer
-- and audio player to pick up with pop_cues():
--   {kind, x, y, amount, target, caster, visual, sound, time}
-- where kind is "damage", "heal", "effect_applied", "effect_expired",
-- "projectile_launched", "projectile_hit", "projectile_miss", "area" or
-- "death".
--
-- A PersistentEffectsSystem made with this system attaches itself as
-- self.persistent and receives each activation after its instant part,
-- for damage and healing over time.
local AbilityEffectSystem = {}
AbilityEffectSystem.__index = AbilityEffectSystem

local Unit = require("src.entities.unit")

AbilityEffectSystem.DEFAULT_STATS = {armor = 0, magic_resist = 0, attack = 1, healing_power = 1}
AbilityEffectSystem.PROJECTILE_HIT_RADIUS = 6

-- {{{ AbilityEffectSystem:new
-- options.random: a function returning 0-1, for critical hits.
function AbilityEffectSystem:new(entity_manager, options)
    options = options or {}
    local system = {
        name = "ability_effects",
        enabled = true,
        entity_manager = entity_manager,
        random = options.random or math.random,
        clock = 0,
        projectiles = {},
        cues = {},
        stats = {
            damage_dealt = 0,
            healing_done = 0,
            overheal = 0,
            effects_applied = 0,
            effects_expired = 0,
            kills = 0,
            projectiles_launched = 0,
            projectile_hits = 0,
            projectile_misses = 0,
            cleave_hits = 0,
            by_type = {}         -- ability type -> {casts, amount}
        }
    }
    setmetatable(system, self)
    return system
end
-- }}}

-- {{{ AbilityEffectSystem:is_enabled
function AbilityEffectSystem:is_enabled()
    return self.enabled
end
-- }}}

-- {{{ local function position_of
local function position_of(em, entity)
    local pos = em:get_component(entity, "position")
    if pos then
        return pos.x, pos.y
    end
    return 0, 0
end
-- }}}

-- {{{ AbilityEffectSystem:cue
function AbilityEffectSystem:cue(kind, fields)
    fields.kind = kind
    fields.time = self.clock
    table.insert(self.cues, fields)
end
-- }}}

-- {{{ AbilityEffectSystem:effects_of
-- The entity's effects component, made if missing.
function AbilityEffectSystem:effects_of(entity)
    local em = self.entity_manager
    local effects = em:get_component(entity, "effects")
    if not effects then
        effects = {active = {}}
        em:add_component(entity, "effects", effects)
    end
    return effects
end
-- }}}

-- {{{ AbilityEffectSystem:get_stat
-- A stat with every active effect applied: (base + flat changes) times
-- (1 + fractional changes), never below zero. Stacks multiply changes.
function AbilityEffectSystem:get_stat(entity, stat)
    local em = self.entity_manager
    local base_stats = em:get_component(entity, "stats")
    local base = (base_stats and base_stats[stat]) or AbilityEffectSystem.DEFAULT_STATS[stat] or 0
    local effects = em:get_component(entity, "effects")
    local flat, fraction = 0, 0
    if effects then
        for _, effect in pairs(effects.active) do
            local stacks = effect.stacks or 1
            flat = flat + ((effect.flat_modifiers or {})[stat] or 0) * stacks
            fraction = fraction + ((effect.modifiers or {})[stat] or 0) * stacks
        end
    end
    return math.max(0, (base + flat) * (1 + fraction))
end
-- }}}

-- {{{ AbilityEffectSystem:stats_of
-- The combat stats the ability kinds read, with effects applied.
function AbilityEffectSystem:stats_of(entity)
    return {
        armor = self:get_stat(entity, "armor"),
        magic_resist = self:get_stat(entity, "magic_resist"),
        attack = self:get_stat(entity, "attack"),
        healing_power = self:get_stat(entity, "healing_power")
    }
end
-- }}}

-- {{{ AbilityEffectSystem:refresh_speed
-- Keeps the unit's moveable speed in step with its speed modifiers.
function AbilityEffectSystem:refresh_speed(entity)
    local em = self.entity_manager
    local moveable = em:get_component(entity, "moveable")
    local effects = em:get_component(entity, "effects")
    if not moveable or not effects then
        return
    end
    effects.base_speed = effects.base_speed or moveable.speed
    local fraction = 0
    for _, effect in pairs(effects.active) do
        fraction = fraction + ((effect.modifiers or {}).speed or 0) * (effect.stacks or 1)
    end
    moveable.speed = math.max(0, effects.base_speed * (1 + fraction))
end
-- }}}

-- {{{ AbilityEffectSystem:count
function AbilityEffectSystem:count(ability, amount)
    local row = self.stats.by_type[ability.type]
    if not row then
        row = {casts = 0, amount = 0}
        self.stats.by_type[ability.type] = row
    end
    row.casts = row.casts + 1
    row.amount = row.amount + (amount or 0)
end
-- }}}

-- {{{ AbilityEffectSystem:deal_damage
-- Applies an already-worked-out amount of damage. Returns what was dealt.
function AbilityEffectSystem:deal_damage(caster, target, amount, ability)
    local em = self.entity_manager
    if not Unit.is_alive(em, target) or amount <= 0 then
        return 0
    end
    local health = em:get_component(target, "health")
    local dealt = math.min(amount, health.current_hp)
    Unit.damage_unit(em, target, amount)
    self.stats.damage_dealt = self.stats.damage_dealt + dealt
    local x, y = position_of(em, target)
    self:cue("damage", {x = x, y = y, amount = dealt, target = target, caster = caster,
        visual = ability.visual_effect, sound = ability.sound_effect})
    if not Unit.is_alive(em, target) then
        self.stats.kills = self.stats.kills + 1
        self:cue("death", {x = x, y = y, target = target, caster = caster})
        local effects = em:get_component(target, "effects")
        if effects then
            effects.active = {}
        end
    end
    return dealt
end
-- }}}

-- {{{ AbilityEffectSystem:heal
-- Heals up to full. Returns what was healed.
function AbilityEffectSystem:heal(caster, target, amount, ability)
    local em = self.entity_manager
    if not Unit.is_alive(em, target) or amount <= 0 then
        return 0
    end
    local health = em:get_component(target, "health")
    local healed = math.min(amount, health.max_hp - health.current_hp)
    Unit.heal_unit(em, target, amount)
    self.stats.healing_done = self.stats.healing_done + healed
    self.stats.overheal = self.stats.overheal + (amount - healed)
    local x, y = position_of(em, target)
    self:cue("heal", {x = x, y = y, amount = healed, target = target, caster = caster,
        visual = ability.visual_effect, sound = ability.sound_effect})
    return healed
end
-- }}}

-- {{{ local function live_target
-- The target's health as it is now, which may differ from when it was
-- chosen earlier in the frame.
local function live_target(em, target)
    local health = em:get_component(target.entity, "health")
    return {
        entity = target.entity,
        current_health = health and health.current_hp or 0,
        max_health = health and health.max_hp or 1
    }
end
-- }}}

-- {{{ AbilityEffectSystem:cleave_targets
-- Living enemies of the caster, other than those in `skip`, within the
-- ability's range and inside its attack arc around the line from the
-- caster to the main target; nearest first, at most cleave_targets.
function AbilityEffectSystem:cleave_targets(caster, main_target, ability, skip)
    local em = self.entity_manager
    local cx, cy = position_of(em, caster)
    local tx, ty = position_of(em, main_target)
    local mx, my = tx - cx, ty - cy
    local main_length = math.sqrt(mx * mx + my * my)
    local half_arc = math.rad(ability.attack_arc / 2)
    local team = em:get_component(caster, "team")
    local own_team = team and team.player_id or 0

    local found = {}
    for _, entity in ipairs(em:get_entities_with_components({"position", "health", "team"})) do
        if entity ~= caster and not skip[entity] and Unit.is_alive(em, entity)
            and em:get_component(entity, "team").player_id ~= own_team then
            local x, y = position_of(em, entity)
            local dx, dy = x - cx, y - cy
            local distance = math.sqrt(dx * dx + dy * dy)
            if distance <= ability.range then
                local inside = true
                if main_length > 1e-6 and distance > 1e-6 then
                    local cosine = (dx * mx + dy * my) / (distance * main_length)
                    inside = math.acos(math.max(-1, math.min(1, cosine))) <= half_arc + 1e-9
                end
                if inside then
                    table.insert(found, {entity = entity, distance = distance})
                end
            end
        end
    end
    table.sort(found, function(a, b)
        if a.distance ~= b.distance then
            return a.distance < b.distance
        end
        return a.entity.id < b.entity.id
    end)
    while #found > ability.cleave_targets do
        table.remove(found)
    end
    return found
end
-- }}}

-- {{{ AbilityEffectSystem:apply_damage_effect
-- Each target takes the ability's damage. With cleave_targets, each blow
-- also strikes that many more enemies in the attack arc for cleave_ratio
-- of the damage.
function AbilityEffectSystem:apply_damage_effect(event)
    local total = 0
    local ability = event.ability
    local caster_stats = self:stats_of(event.caster)
    local struck = {}
    for _, target in ipairs(event.targets) do
        struck[target.entity] = true
    end
    for _, target in ipairs(event.targets) do
        local now = live_target(self.entity_manager, target)
        local effect = ability:calculate_effect(now, event.plan.effect_power, {
            caster_stats = caster_stats,
            target_stats = self:stats_of(target.entity),
            random = self.random
        })
        total = total + self:deal_damage(event.caster, target.entity, effect.amount, ability)
        if (ability.cleave_targets or 0) > 0 then
            for _, extra in ipairs(self:cleave_targets(event.caster, target.entity, ability, struck)) do
                struck[extra.entity] = true
                local cleave = ability:calculate_effect(live_target(self.entity_manager, extra),
                    event.plan.effect_power, {
                        caster_stats = caster_stats,
                        target_stats = self:stats_of(extra.entity),
                        random = self.random,
                        cleave = true
                    })
                total = total + self:deal_damage(event.caster, extra.entity, cleave.amount, ability)
                self.stats.cleave_hits = self.stats.cleave_hits + 1
            end
        end
    end
    return total
end
-- }}}

-- {{{ AbilityEffectSystem:apply_heal_effect
function AbilityEffectSystem:apply_heal_effect(event)
    local total = 0
    local ability = event.ability
    local caster_stats = self:stats_of(event.caster)
    for _, target in ipairs(event.targets) do
        local effect = ability:calculate_effect(live_target(self.entity_manager, target), event.plan.effect_power,
            {caster_stats = caster_stats})
        total = total + self:heal(event.caster, target.entity, effect.amount, ability)
        if effect.cleanse then
            self:cleanse(target.entity, "debuff")
        end
        if effect.self_heal and effect.self_heal > 0 then
            self:heal(event.caster, event.caster, effect.self_heal, ability)
        end
    end
    return total
end
-- }}}

-- {{{ AbilityEffectSystem:add_effect
-- Puts a named effect on a living target. spec: {name, modifiers,
-- flat_modifiers, stun, silence, duration, stacking, max_stacks}; kind is
-- "buff" or "debuff"; cue_source gives the cue's visual and sound.
-- Recasting refreshes the time, or adds a stack when stacking is
-- "stack". Returns true when the effect landed.
function AbilityEffectSystem:add_effect(caster, target, spec, kind, cue_source)
    local em = self.entity_manager
    if not Unit.is_alive(em, target) then
        return false
    end
    local effects = self:effects_of(target)
    local existing = effects.active[spec.name]
    if existing then
        if spec.stacking == "stack" and existing.stacks < existing.max_stacks then
            existing.stacks = existing.stacks + 1
        end
        existing.remaining = spec.duration
    else
        effects.active[spec.name] = {
            name = spec.name,
            kind = kind,
            modifiers = spec.modifiers,
            flat_modifiers = spec.flat_modifiers,
            stun = spec.stun,
            silence = spec.silence,
            duration = spec.duration,
            remaining = spec.duration,
            stacks = 1,
            max_stacks = spec.max_stacks or 1,
            caster = caster
        }
    end
    self:refresh_speed(target)
    self.stats.effects_applied = self.stats.effects_applied + 1
    local x, y = position_of(em, target)
    cue_source = cue_source or {}
    self:cue("effect_applied", {x = x, y = y, target = target, caster = caster,
        name = spec.name, effect_kind = kind, visual = cue_source.visual_effect, sound = cue_source.sound_effect})
    return true
end
-- }}}

-- {{{ AbilityEffectSystem:apply_status_effect
-- Buffs and debuffs.
function AbilityEffectSystem:apply_status_effect(event)
    local ability = event.ability
    local applied = 0
    for _, target in ipairs(event.targets) do
        if Unit.is_alive(self.entity_manager, target.entity) then
            local spec = ability:calculate_effect(target, event.plan.effect_power)
            if self:add_effect(event.caster, target.entity, spec, ability.type, ability) then
                applied = applied + 1
            end
        end
    end
    return applied
end
-- }}}

-- {{{ AbilityEffectSystem:apply_area_effect
function AbilityEffectSystem:apply_area_effect(event)
    local ability = event.ability
    local center = event.center
    if center then
        self:cue("area", {x = center.x, y = center.y, radius = ability.area_radius, caster = event.caster,
            effect = ability.area_effect, visual = ability.visual_effect, sound = ability.sound_effect})
    end
    local caster_stats = self:stats_of(event.caster)
    local total = 0
    for _, target in ipairs(event.targets) do
        local effect = ability:calculate_effect(live_target(self.entity_manager, target), event.plan.effect_power, {
            distance = target.distance_from_center,
            caster_stats = caster_stats,
            target_stats = self:stats_of(target.entity),
            random = self.random
        })
        if effect.effect == "heal" then
            total = total + self:heal(event.caster, target.entity, effect.amount, ability)
        else
            total = total + self:deal_damage(event.caster, target.entity, effect.amount, ability)
        end
    end
    return total
end
-- }}}

-- {{{ AbilityEffectSystem:launch_projectile
-- A projectile flies in a straight line from the caster toward where the
-- first target stood, up to the ability's range, and hits the first
-- `pierce` enemies it passes within PROJECTILE_HIT_RADIUS.
function AbilityEffectSystem:launch_projectile(event)
    local em = self.entity_manager
    local ability = event.ability
    local target = event.targets[1]
    local x, y = position_of(em, event.caster)
    local dx, dy = target.x - x, target.y - y
    local length = math.sqrt(dx * dx + dy * dy)
    if length < 1e-6 then
        dx, dy, length = 1, 0, 1
    end
    local team = em:get_component(event.caster, "team")
    local projectile = {
        x = x, y = y,
        origin_x = x, origin_y = y,
        dir_x = dx / length, dir_y = dy / length,
        speed = ability.projectile_speed,
        travelled = 0,
        max_distance = math.max(ability.range, length) + AbilityEffectSystem.PROJECTILE_HIT_RADIUS,
        hits_left = ability.pierce,
        hit = {},
        caster = event.caster,
        team = team and team.player_id or 0,
        ability = ability,
        share = event.plan.effect_power
    }
    table.insert(self.projectiles, projectile)
    self.stats.projectiles_launched = self.stats.projectiles_launched + 1
    self:cue("projectile_launched", {x = x, y = y, caster = event.caster, visual = ability.visual_effect,
        sound = ability.sound_effect})
    return projectile
end
-- }}}

-- {{{ AbilityEffectSystem:update_projectile
-- Moves one projectile; returns false once it's spent.
function AbilityEffectSystem:update_projectile(projectile, dt)
    local em = self.entity_manager
    local step = math.min(projectile.speed * dt, projectile.max_distance - projectile.travelled)
    local x1, y1 = projectile.x, projectile.y
    local x2, y2 = x1 + projectile.dir_x * step, y1 + projectile.dir_y * step
    local radius_sq = AbilityEffectSystem.PROJECTILE_HIT_RADIUS ^ 2

    -- Enemies near this stretch of the path, nearest the start first.
    local passed = {}
    for _, entity in ipairs(em:get_entities_with_components({"position", "health", "team"})) do
        if not projectile.hit[entity] and Unit.is_alive(em, entity)
            and em:get_component(entity, "team").player_id ~= projectile.team then
            local pos = em:get_component(entity, "position")
            local t = ((pos.x - x1) * projectile.dir_x + (pos.y - y1) * projectile.dir_y)
            t = math.max(0, math.min(step, t))
            local px, py = x1 + projectile.dir_x * t - pos.x, y1 + projectile.dir_y * t - pos.y
            if px * px + py * py <= radius_sq then
                table.insert(passed, {entity = entity, t = t})
            end
        end
    end
    table.sort(passed, function(a, b)
        if a.t ~= b.t then
            return a.t < b.t
        end
        return a.entity.id < b.entity.id
    end)

    local ability = projectile.ability
    for _, entry in ipairs(passed) do
        projectile.hit[entry.entity] = true
        -- A miss flies on past the enemy, still able to hit the next.
        if (ability.accuracy or 1) < 1 and self.random() >= ability.accuracy then
            self.stats.projectile_misses = self.stats.projectile_misses + 1
            local pos = em:get_component(entry.entity, "position")
            self:cue("projectile_miss", {x = pos.x, y = pos.y, target = entry.entity, caster = projectile.caster,
                visual = ability.visual_effect})
            goto continue
        end
        projectile.hits_left = projectile.hits_left - 1
        local health = em:get_component(entry.entity, "health")
        local effect = ability:calculate_effect({current_health = health.current_hp, max_health = health.max_hp},
            projectile.share, {
                caster_stats = self:stats_of(projectile.caster),
                target_stats = self:stats_of(entry.entity),
                random = self.random,
                distance = projectile.travelled + entry.t
            })
        self:deal_damage(projectile.caster, entry.entity, effect.amount, ability)
        self.stats.projectile_hits = self.stats.projectile_hits + 1
        if self.persistent then
            self.persistent:process_ability_activation({caster = projectile.caster, ability = ability,
                targets = {{entity = entry.entity}}, plan = {effect_power = projectile.share}})
        end
        local pos = em:get_component(entry.entity, "position")
        self:cue("projectile_hit", {x = pos.x, y = pos.y, target = entry.entity, caster = projectile.caster,
            visual = ability.visual_effect})
        if projectile.hits_left <= 0 then
            projectile.x = x1 + projectile.dir_x * entry.t
            projectile.y = y1 + projectile.dir_y * entry.t
            return false
        end
        ::continue::
    end

    projectile.x, projectile.y = x2, y2
    projectile.travelled = projectile.travelled + step
    return projectile.travelled < projectile.max_distance - 1e-9
end
-- }}}

-- {{{ AbilityEffectSystem:process_ability_activation
-- Called by the activation system for each event. Returns the total
-- damage or healing done at once (projectiles hit later), or the number
-- of targets a buff or debuff reached.
function AbilityEffectSystem:process_ability_activation(event)
    local ability = event.ability
    local amount
    if ability.delivery == "projectile" and ability.type == "damage" then
        self:launch_projectile(event)
        amount = 0
    elseif ability.type == "damage" then
        amount = self:apply_damage_effect(event)
    elseif ability.type == "heal" then
        amount = self:apply_heal_effect(event)
    elseif ability.type == "buff" or ability.type == "debuff" then
        amount = self:apply_status_effect(event)
    elseif ability.type == "area" then
        amount = self:apply_area_effect(event)
    else
        amount = 0
    end
    -- Over-time effects follow the instant part; a projectile's follow
    -- its hits instead.
    if self.persistent and ability.delivery ~= "projectile" then
        self.persistent:process_ability_activation(event)
    end
    self:count(ability, amount)
    return amount
end
-- }}}

-- {{{ AbilityEffectSystem:cleanse
-- Removes every active effect of a kind ("buff" or "debuff") from an
-- entity. Cleansing debuffs also ends damage over time, when a
-- PersistentEffectsSystem is attached. Returns how many were removed.
function AbilityEffectSystem:cleanse(entity, kind)
    local removed = 0
    if self.persistent and kind == "debuff" then
        removed = removed + self.persistent:cleanse(entity, "damage")
    end
    local effects = self.entity_manager:get_component(entity, "effects")
    if not effects then
        return removed
    end
    for name, effect in pairs(effects.active) do
        if effect.kind == kind then
            effects.active[name] = nil
            removed = removed + 1
        end
    end
    if removed > 0 then
        self:refresh_speed(entity)
    end
    return removed
end
-- }}}

-- {{{ AbilityEffectSystem:update_effects
-- Counts effect durations down and removes the expired ones, and those
-- on dead units.
function AbilityEffectSystem:update_effects(dt)
    local em = self.entity_manager
    for _, entity in ipairs(em:get_entities_with_component("effects")) do
        local effects = em:get_component(entity, "effects")
        local alive = Unit.is_alive(em, entity)
        local changed = false
        for name, effect in pairs(effects.active) do
            if effect.remaining then
                effect.remaining = effect.remaining - dt
            end
            if not alive or (effect.remaining and effect.remaining <= 1e-9) then
                effects.active[name] = nil
                changed = true
                self.stats.effects_expired = self.stats.effects_expired + 1
                if alive then
                    local x, y = position_of(em, entity)
                    self:cue("effect_expired", {x = x, y = y, target = entity, name = name})
                end
            end
        end
        if changed then
            self:refresh_speed(entity)
        end
    end
end
-- }}}

-- {{{ AbilityEffectSystem:update
function AbilityEffectSystem:update(dt)
    self.clock = self.clock + dt
    local flying = {}
    for _, projectile in ipairs(self.projectiles) do
        if self:update_projectile(projectile, dt) then
            table.insert(flying, projectile)
        end
    end
    self.projectiles = flying
    self:update_effects(dt)
end
-- }}}

-- {{{ AbilityEffectSystem:pop_cues
function AbilityEffectSystem:pop_cues()
    local cues = self.cues
    self.cues = {}
    return cues
end
-- }}}

return AbilityEffectSystem
-- }}}
