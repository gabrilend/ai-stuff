--[[
Building Footprints (Issue 536)

What a building covers, as WC3 reads it: its pathing texture (upat, e.g.
"PathTextures\8x8SimpleSolid.tga"), one pixel a 32-unit cell, centred on
the building, the top row north. A pixel's red keeps walkers out, green
fliers, blue builders (white: all three). Buildings are placed on the
32-unit cells so their texture lines up with the map's own.

Where it fits is read cell by cell against the map's pathing map
(war3map.wpm: a byte a 32-unit cell, 0x02 no walking, 0x04 no flying,
0x08 no building, 0x20 blight, 0x40 land rather than water), the ground's
cliff levels and slope, and the cells other buildings keep.

The shape comes from, in order:

  1. the texture itself, read through the map and the owner's install
     (g.assets:texture) when there is one;
  2. its name ("8x8SimpleSolid": 8 by 8 cells, all kept; "...Unbuildable":
     kept from building only);
  3. a STAND-IN by the building's size (tower 4x4, small 6x6, medium and
     altar 8x8, hall 12x12 cells).

    local fp = require("demo.wc3map.footprint")
    local sh = fp.shape(g, "hbar")        -- { w, h, cells = { [j * w + i] = flags }, source }
    local x, y = fp.snap(sh, x, y)
    local ok, why, marks = fp.check(g, "hbar", x, y)   -- marks: per cell, for drawing
    fp.radius(g, id)                      -- half its larger side, in world units
]]

local footprint = {}

footprint.CELL = 32
footprint.NO_WALK, footprint.NO_FLY, footprint.NO_BUILD = 0x02, 0x04, 0x08
footprint.BLIGHT, footprint.LAND = 0x20, 0x40
footprint.STANDIN = { tower = 4, small = 6, medium = 8, altar = 8, special = 8, hall = 12 }

local ALL = 0x02 + 0x04 + 0x08

-- {{{ the map's pathing map (war3map.wpm)
function footprint.parse_wpm(data)
    if not data or #data < 16 or data:sub(1, 4) ~= "MP3W" then return nil end
    local function i32(p)
        local a, b, c, d = data:byte(p, p + 3)
        return a + b * 256 + c * 65536 + d * 16777216
    end
    local w, h = i32(9), i32(13)
    if #data < 16 + w * h then return nil end
    return { w = w, h = h, bytes = data:sub(17, 16 + w * h) }
end

-- the flags of the cell at a world point, or nil without a map
function footprint.map_flags(g, x, y)
    local pm = g.path_map
    if pm == nil then
        pm = false
        local path = g.scene and g.scene.path
        if path then
            local ok, archive = pcall(require("mpq").open, path)
            if ok and archive then
                if archive:has("war3map.wpm") then
                    local ok2, data = pcall(archive.extract, archive, "war3map.wpm")
                    pm = ok2 and footprint.parse_wpm(data) or false
                end
                archive:close()
            end
        end
        g.path_map = pm
    end
    if not pm then return nil end
    local b = g.bounds
    local i = math.floor((x - b.x0) / footprint.CELL)
    local j = math.floor((y - b.y0) / footprint.CELL)
    if i < 0 or j < 0 or i >= pm.w or j >= pm.h then return ALL end
    return pm.bytes:byte(j * pm.w + i + 1)
end
-- }}}

-- {{{ footprint.shape
local function solid(w, h, flags)
    local cells = {}
    for k = 0, w * h - 1 do cells[k] = flags end
    return cells
end

local function from_image(img)
    local w, h = img.width, img.height
    local cells = {}
    local rgba = img.rgba
    for j = 0, h - 1 do
        for i = 0, w - 1 do
            local p = (j * w + i) * 4 + 1
            local r, gr, b = rgba:byte(p, p + 2)
            local f = 0
            if r > 127 then f = f + footprint.NO_WALK end
            if gr > 127 then f = f + footprint.NO_FLY end
            if b > 127 then f = f + footprint.NO_BUILD end
            cells[j * w + i] = f
        end
    end
    return cells
end

function footprint.shape(g, id)
    g.footprints = g.footprints or {}
    local sh = g.footprints[id]
    if sh then return sh end
    local D = g.data and g.data.units
    local path = D and (D:value(id, "upat"))
    if type(path) ~= "string" or path == "" or path == "_" then path = nil end
    local img = path and g.assets and g.assets:texture(path)
    if img and img.width > 0 and img.width <= 64 and img.height <= 64 then
        sh = { w = img.width, h = img.height, cells = from_image(img), source = "texture", path = path }
    elseif path and path:match("(%d+)x(%d+)") then
        local w, h = path:match("(%d+)x(%d+)")
        w, h = tonumber(w), tonumber(h)
        local flags = path:lower():find("unbuildable") and footprint.NO_BUILD or ALL
        sh = { w = w, h = h, cells = solid(w, h, flags), source = "name", path = path }
    else
        local spec = g.unit_spec and g.unit_spec(id) or {}
        local n = footprint.STANDIN[spec.size or "medium"] or 8
        sh = { w = n, h = n, cells = solid(n, n, ALL), source = "stand-in", path = path }
    end
    g.footprints[id] = sh
    return sh
end

function footprint.radius(g, id)
    local sh = footprint.shape(g, id)
    return math.max(sh.w, sh.h) * footprint.CELL / 2
end
-- }}}

