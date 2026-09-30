--[[
WC3 Interface (Issue 518b)

The in-game interface of WC3 over a map scene: top bar, console, command
card, minimap, portrait, hero buttons, idle-worker button, messages,
tooltips and the Quests / Menu / Allies / Log panels; selection by click
and drag, orders by button, hotkey, click and right-click, control groups.

The HUD draws through a 2D backend (render.ui_*) and learns about the
world through a `game` table, so it runs headless in tests:

  game.player                   the local player's number
  game.units                    every placed object: { id, spec, player,
                                x, y, z, name, ... } (see demo/wc3map/main.lua)
  game.db                       object data answers (ui/wc3/commands.lua)
  game.to_screen(x, y, z)       -> sx, sy, in_front
  game.to_ground(sx, sy)        -> x, y (WC3), or nil
  game.camera()                 -> x, y, distance;  game.set_camera(x, y)
  game.order(units, order, x, y)  order: move | attack | patrol | stop | hold
  game.resources(player)        -> { gold, lumber, food, food_cap, notes }
  game.time_of_day()            -> hours, 0-24
  game.minimap                  -> { image, x0, y0, x1, y1 } (WC3 extents)
  game.players                  -> { {number, name, color, team}, ... }
  game.quests                   -> { main = {titles}, optional = {titles} }
  game.portrait(unit)           add the unit's design to the portrait layer
  game.quit()

    local hud = require("ui.wc3.hud").new(game, 1280, 720)
    hud:update(input, dt)    -- input from viewer.mouse/keys (see main.lua)
    hud:draw(render)
]]

local layout = require("ui.wc3.layout")
local commands = require("ui.wc3.commands")
local icons = require("ui.wc3.icons")
local designs = require("geometry.designs")
local script_ui = require("ui.wc3.script_ui")

local Hud = {}
Hud.__index = Hud

local hud = {}

-- {{{ Colours
local C = {
    frame = { 22, 24, 32 }, panel = { 40, 44, 56 }, slot = { 30, 33, 42 },
    trim = { 176, 140, 64 }, trim_dark = { 110, 86, 40 }, text = { 236, 232, 220 },
    gold = { 250, 206, 70 }, dim = { 150, 150, 160 }, hover = { 90, 96, 120 },
    green = { 60, 220, 70 }, blue = { 70, 120, 255 }, red = { 230, 60, 50 },
    yellow = { 240, 220, 60 },
}
-- }}}

-- {{{ hud.new
function hud.new(game, w, h)
    local self = setmetatable({
        game = game, r = layout.compute(w, h),
        selection = {}, subgroup = 1, mode = "main", targeting = nil,
        panel = nil, messages = {}, groups = {}, time = 0,
        toggles = { terrain = true, ally_colors = false, creeps = true, formation = true },
        pings = {}, drag = nil, hover = nil, last_group_key = nil,
    }, Hud)
    return self
end
-- }}}

