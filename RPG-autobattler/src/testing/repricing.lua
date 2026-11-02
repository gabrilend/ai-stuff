-- {{{ Repricing
-- Suggests new point prices from how templates actually do in headless
-- battles (src/testing/ability_balance.lua). It never changes the prices
-- in src/data/template_costs.lua: everything it returns or prints is
-- PROVISIONAL, because the harness walks units straight at each other
-- instead of following lanes. The prices stay first guesses until issue
-- 067 puts ability sets into real matches; then this same machinery can
-- be pointed at those results.
--
-- How it works, in four steps:
--   1. measure: every template fights every other (a seeded round robin
--      of teams of copies); each gets an overall win rate.
--   2. calibrate: one reference template, given a few extra points of
--      health at a time, fights the same field. How far that moves its
--      win rate says how many points one step of "log-odds" of winning
--      is worth. (Or pass points_per_logit to skip this.)
--   3. fair cost: a template that wins more than half its battles is
--      worth more than it pays; fair cost = points used + log-odds of its
--      win rate times points per log-odds.
--   4. fit: each part of a price (a body, a stat's price per unit, an
--      ability) gets a factor, the weighted average of fair/actual over
--      the templates that pay for it (weighted by its share of each
--      template's cost), damped and held to a range. Parts too few
--      templates pay for keep a factor of 1.
--
--   Repricing.run(templates, options)   all four steps; a proposal
--   Repricing.measure(templates, options)
--   Repricing.calibrate(reference, field, options)
--   Repricing.fit(rows, options)        steps 3-4 from measured rows
--   Repricing.cost_under(template, proposal)  a template's points if the
--                                       proposal's factors were used
--   Repricing.lines(proposal)           the proposal in words; every
--                                       line starts "[provisional]"
--
-- The same templates, options and seed give the same proposal, in
-- luajit or lua5.4.
local Repricing = {}

local AbilityBalance = require("src.testing.ability_balance")
local UnitTemplate = require("src.data.unit_template")
local TemplateCosts = require("src.data.template_costs")
local TemplateConstraints = require("src.data.template_constraints")

Repricing.MARK = "[provisional]"

Repricing.DEFAULTS = {
    seed = 1,
    battles = 6,               -- per matchup
    team_size = 4,
    max_time = 60,
    points_per_logit = nil,    -- nil: measure it with calibrate()
    fallback_points_per_logit = 20,
    calibration_points = {0, 5, 10, 20}, -- extra health, in points, for calibrate()
    calibration_battles = 4,   -- per opponent, per step
    damping = 0.5,             -- move half way to the fitted factor
    min_factor = 0.5,
    max_factor = 2.0,
    min_evidence = 0.5         -- total share of cost needed to move a part
}

-- {{{ local function option
local function option(options, key)
    if options and options[key] ~= nil then
        return options[key]
    end
    return Repricing.DEFAULTS[key]
end
-- }}}

-- {{{ local function logit
-- Log-odds of a win rate, smoothed so 0% and 100% stay finite: half a
-- win is added to each side's count.
local function logit(score, battles)
    local p = (score + 0.5) / (battles + 1)
    return math.log(p / (1 - p))
end
Repricing.logit = logit
-- }}}

-- {{{ local function clamp
local function clamp(value, low, high)
    return math.max(low, math.min(high, value))
end
-- }}}

-- {{{ local function harness_options
local function harness_options(options, battles)
    return {
        seed = option(options, "seed"),
        battles = battles,
        team_size = option(options, "team_size"),
        max_time = option(options, "max_time")
    }
end
-- }}}

-- {{{ Repricing.measure
-- A round robin of the templates. Returns rows in the templates' order:
-- {name, template, score, battles, win_rate, low, high}.
function Repricing.measure(templates, options)
    local round = AbilityBalance.round_robin(templates, harness_options(options, option(options, "battles")))
    local rows = {}
    for index, template in ipairs(templates) do
        local overall = round.overall[round.sets[index]]
        rows[index] = {
            name = template.name,
            template = template,
            score = overall.score,
            battles = overall.battles,
            win_rate = overall.win_rate,
            low = overall.low,
            high = overall.high
        }
    end
    return rows
end
-- }}}

-- {{{ Repricing.calibrate
-- How many points one unit of log-odds is worth. The reference template,
-- given 0 and then each step of calibration_points more health, fights
-- every other template in the field; a straight line through (points,
-- log-odds of its win rate) gives log-odds per point. The field is the
-- same one step 1 measures, so the answer is in the same terms as the
-- win rates it prices. (A mirror match against itself would be far too
-- sensitive: between equals, any edge decides most battles.) Returns
-- points_per_logit, the steps ({points, health, score, battles,
-- win_rate}) and a note when the fallback had to be used.
function Repricing.calibrate(reference, field, options)
    local opponents = {}
    for _, template in ipairs(field) do
        if template ~= reference then
            table.insert(opponents, template)
        end
    end
    local battles = option(options, "calibration_battles")
    local steps = {}
    for _, points in ipairs(option(options, "calibration_points")) do
        local data = reference:to_save_data()
        -- Extra health, held under the hard limit so the copy stays valid;
        -- the step counts only the points actually added.
        local price = TemplateCosts.stats.health.per_unit
        local room = TemplateConstraints.stats.health.max - data.stats.health
        local extra = math.max(0, math.min(room, math.floor(points / price + 0.5)))
        data.name = reference.name:sub(1, 25) .. " Plus"
        data.stats.health = data.stats.health + extra
        local boosted = UnitTemplate.new(data)
        local step = {points = extra * price, health = extra, score = 0, battles = 0}
        for _, opponent in ipairs(opponents) do
            local result = AbilityBalance.matchup(boosted, opponent, harness_options(options, battles))
            step.score = step.score + result.wins_a + result.draws / 2
            step.battles = step.battles + result.battles
        end
        step.win_rate = step.battles > 0 and step.score / step.battles or 0.5
        step.logit = logit(step.score, step.battles)
        table.insert(steps, step)
    end
    local mean_x, mean_y = 0, 0
    for _, step in ipairs(steps) do
        mean_x = mean_x + step.points / #steps
        mean_y = mean_y + step.logit / #steps
    end
    local sxy, sxx = 0, 0
    for _, step in ipairs(steps) do
        sxy = sxy + (step.points - mean_x) * (step.logit - mean_y)
        sxx = sxx + (step.points - mean_x) ^ 2
    end
    local slope = sxx > 0 and sxy / sxx or 0
    if slope <= 0.005 or #opponents == 0 then
        return option(options, "fallback_points_per_logit"), steps,
            string.format("extra health didn't raise %s's win rate measurably; used the fallback", reference.name)
    end
    return 1 / slope, steps, nil
end
-- }}}

-- {{{ local function parts_of
-- What a template pays for, as {key -> points}: "body:<type>",
-- "stat:<name>", "ability:<template id>" (custom abilities are
-- "ability:custom").
local function parts_of(template)
    local parts = {}
    local breakdown = template.breakdown
    if breakdown.body > 0 then
        parts["body:" .. template.unit_type] = breakdown.body
    end
    for stat, points in pairs(breakdown.stats) do
        if points > 0 then
            parts["stat:" .. stat] = (parts["stat:" .. stat] or 0) + points
        end
    end
    for index, points in ipairs(breakdown.abilities) do
        local entry = template.abilities[index]
        local key = "ability:" .. (entry.template or "custom")
        if points > 0 then
            parts[key] = (parts[key] or 0) + points
        end
    end
    return parts
end
Repricing.parts_of = parts_of
-- }}}

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

-- {{{ Repricing.fit
-- Steps 3 and 4 from measured rows (each needs template, score and
-- battles). Returns a proposal: {provisional = true, points_per_logit,
-- templates = rows with fair_cost and gap (fair minus actual), factors
-- = {key -> {factor, evidence, templates}} in key order as `order`,
-- spread_before, spread_after (root mean square of fair minus cost,
-- before and after the factors)}.
function Repricing.fit(rows, options)
    local per_logit = option(options, "points_per_logit") or option(options, "fallback_points_per_logit")
    local damping = option(options, "damping")
    local low, high = option(options, "min_factor"), option(options, "max_factor")
    local min_evidence = option(options, "min_evidence")

    local proposal = {provisional = true, points_per_logit = per_logit, templates = {}, factors = {}, order = {}}
    local sums = {}
    for index, row in ipairs(rows) do
        local template = row.template
        local used = template.points_used
        local strength = logit(row.score, row.battles)
        local fair = math.max(1, used + strength * per_logit)
        local out = {}
        for key, value in pairs(row) do
            out[key] = value
        end
        out.points_used = used
        out.fair_cost = fair
        out.gap = fair - used
        proposal.templates[index] = out
        if used > 0 then
            local ratio = clamp(fair / used, low, high)
            for key, points in pairs(parts_of(template)) do
                local share = points / used
                local sum = sums[key] or {weight = 0, total = 0, templates = 0}
                sum.weight = sum.weight + share
                sum.total = sum.total + share * math.log(ratio)
                sum.templates = sum.templates + 1
                sums[key] = sum
            end
        end
    end
    for _, key in ipairs(sorted_keys(sums)) do
        local sum = sums[key]
        local factor = 1
        if sum.weight >= min_evidence then
            factor = clamp(math.exp(damping * sum.total / sum.weight), low, high)
        end
        proposal.factors[key] = {factor = factor, evidence = sum.weight, templates = sum.templates,
            moved = sum.weight >= min_evidence}
        table.insert(proposal.order, key)
    end

    local before, after = 0, 0
    for _, row in ipairs(proposal.templates) do
        before = before + (row.fair_cost - row.points_used) ^ 2
        after = after + (row.fair_cost - Repricing.cost_under(row.template, proposal)) ^ 2
    end
    local count = math.max(1, #proposal.templates)
    proposal.spread_before = math.sqrt(before / count)
    proposal.spread_after = math.sqrt(after / count)
    return proposal
end
-- }}}

-- {{{ Repricing.cost_under
-- A template's points with the proposal's factors applied to each part
-- it pays for (unrounded, to compare proposals).
function Repricing.cost_under(template, proposal)
    local total = 0
    for key, points in pairs(parts_of(template)) do
        local factor = proposal.factors[key] and proposal.factors[key].factor or 1
        total = total + points * factor
    end
    return total
end
-- }}}

-- {{{ Repricing.suggested_prices
-- The prices the factors would give, next to today's, for the parts
-- that have a single number in src/data/template_costs.lua: a body's
-- cost and a stat's price per unit. Abilities are priced by a formula,
-- so for them the factor itself is the suggestion. Nothing is written.
function Repricing.suggested_prices(proposal)
    local prices = {provisional = true, bodies = {}, stats = {}, abilities = {}}
    for _, key in ipairs(proposal.order) do
        local kind, name = key:match("^(%a+):(.+)$")
        local factor = proposal.factors[key].factor
        if kind == "body" then
            local now = TemplateCosts.bodies[name].cost
            prices.bodies[name] = {now = now, suggested = now * factor}
        elseif kind == "stat" then
            local now = TemplateCosts.stats[name].per_unit
            prices.stats[name] = {now = now, suggested = now * factor}
        else
            prices.abilities[name] = {factor = factor}
        end
    end
    return prices
end
-- }}}

-- {{{ Repricing.run
-- Measure, calibrate (unless points_per_logit is given), fit. The
-- reference for calibration is options.reference (a template) or the
-- first template.
function Repricing.run(templates, options)
    options = options or {}
    local rows = Repricing.measure(templates, options)
    local per_logit, calibration, note = option(options, "points_per_logit"), nil, nil
    if not per_logit then
        per_logit, calibration, note = Repricing.calibrate(options.reference or templates[1], templates, options)
    end
    local fit_options = {}
    for key, value in pairs(options) do
        fit_options[key] = value
    end
    fit_options.points_per_logit = per_logit
    local proposal = Repricing.fit(rows, fit_options)
    proposal.calibration = calibration
    proposal.reference = (options.reference or templates[1]).name
    proposal.calibration_note = note
    proposal.seed = option(options, "seed")
    proposal.battles = option(options, "battles")
    return proposal
end
-- }}}

-- {{{ local function number
local function number(value)
    return string.format("%.2f", value)
end
-- }}}

-- {{{ Repricing.lines
-- The proposal in words, every line marked provisional.
function Repricing.lines(proposal)
    local out = {}
    local function say(text, ...)
        table.insert(out, Repricing.MARK .. " " .. string.format(text, ...))
    end
    say("Suggested repricing from the balance harness. NOT applied: src/data/template_costs.lua is unchanged.")
    say("The harness walks units straight at each other, not along lanes; tune only once issue 067 gives real matches.")
    say("seed %s, %s battles a matchup, %s points per log-odds of winning%s", tostring(proposal.seed or "?"),
        tostring(proposal.battles or "?"), number(proposal.points_per_logit),
        proposal.calibration_note and " (fallback)" or proposal.calibration and " (measured)" or " (given)")
    if proposal.calibration_note then
        say("note: %s", proposal.calibration_note)
    end
    for _, step in ipairs(proposal.calibration or {}) do
        say("  calibration: %s +%d health: %5.1f%% against the field", proposal.reference or "reference",
            step.health, step.win_rate * 100)
    end
    say("Templates (win rate, 95%% interval, points used -> fair cost):")
    local rows = {}
    for _, row in ipairs(proposal.templates) do
        table.insert(rows, row)
    end
    table.sort(rows, function(a, b)
        if a.gap ~= b.gap then
            return a.gap > b.gap
        end
        return a.name < b.name
    end)
    for _, row in ipairs(rows) do
        local low, high = AbilityBalance.wilson(row.score, row.battles)
        say("  %-18s %5.1f%% (%4.1f-%4.1f%%)  %3d -> %6.1f  (%+.1f)", row.name, row.score / row.battles * 100,
            low * 100, high * 100, row.points_used, row.fair_cost, row.gap)
    end
    say("Price factors (1.00 = no change; held parts had too little evidence):")
    for _, key in ipairs(proposal.order) do
        local factor = proposal.factors[key]
        say("  %-30s x%s  from %d template(s)%s", key, number(factor.factor), factor.templates,
            factor.moved and "" or ", held")
    end
    local prices = Repricing.suggested_prices(proposal)
    for _, name in ipairs(sorted_keys(prices.stats)) do
        local price = prices.stats[name]
        say("  stat %-14s %s -> %s points per unit", name, number(price.now), number(price.suggested))
    end
    for _, name in ipairs(sorted_keys(prices.bodies)) do
        local price = prices.bodies[name]
        say("  body %-14s %s -> %s points", name, number(price.now), number(price.suggested))
    end
    say("Spread of fair cost minus price: %s before, %s after.", number(proposal.spread_before),
        number(proposal.spread_after))
    return out
end
-- }}}

return Repricing
-- }}}
