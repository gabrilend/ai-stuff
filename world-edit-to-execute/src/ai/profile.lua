--[[
AI Profiles: the AI Editor's Model (Issue 521c)

WC3's AI Editor saves a .wai file and compiles it into a .ai script. A
profile here holds what its tabs hold, as a Lua table: a file per
computer player that anyone can open and edit, as the editor's panels
would. ai/editor_ai.lua plays one.

    General     name, race, options (the editor's checkboxes: melee,
                defend users, random paths, target heroes, repair
                structures, heroes flee, units flee, groups flee, have
                no mercy, ignore injured, take items, buy items, slow
                harvesting, smart artillery), harvest (workers on gold
                and lumber), targets (the target priorities)
    Heroes      the heroes to pick, in order, each with its skill order
    Build       the build priorities: what to have, in order, each with
                an optional condition
    Groups      attack groups: which units, how many, each with an
                optional condition
    Waves       attack waves: which group each wave sends, the delay
                before the first, between waves and where to start
                again after the last
    Conditions  named conditions the rest can use

The AI Editor's own tabs are described from memory of the tool and from
modding guides, not from its files; where a field here has no editor
counterpart the comment says so.

    local profile = require("ai.profile")
    local p = profile.normalize(dofile("ai-profiles/MAP/p03.lua"))
    profile.test(p, "early", ai)       -- a named condition, for an AI
    print(profile.serialize(p))        -- back to an editable file
]]

local profile = {}

-- {{{ Defaults
profile.DEFAULT = {
    name = "Computer",
    race = "custom",          -- human | orc | undead | nightelf | custom
    options = {},             -- over ai/player.lua's OPTIONS
    harvest = { gold = 5, lumber = 3 },
    targets = {               -- first whose condition holds and exists
        { kind = "enemy_near_home" },
        { kind = "enemy_base" },
    },
    heroes = {},              -- { { id = "Hpal", skills = { "AHhb", ... } }, ... }
    build = {},               -- { { kind = "unit" | "hero" | "upgrade" | "expansion", id = , count = , condition = }, ... }
    groups = {},              -- name -> { { id = , count = , condition = }, ... }
    waves = {
        initial_delay = 180,  -- seconds before the first wave forms
        delay = 60,           -- seconds between waves
        repeat_from = 1,      -- after the last wave, start again here
        max_wait = 90,        -- a wave goes once it's waited this long with
        min_fraction = 0.6,   -- at least this much of its group (no editor counterpart)
        list = {},            -- { { group = "main", condition = }, ... }
    },
    conditions = {},          -- name -> condition (see below)
}

local function copy(t)
    if type(t) ~= "table" then return t end
    local o = {}
    for k, v in pairs(t) do o[k] = copy(v) end
    return o
end

-- A profile with every section filled in
function profile.normalize(p)
    p = copy(p or {})
    for k, v in pairs(profile.DEFAULT) do
        if p[k] == nil then p[k] = copy(v) end
    end
    for k, v in pairs(profile.DEFAULT.waves) do
        if p.waves[k] == nil then p.waves[k] = copy(v) end
    end
    return p
end
-- }}}