-- {{{ placing on the cells
-- the centre that lines the texture up with the 32-unit cells
function footprint.snap(sh, x, y)
    local c = footprint.CELL
    local hw, hh = sh.w * c / 2, sh.h * c / 2
    return math.floor((x - hw) / c + 0.5) * c + hw, math.floor((y - hh) / c + 0.5) * c + hh
end

-- each kept cell of a shape at (x, y): f(world cell i, j, flags, cx, cy)
function footprint.each(sh, x, y, f)
    local c = footprint.CELL
    local left, top = x - sh.w * c / 2, y + sh.h * c / 2
    for j = 0, sh.h - 1 do
        for i = 0, sh.w - 1 do
            local flags = sh.cells[j * sh.w + i]
            if flags and flags ~= 0 then
                local cx, cy = left + (i + 0.5) * c, top - (j + 0.5) * c
                f(math.floor(cx / c), math.floor(cy / c), flags, cx, cy)
            end
        end
    end
end

-- the cells other buildings keep builders off (their no-build or no-walk ones)
local function taken(g, near_x, near_y, reach)
    local t = {}
    for _, u in ipairs(g.units) do
        if u.spec.design == "building" and u.alive ~= false and not u.removed
            and math.abs(u.x - near_x) < reach and math.abs(u.y - near_y) < reach then
            footprint.each(footprint.shape(g, u.id), u.x, u.y, function(i, j, flags)
                if flags % 16 >= footprint.NO_BUILD or flags % 4 >= footprint.NO_WALK then
                    t[i .. "," .. j] = true
                end
            end)
        end
    end
    return t
end

-- does building id fit at (x, y): true, or false and why; marks[k] = true
-- for each cell (in footprint.each order) that fits
function footprint.check(g, id, x, y)
    local sh = footprint.shape(g, id)
    local b = g.bounds
    local occupied = taken(g, x, y, (sh.w + 32) * footprint.CELL)
    local t = g.scene.terrain
    local sample = g.scene.sample
    local why, level, lo, hi
    local marks = {}
    footprint.each(sh, x, y, function(i, j, flags, cx, cy)
        local bad
        if cx < b.x0 or cy < b.y0 or cx > b.x1 or cy > b.y1 then
            bad = "off the map"
        else
            local mf = footprint.map_flags(g, cx, cy)
            if mf then
                if mf % 128 < footprint.LAND then bad = "can't build on water"
                elseif mf % 16 >= footprint.NO_BUILD or mf % 4 >= footprint.NO_WALK then bad = "can't build there" end
            else
                if g.pathing then
                    local pi, pj = g.pathing:cell(cx, cy)
                    if not g.pathing:walkable(pi, pj) then bad = "can't build there" end
                end
                if not bad and sample.water_at(cx, cy) > sample.ground_at(cx, cy) + 1 then bad = "can't build on water" end
            end
            if not bad and occupied[i .. "," .. j] then bad = "something's in the way" end
            if not bad then
                local z = sample.ground_at(cx, cy)
                lo, hi = math.min(lo or z, z), math.max(hi or z, z)
                local tp = t:get_tile(math.floor((cx - t.offset_x) / 128 + 0.5), math.floor((cy - t.offset_y) / 128 + 0.5))
                if tp then
                    if level and tp.layer_height ~= level then bad = "not level ground" end
                    level = level or tp.layer_height
                end
            end
        end
        marks[#marks + 1] = not bad
        why = why or bad
    end)
    if not why and lo and hi - lo > 96 then why = "not level ground" end
    if why then return false, why, marks end
    return true, nil, marks
end
-- }}}

return footprint
