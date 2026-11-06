-- {{{ Unit template
-- A player's design for a unit: a body (unit type), stats, one to four
-- abilities and a look, bought from a point budget. Prices come from
-- src/data/template_costs.lua.
--
--   UnitTemplate.new(data)        data: {name, description, created_by,
--                                 version, point_budget, unit_type, stats,
--                                 abilities, appearance}; anything left
--                                 out takes the body's or a default value
--   template:calculate_point_cost()  points used, with a breakdown
--   template:validate()           true, or false with validation_errors
--   template:ability_configs()    the abilities' configs, for
--                                 UnitAbilities.attach
--   template:create_unit(em, x, y, team)  a unit built to the design
--   template:to_save_data() / UnitTemplate.from_save_data(data)
--
-- An ability entry is one of:
--   "power_strike"                          a template from
--                                           src/data/ability_templates.lua
--   {template = "power_strike", changes = {power = 50}}
--   {type = "damage", power = 30, ...}      a whole ability config
-- The first ability is the primary.
local UnitTemplate = {}
UnitTemplate.__index = UnitTemplate

local TemplateCosts = require("src.data.template_costs")
local Ability = require("src.components.ability")
local AbilityFactory = require("src.factories.ability_factory")
local UnitAbilities = require("src.components.unit_abilities")
local Unit = require("src.entities.unit")

UnitTemplate.STAT_NAMES = {"health", "speed", "armor", "magic_resist", "detection_range"}

-- {{{ local function deep_copy
local function deep_copy(value)
    if type(value) ~= "table" then
        return value
    end
    local copy = {}
    for key, inner in pairs(value) do
        copy[key] = deep_copy(inner)
    end
    return copy
end
-- }}}

-- {{{ local function normalize_ability
local function normalize_ability(entry)
    if type(entry) == "string" then
        return {template = entry}
    end
    if type(entry) == "table" and entry.template then
        return {template = entry.template, changes = deep_copy(entry.changes)}
    end
    return {config = deep_copy(entry)}
end
-- }}}

-- {{{ UnitTemplate.new
function UnitTemplate.new(data)
    data = data or {}
    local stats_in = data.stats or {}
    local unit_type = data.unit_type or stats_in.unit_type or "melee"
    local body = TemplateCosts.bodies[unit_type] or {}
    local appearance = data.appearance or {}

    local template = {
        name = data.name or "Unnamed Unit",
        description = data.description or "",
        created_by = data.created_by or "Player",
        version = data.version or 1,
        point_budget = data.point_budget or TemplateCosts.default_point_budget,
        unit_type = unit_type,
        stats = {},
        abilities = {},
        appearance = {
            primary_color = deep_copy(appearance.primary_color) or {1, 0, 0},
            secondary_color = deep_copy(appearance.secondary_color) or {0.5, 0, 0},
            shape = appearance.shape or Unit.get_unit_shape(unit_type),
            size_modifier = appearance.size_modifier or 1.0
        },
        points_used = 0,
        breakdown = nil,
        is_valid = false,
        validation_errors = {}
    }
    for _, stat in ipairs(UnitTemplate.STAT_NAMES) do
        template.stats[stat] = stats_in[stat] or body[stat] or 0
    end
    for index, entry in ipairs(data.abilities or {}) do
        template.abilities[index] = normalize_ability(entry)
    end
    setmetatable(template, UnitTemplate)
    template:validate()
    return template
end
-- }}}

-- {{{ UnitTemplate:ability_config
-- The config for ability `index`, or nil and an error message.
function UnitTemplate:ability_config(index)
    local entry = self.abilities[index]
    if not entry then
        return nil, "no ability " .. tostring(index)
    end
    if entry.template then
        local ok, config = pcall(AbilityFactory.create_config, entry.template, entry.changes)
        if not ok then
            return nil, "unknown ability template " .. tostring(entry.template)
        end
        return config
    end
    if type(entry.config) ~= "table" then
        return nil, "not an ability"
    end
    return deep_copy(entry.config)
end
-- }}}

-- {{{ UnitTemplate:ability_configs
function UnitTemplate:ability_configs()
    local configs = {}
    for index = 1, #self.abilities do
        local config, problem = self:ability_config(index)
        if not config then
            error("Ability " .. index .. ": " .. problem)
        end
        configs[index] = config
    end
    return configs
end
-- }}}

-- {{{ UnitTemplate.round_up
-- Whole points, rounding any part up, never below zero (and never "-0").
function UnitTemplate.round_up(points)
    if points <= 1e-9 then
        return 0
    end
    return math.ceil(points - 1e-9)
end
-- }}}

-- {{{ UnitTemplate.ability_cost
-- Points for one built ability. Its strength is how much it does per
-- second at a steady charge next to a reference ability (see
-- TemplateCosts.abilities): damage and healing by amount, counting
-- critical hits, accuracy, cleave, pierce, extra targets, effects over
-- time and zones; buffs and debuffs by how much of the time they're up.
-- A cooldown longer than the bar's fill time slows the rate.
function UnitTemplate.ability_cost(ability, is_primary)
    local costs = TemplateCosts.abilities
    local base = is_primary and costs.primary_base or costs.secondary_base
    local casts_per_second = ability.mana_rate / ability.max_mana
    if ability.cooldown > 0 then
        casts_per_second = math.min(casts_per_second, 1 / ability.cooldown)
    end

    local strength
    if ability.type == "buff" or ability.type == "debuff" then
        local uptime = ability.duration * casts_per_second
        strength = uptime / costs.reference_uptime
        if ability.stun then
            strength = strength * 1.5
        end
        strength = strength * (1 + ((ability.max_targets or 1) - 1) * 0.5)
    else
        local per_cast = ability.power
        local over_time = ability.damage_over_time > 0 and ability.damage_over_time or ability.heal_over_time
        if over_time > 0 and ability.over_time_duration then
            per_cast = per_cast + over_time * ability.over_time_duration / (ability.over_time_interval or 1)
        end
        if (ability.zone_duration or 0) > 0 then
            per_cast = per_cast + ability.zone_power * ability.zone_duration / ability.zone_interval * costs.zone_share
        end
        per_cast = per_cast * (1 + (ability.critical_chance or 0) * ((ability.critical_multiplier or 2) - 1))
        per_cast = per_cast * (ability.accuracy or 1)

        local targets = 1
        if ability.type == "area" then
            targets = 1 + (math.min(ability.max_targets, 6) - 1) * 0.5
        else
            targets = 1 + (ability.cleave_targets or 0) * (ability.cleave_ratio or 0)
                + (ability.pierce - 1) * costs.pierce_share
        end
        strength = per_cast * casts_per_second * targets / costs.reference_throughput
    end

    local extras = math.max(0, ability.range - costs.reach_base) * costs.per_reach
    if ability.type == "area" then
        extras = extras + ability.area_radius * costs.per_area_radius
    end
    return UnitTemplate.round_up(base * strength + extras)
end
-- }}}

-- {{{ UnitTemplate:calculate_point_cost
-- Sets and returns points_used. self.breakdown says where they went:
-- {body, stats = {stat -> points}, abilities = {index -> points}}.
-- Abilities that can't be built cost nothing here; validate() reports
-- them.
function UnitTemplate:calculate_point_cost()
    local body = TemplateCosts.bodies[self.unit_type] or {cost = 0}
    local breakdown = {body = body.cost or 0, stats = {}, abilities = {}}
    local total = breakdown.body
    for _, stat in ipairs(UnitTemplate.STAT_NAMES) do
        local price = TemplateCosts.stats[stat]
        local above = math.max(0, (self.stats[stat] or 0) - (body[stat] or 0))
        local points = UnitTemplate.round_up(above * price.per_unit)
        breakdown.stats[stat] = points
        total = total + points
    end
    for index = 1, #self.abilities do
        local config = self:ability_config(index)
        local points = 0
        if config then
            local ok, ability = pcall(Ability.new, config)
            if ok then
                points = UnitTemplate.ability_cost(ability, index == 1)
            end
        end
        breakdown.abilities[index] = points
        total = total + points
    end
    self.points_used = total
    self.breakdown = breakdown
    return total
end
-- }}}

-- {{{ UnitTemplate:validate
function UnitTemplate:validate()
    local errors = {}
    if type(self.name) ~= "string" or self.name == "" then
        table.insert(errors, "Must have a name")
    end
    if not TemplateCosts.bodies[self.unit_type] then
        table.insert(errors, "Unknown unit type: " .. tostring(self.unit_type))
    end
    for _, stat in ipairs(UnitTemplate.STAT_NAMES) do
        local value = self.stats[stat]
        local limits = TemplateCosts.stats[stat]
        if type(value) ~= "number" then
            table.insert(errors, stat .. " must be a number")
        elseif value < limits.min or value > limits.max then
            table.insert(errors, string.format("%s must be %g-%g, not %g", stat, limits.min, limits.max, value))
        end
    end

    local limits = TemplateCosts.abilities
    if #self.abilities < limits.min_abilities then
        table.insert(errors, "Must have at least " .. limits.min_abilities .. " ability")
    elseif #self.abilities > limits.max_abilities then
        table.insert(errors, "Cannot have more than " .. limits.max_abilities .. " abilities")
    end
    for index = 1, #self.abilities do
        local config, problem = self:ability_config(index)
        if not config then
            table.insert(errors, string.format("Ability %d: %s", index, problem))
        else
            local ok, built = pcall(Ability.new, config)
            if not ok then
                table.insert(errors, string.format("Ability %d: %s", index, tostring(built):gsub("^.-:%d+: ", "")))
            elseif index == 1 and built.type ~= "damage" and built.type ~= "heal" then
                table.insert(errors, "Ability 1 (the primary) must deal damage or heal")
            end
        end
    end

    if self:calculate_point_cost() > self.point_budget then
        table.insert(errors, string.format("Exceeds point budget: %d/%d", self.points_used, self.point_budget))
    end

    self.validation_errors = errors
    self.is_valid = #errors == 0
    return self.is_valid, errors
end
-- }}}

-- {{{ UnitTemplate:points_left
function UnitTemplate:points_left()
    return self.point_budget - self.points_used
end
-- }}}

-- {{{ UnitTemplate:create_unit
-- A unit built to this design: the body's shape and size (times
-- size_modifier), the template's health, speed, armor and magic resist,
-- its abilities with their mana bars, and its name on the unit's data.
-- Errors on a template that isn't valid.
function UnitTemplate:create_unit(entity_manager, x, y, team)
    if not self:validate() then
        error("Template " .. tostring(self.name) .. " isn't valid: " .. table.concat(self.validation_errors, "; "))
    end
    local em = entity_manager
    local unit = Unit.create_basic_unit(em, x, y, team, self.unit_type)
    local health = em:get_component(unit, "health")
    health.max_hp = self.stats.health
    health.current_hp = self.stats.health
    health.maximum = self.stats.health
    local moveable = em:get_component(unit, "moveable")
    moveable.speed = self.stats.speed
    moveable.max_speed = self.stats.speed * 1.5
    em:add_component(unit, "stats", {armor = self.stats.armor, magic_resist = self.stats.magic_resist})
    local unit_data = em:get_component(unit, "unit_data")
    unit_data.template_name = self.name
    unit_data.detection_range = self.stats.detection_range
    local renderable = em:get_component(unit, "renderable")
    if renderable then
        renderable.shape = self.appearance.shape
        if renderable.size then
            renderable.size = renderable.size * self.appearance.size_modifier
        end
    end
    UnitAbilities.attach(em, unit, self:ability_configs())
    return unit
end
-- }}}

-- {{{ UnitTemplate:to_save_data
-- Plain tables only, ready to be written out (issue 060).
function UnitTemplate:to_save_data()
    local abilities = {}
    for index, entry in ipairs(self.abilities) do
        if entry.template then
            abilities[index] = entry.changes and {template = entry.template, changes = deep_copy(entry.changes)}
                or entry.template
        else
            abilities[index] = deep_copy(entry.config)
        end
    end
    return {
        name = self.name,
        description = self.description,
        created_by = self.created_by,
        version = self.version,
        point_budget = self.point_budget,
        unit_type = self.unit_type,
        stats = deep_copy(self.stats),
        abilities = abilities,
        appearance = deep_copy(self.appearance)
    }
end
-- }}}

-- {{{ UnitTemplate.from_save_data
function UnitTemplate.from_save_data(data)
    return UnitTemplate.new(data)
end
-- }}}

-- {{{ UnitTemplate.is_template
function UnitTemplate.is_template(value)
    return getmetatable(value) == UnitTemplate
end
-- }}}

return UnitTemplate
-- }}}
