-- see-in-3d-render.lua - Draws a scene's triangles from one camera into a
-- buffer of pixels, with no graphics card and no library.
--
-- In plain terms: a camera sits some distance from the middle of everything
-- in the scene, looking at it -- from the front, the right, above, or at an
-- angle. Each triangle is projected onto the picture, and each pixel it covers
-- keeps the colour of whatever is nearest the camera there (a depth buffer).
-- Faces are lit by one light from above and to the side, so their angle
-- shows, with a soft second light from the camera so faces seen straight on
-- keep their colour; both sides of a face are lit alike, so a shape built inside out still
-- reads. Under everything lies a chequered floor at height zero (lower, if a
-- shape goes below zero), found per pixel by following the ray from the camera down to it, so
-- height and position read even with nothing else in view.
--
-- Memory first: the picture and depth buffers are allocated once per view as
-- flat arrays (red, green, blue bytes; one depth number per pixel) and the
-- triangles are walked straight through the model's flat coordinate arrays.

local ffi = require("ffi")
local M = {}

-- {{{ M.views
-- The four cameras, in the order the sheet lays them out (left to right, top
-- to bottom). Azimuth turns around the scene from the front (0) toward the
-- right (90); elevation lifts the camera (90 is straight down).
M.views = {
    { name = "front", label = "FRONT", azimuth = 0, elevation = 8 },
    { name = "right", label = "RIGHT", azimuth = 90, elevation = 8 },
    { name = "top", label = "TOP", azimuth = 0, elevation = 89.5 },
    { name = "angle", label = "ANGLE", azimuth = 35, elevation = 28 },
}
-- }}}

-- {{{ colours
local BACKGROUND = { 244, 242, 238 }
local GROUND_LIGHT = { 226, 222, 214 }
local GROUND_DARK = { 208, 203, 194 }
local LIGHT = { -0.45, 0.8, 0.4 }   -- toward the light; normalised below
do
    local length = math.sqrt(LIGHT[1] ^ 2 + LIGHT[2] ^ 2 + LIGHT[3] ^ 2)
    LIGHT = { LIGHT[1] / length, LIGHT[2] / length, LIGHT[3] / length }
end
local FIELD_OF_VIEW = math.rad(40)
-- }}}

-- {{{ local function bounds()
-- The middle of everything, its lowest point, and the radius that holds it all.
local function bounds(model)
    local lo, hi = { math.huge, math.huge, math.huge }, { -math.huge, -math.huge, -math.huge }
    local axes = { model.px, model.py, model.pz }
    for axis = 1, 3 do
        for _, v in ipairs(axes[axis]) do
            if v < lo[axis] then lo[axis] = v end
            if v > hi[axis] then hi[axis] = v end
        end
    end
    -- the ground is the floor, y = 0, unless something goes below it; it is
    -- counted in the framing, so a shape floating above the floor shows its gap
    local ground = math.min(0, lo[2])
    lo[2] = ground
    local centre = { (lo[1] + hi[1]) / 2, (lo[2] + hi[2]) / 2, (lo[3] + hi[3]) / 2 }
    local radius = math.sqrt((hi[1] - lo[1]) ^ 2 + (hi[2] - lo[2]) ^ 2 + (hi[3] - lo[3]) ^ 2) / 2
    if radius <= 0 then radius = 1 end
    return centre, ground, radius
end
-- }}}

-- {{{ local vector helpers
local function sub(a, b) return { a[1] - b[1], a[2] - b[2], a[3] - b[3] } end
local function dot(a, b) return a[1] * b[1] + a[2] * b[2] + a[3] * b[3] end
local function cross(a, b) return { a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1] } end
local function unit(a)
    local length = math.sqrt(dot(a, a))
    return { a[1] / length, a[2] / length, a[3] / length }
end
-- }}}

