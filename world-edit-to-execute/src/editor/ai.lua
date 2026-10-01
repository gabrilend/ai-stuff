--[[
The AI Editor (Issue 909)

The map's computer players' AI Editor profiles (ai/profile.lua: the AI
Editor's tabs as a table), edited: General (name, options, workers on
gold and lumber, target priorities), Heroes (the heroes and their skill
orders), Build (the build priorities), Groups (attack groups), Waves
(attack waves and their timing) and Conditions.

Each computer player that owns something when the map starts has one:
its file in the profiles folder (ai-profiles/<map>/pNN-*.lua) if there
is one, else the one the map carries, else one derived from what it
owns (ai/faction.lua). Opening them runs the map's script once, as the
game would, to see who owns what.

Saving writes each profile changed into the map as war3mapAI\pNN.lua,
which the game reads when the profiles folder has no file for that
player (ai/faction.lua): the edited map carries its AI with it.
E:export_ai() writes them to the profiles folder instead (the owner's
own copies, which come first).

  E:load_ai(opts)              opts.dir: the profiles folder
  E:ai_profiles()              { player, name, profile, source, file, units } ...
  E:ai_get(entry, path)        path: keys, e.g. { "waves", "delay" }
  E:ai_set(entry, path, value)
  E:ai_insert(entry, path, value, at)   into the list at path
  E:ai_remove(entry, path, at), E:ai_move(entry, path, at, by)
  E:ai_check()                 problems: { entry, message } ...
  E:ai_files(files)            what saving writes
  E:export_ai(dir)             written to the folder; the paths

Every change is one step to undo.

    require("editor.ai")(E)      -- editor/init.lua does this
]]

local profile = require("ai.profile")
local faction = require("ai.faction")
local mpq = require("mpq")

local editor_ai = {}

-- the AI Editor's checkboxes (ai/player.lua's options)
editor_ai.OPTIONS = { "melee", "defend_users", "random_paths", "target_heroes", "repair", "heroes_flee",
                      "units_flee", "groups_flee", "have_no_mercy", "ignore_injured", "take_items", "buy_items",
                      "slow_harvest", "smart_artillery" }
editor_ai.BUILD_KINDS = { "unit", "hero", "upgrade", "expansion" }
-- the target priorities ai/editor_ai.lua knows ("point" takes x and y)
editor_ai.TARGETS = { "enemy_near_home", "enemy_base", "nearest_enemy", "creeps" }

local function copy(t)
    if type(t) ~= "table" then return t end
    local o = {}
    for k, v in pairs(t) do o[k] = copy(v) end
    return o
end
editor_ai.copy = copy

-- a condition written as text (the panel edits them so) and back
function editor_ai.condition_text(c)
    if c == nil then return "" end
    if type(c) == "string" then return string.format("%q", c) end
    local s = profile.serialize({ x = c }):match("x = (.-),\n}") or ""
    return (s:gsub("\n%s*", " "))
end

function editor_ai.parse_condition(text)
    if text == nil or text:match("^%s*$") then return nil, true end
    local chunk = loadstring("return " .. text)
    if not chunk then return nil, false end
    setfenv(chunk, {})
    local ok, v = pcall(chunk)
    if not ok or (type(v) ~= "table" and type(v) ~= "string" and type(v) ~= "boolean") then return nil, false end
    return v, true
end

