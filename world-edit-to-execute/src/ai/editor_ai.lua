--[[
Playing an AI Editor Profile (Issue 521c)

What the AI Editor's compiled .ai script does, for a profile
(ai/profile.lua), through a computer player's mechanism (ai/player.lua).
It runs as a thread of the map's VM (jass/vm.lua), waking every
STEP seconds:

  build     the build priorities, in order: the first entry whose
            condition holds and that's short of its count gets trained
            where it can; one it can't afford yet stops the list (the AI
            saves for it); one nothing can train is passed over
  heroes    a "hero" build entry trains the hero of that slot (Heroes
            tab) if it isn't alive; its skill order is kept, not used
            (heroes don't learn skills yet)
  waves     after the initial delay, each wave gathers its group (and
            trains what the group lacks), goes when all are there (or
            enough, after max_wait), attacks the first target priority
            that holds, and when it's spent or home the next wave waits
            its delay; after the last, the list starts again at
            repeat_from
  options   the General tab's checkboxes, onto the player

Harvesting follows the profile's worker counts (ai/player.lua, issue
527). Buildings are built (or upgraded to, or hired) and expansions put
a hall at a free mine (issue 540, ai/acts.lua); heroes learn their
profile's skill order; "upgrade" entries are researched to their count's
level (issue 542).

    local runner = editor_ai.start(V, ai, profile)
]]

local profile_mod = require("ai.profile")

local editor_ai = {}

editor_ai.STEP = 1.0

local R = {}
R.__index = R

-- {{{ editor_ai.start
function editor_ai.start(V, ai, p)
    local self = setmetatable({ V = V, ai = ai, p = profile_mod.normalize(p) }, R)
    self.state = { wave = 0, heroes = {} }
    self.phase, self.next_at = "waiting", ai.game.time + self.p.waves.initial_delay
    self.noted = {}
    for k, v in pairs(self.p.options) do ai.options[k] = v end
    ai.profile_name = self.p.name
    ai.harvest_plan = self.p.harvest
    self.thread = V:run_thread(function()
        while not self.stopped do
            local ok, err = pcall(self.step, self)
            if not ok then
                V:error("AI " .. tostring(self.p.name) .. ": " .. tostring(err))
                self.stopped = true
                break
            end
            V:sleep(editor_ai.STEP)
        end
    end, { ai = ai })
    return self
end
-- }}}

function R:test(c) return profile_mod.test(self.p, c, self.ai, self.state) end

function R:note_once(key, text)
    if not self.noted[key] then
        self.noted[key] = true
        self.ai:note(text)
    end
end

-- {{{ R:step
function R:step()
    local ai = self.ai
    if ai.game.time - (self.home_at or -1e9) > 10 then
        self.home_at = ai.game.time
        if ai.options.allow_home_changes then ai:find_home() end
    end
    self:heroes()
    self:build()
    self:waves()
end
-- }}}

-- {{{ Heroes: which living hero fills each slot
function R:heroes()
    for slot, h in ipairs(self.p.heroes) do
        local have = self.state.heroes[slot]
        if not have or have.removed then
            self.state.heroes[slot] = nil
            for _, u in ipairs(self.ai:units(function(u) return u.id == h.id end)) do
                local taken = false
                for _, other in pairs(self.state.heroes) do if other == u then taken = true end end
                if not taken then self.state.heroes[slot] = u break end
            end
        end
        if h.skills and #h.skills > 0 and self.ai.set_skills then
            self.ai:set_skills(h.id, h.skills)   -- (issue 540: learned in this order)
        end
    end
end
-- }}}

