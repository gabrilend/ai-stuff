--[[
A Computer Player (Issue 521b)

What WC3's AI natives act on, for one computer player: its units, an
attack captain and a defense captain (groups the AI moves as one), the
units it has asked for, its home, the options the AI Editor's General tab
sets, and commands sent to it with CommandAI.

Everything here is mechanism: nothing decides what to build or when to
attack. How things get made (built, upgraded, hired) and what units do
by themselves (spells, potions, shopping, repair) is ai/acts.lua (issue
540). That's an AI script's job: a map's own .ai (through
ai/natives.lua) or an AI Editor profile (ai/editor_ai.lua).

    local ai_player = require("ai.player")
    local ai = ai_player.new(game, 3)
    ai:produce("hfoo")                  -- train one where it can
    ai:init_assault(); ai:add_assault(6, "hfoo"); ai:form_group()
    ai:attack(x, y)                     -- the attack captain attack-moves
    ai:update(dt)                       -- captains, fleeing, defending
]]

local ai_player = {}

local AI = {}
AI.__index = AI

ai_player.HOME_RADIUS = 1400     -- a captain within this of home is home
ai_player.DEFEND_RADIUS = 1800   -- attacks this near home call the defense
ai_player.FLEE_BELOW = 0.3       -- health fraction that sends units home (flee options)
ai_player.CLEAR_RADIUS = 900     -- a target with no enemies this near is taken

-- The AI Editor's General options (the ones a script sets with SetMeleeAI,
-- SetDefendPlayer, SetHeroesFlee ...), and their defaults here
ai_player.OPTIONS = {
    melee = false, defend_users = false, random_paths = false, target_heroes = false,
    repair = false, heroes_flee = true, units_flee = false, groups_flee = false,
    have_no_mercy = false, ignore_injured = false, take_items = false, buy_items = false,
    slow_harvest = false, allow_home_changes = true, smart_artillery = false,
    watch_mega_targets = false, captain_changes = true,
}

-- {{{ ai_player.new
function ai_player.new(game, player, opts)
    local self = setmetatable({}, AI)
    self.game, self.player = game, player
    self.options = {}
    for k, v in pairs(ai_player.OPTIONS) do self.options[k] = v end
    self.captains = { attack = { units = {}, state = "home" }, defense = { units = {}, state = "home" } }
    self.assault = {}         -- id -> quantity wanted in the attack captain
    self.defenders = {}       -- id -> quantity wanted in the defense captain
    self.commands = {}        -- { {cmd, data}, ... } from CommandAI, oldest first
    self.difficulty = (opts and opts.difficulty) or "normal"
    self.log = {}
    self:find_home()
    return self
end
-- }}}

