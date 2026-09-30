--[[
What a Computer Player Does With Its Hands (Issue 540)

The game's construction, shops, heroes' skills, items and spells, for a
computer player (ai/player.lua). Scripts still decide what to make; this
is how it gets made, and what units do by themselves in a fight:

  making     AI:produce(id) makes id however it's made: upgrading a
             building that upgrades to it (a Keep), training it where it's
             trained, hiring it at a tavern or camp that sells it to the
             player (a unit walks there first), else building it with a
             worker that builds it, on a free spot near home clear of the
             gold mines (AI:construct). AI:count counts what's on its way:
             queued, ordered to be built, going up, upgrading, being hired
  expansions AI:expand(hall) builds a hall at the gold mine nearest home
             that has none of the player's halls near it
  repairing  with the "repair" option, idle workers mend damaged
             buildings near home
  heroes     learn their skills as they level: the profile's skill order
             when it gives one (AI:set_skills), else the first they can
  items      heroes drink restoring items when badly hurt; with the "buy
             items" option a hero at home with room walks to the nearest
             shop that sells to the player and buys what it can afford
             above a reserve, restoring items first; with "take items" a
             hero picks up items lying near it
  spells     each unit with spells casts them in a fight: harmful ones on
             the nearest enemy in range (heroes first with "target
             heroes"), healing ones on a hurt ally, area ones where enemies
             bunch, no-target ones when enemies are close (a shield only
             when hurt), auras and passives never

    require("ai.acts")(AI)      -- ai/player.lua does this
    ai:acts(dt)                 -- from AI:update
]]

local acts = {}

acts.RESERVE = 300          -- gold a shopping hero leaves in the purse
acts.SHOP_REACH = 3500      -- how far from home a hero goes shopping
acts.MINE_CLEAR = 450       -- buildings keep this far from gold mines
acts.FIGHT_RANGE = 900      -- an enemy this near means a fight
acts.DRINK_BELOW = 0.35     -- health share that sends a hero to its potions
acts.HEAL_BELOW = 0.6       -- an ally this hurt gets healed

-- spells used only in need
acts.WHEN_HURT = { AHds = true }
-- spells never cast by the AI (moving the caster about)
acts.NEVER = { AEbl = true }

local function alive(u) return u and u.alive ~= false and not u.removed end
local function d2(a, b) return (a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 end

return function(AI)

    -- {{{ making things
    -- whether one of our workers builds id
    function AI:builders(id)
        local g, out = self.game, {}
        if not g.can_build then return out end
        for _, w in ipairs(self:units(function(u) return u.spec.design == "unit" end)) do
            local listed = false
            for _, b in ipairs(g.db.unit_list(w.id, "ubui")) do if b == id then listed = true end end
            if not listed and g.data and g.data.units.list then
                for _, b in ipairs(g.data.units:list(w.id, "ubui") or {}) do if b == id then listed = true end end
            end
            if listed then out[#out + 1] = w end
        end
        return out
    end

    -- a building of ours that upgrades to id
    function AI:upgrader(id)
        local g = self.game
        if not g.upgrades then return nil end
        for _, b in ipairs(self:units(function(u) return u.spec.design == "building" end)) do
            for _, t in ipairs(g.upgrades(b)) do
                if t == id and not b.upgrading and not b.building_up then return b end
            end
        end
        return nil
    end

    -- a shop that sells id to us (a tavern's hero, a camp's mercenary)
    function AI:seller(id)
        local g = self.game
        if not g.is_shop then return nil end
        local best, bd
        for _, u in ipairs(g.units) do
            if alive(u) and u.shop_stock ~= false and g.sells_to and u.spec.design == "building" then
                local sold = false
                for _, e in ipairs(g.is_shop(u) and g.stock(u) or {}) do if e.id == id then sold = true end end
                if sold and g.sells_to(u, self.player) then
                    local d = d2(u, self.home)
                    if not bd or d < bd then best, bd = u, d end
                end
            end
        end
        return best
    end

    -- a free spot near home for building id (clear of the mines)
    function AI:site(id, near, w)
        local g = self.game
        near = near or self.home
        local mines = {}
        for _, u in ipairs(g.units) do if alive(u) and g.is_mine and g.is_mine(u) then mines[#mines + 1] = u end end
        for r = 320, 2400, 128 do
            local steps = math.max(8, math.floor(2 * math.pi * r / 160))
            local turn = (self.site_turn or 0) * 0.37
            for k = 0, steps - 1 do
                local a = turn + k / steps * math.pi * 2
                local x, y = g.snap(near.x + math.cos(a) * r, near.y + math.sin(a) * r, id)
                local clear = true
                for _, m in ipairs(mines) do
                    if (m.x - x) ^ 2 + (m.y - y) ^ 2 < acts.MINE_CLEAR ^ 2 then clear = false break end
                end
                if clear and g.placeable(id, x, y, w) then
                    self.site_turn = (self.site_turn or 0) + 1
                    return x, y
                end
            end
        end
        return nil
    end

    -- build id with one of our workers: true, or false and why
    function AI:construct(id, near)
        local g = self.game
        local list = self:builders(id)
        if #list == 0 then return false, "nothing builds it" end
        -- a worker not already building, nearest home
        local w, wd, why
        for _, u in ipairs(list) do
            if not u.construct and not u.repair then
                local ok, reason = g.can_build(u, id)
                if ok then
                    local d = d2(u, near or self.home)
                    if not wd or d < wd then w, wd = u, d end
                else
                    why = why or reason
                end
            end
        end
        if not w then return false, why or "no worker free" end
        local x, y = self:site(id, near, w)
        if not x then return false, "no room to build it" end
        local ok, reason = g.build(w, id, x, y)
        if ok then self:note("building " .. id) end
        return ok, reason
    end

    -- hire id at a shop: a unit of ours walks there, then buys
    function AI:hire(id, shop)
        local g = self.game
        if g.buyer_for(shop, self.player, false) then return g.buy(shop, self.player, id) end
        -- send the nearest unit of ours
        local best, bd
        for _, u in ipairs(self:units(function(u) return u.spec.design == "unit" and not u.ai_captain end)) do
            local d = d2(u, shop)
            if not bd or d < bd then best, bd = u, d end
        end
        if not best then return false, "no one to send" end
        g.visit_shop(best, shop)
        self.hiring = self.hiring or {}
        self.hiring[#self.hiring + 1] = { id = id, shop = shop, unit = best, since = g.time }
        return true
    end

    -- the hall our workers build (for expansions without an id)
    function AI:hall_type()
        local g = self.game
        for _, w in ipairs(self:units(function(u) return u.spec.archetype == "worker" end)) do
            local list = g.db.unit_list(w.id, "ubui")
            if #list == 0 and g.data and g.data.units.list then list = g.data.units:list(w.id, "ubui") or {} end
            for _, id in ipairs(list) do
                if (g.unit_spec(id) or {}).size == "hall" then return id end
            end
        end
        return nil
    end

    -- expansions: a hall at the gold mine nearest home with none of ours
    function AI:expand(hall)
        local g = self.game
        local halls = self:units(function(u) return u.spec.design == "building" end)
        local best, bd
        for _, m in ipairs(g.units) do
            if alive(m) and g.is_mine and g.is_mine(m) and (m.gold == nil or m.gold > 0) then
                local taken = false
                for _, h in ipairs(halls) do if d2(h, m) < 1500 ^ 2 then taken = true end end
                if not taken then
                    local d = d2(m, self.home)
                    if not bd or d < bd then best, bd = m, d end
                end
            end
        end
        if not best then return false, "no free mine" end
        -- a hall keeps its distance from the mine, not away from it
        local saved = acts.MINE_CLEAR
        acts.MINE_CLEAR = 500
        local ok, why = self:construct(hall, best)
        acts.MINE_CLEAR = saved
        return ok, why
    end
    -- }}}

    -- {{{ what's on its way (for AI:count)
    function AI:coming(id)
        local n = 0
        for _, u in ipairs(self:units()) do
            if u.construct and u.construct.id == id and not u.construct.building then n = n + 1 end
            if u.upgrading and u.upgrading.to == id then n = n + 1 end
        end
        for _, h in ipairs(self.hiring or {}) do if h.id == id then n = n + 1 end end
        return n
    end
    -- }}}

    -- {{{ heroes' skills
    function AI:set_skills(hero_id, order) self.skill_orders = self.skill_orders or {} self.skill_orders[hero_id] = order end

    function AI:learn_skills()
        local g = self.game
        if not g.learn then return end
        for _, h in ipairs(self:units(function(u) return u.hero ~= nil end)) do
            local guard = 0
            while (h.skill_points or 0) > 0 and guard < 10 do
                guard = guard + 1
                local learned = false
                for _, id in ipairs(self.skill_orders and self.skill_orders[h.id] or {}) do
                    if not learned and g.learn(h, id) then learned = true end
                end
                if not learned then
                    for _, id in ipairs(g.hero_skills(h)) do
                        if not learned and g.learn(h, id) then learned = true end
                    end
                end
                if not learned then break end
            end
        end
    end
    -- }}}

    -- {{{ spells
    -- the enemies this player sees, in 512-unit buckets (made once a pass)
    local CELL = 512
    local function enemy_grid(self)
        local g = self.game
        local grid = {}
        for _, u in ipairs(g.units) do
            if alive(u) and not u.hidden and u.spec.design == "unit" and u.player ~= self.player and u.player ~= 15
                and (not g.allied or not g.allied(self.player, u.player))
                and (not g.vision or g.vision:sees(self.player, u)) then
                local k = math.floor(u.x / CELL) .. "," .. math.floor(u.y / CELL)
                local b = grid[k]
                if not b then b = {}; grid[k] = b end
                b[#b + 1] = u
            end
        end
        return grid
    end
    local function enemies_near(self, x, y, r)
        local grid = self.foe_grid or enemy_grid(self)
        local out = {}
        local i0, i1 = math.floor((x - r) / CELL), math.floor((x + r) / CELL)
        local j0, j1 = math.floor((y - r) / CELL), math.floor((y + r) / CELL)
        for i = i0, i1 do
            for j = j0, j1 do
                for _, u in ipairs(grid[i .. "," .. j] or {}) do
                    if alive(u) and (u.x - x) ^ 2 + (u.y - y) ^ 2 <= r * r then out[#out + 1] = u end
                end
            end
        end
        return out
    end
    acts.enemies_near = enemies_near

    -- whether a unit has a spell it could cast (not auras or passives)
    local function has_spells(g, u)
        if not u.abilities or not next(u.abilities) then return false end
        for id, level in pairs(u.abilities) do
            if level > 0 then
                local _, target = g.ability_spec(id, level)
                if target ~= "aura" and target ~= "passive" then return true end
            end
        end
        return false
    end

    function AI:cast_spells()
        local g = self.game
        if not g.castable or not g.cast then return end
        local casters = self:units(function(x) return x.spec.design == "unit" and not x.casting and not x.ai_fleeing end)
        local any = false
        for _, u in ipairs(casters) do if has_spells(g, u) then any = true break end end
        if not any then return end
        self.foe_grid = enemy_grid(self)
        for _, u in ipairs(casters) do
            if has_spells(g, u) then
                local foes = enemies_near(self, u.x, u.y, acts.FIGHT_RANGE)
                if #foes > 0 then self:cast_one(u, foes) end
            end
        end
        self.foe_grid = nil
    end

    function AI:cast_one(u, foes)
        local g = self.game
        for _, a in ipairs(g.castable(u)) do
            local b, target, i = g.ability_spec(a.id, a.level)
            local base = i.base or a.id
            local ready = g.ability_ready(u, a.id)
            if b and ready and not acts.NEVER[base] and target ~= "aura" and target ~= "passive" then
                local range = i.range or 600
                if target == "unit" then
                    -- a hurt ally to heal, else an enemy to strike
                    local pick
                    if b.allies then
                        local worst
                        for _, f in ipairs(self:units(function(x) return x.spec.design == "unit" end)) do
                            if f.hp_max and f.hp / f.hp_max < acts.HEAL_BELOW and d2(f, u) <= range * range then
                                if not worst or f.hp / f.hp_max < worst.hp / worst.hp_max then worst = f end
                            end
                        end
                        pick = worst
                        -- a buff for the fight (only allies): anyone near without it
                        if not pick and not b.enemies then
                            for _, f in ipairs(self:units(function(x) return x.spec.design == "unit" and x.weapon end)) do
                                if not pick and d2(f, u) <= range * range and not (f.buffs and next(f.buffs)) then pick = f end
                            end
                        end
                    end
                    if not pick and b.enemies then
                        local best, bd
                        for _, e in ipairs(foes) do
                            local d = d2(e, u)
                            if self.options.target_heroes and e.spec.hero then d = d * 0.25 end
                            if d <= (range + 200) ^ 2 and (not bd or d < bd) then best, bd = e, d end
                        end
                        pick = best
                    end
                    if pick and g.cast(u, a.id, pick) then return true end
                elseif target == "point" then
                    -- where enemies bunch (three or more within its area)
                    local area = i.area or 0
                    if area > 0 then
                        for _, e in ipairs(foes) do
                            if d2(e, u) <= (range + 200) ^ 2 and #enemies_near(self, e.x, e.y, area) >= 3 then
                                if g.cast(u, a.id, nil, e.x, e.y) then return true end
                            end
                        end
                    end
                elseif target == "none" then
                    local hurt = u.hp_max and u.hp / u.hp_max < 0.3
                    local area = i.area or 0
                    local go
                    if acts.WHEN_HURT[base] then go = hurt
                    elseif area > 0 then go = #enemies_near(self, u.x, u.y, area) >= 2
                    else go = true end
                    if go and g.cast(u, a.id) then return true end
                end
            end
        end
        return false
    end
    -- }}}

    -- {{{ items
    local function restores(g, it)
        local t = it.type
        if not t or not t.usable or (t.charges > 0 and it.charges <= 0) then return false end
        local A = g.data.abilities
        for _, a in ipairs(t.abilities) do
            if tonumber((A:value(a, "Ihpg", 1))) or tonumber((A:value(a, "Ihp2", 1))) then return true end
        end
        return (it.type.name or ""):lower():find("heal") ~= nil
    end
    acts.restores = restores

    function AI:use_items()
        local g = self.game
        if not g.use_item then return end
        for _, h in ipairs(self:units(function(u) return u.inventory ~= nil end)) do
            if h.hp_max and h.hp / h.hp_max < acts.DRINK_BELOW then
                for k = 0, 5 do
                    local it = h.inventory[k]
                    if it and restores(g, it) and g.use_item(h, it) then break end
                end
            end
        end
    end

    function AI:shop()
        local g = self.game
        if not g.buy or not self.options.buy_items then return end
        for _, h in ipairs(self:units(function(u) return u.spec.hero end)) do
            local room = 0
            for k = 0, g.inventory_size(h) - 1 do if not (h.inventory and h.inventory[k]) then room = room + 1 end end
            local at_home = d2(h, self.home) < 1500 ^ 2 and not (h.ai_captain and h.ai_captain.state == "attacking")
            if room > 0 and at_home and not h.visiting then
                -- the nearest shop that sells items to us
                local shop, sd
                for _, b in ipairs(g.units) do
                    if alive(b) and b.spec.design == "building" and g.is_shop(b) and g.sells_to(b, self.player)
                        and d2(b, self.home) < acts.SHOP_REACH ^ 2 then
                        local items = false
                        for _, e in ipairs(g.stock(b)) do if e.kind == "item" and e.count > 0 then items = true end end
                        local d = d2(b, h)
                        if items and (not sd or d < sd) then shop, sd = b, d end
                    end
                end
                if shop then
                    if g.buyer_for(shop, self.player, true) == h or g.set_patron(shop, h) then
                        -- what it can afford above the reserve: restoring items first, then the dearest
                        local s = g.state(self.player)
                        local choice, score
                        for _, e in ipairs(g.stock(shop)) do
                            if e.kind == "item" and e.count > 0 then
                                local t = g.item_type(e.id)
                                if (s.gold or 0) - t.gold >= acts.RESERVE and (s.lumber or 0) >= t.lumber then
                                    local have = false
                                    for k = 0, 5 do if h.inventory and h.inventory[k] and h.inventory[k].id == e.id then have = true end end
                                    local sc = t.gold + (t.usable and t.charges > 0 and 10000 or 0) - (have and 20000 or 0)
                                    if not score or sc > score then choice, score = e.id, sc end
                                end
                            end
                        end
                        if choice and g.buy(shop, self.player, choice) then self:note("bought " .. choice) end
                    elseif not h.order and not h.ai_captain then
                        g.visit_shop(h, shop)
                    end
                end
            end
        end
    end

    function AI:take_items()
        local g = self.game
        if not self.options.take_items or not g.item_at then return end
        for _, h in ipairs(self:units(function(u) return u.spec.hero end)) do
            if not h.fetch and not h.casting then
                local it = g.item_at(h.x, h.y, 600)
                if it then g.pick_up(h, it) end
            end
        end
    end
    -- }}}

    -- {{{ repairing
    function AI:repair_base()
        local g = self.game
        if not self.options.repair or not g.repair then return end
        for _, b in ipairs(self:units(function(u) return u.spec.design == "building" end)) do
            if not b.building_up and b.hp_max and b.hp < b.hp_max * 0.9 and d2(b, self.home) < 2500 ^ 2 then
                local busy = false
                for _, w in ipairs(self:units()) do if w.repair and w.repair.target == b then busy = true end end
                if not busy then
                    for _, w in ipairs(self:units(function(u) return u.spec.archetype == "worker" end)) do
                        if not w.construct and not w.repair and not w.order and g.can_repair(w, b) and g.repair(w, b) then
                            break
                        end
                    end
                end
            end
        end
    end
    -- }}}

    -- {{{ AI:acts, from AI:update
    function AI:acts(dt)
        local g = self.game
        self.cast_clock = (self.cast_clock or 0) + dt
        if self.cast_clock >= 0.5 then
            self.cast_clock = 0
            self:cast_spells()
            self:use_items()
        end
        self.hands_clock = (self.hands_clock or 0) + dt
        if self.hands_clock >= 2 then
            self.hands_clock = 0
            self:learn_skills()
            self:repair_base()
            self:shop()
            self:take_items()
            -- units sent to hire: buy when there, give up after a minute
            local keep = {}
            for _, h in ipairs(self.hiring or {}) do
                if alive(h.unit) and alive(h.shop) and g.time - h.since < 60 then
                    if g.buyer_for(h.shop, self.player, false) then
                        local ok, why = g.buy(h.shop, self.player, h.id)
                        if not ok and why ~= "out of stock" and why ~= "not enough gold" then self:note("can't hire " .. h.id .. ": " .. tostring(why)) end
                        if not ok and (why == "out of stock" or why == "not enough gold") then keep[#keep + 1] = h end
                    else
                        keep[#keep + 1] = h
                    end
                end
            end
            self.hiring = keep
        end
    end
    -- }}}
end