-- {{{ Conditions
--[[
A condition is one of:
    "name"                             a named condition from the profile
    function(ai, state) ... end        Lua (not saved by serialize)
    { "and", c1, c2, ... }  { "or", ... }  { "not", c }
    { "game_time", op, seconds }       time since the game began
    { "wave", op, n }                  the current attack wave number
    { "difficulty", op, "easy"|"normal"|"insane" }
    { "count", id, op, n }             units of id, those in training too
    { "count_done", id, op, n }        finished units of id
    { "army", op, n }                  fighting units owned
    { "gold", op, n }  { "lumber", op, n }  { "food", op, n }  { "food_cap", op, n }
    { "hero_level", slot, op, n }      the level of the hero picked in slot
    { "towns", op, n }                 halls owned
    { "enemies_near_home", op, n }
    { "command", cmd }                 a CommandAI command waiting (then taken)
op is one of < <= == ~= >= >. The AI Editor's condition functions
(difficulty, game time, attack wave, unit counts, town count) map onto
these; the rest are ours.
]]
local OPS = {
    ["<"] = function(a, b) return a < b end, ["<="] = function(a, b) return a <= b end,
    ["=="] = function(a, b) return a == b end, ["~="] = function(a, b) return a ~= b end,
    ["!="] = function(a, b) return a ~= b end, [">="] = function(a, b) return a >= b end,
    [">"] = function(a, b) return a > b end,
}
local DIFFICULTY = { easy = 1, normal = 2, insane = 3 }

local function compare(a, op, b)
    local f = OPS[op]
    if not f then error("unknown comparison " .. tostring(op)) end
    return f(a, b)
end

-- state: { wave = n, heroes = { unit per slot } } from the runner
function profile.test(p, c, ai, state, depth)
    depth = (depth or 0) + 1
    if depth > 20 then error("conditions nest too deep (a loop?)") end
    if c == nil then return true end
    local t = type(c)
    if t == "boolean" then return c end
    if t == "function" then return c(ai, state) and true or false end
    if t == "string" then
        local named = p.conditions[c]
        if named == nil then error("no condition named " .. c) end
        return profile.test(p, named, ai, state, depth)
    end
    local k = c[1]
    state = state or {}
    local g = ai.game
    if k == "and" then
        for i = 2, #c do if not profile.test(p, c[i], ai, state, depth) then return false end end
        return true
    elseif k == "or" then
        for i = 2, #c do if profile.test(p, c[i], ai, state, depth) then return true end end
        return false
    elseif k == "not" then
        return not profile.test(p, c[2], ai, state, depth)
    elseif k == "game_time" then return compare(g.time, c[2], c[3])
    elseif k == "wave" then return compare(state.wave or 0, c[2], c[3])
    elseif k == "difficulty" then
        return compare(DIFFICULTY[ai.difficulty] or 2, c[2], DIFFICULTY[c[3]] or 2)
    elseif k == "count" then return compare(ai:count(c[2]), c[3], c[4])
    elseif k == "count_done" then return compare(ai:count_done(c[2]), c[3], c[4])
    elseif k == "army" then return compare(#ai:army(), c[2], c[3])
    elseif k == "gold" then return compare(g.purse(ai.player).gold or 0, c[2], c[3])
    elseif k == "lumber" then return compare(g.purse(ai.player).lumber or 0, c[2], c[3])
    elseif k == "food" or k == "food_cap" then
        local used, cap = g.food(ai.player)
        return compare(k == "food" and used or cap, c[2], c[3])
    elseif k == "hero_level" then
        local h = state.heroes and state.heroes[c[2]]
        return compare(h and h.alive ~= false and (h.level or 1) or 0, c[3], c[4])
    elseif k == "towns" then
        return compare(#ai:units(function(u) return u.spec.size == "hall" end), c[2], c[3])
    elseif k == "enemies_near_home" then
        local n = 0
        local r2 = 1800 * 1800
        for _, u in ipairs(g.units) do
            if u.alive ~= false and u.player ~= ai.player and u.player < 13
                and (u.x - ai.home.x) ^ 2 + (u.y - ai.home.y) ^ 2 < r2
                and (u.player == 12 or not g.allied or not g.allied(ai.player, u.player)) then
                n = n + 1
            end
        end
        return compare(n, c[2], c[3])
    elseif k == "command" then
        for i = #ai.commands, 1, -1 do
            if ai.commands[i][1] == c[2] then
                table.remove(ai.commands, i)
                return true
            end
        end
        return false
    end
    error("unknown condition " .. tostring(k))
end
-- }}}

-- {{{ profile.check
-- Problems with a profile, as messages (empty when it's sound): unknown
-- conditions, waves naming groups that don't exist, entries without ids
function profile.check(p)
    p = profile.normalize(p)
    local problems = {}
    local function cond(c, where)
        if type(c) == "string" and p.conditions[c] == nil then
            problems[#problems + 1] = where .. ": no condition named " .. c
        elseif type(c) == "table" then
            for i = 2, #c do if type(c[i]) == "table" or (c[1] == "and" or c[1] == "or" or c[1] == "not") then cond(c[i], where) end end
        end
    end
    for i, b in ipairs(p.build) do
        if (b.kind or "unit") ~= "expansion" and (b.kind or "unit") ~= "hero" and not b.id then
            problems[#problems + 1] = "build " .. i .. ": no id"
        end
        cond(b.condition, "build " .. i)
    end
    for i, w in ipairs(p.waves.list) do
        if not p.groups[w.group] then problems[#problems + 1] = "wave " .. i .. ": no group named " .. tostring(w.group) end
        cond(w.condition, "wave " .. i)
    end
    for name, g in pairs(p.groups) do
        for i, e in ipairs(g) do
            if not e.id then problems[#problems + 1] = "group " .. name .. " " .. i .. ": no id" end
            cond(e.condition, "group " .. name .. " " .. i)
        end
    end
    for i, t in ipairs(p.targets) do cond(t.condition, "target " .. i) end
    return problems
end
-- }}}

-- {{{ profile.serialize
-- A profile as the text of a Lua file that returns it: sections in the
-- AI Editor's tab order with the tab named, short records on one line
-- (functions are left out: they can't be written back)
local KEY_ORDER = { kind = 1, slot = 2, group = 3, id = 4, count = 5, condition = 6, skills = 7 }

local function key_text(k)
    if type(k) == "string" and k:match("^[%a_][%w_]*$") then return k end
    return "[" .. string.format("%q", k) .. "]"
end

local function sorted_keys(v, n)
    local keys = {}
    for k in pairs(v) do
        if not (type(k) == "number" and k >= 1 and k <= n and k % 1 == 0) and type(v[k]) ~= "function" then
            keys[#keys + 1] = k
        end
    end
    table.sort(keys, function(a, b)
        local oa, ob = KEY_ORDER[a] or 99, KEY_ORDER[b] or 99
        if oa ~= ob then return oa < ob end
        return tostring(a) < tostring(b)
    end)
    return keys
end

local value_text
-- one line, if it fits and holds no records
local function inline(v)
    if type(v) ~= "table" then return value_text(v, 0) end
    local n = #v
    local parts = {}
    for i = 1, n do
        local x = v[i]
        if type(x) == "table" then
            for _, y in pairs(x) do if type(y) == "table" then return nil end end
            local sub = inline(x)
            if not sub then return nil end
            parts[#parts + 1] = sub
        else
            parts[#parts + 1] = value_text(x, 0)
        end
    end
    for _, k in ipairs(sorted_keys(v, n)) do
        local sub = inline(v[k])
        if not sub then return nil end
        parts[#parts + 1] = key_text(k) .. " = " .. sub
    end
    if #parts == 0 then return "{}" end
    local text = "{ " .. table.concat(parts, ", ") .. " }"
    return #text <= 96 and text or nil
end

local name_of   -- id -> display name, while serializing (for comments)

value_text = function(v, indent)
    local t = type(v)
    if t == "string" then return string.format("%q", v) end
    if t == "number" or t == "boolean" then return tostring(v) end
    if t ~= "table" then return "nil" end
    local one = inline(v)
    if one and #one + indent * 4 <= 100 and not (name_of and #v > 0 and type(v[1]) == "table" and v[1].id) then
        return one
    end
    local pad = string.rep("    ", indent + 1)
    local lines, n = {}, #v
    for i = 1, n do
        local line = value_text(v[i], indent + 1) .. ","
        local id = type(v[i]) == "table" and v[i].id
        local label = id and name_of and name_of(id)
        if label and label ~= id then line = line .. "   -- " .. label:gsub("\n", " ") end
        lines[#lines + 1] = line
    end
    for _, k in ipairs(sorted_keys(v, n)) do
        lines[#lines + 1] = key_text(k) .. " = " .. value_text(v[k], indent + 1) .. ","
    end
    return "{\n" .. pad .. table.concat(lines, "\n" .. pad) .. "\n" .. string.rep("    ", indent) .. "}"
end

profile.SECTIONS = {
    { "name", "General" }, { "race" }, { "options" }, { "harvest" }, { "targets", "General: target priorities" },
    { "heroes", "Heroes" }, { "build", "Build Priorities" }, { "groups", "Attack Groups" },
    { "waves", "Attack Waves" }, { "conditions", "Conditions" },
}

-- names: optional function(id) -> display name, written as comments
function profile.serialize(p, header, names)
    name_of = names
    local out = {}
    if header then out[#out + 1] = "-- " .. header:gsub("\n", "\n-- ") end
    out[#out + 1] = "return {"
    local done = {}
    for _, sec in ipairs(profile.SECTIONS) do
        local k = sec[1]
        done[k] = true
        if p[k] ~= nil then
            if sec[2] then out[#out + 1] = "    -- " .. sec[2] end
            out[#out + 1] = "    " .. key_text(k) .. " = " .. value_text(p[k], 1) .. ","
        end
    end
    for _, k in ipairs(sorted_keys(p, 0)) do
        if not done[k] then out[#out + 1] = "    " .. key_text(k) .. " = " .. value_text(p[k], 1) .. "," end
    end
    out[#out + 1] = "}"
    name_of = nil
    return table.concat(out, "\n") .. "\n"
end
-- }}}

return profile