-- {{{ Owned units
local function alive(u) return u.alive ~= false and not u.removed end

function AI:units(test)
    local out = {}
    for _, u in ipairs(self.game.units) do
        if u.player == self.player and alive(u) and (not test or test(u)) then out[#out + 1] = u end
    end
    return out
end

function AI:army()
    return self:units(function(u)
        return u.spec.design == "unit" and u.weapon ~= nil and u.spec.archetype ~= "worker"
    end)
end

-- living units of id, and those being trained (GetUnitCount)
function AI:count(id)
    local n = 0
    for _, u in ipairs(self.game.units) do
        if u.player == self.player and alive(u) then
            if u.id == id then n = n + 1 end
            for _, q in ipairs(u.queue or {}) do if q.id == id then n = n + 1 end end
        end
    end
    -- ordered built, upgrading to it, being hired (issue 540)
    return n + (self.coming and self:coming(id) or 0)
end

-- finished units of id only (GetUnitCountDone)
function AI:count_done(id)
    local n = 0
    for _, u in ipairs(self.game.units) do
        if u.player == self.player and alive(u) and u.id == id then n = n + 1 end
    end
    return n
end
-- }}}

-- {{{ Home
-- The main building (a hall, else the middle of the buildings, else of
-- everything owned)
function AI:find_home()
    local halls, sx, sy, n = {}, 0, 0, 0
    local all = self:units()
    for _, u in ipairs(all) do
        if u.spec.design == "building" then
            if u.spec.size == "hall" then halls[#halls + 1] = u end
            sx, sy, n = sx + u.x, sy + u.y, n + 1
        end
    end
    if #halls > 0 then
        self.home = { x = halls[1].x, y = halls[1].y }
    elseif n > 0 then
        self.home = { x = sx / n, y = sy / n }
    elseif #all > 0 then
        for _, u in ipairs(all) do sx, sy = sx + u.x, sy + u.y end
        self.home = { x = sx / #all, y = sy / #all }
    else
        self.home = self.home or { x = 0, y = 0 }
    end
    return self.home
end
-- }}}

-- {{{ Production
-- Make one `id` however it's made (issue 540): upgrading a building to
-- it, training it at the owned building with the shortest queue, hiring
-- it at a shop, or building it with a worker. true, or false and why not
-- (the first reason met).
function AI:produce(id)
    local g = self.game
    if not g.train then return false, "no production" end
    local up = self.upgrader and self:upgrader(id)
    if up then return g.upgrade(up, id) end
    if self.builders and not self:trainable(id) then
        if #self:builders(id) > 0 then return self:construct(id) end
        local shop = self:seller(id)
        if shop then return self:hire(id, shop) end
    end
    local best, best_q, why
    for _, b in ipairs(self:units(function(u) return u.spec.design == "building" end)) do
        local ok, reason = g.can_train(b, id)
        if ok then
            local q = #(b.queue or {})
            if not best or q < best_q then best, best_q = b, q end
        elseif reason ~= "doesn't train that" then
            why = why or reason
        end
    end
    if not best then return false, why or "nothing trains it" end
    return g.train(best, id)
end

-- Whether anything owned could ever train id (ignoring cost)
function AI:trainable(id)
    for _, b in ipairs(self:units(function(u) return u.spec.design == "building" end)) do
        for _, t in ipairs(self.game.db.unit_list(b.id, "utra")) do
            if t == id then return true end
        end
    end
    return false
end
-- }}}

-- {{{ Captains
local function prune(c)
    local l = {}
    for _, u in ipairs(c.units) do if alive(u) and u.ai_captain == c then l[#l + 1] = u end end
    c.units = l
    return l
end

function AI:init_assault() self.assault = {} end
function AI:add_assault(qty, id) self.assault[id] = (self.assault[id] or 0) + qty end
function AI:init_defense() self.defenders = {} end
function AI:add_defenders(qty, id) self.defenders[id] = (self.defenders[id] or 0) + qty end

-- Put free units into a captain to meet its wants; true when met
local function fill(self, captain, wants)
    local have = {}
    for _, u in ipairs(prune(captain)) do have[u.id] = (have[u.id] or 0) + 1 end
    local met = true
    for id, qty in pairs(wants) do
        if (have[id] or 0) < qty then
            for _, u in ipairs(self:units(function(v) return v.id == id and v.ai_captain == nil end)) do
                if (have[id] or 0) >= qty then break end
                u.ai_captain = captain
                captain.units[#captain.units + 1] = u
                have[id] = (have[id] or 0) + 1
            end
            if (have[id] or 0) < qty then met = false end
        end
    end
    return met
end

-- FormGroup: gather the assault's units; true when all are there
function AI:form_group()
    fill(self, self.captains.defense, self.defenders)
    return fill(self, self.captains.attack, self.assault)
end

-- The attack captain's units (living)
function AI:attackers() return prune(self.captains.attack) end

function AI:attack(x, y)
    local list = prune(self.captains.attack)
    if #list == 0 then return false end
    self.captains.attack.state, self.captains.attack.target = "attacking", { x = x, y = y }
    self.captains.attack.since = self.game.time
    self.game.order(list, "attack", x, y)
    return true
end

function AI:go_home()
    local list = prune(self.captains.attack)
    self.captains.attack.state, self.captains.attack.target = "returning", nil
    if #list > 0 then self.game.order(list, "move", self.home.x, self.home.y) end
end

local function middle(list)
    local x, y = 0, 0
    for _, u in ipairs(list) do x, y = x + u.x, y + u.y end
    return x / #list, y / #list
end

function AI:is_home()
    local list = prune(self.captains.attack)
    if #list == 0 then return true end
    local x, y = middle(list)
    return (x - self.home.x) ^ 2 + (y - self.home.y) ^ 2 < ai_player.HOME_RADIUS ^ 2
end

function AI:in_combat()
    for _, u in ipairs(prune(self.captains.attack)) do
        if u.target or (u.last_hit and self.game.time - u.last_hit < 3) then return true end
    end
    return false
end

-- Fraction of the attack captain's health left (CaptainReadiness)
function AI:readiness()
    local hp, max = 0, 0
    for _, u in ipairs(prune(self.captains.attack)) do hp, max = hp + (u.hp or 0), max + (u.hp_max or 1) end
    return max > 0 and hp / max or 0
end

-- Release the attack captain's units (after a wave is spent)
function AI:disband()
    for _, u in ipairs(self.captains.attack.units) do if u.ai_captain == self.captains.attack then u.ai_captain = nil end end
    self.captains.attack.units, self.captains.attack.state = {}, "home"
end
-- }}}

-- {{{ Targets
local function hostile(self, p)
    local g = self.game
    if p == self.player or p >= 13 then return false end
    if p == 12 then return true end
    if g.allied then return not g.allied(self.player, p) end
    return g.team_of(self.player) ~= g.team_of(p)
end

local function nearest(self, list, x, y)
    local best, bd
    for _, u in ipairs(list) do
        local d = (u.x - x) ^ 2 + (u.y - y) ^ 2
        if not bd or d < bd then best, bd = u, d end
    end
    return best
end

-- An enemy's main base: the hall (else any building) of the chosen enemy
-- player (the alliance target if set, else the one whose buildings are
-- nearest home)
function AI:enemy_base()
    local g = self.game
    local by = {}
    for _, u in ipairs(g.units) do
        if alive(u) and not u.invulnerable and u.spec.design == "building" and u.player ~= 12 and hostile(self, u.player) then
            local l = by[u.player]
            if not l then l = {}; by[u.player] = l end
            l[#l + 1] = u
        end
    end
    local pick = self.alliance_target and by[self.alliance_target] and self.alliance_target
    if not pick then
        local bd
        for p, l in pairs(by) do
            local b = nearest(self, l, self.home.x, self.home.y)
            local d = (b.x - self.home.x) ^ 2 + (b.y - self.home.y) ^ 2
            if not bd or d < bd then pick, bd = p, d end
        end
    end
    if not pick then return nil end
    local l = by[pick]
    local halls = {}
    for _, b in ipairs(l) do if b.spec.size == "hall" then halls[#halls + 1] = b end end
    local b = nearest(self, #halls > 0 and halls or l, self.home.x, self.home.y)
    return b, pick
end

-- The nearest living enemy (unit or building) to a point
function AI:nearest_enemy(x, y, test)
    local list = {}
    for _, u in ipairs(self.game.units) do
        if alive(u) and not u.invulnerable and not u.hidden and hostile(self, u.player) and u.player ~= 12
            and (not test or test(u)) then
            list[#list + 1] = u
        end
    end
    return nearest(self, list, x or self.home.x, y or self.home.y)
end

-- The nearest creep (neutral hostile) to home
function AI:creep_camp()
    local list = {}
    for _, u in ipairs(self.game.units) do
        if alive(u) and u.player == 12 and not u.invulnerable then list[#list + 1] = u end
    end
    return nearest(self, list, self.home.x, self.home.y)
end
-- }}}

-- {{{ Commands (CommandAI)
function AI:command(cmd, data) self.commands[#self.commands + 1] = { cmd, data } end
function AI:commands_waiting() return #self.commands end
function AI:last_command() local c = self.commands[#self.commands] return c and c[1] or 0 end
function AI:last_data() local c = self.commands[#self.commands] return c and c[2] or 0 end
function AI:pop_command() table.remove(self.commands) end
-- }}}

-- {{{ AI:update
-- The captains' own behaviour, whatever script drives them
function AI:update(dt)
    local g = self.game
    local o = self.options

    -- spells, items, skills, shopping, repair (issue 540)
    self:acts(dt)

    -- a wave that has taken its target moves on to the next enemy nearby,
    -- and comes home when there's none
    local att = self.captains.attack
    if att.state == "attacking" then
        local list = prune(att)
        if #list == 0 then
            att.state = "home"
        elseif att.target then
            local x, y = middle(list)
            local close = (x - att.target.x) ^ 2 + (y - att.target.y) ^ 2 < ai_player.CLEAR_RADIUS ^ 2
            if close and not self:in_combat() then
                local e = self:nearest_enemy(x, y, function(u)
                    return (u.x - x) ^ 2 + (u.y - y) ^ 2 < (ai_player.CLEAR_RADIUS * 2.5) ^ 2
                end)
                if e then self:attack(e.x, e.y) else self:go_home() end
            end
        end
    elseif att.state == "returning" and self:is_home() then
        att.state = "home"
    end

    -- fleeing: the badly hurt go home to heal (heroes, units, whole groups)
    local flee_units = o.units_flee or o.heroes_flee
    if flee_units then
        for _, u in ipairs(prune(att)) do
            local hurt = u.hp_max and u.hp / u.hp_max < ai_player.FLEE_BELOW
            if hurt and not u.ai_fleeing and ((u.spec.hero and o.heroes_flee) or (not u.spec.hero and o.units_flee)) then
                u.ai_fleeing = true
                g.order({ u }, "move", self.home.x, self.home.y)
            elseif u.ai_fleeing and u.hp / u.hp_max > 0.8 then
                u.ai_fleeing = nil
            end
        end
    end
    if o.groups_flee and att.state == "attacking" and self:readiness() < ai_player.FLEE_BELOW then
        self:go_home()
    end

    -- harvesting (issue 527): idle workers to gold, then lumber, up to the
    -- profile's counts (the AI Editor's "workers on gold / lumber")
    self.harvest_clock = (self.harvest_clock or 0) + dt
    if self.harvest_clock >= 2 and g.gather then
        self.harvest_clock = 0
        self:assign_workers()
    end

    -- defending: anything of ours struck near home calls the defense
    -- captain and every free fighter at home
    self.defend_clock = (self.defend_clock or 0) + dt
    if self.defend_clock >= 1 then
        self.defend_clock = 0
        local threat
        for _, u in ipairs(self:units()) do
            if u.last_hit and g.time - u.last_hit < 2
                and (u.x - self.home.x) ^ 2 + (u.y - self.home.y) ^ 2 < ai_player.DEFEND_RADIUS ^ 2 then
                threat = u
                break
            end
        end
        if threat then
            local near = self:nearest_enemy(threat.x, threat.y)
            if near and (near.x - threat.x) ^ 2 + (near.y - threat.y) ^ 2 < 1200 ^ 2 then
                local list = prune(self.captains.defense)
                for _, u in ipairs(self:army()) do
                    if u.ai_captain == nil and not u.order and (u.x - self.home.x) ^ 2 + (u.y - self.home.y) ^ 2
                        < ai_player.DEFEND_RADIUS ^ 2 then
                        list[#list + 1] = u
                    end
                end
                if #list > 0 then g.order(list, "attack", near.x, near.y) end
                self.defending = g.time
            end
        end
    end
end
-- }}}

-- {{{ AI:assign_workers
function AI:assign_workers()
    local g = self.game
    local plan = self.harvest_plan or { gold = 5, lumber = 3 }
    local on = { gold = 0, lumber = 0 }
    local idle = {}
    for _, u in ipairs(self:units()) do
        if u.spec.archetype == "worker" and u.spec.design == "unit" then
            if u.harvest then
                on[u.harvest.kind] = on[u.harvest.kind] + 1
            elseif not u.order and not u.ai_captain then
                idle[#idle + 1] = u
            end
        end
    end
    if #idle == 0 then return end
    local hx, hy = self.home.x, self.home.y
    -- the mine nearest home with gold left
    local mine, md = nil, math.huge
    for _, u in ipairs(g.units) do
        if u.alive and g.is_mine and g.is_mine(u) and (u.gold == nil or u.gold > 0) then
            local d = (u.x - hx) ^ 2 + (u.y - hy) ^ 2
            if d < md then mine, md = u, d end
        end
    end
    for _, u in ipairs(idle) do
        if mine and on.gold < (plan.gold or 0) and g.gather(u, mine) then
            on.gold = on.gold + 1
        elseif on.lumber < (plan.lumber or 0) and g.gather(u, nil, hx, hy) then
            on.lumber = on.lumber + 1
        end
    end
end
-- }}}

require("ai.acts")(AI)

function AI:note(text)
    if #self.log < 200 then self.log[#self.log + 1] = { time = self.game.time, text = text } end
end

return ai_player
