-- {{{ Template preview
-- What a template preview shows, worked out with nothing drawn: an
-- analysis of how the unit fights (survival, damage, healing, reach,
-- support), headless battles against one unit of each body, a
-- comparison of two templates, and the view's own state (mode, zoom,
-- overlays) with the shapes an overlay would draw. A screen draws these;
-- the template editor (issue 062) keeps one TemplatePreview and calls
-- update() whenever the template changes.
--
--   TemplatePreview.analyze(template)        see the function
--   TemplatePreview.simulate(template, opts) battles; see the function
--   TemplatePreview.compare(a, b)            differences, in numbers and
--                                            words
--   TemplatePreview:new()                    view state and caches
--   preview:update(template)                 the analysis, cached by the
--                                            template's contents
--   preview:simulation(template, opts)       cached the same way
--   preview:set_mode / zoom_by / toggle / overlay_shapes
local TemplatePreview = {}
TemplatePreview.__index = TemplatePreview

local UnitTemplate = require("src.data.unit_template")
local Ability = require("src.components.ability")

TemplatePreview.MODES = {"visual", "stats", "combat", "comparison"}
TemplatePreview.OVERLAYS = {"sight", "ranges", "stats", "mana"}
TemplatePreview.ZOOM = {min = 0.5, max = 3, step = 1.25, default = 1}
-- The size a unit is drawn at, before its size modifier and the zoom,
-- and the share of a distance an overlay circle is drawn at (the sketch's
-- half scale, so a sight circle fits the panel).
TemplatePreview.UNIT_SIZE = 25
TemplatePreview.RANGE_SCALE = 0.5

-- One opponent of each body from the starter set, for simulate().
TemplatePreview.OPPONENTS = {"Warrior", "Archer", "Brute", "Cleric", "Battle Mage"}

-- {{{ local function serialize
-- A stable text form of plain data, for cache keys.
local function serialize(value)
    if type(value) ~= "table" then
        return type(value) == "string" and string.format("%q", value) or tostring(value)
    end
    local keys = {}
    for key in pairs(value) do
        table.insert(keys, key)
    end
    table.sort(keys, function(a, b)
        return tostring(a) < tostring(b)
    end)
    local parts = {}
    for _, key in ipairs(keys) do
        table.insert(parts, tostring(key) .. "=" .. serialize(value[key]))
    end
    return "{" .. table.concat(parts, ",") .. "}"
end
TemplatePreview.signature = function(template)
    return serialize(template:to_save_data())
end
-- }}}

-- {{{ local function as_template
local function as_template(template)
    if UnitTemplate.is_template(template) then
        return template
    end
    return UnitTemplate.new(template)
end
-- }}}

-- {{{ TemplatePreview.analyze
-- Returns {
--   survival = {health, armor, magic_resist, effective_health_physical,
--               effective_health_magical}   (health that much damage of
--               each kind takes to remove: armor A turns H into
--               H * (1 + A / 100))
--   offense = {burst (one cast of every damage ability at once),
--              damage_per_second, healing_per_second (both at a steady
--              charge, counting accuracy, critical hits, cooldowns,
--              effects over time and extra targets), reach (longest
--              damage reach), primary_reach}
--   support = {buffs, debuffs, uptime (seconds of buff or debuff per
--              second)}
--   mobility = {speed, sight}
--   kinds = {single_target, area, piercing, cleave, over_time,
--            crowd_control, physical, magical, true}  (ability counts)
--   abilities = per ability {index, name, kind, role, charge_time,
--               cycle (seconds between casts), per_cast, per_second,
--               targets, range, conditional (it waits on a trigger)}
-- }
-- Abilities that can't be built are left out.
function TemplatePreview.analyze(template)
    template = as_template(template)
    local stats = template.stats
    local analysis = {
        survival = {health = stats.health, armor = stats.armor, magic_resist = stats.magic_resist,
            effective_health_physical = stats.health * (1 + stats.armor / 100),
            effective_health_magical = stats.health * (1 + stats.magic_resist / 100)},
        offense = {burst = 0, damage_per_second = 0, healing_per_second = 0, reach = 0, primary_reach = 0},
        support = {buffs = 0, debuffs = 0, uptime = 0},
        mobility = {speed = stats.speed, sight = stats.detection_range},
        kinds = {single_target = 0, area = 0, piercing = 0, cleave = 0, over_time = 0, crowd_control = 0,
            physical = 0, magical = 0, ["true"] = 0},
        abilities = {}
    }
    for index = 1, #template.abilities do
        local config = template:ability_config(index)
        local ok, ability = pcall(Ability.new, config or {})
        if config and ok then
            local throughput = UnitTemplate.ability_throughput(ability)
            local heals = ability.type == "heal" or (ability.type == "area" and ability.area_effect == "heal")
            local row = {
                index = index, name = ability.name, kind = ability.type, role = index == 1 and "primary" or "secondary",
                charge_time = ability.max_mana / ability.mana_rate,
                cycle = 1 / throughput.casts_per_second,
                targets = throughput.targets, range = ability.range,
                conditional = #ability.generation_conditions > 0 or #ability.activation_conditions > 0
            }
            if throughput.per_cast then
                row.per_cast = throughput.per_cast
                row.per_second = throughput.per_cast * throughput.casts_per_second * throughput.targets
                if heals then
                    analysis.offense.healing_per_second = analysis.offense.healing_per_second + row.per_second
                else
                    analysis.offense.damage_per_second = analysis.offense.damage_per_second + row.per_second
                    analysis.offense.burst = analysis.offense.burst + throughput.per_cast * throughput.targets
                    analysis.offense.reach = math.max(analysis.offense.reach, ability.range)
                    local damage_type = ability.damage_type or "physical"
                    analysis.kinds[damage_type] = (analysis.kinds[damage_type] or 0) + 1
                    if ability.type == "area" then
                        analysis.kinds.area = analysis.kinds.area + 1
                    elseif throughput.targets <= 1 then
                        analysis.kinds.single_target = analysis.kinds.single_target + 1
                    end
                    if ability.pierce > 1 then analysis.kinds.piercing = analysis.kinds.piercing + 1 end
                    if (ability.cleave_targets or 0) > 0 then analysis.kinds.cleave = analysis.kinds.cleave + 1 end
                    if ability.damage_over_time > 0 or (ability.zone_duration or 0) > 0 then
                        analysis.kinds.over_time = analysis.kinds.over_time + 1
                    end
                end
            else
                row.uptime = throughput.uptime
                analysis.support[ability.type == "buff" and "buffs" or "debuffs"] =
                    analysis.support[ability.type == "buff" and "buffs" or "debuffs"] + 1
                analysis.support.uptime = analysis.support.uptime + throughput.uptime
            end
            local modifiers = ability.modifiers or ability.zone_modifiers or {}
            if ability.stun or (modifiers.speed or 0) < 0 then
                analysis.kinds.crowd_control = analysis.kinds.crowd_control + 1
            end
            if index == 1 then
                analysis.offense.primary_reach = ability.range
            end
            table.insert(analysis.abilities, row)
        end
    end
    return analysis
end
-- }}}

-- {{{ TemplatePreview.opponents
-- The opponent templates for simulate(): the starter defaults named in
-- OPPONENTS, built fresh.
function TemplatePreview.opponents(names)
    local TemplateManager = require("src.managers.template_manager")
    local manager = TemplateManager:new()
    manager:create_default_templates({"starter"})
    local list = {}
    for _, name in ipairs(names or TemplatePreview.OPPONENTS) do
        local template = manager:get_template(name)
        if template then
            table.insert(list, template)
        end
    end
    return list
end
-- }}}

-- {{{ TemplatePreview.simulate
-- Headless battles (src/testing/ability_balance.lua): a team of the
-- template against a team of each opponent, sides swapped every other
-- battle. options: opponents (templates; default one of each body),
-- battles (per opponent, default 6), team_size (default 3), seed
-- (default 1), max_time. Returns {rows = per opponent {opponent, body,
-- win_rate, low, high, wins, losses, draws, average_time}, overall =
-- {win_rate, low, high, battles}, note}. The harness walks units
-- straight at each other rather than along lanes, so these compare
-- templates; they don't predict real matches.
function TemplatePreview.simulate(template, options)
    local AbilityBalance = require("src.testing.ability_balance")
    template = as_template(template)
    options = options or {}
    local opponents = options.opponents or TemplatePreview.opponents()
    local result = {rows = {}, note = "Headless battles: units walk straight at each other, not along lanes; "
        .. "compare templates with these, don't read them as real match odds."}
    local score, battles = 0, 0
    for _, opponent in ipairs(opponents) do
        local matchup = AbilityBalance.matchup(template, opponent, {battles = options.battles or 6,
            team_size = options.team_size or 3, seed = options.seed or 1, max_time = options.max_time})
        table.insert(result.rows, {opponent = opponent.name, body = opponent.unit_type, win_rate = matchup.win_rate_a,
            low = matchup.low, high = matchup.high, wins = matchup.wins_a, losses = matchup.wins_b,
            draws = matchup.draws, average_time = matchup.average_time})
        score = score + matchup.wins_a + matchup.draws / 2
        battles = battles + matchup.battles
    end
    local low, high = AbilityBalance.wilson(score, battles)
    result.overall = {win_rate = battles > 0 and score / battles or 0.5, low = low, high = high, battles = battles}
    return result
end
-- }}}

-- {{{ TemplatePreview.compare
-- Template b next to template a: {a, b (names), points = {a, b, diff},
-- stats = per stat {stat, a, b, diff}, abilities = {added (in b only),
-- removed (in a only), shared}, analysis = per measure {key, a, b,
-- diff}, lines (the differences in words, b against a)}.
function TemplatePreview.compare(a, b)
    a, b = as_template(a), as_template(b)
    local result = {a = a.name, b = b.name, stats = {}, abilities = {added = {}, removed = {}, shared = {}},
        analysis = {}, lines = {}}
    result.points = {a = a.points_used, b = b.points_used, diff = b.points_used - a.points_used}
    local function say(text, ...)
        table.insert(result.lines, string.format(text, ...))
    end
    if a.unit_type ~= b.unit_type then
        say("%s has a %s body; %s has a %s body", b.name, b.unit_type, a.name, a.unit_type)
    end
    for _, stat in ipairs(UnitTemplate.STAT_NAMES) do
        local diff = b.stats[stat] - a.stats[stat]
        table.insert(result.stats, {stat = stat, a = a.stats[stat], b = b.stats[stat], diff = diff})
        if diff ~= 0 then
            say("%s has %+g %s (%g against %g)", b.name, diff, (stat:gsub("_", " ")), b.stats[stat], a.stats[stat])
        end
    end
    local function names(template)
        local list, set = {}, {}
        for index = 1, #template.abilities do
            local config = template:ability_config(index)
            local name = config and config.name or ("ability " .. index)
            table.insert(list, name)
            set[name] = (set[name] or 0) + 1
        end
        return list, set
    end
    local list_a, set_a = names(a)
    local list_b, set_b = names(b)
    for _, name in ipairs(list_b) do
        if set_a[name] then
            table.insert(result.abilities.shared, name)
        else
            table.insert(result.abilities.added, name)
        end
    end
    for _, name in ipairs(list_a) do
        if not set_b[name] then
            table.insert(result.abilities.removed, name)
        end
    end
    if #result.abilities.added > 0 then
        say("Only %s has %s", b.name, table.concat(result.abilities.added, ", "))
    end
    if #result.abilities.removed > 0 then
        say("Only %s has %s", a.name, table.concat(result.abilities.removed, ", "))
    end
    local analysis_a, analysis_b = TemplatePreview.analyze(a), TemplatePreview.analyze(b)
    local measures = {
        {"effective_health_physical", "survival", "health against physical damage"},
        {"effective_health_magical", "survival", "health against magical damage"},
        {"damage_per_second", "offense", "damage a second"},
        {"burst", "offense", "burst damage"},
        {"healing_per_second", "offense", "healing a second"},
        {"reach", "offense", "reach"}
    }
    for _, measure in ipairs(measures) do
        local key, group, words = measure[1], measure[2], measure[3]
        local value_a, value_b = analysis_a[group][key], analysis_b[group][key]
        table.insert(result.analysis, {key = key, a = value_a, b = value_b, diff = value_b - value_a})
        if math.abs(value_b - value_a) > 1e-9 then
            say("%s has %+.1f %s (%.1f against %.1f)", b.name, value_b - value_a, words, value_b, value_a)
        end
    end
    if result.points.diff ~= 0 then
        say("%s costs %+d points (%d against %d)", b.name, result.points.diff, b.points_used, a.points_used)
    end
    return result
end
-- }}}

-- {{{ TemplatePreview:new
-- View state: mode, zoom, overlays (all on), and caches.
function TemplatePreview:new()
    local overlays = {}
    for _, name in ipairs(TemplatePreview.OVERLAYS) do
        overlays[name] = true
    end
    local preview = {
        mode = "visual",
        zoom = TemplatePreview.ZOOM.default,
        overlays = overlays,
        comparison = nil,
        analysis = nil,
        signature = nil,
        simulations = {},
        stats = {analyses = 0, simulations = 0}
    }
    setmetatable(preview, self)
    return preview
end
-- }}}

-- {{{ TemplatePreview:set_mode
function TemplatePreview:set_mode(mode)
    for _, name in ipairs(TemplatePreview.MODES) do
        if name == mode then
            self.mode = mode
            return true
        end
    end
    return false, "No preview mode named " .. tostring(mode)
end
-- }}}

-- {{{ TemplatePreview:zoom_by
-- direction 1 zooms in a step, -1 out; held to the zoom limits.
function TemplatePreview:zoom_by(direction)
    local zoom = TemplatePreview.ZOOM
    local factor = direction < 0 and 1 / zoom.step or zoom.step
    self.zoom = math.max(zoom.min, math.min(zoom.max, self.zoom * factor))
    return self.zoom
end
-- }}}

-- {{{ TemplatePreview:toggle
function TemplatePreview:toggle(overlay)
    if self.overlays[overlay] == nil then
        return nil, "No overlay named " .. tostring(overlay)
    end
    self.overlays[overlay] = not self.overlays[overlay]
    return self.overlays[overlay]
end
-- }}}

-- {{{ TemplatePreview:update
-- The template's analysis, worked out again only when its contents
-- changed.
function TemplatePreview:update(template)
    template = as_template(template)
    local signature = TemplatePreview.signature(template)
    if signature ~= self.signature then
        self.signature = signature
        self.analysis = TemplatePreview.analyze(template)
        self.stats.analyses = self.stats.analyses + 1
    end
    return self.analysis
end
-- }}}

-- {{{ TemplatePreview:simulation
-- simulate(), cached by the template's contents and the options' battle
-- count, team size and seed.
function TemplatePreview:simulation(template, options)
    template = as_template(template)
    options = options or {}
    local key = TemplatePreview.signature(template) .. serialize({options.battles, options.team_size, options.seed,
        options.max_time})
    if not self.simulations[key] then
        self.simulations[key] = TemplatePreview.simulate(template, options)
        self.stats.simulations = self.stats.simulations + 1
    end
    return self.simulations[key]
end
-- }}}

-- {{{ TemplatePreview:overlay_shapes
-- What the visual mode draws, with the zoom applied: {unit = {size,
-- shape, primary_color, secondary_color}, circles = list of {kind
-- ("sight" or "ability"), radius, label, index}}. Circles only for
-- overlays switched on.
function TemplatePreview:overlay_shapes(template)
    template = as_template(template)
    local appearance = template.appearance
    local shapes = {
        unit = {size = TemplatePreview.UNIT_SIZE * (appearance.size_modifier or 1) * self.zoom,
            shape = appearance.shape, primary_color = appearance.primary_color,
            secondary_color = appearance.secondary_color},
        circles = {}
    }
    local scale = TemplatePreview.RANGE_SCALE * self.zoom
    if self.overlays.sight then
        table.insert(shapes.circles, {kind = "sight", radius = template.stats.detection_range * scale,
            label = string.format("sight %g", template.stats.detection_range)})
    end
    if self.overlays.ranges then
        for index = 1, #template.abilities do
            local config = template:ability_config(index)
            if config and config.range then
                table.insert(shapes.circles, {kind = "ability", index = index, radius = config.range * scale,
                    label = string.format("%s %g", config.name or "ability", config.range)})
            end
        end
    end
    return shapes
end
-- }}}

return TemplatePreview
-- }}}