local function install(E)

    -- {{{ loading
    function E:load_ai(opts)
        opts = opts or {}
        local root = opts.root or (self.opts and self.opts.root) or "."
        self.ai_dir = opts.dir or (root .. "/ai-profiles/" .. faction.map_key(self.path))
        local scene = require("demo.wc3map.scene").load(self.path)
        local game = require("demo.wc3map.game").new(scene, { player = 0, minimap = false, placed = false,
                                                               vision = false, combat = false })
        local V, err = game.run_script({ ai = "none" })
        if not V then return nil, err end
        self.ai_game = game
        local archive = mpq.open(self.path)
        local function read_map(name)
            if not archive then return nil end
            return archive:has(name) and archive:extract(name) or nil
        end
        self.ai_list = {}
        for n = 1, 11 do
            local pl = V.players[n]
            local owns = 0
            for _, u in ipairs(game.units) do
                if u.player == n and u.alive ~= false then owns = owns + 1 end
            end
            if pl and owns > 0 and (opts.all or pl.controller == "MAP_CONTROL_COMPUTER") then
                local name = V:text(pl.name)
                local ok, p, where = pcall(faction.load_or_derive, self.ai_dir, game, n, name, read_map)
                if not ok then
                    self:say(tostring(p))
                    p, where = faction.derive(game, n, name), "derived"
                end
                -- what its buildings can train: the choices the panel offers
                local trains, seen = {}, {}
                for _, u in ipairs(game.units) do
                    if u.player == n and u.alive ~= false and u.spec.design == "building" then
                        for _, id in ipairs(game.db.unit_list(u.id, "utra")) do
                            if not seen[id] then seen[id] = true; trains[#trains + 1] = id end
                        end
                    end
                end
                table.sort(trains)
                self.ai_list[#self.ai_list + 1] = { player = n, name = name, profile = profile.normalize(p),
                    source = where, file = where ~= "derived" and not where:match("^map:") and where or nil,
                    units = owns, trains = trains }
            end
        end
        if archive then archive:close() end
        self.dirty.ai = self.dirty.ai or {}
        return self.ai_list
    end

    function E:ai_profiles() return self.ai_list or {} end

    function E:ai_profile_of(player)
        for _, e in ipairs(self:ai_profiles()) do if e.player == player then return e end end
    end

    -- a unit type's name, for the panel and the saved file's comments
    function E:ai_name_of(id)
        local g = self.ai_game
        local b = g and g.db.unit_button and g.db.unit_button(id)
        local n = b and b.name
        return n and (n:gsub("|[cC]%x%x%x%x%x%x%x%x", ""):gsub("|[rR]", "")) or id
    end
    -- }}}

    -- {{{ changes
    local function at_path(t, path, upto)
        for i = 1, (upto or #path) do
            if type(t) ~= "table" then return nil end
            t = t[path[i]]
        end
        return t
    end

    local function mark(self, entry)
        self.dirty.ai = self.dirty.ai or {}
        self.dirty.ai[entry.player] = true
    end

    function E:ai_get(entry, path) return at_path(entry.profile, path) end

    function E:ai_set(entry, path, value)
        local parent = at_path(entry.profile, path, #path - 1)
        if type(parent) ~= "table" then return false, "no such place" end
        local key = path[#path]
        local old = copy(parent[key])
        value = copy(value)
        local me = self
        self.history:run({ name = string.format("AI %s: %s", entry.name, table.concat(path, ".")),
            redo = function() parent[key] = copy(value); mark(me, entry) end,
            undo = function() parent[key] = copy(old); mark(me, entry) end })
        return true
    end

    function E:ai_insert(entry, path, value, at)
        local list = at_path(entry.profile, path)
        if type(list) ~= "table" then return false, "no such list" end
        at = at or (#list + 1)
        local me = self
        self.history:run({ name = string.format("AI %s: add to %s", entry.name, table.concat(path, ".")),
            redo = function() table.insert(list, at, value); mark(me, entry) end,
            undo = function() table.remove(list, at); mark(me, entry) end })
        return true
    end

    function E:ai_remove(entry, path, at)
        local list = at_path(entry.profile, path)
        if type(list) ~= "table" or list[at] == nil then return false end
        local old = list[at]
        local me = self
        self.history:run({ name = string.format("AI %s: remove from %s", entry.name, table.concat(path, ".")),
            redo = function() table.remove(list, at); mark(me, entry) end,
            undo = function() table.insert(list, at, old); mark(me, entry) end })
        return true
    end

    function E:ai_move(entry, path, at, by)
        local list = at_path(entry.profile, path)
        if type(list) ~= "table" then return false end
        local to = math.max(1, math.min(#list, at + by))
        if to == at then return false end
        local me = self
        self.history:run({ name = string.format("AI %s: move in %s", entry.name, table.concat(path, ".")),
            redo = function() local v = table.remove(list, at); table.insert(list, to, v); mark(me, entry) end,
            undo = function() local v = table.remove(list, to); table.insert(list, at, v); mark(me, entry) end })
        return true
    end
    -- }}}

    -- {{{ checking, saving
    function E:ai_check()
        local out = {}
        for _, e in ipairs(self:ai_profiles()) do
            for _, m in ipairs(profile.check(e.profile)) do out[#out + 1] = { entry = e, message = m } end
        end
        return out
    end

    local function text_of(self, e)
        local header = string.format("AI profile for %s (player %d), in the AI Editor's shape: see src/ai/profile.lua.\n"
            .. "Edited in the map editor (issue 909).", e.name, e.player)
        return profile.serialize(e.profile, header, function(id) return self:ai_name_of(id) end)
    end
    E.ai_text = text_of

    function E:ai_files(files)
        for player, changed in pairs(self.dirty.ai or {}) do
            local e = changed and self:ai_profile_of(player)
            if e then files[faction.map_file(player)] = text_of(self, e) end
        end
        return files
    end

    function E:export_ai(dir)
        dir = dir or self.ai_dir
        os.execute('mkdir -p "' .. dir .. '"')
        local written = {}
        for player, changed in pairs(self.dirty.ai or {}) do
            local e = changed and self:ai_profile_of(player)
            if e then
                local path = faction.find_file(dir, player) or (dir .. "/" .. faction.file_name(player, e.name))
                local f = io.open(path, "w")
                if f then
                    f:write(text_of(self, e))
                    f:close()
                    written[#written + 1] = path
                end
            end
        end
        if #written > 0 then self:say("AI profiles written: " .. #written) end
        return written
    end
    -- }}}
end

return setmetatable(editor_ai, { __call = function(_, E) return install(E) end })
