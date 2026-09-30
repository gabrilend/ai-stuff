--[[
Terrain Brushes (Issue 902)

The tools that change the ground, over the tilepoints within the brush
(brush.size tilepoints about the point; the change falls off toward the
edge for the height tools):

  raise, lower   height up or down by brush.strength a touch
  smooth         each toward its neighbours' mean
  flatten        to the height where the stroke began
  paint          ground texture brush.texture (the map's tilesets, in order)
  water, dry     water at brush.level (else a little over the ground where
                 the stroke began), or none
  cliff_up/down  the cliff level up or down one (a cliff shows between
                 levels; the tile gets the first cliff tileset when it had
                 none)
  blight, unblight

A stroke is one step to undo: stroke_begin, stroke(x, y) as often as the
pointer moves, stroke_end. The tilepoints a stroke touched are marked in
E.changed_tiles for the window to draw again.

    require("editor.terrain")(E)     -- editor/init.lua does this
]]

local w3e = require("parsers.w3e")

local FIELDS = { "height", "water_level", "has_water", "water_flags", "ground_texture", "texture_details",
                 "layer_height", "cliff_texture", "cliff_variation", "is_ramp", "is_blight" }
local HEIGHT_MIN, HEIGHT_MAX = -2000, 6000
local TERRAIN_TOOLS = { raise = true, lower = true, smooth = true, flatten = true, paint = true, water = true,
                        dry = true, cliff_up = true, cliff_down = true, blight = true, unblight = true }

local function snapshot(tp)
    local s = {}
    for _, f in ipairs(FIELDS) do s[f] = tp[f] end
    return s
end
local function restore(tp, s)
    for _, f in ipairs(FIELDS) do tp[f] = s[f] end
end

return function(E)

    function E:is_terrain_tool(name) return TERRAIN_TOOLS[name or self.tool] == true end

    -- {{{ where
    function E:tile_at(x, y)
        local t = self.terrain
        local i = math.floor((x - t.offset_x) / 128 + 0.5)
        local j = math.floor((y - t.offset_y) / 128 + 0.5)
        if i < 0 or j < 0 or i >= t.width or j >= t.height then return nil end
        return i, j
    end

    function E:ground_z(x, y)
        local i, j = self:tile_at(x, y)
        if not i then return 0 end
        return w3e.ground_z(self.terrain.tilepoints[j][i])
    end

    -- the tilepoints within r tilepoints of (i, j), with how near (1 at
    -- the middle, falling to 0 past the edge)
    function E:tiles_in(i, j, r)
        local t = self.terrain
        local out = {}
        for dj = -r, r do
            for di = -r, r do
                local d = math.sqrt(di * di + dj * dj)
                local ni, nj = i + di, j + dj
                if d <= r + 0.01 and ni >= 0 and nj >= 0 and ni < t.width and nj < t.height then
                    out[#out + 1] = { i = ni, j = nj, near = 1 - d / (r + 1) }
                end
            end
        end
        return out
    end
    -- }}}

    -- {{{ strokes
    function E:stroke_begin(tool, x, y)
        tool = tool or self.tool
        if not TERRAIN_TOOLS[tool] then return false end
        self.stroke_now = { tool = tool, before = {}, keys = {} }
        if x then
            local i, j = self:tile_at(x, y)
            if i then
                local tp = self.terrain.tilepoints[j][i]
                self.stroke_now.flat = tp.height
                self.stroke_now.level = self.brush.level or (w3e.ground_z(tp) + 64 + w3e.WATER_OFFSET)
            end
        end
        return true
    end

    local function touch(self, i, j)
        local s = self.stroke_now
        local k = j * self.terrain.width + i
        local tp = self.terrain.tilepoints[j][i]
        if not s.before[k] then
            s.before[k] = snapshot(tp)
            s.keys[#s.keys + 1] = k
        end
        self.changed_tiles[k] = true
        self.terrain_touched[k] = true
        return tp
    end

    -- one touch of the brush at (x, y)
    function E:stroke(x, y)
        local s = self.stroke_now
        if not s then return false end
        local ci, cj = self:tile_at(x, y)
        if not ci then return false end
        local t = self.terrain
        local b = self.brush
        local tiles = self:tiles_in(ci, cj, b.size)
        if s.flat == nil then
            s.flat = t.tilepoints[cj][ci].height
            s.level = b.level or (w3e.ground_z(t.tilepoints[cj][ci]) + 64 + w3e.WATER_OFFSET)
        end
        local tool = s.tool
        -- smoothing reads the heights before this touch
        local old = {}
        if tool == "smooth" then
            for _, p in ipairs(tiles) do
                for dj = -1, 1 do
                    for di = -1, 1 do
                        local ni, nj = p.i + di, p.j + dj
                        local tp = t.tilepoints[nj] and t.tilepoints[nj][ni]
                        if tp then old[nj * t.width + ni] = tp.height end
                    end
                end
            end
        end
        for _, p in ipairs(tiles) do
            local tp = touch(self, p.i, p.j)
            if tool == "raise" or tool == "lower" then
                local d = b.strength * p.near * (tool == "raise" and 1 or -1)
                tp.height = math.max(HEIGHT_MIN, math.min(HEIGHT_MAX, tp.height + d))
            elseif tool == "smooth" then
                local sum, n = 0, 0
                for dj = -1, 1 do
                    for di = -1, 1 do
                        local h = old[(p.j + dj) * t.width + (p.i + di)]
                        if h then sum, n = sum + h, n + 1 end
                    end
                end
                if n > 0 then tp.height = tp.height + (sum / n - tp.height) * math.min(1, 0.5 * p.near + 0.25) end
            elseif tool == "flatten" then
                tp.height = s.flat
            elseif tool == "paint" then
                tp.ground_texture = math.max(0, math.min(#t.ground_tilesets - 1, b.texture or 0))
            elseif tool == "water" then
                tp.has_water, tp.water_level = true, s.level
            elseif tool == "dry" then
                tp.has_water = false
            elseif tool == "cliff_up" or tool == "cliff_down" then
                -- once a stroke for each tilepoint
                if not s.cliffed then s.cliffed = {} end
                local k = p.j * t.width + p.i
                if not s.cliffed[k] then
                    s.cliffed[k] = true
                    tp.layer_height = math.max(0, math.min(15, tp.layer_height + (tool == "cliff_up" and 1 or -1)))
                    if tp.cliff_texture == 15 then tp.cliff_texture = 0 end
                end
            elseif tool == "blight" or tool == "unblight" then
                tp.is_blight = tool == "blight"
            end
        end
        self.dirty.terrain = true
        return true
    end

    function E:stroke_end()
        local s = self.stroke_now
        self.stroke_now = nil
        if not s or #s.keys == 0 then return nil end
        local t = self.terrain
        local after = {}
        for _, k in ipairs(s.keys) do
            local i, j = k % t.width, math.floor(k / t.width)
            after[k] = snapshot(t.tilepoints[j][i])
        end
        local me = self
        local function put(which)
            for _, k in ipairs(s.keys) do
                local i, j = k % t.width, math.floor(k / t.width)
                restore(t.tilepoints[j][i], which[k])
                me.changed_tiles[k] = true
                me.terrain_touched[k] = true
            end
            me.dirty.terrain = true
        end
        local names = { raise = "Raise", lower = "Lower", smooth = "Smooth", flatten = "Flatten", paint = "Paint",
                        water = "Water", dry = "Dry", cliff_up = "Cliff up", cliff_down = "Cliff down",
                        blight = "Blight", unblight = "Clear blight" }
        local cmd = { name = (names[s.tool] or s.tool) .. " (" .. #s.keys .. " points)",
                      redo = function() put(after) end, undo = function() put(s.before) end }
        self.history:record(cmd)
        return cmd.name
    end

    -- the tilepoints changed since the window last asked (and forget them)
    function E:take_changed_tiles()
        local list = {}
        for k in pairs(self.changed_tiles) do list[#list + 1] = k end
        self.changed_tiles = {}
        return list
    end
    -- }}}
end
