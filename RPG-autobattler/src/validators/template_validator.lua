-- {{{ Template validator
-- Judges a unit template (src/data/unit_template.lua) against the rules
-- in src/data/template_constraints.lua. Critical rules make errors: the
-- template can't be used. The others make warnings: legal, but likely a
-- mistake. Every message names what's wrong, the number found, the limit
-- and what to change.
--
--   TemplateValidator:new(constraints)   constraints default to the file
--   validator:validate_template(template)
--       returns ok, errors, warnings (lists of strings)
--   validator:validate_detailed(template)
--       returns ok and a list of {rule, critical, message}
--
-- A rule is {name, critical, check}; check(validator, template, add)
-- calls add(message) once per problem. Rules can be added with
-- add_rule, so a game mode can bring its own.
local TemplateValidator = {}
TemplateValidator.__index = TemplateValidator

local Ability = require("src.components.ability")

-- {{{ local function sorted_keys
local function sorted_keys(map)
    local keys = {}
    for key in pairs(map) do
        table.insert(keys, key)
    end
    table.sort(keys)
    return keys
end
-- }}}

-- {{{ local function ability_label
local function ability_label(template, index, ability)
    local entry = template.abilities[index]
    local name = (ability and ability.name) or (entry and entry.template) or "?"
    return string.format("Ability %d (%s)", index, name)
end
-- }}}

-- {{{ TemplateValidator:new
function TemplateValidator:new(constraints)
    local validator = {
        constraints = constraints or require("src.data.template_constraints"),
        rules = {}
    }
    setmetatable(validator, self)
    validator:add_rule("name", true, TemplateValidator.check_name)
    validator:add_rule("unit_type", true, TemplateValidator.check_unit_type)
    validator:add_rule("stat_ranges", true, TemplateValidator.check_stat_ranges)
    validator:add_rule("ability_count", true, TemplateValidator.check_ability_count)
    validator:add_rule("abilities", true, TemplateValidator.check_abilities)
    validator:add_rule("point_budget", true, TemplateValidator.check_point_budget)
    validator:add_rule("recommended_stats", false, TemplateValidator.check_recommended_stats)
    validator:add_rule("ability_mix", false, TemplateValidator.check_ability_mix)
    validator:add_rule("type_coherence", false, TemplateValidator.check_type_coherence)
    validator:add_rule("budget_use", false, TemplateValidator.check_budget_use)
    return validator
end
-- }}}

-- {{{ TemplateValidator:add_rule
function TemplateValidator:add_rule(name, critical, check)
    table.insert(self.rules, {name = name, critical = critical, check = check})
end
-- }}}

-- {{{ TemplateValidator:built_abilities
-- Each ability built once per validation: {index -> ability} and
-- {index -> problem} for those that can't be built.
function TemplateValidator:built_abilities(template)
    local built, problems = {}, {}
    for index = 1, #template.abilities do
        local config, problem = template:ability_config(index)
        if not config then
            problems[index] = problem
        else
            local ok, ability = pcall(Ability.new, config)
            if ok then
                built[index] = ability
            else
                problems[index] = tostring(ability):gsub("^.-:%d+: ", "")
            end
        end
    end
    return built, problems
end
-- }}}

-- {{{ TemplateValidator:validate_detailed
function TemplateValidator:validate_detailed(template)
    local findings = {}
    local ok = true
    self.built, self.build_problems = self:built_abilities(template)
    for _, rule in ipairs(self.rules) do
        local function add(message)
            table.insert(findings, {rule = rule.name, critical = rule.critical, message = message})
            if rule.critical then
                ok = false
            end
        end
        rule.check(self, template, add)
    end
    self.built, self.build_problems = nil, nil
    return ok, findings
end
-- }}}

-- {{{ TemplateValidator:validate_template
function TemplateValidator:validate_template(template)
    local ok, findings = self:validate_detailed(template)
    local errors, warnings = {}, {}
    for _, finding in ipairs(findings) do
        table.insert(finding.critical and errors or warnings, finding.message)
    end
    return ok, errors, warnings
end
-- }}}

-- {{{ TemplateValidator.check_name
function TemplateValidator.check_name(self, template, add)
    local rules = self.constraints.name
    local name = template.name
    if type(name) ~= "string" or name:match("^%s*$") then
        add("Template must have a name")
        return
    end
    if #name < rules.min_length then
        add(string.format("Name \"%s\" is too short (%d characters); use at least %d", name, #name, rules.min_length))
    elseif #name > rules.max_length then
        add(string.format("Name is too long (%d characters); use at most %d", #name, rules.max_length))
    end
    local bad = name:match(rules.disallowed_pattern)
    if bad then
        add(string.format("Name contains \"%s\"; use only letters, digits, spaces, hyphens, underscores and apostrophes", bad))
    end
    if type(template.description) == "string" and #template.description > rules.max_description_length then
        add(string.format("Description is too long (%d characters); use at most %d", #template.description,
            rules.max_description_length))
    end
end
-- }}}

-- {{{ TemplateValidator.check_unit_type
function TemplateValidator.check_unit_type(self, template, add)
    local TemplateCosts = require("src.data.template_costs")
    if not TemplateCosts.bodies[template.unit_type] then
        add(string.format("Unknown unit type \"%s\"; choose one of %s", tostring(template.unit_type),
            table.concat(sorted_keys(TemplateCosts.bodies), ", ")))
    end
end
-- }}}

-- {{{ TemplateValidator.check_stat_ranges
function TemplateValidator.check_stat_ranges(self, template, add)
    for _, stat in ipairs(sorted_keys(self.constraints.stats)) do
        local limits = self.constraints.stats[stat]
        local value = template.stats[stat]
        if type(value) ~= "number" or value ~= value then
            add(string.format("%s must be a number", stat))
        elseif value < limits.min then
            add(string.format("%s %g is below the minimum of %g; raise it", stat, value, limits.min))
        elseif value > limits.max then
            add(string.format("%s %g is above the maximum of %g; lower it", stat, value, limits.max))
        end
    end
end
-- }}}

-- {{{ TemplateValidator.check_ability_count
function TemplateValidator.check_ability_count(self, template, add)
    local rules = self.constraints.abilities
    local count = #template.abilities
    if count < rules.min_count then
        add(string.format("Needs at least %d ability; add a primary attack or heal", rules.min_count))
    elseif count > rules.max_count then
        add(string.format("Has %d abilities; remove %d to get to the limit of %d", count, count - rules.max_count,
            rules.max_count))
    end
end
-- }}}

-- {{{ local function check_limit
local function check_limit(add, label, field, value, limit, low)
    if value == nil then
        return
    end
    if low ~= nil and value < low then
        add(string.format("%s: %s %g is below %g; raise it", label, field, value, low))
    elseif limit ~= nil and value > limit then
        add(string.format("%s: %s %g is over the limit of %g; lower it", label, field, value, limit))
    end
end
-- }}}

-- {{{ TemplateValidator.check_abilities
-- Each ability must build, keep within the limits, and make sense for
-- its kind; the first must be a damage or heal ability.
function TemplateValidator.check_abilities(self, template, add)
    local rules = self.constraints.abilities
    for index = 1, #template.abilities do
        local ability = self.built[index]
        local label = ability_label(template, index, ability)
        if not ability then
            add(string.format("%s can't be built: %s", label, tostring(self.build_problems[index])))
        else
            if index == 1 and not rules.primary_types[ability.type] then
                add(string.format("%s is a %s ability; the first ability is the primary and must deal damage or heal",
                    label, ability.type))
            end
            check_limit(add, label, "power", ability.power, rules.max_power, 0)
            check_limit(add, label, "range", ability.range, rules.max_range, 1)
            check_limit(add, label, "cooldown", ability.cooldown, rules.max_cooldown, 0)
            check_limit(add, label, "mana_rate", ability.mana_rate, rules.max_mana_rate, rules.min_mana_rate)
            check_limit(add, label, "pierce", ability.pierce, rules.max_pierce, 1)
            check_limit(add, label, "cleave_targets", ability.cleave_targets, rules.max_cleave_targets, 0)
            check_limit(add, label, "over_time_duration", ability.over_time_duration, rules.max_over_time_duration, 0)
            if ability.type == "area" then
                check_limit(add, label, "area_radius", ability.area_radius, rules.max_area_radius, 1)
                check_limit(add, label, "zone_duration", ability.zone_duration, rules.max_zone_duration, 0)
            end
            if ability.type == "buff" or ability.type == "debuff" then
                -- The buff and debuff kinds give a duration of 0 or less
                -- their 5-second default, so only the top is checked.
                check_limit(add, label, "duration", ability.duration, rules.max_duration)
            elseif ability.type == "damage" or ability.type == "heal" then
                local over_time = ability.type == "damage" and ability.damage_over_time or ability.heal_over_time
                if ability.power <= 0 and (over_time or 0) <= 0 then
                    add(string.format("%s: a %s ability needs power above 0", label, ability.type))
                end
            elseif ability.type == "area" then
                if ability.power <= 0 and (ability.zone_power or 0) <= 0 and not ability.zone_modifiers then
                    add(string.format("%s: an area ability needs power, a zone or a zone effect", label))
                end
            end
        end
    end
end
-- }}}

-- {{{ TemplateValidator.check_point_budget
function TemplateValidator.check_point_budget(self, template, add)
    local used = template:calculate_point_cost()
    if used > template.point_budget then
        add(string.format("Uses %d points of a %d budget; remove %d points of stats or abilities", used,
            template.point_budget, used - template.point_budget))
    end
end
-- }}}

-- {{{ TemplateValidator.check_recommended_stats
function TemplateValidator.check_recommended_stats(self, template, add)
    for _, stat in ipairs(sorted_keys(self.constraints.stats)) do
        local limits = self.constraints.stats[stat]
        local value = template.stats[stat]
        if type(value) == "number" and value >= limits.min and value <= limits.max then
            if value < limits.recommended_min then
                add(string.format("%s %g is very low (usual range %g-%g)", stat, value, limits.recommended_min,
                    limits.recommended_max))
            elseif value > limits.recommended_max then
                add(string.format("%s %g is very high (usual range %g-%g)", stat, value, limits.recommended_min,
                    limits.recommended_max))
            end
        end
    end
end
-- }}}

-- {{{ TemplateValidator.check_ability_mix
-- Too many of one kind besides the primary, or the same ability twice.
-- The primary is left out of the count, since it always attacks or
-- heals: a primary attack and two damage secondaries is a damage
-- dealer, not a crowd.
function TemplateValidator.check_ability_mix(self, template, add)
    local limit = self.constraints.balance.max_same_kind
    local kinds, kind_order, seen = {}, {}, {}
    for index = 1, #template.abilities do
        local ability = self.built[index]
        if ability then
            if index > 1 then
                if not kinds[ability.type] then
                    table.insert(kind_order, ability.type)
                end
                kinds[ability.type] = (kinds[ability.type] or 0) + 1
            end
            if seen[ability.name] then
                add(string.format("%s repeats ability %d; a second copy only shares its job",
                    ability_label(template, index, ability), seen[ability.name]))
            else
                seen[ability.name] = index
            end
        end
    end
    for _, kind in ipairs(kind_order) do
        if kinds[kind] > limit then
            add(string.format("%d %s abilities besides the primary; more than %d of one kind may leave gaps",
                kinds[kind], kind, limit))
        end
    end
end
-- }}}

-- {{{ TemplateValidator.check_type_coherence
function TemplateValidator.check_type_coherence(self, template, add)
    local rules = self.constraints.balance
    if template.unit_type == "melee" or template.unit_type == "tank" then
        for index = 1, #template.abilities do
            local ability = self.built[index]
            if ability and ability.type == "damage" and ability.range > rules.melee_max_reach then
                add(string.format("%s reaches %g on a %s body; a ranged body suits it better",
                    ability_label(template, index, ability), ability.range, template.unit_type))
            end
        end
    elseif template.unit_type == "ranged" then
        local armor = template.stats.armor
        if type(armor) == "number" and armor > rules.ranged_max_armor then
            add(string.format("armor %g is unusual for a ranged body (over %g)", armor, rules.ranged_max_armor))
        end
    end
end
-- }}}

-- {{{ TemplateValidator.check_budget_use
function TemplateValidator.check_budget_use(self, template, add)
    local share = self.constraints.balance.min_budget_share
    local used = template.points_used or 0
    if template.point_budget > 0 and used < template.point_budget * share then
        add(string.format("Uses only %d of %d points; it may be underpowered", used, template.point_budget))
    end
end
-- }}}

return TemplateValidator
-- }}}