-- {{{ Queries

-- {{{ Hud:own
function Hud:own(u)
    return u.player == self.game.player
end
-- }}}

-- {{{ Hud:leader
-- The unit whose command card and information show: the first of the
-- active subgroup (units of one type)
function Hud:leader()
    local groups = self:subgroups()
    local g = groups[self.subgroup] or groups[1]
    return g and g[1] or nil
end

function Hud:subgroups()
    local order, by = {}, {}
    for _, u in ipairs(self.selection) do
        if not by[u.id] then
            by[u.id] = {}
            order[#order + 1] = by[u.id]
        end
        table.insert(by[u.id], u)
    end
    return order
end
-- }}}

-- {{{ Hud:card
-- The command card now showing (empty for units you don't control)
function Hud:card()
    local u = self:leader()
    if not u then return {} end
    -- a shop that sells to us shows what it sells, whoever owns it (issue 533)
    if not self:own(u) then
        local g = self.game
        if g.is_shop and g.is_shop(u) and g.sells_to(u, g.player) then return commands.card(u, g.db, "main") end
        return {}
    end
    return commands.card(u, self.game.db, self.mode)
end
-- }}}

-- {{{ Hud:heroes / Hud:idle_workers
function Hud:heroes()
    local list = {}
    for _, u in ipairs(self.game.units) do
        if self:own(u) and u.spec.hero and not u.hidden and not u.removed then list[#list + 1] = u end
    end
    return list
end

function Hud:idle_workers()
    local list = {}
    for _, u in ipairs(self.game.units) do
        if self:own(u) and u.spec.archetype == "worker" and not u.order and u.alive ~= false then list[#list + 1] = u end
    end
    return list
end
-- }}}
-- }}}

-- {{{ Messages
function Hud:message(text)
    table.insert(self.messages, { text = text, at = self.time })
    self.log = self.log or {}
    table.insert(self.log, string.format("[%d:%02d] %s", math.floor(self.time / 60), math.floor(self.time % 60), text))
end
-- }}}

-- {{{ Selecting

-- {{{ Hud:select
function Hud:select(list, add)
    if not add then self.selection = {} end
    local seen = {}
    for _, u in ipairs(self.selection) do seen[u] = true end
    for _, u in ipairs(list) do
        if not seen[u] and #self.selection < 12 then
            self.selection[#self.selection + 1] = u
            seen[u] = true
        end
    end
    self.subgroup, self.mode, self.targeting = 1, "main", nil
end
-- }}}

-- {{{ shown
-- Whether the local player sees u (the game's fog of war, Issue 524)
local function shown(game, u)
    return not game.shown or game.shown(u)
end
-- }}}

-- {{{ screen_point
-- Where a unit shows on screen (its middle), or nil when off screen/behind
local function screen_point(game, u)
    local sx, sy, ahead = game.to_screen(u.x, u.y, u.z + (u.spec.design == "building" and 100 or 45))
    if not ahead then return nil end
    return sx, sy
end
-- }}}

-- {{{ Hud:pick
-- The object nearest a screen point, within reach (bigger for buildings)
function Hud:pick(mx, my)
    local best, best_d = nil, math.huge
    for _, u in ipairs(self.game.units) do
        local sx, sy
        if u.alive ~= false and not u.hidden and shown(self.game, u) then sx, sy = screen_point(self.game, u) end
        if sx then
            local reach = u.spec.design == "building" and 44 or 22
            local d = (sx - mx) ^ 2 + (sy - my) ^ 2
            if d < reach * reach and d < best_d then best, best_d = u, d end
        end
    end
    return best
end
-- }}}

-- {{{ Hud:pick_item
-- The item on the ground under a screen point (its treasure icon), when
-- the local player can see where it lies
function Hud:pick_item(mx, my)
    local game = self.game
    local best, best_d = nil, 20 * 20
    for _, it in ipairs(game.items or {}) do
        if not it.owner and not it.removed and not it.hidden
            and (not game.shown_at or game.shown_at(it.x, it.y)) then
            local sx, sy, ahead = game.to_screen(it.x, it.y, (it.z or 0) + 20)
            if ahead then
                local d = (sx - mx) ^ 2 + (sy - my) ^ 2
                if d < best_d then best, best_d = it, d end
            end
        end
    end
    return best
end
-- }}}

-- {{{ Hud:box_select
-- Your units inside a screen rectangle (units before buildings), up to 12
function Hud:box_select(x0, y0, x1, y1)
    if x0 > x1 then x0, x1 = x1, x0 end
    if y0 > y1 then y0, y1 = y1, y0 end
    local mobile, buildings = {}, {}
    for _, u in ipairs(self.game.units) do
        if self:own(u) and u.alive ~= false and not u.hidden then
            local sx, sy = screen_point(self.game, u)
            if sx and sx >= x0 and sx <= x1 and sy >= y0 and sy <= y1 then
                table.insert(u.spec.design == "building" and buildings or mobile, u)
            end
        end
    end
    return #mobile > 0 and mobile or buildings
end
-- }}}
-- }}}

-- {{{ Orders and buttons

-- {{{ Hud:press
-- A command button pressed (by click or hotkey)
function Hud:press(b)
    local sel = self:own_selection()
    local a = b.action
    if a == "move" or a == "attack" or a == "patrol" or a == "gather" or a == "repair" or a == "rally" then
        self.targeting = a
    elseif a == "stop" or a == "hold" then
        self.game.order(sel, a)
    elseif a == "build" and b.target and self.game.build then
        -- a structure picked from the build menu: place it (issue 531)
        self.targeting, self.place_id = "place", b.target
        self.mode = "main"
    elseif a == "build" then
        self.mode = "build"
    elseif a == "cancel_build" and self.game.cancel_build then
        for _, u in ipairs(sel) do if u.building_up then self.game.cancel_build(u) end end
    elseif a == "learn" and b.target and self.game.learn then
        -- a skill picked from the hero's list
        local hero = self:leader()
        local ok, why = self.game.learn(hero, b.target)
        if not ok then self:message((why:sub(1, 1):upper() .. why:sub(2)) .. ".") end
        if ok and (hero.skill_points or 0) <= 0 then self.mode = "main" end
    elseif a == "learn" then
        self.mode = "learn"
    elseif a == "ability" and self.game.cast then
        -- a spell: at once when it needs no target, else pick one
        if b.target_kind == "none" then
            local why
            for _, u in ipairs(sel) do
                if u.abilities and (u.abilities[b.target] or 0) > 0 then
                    local ok, reason = self.game.cast(u, b.target)
                    if ok then return end
                    why = why or reason
                end
            end
            self:message((why and (why:sub(1, 1):upper() .. why:sub(2)) or "Can't cast that") .. ".")
        else
            self.targeting, self.spell = "cast", b.target
        end
    elseif a == "buy" and self.game.buy then
        local ok, why = self.game.buy(self:leader(), self.game.player, b.target)
        if not ok then self:message((why:sub(1, 1):upper() .. why:sub(2)) .. ".") end
    elseif a == "passive" then
        self:message(b.label .. " works on its own.")
    elseif a == "revive" and self.game.revive then
        local why
        for _, u in ipairs(sel) do
            if u.spec.design == "building" then
                local ok, reason = self.game.revive(u, b.target)
                if ok then return end
                why = why or reason
            end
        end
        self:message((why and (why:sub(1, 1):upper() .. why:sub(2)) or "Can't revive") .. ".")
    elseif a == "cancel" then
        self.mode, self.targeting = "main", nil
    elseif a == "train" and self.game.train then
        -- the first selected building of its kind that can take it
        local why
        for _, u in ipairs(sel) do
            if u.spec.design == "building" then
                local ok, reason = self.game.train(u, b.target)
                if ok then return end
                why = why or reason
            end
        end
        self:message((why and (why:sub(1, 1):upper() .. why:sub(2)) or "Can't train that") .. ".")
    else
        -- train, ability, structure: shown as the map defines them, not yet simulated
        self:message(b.label .. ": not simulated in this viewer yet")
    end
end
-- }}}

function Hud:own_selection()
    local list = {}
    for _, u in ipairs(self.selection) do if self:own(u) then list[#list + 1] = u end end
    return list
end

-- {{{ Hud:target
-- A world point chosen while targeting
function Hud:target(x, y, unit)
    local order = self.targeting
    self.targeting = nil
    if order == "attack" and unit and unit.alive ~= false and not self:own(unit) then
        self.game.order(self:own_selection(), "attack_unit", unit.x, unit.y, unit)
    elseif order == "move" or order == "attack" or order == "patrol" then
        self.game.order(self:own_selection(), order, x, y)
    elseif order == "use_item" and self.game.use_item then
        local lead = self:leader()
        local ok, why = self.game.use_item(lead, self.use_item, unit, x, y)
        if not ok then self:message((why:sub(1, 1):upper() .. why:sub(2)) .. ".") end
    elseif order == "place" and self.game.build then
        local why
        for _, u in ipairs(self:own_selection()) do
            if u.spec.archetype == "worker" or u.spec.design == "unit" then
                local ok, reason = self.game.build(u, self.place_id, x, y)
                if ok then return end
                why = why or reason
            end
        end
        self:message((why and (why:sub(1, 1):upper() .. why:sub(2)) or "Can't build there") .. ".")
    elseif order == "cast" and self.game.cast then
        local why
        for _, u in ipairs(self:own_selection()) do
            if u.abilities and (u.abilities[self.spell] or 0) > 0 then
                local ok, reason = self.game.cast(u, self.spell, unit, x, y)
                if ok then return end
                why = why or reason
            end
        end
        self:message((why and (why:sub(1, 1):upper() .. why:sub(2)) or "Can't cast that") .. ".")
    elseif order == "gather" and self.game.gather then
        if not self.game.order(self:own_selection(), "gather", x, y, unit) then
            self:message("Nothing to gather there.")
        end
    elseif order == "rally" and self.game.set_rally then
        for _, u in ipairs(self:own_selection()) do
            if u.spec.design == "building" then self.game.set_rally(u, x, y) end
        end
    else
        self:message(commands.STOCK[order].label .. ": not simulated in this viewer yet")
    end
end
-- }}}
-- }}}

-- {{{ Minimap

-- {{{ Hud:minimap_to_world / world_to_minimap
function Hud:minimap_to_world(mx, my)
    local m, r = self.game.minimap, self.r.minimap
    local fx, fy = (mx - r.x) / r.w, (my - r.y) / r.h
    return m.x0 + fx * (m.x1 - m.x0), m.y1 - fy * (m.y1 - m.y0)
end

function Hud:world_to_minimap(x, y)
    local m, r = self.game.minimap, self.r.minimap
    return r.x + (x - m.x0) / (m.x1 - m.x0) * r.w, r.y + (m.y1 - y) / (m.y1 - m.y0) * r.h
end
-- }}}

-- {{{ Hud:toggle
function Hud:toggle(id)
    if id == "signal" then
        self.targeting = "signal"
        return
    end
    self.toggles[id] = not self.toggles[id]
    local b
    for _, mb in ipairs(self.r.minimap_buttons) do if mb.id == id then b = mb end end
    self:message(b.label .. (self.toggles[id] and " on" or " off"))
end
-- }}}
-- }}}

-- {{{ Hud:update
-- input: { mx, my, lp (left pressed), ld (left down), lr (left released),
--          rp (right pressed), keys = {names}, shift, ctrl, alt }
function Hud:update(input, dt)
    self.time = self.time + (dt or 0)
    local r, game = self.r, self.game
    self.alt = input.alt
    -- the map's script: chat typing, its dialogs, Esc (ui/wc3/script_ui.lua)
    script_ui.update(self, input)
    local mx, my = input.mx or 0, input.my or 0

    -- the dead leave selections and groups
    local function living(list)
        local out = {}
        for _, u in ipairs(list) do if u.alive ~= false then out[#out + 1] = u end end
        return out
    end
    if #self.selection > 0 then
        local before = #self.selection
        self.selection = living(self.selection)
        if #self.selection ~= before then self.subgroup, self.mode = 1, "main" end
    end
    for k, g in pairs(self.groups) do self.groups[k] = living(g) end

    -- keys
    for _, key in ipairs(input.keys or {}) do self:key(key, input) end

    -- the hovered button, for its tooltip
    self.hover = nil
    local card = self:card()
    for s = 1, 12 do
        if card[s] and layout.inside(r.card[s], mx, my) then self.hover = card[s] end
    end

    local over_ui = my < r.top.h or my >= r.console.y
        or layout.inside(r.idle, mx, my) or (self.panel and layout.inside(r.panel, mx, my))
    for _, h in ipairs(r.heroes) do over_ui = over_ui or layout.inside(h, mx, my) end

    -- right click: cancel targeting, or a move/attack order
    if input.rp then
        if self.targeting then
            self.targeting = nil
        elseif #self:own_selection() > 0 then
            local x, y
            if layout.inside(r.minimap, mx, my) then x, y = self:minimap_to_world(mx, my)
            elseif not over_ui then x, y = game.to_ground(mx, my) end
            if x then
                local target = not over_ui and self:pick(mx, my)
                -- workers: a gold mine, or ground among trees, is gathering
                local workers = {}
                for _, u in ipairs(self:own_selection()) do
                    if u.spec.archetype == "worker" then workers[#workers + 1] = u end
                end
                local gathered = false
                -- an item's treasure icon clicked on: the first selected unit
                -- with an inventory fetches it (walking over one does nothing)
                local item = not target and not over_ui and game.pick_up and self:pick_item(mx, my)
                if item then
                    for _, u in ipairs(self:own_selection()) do
                        if game.inventory_size(u) > 0 and game.pick_up(u, item) then gathered = true break end
                    end
                end
                if not gathered and #workers > 0 and game.gather then
                    if target and game.is_mine and game.is_mine(target) then
                        gathered = game.order(workers, "gather", target.x, target.y, target)
                    elseif not target and game.nearest_tree and game.nearest_tree(x, y, 120) then
                        gathered = game.order(workers, "gather", x, y)
                    end
                end
                if gathered then
                    -- (the rest of the selection moves)
                elseif target and target.alive ~= false and not self:own(target) and target.player < 13 then
                    game.order(self:own_selection(), "attack_unit", target.x, target.y, target)
                else
                    game.order(self:own_selection(), "move", x, y)
                end
            end
        end
    end

    if input.lp then self:click(mx, my, input, over_ui) end

    -- drag selection
    if self.drag then
        self.drag.x1, self.drag.y1 = mx, my
        if input.lr then
            local d = self.drag
            self.drag = nil
            if math.abs(d.x1 - d.x0) > 6 or math.abs(d.y1 - d.y0) > 6 then
                local list = self:box_select(d.x0, d.y0, d.x1, d.y1)
                if #list > 0 then self:select(list, input.shift) end
            else
                local u = self:pick(d.x0, d.y0)
                if u then self:select({ u }, input.shift)
                elseif not input.shift then self:select({}) end
            end
        end
    end

    -- minimap drag moves the camera
    if input.ld and not self.targeting and not self.drag and layout.inside(r.minimap, mx, my) then
        game.set_camera(self:minimap_to_world(mx, my))
    end
end
-- }}}

-- {{{ Hud:click
function Hud:click(mx, my, input, over_ui)
    local r, game = self.r, self.game

    if self.panel then
        self:click_panel(mx, my)
        return
    end
    for _, m in ipairs(r.menu) do
        if layout.inside(m, mx, my) then self.panel = m.panel; return end
    end
    local card = self:card()
    for s = 1, 12 do
        local b = card[s]
        if b and layout.inside(r.card[s], mx, my) then self:press(b); return end
    end
    for _, mb in ipairs(r.minimap_buttons) do
        if layout.inside(mb, mx, my) then self:toggle(mb.id); return end
    end
    for i, h in ipairs(r.heroes) do
        local hero = self:heroes()[i]
        if hero and layout.inside(h, mx, my) then self:select({ hero }); return end
    end
    -- an item in the inventory: use it (issue 532)
    for i, slot in ipairs(r.inventory) do
        local lead = self:leader()
        local it = lead and self:own(lead) and lead.inventory and lead.inventory[i - 1]
        if it and layout.inside(slot, mx, my) and game.use_item then
            local ok, why = game.use_item(lead, it)
            if not ok and (why == "needs a unit target" or why == "needs a point" or why == "needs a target") then
                self.targeting, self.use_item = "use_item", it
            elseif not ok then
                self:message((why:sub(1, 1):upper() .. why:sub(2)) .. ".")
            end
            return
        end
    end
    if layout.inside(r.idle, mx, my) then self:next_idle(); return end
    if layout.inside(r.info, mx, my) and #self.selection > 1 then
        -- a unit's icon in the group: select just that one
        for i, u in ipairs(self.selection) do
            local ix, iy = r.info.x + 10 + ((i - 1) % 6) * 66, r.info.y + 40 + math.floor((i - 1) / 6) * 66
            if mx >= ix and mx < ix + 58 and my >= iy and my < iy + 58 then self:select({ u }); return end
        end
    end

    if layout.inside(r.minimap, mx, my) then
        local x, y = self:minimap_to_world(mx, my)
        if self.targeting == "signal" then
            self.targeting = nil
            table.insert(self.pings, { x = x, y = y, at = self.time })
            self:message("Signal sent")
        elseif self.targeting then
            self:target(x, y)
        end
        return
    end
    if over_ui then return end

    if self.targeting then
        local x, y = game.to_ground(mx, my)
        if x then
            if self.targeting == "signal" then
                self.targeting = nil
                table.insert(self.pings, { x = x, y = y, at = self.time })
            else
                self:target(x, y, self:pick(mx, my))
            end
        end
        return
    end
    self.drag = { x0 = mx, y0 = my, x1 = mx, y1 = my }
end
-- }}}

-- {{{ Hud:next_idle
function Hud:next_idle()
    local idle = self:idle_workers()
    if #idle == 0 then return end
    self.idle_index = (self.idle_index or 0) % #idle + 1
    local u = idle[self.idle_index]
    self:select({ u })
    self.game.set_camera(u.x, u.y)
end
-- }}}

-- {{{ Hud:key
function Hud:key(key, input)
    if input.alt then
        local map = { G = "signal", T = "terrain", A = "ally_colors", R = "creeps", F = "formation" }
        if map[key] then self:toggle(map[key]) end
        return
    end
    local panels = { F9 = "quests", F10 = "menu", F11 = "allies", F12 = "log" }
    if panels[key] then
        if self.panel == panels[key] then self.panel = nil else self.panel = panels[key] end
        return
    end
    if key == "ESCAPE" then
        if self.panel then self.panel = nil
        elseif self.targeting then self.targeting = nil
        elseif self.mode ~= "main" then self.mode = "main" end
        return
    end
    if self.panel then return end
    if key == "F8" then self:next_idle(); return end
    local hero_n = key:match("^F([123])$")
    if hero_n then
        local hero = self:heroes()[tonumber(hero_n)]
        if hero then
            if self.selection[1] == hero and #self.selection == 1 then self.game.set_camera(hero.x, hero.y) end
            self:select({ hero })
        end
        return
    end
    if key == "TAB" then
        local n = #self:subgroups()
        if n > 0 then self.subgroup = self.subgroup % n + 1 end
        self.mode = "main"
        return
    end
    local digit = key:match("^%d$")
    if digit then
        if input.ctrl then
            local copy = {}
            for i, u in ipairs(self.selection) do copy[i] = u end
            self.groups[digit] = copy
            self:message("Group " .. digit .. " set")
        elseif self.groups[digit] and #self.groups[digit] > 0 then
            if self.last_group_key == digit and self.time - (self.last_group_at or -9) < 0.5 then
                local u = self.groups[digit][1]
                self.game.set_camera(u.x, u.y)
            end
            self:select(self.groups[digit])
            self.last_group_key, self.last_group_at = digit, self.time
        end
        return
    end
    local card = self:card()
    local s = commands.find_hotkey(card, key)
    if s then self:press(card[s]) end
end
-- }}}

-- {{{ Panels
local MENU_BUTTONS = { "Save Game", "Load Game", "Options", "Help", "Tips", "End Game", "Return to Game" }

function Hud:click_panel(mx, my)
    local p = self.r.panel
    if not layout.inside(p, mx, my) then return end
    if self.panel == "menu" then
        for i, label in ipairs(MENU_BUTTONS) do
            local by = p.y + 60 + (i - 1) * 46
            if my >= by and my < by + 38 and mx >= p.x + 90 and mx < p.x + p.w - 90 then
                if label == "Return to Game" then self.panel = nil
                elseif label == "End Game" then self.game.quit()
                else self:message(label .. ": not in this viewer yet") end
            end
        end
    elseif my >= p.y + p.h - 50 then
        self.panel = nil   -- the OK button along the bottom
    end
end
-- }}}

-- {{{ Drawing helpers
local function rect(ui, x, y, w, h, c, a) ui.ui_rect(x, y, w, h, c[1], c[2], c[3], a or 255) end
local function frame(ui, x, y, w, h, t, c) ui.ui_frame(x, y, w, h, t, c[1], c[2], c[3], 255) end
local function text(ui, s, x, y, size, c) ui.ui_text(s, x, y, size, c[1], c[2], c[3], 255) end
local function bevel(ui, b, fill)
    rect(ui, b.x, b.y, b.w, b.h, fill or C.panel)
    frame(ui, b.x, b.y, b.w, b.h, 2, C.trim_dark)
end
local function bar(ui, x, y, w, h, frac, c)
    rect(ui, x, y, w, h, { 10, 10, 14 })
    rect(ui, x + 1, y + 1, math.max(0, (w - 2) * math.min(1, frac)), h - 2, c)
end
local function team_of(u) return designs.TEAM[u.player] or designs.TEAM[15] end
-- }}}

-- {{{ Hud:draw
function Hud:draw(ui)
    local r = self.r
    self:draw_health(ui)
    self:draw_top(ui)
    self:draw_console(ui)
    self:draw_side(ui)
    self:draw_messages(ui)
    if self.drag then
        local d = self.drag
        local x0, x1 = math.min(d.x0, d.x1), math.max(d.x0, d.x1)
        local y0, y1 = math.min(d.y0, d.y1), math.max(d.y0, d.y1)
        if x1 - x0 > 6 or y1 - y0 > 6 then frame(ui, x0, y0, x1 - x0, y1 - y0, 2, C.green) end
    end
    if self.hover and not self.panel then self:draw_tooltip(ui, self.hover) end
    if self.targeting then
        text(ui, "Select a target (right click or Esc to cancel)", r.messages.x, r.console.y - 28, 18, C.yellow)
    end
    if self.panel then self:draw_panel(ui) end
    script_ui.draw(self, ui)
end
-- }}}

-- {{{ Hud:draw_health
-- Bars over units that are hurt, selected, or all of them while Alt is
-- held, as WC3 shows them
function Hud:draw_health(ui)
    local game = self.game
    if not game.camera then return end
    local cx, cy, dist = game.camera()
    local reach = (dist or 1650) * 1.6
    local chosen = {}
    for _, u in ipairs(self.selection) do chosen[u] = true end
    for _, u in ipairs(game.units) do
        if u.alive ~= false and not u.hidden and u.hp_max and shown(game, u) and math.abs(u.x - cx) < reach and math.abs(u.y - cy) < reach
            and (self.alt or chosen[u] or (u.hp or u.hp_max) < u.hp_max) then
            local building = u.spec.design == "building"
            local sx, sy, ahead = game.to_screen(u.x, u.y, u.z + (building and 280 or 120))
            if ahead and sy > self.r.top.h and sy < self.r.console.y then
                local w = building and 70 or 36
                local frac = math.max(0, (u.hp or u.hp_max) / u.hp_max)
                local c = frac > 0.66 and C.green or (frac > 0.33 and C.yellow or C.red)
                rect(ui, sx - w / 2 - 1, sy - 1, w + 2, 7, { 0, 0, 0 }, 200)
                rect(ui, sx - w / 2, sy, w * frac, 5, c)
            end
        end
    end
end
-- }}}

-- {{{ Hud:draw_top
function Hud:draw_top(ui)
    local r, game = self.r, self.game
    rect(ui, 0, 0, r.w, r.top.h, C.frame, 235)
    ui.ui_line(0, r.top.h, r.w, r.top.h, 2, C.trim[1], C.trim[2], C.trim[3], 255)
    for _, m in ipairs(r.menu) do
        bevel(ui, m, self.panel == m.panel and C.hover or C.panel)
        text(ui, m.label, m.x + 8, m.y + 5, 16, C.gold)
        text(ui, m.key, m.x + m.w - ui.ui_text_width(m.key, 12) - 6, m.y + 7, 12, C.dim)
    end

    -- the day clock: a dial with the sun by day and the moon by night
    local c = r.clock
    local hours = game.time_of_day()
    local day = hours >= 6 and hours < 18
    ui.ui_circle(c.x + c.w / 2, 18, 20, C.frame[1], C.frame[2], C.frame[3], 255)
    ui.ui_circle(c.x + c.w / 2, 18, 18, day and 90 or 30, day and 130 or 40, day and 200 or 90, 255)
    local a = (hours / 24) * 2 * math.pi - math.pi / 2
    local sx, sy = c.x + c.w / 2 + math.cos(a) * 11, 18 + math.sin(a) * 11
    if day then ui.ui_circle(sx, sy, 6, 255, 220, 80, 255)
    else ui.ui_circle(sx, sy, 5, 230, 230, 240, 255) end
    text(ui, string.format("%02d:%02d", math.floor(hours), math.floor((hours % 1) * 60)),
         c.x + c.w / 2 + 26, 8, 14, C.text)

    -- gold, lumber, food and upkeep
    local res = game.resources(game.player)
    local x = r.resources.x
    ui.ui_circle(x + 10, 15, 8, 250, 206, 70, 255)
    text(ui, tostring(res.gold), x + 24, 7, 18, C.gold)
    rect(ui, x + 110, 9, 16, 12, { 140, 96, 50 })
    text(ui, tostring(res.lumber), x + 132, 7, 18, { 120, 220, 120 })
    rect(ui, x + 220, 8, 14, 14, { 200, 60, 60 })
    text(ui, string.format("%d/%d", res.food, res.food_cap), x + 240, 7, 18, C.text)
    -- upkeep: the game's tier (its gameplay constants), else WC3's usual 50 / 80
    local tier = res.upkeep
    if tier == nil then tier = res.food > 80 and 2 or (res.food > 50 and 1 or 0) end
    local upkeep, uc = "No Upkeep", C.green
    if tier >= 2 then upkeep, uc = "High Upkeep", C.red
    elseif tier == 1 then upkeep, uc = "Low Upkeep", C.yellow end
    text(ui, upkeep, x + 340, 7, 18, uc)
end
-- }}}

-- {{{ Hud:draw_console
function Hud:draw_console(ui)
    local r, game = self.r, self.game
    local con = r.console
    rect(ui, con.x, con.y, con.w, con.h, C.frame, 245)
    ui.ui_line(0, con.y, r.w, con.y, 3, C.trim[1], C.trim[2], C.trim[3], 255)

    -- minimap and its buttons
    local mm = r.minimap
    bevel(ui, { x = mm.x - 3, y = mm.y - 3, w = mm.w + 6, h = mm.h + 6 }, C.frame)
    if self.toggles.terrain and game.minimap.image then
        ui.ui_image(game.minimap.image, mm.x, mm.y, mm.w, mm.h)
        if game.minimap.fog then ui.ui_image(game.minimap.fog, mm.x, mm.y, mm.w, mm.h) end
    else
        rect(ui, mm.x, mm.y, mm.w, mm.h, { 8, 8, 10 })
    end
    for _, u in ipairs(game.units) do
        if u.alive ~= false and not u.hidden and (self.toggles.creeps or u.player ~= 12) and shown(game, u) then
            local px, py = self:world_to_minimap(u.x, u.y)
            local c = team_of(u)
            if self.toggles.ally_colors then
                c = self:own(u) and C.green or ((u.player == 12 or u.player == 15) and C.yellow or C.red)
            end
            local s = u.spec.design == "building" and 3 or 2
            ui.ui_rect(px - s / 2, py - s / 2, s, s, c[1], c[2], c[3], 255)
        end
    end
    for _, p in ipairs(self.pings) do
        local age = self.time - p.at
        if age < 3 then
            local px, py = self:world_to_minimap(p.x, p.y)
            ui.ui_frame(px - 4 - age * 6, py - 4 - age * 6, 8 + age * 12, 8 + age * 12, 2, 250, 220, 60, 255)
        end
    end
    -- what the camera sees
    local corners = {}
    for _, sp in ipairs({ { 0, r.top.h }, { r.w, r.top.h }, { r.w, con.y }, { 0, con.y } }) do
        local x, y = game.to_ground(sp[1], sp[2])
        if x then corners[#corners + 1] = { self:world_to_minimap(x, y) } end
    end
    if #corners == 4 then
        for i = 1, 4 do
            local a, b = corners[i], corners[i % 4 + 1]
            local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
            ui.ui_line(clamp(a[1], mm.x, mm.x + mm.w), clamp(a[2], mm.y, mm.y + mm.h),
                       clamp(b[1], mm.x, mm.x + mm.w), clamp(b[2], mm.y, mm.y + mm.h), 1, 255, 255, 255, 255)
        end
    end
    for _, mb in ipairs(r.minimap_buttons) do
        local on = mb.id ~= "signal" and self.toggles[mb.id]
        bevel(ui, mb, on and C.hover or C.panel)
        text(ui, mb.alt, mb.x + 8, mb.y + 8, 14, on and C.gold or C.dim)
    end

    -- portrait and vitals
    local lead = self:leader()
    bevel(ui, { x = r.portrait.x - 2, y = r.portrait.y - 2, w = r.portrait.w + 4, h = r.portrait.h + 4 }, C.frame)
    if lead then ui.ui_portrait(r.portrait.x, r.portrait.y, r.portrait.w, r.portrait.h) end
    if lead and #self.selection == 1 then
        local v = r.vitals
        text(ui, lead.hp_max and string.format("%d / %d", math.ceil(lead.hp or lead.hp_max), lead.hp_max) or "- / -",
             v.x + 8, v.y + 4, 16, C.green)
        if lead.mana_max and lead.mana_max > 0 then
            text(ui, string.format("%d / %d", lead.mana or lead.mana_max, lead.mana_max), v.x + 8, v.y + 24, 16, C.blue)
        end
    end

    -- information
    local info = r.info
    bevel(ui, info)
    if #self.selection == 1 and lead then
        self:draw_unit_info(ui, lead)
    elseif #self.selection > 1 then
        local groups = self:subgroups()
        local active = groups[self.subgroup] or groups[1]
        for i, u in ipairs(self.selection) do
            local ix, iy = info.x + 10 + ((i - 1) % 6) * 66, info.y + 40 + math.floor((i - 1) / 6) * 66
            local mine = false
            for _, a in ipairs(active) do mine = mine or a == u end
            bevel(ui, { x = ix, y = iy, w = 58, h = 58 }, mine and C.hover or C.slot)
            icons.draw(ui, u.spec.design == "building" and "structure" or (u.spec.hero and "hero" or "unit"),
                       ix + 4, iy + 2, 50, { team = team_of(u), archetype = u.spec.archetype })
            bar(ui, ix + 4, iy + 52, 50, 4, u.hp_max and (u.hp or u.hp_max) / u.hp_max or 1, C.green)
        end
        text(ui, string.format("%d selected  (Tab: next group)", #self.selection), info.x + 10, info.y + 10, 16, C.dim)
    end

    -- inventory: heroes carry six items (issue 532: what they carry,
    -- charges, and the slots a unit doesn't have darkened)
    local size = lead and game.inventory_size and game.inventory_size(lead) or ((lead and lead.spec.hero) and 6 or 0)
    for i, slot in ipairs(r.inventory) do
        bevel(ui, slot, C.slot)
        local it = lead and lead.inventory and lead.inventory[i - 1]
        if it then
            local name = it.type and it.type.name or it.id
            rect(ui, slot.x + 4, slot.y + 4, slot.w - 8, slot.h - 8, { 90 + (#name * 37) % 120, 80, 60 + (#name * 53) % 150 })
            text(ui, name:sub(1, 5), slot.x + 5, slot.y + 6, 12, C.text)
            if (it.charges or 0) > 0 then text(ui, tostring(it.charges), slot.x + slot.w - 16, slot.y + slot.h - 16, 12, C.gold) end
        end
        if not (lead and self:own(lead)) or i > size then
            rect(ui, slot.x + 2, slot.y + 2, slot.w - 4, slot.h - 4, { 0, 0, 0 }, 120)
        end
    end
    text(ui, "Inventory", r.inventory[5].x, r.inventory[5].y + 52, 12, C.dim)

    -- command card
    local card = self:card()
    for s = 1, 12 do
        local b, slot = card[s], r.card[s]
        bevel(ui, slot, C.slot)
        if b then
            if self.hover == b then rect(ui, slot.x + 2, slot.y + 2, slot.w - 4, slot.h - 4, C.hover) end
            local active = self.targeting == b.action
            if active then frame(ui, slot.x + 1, slot.y + 1, slot.w - 2, slot.h - 2, 3, C.gold) end
            local tint = b.action == "ability" and { 120 + (#b.label * 37) % 120, 140, 255 - (#b.label * 23) % 120 } or nil
            icons.draw(ui, b.icon, slot.x + 3, slot.y + 3, slot.w - 6,
                       { team = lead and team_of(lead), archetype = b.archetype, tint = tint })
            if b.hotkey and b.hotkey:match("^%w$") then
                rect(ui, slot.x + slot.w - 16, slot.y + 2, 14, 16, { 0, 0, 0 }, 170)
                text(ui, b.hotkey:sub(1, 1), slot.x + slot.w - 13, slot.y + 3, 14, C.gold)
            end
            -- not usable now (a skill not yet learnable, an ability
            -- cooling down): darkened, the cooldown as a shade
            if b.disabled then rect(ui, slot.x, slot.y, slot.w, slot.h, { 0, 0, 0 }, 140) end
            if b.cooldown and b.cooldown > 0 then
                rect(ui, slot.x, slot.y, slot.w, slot.h * math.min(1, b.cooldown), { 0, 0, 0 }, 150)
            end
        end
    end
end
-- }}}

-- {{{ Hud:draw_unit_info
function Hud:draw_unit_info(ui, u)
    local info, game = self.r.info, self.game
    text(ui, u.name or u.id, info.x + 12, info.y + 10, 22, C.gold)
    local kind
    if u.spec.design == "building" then kind = "Building"
    elseif u.spec.hero then
        kind = string.format("Level %d Hero", u.level or 1)
        -- experience toward the next level, and unspent skill points
        if game.constants and u.xp then
            local now = game.constants:hero_xp_needed(u.level or 1)
            local nxt = game.constants:hero_xp_needed((u.level or 1) + 1)
            kind = kind .. string.format("   XP %d / %d", math.floor(u.xp), nxt)
            if nxt > now then
                bar(ui, info.x + 12, info.y + 76, 180, 5, (u.xp - now) / (nxt - now), C.gold)
            end
        end
        if (u.skill_points or 0) > 0 then kind = kind .. string.format("   (%d skill point%s)", u.skill_points,
            u.skill_points == 1 and "" or "s") end
    else kind = ({ infantry = "Melee", ranged = "Ranged", gunner = "Ranged", caster = "Caster",
                   mounted = "Cavalry", heavy = "Heavy", flyer = "Flying", siege = "Siege",
                   ship = "Naval", worker = "Worker", beast = "Beast" })[u.spec.archetype or "infantry"] or "Unit" end
    text(ui, kind, info.x + 12, info.y + 38, 16, C.text)
    local owner = "Neutral"
    for _, p in ipairs(game.players or {}) do if p.number == u.player then owner = p.name end end
    if u.player == 12 then owner = "Neutral Hostile" end
    text(ui, owner, info.x + 12, info.y + 58, 14, team_of(u))

    local y = info.y + 88
    if u.damage then
        icons.draw(ui, "attack", info.x + 10, y - 4, 28)
        text(ui, "Damage: " .. u.damage, info.x + 44, y, 16, C.text)
        y = y + 32
    end
    icons.draw(ui, "hold", info.x + 10, y - 4, 28)
    text(ui, "Armor: " .. (u.armor and tostring(u.armor) or "-"), info.x + 44, y, 16, C.text)
    if u.spec.hero and u.str then
        text(ui, string.format("Str %s   Agi %s   Int %s", u.str, u.agi or "-", u.int or "-"),
             info.x + 200, info.y + 88, 16, C.text)
    end
    if u.order then
        text(ui, "Order: " .. u.order.kind, info.x + 200, info.y + 120, 16, C.dim)
    end
    text(ui, "'" .. u.id .. "'", info.x + info.w - 64, info.y + info.h - 22, 12, C.dim)
end
-- }}}

-- {{{ Hud:draw_side
function Hud:draw_side(ui)
    local r = self.r
    for i, hero in ipairs(self:heroes()) do
        local b = r.heroes[i]
        if not b then break end
        bevel(ui, b, self.selection[1] == hero and C.hover or C.slot)
        icons.draw(ui, "hero", b.x + 4, b.y + 2, b.w - 8, { team = team_of(hero), archetype = hero.spec.archetype })
        bar(ui, b.x, b.y + b.h + 2, b.w, 6, hero.hp_max and (hero.hp or hero.hp_max) / hero.hp_max or 1, C.green)
        bar(ui, b.x, b.y + b.h + 9, b.w, 6, (hero.mana_max or 0) > 0 and (hero.mana or 0) / hero.mana_max or 0, C.blue)
        text(ui, tostring(hero.level or 1), b.x + 4, b.y + b.h - 16, 14, C.gold)
        if hero.alive == false then rect(ui, b.x, b.y, b.w, b.h, { 0, 0, 0 }, 150) end
        text(ui, b.key, b.x + b.w + 4, b.y + 2, 12, C.dim)
    end
    local idle = #self:idle_workers()
    if idle > 0 then
        local b = r.idle
        bevel(ui, b, C.slot)
        icons.draw(ui, "unit", b.x + 3, b.y + 2, b.w - 6, { team = designs.TEAM[self.game.player], archetype = "worker" })
        text(ui, tostring(idle), b.x + b.w - 20, b.y + b.h - 18, 16, C.gold)
    end
end
-- }}}

-- {{{ Hud:draw_messages
function Hud:draw_messages(ui)
    local r = self.r
    -- the interface's own notes (8 seconds) and the script's (as long as
    -- it asked), oldest first, as screen lines
    local shown = {}
    for _, m in ipairs(self.messages) do
        if self.time - m.at < 8 then shown[#shown + 1] = { text = m.text, at = m.at, fade = 8 - (self.time - m.at) } end
    end
    local V = self.game.script
    if V then
        for _, m in ipairs(V.messages) do shown[#shown + 1] = { text = m.text, at = m.at, fade = m.ends - V.time } end
    end
    table.sort(shown, function(a, b) return a.at < b.at end)
    local lines = {}
    for _, m in ipairs(shown) do
        for _, line in ipairs(script_ui.lines(ui, m.text, 18, r.messages.w)) do
            lines[#lines + 1] = { text = line, fade = m.fade }
        end
    end
    local first = math.max(1, #lines - 7)
    local y0 = r.messages.y - math.max(0, math.min(8, #lines) - 6) * r.messages.line
    for i = first, #lines do
        local l = lines[i]
        local alpha = math.floor(255 * math.max(0, math.min(1, l.fade)))
        script_ui.text(ui, l.text, r.messages.x, y0 + (i - first) * r.messages.line, 18, C.text, alpha)
    end
end
-- }}}

-- {{{ Hud:draw_tooltip
function Hud:draw_tooltip(ui, b)
    local t = self.r.tooltip
    local lines = {}
    if b.tip then
        for line in (b.tip .. "\n"):gmatch("([^\n]*)\n") do
            line = line:gsub("|[cC]%x%x%x%x%x%x%x%x", ""):gsub("|[rRnN]", "")
            while #line > 44 do
                local cut = line:sub(1, 44):match(".*() ") or 44
                lines[#lines + 1] = line:sub(1, cut)
                line = line:sub(cut + 1)
            end
            lines[#lines + 1] = line
            if #lines >= 8 then break end
        end
    end
    local h = 36 + #lines * 18
    local y = t.bottom - h
    rect(ui, t.x, y, t.w, h, C.frame, 235)
    frame(ui, t.x, y, t.w, h, 2, C.trim)
    local key = b.hotkey and (b.hotkey == "ESCAPE" and "Esc" or b.hotkey) or nil
    local title = b.label:gsub("|[cC]%x%x%x%x%x%x%x%x", ""):gsub("|[rR]", "")
    text(ui, title .. (key and ("  (" .. key .. ")") or ""), t.x + 10, y + 8, 18, C.gold)
    for i, line in ipairs(lines) do
        text(ui, line, t.x + 10, y + 16 + i * 18, 15, C.text)
    end
end
-- }}}

-- {{{ Hud:draw_panel
function Hud:draw_panel(ui)
    local p, game = self.r.panel, self.game
    rect(ui, p.x, p.y, p.w, p.h, C.frame, 240)
    frame(ui, p.x, p.y, p.w, p.h, 3, C.trim)
    local titles = { quests = "Quests", menu = "Menu", allies = "Allies", log = "Message Log" }
    local title = titles[self.panel]
    text(ui, title, p.x + p.w / 2 - ui.ui_text_width(title, 26) / 2, p.y + 16, 26, C.gold)

    if self.panel == "menu" then
        for i, label in ipairs(MENU_BUTTONS) do
            local b = { x = p.x + 90, y = p.y + 60 + (i - 1) * 46, w = p.w - 180, h = 38 }
            bevel(ui, b)
            text(ui, label, b.x + b.w / 2 - ui.ui_text_width(label, 18) / 2, b.y + 10, 18, C.text)
        end
        return
    end

    local y = p.y + 60
    if self.panel == "quests" then
        for _, part in ipairs({ { "Main Quests", game.quests.main }, { "Optional Quests", game.quests.optional } }) do
            text(ui, part[1], p.x + 20, y, 20, C.gold)
            y = y + 26
            if #part[2] == 0 then text(ui, "(none)", p.x + 36, y, 16, C.dim); y = y + 22 end
            if #part[2] > 5 then
                text(ui, string.format("... and %d more", #part[2] - 5), p.x + 250, y - 26, 14, C.dim)
            end
            for i = 1, math.min(#part[2], 5) do
                text(ui, part[2][i], p.x + 36, y, 16, C.text)
                y = y + 22
            end
            y = y + 10
        end
    elseif self.panel == "allies" then
        text(ui, "Player", p.x + 20, y, 16, C.dim)
        text(ui, "Allied   Vision   Units", p.x + 250, y, 16, C.dim)
        y = y + 24
        for _, pl in ipairs(game.players or {}) do
            if pl.number ~= game.player and y < p.y + p.h - 70 then
                local c = designs.TEAM[pl.number] or C.dim
                rect(ui, p.x + 20, y + 2, 14, 14, c)
                text(ui, pl.name, p.x + 42, y, 16, C.text)
                for k = 0, 2 do
                    frame(ui, p.x + 268 + k * 70, y, 16, 16, 2, C.trim_dark)
                    local on
                    local sp = game.script and game.script.players[game.player]
                    if sp then on = (k == 0 and sp.ally[pl.number]) or (k == 1 and sp.vision[pl.number])
                    else on = pl.team == game.team and k < 2 end
                    if on then rect(ui, p.x + 272 + k * 70, y + 4, 8, 8, C.green) end
                end
                y = y + 24
            end
        end
    elseif self.panel == "log" then
        local log = self.log or {}
        for i = math.max(1, #log - 14), #log do
            text(ui, log[i], p.x + 20, y, 16, C.text)
            y = y + 20
        end
        if #log == 0 then text(ui, "(no messages yet)", p.x + 20, y, 16, C.dim) end
    end
    local ok = { x = p.x + p.w / 2 - 60, y = p.y + p.h - 46, w = 120, h = 34 }
    bevel(ui, ok)
    text(ui, "OK", ok.x + 48, ok.y + 8, 18, C.text)
end
-- }}}

-- {{{ Hud:paint_portrait
-- Put the leader's design in the portrait layer (call before drawing)
function Hud:paint_portrait()
    local u = self:leader()
    if u then self.game.portrait(u) end
end
-- }}}

return hud
