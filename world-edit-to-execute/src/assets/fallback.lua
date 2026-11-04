--[[
Fallback: Wire-frame Shapes When an Asset Is Missing (Issue 602)

What is drawn in place of an asset that isn't there, and the debug view of
a whole map: a unit with no model is a box outlined in its kind's colour
with a letter over it, terrain with no textures is a grid of lines at the
ground's height, a region is a dashed outline with its name, and so on. It
is also the view of a blank new map, and can be forced on (wire-frame mode)
when every asset is there.

Everything is built as data first, in WC3 units (x east, y north, z up),
as the geometry kit's primitives (geometry/kit.lua): a line is one thin
quad, so the renderer's existing geometry painting (render.geo_*) draws it
and a test can count it without a window. Labels are a separate list for
the 2D layer (render.ui_text, raylib's built-in font: no asset needed).

    local fallback = require("assets.fallback")
    local F = fallback.new({ loader = L })          -- L: an assets.loader (optional)
    local out = F:build({
        terrain = fallback.blank(64, 64),           -- or { width, height, x0, y0, tile, height_at }
        objects = { { kind = "unit", x = 0, y = 0, type_id = "hfoo" }, ... },
        regions = { { name = "Spawn", x1 = -512, y1 = -512, x2 = 0, y2 = 0 } },
        cameras = { { name = "Intro", x = 0, y = -900, z = 600, target_x = 0, target_y = 0 } },
        waypoints = { { x = 300, y = 300 } },
    })
    fallback.emit(out, render, true, ground)        -- paint the primitives
    fallback.draw_labels(out.labels, render, viewer.to_screen)
    F:texture("Textures\\Missing.blp")               -- the loader's, or a checker placeholder
    F:is_active(path)  F:force_wireframe(true)  F:set_debug_overlay(true)
    F:register("unit", function(obj, ctx) ctx:wire_box(...) end)   -- draw a kind your own way

Kinds and colours (fallback.COLORS): unit blue, flyer cyan, building brown,
hero gold, tree green, doodad grey, item purple, region orange, camera red,
waypoint yellow; a selected object is outlined again, thicker, in green.
]]

local kit = require("geometry.kit")

local fallback = {}

-- {{{ constants
fallback.COLORS = {
    unit     = { 60, 110, 230 },
    flyer    = { 60, 210, 230 },
    building = { 150, 100, 50 },
    hero     = { 235, 190, 40 },
    tree     = { 50, 170, 60 },
    doodad   = { 150, 150, 150 },
    item     = { 165, 80, 205 },
    region   = { 240, 140, 40 },
    camera   = { 220, 50, 50 },
    waypoint = { 240, 230, 60 },
    selected = { 90, 240, 90 },
    grid     = { 70, 70, 70 },
    unknown  = { 230, 40, 230 },
}

-- The letter drawn over each kind (the issue's U, B, H, and the rest).
fallback.LETTERS = {
    unit = "U", flyer = "U", building = "B", hero = "H", item = "I",
    camera = "C", waypoint = "W",
}

-- Sizes in WC3 units: { length, width, height }.
fallback.SIZES = {
    unit     = { 64, 64, 96 },
    flyer    = { 64, 64, 64 },
    building = { 192, 192, 160 },
    hero     = { 72, 72, 120 },
    item     = { 32, 32, 32 },
    tree     = { 96, 96, 192 },
    doodad   = { 64, 64, 64 },
    camera   = { 48, 48, 48 },
    waypoint = { 48, 48, 0 },
}

fallback.LINE = 6            -- a line's width
fallback.SELECTED_LINE = 12
fallback.FLY_HEIGHT = 256    -- where a flyer is drawn without its own z
fallback.DASH, fallback.GAP = 48, 32
fallback.TILE = 128
-- }}}

-- {{{ fallback.kind_of
-- What an object is, for its colour and shape: its own `kind` when it
-- names one; a doodad flagged `tree` is a tree; a WC3 type id starting with
-- a capital letter is a hero (Hpal, Obla: WC3's convention), `building` and
-- `flying` flags make a building and a flyer; anything else is a unit.
function fallback.kind_of(obj)
    if obj.kind and fallback.COLORS[obj.kind] then return obj.kind end
    if obj.doodad then return obj.tree and "tree" or "doodad" end
    if obj.building then return "building" end
    if type(obj.type_id) == "string" and obj.type_id:match("^%u") then return "hero" end
    if obj.flying then return "flyer" end
    return "unit"
end
-- }}}

-- {{{ fallback.color_for
function fallback.color_for(kind_or_obj)
    local kind = type(kind_or_obj) == "table" and fallback.kind_of(kind_or_obj) or kind_or_obj
    return fallback.COLORS[kind] or fallback.COLORS.unknown
end
-- }}}

-- {{{ fallback.texture
-- A checkerboard of the kind's colour and near-black, SIZE by SIZE (8),
-- as a decoded texture { width, height, rgba } like the loader gives:
-- what a missing texture is drawn with.
function fallback.texture(kind, size)
    size = size or 8
    local c = fallback.COLORS[kind or "unknown"] or fallback.COLORS.unknown
    local on = string.char(c[1], c[2], c[3], 255)
    local off = string.char(20, 20, 24, 255)
    local rows = {}
    for y = 0, size - 1 do
        local row = {}
        for x = 0, size - 1 do
            row[#row + 1] = (math.floor(x / 2) + math.floor(y / 2)) % 2 == 0 and on or off
        end
        rows[#rows + 1] = table.concat(row)
    end
    return { width = size, height = size, rgba = table.concat(rows), placeholder = true }
end
-- }}}

-- {{{ fallback.blank
-- The terrain of a blank map, WIDTH by HEIGHT tiles, flat, centred on 0.
function fallback.blank(width, height)
    return {
        width = width, height = height, tile = fallback.TILE,
        x0 = -width * fallback.TILE / 2, y0 = -height * fallback.TILE / 2,
        height_at = function() return 0 end,
    }
end
-- }}}

-- {{{ the drawing context
-- Painters draw through this: each call adds kit primitives or labels.
local Ctx = {}
Ctx.__index = Ctx

-- A line from P to Q ({x, y, z} each) as one quad WIDTH wide: lying flat
-- (seen from above) for a line that runs along the ground or slopes, and
-- standing across the view (facing south, as the WC3 camera looks north)
-- for a vertical one.
function Ctx:line(p, q, color, width)
    local w = (width or self.width) / 2
    local dx, dy = q[1] - p[1], q[2] - p[2]
    local flat = math.sqrt(dx * dx + dy * dy)
    local ox, oy, oz
    if flat > 1e-6 then
        ox, oy, oz = -dy / flat * w, dx / flat * w, 0
    else
        ox, oy, oz = w, 0, 0
    end
    self.prims[#self.prims + 1] = { kind = "quad", color = color, pts = {
        { p[1] - ox, p[2] - oy, p[3] - oz }, { p[1] + ox, p[2] + oy, p[3] + oz },
        { q[1] + ox, q[2] + oy, q[3] + oz }, { q[1] - ox, q[2] - oy, q[3] - oz } } }
    self.lines = self.lines + 1
end

-- The twelve edges of a box: (x, y, z) the centre of its base, LEN along
-- YAW, WID across, HGT up.
function Ctx:wire_box(x, y, z, len, wid, hgt, yaw, color, width)
    yaw = yaw or 0
    local corners = {}
    for i, s in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
        local cx, cy = kit.local_point(x, y, yaw, s[1] * len / 2, s[2] * wid / 2)
        corners[i] = { cx, cy }
    end
    for i = 1, 4 do
        local a, b = corners[i], corners[i % 4 + 1]
        self:line({ a[1], a[2], z }, { b[1], b[2], z }, color, width)
        if hgt > 0 then
            self:line({ a[1], a[2], z + hgt }, { b[1], b[2], z + hgt }, color, width)
            self:line({ a[1], a[2], z }, { a[1], a[2], z + hgt }, color, width)
        end
    end
end

-- A solid box (a kit primitive), for marks too small to outline.
function Ctx:box(x, y, z, len, wid, hgt, yaw, color)
    self.prims[#self.prims + 1] = { kind = "box", x = x, y = y, z = z, len = len, wid = wid,
                                    hgt = hgt, yaw = yaw or 0, color = color }
end

-- A dashed line from P to Q at ground level.
function Ctx:dashed(p, q, color, width)
    local dx, dy, dz = q[1] - p[1], q[2] - p[2], q[3] - p[3]
    local len = math.sqrt(dx * dx + dy * dy + dz * dz)
    if len < 1e-6 then return end
    local step = fallback.DASH + fallback.GAP
    local at = 0
    while at < len do
        local stop = math.min(at + fallback.DASH, len)
        local a, b = at / len, stop / len
        self:line({ p[1] + dx * a, p[2] + dy * a, p[3] + dz * a },
                  { p[1] + dx * b, p[2] + dy * b, p[3] + dz * b }, color, width)
        at = at + step
    end
end

-- A label for the 2D layer, at a point in the world.
function Ctx:label(x, y, z, text, color)
    self.labels[#self.labels + 1] = { x = x, y = y, z = z, text = text, color = color or { 235, 235, 235 } }
end
-- }}}

-- {{{ built-in painters
local painters = {}

local function size_of(obj, kind)
    local s = fallback.SIZES[kind] or fallback.SIZES.unit
    return obj.length or obj.size or s[1], obj.width or obj.size or s[2], obj.height or s[3]
end

local function body(obj, ctx, kind)
    local len, wid, hgt = size_of(obj, kind)
    local color = fallback.color_for(kind)
    local ground = ctx.ground_at(obj.x, obj.y)
    local z = obj.z or ground
    if kind == "flyer" and not obj.z then z = ground + fallback.FLY_HEIGHT end
    ctx:wire_box(obj.x, obj.y, z, len, wid, hgt, obj.facing, color)
    if z > ground + 1 then
        -- a line to the ground, and a cross where it lands: how high it is
        ctx:line({ obj.x, obj.y, z }, { obj.x, obj.y, ground }, color)
        ctx:line({ obj.x - len / 4, obj.y, ground }, { obj.x + len / 4, obj.y, ground }, color)
        ctx:line({ obj.x, obj.y - wid / 4, ground }, { obj.x, obj.y + wid / 4, ground }, color)
    end
    ctx:label(obj.x, obj.y, z + hgt + 16, fallback.LETTERS[kind] or "?", color)
    return z, len, wid, hgt
end

for _, kind in ipairs({ "unit", "flyer", "building", "hero", "item", "camera" }) do
    painters[kind] = function(obj, ctx)
        local z, len, wid, hgt = body(obj, ctx, kind)
        if kind == "camera" and obj.target_x then
            local tz = ctx.ground_at(obj.target_x, obj.target_y)
            ctx:line({ obj.x, obj.y, z + hgt / 2 }, { obj.target_x, obj.target_y, tz }, fallback.COLORS.camera)
        end
        return z, len, wid, hgt
    end
end

-- A tree: a trunk and three legs from its top, like /|\.
painters.tree = function(obj, ctx)
    local len, _, hgt = size_of(obj, "tree")
    local color = fallback.color_for("tree")
    local z = obj.z or ctx.ground_at(obj.x, obj.y)
    local top = { obj.x, obj.y, z + hgt }
    ctx:line({ obj.x, obj.y, z }, top, color)
    for i = 0, 2 do
        local a = (i / 3) * 2 * math.pi + math.pi / 2
        ctx:line(top, { obj.x + math.cos(a) * len / 2, obj.y + math.sin(a) * len / 2, z + hgt * 0.35 }, color)
    end
    return z, len, len, hgt
end

-- A doodad: an asterisk standing on the ground.
painters.doodad = function(obj, ctx)
    local len, _, hgt = size_of(obj, "doodad")
    local color = fallback.color_for("doodad")
    local z = obj.z or ctx.ground_at(obj.x, obj.y)
    local mid = z + hgt / 2
    ctx:line({ obj.x, obj.y, z }, { obj.x, obj.y, z + hgt }, color)
    ctx:line({ obj.x - len / 2, obj.y, mid }, { obj.x + len / 2, obj.y, mid }, color)
    ctx:line({ obj.x - len / 3, obj.y, mid - hgt / 3 }, { obj.x + len / 3, obj.y, mid + hgt / 3 }, color)
    ctx:line({ obj.x - len / 3, obj.y, mid + hgt / 3 }, { obj.x + len / 3, obj.y, mid - hgt / 3 }, color)
    return z, len, len, hgt
end

-- A waypoint: a diamond on the ground.
painters.waypoint = function(obj, ctx)
    local r = (fallback.SIZES.waypoint)[1] / 2
    local color = fallback.color_for("waypoint")
    local z = obj.z or ctx.ground_at(obj.x, obj.y)
    local pts = { { obj.x + r, obj.y, z }, { obj.x, obj.y + r, z }, { obj.x - r, obj.y, z }, { obj.x, obj.y - r, z } }
    for i = 1, 4 do ctx:line(pts[i], pts[i % 4 + 1], color) end
    if obj.name then ctx:label(obj.x, obj.y, z + 16, obj.name, color) end
    return z, 2 * r, 2 * r, 0
end
fallback.PAINTERS = painters
-- }}}

local F = {}
F.__index = F

-- {{{ function fallback.new
-- opts: loader (an assets.loader, for is_active, texture and model),
-- overlay (debug labels), force (wire-frame for everything), has_model
-- (function(obj) -> true when the real model will be drawn instead).
function fallback.new(opts)
    opts = opts or {}
    return setmetatable({
        loader = opts.loader,
        overlay = opts.overlay or false,
        force = opts.force or false,
        has_model = opts.has_model,
        painters = setmetatable({}, { __index = painters }),
        placeheld = {},
    }, F)
end
-- }}}

-- {{{ function F:register / F:color_for / F:set_debug_overlay / F:force_wireframe
-- Draws KIND with FN(obj, ctx) instead of the built-in shape; nil puts the
-- built-in back.
function F:register(kind, fn)
    if fn ~= nil and type(fn) ~= "function" then
        error("fallback: register wants a function, got " .. type(fn), 2)
    end
    self.painters[kind] = fn
end

function F:color_for(kind_or_obj) return fallback.color_for(kind_or_obj) end
function F:set_debug_overlay(on) self.overlay = on and true or false end
function F:force_wireframe(on) self.force = on and true or false end
-- }}}

-- {{{ function F:is_active
-- True when PATH is drawn by the fallback: wire-frame mode is forced, the
-- loader looked for it and didn't find it (or couldn't read it), or this
-- fallback handed out a placeholder for it.
function F:is_active(path)
    if self.force then return true end
    local key = path:gsub("\\", "/"):gsub("^/+", ""):lower()
    if self.placeheld[key] then return true end
    if self.loader then
        return self.loader.missing[key] ~= nil and not self.loader.cache:has(key)
    end
    return false
end
-- }}}

-- {{{ function F:texture / F:model
-- The loader's texture, or a placeholder (KIND's checkerboard) when it is
-- missing or wire-frame mode is on; and where it came from ("fallback").
function F:texture(path, kind)
    local key = path:gsub("\\", "/"):gsub("^/+", ""):lower()
    if not self.force and self.loader then
        local img, from = self.loader:get(path)
        if img and type(img) == "table" and img.rgba then
            self.placeheld[key] = nil
            return img, from
        end
    end
    self.placeheld[key] = true
    return fallback.texture(kind), "fallback"
end

-- The loader's model, or nil when it is missing or wire-frame mode is on
-- (the caller then draws the object through build()).
function F:model(path)
    local key = path:gsub("\\", "/"):gsub("^/+", ""):lower()
    if not self.force and self.loader then
        local m, from = self.loader:get(path)
        if m ~= nil then
            self.placeheld[key] = nil
            return m, from
        end
    end
    self.placeheld[key] = true
    return nil, "fallback"
end
-- }}}

-- {{{ local function grid
-- The terrain as lines between its vertices, at their heights. A line is
-- wider where the ground is higher (the issue's "height shown via line
-- thickness"), and each vertex has a dot when there are few enough.
local function grid(ctx, t)
    local tile = t.tile or fallback.TILE
    local every = t.every or 1
    local hat = t.height_at or function() return 0 end
    local color = fallback.COLORS.grid
    local function vertex(ix, iy)
        return { t.x0 + ix * tile, t.y0 + iy * tile, hat(ix, iy) or 0 }
    end
    local function width_at(z)
        return fallback.LINE * (1 + math.max(0, math.min(1, z / 512)))
    end
    for iy = 0, t.height, every do
        for ix = 0, t.width - every, every do
            local a, b = vertex(ix, iy), vertex(ix + every, iy)
            ctx:line(a, b, color, width_at((a[3] + b[3]) / 2))
        end
    end
    for ix = 0, t.width, every do
        for iy = 0, t.height - every, every do
            local a, b = vertex(ix, iy), vertex(ix, iy + every)
            ctx:line(a, b, color, width_at((a[3] + b[3]) / 2))
        end
    end
    local dots = t.dots
    if dots == nil then dots = (t.width / every + 1) * (t.height / every + 1) <= 4225 end
    if dots then
        for iy = 0, t.height, every do
            for ix = 0, t.width, every do
                local v = vertex(ix, iy)
                ctx:box(v[1], v[2], v[3], 10, 10, 6, 0, { 110, 110, 110 })
            end
        end
    end
end
-- }}}

-- {{{ function F:build
-- Everything in SCENE drawn the fallback way. Returns
-- { prims, labels, lines, drawn = { kind -> count }, skipped } where
-- skipped counts objects has_model said would be drawn for real.
function F:build(scene)
    local ctx = setmetatable({ prims = {}, labels = {}, lines = 0, width = fallback.LINE }, Ctx)
    local t = scene.terrain
    ctx.ground_at = function(x, y)
        if not t or not t.height_at then return 0 end
        local tile = t.tile or fallback.TILE
        local ix = math.floor((x - t.x0) / tile + 0.5)
        local iy = math.floor((y - t.y0) / tile + 0.5)
        if ix < 0 or iy < 0 or ix > t.width or iy > t.height then return 0 end
        return t.height_at(ix, iy) or 0
    end
    local drawn, skipped = {}, 0
    if t then grid(ctx, t) end

    for _, obj in ipairs(scene.objects or {}) do
        if not self.force and self.has_model and self.has_model(obj) then
            skipped = skipped + 1
        else
            local kind = fallback.kind_of(obj)
            local paint = self.painters[kind] or painters.unit
            local z, len, wid, hgt = paint(obj, ctx)
            drawn[kind] = (drawn[kind] or 0) + 1
            if obj.selected and z then
                ctx:wire_box(obj.x, obj.y, z, (len or 64) + 16, (wid or 64) + 16, (hgt or 0) + 8, obj.facing,
                    fallback.COLORS.selected, fallback.SELECTED_LINE)
            end
            if self.overlay and z then
                ctx:label(obj.x, obj.y, z - 16, string.format("%s%s (%d, %d)",
                    obj.type_id and (obj.type_id .. " ") or "", obj.id and ("#" .. obj.id) or "",
                    math.floor(obj.x + 0.5), math.floor(obj.y + 0.5)), { 200, 200, 200 })
            end
        end
    end

    for _, r in ipairs(scene.regions or {}) do
        local color = fallback.COLORS.region
        local x1, y1 = math.min(r.x1, r.x2), math.min(r.y1, r.y2)
        local x2, y2 = math.max(r.x1, r.x2), math.max(r.y1, r.y2)
        local function at(x, y) return { x, y, ctx.ground_at(x, y) + 2 } end
        ctx:dashed(at(x1, y1), at(x2, y1), color)
        ctx:dashed(at(x2, y1), at(x2, y2), color)
        ctx:dashed(at(x2, y2), at(x1, y2), color)
        ctx:dashed(at(x1, y2), at(x1, y1), color)
        local cx, cy = (x1 + x2) / 2, (y1 + y2) / 2
        ctx:label(cx, cy, ctx.ground_at(cx, cy) + 8, r.name or "region", color)
        drawn.region = (drawn.region or 0) + 1
    end
    for _, c in ipairs(scene.cameras or {}) do
        local obj = setmetatable({ kind = "camera" }, { __index = c })
        local paint = self.painters.camera
        paint(obj, ctx)
        if c.name then ctx:label(c.x, c.y, (c.z or 0) + 72, c.name, fallback.COLORS.camera) end
        drawn.camera = (drawn.camera or 0) + 1
    end
    for _, w in ipairs(scene.waypoints or {}) do
        self.painters.waypoint(w, ctx)
        drawn.waypoint = (drawn.waypoint or 0) + 1
    end
    return { prims = ctx.prims, labels = ctx.labels, lines = ctx.lines, drawn = drawn, skipped = skipped }
end
-- }}}

-- {{{ function fallback.emit
-- Paints OUT's primitives through render.geo_* (geometry/kit.lua places
-- them); DYNAMIC: the per-frame layer. Returns how many were painted.
function fallback.emit(out, render, dynamic, ground)
    return kit.emit_prims(out.prims, render, dynamic, ground)
end
-- }}}

-- {{{ function fallback.draw_labels
-- Draws OUT's labels with render.ui_text at the screen points TO_SCREEN
-- gives (scene_viewer's viewer.to_screen: x, y, z -> sx, sy, in_front),
-- centred, skipping those behind the camera. Returns how many were drawn.
function fallback.draw_labels(labels, render, to_screen, size)
    size = size or 14
    local n = 0
    for _, l in ipairs(labels) do
        local sx, sy, in_front = to_screen(l.x, l.y, l.z)
        if sx and in_front ~= false then
            local w = render.ui_text_width and render.ui_text_width(l.text, size) or (#l.text * size / 2)
            render.ui_text(l.text, sx - w / 2, sy - size / 2, size, l.color[1], l.color[2], l.color[3], 255)
            n = n + 1
        end
    end
    return n
end
-- }}}

return fallback