-- {{{ local function camera()
-- Where the camera is and which ways are right, up and forward for it. Looking
-- straight down, "up" on the picture is toward the back of the scene.
local function camera(view, centre, radius)
    local az, el = math.rad(view.azimuth), math.rad(view.elevation)
    local distance = radius / math.sin(FIELD_OF_VIEW / 2) * 1.08
    local eye = { centre[1] + distance * math.sin(az) * math.cos(el), centre[2] + distance * math.sin(el),
        centre[3] + distance * math.cos(az) * math.cos(el) }
    local forward = unit(sub(centre, eye))
    local world_up = (view.elevation > 80) and { 0, 0, -1 } or { 0, 1, 0 }
    local right = unit(cross(forward, world_up))
    local up = cross(right, forward)
    return { eye = eye, forward = forward, right = right, up = up }
end
-- }}}

-- {{{ M.render(model, view, size)
-- One view as a string of size x size red-green-blue bytes.
function M.render(model, view, size)
    local centre, ground_y, radius = bounds(model)
    local cam = camera(view, centre, radius)
    local focal = (size / 2) / math.tan(FIELD_OF_VIEW / 2)
    local pixels = ffi.new("uint8_t[?]", size * size * 3)
    local depth = ffi.new("double[?]", size * size)   -- 1 / distance; 0 means nothing drawn yet
    local half = size / 2

    -- the ground: every pixel's ray followed down to the ground's height
    local cell = radius / 3
    local extent = radius * 2.2
    for y = 0, size - 1 do
        for x = 0, size - 1 do
            local u, v = (x + 0.5 - half) / focal, (half - y - 0.5) / focal
            local ray = { cam.forward[1] + cam.right[1] * u + cam.up[1] * v,
                cam.forward[2] + cam.right[2] * u + cam.up[2] * v,
                cam.forward[3] + cam.right[3] * u + cam.up[3] * v }
            local colour = BACKGROUND
            local index = y * size + x
            -- a ray that goes down far enough meets the ground; others see sky
            if ray[2] < -1e-9 then
                local t = (ground_y - cam.eye[2]) / ray[2]
                local gx, gz = cam.eye[1] + ray[1] * t, cam.eye[3] + ray[3] * t
                if t > 0 and math.abs(gx - centre[1]) < extent and math.abs(gz - centre[3]) < extent then
                    local parity = (math.floor((gx - centre[1]) / cell) + math.floor((gz - centre[3]) / cell)) % 2
                    colour = (parity == 0) and GROUND_LIGHT or GROUND_DARK
                    depth[index] = 1 / (t * dot(ray, cam.forward)) * 0.999999
                end
            end
            pixels[index * 3], pixels[index * 3 + 1], pixels[index * 3 + 2] = colour[1], colour[2], colour[3]
        end
    end

    -- the triangles
    local px, py, pz, cr, cg, cb = model.px, model.py, model.pz, model.cr, model.cg, model.cb
    local sx, sy, inverse = {}, {}, {}
    for t = 1, #cr do
        local base = (t - 1) * 3
        local corners = {}
        local behind = false
        for k = 1, 3 do
            local p = { px[base + k], py[base + k], pz[base + k] }
            corners[k] = p
            local d = sub(p, cam.eye)
            local z = dot(d, cam.forward)
            -- a corner behind the camera cannot be projected; the camera is
            -- always outside everything, so this marks a broken model
            if z <= 1e-6 then behind = true break end
            sx[k] = half + dot(d, cam.right) / z * focal
            sy[k] = half - dot(d, cam.up) / z * focal
            inverse[k] = 1 / z
        end
        if not behind then
            local normal = cross(sub(corners[2], corners[1]), sub(corners[3], corners[1]))
            local length = math.sqrt(dot(normal, normal))
            -- a glowing face gives off its own light and shows its colour as
            -- given; every other face gets a little everywhere-light, the key
            -- light from above and to the side (so slopes read), and a soft
            -- light from the camera itself (so a face seen straight on shows
            -- near its true colour -- with the key light alone, a white page
            -- facing the camera came out mid-grey)
            local light = 0.25
            if model.glow[t] then light = 1
            elseif length > 0 then
                light = 0.25 + 0.4 * math.abs(dot(normal, LIGHT)) / length + 0.4 * math.abs(dot(normal, cam.forward)) / length
            end
            local r, g, b = math.min(255, cr[t] * light * 255 + 0.5), math.min(255, cg[t] * light * 255 + 0.5), math.min(255, cb[t] * light * 255 + 0.5)
            local x0 = math.max(0, math.floor(math.min(sx[1], sx[2], sx[3])))
            local x1 = math.min(size - 1, math.ceil(math.max(sx[1], sx[2], sx[3])))
            local y0 = math.max(0, math.floor(math.min(sy[1], sy[2], sy[3])))
            local y1 = math.min(size - 1, math.ceil(math.max(sy[1], sy[2], sy[3])))
            local area = (sx[2] - sx[1]) * (sy[3] - sy[1]) - (sx[3] - sx[1]) * (sy[2] - sy[1])
            if math.abs(area) > 1e-12 then
                for y = y0, y1 do
                    for x = x0, x1 do
                        local cx, cy = x + 0.5, y + 0.5
                        local w1 = ((sx[2] - cx) * (sy[3] - cy) - (sx[3] - cx) * (sy[2] - cy)) / area
                        local w2 = ((sx[3] - cx) * (sy[1] - cy) - (sx[1] - cx) * (sy[3] - cy)) / area
                        local w3 = 1 - w1 - w2
                        if w1 >= 0 and w2 >= 0 and w3 >= 0 then
                            local z = w1 * inverse[1] + w2 * inverse[2] + w3 * inverse[3]
                            local index = y * size + x
                            if z > depth[index] then
                                depth[index] = z
                                pixels[index * 3], pixels[index * 3 + 1], pixels[index * 3 + 2] = r, g, b
                            end
                        end
                    end
                end
            end
        end
    end
    return ffi.string(pixels, size * size * 3)
end
-- }}}

