-- {{{ Point budget
-- What a budget display shows, worked out with nothing drawn: how much
-- of a template's point budget is used, where each point went (as
-- segments of a bar, each with a tooltip), how the template stands
-- (over, near the limit, good, or with points unused), the validator's
-- findings with their severity, and what changed between two looks, so
-- a screen knows when to animate or shake.
--
--   PointBudget.summary(template)           see the function
--   PointBudget.change(before, after)       two summaries compared
--
-- Segments come in a fixed order (body, stats, abilities) with a group
-- name a screen maps to a colour.
local PointBudget = {}

local UnitTemplate = require("src.data.unit_template")
local TemplateCosts = require("src.data.template_costs")
local Ability = require("src.components.ability")

-- Thresholds for the budget's status, as shares of the budget.
PointBudget.NEAR = 0.9       -- at or above this: near the limit
PointBudget.UNUSED = 0.15    -- more than this left: points unused

PointBudget.STAT_LABELS = {health = "Health", speed = "Speed", armor = "Armor", magic_resist = "Magic resist",
    detection_range = "Sight"}

-- {{{ local function number
local function number(value)
    if value == math.floor(value) then
        return string.format("%d", value)
    end
    return string.format("%.1f", value)
end
-- }}}

-- {{{ local function status_of
-- status, severity and message for points used against a budget.
local function status_of(used, budget)
    local left = budget - used
    if used > budget then
        return "over", "error", string.format("Over budget by %d points", -left)
    elseif used >= budget * PointBudget.NEAR then
        return "near", "warning", string.format("%d points left", left)
    elseif left > budget * PointBudget.UNUSED then
        return "unused", "info", string.format("%d points unused", left)
    end
    return "good", "success", string.format("Good use of points: %d left", left)
end
PointBudget.status_of = status_of
-- }}}

-- {{{ local function stat_tooltip
local function stat_tooltip(template, stat, points)
    local base = (TemplateCosts.bodies[template.unit_type] or {})[stat] or 0
    local value = template.stats[stat]
    local per_unit = TemplateCosts.stats[stat].per_unit
    return {
        string.format("%s %s", PointBudget.STAT_LABELS[stat], number(value)),
        string.format("%s above the %s body's %s, at %s points each", number(value - base), template.unit_type,
            number(base), number(per_unit)),
        string.format("%d points (%s before rounding up)", points, number((value - base) * per_unit))
    }
end
-- }}}

-- {{{ local function ability_tooltip
local function ability_tooltip(template, index, points)
    local config = template:ability_config(index)
    local ok, ability = pcall(Ability.new, config or {})
    local entry = template.abilities[index]
    local name = entry.template or (config and config.name) or "custom ability"
    local lines = {string.format("%s (%s): %d points", name, index == 1 and "primary" or "secondary", points)}
    if ok and ability then
        local costs = TemplateCosts.abilities
        table.insert(lines, string.format("Base %d for a %s, scaled by how strong it is", index == 1 and
            costs.primary_base or costs.secondary_base, index == 1 and "primary" or "secondary"))
        table.insert(lines, string.format("Charges in %s s; reach %s (free up to %s)", number(ability.max_mana /
            ability.mana_rate), number(ability.range), number(costs.reach_base)))
        if entry.changes and next(entry.changes) then
            local keys = {}
            for key in pairs(entry.changes) do
                table.insert(keys, key)
            end
            table.sort(keys)
            local parts = {}
            for _, key in ipairs(keys) do
                table.insert(parts, key .. " " .. tostring(entry.changes[key]))
            end
            table.insert(lines, "Tuned: " .. table.concat(parts, ", "))
        end
    else
        table.insert(lines, "Can't be built, so it costs nothing until fixed")
    end
    return lines
end
-- }}}

-- {{{ PointBudget.summary
-- Returns {budget, used, left, share (used / budget), status ("over",
-- "near", "good" or "unused"), severity, message, scale (what the bar's
-- full width stands for: the budget, or the points used when over),
-- segments, totals = {body, stats, abilities}, messages}.
-- A segment: {key, group ("body", "stats" or "abilities"), label,
-- points, share (of the budget), start (share before it), tooltip
-- (lines)}; zero-point parts are left out.
-- messages: the status first, then the validator's errors and warnings
-- (but not its budget rules, which the status covers), each {severity,
-- rule, text}.
function PointBudget.summary(template)
    if not UnitTemplate.is_template(template) then
        template = UnitTemplate.new(template)
    end
    local budget, used = template.point_budget, template.points_used
    local breakdown = template.breakdown
    local status, severity, message = status_of(used, budget)
    local summary = {budget = budget, used = used, left = budget - used, share = used / budget, status = status,
        severity = severity, message = message, scale = math.max(budget, used), segments = {},
        totals = {body = breakdown.body, stats = 0, abilities = 0}, messages = {}}

    local start = 0
    local function add(key, group, label, points, tooltip)
        if points > 0 then
            table.insert(summary.segments, {key = key, group = group, label = label, points = points,
                share = points / budget, start = start, tooltip = tooltip})
            start = start + points / budget
        end
    end
    add("body", "body", template.unit_type .. " body", breakdown.body,
        {string.format("The %s body: %d points", template.unit_type, breakdown.body)})
    for _, stat in ipairs(UnitTemplate.STAT_NAMES) do
        local points = breakdown.stats[stat]
        summary.totals.stats = summary.totals.stats + points
        add("stat:" .. stat, "stats", PointBudget.STAT_LABELS[stat], points, stat_tooltip(template, stat, points))
    end
    for index = 1, #template.abilities do
        local points = breakdown.abilities[index]
        summary.totals.abilities = summary.totals.abilities + points
        local entry = template.abilities[index]
        local label = entry.template or (entry.config and entry.config.name) or ("ability " .. index)
        add("ability:" .. index, "abilities", label, points, ability_tooltip(template, index, points))
    end

    -- The budget's own status stands in for the validator's two budget
    -- rules; every other finding follows, errors first.
    table.insert(summary.messages, {severity = severity, rule = "budget", text = message})
    local _, findings = UnitTemplate.default_validator():validate_detailed(template)
    for _, critical in ipairs({true, false}) do
        for _, finding in ipairs(findings) do
            if finding.critical == critical and finding.rule ~= "point_budget" and finding.rule ~= "budget_use" then
                table.insert(summary.messages, {severity = critical and "error" or "warning", rule = finding.rule,
                    text = finding.message})
            end
        end
    end
    return summary
end
-- }}}

-- {{{ PointBudget.change
-- What changed between two summaries: {delta (points), status_changed,
-- became_over (the moment for a shake), back_in_budget, groups = {body,
-- stats, abilities -> delta}, animate (anything moved)}.
function PointBudget.change(before, after)
    local groups = {}
    local moved = false
    for _, group in ipairs({"body", "stats", "abilities"}) do
        groups[group] = after.totals[group] - before.totals[group]
        moved = moved or groups[group] ~= 0
    end
    return {
        delta = after.used - before.used,
        status_changed = before.status ~= after.status,
        became_over = before.status ~= "over" and after.status == "over",
        back_in_budget = before.status == "over" and after.status ~= "over",
        groups = groups,
        animate = moved or before.budget ~= after.budget
    }
end
-- }}}

return PointBudget
-- }}}
