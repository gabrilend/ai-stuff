-- {{{ Ability library
-- The abilities a player can put on a unit template, with what each
-- does in words, how it can be tuned, and what it costs. Built from the
-- ability templates (src/data/ability_templates.lua), so every ability
-- here is one the game already runs; prices come from
-- UnitTemplate.ability_cost, so the cost shown is the cost charged.
--
--   AbilityLibrary:new()
--   library:get(id)                    an entry (see below), or nil
--   library:search(query, filters)     entries, best match first;
--                                      filters: category, subcategory,
--                                      tag, primary_only, max_cost
--   library:categories()
--   library:limits(id)                 property -> {min, max, base}
--   library:create_config(id, changes) a config with changes held inside
--                                      their limits, and notes of any
--                                      that were moved
--   library:cost(id, changes, is_primary)
--
-- An entry: {id, name, description, category (the ability's kind),
-- subcategory (melee, ranged, over_time, burst, zone or support), tags,
-- customizable (property names, in order), base (the template's own
-- values of those properties), can_be_primary}.
local AbilityLibrary = {}
AbilityLibrary.__index = AbilityLibrary

local AbilityTemplates = require("src.data.ability_templates")
local AbilityFactory = require("src.factories.ability_factory")
local Ability = require("src.components.ability")
local TemplateConstraints = require("src.data.template_constraints")

-- What each ability does, in a line, for players.
AbilityLibrary.DESCRIPTIONS = {
    primary_melee_attack = "A steady sword strike on the nearest enemy.",
    primary_ranged_attack = "A bow shot at the weakest enemy in sight; may miss, weaker at long range.",
    axe_attack = "A heavy axe blow that cleaves a second enemy beside the first.",
    dagger_attack = "Quick, light stabs with a chance of a critical hit.",
    spear_attack = "A long thrust that runs through to the enemy behind.",
    crossbow_attack = "Slow, heavy, accurate bolts that pierce a little armor.",
    sling_attack = "Fast, light stones; often miss.",
    javelin_attack = "A heavy throw at short range.",
    power_strike = "A crushing blow that can land a critical hit; charges only with an enemy in reach.",
    piercing_shot = "An arrow through up to three enemies in a line; charges only while standing still.",
    minor_heal = "Heals the most hurt ally, more so when they are badly hurt.",
    emergency_heal = "A big heal kept for an ally below 30% health.",
    regeneration = "Heals an ally a little every second for eight seconds.",
    purifying_touch = "A small heal that also removes the ally's debuffs.",
    battle_fury = "Allies hit harder; stacks up to three times.",
    protective_ward = "Adds armor and magic resist to an ally; charges with two allies near.",
    focus = "Shortens the unit's own cooldowns for a while.",
    poison_dart = "A dart whose poison deals damage over five seconds, through armor.",
    crippling_blow = "Slows an enemy by 40%.",
    stunning_bash = "Stuns an enemy for a moment.",
    sunder_armor = "Strips 20 armor from an enemy.",
    weakness_curse = "An enemy hits and heals 30% weaker.",
    meteor_strike = "Damages every enemy in a circle; waits for two enemies in reach.",
    healing_circle = "Heals every ally in a circle; waits for two allies in reach.",
    static_field = "Leaves a field that burns and slows enemies for six seconds."
}

-- Which properties a player may tune, by ability kind, and how far from
-- the template's own value: a factor range around it, inside the hard
-- limits of src/data/template_constraints.lua.
AbilityLibrary.TUNABLE = {
    damage = {"power", "range", "mana_rate"},
    heal = {"power", "range", "mana_rate"},
    buff = {"duration", "range", "mana_rate"},
    debuff = {"duration", "range", "mana_rate"},
    area = {"power", "area_radius", "range", "mana_rate"}
}
AbilityLibrary.FACTORS = {
    power = {0.5, 1.5},
    range = {0.5, 1.5},
    mana_rate = {0.5, 2.0},
    duration = {0.5, 2.0},
    area_radius = {0.5, 1.5}
}

-- {{{ local function subcategory_of
local function subcategory_of(ability)
    if (ability.zone_duration or 0) > 0 then
        return "zone"
    elseif ability.damage_over_time > 0 or ability.heal_over_time > 0 then
        return "over_time"
    elseif ability.type == "area" then
        return "burst"
    elseif ability.delivery == "projectile" then
        return "ranged"
    elseif ability.type == "damage" then
        return ability.range <= 20 and "melee" or "ranged"
    end
    return "support"
end
-- }}}

-- {{{ local function tags_of
local function tags_of(id, ability)
    local tags = {}
    if id:find("^primary_") or (ability.weapon_type and ability.type == "damage" and #ability.generation_conditions == 0) then
        table.insert(tags, "weapon")
    end
    if ability.weapon_type then
        table.insert(tags, ability.weapon_type)
    end
    if (ability.cleave_targets or 0) > 0 then table.insert(tags, "cleave") end
    if ability.pierce > 1 then table.insert(tags, "pierce") end
    if (ability.critical_chance or 0) > 0 then table.insert(tags, "critical") end
    if ability.stun then table.insert(tags, "stun") end
    if ability.cleanse then table.insert(tags, "cleanse") end
    if ability.cooldown > 0 then table.insert(tags, "cooldown") end
    local modifiers = ability.modifiers or ability.zone_modifiers or {}
    if (modifiers.speed or 0) < 0 then table.insert(tags, "slow") end
    if #ability.generation_conditions > 0 or #ability.activation_conditions > 0 then
        table.insert(tags, "conditional")
    end
    return tags
end
-- }}}

-- {{{ local function display_name
local function display_name(id)
    return (id:gsub("_", " "):gsub("(%a)(%w*)", function(first, rest) return first:upper() .. rest end))
end
-- }}}

-- {{{ AbilityLibrary:new
function AbilityLibrary:new()
    local library = {entries = {}, order = {}}
    setmetatable(library, self)
    for _, id in ipairs(AbilityFactory.template_names()) do
        library:register(id)
    end
    return library
end
-- }}}

-- {{{ AbilityLibrary:register
-- Adds an ability template to the library by its name.
function AbilityLibrary:register(id)
    local ability = AbilityFactory.create(id)
    local customizable = {}
    local base = {}
    for _, property in ipairs(AbilityLibrary.TUNABLE[ability.type] or {}) do
        table.insert(customizable, property)
        base[property] = ability[property]
    end
    local entry = {
        id = id,
        name = display_name(id),
        description = AbilityLibrary.DESCRIPTIONS[id] or "",
        category = ability.type,
        subcategory = subcategory_of(ability),
        tags = tags_of(id, ability),
        customizable = customizable,
        base = base,
        can_be_primary = ability.type == "damage" or ability.type == "heal"
    }
    if not self.entries[id] then
        table.insert(self.order, id)
    end
    self.entries[id] = entry
    return entry
end
-- }}}

-- {{{ AbilityLibrary:get
function AbilityLibrary:get(id)
    return self.entries[id]
end
-- }}}

-- {{{ AbilityLibrary:categories
function AbilityLibrary:categories()
    local seen, list = {}, {}
    for _, id in ipairs(self.order) do
        local category = self.entries[id].category
        if not seen[category] then
            seen[category] = true
            table.insert(list, category)
        end
    end
    table.sort(list)
    return list
end
-- }}}

-- {{{ AbilityLibrary:limits
-- property -> {min, max, base} for each tunable property: the factor
-- range around the template's value, inside the hard limits.
function AbilityLibrary:limits(id)
    local entry = self.entries[id]
    if not entry then
        return nil
    end
    local hard = TemplateConstraints.abilities
    local caps = {
        power = {0, hard.max_power},
        range = {1, hard.max_range},
        mana_rate = {hard.min_mana_rate, hard.max_mana_rate},
        duration = {0.5, hard.max_duration},
        area_radius = {1, hard.max_area_radius}
    }
    local limits = {}
    for _, property in ipairs(entry.customizable) do
        local base = entry.base[property]
        local factors = AbilityLibrary.FACTORS[property]
        local cap = caps[property]
        local low = math.max(cap[1], base * factors[1])
        local high = math.min(cap[2], base * factors[2])
        limits[property] = {min = math.min(low, base), max = math.max(high, base), base = base}
    end
    return limits
end
-- }}}

-- {{{ AbilityLibrary:clean_changes
-- Keeps only tunable properties, held inside their limits; drops any
-- equal to the template's own value. Returns changes and notes (what
-- was moved or refused, in words).
function AbilityLibrary:clean_changes(id, changes)
    local limits = self:limits(id)
    local clean, notes = {}, {}
    local keys = {}
    for key in pairs(changes or {}) do
        table.insert(keys, key)
    end
    table.sort(keys)
    for _, property in ipairs(keys) do
        local value = changes[property]
        local limit = limits and limits[property]
        if not limit then
            table.insert(notes, string.format("%s can't be changed on %s", property, id))
        elseif type(value) ~= "number" or value ~= value then
            table.insert(notes, string.format("%s must be a number", property))
        else
            local held = math.max(limit.min, math.min(limit.max, value))
            if held ~= value then
                table.insert(notes, string.format("%s %g was held to %g (allowed %g-%g)", property, value, held,
                    limit.min, limit.max))
            end
            if held ~= limit.base then
                clean[property] = held
            end
        end
    end
    return clean, notes
end
-- }}}

-- {{{ AbilityLibrary:create_config
-- The ability's config with the changes applied (held to their limits).
-- Returns config, the cleaned changes and notes; nil and a note for an
-- unknown id.
function AbilityLibrary:create_config(id, changes)
    if not self.entries[id] then
        return nil, nil, {"No ability named " .. tostring(id)}
    end
    local clean, notes = self:clean_changes(id, changes)
    return AbilityFactory.create_config(id, clean), clean, notes
end
-- }}}

-- {{{ AbilityLibrary:cost
-- Points the ability would cost on a template, with these changes, as a
-- primary or not.
function AbilityLibrary:cost(id, changes, is_primary)
    local UnitTemplate = require("src.data.unit_template")
    local config = self:create_config(id, changes)
    if not config then
        return nil
    end
    return UnitTemplate.ability_cost(Ability.new(config), is_primary)
end
-- }}}

-- {{{ AbilityLibrary:search
-- Entries matching every word of the query (in the name, id,
-- description, category, subcategory or tags), best first: a name match
-- before a tag match before a description match, then by name.
-- filters: category, subcategory, tag, primary_only (abilities that can
-- be a primary), max_cost (as a secondary unless primary_only).
function AbilityLibrary:search(query, filters)
    filters = filters or {}
    query = tostring(query or ""):lower()
    local words = {}
    for word in query:gmatch("%S+") do
        table.insert(words, word)
    end
    local results = {}
    for _, id in ipairs(self.order) do
        local entry = self.entries[id]
        local keep = true
        if filters.category and entry.category ~= filters.category then keep = false end
        if filters.subcategory and entry.subcategory ~= filters.subcategory then keep = false end
        if filters.primary_only and not entry.can_be_primary then keep = false end
        if keep and filters.tag then
            local has = false
            for _, tag in ipairs(entry.tags) do
                if tag == filters.tag then has = true end
            end
            keep = has
        end
        if keep and filters.max_cost then
            keep = self:cost(id, nil, filters.primary_only == true) <= filters.max_cost
        end
        local score = 0
        if keep then
            for _, word in ipairs(words) do
                local best = 0
                if entry.name:lower():find(word, 1, true) or id:find(word, 1, true) then
                    best = 3
                else
                    for _, text in ipairs({entry.category, entry.subcategory, table.concat(entry.tags, " ")}) do
                        if best < 2 and text:find(word, 1, true) then
                            best = 2
                        end
                    end
                    if best < 1 and entry.description:lower():find(word, 1, true) then
                        best = 1
                    end
                end
                if best == 0 then
                    keep = false
                    break
                end
                score = score + best
            end
        end
        if keep then
            table.insert(results, {entry = entry, score = score})
        end
    end
    table.sort(results, function(a, b)
        if a.score ~= b.score then
            return a.score > b.score
        end
        return a.entry.name < b.entry.name
    end)
    local entries = {}
    for index, row in ipairs(results) do
        entries[index] = row.entry
    end
    return entries
end
-- }}}

return AbilityLibrary
-- }}}
