--[[
Faction AI for Custom Maps (Issue 521d)

Most custom maps don't play like melee: factions start with bases and
armies placed by the script and new units come from what those bases
train. This builds an AI Editor profile (ai/profile.lua) for such a
faction from what it owns when the game starts:

  build     keep the army's own unit types up to their starting numbers
            (the ones its buildings train and the map allows), then more
            of what its buildings offer, cheapest first
  heroes    the heroes it starts with, kept in their slots
  groups    "main": about half of the starting army's types and numbers
  waves     main, again and again, after a first delay
  targets   enemies near home first, then the nearest enemy base

A derived profile is a starting point: faction.write saves one per
computer player as an editable Lua file (the AI Editor's .wai, here),
and faction.load_or_derive prefers the file when there is one.

    local faction = require("ai.faction")
    local p = faction.derive(game, 3)
    faction.write(dir, game, { 1, 2, 3 })         -- ai-profiles/<map>/p01-<name>.lua ...
]]

local profile_mod = require("ai.profile")

local faction = {}

faction.MAX_BUILD_TYPES = 8
faction.KEEP_UP_TO = 12       -- per unit type, whatever the starting army had

-- {{{ faction.derive
function faction.derive(game, player, name)
    local counts, order, heroes = {}, {}, {}
    local trains = {}
    for _, u in ipairs(game.units) do
        if u.player == player and u.alive ~= false and not u.removed then
            if u.spec.design == "building" then
                for _, id in ipairs(game.db.unit_list(u.id, "utra")) do trains[id] = true end
            elseif u.spec.hero then
                heroes[#heroes + 1] = { id = u.id }
            elseif u.weapon and u.spec.archetype ~= "worker" then
                if not counts[u.id] then order[#order + 1] = u.id end
                counts[u.id] = (counts[u.id] or 0) + 1
            end
        end
    end
    table.sort(order, function(a, b) return counts[a] > counts[b] end)

    -- what the map lets it train now (a script may unlock more later;
    -- entries it can't train are passed over, not stuck on)
    local ps = game.script and game.script.players[player]
    local function allowed(id) return not (ps and ps.tech_max[id] == 0) end

    local build, group = {}, {}
    local used = {}
    for _, id in ipairs(order) do
        if trains[id] and allowed(id) and #build < faction.MAX_BUILD_TYPES then
            build[#build + 1] = { kind = "unit", id = id, count = math.min(faction.KEEP_UP_TO, counts[id]) }
            used[id] = true
        end
        if #group < 6 then
            group[#group + 1] = { id = id, count = math.max(1, math.floor(counts[id] / 2)) }
        end
    end
    -- a few more of what the buildings offer, once the army is up
    local extra = {}
    for id in pairs(trains) do
        if not used[id] and allowed(id) and not id:sub(1, 1):match("%u") then extra[#extra + 1] = id end
    end
    table.sort(extra)
    -- the cheapest first, so something always comes out
    if game.unit_cost then
        table.sort(extra, function(a, b)
            local ca, cb = game.unit_cost(a).gold, game.unit_cost(b).gold
            if ca ~= cb then return ca < cb end
            return a < b
        end)
    end
    for i = 1, math.min(faction.MAX_BUILD_TYPES - #build, #extra) do
        build[#build + 1] = { kind = "unit", id = extra[i], count = i <= 2 and 4 or 2,
                              condition = i > 2 and "army_up" or nil }
    end
    for slot = 1, #heroes do table.insert(build, slot, { kind = "hero", slot = slot }) end

    return profile_mod.normalize({
        name = name or ("Player " .. (player + 1)),
        race = "custom",
        options = { defend_users = true, target_heroes = true, heroes_flee = true, units_flee = false,
                    groups_flee = true },
        heroes = heroes,
        conditions = { army_up = { "army", ">=", 8 } },
        build = build,
        groups = { main = group },
        waves = { initial_delay = 240, delay = 120, repeat_from = 1, max_wait = 90, min_fraction = 0.6,
                  list = { { group = "main" }, { group = "main" }, { group = "main" } } },
        targets = { { kind = "enemy_near_home" }, { kind = "enemy_base" } },
    })
end
-- }}}

-- {{{ Files
-- "DAoW-5.4b-PUBLIC-TEST.w3x" -> "DAoW-5.4b-PUBLIC-TEST"
function faction.map_key(path)
    return (tostring(path or "map"):match("([^/\\]+)$") or "map"):gsub("%.w3[xm]$", "")
end

local function slug(s)
    return (tostring(s or ""):gsub("|[cC]%x%x%x%x%x%x%x%x", ""):gsub("|[rR]", ""):gsub("[^%w]+", "-")
        :gsub("^%-+", ""):gsub("%-+$", ""))
end

function faction.file_name(player, name)
    local s = slug(name)
    return string.format("p%02d%s.lua", player, s ~= "" and ("-" .. s) or "")
end

-- The profile file for a player in dir, if one exists (any name p<NN>*.lua)
function faction.find_file(dir, player)
    local prefix = string.format("p%02d", player)
    local ok, p = pcall(io.popen, 'ls "' .. dir .. '" 2>/dev/null')
    if not ok or not p then return nil end
    local found
    for f in p:lines() do
        if f:sub(1, 3) == prefix and f:match("%.lua$") and not f:sub(4, 4):match("%d") then found = dir .. "/" .. f end
    end
    p:close()
    return found
end

-- The name a player's profile has inside a map (issue 909: the editor
-- saves profiles into the map, so they travel with it)
function faction.map_file(player)
    return string.format("war3mapAI\\p%02d.lua", player)
end

-- A profile's text read as data: no globals, so a map's file can't do
-- anything but return its table
function faction.read_profile(text, where)
    local chunk, err = loadstring(text, "=" .. tostring(where))
    if not chunk then error("AI profile " .. tostring(where) .. ": " .. tostring(err)) end
    setfenv(chunk, {})
    local ok, p = pcall(chunk)
    if not ok or type(p) ~= "table" then error("AI profile " .. tostring(where) .. ": " .. tostring(ok and "not a table" or p)) end
    return p
end

-- The player's profile: its file in dir if there is one (the owner's own,
-- first), else the one the map carries (read_map(name) -> text), else
-- derived.
function faction.load_or_derive(dir, game, player, name, read_map)
    local file = dir and faction.find_file(dir, player)
    if file then
        local chunk, err = loadfile(file)
        if not chunk then error("AI profile " .. file .. ": " .. tostring(err)) end
        local p = profile_mod.normalize(chunk())
        local problems = profile_mod.check(p)
        if #problems > 0 then error("AI profile " .. file .. ": " .. problems[1]) end
        return p, file
    end
    local text = read_map and read_map(faction.map_file(player))
    if text then
        local where = "map:" .. faction.map_file(player)
        local p = profile_mod.normalize(faction.read_profile(text, where))
        local problems = profile_mod.check(p)
        if #problems > 0 then error("AI profile " .. where .. ": " .. problems[1]) end
        return p, where
    end
    return faction.derive(game, player, name), "derived"
end

-- Write each player's derived profile into dir (made if missing), not
-- overwriting a file already there. Returns the paths written.
function faction.write(dir, game, players, names)
    os.execute('mkdir -p "' .. dir .. '"')
    local written = {}
    for _, player in ipairs(players) do
        if not faction.find_file(dir, player) then
            local name = names and names[player]
            local p = faction.derive(game, player, name)
            local path = dir .. "/" .. faction.file_name(player, name)
            local f = assert(io.open(path, "w"))
            local function names_of(id)
                local b = game.db.unit_button(id)
                local n = b and b.name
                return n and n:gsub("|[cC]%x%x%x%x%x%x%x%x", ""):gsub("|[rR]", "") or nil
            end
            f:write(profile_mod.serialize(p, string.format(
                "AI profile for %s (player %d), in the AI Editor's shape: see src/ai/profile.lua.\n"
                .. "Derived from what the faction owns when the game starts; edit freely:\n"
                .. "this file is used instead of deriving while it exists.", name or "?", player), names_of))
            f:close()
            written[#written + 1] = path
        end
    end
    return written
end
-- }}}

return faction
