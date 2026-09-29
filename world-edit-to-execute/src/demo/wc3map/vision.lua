--[[
Fog of War (Issue 524)

What each player sees, the way WC3 works it out:

  cells     the map's tile grid (128 units a cell), per player: how many
            of its sight sources see each cell, and whether it has ever
            been seen (explored)
  states    visible (seen now), fogged (seen before: the ground and the
            buildings as they were, no units), masked (never seen: black)
  sight     each living unit sees a circle: its day or night sight radius
            (the map's fields usid/usin, else stand-ins below). Ground
            units don't see onto higher cliff levels than their own, nor
            past them, nor past trees; flyers see over everything
  sharing   a player sees what the players sharing vision with it see
            (the script's alliances; else forces flagged "share vision")
  modifiers the script's fog modifiers (CreateFogModifierRect/Radius):
            "visible" ones reveal an area; "fogged" and "masked" ones
            cover one, over the units' sight when made "after units"
  switches  FogEnable(false): all visible; FogMaskEnable(false): nothing
            black (everything at least fogged)

Sight is worked out per unit only when it moves to another cell, its
radius changes (day and night) or it dies: each unit keeps the cells it
lights, and they're added to and taken from its owner's counts. A full
update every quarter second is then cheap.

    local vision = require("demo.wc3map.vision")
    local V = vision.new(game)        -- after the units exist
    V:update(dt)                      -- every tick (works every UPDATE_EVERY)
    V:state(player, x, y)             -- 2 visible, 1 fogged, 0 masked
    V:sees(player, u)                 -- can player see unit u
    V:mask(player)                    -- a byte per cell for the renderer

Stand-in sight radii (not stock values): units 1400 by day and 800 by
night, heroes 1800/800, buildings 900/600, towers 1600/900.
]]

local ffi = require("ffi")

local vision = {}

vision.CELL = 128
vision.UPDATE_EVERY = 0.25
vision.VISIBLE, vision.FOGGED, vision.MASKED = 2, 1, 0
-- bytes for the renderer's fog texture: how light each state is drawn
vision.SHADE = { [0] = 0, [1] = 110, [2] = 255 }

local SIGHT = {
    unit = { 1400, 800 }, hero = { 1800, 800 }, building = { 900, 600 }, tower = { 1600, 900 },
}

local V = {}
V.__index = V

-- {{{ vision.new
function vision.new(game, opts)
    opts = opts or {}
    local t = game.scene.terrain
    local self = setmetatable({
        game = game, w = t.width, h = t.height, x0 = t.offset_x, y0 = t.offset_y,
        count = {}, explored = {}, clock = 0, due = 0, fog = true, mask_on = true,
        modifiers = {}, templates = {}, stamped = {}, share_cache = {},
    }, V)
    local n = self.w * self.h
    self.n = n
    -- cliff level and sight blockers (trees) per cell
    self.level = ffi.new("uint8_t[?]", n)
    self.blocker = ffi.new("uint8_t[?]", n)
    for j = 0, self.h - 1 do
        for i = 0, self.w - 1 do
            local tp = t:get_tile(i, j)
            self.level[j * self.w + i] = tp and tp.layer_height or 0
        end
    end
    for _, d in ipairs(game.scene.doodads or {}) do
        if d.spec and d.spec.design == "tree" then
            local k = self:cell(d.x, d.y)
            if k then self.blocker[k] = 1 end
        end
    end
    self.override = {}      -- per player: bytes, 0 none, 1 masked, 2 fogged, (+4: over units)
    return self
end
-- }}}

-- {{{ Cells
function V:cell(x, y)
    local i = math.floor((x - self.x0) / vision.CELL + 0.5)
    local j = math.floor((y - self.y0) / vision.CELL + 0.5)
    if i < 0 or j < 0 or i >= self.w or j >= self.h then return nil end
    return j * self.w + i, i, j
end

function V:counts(p)
    local c = self.count[p]
    if not c then
        c = ffi.new("uint16_t[?]", self.n)
        self.count[p] = c
        self.explored[p] = ffi.new("uint8_t[?]", self.n)
    end
    return c, self.explored[p]
end
-- }}}

-- {{{ Sight templates
-- For a radius in cells: every offset inside it, and the cells a line
-- from the middle crosses on its way there (to test for blocking)
local function template(r)
    local offs, paths = {}, {}
    for dy = -r, r do
        for dx = -r, r do
            if dx * dx + dy * dy <= r * r + r then
                local path = {}
                local steps = math.max(math.abs(dx), math.abs(dy))
                for s = 1, steps - 1 do
                    local px = math.floor(dx * s / steps + 0.5)
                    local py = math.floor(dy * s / steps + 0.5)
                    path[#path + 1] = { px, py }
                end
                offs[#offs + 1] = { dx, dy }
                paths[#paths + 1] = path
            end
        end
    end
    return { offs = offs, paths = paths }
end

function V:template(r)
    local t = self.templates[r]
    if not t then
        t = template(r)
        self.templates[r] = t
    end
    return t
end
-- }}}

-- {{{ Sight of a unit
function vision.sight_radius(u, night)
    if u.sight_day or u.sight_night then
        return (night and (u.sight_night or u.sight_day) or (u.sight_day or u.sight_night)) or 0
    end
    local s = SIGHT.unit
    if u.spec.hero then s = SIGHT.hero
    elseif u.spec.design == "building" then
        s = (u.attacks and u.attacks ~= 0) and SIGHT.tower or SIGHT.building
    end
    return night and s[2] or s[1]
end

-- The cells unit u lights from where it stands (an int32 array and count)
function V:light(u, r)
    local k, ci, cj = self:cell(u.x, u.y)
    if not k then return nil, 0 end
    local tpl = self:template(r)
    local out = ffi.new("int32_t[?]", #tpl.offs)
    local n = 0
    local flying = u.spec.archetype == "flyer"
    local lv = self.level[k]
    local w, h, level, blocker = self.w, self.h, self.level, self.blocker
    for idx, o in ipairs(tpl.offs) do
        local i, j = ci + o[1], cj + o[2]
        if i >= 0 and j >= 0 and i < w and j < h then
            local ok = true
            if not flying then
                local target = j * w + i
                if level[target] > lv then
                    ok = false
                else
                    for _, pth in ipairs(tpl.paths[idx]) do
                        local pi, pj = ci + pth[1], cj + pth[2]
                        if pi >= 0 and pj >= 0 and pi < w and pj < h then
                            local c = pj * w + pi
                            if level[c] > lv or blocker[c] ~= 0 then ok = false; break end
                        end
                    end
                end
            end
            if ok then
                out[n] = j * w + i
                n = n + 1
            end
        end
    end
    return out, n
end
-- }}}

-- {{{ Stamps
local function add(self, p, cells, n, d)
    local c, ex = self:counts(p)
    for q = 0, n - 1 do
        local k = cells[q]
        c[k] = c[k] + d
        if d > 0 then ex[k] = 1 end
    end
end

-- whose sight a unit gives: nobody's for the neutral passive players
local function source(u)
    return u.alive and not u.removed and not u.hidden and u.player <= 12
end

function V:refresh_unit(u, night)
    local key
    if source(u) then
        local k = self:cell(u.x, u.y)
        local r = math.floor(vision.sight_radius(u, night) / vision.CELL + 0.5)
        if k and r > 0 then key = (k * 64 + math.min(r, 63)) * 16 + u.player end
    end
    if key == u.vis_key then return false end
    if u.vis_cells then add(self, u.vis_owner, u.vis_cells, u.vis_n, -1) end
    u.vis_cells, u.vis_n, u.vis_owner, u.vis_key = nil, 0, nil, key
    self.stamped[u] = nil
    if key then
        local r = math.floor(vision.sight_radius(u, night) / vision.CELL + 0.5)
        local cells, n = self:light(u, math.min(r, 63))
        if cells then
            add(self, u.player, cells, n, 1)
            u.vis_cells, u.vis_n, u.vis_owner = cells, n, u.player
            self.stamped[u] = true
        end
    end
    return true
end
-- }}}

-- {{{ V:update
function V:update(dt, force)
    self.clock = self.clock + (dt or 0)
    if not force and self.clock < self.due then return end
    self.due = self.clock + vision.UPDATE_EVERY
    local tod = self.game.time_of_day and self.game.time_of_day() or 12
    local night = tod < 6 or tod >= 18
    local changed = 0
    self.share_cache = {}
    self.masks = nil
    -- units gone from the game's list take their sight with them
    local present = {}
    for _, u in ipairs(self.game.units) do present[u] = true end
    for u in pairs(self.stamped) do
        if not present[u] then
            add(self, u.vis_owner, u.vis_cells, u.vis_n, -1)
            u.vis_cells, u.vis_n, u.vis_owner, u.vis_key = nil, 0, nil, nil
            self.stamped[u] = nil
        end
    end
    for _, u in ipairs(self.game.units) do
        if self:refresh_unit(u, night) then changed = changed + 1 end
        -- the local player remembers buildings it has seen
        if u.spec.design == "building" and not u.seen and self:sees(self.game.player, u, true) then
            u.seen = true
            self.game.buildings_changed = true
        end
    end
    self.changed = changed
    self.version = (self.version or 0) + 1
    return changed
end
-- }}}

-- {{{ Sharing
-- the players whose sight player p shares (p itself first)
function V:sharers(p)
    local list = self.share_cache[p]
    if list then return list end
    local g = self.game
    list = { p }
    for q in pairs(self.count) do
        if q ~= p and g.shares_vision and g.shares_vision(q, p) then list[#list + 1] = q end
    end
    self.share_cache[p] = list
    return list
end
-- }}}

-- {{{ Queries
-- A cell's state for player p (k: the cell index)
function V:cell_state(p, k)
    if not self.fog then return 2 end
    local ov = self.override[p]
    local o = ov and ov[k] or 0
    if o >= 4 then return o == 5 and (self.mask_on and 0 or 1) or 1 end
    local seen, explored = false, false
    for _, q in ipairs(self:sharers(p)) do
        local c = self.count[q]
        if c then
            if c[k] > 0 then seen = true; break end
            if self.explored[q][k] ~= 0 then explored = true end
        end
    end
    if seen then return 2 end
    if o == 1 then return self.mask_on and 0 or 1 end
    if o == 2 then return 1 end
    if explored or not self.mask_on then return 1 end
    return 0
end

function V:state(p, x, y)
    local k = self:cell(x, y)
    if not k then return 0 end
    return self:cell_state(p, k)
end

-- Can player p see unit u: its own and its sharers' always; others when
-- they stand in a visible cell (and aren't invisible). remembered: a
-- building the player has seen before counts while it's fogged
function V:sees(p, u, now_only)
    if not self.fog then return true end
    if u.player == p then return true end
    local g = self.game
    if g.shares_vision and g.shares_vision(u.player, p) then return true end
    local s = self:state(p, u.x, u.y)
    if s == 2 then return not u.invisible end
    if not now_only and s == 1 and u.seen and u.spec.design == "building" and p == g.player then return true end
    return false
end

-- A byte per cell (w x h, row 0 the southmost) for player p: how light
-- the renderer draws it (vision.SHADE). The same rules as cell_state, in
-- one loop over the grid
function V:mask(p)
    self.masks = self.masks or {}
    if self.masks[p] then return self.masks[p] end
    local n = self.n
    local buf = ffi.new("uint8_t[?]", n)
    local shade = vision.SHADE
    local s0, s1, s2 = shade[0], shade[1], shade[2]
    if not self.fog then
        ffi.fill(buf, n, s2)
    else
        local counts, exps = {}, {}
        for _, q in ipairs(self:sharers(p)) do
            if self.count[q] then counts[#counts + 1] = self.count[q]; exps[#exps + 1] = self.explored[q] end
        end
        local nc = #counts
        local ov = self.override[p]
        local mask_on = self.mask_on
        for k = 0, n - 1 do
            local o = ov and ov[k] or 0
            local st
            if o >= 4 then
                st = (o == 5 and mask_on) and 0 or 1
            else
                st = 0
                for c = 1, nc do
                    if counts[c][k] > 0 then st = 2; break end
                    if exps[c][k] ~= 0 then st = 1 end
                end
                if st ~= 2 then
                    if o == 1 then st = mask_on and 0 or 1
                    elseif o == 2 or not mask_on then st = 1 end
                end
            end
            buf[k] = st == 2 and s2 or (st == 1 and s1 or s0)
        end
    end
    local out = ffi.string(buf, n)
    self.masks[p] = out
    return out
end
-- }}}

-- {{{ Script control: switches, modifiers, one-off states
function V:enable(on) self.fog = on and true or false; self.masks = nil end
function V:enable_mask(on) self.mask_on = on and true or false; self.masks = nil end

-- the cells of a shape: { x0, y0, x1, y1 } or { x, y, r }
function V:shape_cells(shape)
    local list = {}
    local x0, y0, x1, y1
    if shape.r then
        x0, y0, x1, y1 = shape.x - shape.r, shape.y - shape.r, shape.x + shape.r, shape.y + shape.r
    else
        x0, y0, x1, y1 = shape.x0, shape.y0, shape.x1, shape.y1
    end
    local _, i0, j0 = self:cell(math.max(x0, self.x0), math.max(y0, self.y0))
    local _, i1, j1 = self:cell(math.min(x1, self.x0 + (self.w - 1) * vision.CELL),
                                math.min(y1, self.y0 + (self.h - 1) * vision.CELL))
    if not i0 or not i1 then return list end
    for j = j0, j1 do
        for i = i0, i1 do
            local cx, cy = self.x0 + i * vision.CELL, self.y0 + j * vision.CELL
            if not shape.r or (cx - shape.x) ^ 2 + (cy - shape.y) ^ 2 <= shape.r ^ 2 then
                list[#list + 1] = j * self.w + i
            end
        end
    end
    return list
end

-- state: "visible" | "fogged" | "masked"
function V:modifier(p, state, shape, after_units)
    local m = { player = p, state = state, cells = self:shape_cells(shape), after = after_units, on = false }
    self.modifiers[#self.modifiers + 1] = m
    return m
end

local function rebuild_overrides(self)
    self.override = {}
    for _, m in ipairs(self.modifiers) do
        if m.on and m.state ~= "visible" then
            local ov = self.override[m.player]
            if not ov then ov = ffi.new("uint8_t[?]", self.n); self.override[m.player] = ov end
            local v = (m.state == "masked" and 1 or 2) + (m.after and 4 or 0)
            for _, k in ipairs(m.cells) do ov[k] = v end
        end
    end
    self.masks = nil
end

function V:start(m)
    if not m or m.on or m.gone then return end
    m.on = true
    if m.state == "visible" then
        local cells = ffi.new("int32_t[?]", math.max(1, #m.cells))
        for q, k in ipairs(m.cells) do cells[q - 1] = k end
        m.stamp = cells
        add(self, m.player, cells, #m.cells, 1)
    else
        rebuild_overrides(self)
    end
    self.masks = nil
end

function V:stop(m)
    if not m or not m.on then return end
    m.on = false
    if m.state == "visible" then
        add(self, m.player, m.stamp, #m.cells, -1)
        m.stamp = nil
    else
        rebuild_overrides(self)
    end
    self.masks = nil
end

function V:destroy(m)
    if not m then return end
    self:stop(m)
    m.gone = true
    for i, x in ipairs(self.modifiers) do
        if x == m then table.remove(self.modifiers, i); break end
    end
end

-- SetFogStateRect/Radius: at once, and left so: "visible" explores the
-- area (and shows it until the next update), "fogged" explores it,
-- "masked" forgets it
function V:set_state(p, state, shape)
    local _, ex = self:counts(p)
    for _, k in ipairs(self:shape_cells(shape)) do
        ex[k] = state == "masked" and 0 or 1
    end
    self.masks = nil
end
-- }}}

return vision
