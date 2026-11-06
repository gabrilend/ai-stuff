-- {{{ Mana efficiency
-- Works out how much of a full mana bar an ability should spend, so that
-- none is wasted, as the vision asks: a blow that would overkill a nearly
-- dead foe spends only the share of mana its needed damage is worth, and a
-- heal on a nearly full ally spends only enough to top them off. The rest
-- stays in the bar and the bar refills from there.
--
-- An ability here is a table with:
--   type         "damage", "heal", "buff", "debuff" or "area"
--   power        the effect at a full bar (damage or healing; per target
--                for "area")
--   max_mana     the bar's size
--   area_effect  for "area": "damage" (default) or "heal"
--   max_targets  for "area": how many targets a full bar is meant for
--                (default 5)
-- A target is a table with current_health, max_health and, for buffs and
-- debuffs, has_effect (true when it already has this one).
--
-- plan() never spends anything; cast() spends what plan() says and records
-- it in a Stats table for balancing.
local ManaEfficiency = {}

local ManaSystem = require("src.systems.mana_system")

-- No cast costs less than this share of the bar, so abilities are never
-- free even when almost nothing is needed.
ManaEfficiency.MINIMUM_SHARE = 0.1
ManaEfficiency.DEFAULT_MAX_TARGETS = 5

-- {{{ local function refuse
local function refuse(reason)
    return {can_execute = false, mana_to_use = 0, effect_power = 0, amount = 0, reason = reason}
end
-- }}}

-- {{{ local function need_of
-- How much of `power` this target can use: damage up to its health,
-- healing up to what it is missing.
local function need_of(effect, target, power)
    if effect == "heal" then
        return math.min(power, math.max(0, target.max_health - target.current_health))
    end
    return math.min(power, math.max(0, target.current_health))
end
-- }}}

-- {{{ local function priced
-- Turns the share of the bar's effect that is needed into a plan.
local function priced(ability, share, available_mana, extra)
    local max_mana = ability.max_mana
    local mana = max_mana * math.max(ManaEfficiency.MINIMUM_SHARE, math.min(1, share))
    local plan = {
        can_execute = available_mana >= mana - 1e-9,
        mana_to_use = mana,
        effect_power = mana / max_mana,
        amount = ability.power * (mana / max_mana),
        needed_share = share,
        reason = nil
    }
    if not plan.can_execute then
        plan.reason = "not_enough_mana"
    end
    for key, value in pairs(extra or {}) do
        plan[key] = value
    end
    return plan
end
-- }}}

-- {{{ ManaEfficiency.plan
-- targets is a list (one entry for single-target abilities).
function ManaEfficiency.plan(ability, targets, available_mana)
    targets = targets or {}
    local target = targets[1]
    local kind = ability.type

    if kind == "damage" or kind == "heal" then
        if not target then
            return refuse("no_target")
        end
        local need = need_of(kind, target, ability.power)
        if need <= 0 then
            return refuse(kind == "heal" and "target_full_health" or "target_dead")
        end
        return priced(ability, need / ability.power, available_mana, {needed = need})

    elseif kind == "buff" or kind == "debuff" then
        if not target then
            return refuse("no_target")
        end
        if target.has_effect then
            return refuse("already_affected")
        end
        return priced(ability, 1, available_mana)

    elseif kind == "area" then
        local effect = ability.area_effect or "damage"
        local max_targets = ability.max_targets or ManaEfficiency.DEFAULT_MAX_TARGETS
        local useful = 0
        local counted = 0
        for _, each in ipairs(targets) do
            if counted >= max_targets then
                break
            end
            counted = counted + 1
            useful = useful + need_of(effect, each, ability.power) / ability.power
        end
        if useful <= 0 then
            return refuse("no_useful_targets")
        end
        return priced(ability, useful / max_targets, available_mana, {targets_hit = counted})
    end

    -- Unknown kinds spend the whole bar, as before this existed.
    return priced(ability, 1, available_mana)
end
-- }}}

-- {{{ ManaEfficiency.new_stats
function ManaEfficiency.new_stats()
    return {
        casts = 0,
        mana_spent = 0,
        mana_saved = 0,      -- full-bar cost minus what was spent
        refused = {},        -- reason -> count
        by_type = {}         -- type -> {casts, mana_spent, mana_saved}
    }
end
-- }}}

-- {{{ ManaEfficiency.record
function ManaEfficiency.record(stats, ability, plan)
    if not plan.can_execute then
        local reason = plan.reason or "unknown"
        stats.refused[reason] = (stats.refused[reason] or 0) + 1
        return
    end
    local saved = ability.max_mana - plan.mana_to_use
    stats.casts = stats.casts + 1
    stats.mana_spent = stats.mana_spent + plan.mana_to_use
    stats.mana_saved = stats.mana_saved + saved

    local row = stats.by_type[ability.type]
    if not row then
        row = {casts = 0, mana_spent = 0, mana_saved = 0}
        stats.by_type[ability.type] = row
    end
    row.casts = row.casts + 1
    row.mana_spent = row.mana_spent + plan.mana_to_use
    row.mana_saved = row.mana_saved + saved
end
-- }}}

-- {{{ ManaEfficiency.cast
-- Plans the ability against the bar's current mana and, if it can go
-- ahead, spends that much from bar `index` of `mana`. Returns the plan;
-- the caller applies plan.amount (damage, healing, or the buff's strength).
function ManaEfficiency.cast(mana, index, ability, targets, stats)
    local bar = mana.bars[index]
    local plan = ManaEfficiency.plan(ability, targets, bar and bar.current or 0)
    if plan.can_execute then
        ManaSystem.spend(mana, index, plan.mana_to_use)
    end
    if stats then
        ManaEfficiency.record(stats, ability, plan)
    end
    return plan
end
-- }}}

return ManaEfficiency
-- }}}
