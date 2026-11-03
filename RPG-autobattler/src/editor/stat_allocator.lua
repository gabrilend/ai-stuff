-- {{{ Stat allocator
-- The logic behind setting a unit template's stats, with nothing drawn:
-- a screen (the template editor, issue 062) shows each stat's row and
-- calls these when the player drags a slider, types a number or presses
-- plus or minus. It works on its own copy of the template; result()
-- hands back the edited one.
--
-- Stats are priced against the body's own values (src/data/
-- template_costs.lua), so a row shows what the body gives for free, what
-- has been bought, what one more step costs and what one fewer saves.
--
--   StatAllocator:new(template)
--   allocator:rows()                 one row per stat (see rows())
--   allocator:set(stat, value)       held to the hard limits and to the
--                                    points left; returns value kept and
--                                    a note when it was moved
--   allocator:step(stat, direction)  one increment up (1) or down (-1)
--   allocator:set_fraction(stat, f)  a slider position, 0-1
--   allocator:reset(stat)            back to the body's value
--   allocator:presets()              build presets, in order
--   allocator:apply_preset(id, points)
--   allocator:suggestions()          advice, as {kind, severity, stat,
--                                    message}
--   allocator:result()               a new UnitTemplate
local StatAllocator = {}
StatAllocator.__index = StatAllocator

local UnitTemplate = require("src.data.unit_template")
local TemplateCosts = require("src.data.template_costs")
local TemplateConstraints = require("src.data.template_constraints")

-- How each stat is shown and stepped. Categories group the rows:
-- survival (staying alive), mobility and awareness.
StatAllocator.STATS = {
    health = {name = "Health", category = "survival", increment = 10,
        description = "Damage the unit can take."},
    armor = {name = "Armor", category = "survival", increment = 1,
        description = "Cuts physical damage: 100 armor halves it."},
    magic_resist = {name = "Magic resist", category = "survival", increment = 1,
        description = "Cuts magical damage the way armor cuts physical."},
    speed = {name = "Speed", category = "mobility", increment = 5,
        description = "How fast the unit walks its lane."},
    detection_range = {name = "Sight", category = "awareness", increment = 5,
        description = "How far the unit notices enemies."}
}
StatAllocator.CATEGORY_ORDER = {"survival", "mobility", "awareness"}

-- Ways to spend stat points, as shares of the points spent. They are
-- shares rather than fixed values so they suit every body and leave the
-- abilities' points alone. In the order a player would read them.
StatAllocator.PRESETS = {
    {id = "balanced", name = "Balanced", description = "A little of each: health, armor and speed.",
        shares = {health = 0.4, armor = 0.3, speed = 0.3}},
    {id = "tank", name = "Tank", description = "Health and armor to hold a lane.",
        shares = {health = 0.6, armor = 0.4}},
    {id = "bruiser", name = "Bruiser", description = "Tough and quick enough to reach the fight.",
        shares = {health = 0.5, armor = 0.25, speed = 0.25}},
    {id = "skirmisher", name = "Skirmisher", description = "Fast, with enough health to get away.",
        shares = {speed = 0.6, health = 0.4}},
    {id = "scout", name = "Scout", description = "Speed and sight, to see and get there first.",
        shares = {speed = 0.5, detection_range = 0.5}},
    {id = "spellguard", name = "Spellguard", description = "Health and magic resist against casters.",
        shares = {health = 0.5, magic_resist = 0.5}}
}

-- {{{ local function body_of
local function body_of(template)
    return TemplateCosts.bodies[template.unit_type] or {}
end
-- }}}

-- {{{ StatAllocator:new
function StatAllocator:new(template)
    local data = UnitTemplate.is_template(template) and template:to_save_data() or template
    local allocator = {template = UnitTemplate.new(data)}
    setmetatable(allocator, self)
    return allocator
end
-- }}}

-- {{{ StatAllocator:with
-- The template with one stat changed (not kept).
function StatAllocator:with(stat, value)
    local data = self.template:to_save_data()
    data.stats[stat] = value
    return UnitTemplate.new(data)
end
-- }}}

-- {{{ StatAllocator:exact_cost
-- A stat's points before rounding up, at a value.
function StatAllocator:exact_cost(stat, value)
    local base = body_of(self.template)[stat] or 0
    return math.max(0, value - base) * TemplateCosts.stats[stat].per_unit
end
-- }}}

-- {{{ StatAllocator:affordable_max
-- The highest value this stat can take with the points left, inside the
-- hard limit.
function StatAllocator:affordable_max(stat)
    local limit = TemplateConstraints.stats[stat].max
    local value = self.template.stats[stat]
    local spare = self.template:points_left() + self.template.breakdown.stats[stat]
    if spare < 0 then
        return value
    end
    local base = body_of(self.template)[stat] or 0
    local per_unit = TemplateCosts.stats[stat].per_unit
    local high = math.min(limit, math.floor(base + spare / per_unit + 1e-9))
    -- Rounding up can cost a point more than the exact price; step back
    -- until it fits.
    while high > value and UnitTemplate.round_up(self:exact_cost(stat, high)) > spare do
        high = high - 1
    end
    return math.max(value, high)
end
-- }}}

-- {{{ StatAllocator:rows
-- One row per stat, in category order: {stat, name, category,
-- description, value, base (the body's value), min, max,
-- recommended_min, recommended_max, increment, points (paid now),
-- exact (before rounding up), rounding (points lost to rounding),
-- next_cost (points one increment more would add), refund (points one
-- increment less would save), per_point (units a point buys),
-- affordable_max, fraction (slider position, 0-1)}.
function StatAllocator:rows()
    local rows = {}
    for _, category in ipairs(StatAllocator.CATEGORY_ORDER) do
        for _, stat in ipairs(UnitTemplate.STAT_NAMES) do
            local info = StatAllocator.STATS[stat]
            if info.category == category then
                local limits = TemplateConstraints.stats[stat]
                local value = self.template.stats[stat]
                local points = self.template.breakdown.stats[stat]
                local up = math.min(limits.max, value + info.increment)
                local down = math.max(limits.min, value - info.increment)
                local exact = self:exact_cost(stat, value)
                table.insert(rows, {
                    stat = stat, name = info.name, category = category, description = info.description,
                    value = value, base = body_of(self.template)[stat] or 0,
                    min = limits.min, max = limits.max,
                    recommended_min = limits.recommended_min, recommended_max = limits.recommended_max,
                    increment = info.increment, points = points, exact = exact,
                    rounding = points - exact,
                    next_cost = UnitTemplate.round_up(self:exact_cost(stat, up)) - points,
                    refund = points - UnitTemplate.round_up(self:exact_cost(stat, down)),
                    per_point = 1 / TemplateCosts.stats[stat].per_unit,
                    affordable_max = self:affordable_max(stat),
                    fraction = (value - limits.min) / (limits.max - limits.min)
                })
            end
        end
    end
    return rows
end
-- }}}

-- {{{ StatAllocator:set
-- Sets a stat, held inside its hard limits and, when raising it, to what
-- the points left can buy. Lowering is always allowed. Returns the value
-- kept and a note when it differs from the one asked for; nil and a note
-- for an unknown stat or a value that isn't a number.
function StatAllocator:set(stat, value)
    local limits = TemplateConstraints.stats[stat]
    if not limits then
        return nil, "No stat named " .. tostring(stat)
    end
    if type(value) ~= "number" or value ~= value then
        return nil, StatAllocator.STATS[stat].name .. " must be a number"
    end
    local wanted = value
    value = math.floor(value + 0.5)
    value = math.max(limits.min, math.min(limits.max, value))
    local note
    if value > self.template.stats[stat] then
        local cap = self:affordable_max(stat)
        if value > cap then
            value = cap
            note = string.format("%s %g would go over budget; held to %g", StatAllocator.STATS[stat].name, wanted, value)
        end
    end
    if not note and value ~= wanted then
        note = string.format("%s %g was held to %g (allowed %g-%g, whole numbers)", StatAllocator.STATS[stat].name,
            wanted, value, limits.min, limits.max)
    end
    self.template = self:with(stat, value)
    return value, note
end
-- }}}

-- {{{ StatAllocator:step
function StatAllocator:step(stat, direction)
    local info = StatAllocator.STATS[stat]
    if not info then
        return nil, "No stat named " .. tostring(stat)
    end
    return self:set(stat, self.template.stats[stat] + (direction < 0 and -1 or 1) * info.increment)
end
-- }}}

-- {{{ StatAllocator:set_fraction
-- A slider position (0 at the hard minimum, 1 at the maximum), snapped to
-- the stat's increment.
function StatAllocator:set_fraction(stat, fraction)
    local limits = TemplateConstraints.stats[stat]
    if not limits or type(fraction) ~= "number" then
        return nil, "No stat named " .. tostring(stat)
    end
    fraction = math.max(0, math.min(1, fraction))
    local increment = StatAllocator.STATS[stat].increment
    local value = limits.min + fraction * (limits.max - limits.min)
    value = limits.min + math.floor((value - limits.min) / increment + 0.5) * increment
    return self:set(stat, value)
end
-- }}}

-- {{{ StatAllocator:reset
function StatAllocator:reset(stat)
    return self:set(stat, body_of(self.template)[stat] or TemplateConstraints.stats[stat].min)
end
-- }}}

-- {{{ StatAllocator:presets
function StatAllocator:presets()
    return StatAllocator.PRESETS
end
-- }}}

-- {{{ StatAllocator:apply_preset
-- Puts every stat back to the body's value, then spends `points` (by
-- default every point not spent on the body and abilities) by the
-- preset's shares, one increment at a time: each step goes to the stat
-- furthest below its share, so a stat that reaches its hard limit hands
-- its share to the others. Never over budget. Returns true and the
-- points spent on stats, or nil and a note.
function StatAllocator:apply_preset(id, points)
    local preset
    for _, entry in ipairs(StatAllocator.PRESETS) do
        if entry.id == id then
            preset = entry
        end
    end
    if not preset then
        return nil, "No preset named " .. tostring(id)
    end
    local data = self.template:to_save_data()
    local body = body_of(self.template)
    for _, stat in ipairs(UnitTemplate.STAT_NAMES) do
        data.stats[stat] = body[stat] or TemplateConstraints.stats[stat].min
    end
    local bare = UnitTemplate.new(data)
    local available = math.max(0, math.min(points or bare:points_left(), bare:points_left()))
    self.template = bare

    local values, paid, spent = {}, {}, 0
    for _, stat in ipairs(UnitTemplate.STAT_NAMES) do
        values[stat] = data.stats[stat]
        paid[stat] = 0
    end
    while true do
        local best, best_ratio, best_cost
        for _, stat in ipairs(UnitTemplate.STAT_NAMES) do
            local share = preset.shares[stat]
            if share then
                local next_value = values[stat] + StatAllocator.STATS[stat].increment
                if next_value <= TemplateConstraints.stats[stat].max then
                    local cost = UnitTemplate.round_up(self:exact_cost(stat, next_value)) - paid[stat]
                    local ratio = paid[stat] / share
                    if spent + cost <= available and (not best or ratio < best_ratio) then
                        best, best_ratio, best_cost = stat, ratio, cost
                    end
                end
            end
        end
        if not best then
            break
        end
        values[best] = values[best] + StatAllocator.STATS[best].increment
        paid[best] = paid[best] + best_cost
        spent = spent + best_cost
    end
    for _, stat in ipairs(UnitTemplate.STAT_NAMES) do
        data.stats[stat] = values[stat]
    end
    self.template = UnitTemplate.new(data)
    return true, self.template.points_used - bare.points_used
end
-- }}}

-- {{{ StatAllocator:suggestions
-- Advice on the stats as they stand, most useful first:
--   over_budget      (error)   the template is over budget
--   below_body       (info)    a stat below the body's own value: it
--                              saves no points
--   rounding         (info)    a stat paying for a part-point it could
--                              use: one more step for no extra cost
--   unused_points    (warning) more than a tenth of the budget unspent
--   lopsided         (info)    one stat holding over 70% of the stat
--                              points
function StatAllocator:suggestions()
    local list = {}
    local template = self.template
    local function add(kind, severity, stat, message)
        table.insert(list, {kind = kind, severity = severity, stat = stat, message = message})
    end
    if template:points_left() < 0 then
        add("over_budget", "error", nil, string.format("%d points over budget; lower a stat or drop an ability",
            -template:points_left()))
    end
    local stat_points = 0
    for _, row in ipairs(self:rows()) do
        stat_points = stat_points + row.points
        if row.value < row.base then
            add("below_body", "info", row.stat, string.format(
                "%s %g is below the %s body's %g; lowering it gives no points back", row.name, row.value,
                template.unit_type, row.base))
        end
        if row.points > 0 and row.next_cost == 0 and row.value < row.max then
            add("rounding", "info", row.stat, string.format(
                "%s costs %d points for %g; one more step (to %g) costs nothing more", row.name, row.points,
                row.value, math.min(row.max, row.value + row.increment)))
        end
    end
    local left = template:points_left()
    if left > template.point_budget * 0.1 then
        add("unused_points", "warning", nil, string.format("%d points unspent (%.0f%% of the budget); a preset can "
            .. "spend them", left, left / template.point_budget * 100))
    end
    if stat_points > 0 then
        for _, stat in ipairs(UnitTemplate.STAT_NAMES) do
            local share = template.breakdown.stats[stat] / stat_points
            if share > 0.7 and stat_points >= 10 then
                add("lopsided", "info", stat, string.format("%s holds %.0f%% of the stat points; a unit this "
                    .. "one-sided has a clear weakness", StatAllocator.STATS[stat].name, share * 100))
            end
        end
    end
    return list
end
-- }}}

-- {{{ StatAllocator:result
function StatAllocator:result()
    return UnitTemplate.new(self.template:to_save_data())
end
-- }}}

return StatAllocator
-- }}}
