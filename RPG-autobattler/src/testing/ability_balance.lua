-- {{{ Ability balance harness
-- Runs small headless battles between units carrying ability sets (from
-- src/data/ability_templates.lua) with every ability system running, and
-- turns many of them into win rates, confidence intervals and plain
-- advice. Nothing is drawn; it runs under luajit or lua5.4 alone.
--
-- A battle: two teams stand in columns some way apart. Each step, a unit
-- with no enemy within its first ability's reach walks toward the
-- nearest enemy at its speed (slows count, stuns hold it); the others
-- stand and fight. The mana, targeting, activation, cooldown, effect and
-- over-time systems do the rest. The battle ends when one side has no
-- one standing or time runs out (a draw).
--
-- The walking is a stand-in for lane following, enough to bring melee
-- into reach and let ranged units fire from further off. It isn't the
-- game's movement, so results compare sets with each other rather than
-- predict real matches.
--
--   AbilityBalance.run_battle(options)    one battle; see the function
--   AbilityBalance.matchup(a, b, options) many battles, sides swapped
--                                         every other one
--   AbilityBalance.round_robin(sets, options)
--   AbilityBalance.report(round, options) advice from a round robin
--   AbilityBalance.wilson(wins, n)        a 95% interval for a rate
local AbilityBalance = {}

local EntityManager = require("src.systems.entity_manager")
local Unit = require("src.entities.unit")
local ManaSystem = require("src.systems.mana_system")
local TargetingSystem = require("src.systems.targeting_system")
local AbilityActivationSystem = require("src.systems.ability_activation_system")
local AbilityEffectSystem = require("src.systems.ability_effect_system")
local PersistentEffectsSystem = require("src.systems.persistent_effects_system")
local AbilityFactory = require("src.factories.ability_factory")

-- The unit body each set is carried by, when the roster doesn't say.
AbilityBalance.UNIT_TYPE_FOR_SET = {
    basic_warrior = "melee", basic_archer = "ranged", support_cleric = "support",
    battle_mage = "special", brute = "tank", druid = "support", skirmisher = "ranged",
    berserker = "melee", crossbowman = "ranged", field_medic = "support", storm_caller = "special"
}

AbilityBalance.DEFAULTS = {
    team_size = 4,
    gap = 70,            -- distance between the two columns
    spacing = 10,        -- distance between units in a column
    jitter = 4,          -- random shift of each starting place
    dt = 0.1,
    max_time = 60,
    battles = 20,
    dominant = 0.65,     -- an overall win rate above this is flagged
    weak = 0.35          -- and below this
}

-- {{{ local function option
local function option(options, key)
    if options and options[key] ~= nil then
        return options[key]
    end
    return AbilityBalance.DEFAULTS[key]
end
-- }}}

-- {{{ AbilityBalance.random_source
-- A seeded generator returning 0-1 (Park and Miller's), exact in both
-- luajit and lua5.4, so a seed gives the same battle in either.
function AbilityBalance.random_source(seed)
    local state = math.floor(seed or 1) % 2147483647
    if state <= 0 then
        state = state + 2147483646
    end
    return function()
        state = (state * 16807) % 2147483647
        return state / 2147483647
    end
end
-- }}}

-- {{{ AbilityBalance.roster
-- A roster from a set name and a count, or a list of set names or
-- {set, unit_type} entries.
function AbilityBalance.roster(spec, count)
    local list = {}
    if type(spec) == "string" then
        for i = 1, count or AbilityBalance.DEFAULTS.team_size do
            list[i] = {set = spec}
        end
    else
        for i, entry in ipairs(spec) do
            list[i] = type(entry) == "string" and {set = entry} or entry
        end
    end
    for _, entry in ipairs(list) do
        entry.unit_type = entry.unit_type or AbilityBalance.UNIT_TYPE_FOR_SET[entry.set] or "melee"
    end
    return list
end
-- }}}

-- {{{ AbilityBalance.new_world
function AbilityBalance.new_world(seed)
    local em = EntityManager:new()
    local random = AbilityBalance.random_source(seed)
    local effects = AbilityEffectSystem:new(em, {random = random})
    local world = {
        em = em,
        random = random,
        mana = ManaSystem:new(em),
        targeting = TargetingSystem:new(em),
        effects = effects,
        persistent = PersistentEffectsSystem:new(em, effects),
        units = {[1] = {}, [2] = {}},
        reach = {},
        set_of = {},
        time = 0,
        casts = {},          -- ability name -> times fired
        damage_by_team = {[1] = 0, [2] = 0},
        healing_by_team = {[1] = 0, [2] = 0}
    }
    world.activation = AbilityActivationSystem:new(em, {targeting = world.targeting, effect_system = effects})
    return world
end
-- }}}

-- {{{ AbilityBalance.add_team
-- Places a roster in a column at x, centred on y = 0.
function AbilityBalance.add_team(world, team, roster, x, options)
    local spacing = option(options, "spacing")
    local jitter = option(options, "jitter")
    local top = -(#roster - 1) * spacing / 2
    for i, entry in ipairs(roster) do
        local ux = x + (world.random() * 2 - 1) * jitter
        local uy = top + (i - 1) * spacing + (world.random() * 2 - 1) * jitter
        local unit = Unit.create_basic_unit(world.em, ux, uy, team, entry.unit_type)
        local container = AbilityFactory.attach_set(world.em, unit, entry.set)
        table.insert(world.units[team], unit)
        world.reach[unit] = container.abilities[1] and container.abilities[1].range or 15
        world.set_of[unit] = entry.set
    end
end
-- }}}

-- {{{ AbilityBalance.living
function AbilityBalance.living(world, team)
    local count, health = 0, 0
    for _, unit in ipairs(world.units[team]) do
        if Unit.is_alive(world.em, unit) then
            count = count + 1
            health = health + world.em:get_component(unit, "health").current_hp
        end
    end
    return count, health
end
-- }}}

-- {{{ local function stunned
local function stunned(em, unit)
    local effects = em:get_component(unit, "effects")
    if not effects then
        return false
    end
    for _, effect in pairs(effects.active) do
        if effect.stun then
            return true
        end
    end
    return false
end
-- }}}

-- {{{ AbilityBalance.move_units
-- Walks each unit with no enemy in reach toward its nearest enemy.
function AbilityBalance.move_units(world, dt)
    local em = world.em
    for team = 1, 2 do
        local foes = world.units[3 - team]
        for _, unit in ipairs(world.units[team]) do
            local moveable = em:get_component(unit, "moveable")
            moveable.velocity_x, moveable.velocity_y = 0, 0
            if Unit.is_alive(em, unit) and not stunned(em, unit) then
                local pos = em:get_component(unit, "position")
                local nearest, nearest_sq
                for _, foe in ipairs(foes) do
                    if Unit.is_alive(em, foe) then
                        local fpos = em:get_component(foe, "position")
                        local dx, dy = fpos.x - pos.x, fpos.y - pos.y
                        local d_sq = dx * dx + dy * dy
                        if not nearest_sq or d_sq < nearest_sq then
                            nearest, nearest_sq = fpos, d_sq
                        end
                    end
                end
                local reach = world.reach[unit] * 0.9
                if nearest and nearest_sq > reach * reach then
                    local distance = math.sqrt(nearest_sq)
                    local step = math.min(moveable.speed * dt, distance - reach)
                    local nx, ny = (nearest.x - pos.x) / distance, (nearest.y - pos.y) / distance
                    pos.x, pos.y = pos.x + nx * step, pos.y + ny * step
                    moveable.velocity_x, moveable.velocity_y = nx * step / dt, ny * step / dt
                end
            end
        end
    end
end
-- }}}

-- {{{ AbilityBalance.tally
-- Adds the effect system's damage and healing cues to each team's total.
function AbilityBalance.tally(world)
    local em = world.em
    for _, cue in ipairs(world.effects:pop_cues()) do
        if (cue.kind == "damage" or cue.kind == "heal") and cue.caster then
            local team = em:get_component(cue.caster, "team")
            team = team and team.player_id
            if team == 1 or team == 2 then
                local totals = cue.kind == "damage" and world.damage_by_team or world.healing_by_team
                totals[team] = totals[team] + (cue.amount or 0)
            end
        end
    end
end
-- }}}

-- {{{ AbilityBalance.step
function AbilityBalance.step(world, dt)
    AbilityBalance.move_units(world, dt)
    world.mana:update(dt)
    world.activation:update(dt)
    world.effects:update(dt)
    world.persistent:update(dt)
    world.targeting:invalidate()
    for _, event in ipairs(world.activation:pop_events()) do
        local name = event.ability.name
        world.casts[name] = (world.casts[name] or 0) + 1
    end
    AbilityBalance.tally(world)
    world.time = world.time + dt
end
-- }}}

-- {{{ AbilityBalance.run_battle
-- options: team_a, team_b (rosters: a set name, a list of set names or
-- {set, unit_type} entries), team_size (for a set name), seed, gap,
-- spacing, jitter, dt, max_time.
-- Returns {winner (1, 2, or 0 for a draw), time, survivors = {n1, n2},
-- health_left = {h1, h2}, damage = {d1, d2}, healing = {h1, h2},
-- activations, casts (ability name -> times fired)}; with keep_world,
-- also the world itself.
function AbilityBalance.run_battle(options)
    local size = option(options, "team_size")
    local world = AbilityBalance.new_world(options.seed or 1)
    local gap = option(options, "gap")
    AbilityBalance.add_team(world, 1, AbilityBalance.roster(options.team_a, size), 0, options)
    AbilityBalance.add_team(world, 2, AbilityBalance.roster(options.team_b, size), gap, options)

    local dt, max_time = option(options, "dt"), option(options, "max_time")
    local alive_a, alive_b = AbilityBalance.living(world, 1), AbilityBalance.living(world, 2)
    while world.time < max_time - 1e-9 and alive_a > 0 and alive_b > 0 do
        AbilityBalance.step(world, dt)
        alive_a, alive_b = AbilityBalance.living(world, 1), AbilityBalance.living(world, 2)
    end

    local _, health_a = AbilityBalance.living(world, 1)
    local _, health_b = AbilityBalance.living(world, 2)
    local winner = 0
    if alive_a > 0 and alive_b == 0 then
        winner = 1
    elseif alive_b > 0 and alive_a == 0 then
        winner = 2
    end
    return {
        winner = winner,
        time = world.time,
        survivors = {alive_a, alive_b},
        health_left = {health_a, health_b},
        damage = {world.damage_by_team[1], world.damage_by_team[2]},
        healing = {world.healing_by_team[1], world.healing_by_team[2]},
        activations = world.activation.stats.activations,
        casts = world.casts,
        world = options.keep_world and world or nil
    }
end
-- }}}

-- {{{ AbilityBalance.wilson
-- The 95% Wilson score interval for `wins` out of `n`: where the true
-- win rate most likely lies. Returns low, high.
function AbilityBalance.wilson(wins, n)
    if n == 0 then
        return 0, 1
    end
    local z = 1.96
    local p = wins / n
    local denominator = 1 + z * z / n
    local centre = (p + z * z / (2 * n)) / denominator
    local spread = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / denominator
    return math.max(0, centre - spread), math.min(1, centre + spread)
end
-- }}}

-- {{{ AbilityBalance.matchup
-- Many battles between two rosters. Every other battle swaps which side
-- each starts on, so neither gains from the side. Draws count half a win
-- to each. Returns {a, b, battles, wins_a, wins_b, draws, win_rate_a,
-- low, high (95% interval of win_rate_a), average_time, damage_a,
-- damage_b, healing_a, healing_b} (totals over all battles).
function AbilityBalance.matchup(roster_a, roster_b, options)
    options = options or {}
    local battles = option(options, "battles")
    local result = {a = roster_a, b = roster_b, battles = battles, wins_a = 0, wins_b = 0, draws = 0,
        total_time = 0, damage_a = 0, damage_b = 0, healing_a = 0, healing_b = 0}
    for i = 1, battles do
        local swapped = i % 2 == 0
        local battle_options = {}
        for key, value in pairs(options) do
            battle_options[key] = value
        end
        battle_options.seed = (options.seed or 1) * 1000 + i
        battle_options.team_a = swapped and roster_b or roster_a
        battle_options.team_b = swapped and roster_a or roster_b
        local battle = AbilityBalance.run_battle(battle_options)
        local side_a = swapped and 2 or 1
        if battle.winner == 0 then
            result.draws = result.draws + 1
        elseif battle.winner == side_a then
            result.wins_a = result.wins_a + 1
        else
            result.wins_b = result.wins_b + 1
        end
        result.total_time = result.total_time + battle.time
        result.damage_a = result.damage_a + battle.damage[side_a]
        result.damage_b = result.damage_b + battle.damage[3 - side_a]
        result.healing_a = result.healing_a + battle.healing[side_a]
        result.healing_b = result.healing_b + battle.healing[3 - side_a]
    end
    local score = result.wins_a + result.draws / 2
    result.win_rate_a = score / battles
    result.low, result.high = AbilityBalance.wilson(score, battles)
    result.average_time = result.total_time / battles
    return result
end
-- }}}

-- {{{ AbilityBalance.round_robin
-- Every set against every other set (each named once). Returns
-- {sets, matchups (list), table (a -> b -> win rate of a), overall
-- (set -> {score, battles, win_rate, low, high})}.
function AbilityBalance.round_robin(sets, options)
    local round = {sets = sets, matchups = {}, table = {}, overall = {}}
    for _, set in ipairs(sets) do
        round.table[set] = {}
        round.overall[set] = {score = 0, battles = 0}
    end
    for i = 1, #sets do
        for j = i + 1, #sets do
            local a, b = sets[i], sets[j]
            local result = AbilityBalance.matchup(a, b, options)
            table.insert(round.matchups, result)
            round.table[a][b] = result.win_rate_a
            round.table[b][a] = 1 - result.win_rate_a
            local score_a = result.wins_a + result.draws / 2
            round.overall[a].score = round.overall[a].score + score_a
            round.overall[b].score = round.overall[b].score + (result.battles - score_a)
            round.overall[a].battles = round.overall[a].battles + result.battles
            round.overall[b].battles = round.overall[b].battles + result.battles
        end
    end
    for _, set in ipairs(sets) do
        local row = round.overall[set]
        row.win_rate = row.battles > 0 and row.score / row.battles or 0.5
        row.low, row.high = AbilityBalance.wilson(row.score, row.battles)
    end
    return round
end
-- }}}

-- {{{ AbilityBalance.report
-- Advice from a round robin. A set is flagged only when its whole 95%
-- interval lies past a threshold, so a lucky few battles aren't
-- mistaken for a problem. Returns {lines, recommendations}, each
-- recommendation {set, verdict ("dominant", "weak" or "balanced"),
-- win_rate, low, high, advice}.
function AbilityBalance.report(round, options)
    local dominant, weak = option(options, "dominant"), option(options, "weak")
    local lines, recommendations = {}, {}
    table.insert(lines, "Ability set balance (win rate, 95% interval):")
    local order = {}
    for _, set in ipairs(round.sets) do
        table.insert(order, set)
    end
    table.sort(order, function(x, y)
        local rx, ry = round.overall[x].win_rate, round.overall[y].win_rate
        if rx ~= ry then
            return rx > ry
        end
        return x < y
    end)
    for _, set in ipairs(order) do
        local row = round.overall[set]
        local verdict, advice = "balanced", "no change needed"
        if row.low > dominant then
            verdict = "dominant"
            advice = "weaken: lower its primary power or mana rate, or raise its cooldowns"
        elseif row.high < weak then
            verdict = "weak"
            advice = "strengthen: raise its primary power or mana rate, or its reach"
        end
        table.insert(recommendations, {set = set, verdict = verdict, win_rate = row.win_rate,
            low = row.low, high = row.high, advice = advice})
        table.insert(lines, string.format("  %-16s %5.1f%%  (%4.1f-%4.1f%%)  %s: %s", set, row.win_rate * 100,
            row.low * 100, row.high * 100, verdict, advice))
    end
    local lopsided = 0
    for _, result in ipairs(round.matchups) do
        if result.low > 0.9 or result.high < 0.1 then
            lopsided = lopsided + 1
            table.insert(lines, string.format("  one-sided: %s vs %s, %.0f%%", tostring(result.a), tostring(result.b),
                result.win_rate_a * 100))
        end
    end
    return {lines = lines, recommendations = recommendations, lopsided = lopsided}
end
-- }}}

return AbilityBalance
-- }}}