-- {{{ Build priorities
function R:build()
    local ai = self.ai
    for i, b in ipairs(self.p.build) do
        local kind = b.kind or "unit"
        if self:test(b.condition) then
            local id, want = b.id, b.count or 1
            if kind == "hero" then
                local h = self.p.heroes[b.slot or 1]
                id, want = h and h.id, 1
                if id and self.state.heroes[b.slot or 1] then want = 0 end
            elseif kind == "upgrade" then
                -- research to that level (issue 542): produce researches it
                if not ai.researcher then
                    self:note_once(kind, "upgrade entries are kept, not played: the game has no research")
                    id = nil
                end
            elseif kind == "expansion" then
                -- a hall at a free mine: counted as halls beyond the first
                local hall = id or (ai.hall_type and ai:hall_type())
                local halls = hall and (#ai:units(function(u)
                    return u.spec.design == "building" and u.spec.size == "hall" end) + ai:coming(hall)) or 0
                if hall and halls < want + 1 and ai.expand then
                    local ok, why = ai:expand(hall)
                    if not ok and (why == "not enough gold" or why == "not enough lumber") then return end
                    if not ok then self:note_once("cant:expand", "can't expand: " .. tostring(why)) end
                end
                id = nil
            end
            if id and ai:count(id) < want then
                local ok, why = ai:produce(id)
                if not ok then
                    if why == "not enough gold" or why == "not enough lumber" or why == "not enough food" then
                        return   -- save for it (priorities are in order)
                    end
                    self:note_once("cant:" .. id, "can't produce " .. id .. ": " .. tostring(why))
                end
            end
        end
    end
end
-- }}}

-- {{{ Targets
function R:target()
    local ai = self.ai
    for _, t in ipairs(self.p.targets) do
        if self:test(t.condition) then
            local x, y
            if t.kind == "enemy_near_home" then
                local e = ai:nearest_enemy(ai.home.x, ai.home.y)
                if e and (e.x - ai.home.x) ^ 2 + (e.y - ai.home.y) ^ 2 < 2400 ^ 2 then x, y = e.x, e.y end
            elseif t.kind == "enemy_base" then
                if t.player then ai.alliance_target = t.player end
                local b = ai:enemy_base()
                if b then x, y = b.x, b.y end
            elseif t.kind == "nearest_enemy" then
                local e = ai:nearest_enemy()
                if e then x, y = e.x, e.y end
            elseif t.kind == "creeps" then
                local c = ai:creep_camp()
                if c then x, y = c.x, c.y end
            elseif t.kind == "point" then
                x, y = t.x, t.y
            end
            if x then return x, y, t.kind end
        end
    end
end
-- }}}

-- {{{ Attack waves
function R:group_wants(name)
    local wants = {}
    for _, e in ipairs(self.p.groups[name] or {}) do
        if self:test(e.condition) then wants[e.id] = (wants[e.id] or 0) + (e.count or 1) end
    end
    return wants
end

function R:waves()
    local ai, w = self.ai, self.p.waves
    local now = ai.game.time
    if #w.list == 0 then return end

    if self.phase == "waiting" then
        if now < self.next_at then return end
        self.state.wave = self.state.wave + 1
        if self.state.wave > #w.list then self.state.wave = math.max(1, math.min(w.repeat_from, #w.list)) end
        local entry = w.list[self.state.wave]
        if not self:test(entry.condition) then
            self.next_at = now + 5
            return
        end
        self.phase, self.formed_at = "forming", now
        self.wants = self:group_wants(entry.group)
        ai:init_assault()
        for id, n in pairs(self.wants) do ai:add_assault(n, id) end
    end

    if self.phase == "forming" then
        local all = ai:form_group()
        -- train what the group still lacks
        local have = {}
        for _, u in ipairs(ai:attackers()) do have[u.id] = (have[u.id] or 0) + 1 end
        local wanted, got = 0, 0
        for id, n in pairs(self.wants) do
            wanted, got = wanted + n, got + math.min(n, have[id] or 0)
            if ai:count(id) - ai:count_done(id) + (have[id] or 0) < n and ai:trainable(id) then ai:produce(id) end
        end
        local frac = wanted > 0 and got / wanted or 0
        if all or (now - self.formed_at >= w.max_wait and frac >= w.min_fraction) then
            local x, y, kind = self:target()
            if x and ai:attack(x, y) then
                self.phase = "attacking"
                ai:note(string.format("wave %d: %d units at %s (%.0f, %.0f)", self.state.wave, #ai:attackers(), kind, x, y))
            elseif now - self.formed_at >= w.max_wait * 2 then
                ai:disband()
                self.phase, self.next_at = "waiting", now + w.delay
            end
        end
    elseif self.phase == "attacking" then
        if ai.captains.attack.state == "home" then
            ai:disband()
            self.phase, self.next_at = "waiting", now + w.delay
        end
    end
end
-- }}}

function R:stop() self.stopped = true end

return editor_ai
