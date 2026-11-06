-- {{{ Ability activation system
-- Fires abilities when their mana bars are full, as the vision says:
-- "when the bar reaches the max, the unit will use the ability".
--
-- Each update, for every living unit with an "abilities" component:
--   1. its cooldowns count down;
--   2. if it can act (not stunned, silenced or retreating), the abilities
--      whose bars are full, that aren't cooling down, and whose
--      activation conditions hold are tried in priority order (the
--      primary first unless an ability says otherwise);
--   3. an ability looks for targets (TargetingSystem) and prices the cast
--      (ManaEfficiency). If both succeed, the planned mana is spent, its
--      cooldown and the unit's global cooldown start, and an activation
--      event goes to the effect handler. If not, the reason is recorded
--      and the bar stays full, so it tries again next update.
-- A unit fires at most abilities_per_update abilities in one update
-- (default 1), and the global cooldown spaces the rest out. A full bar
-- that has to wait is how abilities queue.
--
-- The activation event is:
--   {caster, ability, index, targets, center, plan, mana_spent, time}
-- where plan is ManaEfficiency's plan (plan.effect_power is the share of
-- full strength). Events go to options.on_activate(event), or to
-- options.effect_system:process_ability_activation(event), and are also
-- kept for pop_events().
local AbilityActivationSystem = {}
AbilityActivationSystem.__index = AbilityActivationSystem

local UnitAbilities = require("src.components.unit_abilities")
local ManaSystem = require("src.systems.mana_system")
local ManaEfficiency = require("src.systems.mana_efficiency")
local TargetingSystem = require("src.systems.targeting_system")

AbilityActivationSystem.GLOBAL_COOLDOWN = 0.25
AbilityActivationSystem.ABILITIES_PER_UPDATE = 1

-- Combat states in which a unit uses no abilities.
AbilityActivationSystem.BLOCKING_STATES = {retreating = true, fleeing = true}

-- {{{ AbilityActivationSystem:new
-- options:
--   targeting             a TargetingSystem (one is made if not given)
--   on_activate(event)    called for each activation
--   effect_system         or an object with process_ability_activation
--   global_cooldown       seconds between a unit's abilities (default 0.25)
--   abilities_per_update  most abilities one unit fires per update
--   check_interval        seconds between activation checks (default 0:
--                         every update); cooldowns still count every update
function AbilityActivationSystem:new(entity_manager, options)
    options = options or {}
    local system = {
        name = "ability_activation",
        enabled = true,
        entity_manager = entity_manager,
        targeting = options.targeting or TargetingSystem:new(entity_manager),
        on_activate = options.on_activate,
        effect_system = options.effect_system,
        global_cooldown = options.global_cooldown or AbilityActivationSystem.GLOBAL_COOLDOWN,
        abilities_per_update = options.abilities_per_update or AbilityActivationSystem.ABILITIES_PER_UPDATE,
        check_interval = options.check_interval or 0,
        since_check = 0,
        clock = 0,
        events = {},
        mana_stats = ManaEfficiency.new_stats(),
        stats = {
            activations = 0,
            failures = 0,
            failure_reasons = {},     -- reason -> count
            by_ability = {}           -- ability name -> activations
        }
    }
    setmetatable(system, self)
    return system
end
-- }}}

-- {{{ AbilityActivationSystem:is_enabled
-- So a SystemManager can run it.
function AbilityActivationSystem:is_enabled()
    return self.enabled
end
-- }}}

-- {{{ AbilityActivationSystem:can_act
-- Whether a unit may use abilities at all now. Returns true, or false and
-- a reason.
function AbilityActivationSystem:can_act(entity, state)
    if not state.alive then
        return false, "dead"
    end
    local unit_data = self.entity_manager:get_component(entity, "unit_data")
    if unit_data and (unit_data.is_stunned or unit_data.is_disabled) then
        return false, "stunned"
    end
    if unit_data and unit_data.is_silenced then
        return false, "silenced"
    end
    for _, effect in pairs(state.active_effects or {}) do
        if effect.stun then
            return false, "stunned"
        end
        if effect.silence then
            return false, "silenced"
        end
    end
    if AbilityActivationSystem.BLOCKING_STATES[state.combat_state] then
        return false, state.combat_state
    end
    return true
end
-- }}}

-- {{{ AbilityActivationSystem:record_failure
-- Counts a failure once each time an ability's reason changes, so a full
-- bar that waits several seconds for a target counts once, not once a
-- frame. container.last_failure keeps each ability's latest reason.
function AbilityActivationSystem:record_failure(container, index, ability, reason)
    container.last_failure = container.last_failure or {}
    if container.last_failure[index] == reason then
        return
    end
    container.last_failure[index] = reason
    self.stats.failures = self.stats.failures + 1
    self.stats.failure_reasons[reason] = (self.stats.failure_reasons[reason] or 0) + 1
    ability:record(false, reason)
end
-- }}}

-- {{{ AbilityActivationSystem:attempt
-- Tries one ready ability. Returns the event, or nil and a reason.
function AbilityActivationSystem:attempt(entity, container, mana, index, ability)
    local bar = mana.bars[index]
    local targets, info = self.targeting:find_targets(entity, ability)
    if #targets == 0 then
        return nil, info.reason or "no_targets"
    end

    local plan = ManaEfficiency.plan(ability, targets, bar.current)
    if not plan.can_execute then
        return nil, plan.reason or "refused"
    end

    ManaSystem.spend(mana, index, plan.mana_to_use)
    ManaEfficiency.record(self.mana_stats, ability, plan)
    container.cooldowns[index] = ability.cooldown or 0
    container.global_cooldown = self.global_cooldown
    container.last_used = index
    container.last_target = (info.center and ability.targeting ~= "self") and info.center or targets[1].entity
    if container.last_failure then
        container.last_failure[index] = nil
    end

    local event = {
        caster = entity,
        ability = ability,
        index = index,
        targets = targets,
        center = info.center,
        plan = plan,
        mana_spent = plan.mana_to_use,
        time = self.clock
    }
    ability:record(true, {amount = plan.amount, mana = plan.mana_to_use})
    self.stats.activations = self.stats.activations + 1
    self.stats.by_ability[ability.name] = (self.stats.by_ability[ability.name] or 0) + 1
    return event
end
-- }}}

-- {{{ AbilityActivationSystem:dispatch
function AbilityActivationSystem:dispatch(event)
    table.insert(self.events, event)
    if self.on_activate then
        self.on_activate(event)
    elseif self.effect_system and self.effect_system.process_ability_activation then
        self.effect_system:process_ability_activation(event)
    end
end
-- }}}

-- {{{ AbilityActivationSystem:update_unit
-- Returns how many abilities the unit fired.
function AbilityActivationSystem:update_unit(entity, container, mana, snapshot)
    local state = UnitAbilities.unit_state(self.entity_manager, entity, snapshot)
    local ok, reason = self:can_act(entity, state)
    if not ok then
        container.blocked_reason = reason
        return 0
    end
    container.blocked_reason = nil

    local ready, blocked = UnitAbilities.get_ready(container, mana, state)
    for index, why in pairs(blocked) do
        -- Waiting for mana or a cooldown is normal, not a failure.
        if why:sub(1, 17) == "condition_failed:" then
            self:record_failure(container, index, container.abilities[index], why)
        end
    end

    local fired = 0
    for _, entry in ipairs(ready) do
        if fired >= self.abilities_per_update or container.global_cooldown > 0 then
            break
        end
        local event, why = self:attempt(entity, container, mana, entry.index, entry.ability)
        if event then
            fired = fired + 1
            self:dispatch(event)
        else
            self:record_failure(container, entry.index, entry.ability, why)
        end
    end
    return fired
end
-- }}}

-- {{{ AbilityActivationSystem:update
function AbilityActivationSystem:update(dt)
    local em = self.entity_manager
    self.clock = self.clock + dt
    self.targeting:update(dt)

    local units = em:get_entities_with_components({"abilities", "mana"})
    for _, entity in ipairs(units) do
        UnitAbilities.update_cooldowns(em:get_component(entity, "abilities"), dt)
    end

    self.since_check = self.since_check + dt
    if self.since_check < self.check_interval - 1e-9 then
        return
    end
    self.since_check = 0

    local snapshot = self.targeting:snapshot().units
    for _, entity in ipairs(units) do
        self:update_unit(entity, em:get_component(entity, "abilities"), em:get_component(entity, "mana"), snapshot)
    end
end
-- }}}

-- {{{ AbilityActivationSystem:pop_events
function AbilityActivationSystem:pop_events()
    local events = self.events
    self.events = {}
    return events
end
-- }}}

-- {{{ AbilityActivationSystem:get_debug_info
function AbilityActivationSystem:get_debug_info()
    return {
        activations = self.stats.activations,
        failures = self.stats.failures,
        failure_reasons = self.stats.failure_reasons,
        by_ability = self.stats.by_ability,
        mana_spent = self.mana_stats.mana_spent,
        mana_saved = self.mana_stats.mana_saved
    }
end
-- }}}

return AbilityActivationSystem
-- }}}