-- {{{ glyphs
-- A 5x7 letter for each letter the view labels use; each row is five bits,
-- left to right.
local glyphs = {
    A = { 14, 17, 17, 31, 17, 17, 17 }, E = { 31, 16, 16, 30, 16, 16, 31 }, F = { 31, 16, 16, 30, 16, 16, 16 },
    G = { 14, 17, 16, 23, 17, 17, 15 }, H = { 17, 17, 17, 31, 17, 17, 17 }, I = { 14, 4, 4, 4, 4, 4, 14 },
    L = { 16, 16, 16, 16, 16, 16, 31 }, N = { 17, 25, 21, 19, 17, 17, 17 }, O = { 14, 17, 17, 17, 17, 17, 14 },
    P = { 30, 17, 17, 30, 16, 16, 16 }, R = { 30, 17, 17, 30, 20, 18, 17 }, T = { 31, 4, 4, 4, 4, 4, 4 },
}
-- }}}

-- {{{ M.sheet(views, size)
-- Four rendered views (strings of size x size RGB, in M.views order) laid out
-- 2 x 2, each labelled in its top-left corner, with a thin line between.
-- Returns the sheet's RGB string; it is 2 * size on each side.
function M.sheet(rendered, size)
    local width = size * 2
    local out = ffi.new("uint8_t[?]", width * width * 3)
    for index, view in ipairs(M.views) do
        local ox, oy = ((index - 1) % 2) * size, math.floor((index - 1) / 2) * size
        local source = rendered[index]
        for y = 0, size - 1 do
            ffi.copy(out + ((oy + y) * width + ox) * 3, ffi.cast("const char *", source) + y * size * 3, size * 3)
        end
        -- the label, two pixels per glyph dot, dark grey
        local cursor = ox + 10
        for letter in view.label:gmatch(".") do
            local rows = glyphs[letter]
            for row = 1, 7 do
                for column = 0, 4 do
                    if math.floor(rows[row] / 2 ^ (4 - column)) % 2 == 1 then
                        for dy = 0, 1 do for dx = 0, 1 do
                            local i = ((oy + 10 + (row - 1) * 2 + dy) * width + cursor + column * 2 + dx) * 3
                            out[i], out[i + 1], out[i + 2] = 60, 60, 60
                        end end
                    end
                end
            end
            cursor = cursor + 12
        end
    end
    -- the dividing lines
    for k = 0, width - 1 do
        for _, at in ipairs({ (size * width + k) * 3, (k * width + size) * 3 }) do
            out[at], out[at + 1], out[at + 2] = 150, 150, 150
        end
    end
    return ffi.string(out, width * width * 3)
end
-- }}}

return M
