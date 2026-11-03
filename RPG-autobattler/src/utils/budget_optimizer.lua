-- {{{ Budget optimizer
-- Ways to bring an over-budget unit template back within its budget,
-- each tried on a copy so its saving and its result are known exactly:
--   lower_stat     lower one bought stat just enough (or to the body's
--                  own value when that isn't enough)
--   slow_ability   tune a library ability to its slowest charge rate
--   swap_ability   swap an ability for the cheapest one of the same
--                  kind that saves enough (a primary only for another
--                  that can be a primary)
--   remove_ability drop a secondary ability
--
--   BudgetOptimizer.suggest(template, options)  a list, best first
--   BudgetOptimizer.apply(suggestion)          the changed template
--
-- A suggestion: {kind, description, saves (points), points_after, fits
-- (within budget), valid (no errors at all), new_warnings (warnings the
-- change would add), data (the changed template's data)}. Best first:
-- those that fit, then those that are valid, then those adding fewer
-- warnings, then the smallest saving (the least taken away), then by
-- kind in the order above. options.limit caps the list (default 8). A template within its
-- budget gets an empty list.
local BudgetOptimizer = {}

local UnitTemplate = require("src.data.unit_template")
local TemplateCosts = require("src.data.template_costs")
local AbilityLibrary = require("src.data.ability_library")

BudgetOptimizer.KIND_ORDER = {lower_stat = 1, slow_ability = 2, swap_ability = 3, remove_ability = 4}

local STAT_LABELS = {health = "health", speed = "speed", armor = "armor", magic_resist = "magic resist",
    detection_range = "sight"}

local shared_library
-- {{{ local function library
local function library()
    shared_library = shared_library or AbilityLibrary:new()
    return shared_library
end
-- }}}

-- {{{ local function candidate
local function candidate(template, kind, description, data)
    local result = UnitTemplate.new(data)
    local had = {}
    for _, warning in ipairs(template.validation_warnings) do
        had[warning] = true
    end
    local new_warnings = {}
    for _, warning in ipairs(result.validation_warnings) do
        if not had[warning] then
            table.insert(new_warnings, warning)
        end
    end
    return {
        new_warnings = new_warnings,
        kind = kind,
        description = description,
        saves = template.points_used - result.points_used,
        points_after = result.points_used,
        fits = result.points_used <= result.point_budget,
        valid = result.is_valid,
        data = data
    }
end
-- }}}

-- {{{ local function lower_stats
local function lower_stats(template, excess, out)
    local body = TemplateCosts.bodies[template.unit_type] or {}
    for _, stat in ipairs(UnitTemplate.STAT_NAMES) do
        local paid = template.breakdown.stats[stat]
        if paid > 0 then
            local base = body[stat] or 0
            local value = template.stats[stat]
            local per_unit = TemplateCosts.stats[stat].per_unit
            -- The highest value whose price is at most paid - excess.
            local target_points = math.max(0, paid - excess)
            local target = math.max(base, math.floor(base + target_points / per_unit + 1e-9))
            while target > base and UnitTemplate.round_up((target - base) * per_unit) > target_points do
                target = target - 1
            end
            if target < value then
                local data = template:to_save_data()
                data.stats[stat] = target
                table.insert(out, candidate(template, "lower_stat", string.format("Lower %s from %g to %g",
                    STAT_LABELS[stat], value, target), data))
            end
        end
    end
end
-- }}}

-- {{{ local function ability_changes
local function ability_changes(template, excess, out)
    local lib = library()
    for index, entry in ipairs(template.abilities) do
        local id = entry.template
        local info = id and lib:get(id)
        local role = index == 1 and "primary" or "secondary"
        local current = template.breakdown.abilities[index]
        if info then
            -- Slowest charge rate.
            local limits = lib:limits(id)
            local changes = {}
            for key, value in pairs(entry.changes or {}) do
                changes[key] = value
            end
            if limits.mana_rate and (changes.mana_rate or limits.mana_rate.base) > limits.mana_rate.min then
                changes.mana_rate = limits.mana_rate.min
                local data = template:to_save_data()
                data.abilities[index] = {template = id, changes = changes}
                table.insert(out, candidate(template, "slow_ability", string.format(
                    "Slow %s's charge rate to %g", id, limits.mana_rate.min), data))
            end
            -- The dearest same-kind ability that still saves enough (the
            -- least taken away), or else the cheapest; one that works the
            -- same way (same subcategory: melee, ranged, burst...) first.
            local function pick_from(entries)
                local best, best_cost, cheapest, cheapest_cost
                for _, other in ipairs(entries) do
                    if other.id ~= id then
                        local cost = lib:cost(other.id, nil, index == 1)
                        if cost < current then
                            if current - cost >= excess and (not best or cost > best_cost or
                                    (cost == best_cost and other.id < best.id)) then
                                best, best_cost = other, cost
                            end
                            if not cheapest or cost < cheapest_cost or
                                    (cost == cheapest_cost and other.id < cheapest.id) then
                                cheapest, cheapest_cost = other, cost
                            end
                        end
                    end
                end
                return best, cheapest
            end
            local same_best, same_cheapest = pick_from(lib:search("", {category = info.category,
                subcategory = info.subcategory, primary_only = index == 1}))
            local kind_best, kind_cheapest = pick_from(lib:search("", {category = info.category,
                primary_only = index == 1}))
            local pick = same_best or kind_best or same_cheapest or kind_cheapest
            if pick then
                local data = template:to_save_data()
                data.abilities[index] = pick.id
                table.insert(out, candidate(template, "swap_ability", string.format("Swap %s %s for %s",
                    role, id, pick.id), data))
            end
        end
        if index > 1 then
            local data = template:to_save_data()
            table.remove(data.abilities, index)
            table.insert(out, candidate(template, "remove_ability", string.format("Remove %s",
                id or (entry.config and entry.config.name) or ("ability " .. index)), data))
        end
    end
end
-- }}}

-- {{{ BudgetOptimizer.suggest
function BudgetOptimizer.suggest(template, options)
    options = options or {}
    if not UnitTemplate.is_template(template) then
        template = UnitTemplate.new(template)
    end
    local excess = template.points_used - template.point_budget
    if excess <= 0 then
        return {}
    end
    local list = {}
    lower_stats(template, excess, list)
    ability_changes(template, excess, list)
    local kept = {}
    for _, item in ipairs(list) do
        if item.saves > 0 then
            table.insert(kept, item)
        end
    end
    table.sort(kept, function(a, b)
        if a.fits ~= b.fits then
            return a.fits
        end
        if a.valid ~= b.valid then
            return a.valid
        end
        if #a.new_warnings ~= #b.new_warnings then
            return #a.new_warnings < #b.new_warnings
        end
        if a.fits and a.saves ~= b.saves then
            return a.saves < b.saves
        elseif not a.fits and a.saves ~= b.saves then
            return a.saves > b.saves
        end
        if a.kind ~= b.kind then
            return BudgetOptimizer.KIND_ORDER[a.kind] < BudgetOptimizer.KIND_ORDER[b.kind]
        end
        return a.description < b.description
    end)
    local limit = options.limit or 8
    while #kept > limit do
        table.remove(kept)
    end
    return kept
end
-- }}}

-- {{{ BudgetOptimizer.apply
function BudgetOptimizer.apply(suggestion)
    return UnitTemplate.new(suggestion.data)
end
-- }}}

return BudgetOptimizer
-- }}}
