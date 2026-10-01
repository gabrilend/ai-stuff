--[[
Computer Players (Issue 521)

One AI per computer player, on a running map script (jass/vm.lua):

  started by the map    StartMeleeAI / StartCampaignAI(player, path): the
                        player's own profile if there is one (the profiles
                        folder's, or the map's: issue 909), else the
                        map's own .ai script if the map holds that file
                        (run through ai/natives.lua), else our melee
                        profile for the race the path names (ai/melee.lua),
                        as a map calling scripts\human.ai expects the
                        game's melee AI
  filled in             mode "auto": every computer player the map left
                        without an AI gets its profile file from the
                        profiles folder if there is one, else the one the
                        map carries (war3mapAI\\pNN.lua, saved by the
                        editor: issue 909), else a profile derived from
                        its faction (ai/faction.lua); WC3
                        itself leaves such players idle (mode "script")
  commanded             CommandAI(player, command, data) queues for the
                        player's AI (common.ai's CommandsWaiting and
                        friends, or a profile's { "command", n } condition)

    local ai = require("ai")
    local M = ai.manager(V)             -- V.world is the game
    M:fill("auto", "ai-profiles/DAoW-5.4b-PUBLIC-TEST")
    M:update(dt)                        -- each tick (game.tick does it)
]]

local ai_player = require("ai.player")
local editor_ai = require("ai.editor_ai")
local ai_natives = require("ai.natives")
local melee = require("ai.melee")
local faction = require("ai.faction")
local lexer = require("jass.lexer")
local parser = require("jass.parser")
local transpiler = require("jass.transpiler")

local ai = {}

ai.UPDATE_EVERY = 0.5

local M = {}
M.__index = M

-- {{{ ai.manager
function ai.manager(V)
    if V.ai_manager then return V.ai_manager end
    local self = setmetatable({ V = V, game = V.world, players = {}, how = {}, clock = 0 }, M)
    V.ai_manager = self
    V.world.ai_manager = self
    return self
end
-- }}}

-- {{{ M:player
function M:player(p)
    local a = self.players[p]
    if not a then
        a = ai_player.new(self.game, p, { difficulty = self.V.opts.ai_difficulty })
        self.players[p] = a
    end
    return a
end
-- }}}

-- {{{ Starting
function M:start_profile(p, prof, where)
    local a = self:player(p)
    if a.runner then a.runner:stop() end
    a.runner = editor_ai.start(self.V, a, prof)
    self.how[p] = where or "profile"
    return a
end

-- A .ai JASS script for player p. true, or nil and why.
function M:start_jass(p, source, where)
    local V = self.V
    local a = self:player(p)
    local ok, tokens = pcall(lexer.tokenize, source)
    if not ok then return nil, "lex: " .. tostring(tokens) end
    local ast, perr = parser.parse(tokens)
    if perr and #perr > 0 then return nil, "parse: " .. tostring(perr[1].message or perr[1]) end
    local types = {}
    for k, v in pairs(V.types) do types[k] = v end
    for k, v in pairs(ai_natives.TYPES) do types[k] = v end
    local lua, terr = transpiler.transpile(ast, { scope = "env", native_types = types, global_types = V.global_types })
    if terr and #terr > 0 then return nil, "transpile: " .. tostring(terr[1].message or terr[1]) end
    local chunk, err = loadstring(lua, "=" .. (where or "ai"))
    if not chunk then return nil, "lua: " .. tostring(err) end
    local env = ai_natives.env(V)
    setfenv(chunk, env)
    local ran, rerr = pcall(chunk)
    if not ran then return nil, "globals: " .. tostring(rerr) end
    a.env = env
    if type(rawget(env, "main")) == "function" then V:run_thread(env.main, { ai = a }) end
    self.how[p] = where or "script"
    return true
end

-- StartMeleeAI / StartCampaignAI: the map's file if it has it, else
-- our melee profile for the race the path names (or the player's)
function M:start_script(p, path, campaign)
    local V = self.V
    -- a profile made for this player (the profiles folder's, or the one
    -- the map carries: the editor's AI editor, issue 909) plays instead
    -- of the stock melee AI
    local okp, prof, where = pcall(faction.find_profile, V.opts.ai_dir, p, V.opts.read_file)
    if okp and prof then
        self:start_profile(p, prof, where)
        return true
    elseif not okp then
        V:error(tostring(prof))
    end
    local source = V.opts.read_file and path and V.opts.read_file(path)
    if source then
        local ok, err = self:start_jass(p, source, path)
        if ok then return true end
        V:error("AI script " .. tostring(path) .. " for player " .. p .. ": " .. tostring(err))
    end
    local race = melee.race_of(path) or melee.race_of(V:player(p).race) or "human"
    local prof = melee.profile(race)
    if campaign then prof.options.melee = false end
    self:start_profile(p, prof, "melee:" .. race)
    return true
end

-- Every computer player without an AI gets one (mode "auto")
function M:fill(mode, dir)
    if mode ~= "auto" then return {} end
    local started = {}
    for n = 0, 11 do
        local pl = self.V.players[n]
        if pl and pl.controller == "MAP_CONTROL_COMPUTER" and pl.slot == "PLAYER_SLOT_STATE_PLAYING"
            and not self.players[n] then
            local owns = false
            for _, u in ipairs(self.game.units) do
                if u.player == n and u.alive ~= false then owns = true break end
            end
            if owns then
                local ok, prof, where = pcall(faction.load_or_derive, dir, self.game, n, self.V:text(pl.name),
                    self.V.opts.read_file)
                if ok then
                    self:start_profile(n, prof, where)
                    started[#started + 1] = n
                else
                    self.V:error(tostring(prof))
                end
            end
        end
    end
    return started
end
-- }}}

-- {{{ M:command / M:pause
function M:command(p, cmd, data) self:player(p):command(cmd, data) end
function M:pause(p, on) self:player(p).paused = on and true or nil end
-- }}}

-- {{{ M:update
function M:update(dt)
    self.clock = self.clock + dt
    if self.clock < ai.UPDATE_EVERY then return end
    local step = self.clock
    self.clock = 0
    for _, a in pairs(self.players) do
        if not a.paused then a:update(step) end
    end
end
-- }}}

-- {{{ M:report
-- { {player, how, profile name, wave, attackers, log}, ... }
function M:report()
    local out = {}
    for p, a in pairs(self.players) do
        out[#out + 1] = { player = p, how = self.how[p], name = a.profile_name,
                          wave = a.runner and a.runner.state.wave or 0,
                          attackers = #a:attackers(), log = a.log }
    end
    table.sort(out, function(x, y) return x.player < y.player end)
    return out
end
-- }}}

return ai
