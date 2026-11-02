-- {{{ Ability component
-- One ability a unit can use. An ability is a table of settings with
-- methods; a unit keeps up to four of them in its "abilities" component
-- (src/components/unit_abilities.lua), one for each of its mana bars.
-- Ability number i spends mana bar number i.
--
-- The mana itself lives in the mana bars (src/components/mana.lua), not
-- here, so ManaSystem keeps charging the bars and ManaEfficiency keeps
-- pricing casts. An ability carries the fields ManaEfficiency reads:
--   type         "damage", "heal", "buff", "debuff" or "area"
--   power        the effect at a full bar
--   max_mana     the size of its bar
--   area_effect  for "area": "damage" or "heal"
--   max_targets  how many targets it is meant for
--
-- Ability.new(config) picks the specialized kind for config.type from
-- src/components/abilities/ (damage, heal, buff, debuff, area), each of
-- which inherits from this base and adds how its effect is worked out.
-- Ability.extend(type, defaults) makes a new kind.
local Ability = {}
Ability.__index = Ability

Ability.TYPES = {"damage", "heal", "buff", "debuff", "area"}
Ability.CATEGORIES = {active = true, passive = true, triggered = true}
Ability.TARGETING = {enemy = true, ally = true, self = true, ground = true, area = true}

-- Who an ability aims at when its config doesn't say.
Ability.DEFAULT_TARGETING = {
    damage = "enemy",
    heal = "ally",
    buff = "ally",
    debuff = "enemy",
    area = "area"
}

-- The kinds by type, filled in by Ability.extend.
Ability.KINDS = {}

local next_id = 0
local FULL_EPSILON = 1e-9

-- {{{ local function pick
-- The first value that isn't nil, so a config can say false.
local function pick(...)
    for i = 1, select("#", ...) do
        local value = select(i, ...)
        if value ~= nil then
            return value
        end
    end
    return nil
end
-- }}}

-- {{{ Ability.base
-- Builds the plain settings every kind shares. Kinds call this and then
-- add their own fields; nothing outside a kind needs it.
function Ability.base(config)
    config = config or {}
    local kind = config.type or "damage"
    next_id = next_id + 1

    local ability = {
        id = config.id or next_id,
        name = config.name or (kind .. "_ability"),
        type = kind,
        category = config.category or "active",

        -- Mana: the size and charge rate of this ability's bar.
        max_mana = pick(config.max_mana, config.max_mana_cost, 100),
        mana_rate = pick(config.mana_rate, config.mana_generation_rate, 10),

        -- Targeting
        targeting = config.targeting or config.targeting_type or Ability.DEFAULT_TARGETING[kind] or "enemy",
        range = config.range or 50,
        area_radius = pick(config.area_radius, config.area_of_effect, 0),
        max_targets = config.max_targets or (kind == "area" and 5 or 1),
        line_of_sight = pick(config.line_of_sight, config.line_of_sight_required, true),
        target_priority = config.target_priority,     -- read by the targeting system
        exclude_self = config.exclude_self or false,  -- ally targeting leaves the caster out

        -- Effect
        power = pick(config.power, config.base_power, 50),
        scaling = config.scaling or config.scaling_factor or 1.0,
        duration = pick(config.duration, config.effect_duration, 0),     -- 0 = instant
        cooldown = pick(config.cooldown, config.cooldown_duration, 0),
        priority = config.priority,                   -- lower goes first; default its slot
        area_effect = config.area_effect,

        -- Conditions: lists of {type, operator, value[, range]}
        generation_conditions = config.generation_conditions or {},
        activation_conditions = config.activation_conditions or {},

        -- Anything a kind or a later system wants to carry along.
        custom = config.custom or {},

        stats = {
            activations = 0,
            failures = 0,
            failure_reasons = {},
            total_effect = 0,
            mana_spent = 0
        }
    }

    if ability.max_mana <= 0 then
        error("Ability " .. ability.name .. " needs a positive max_mana")
    end
    if not Ability.CATEGORIES[ability.category] then
        error("Ability " .. ability.name .. " has unknown category " .. tostring(ability.category))
    end
    if not Ability.TARGETING[ability.targeting] then
        error("Ability " .. ability.name .. " has unknown targeting " .. tostring(ability.targeting))
    end
    return ability
end
-- }}}

-- {{{ Ability.extend
-- Makes a kind of ability: a class that inherits every method here.
-- `fields` is a function(ability, config) that adds the kind's own
-- settings; the kind can then override methods such as
-- calculate_effect.
function Ability.extend(kind, fields)
    local class = {}
    class.__index = class
    class.kind = kind
    setmetatable(class, {__index = Ability})

    -- {{{ class.new
    function class.new(config)
        config = config or {}
        local copy = {}
        for key, value in pairs(config) do
            copy[key] = value
        end
        copy.type = kind
        local ability = Ability.base(copy)
        if fields then
            fields(ability, copy)
        end
        return setmetatable(ability, class)
    end
    -- }}}

    Ability.KINDS[kind] = class
    return class
end
-- }}}

-- {{{ Ability.new
-- Makes an ability of config.type, from its specialized kind.
function Ability.new(config)
    config = config or {}
    local kind = config.type or "damage"
    -- Loading the kinds here, not at the top, keeps the requires one-way:
    -- each kind file requires this one.
    if not Ability.KINDS[kind] then
        local ok = pcall(require, "src.components.abilities." .. kind .. "_ability")
        if not ok or not Ability.KINDS[kind] then
            error("Unknown ability type: " .. tostring(kind))
        end
    end
    return Ability.KINDS[kind].new(config)
end
-- }}}

-- {{{ Ability.is_ability
function Ability.is_ability(value)
    local meta = getmetatable(value)
    while meta do
        if meta == Ability then
            return true
        end
        local parent = getmetatable(meta)
        meta = parent and parent.__index
    end
    return false
end
-- }}}

-- {{{ Ability.compare
-- Compares two values with an operator written as a symbol or a word.
function Ability.compare(actual, operator, expected)
    if actual == nil then
        return false
    end
    if operator == nil or operator == "==" or operator == "equals" then
        return actual == expected
    elseif operator == "~=" or operator == "!=" or operator == "not_equals" then
        return actual ~= expected
    elseif operator == ">" or operator == "greater_than" then
        return actual > expected
    elseif operator == ">=" or operator == "greater_equal" then
        return actual >= expected
    elseif operator == "<" or operator == "less_than" then
        return actual < expected
    elseif operator == "<=" or operator == "less_equal" then
        return actual <= expected
    end
    error("Unknown comparison operator: " .. tostring(operator))
end
-- }}}

-- {{{ Ability:check_condition
-- One condition against a unit's state. The state is what
-- UnitAbilities.unit_state builds:
--   unit_type, health_fraction, moving, still_time, combat_state,
--   active_effects (name -> effect), and enemies_within(range) and
--   allies_within(range), which count living units in range.
-- Condition types:
--   unit_type          value is a unit type
--   health_percentage  value is 0-100, compared with operator
--   enemies_in_range   count within condition.range (default the
--                      ability's range), compared with operator
--   allies_in_range    the same for allies (not counting the unit)
--   is_stationary      value true or false
--   combat_state       value is a combat state
--   has_effect         value is an effect name the unit carries
--   missing_effect     value is an effect name the unit lacks
--   custom             condition.check(state, ability) returns a boolean
function Ability:check_condition(condition, state)
    local kind = condition.type
    if kind == "unit_type" then
        return state.unit_type == condition.value
    elseif kind == "health_percentage" then
        return Ability.compare((state.health_fraction or 1) * 100, condition.operator, condition.value)
    elseif kind == "enemies_in_range" or kind == "allies_in_range" then
        local range = condition.range or self.range
        local counter = kind == "enemies_in_range" and state.enemies_within or state.allies_within
        local count = counter and counter(range) or 0
        return Ability.compare(count, condition.operator or ">=", condition.value or 1)
    elseif kind == "is_stationary" then
        return (not state.moving) == (condition.value ~= false)
    elseif kind == "combat_state" then
        return state.combat_state == condition.value
    elseif kind == "has_effect" or kind == "has_buff" then
        return state.active_effects ~= nil and state.active_effects[condition.value] ~= nil
    elseif kind == "missing_effect" or kind == "missing_buff" then
        return not (state.active_effects and state.active_effects[condition.value])
    elseif kind == "custom" then
        return condition.check(state, self) and true or false
    end
    return self:check_custom_condition(condition, state)
end
-- }}}

-- {{{ Ability:check_custom_condition
-- Kinds can override this for condition types of their own. Unknown
-- types fail, so a typo never lets an ability fire by accident.
function Ability:check_custom_condition(condition, state)
    return false
end
-- }}}

-- {{{ Ability:conditions_met
-- Whether every condition in the list holds. Returns false and the first
-- condition that failed.
function Ability:conditions_met(conditions, state)
    for _, condition in ipairs(conditions or {}) do
        if not self:check_condition(condition, state) then
            return false, condition
        end
    end
    return true
end
-- }}}

-- {{{ Ability:can_generate_mana
-- Whether this ability's bar may charge now. ManaSystem asks this on top
-- of its own rules for primary and secondary bars.
function Ability:can_generate_mana(state)
    if #self.generation_conditions == 0 then
        return true
    end
    return (self:conditions_met(self.generation_conditions, state))
end
-- }}}

-- {{{ Ability:can_activate
-- Whether the ability may fire now: its bar is full, it isn't cooling
-- down, it's active (passive abilities never fire on their own), and its
-- activation conditions hold. Returns true, or false and a reason.
function Ability:can_activate(bar, state, cooldown_remaining)
    if self.category == "passive" then
        return false, "passive"
    end
    if not bar or bar.current < bar.max - FULL_EPSILON then
        return false, "mana_not_full"
    end
    if (cooldown_remaining or 0) > 0 then
        return false, "on_cooldown"
    end
    local ok, failed = self:conditions_met(self.activation_conditions, state or {})
    if not ok then
        return false, "condition_failed:" .. tostring(failed.type)
    end
    return true
end
-- }}}

-- {{{ Ability:calculate_effect
-- What the ability does to one target when it spends `share` of its bar
-- (from ManaEfficiency's plan: effect_power). Kinds override this; the
-- base just scales power. `context` may carry caster_stats, target_stats,
-- and random (a function returning 0-1, for critical hits).
function Ability:calculate_effect(target, share, context)
    return {amount = self.power * self.scaling * (share or 1)}
end
-- }}}

-- {{{ Ability:record
-- Keeps the ability's own counts for balancing and debugging.
function Ability:record(succeeded, detail)
    local stats = self.stats
    if succeeded then
        stats.activations = stats.activations + 1
        stats.total_effect = stats.total_effect + ((detail and detail.amount) or 0)
        stats.mana_spent = stats.mana_spent + ((detail and detail.mana) or 0)
    else
        stats.failures = stats.failures + 1
        local reason = detail or "unknown"
        stats.failure_reasons[reason] = (stats.failure_reasons[reason] or 0) + 1
    end
end
-- }}}

-- {{{ Ability:get_debug_info
function Ability:get_debug_info(bar)
    return {
        id = self.id,
        name = self.name,
        type = self.type,
        category = self.category,
        targeting = self.targeting,
        range = self.range,
        power = self.power,
        mana = bar and string.format("%.1f/%.1f", bar.current, bar.max) or nil,
        mana_fraction = bar and bar.current / bar.max or nil,
        activations = self.stats.activations,
        failures = self.stats.failures
    }
end
-- }}}

return Ability
-- }}}
