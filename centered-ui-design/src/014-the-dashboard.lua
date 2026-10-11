-- 014-the-dashboard.lua - the arch console, drawn as three layers.
--
-- In plain terms: the console in the middle of the screen is an arch (one
-- hump of an M, see 019). Its band is the display of the map — the map
-- painted onto it from far beyond (024), its ally's quadrant unrolled along
-- it. Beneath its curve is the dashboard surface. Everything is drawn into
-- four pictures the size of the window, which the view plane (015) lays over
-- the world:
--
--   face   the brushed-metal surface under the arch, with windows cut out,
--          painted buttons, engraved labels, gold edges along the band
--   dials  what lies beneath the windows: paper-thin discs with words and
--          numbers inscribed on them, turned by the game to show a value,
--          each clipped to its own window
--   glass  for each window and for the band, how strongly and which way its
--          glass bends what is beneath it (red = glass here; green and blue =
--          the direction of the bend, 0.5 meaning none; alpha 1 = a dial is
--          beneath, alpha 0.5 = the band's painted map is beneath)
--   band   where on the map each band pixel paints: red = how far along the
--          band (0 left foot .. 1 right foot), green = how far across (0
--          inner edge = the hub .. 1 outer edge = the farthest tier), blue =
--          which ally's quadrant (seat - 1, over the team's size)
--
-- Allies: the whole console is one arch per ally, a ring of them; the row
-- slides as the player turns their chair (M.set_chair), and a clip shows
-- only your own arch and the very edge of the next. Only your own arch's
-- buttons answer.
--
-- The player clicks only painted buttons. Dials and the band are
-- information: they ignore the mouse completely. The settings menu (Escape)
-- is a panel of painted buttons around one dial showing the framerate cap.
--
-- Positions inside the arch are written in arch units (across from the
-- center, up from the base, as shares of the arch's height), so the layout is
-- data and keeps its proportions at any window size.
--
-- This is viewing code. Clicks on buttons are reported back to the game as
-- verbs; the game decides what they mean.

local arch = require("019-the-arch")

local M = {}

M.MONTHS = { "JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE", "JULY",
    "AUGUST", "SEPTEMBER", "OCTOBER", "NOVEMBER", "DECEMBER" }
M.MONTH_DAYS = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
M.WEEKDAYS = { "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY", "SUNDAY" }

-- The arch's band thickness as a share of its height. Its height is a
-- setting (a share of the window's height); its width is the window's: it
-- stands on the bottom pixel row and reaches both sides (the owner, issue
-- 302). Each section keeps these whatever the number of allies.

-- {{{ function M.width_share_for()
-- The arch's width as a share of its height, for a window and a height share.
function M.width_share_for(width, height, height_share)
    return width / (height * height_share)
end
-- }}}

M.ARCH_BAND_SHARE = 0.085
-- How much of each neighbour's arch shows beside your own, as a share of
-- your arch's width: "only your own, and the very edge of your allies".
-- Turn your chair to see more of theirs.
M.NEIGHBOUR_SHOWN = 0.03

-- The center the calendar rings turn around (arch units).
M.CALENDAR_CENTER = { 0, 0.20 }

-- The order buttons: verb, label, paint, and where they sit (arch units):
-- two columns up the inside of the arch's legs.
M.ORDER_BUTTONS = {
    { verb = "advance",     label = "ADVANCE",   paint = { 0.20, 0.85, 0.35 }, across = -0.28, up = 0.33 },
    { verb = "attack",      label = "ATTACK",    paint = { 0.95, 0.20, 0.18 }, across = -0.28, up = 0.24 },
    { verb = "hold",        label = "HOLD",      paint = { 1.00, 0.72, 0.10 }, across = -0.28, up = 0.15 },
    { verb = "fall_back",   label = "FALL BACK", paint = { 0.20, 0.45, 1.00 }, across = -0.28, up = 0.06 },
    { verb = "flank_left",  label = "FLANK L",   paint = { 0.10, 0.85, 0.90 }, across = 0.28,  up = 0.33 },
    { verb = "flank_right", label = "FLANK R",   paint = { 0.65, 0.35, 1.00 }, across = 0.28,  up = 0.24 },
    { verb = "shield",      label = "SHIELD",    paint = { 0.15, 0.80, 0.65 }, across = 0.28,  up = 0.15 },
    { verb = "build",       label = "BUILD",     paint = { 1.00, 0.45, 0.10 }, across = 0.28,  up = 0.06 },
}
M.ORDER_BUTTON_RADIUS = 0.04

-- The settings menu's buttons (arch units).
M.SETTINGS_BUTTONS = {
    { verb = "cap_minus_10",   label = "-10",  paint = { 0.20, 0.45, 1.00 }, across = -0.24, up = 0.43 },
    { verb = "cap_plus_10",    label = "+10",  paint = { 1.00, 0.45, 0.10 }, across = 0.24,  up = 0.43 },
    { verb = "cap_minus_1",    label = "-1",   paint = { 0.10, 0.85, 0.90 }, across = -0.12, up = 0.43 },
    { verb = "cap_plus_1",     label = "+1",   paint = { 1.00, 0.72, 0.10 }, across = 0.12,  up = 0.43 },
    { verb = "close_settings", label = "BACK", paint = { 0.20, 0.85, 0.35 }, across = -0.10, up = 0.07 },
    { verb = "quit",           label = "QUIT", paint = { 0.95, 0.20, 0.18 }, across = 0.10,  up = 0.07 },
    -- the look toggles (issue 214): each shows its current choice
    { verb = "toggle_depth",    look = "depth",    paint = { 0.65, 0.35, 1.00 }, across = -0.30, up = 0.19 },
    { verb = "toggle_standing", look = "standing", paint = { 0.15, 0.80, 0.65 }, across = 0,     up = 0.19 },
    { verb = "toggle_blur",     look = "blur",     paint = { 0.10, 0.85, 0.90 }, across = 0.30,  up = 0.19 },
}

-- What a look toggle's button says for each choice.
M.LOOK_WORDS = {
    depth = { flat = "FLAT VIEW", hub = "HUB VIEW", slant = "SLANT VIEW", arch = "ARCH VIEW" },
    standing = { upright = "UPRIGHT", outward = "OUTWARD" },
    blur = { on = "BLUR ON", off = "BLUR OFF" },
}
M.SETTINGS_BUTTON_RADIUS = 0.042

-- Every window, in arch units. `only` says when it is shown: "always",
-- "orders" (settings shut) or "settings" (settings open).
--   arc:   around the calendar center, between two radii and two angles
--          (degrees, screen convention: -90 is straight up)
--   round: a circular hole
--   slot:  a rounded rectangle
M.WINDOWS = {
    { dial = "month",    shape = "arc",   only = "orders", inner = 0.46, outer = 0.53, from = -104, to = -76 },
    { dial = "weekday",  shape = "arc",   only = "orders", inner = 0.36, outer = 0.43, from = -104, to = -76 },
    { dial = "day",      shape = "round", only = "orders", across = 0, up = 0.49, radius = 0.035 },
    { dial = "fps",      shape = "round", only = "always", across = -0.15, up = 0.30, radius = 0.055 },
    { dial = "frame_ms", shape = "round", only = "always", across = 0,     up = 0.30, radius = 0.055 },
    { dial = "units",    shape = "round", only = "always", across = 0.15,  up = 0.30, radius = 0.055 },
    { dial = "named",    shape = "slot",  only = "orders", across = 0, up = 0.115, half_width = 0.17, half_height = 0.035 },
    { dial = "cap",      shape = "round", only = "settings", across = 0, up = 0.56, radius = 0.075 },
    -- how many cuboids rest in each color's section (ink in that color)
    { dial = "section_1", shape = "round", only = "orders", across = -0.20, up = 0.425, radius = 0.028 },
    { dial = "section_2", shape = "round", only = "orders", across = -0.11, up = 0.425, radius = 0.028 },
    { dial = "section_3", shape = "round", only = "orders", across = 0.11,  up = 0.425, radius = 0.028 },
    { dial = "section_4", shape = "round", only = "orders", across = 0.20,  up = 0.425, radius = 0.028 },
}

-- Engraved labels (arch units, centered there).
M.LABELS = {
    { text = "FRAMES / S", across = -0.15, up = 0.375, only = "always" },
    { text = "FRAME MS",   across = 0,     up = 0.375, only = "always" },
    { text = "UNITS",      across = 0.15,  up = 0.375, only = "always" },
    { text = "NEXT ORDER GOES TO", across = 0, up = 0.175, only = "orders" },
    { text = "ESCAPE: SETTINGS",   across = 0, up = 0.03,  only = "orders" },
    { text = "MAXIMUM FRAMERATE   (0 = NO CAP)", across = 0, up = 0.665, only = "settings" },
}

local METAL_PIXEL = [[
uniform vec2 arch_base;        // the middle of the arch's base (pixels)
uniform float arch_height;
uniform float arch_half_width;
uniform vec3 base_tone;
uniform vec3 surface_light;    // the metal dial's light on an upward surface
uniform vec3 sheen_color;      // what the far edge reflects (the sky's haze)
uniform float highlight_along; // where along the arch the hour's highlight is (-1..1)
uniform float daylight;        // 0 at night .. 1 at noon

// The console seen across, like a desk (issue 302): brushed along the arch,
// lit by the time of day, a soft sheen toward the far edge, one faint
// highlight sliding along with the hour.
vec4 effect(vec4 color, Image t, vec2 uv, vec2 screen) {
    // which scaled copy of the arch passes through this pixel (f: 0 at the
    // base's middle, 1 on the outer curve) and where along it (s: -1..1)
    float dx = screen.x - arch_base.x;
    float up = arch_base.y - screen.y;
    float f = (up + sqrt(up * up + 4.0 * arch_height * arch_height * dx * dx
               / (arch_half_width * arch_half_width))) / (2.0 * arch_height);
    float s = clamp(dx / max(f * arch_half_width, 1.0), -1.0, 1.0);
    // brushing: fine streaks along the curve, each its own shade, with a
    // slow wander along the arch so no two stretches look stamped
    float line = floor(f * 520.0);
    float streak = fract(sin(line * 12.9898) * 43758.5453);
    float wander = 0.5 + 0.5 * sin(s * 7.0 + line * 0.37);
    float brushed = 0.90 + 0.07 * streak + 0.03 * wander;
    // the far edge, seen at a grazing angle, reflects the sky the most
    float sheen = pow(clamp(up / arch_height, 0.0, 1.0), 3.0) * 0.16;
    // brushed metal throws a light back as a stripe across its streaks
    float highlight = exp(-pow((s - highlight_along) / 0.22, 2.0)) * 0.07 * daylight;
    vec3 tone = base_tone * surface_light * brushed
              + sheen_color * sheen
              + vec3(highlight);
    return vec4(tone * color.rgb, color.a);
}
]]

-- {{{ function M.new()
-- `team_size` (whole, 1..4) and `seat` (whole) decide which allies' arches
-- are beside yours; `height_share` is the arch's height as a share of the
-- window's.

function M.new(width, height, team_size, seat, height_share)
    local arch_height = height * height_share
    -- standing on the bottom pixel row, reaching both sides of the window
    local section = arch.new(width / 2, height, arch_height,
        M.width_share_for(width, height, height_share), M.ARCH_BAND_SHARE)
    local dashboard = {
        width = width,
        height = height,
        section = section,
        team_size = team_size,
        seat = seat,
        home_x = section.center_x,
        chair_offset = 0,
        face = love.graphics.newCanvas(width, height),
        dials = love.graphics.newCanvas(width, height),
        glass = love.graphics.newCanvas(width, height),
        -- the band's map coordinates need finer steps than 8 bits give
        band = love.graphics.newCanvas(width, height, { format = "rgba16f" }),
        metal_shader = love.graphics.newShader(METAL_PIXEL),
        dial_angles = { month = 0, weekday = 0, day = 0 },
        settings_open = false,
        hovered_verb = nil,
        pressed_verb = nil,
        flash_seconds = 0,
    }
    dashboard.fonts = {
        label = love.graphics.newFont(math.max(9, math.floor(arch_height * 0.019))),
        dial = love.graphics.newFont(math.max(10, math.floor(arch_height * 0.026))),
        small = love.graphics.newFont(math.max(9, math.floor(arch_height * 0.022))),
        readout = love.graphics.newFont(math.max(12, math.floor(arch_height * 0.037))),
        big = love.graphics.newFont(math.max(16, math.floor(arch_height * 0.065))),
        seat = love.graphics.newFont(math.max(10, math.floor(arch_height * 0.024))),
        button = love.graphics.newFont(math.max(8, math.floor(arch_height * 0.0145))),
    }
    return dashboard
end
-- }}}

-- {{{ local function shown()
-- Whether something marked `only` is shown in the current mode.
local function shown(dashboard, only)
    -- always shown
    if only == "always" then
        return true
    end
    -- the settings menu's own parts
    if only == "settings" then
        return dashboard.settings_open
    end
    -- the order parts, hidden while the settings menu is open
    return not dashboard.settings_open
end
-- }}}

-- {{{ local function windows_of()
-- The windows shown now, each with its pixel position filled in.
local function windows_of(dashboard)
    local section = dashboard.section
    local H = section.height
    local cx, cy = arch.at(section, M.CALENDAR_CENTER[1], M.CALENDAR_CENTER[2])
    local windows = {}
    for _, layout in ipairs(M.WINDOWS) do
        if shown(dashboard, layout.only) then
            local window = { dial = layout.dial, shape = layout.shape }
            -- an arc slot turns around the calendar center
            if layout.shape == "arc" then
                window.center_x, window.center_y = cx, cy
                window.inner, window.outer = layout.inner * H, layout.outer * H
                window.from, window.to = layout.from, layout.to
            else
                -- a round hole or a slot sits at its own spot
                window.x, window.y = arch.at(section, layout.across, layout.up)
                window.radius = (layout.radius or 0) * H
                window.half_width = (layout.half_width or 0) * H
                window.half_height = (layout.half_height or 0) * H
            end
            windows[#windows + 1] = window
        end
    end
    return windows
end
-- }}}

-- {{{ local function fill_window()
-- Fills a window's shape with the current color (to cut it from the face,
-- or to clip a dial to it).
local function fill_window(window)
    -- a round hole
    if window.shape == "round" then
        love.graphics.circle("fill", window.x, window.y, window.radius, 64)
        return
    end
    -- a rounded slot
    if window.shape == "slot" then
        love.graphics.rectangle("fill", window.x - window.half_width, window.y - window.half_height,
            window.half_width * 2, window.half_height * 2, window.half_height, window.half_height, 16)
        return
    end
    -- an arc slot, as a strip of quads so it stays exact
    local steps = 32
    for step = 0, steps - 1 do
        local a1 = math.rad(window.from + (window.to - window.from) * step / steps)
        local a2 = math.rad(window.from + (window.to - window.from) * (step + 1) / steps)
        local cx, cy = window.center_x, window.center_y
        love.graphics.polygon("fill",
            cx + window.inner * math.cos(a1), cy + window.inner * math.sin(a1),
            cx + window.outer * math.cos(a1), cy + window.outer * math.sin(a1),
            cx + window.outer * math.cos(a2), cy + window.outer * math.sin(a2),
            cx + window.inner * math.cos(a2), cy + window.inner * math.sin(a2))
    end
end
-- }}}

-- {{{ local function outline_window()
-- A dark edge and a bright lip around a window.
local function outline_window(window)
    love.graphics.setColor(0.08, 0.08, 0.09, 0.9)
    love.graphics.setLineWidth(3)
    -- a round hole's bezel is two circles
    if window.shape == "round" then
        love.graphics.circle("line", window.x, window.y, window.radius + 1, 64)
        love.graphics.setColor(0.92, 0.94, 0.97, 0.6)
        love.graphics.setLineWidth(1.5)
        love.graphics.circle("line", window.x, window.y, window.radius + 4, 64)
        return
    end
    -- a slot's bezel follows its rounded rectangle
    if window.shape == "slot" then
        love.graphics.rectangle("line", window.x - window.half_width - 1, window.y - window.half_height - 1,
            window.half_width * 2 + 2, window.half_height * 2 + 2, window.half_height, window.half_height, 16)
        return
    end
    -- an arc slot's bezel is its outline
    local points = {}
    local cx, cy = window.center_x, window.center_y
    for step = 0, 32 do
        local a = math.rad(window.from + (window.to - window.from) * step / 32)
        points[#points + 1] = cx + window.outer * math.cos(a)
        points[#points + 1] = cy + window.outer * math.sin(a)
    end
    for step = 32, 0, -1 do
        local a = math.rad(window.from + (window.to - window.from) * step / 32)
        points[#points + 1] = cx + window.inner * math.cos(a)
        points[#points + 1] = cy + window.inner * math.sin(a)
    end
    love.graphics.polygon("line", points)
end
-- }}}

-- {{{ local function glass_mesh_for()
-- A mesh covering a window whose colors say how its glass bends: red 1;
-- green and blue lean outward toward the rim, neutral across the middle;
-- alpha 1 (a dial lies beneath).
local function glass_mesh_for(window)
    local vertices = {}
    -- a round hole: a fan from a neutral center to a rim leaning outward
    if window.shape == "round" then
        vertices[1] = { window.x, window.y, 0, 0, 1, 0.5, 0.5, 1 }
        for step = 0, 64 do
            local a = 2 * math.pi * step / 64
            vertices[#vertices + 1] = {
                window.x + window.radius * math.cos(a), window.y + window.radius * math.sin(a),
                0, 0, 1, 0.5 + 0.5 * math.cos(a), 0.5 + 0.5 * math.sin(a), 1,
            }
        end
        return love.graphics.newMesh(vertices, "fan", "static")
    end
    -- a slot: its top edge leans up, its bottom edge down, its middle neutral
    if window.shape == "slot" then
        local left, right = window.x - window.half_width, window.x + window.half_width
        local top, middle, bottom = window.y - window.half_height, window.y, window.y + window.half_height
        vertices = {
            { left, top, 0, 0, 1, 0.5, 0, 1 }, { right, top, 0, 0, 1, 0.5, 0, 1 },
            { left, middle, 0, 0, 1, 0.5, 0.5, 1 }, { right, middle, 0, 0, 1, 0.5, 0.5, 1 },
            { left, bottom, 0, 0, 1, 0.5, 1, 1 }, { right, bottom, 0, 0, 1, 0.5, 1, 1 },
        }
        return love.graphics.newMesh(vertices, "strip", "static")
    end
    -- an arc slot: a strip whose inner edge leans inward and outer edge outward
    local cx, cy = window.center_x, window.center_y
    for step = 0, 32 do
        local a = math.rad(window.from + (window.to - window.from) * step / 32)
        local c, s = math.cos(a), math.sin(a)
        vertices[#vertices + 1] = { cx + window.inner * c, cy + window.inner * s, 0, 0,
            1, 0.5 - 0.5 * c, 0.5 - 0.5 * s, 1 }
        vertices[#vertices + 1] = { cx + window.outer * c, cy + window.outer * s, 0, 0,
            1, 0.5 + 0.5 * c, 0.5 + 0.5 * s, 1 }
    end
    return love.graphics.newMesh(vertices, "strip", "static")
end
-- }}}

-- {{{ local function band_glass_mesh()
-- The band's glass: a strip from foot to foot, its inner edge leaning in
-- toward the dashboard and its outer edge leaning out, alpha 0.5 (the painted
-- map lies beneath it, not a dial).
local function band_glass_mesh(section)
    local vertices = {}
    for _, point in ipairs(arch.curve_points(section, 96)) do
        local dx, dy = point[3] - point[1], point[4] - point[2]
        local length = math.sqrt(dx * dx + dy * dy)
        local nx, ny = dx / length, dy / length
        vertices[#vertices + 1] = { point[1], point[2], 0, 0, 1, 0.5 - 0.5 * nx, 0.5 - 0.5 * ny, 0.5 }
        vertices[#vertices + 1] = { point[3], point[4], 0, 0, 1, 0.5 + 0.5 * nx, 0.5 + 0.5 * ny, 0.5 }
    end
    return love.graphics.newMesh(vertices, "strip", "static")
end
-- }}}

-- {{{ local function band_coordinates_mesh()
-- The band as a strip whose colors say where on the map each pixel paints:
-- red runs 0 to 1 from the left foot to the right, green 0 on the inner edge
-- to 1 on the outer, blue is the ally's quadrant (`quadrant`, 0..1).
local function band_coordinates_mesh(section, quadrant)
    local vertices = {}
    local points = arch.curve_points(section, 96)
    for index, point in ipairs(points) do
        local along = (index - 1) / (#points - 1)
        vertices[#vertices + 1] = { point[1], point[2], 0, 0, along, 0, quadrant, 1 }
        vertices[#vertices + 1] = { point[3], point[4], 0, 0, along, 1, quadrant, 1 }
    end
    return love.graphics.newMesh(vertices, "strip", "static")
end
-- }}}

-- {{{ function M.set_chair()
-- Turns the chair: `offset` is how many arches along the row the view has
-- slid (0 = your own arch in front; 1 = the next ally's). Your own arch's
-- place, and so its buttons and dials, move with it.
function M.set_chair(dashboard, offset)
    dashboard.chair_offset = offset
    local spacing = dashboard.section.width - dashboard.section.band
    dashboard.section.center_x = dashboard.home_x - offset * spacing
end
-- }}}

-- {{{ local function visible_arches()
-- Every arch with any part in view: a list of { section, seat, own }.
-- Seats form a ring, so the arch k places along the row from yours is seat
-- (seat + k) wrapped around the team.
local function visible_arches(dashboard)
    local arches = {}
    local own = dashboard.section
    local team = dashboard.team_size
    local nearest = math.floor(dashboard.chair_offset + 0.5)
    for k = nearest - 2, nearest + 2 do
        local seat = (dashboard.seat - 1 + k) % team + 1
        -- alone: the one arch, once
        if team > 1 or k == 0 then
            arches[#arches + 1] = { section = arch.shifted(own, k), seat = seat, own = (k == 0) }
        end
    end
    return arches
end
-- }}}

-- {{{ local function clip()
-- The part of the window the console may show: your own arch's width at the
-- screen's center plus the very edge of the next on each side.
local function clip(dashboard)
    local section = dashboard.section
    local half = section.width / 2 + section.width * M.NEIGHBOUR_SHOWN
    return dashboard.home_x - half, 0, half * 2, dashboard.height
end
-- }}}

-- {{{ local function draw_band_edges()
-- Gold edges along both curves of the band (the band itself stays clear on
-- the face: its glass shows the world).
local function draw_band_edges(section)
    local inner, outer = {}, {}
    for _, point in ipairs(arch.curve_points(section, 96)) do
        inner[#inner + 1] = point[1]
        inner[#inner + 1] = point[2]
        outer[#outer + 1] = point[3]
        outer[#outer + 1] = point[4]
    end
    love.graphics.setLineWidth(3)
    love.graphics.setColor(0.55, 0.40, 0.10, 1)
    love.graphics.line(inner)
    love.graphics.line(outer)
    love.graphics.setLineWidth(1.2)
    love.graphics.setColor(1.0, 0.86, 0.42, 1)
    love.graphics.line(inner)
    love.graphics.line(outer)
end
-- }}}

-- {{{ local function engraved()
-- Text cut into metal: a dark line with a faint light edge below it,
-- centered on x, y.
local function engraved(font, text, x, y)
    love.graphics.setFont(font)
    local width = font:getWidth(text)
    local top = y - font:getHeight() / 2
    love.graphics.setColor(1, 1, 1, 0.18)
    love.graphics.print(text, x - width / 2, top + 1)
    love.graphics.setColor(0.08, 0.09, 0.1, 0.85)
    love.graphics.print(text, x - width / 2, top)
end
-- }}}

-- {{{ local function button_spots()
-- Where every clickable button is right now: a list of
-- { verb, label, paint, x, y, radius, de_selected }.
local function button_spots(dashboard, someone_named)
    local section = dashboard.section
    local spots = {}
    -- the settings menu is open: only its buttons can be pressed
    local list, radius, de_selected = M.ORDER_BUTTONS, M.ORDER_BUTTON_RADIUS, not someone_named
    if dashboard.settings_open then
        list, radius, de_selected = M.SETTINGS_BUTTONS, M.SETTINGS_BUTTON_RADIUS, false
    end
    for _, button in ipairs(list) do
        local x, y = arch.at(section, button.across, button.up)
        local label = button.label
        -- a look toggle: its label is its current choice
        if button.look ~= nil then
            label = M.LOOK_WORDS[button.look][dashboard.look[button.look]]
        end
        spots[#spots + 1] = {
            verb = button.verb, label = label, paint = button.paint,
            x = x, y = y, radius = radius * section.height, de_selected = de_selected,
        }
    end
    return spots
end
-- }}}

-- {{{ function M.button_under()
-- The verb of the button under a pixel, or nil. Dials and the band never answer.
function M.button_under(dashboard, x, y, someone_named)
    local left, _, width = clip(dashboard)
    -- outside the shown part of the console: no button there
    if x < left or x > left + width then
        return nil
    end
    for _, spot in ipairs(button_spots(dashboard, someone_named)) do
        local dx, dy = x - spot.x, y - spot.y
        if dx * dx + dy * dy <= spot.radius * spot.radius then
            return spot.verb
        end
    end
    return nil
end
-- }}}

-- {{{ function M.covers()
-- Whether a pixel lies on your arch (its surface or its band), so a click
-- there is not a map click.
function M.covers(dashboard, x, y)
    local left, _, width = clip(dashboard)
    -- outside the shown part of the console: the map
    if x < left or x > left + width then
        return false
    end
    -- on any shown arch (yours, or an ally's slid into view)
    for _, shown_arch in ipairs(visible_arches(dashboard)) do
        if arch.in_interior(shown_arch.section, x, y) or arch.in_band(shown_arch.section, x, y) then
            return true
        end
    end
    return false
end
-- }}}

-- {{{ local function turn_dial()
-- Turns a dial toward its target angle with weight: quickly when far, then
-- settling, never jumping. Angles in degrees.
local function turn_dial(dashboard, name, target, seconds)
    local current = dashboard.dial_angles[name]
    -- go the short way round
    local difference = (target - current + 540) % 360 - 180
    dashboard.dial_angles[name] = current + difference * (1 - math.exp(-seconds * 6))
end
-- }}}

-- {{{ local function draw_ring_dial()
-- A paper ring around (cx, cy) inscribed with words spaced evenly around it,
-- turned by `angle`; words read upright at the top.
local function draw_ring_dial(dashboard, words, cx, cy, angle, radius)
    local spacing = 360 / #words
    local font = dashboard.fonts.dial
    love.graphics.setFont(font)
    love.graphics.setColor(0.12, 0.12, 0.14, 1)
    for index, word in ipairs(words) do
        local a = math.rad(angle + (index - 1) * spacing)
        love.graphics.print(word, cx + radius * math.cos(a), cy + radius * math.sin(a),
            a + math.pi / 2, 1, 1, font:getWidth(word) / 2, font:getHeight() / 2)
    end
end
-- }}}

-- {{{ local function window_named()
local function window_named(dashboard, dial)
    for _, window in ipairs(windows_of(dashboard)) do
        if window.dial == dial then
            return window
        end
    end
    return nil
end
-- }}}

-- {{{ local function under_window()
-- Draws `draw_contents` clipped to one window's shape: each dial is its own
-- disc at its own level, so one disc's inscriptions never show through
-- another disc's window. A window not shown now draws nothing.
local function under_window(dashboard, dial, draw_contents)
    local window = window_named(dashboard, dial)
    -- the window is hidden in this mode
    if window == nil then
        return
    end
    love.graphics.stencil(function()
        fill_window(window)
    end, "replace", 1)
    love.graphics.setStencilTest("greater", 0)
    draw_contents(window)
    love.graphics.setStencilTest()
end
-- }}}

-- {{{ local function draw_dials()
-- The layer beneath the windows. `state` carries the values to show.
local function draw_dials(dashboard, state, seconds)
    local section = dashboard.section
    local H = section.height
    local cx, cy = arch.at(section, M.CALENDAR_CENTER[1], M.CALENDAR_CENTER[2])
    love.graphics.setCanvas({ dashboard.dials, stencil = true })
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setScissor(clip(dashboard))

    -- months: a cream paper ring, its month's word turned to the top window
    turn_dial(dashboard, "month", -90 - (state.month - 1) * 30, seconds)
    under_window(dashboard, "month", function()
        love.graphics.setColor(0.86, 0.83, 0.76, 1)
        love.graphics.circle("fill", cx, cy, 0.6 * H, 256)
        draw_ring_dial(dashboard, M.MONTHS, cx, cy, dashboard.dial_angles.month, 0.495 * H)
    end)

    -- weekdays: a second ring at its own level, one window lower
    turn_dial(dashboard, "weekday", -90 - (state.weekday - 1) * (360 / 7), seconds)
    under_window(dashboard, "weekday", function()
        love.graphics.setColor(0.80, 0.77, 0.70, 1)
        love.graphics.circle("fill", cx, cy, 0.6 * H, 256)
        draw_ring_dial(dashboard, M.WEEKDAYS, cx, cy, dashboard.dial_angles.weekday, 0.395 * H)
    end)

    -- the day number: one level lower again, on a darker disc whose rim passes
    -- under the round hole; the disc turns so today's number is there
    turn_dial(dashboard, "day", 90 - (state.day - 1) * (360 / 31), seconds)
    under_window(dashboard, "day", function(window)
        local disc_x, disc_y = window.x, window.y - 0.16 * H
        local font = dashboard.fonts.dial
        love.graphics.setColor(0.66, 0.63, 0.57, 1)
        love.graphics.circle("fill", disc_x, disc_y, 0.2 * H, 96)
        love.graphics.setFont(font)
        love.graphics.setColor(0.1, 0.1, 0.12, 1)
        for number = 1, 31 do
            local a = math.rad(dashboard.dial_angles.day + (number - 1) * (360 / 31))
            local text = tostring(number)
            love.graphics.print(text, disc_x + 0.16 * H * math.cos(a), disc_y + 0.16 * H * math.sin(a),
                a - math.pi / 2, 1, 1, font:getWidth(text) / 2, font:getHeight() / 2)
        end
    end)

    -- the readout dials: paper discs with a number on each
    local readouts = {
        { dial = "fps", text = string.format("%d", state.fps) },
        { dial = "frame_ms", text = string.format("%.1f", state.frame_ms) },
        { dial = "units", text = string.format("%d", state.unit_count) },
        { dial = "cap", text = tostring(state.cap), big = true },
    }
    -- each section's count, inked in its color
    for index = 1, 4 do
        readouts[#readouts + 1] = { dial = "section_" .. index, text = tostring(state.delivered[index]),
            small = true, ink = state.seat_colors[index] }
    end
    for _, readout in ipairs(readouts) do
        under_window(dashboard, readout.dial, function(window)
            local font = readout.big and dashboard.fonts.big
                or (readout.small and dashboard.fonts.small or dashboard.fonts.readout)
            local ink = readout.ink or { 0.1, 0.1, 0.12 }
            love.graphics.setColor(0.9, 0.88, 0.82, 1)
            love.graphics.circle("fill", window.x, window.y, window.radius, 64)
            love.graphics.setColor(ink[1] * 0.8, ink[2] * 0.8, ink[3] * 0.8, 1)
            love.graphics.setFont(font)
            love.graphics.printf(readout.text, window.x - window.radius, window.y - font:getHeight() / 2,
                window.radius * 2, "center")
        end)
    end

    -- the named stand's slot: who the next order goes to, or a reminder
    local named_text = state.named_text
    -- a button was pressed with no one named: the reminder flashes
    if dashboard.flash_seconds > 0 then
        named_text = "NAME SOMEONE FIRST"
        dashboard.flash_seconds = dashboard.flash_seconds - seconds
    end
    under_window(dashboard, "named", function(window)
        local font = dashboard.fonts.small
        love.graphics.setColor(0.86, 0.83, 0.76, 1)
        love.graphics.rectangle("fill", window.x - window.half_width, window.y - window.half_height,
            window.half_width * 2, window.half_height * 2)
        love.graphics.setColor(0.12, 0.12, 0.14, 1)
        love.graphics.setFont(font)
        love.graphics.printf(named_text, window.x - window.half_width, window.y - font:getHeight() / 2,
            window.half_width * 2, "center")
    end)
end
-- }}}

-- The metal's own tone before light (graphite steel), and how strongly the
-- dial's light shows on it. Tuning knobs: record changes in
-- docs/balance-updates.md.
M.METAL_TONE = { 0.50, 0.52, 0.55 }
M.METAL_LIGHT_GAIN = 1.25
-- The console's own panel lamp, which the day's light adds to: without it
-- the engraved labels could not be read at night (picture 022).
M.PANEL_LAMP = { 0.46, 0.48, 0.55 }

-- {{{ local function draw_surface()
-- One arch's metal surface (and its band cut away), brightness `tone`.
local function draw_surface(dashboard, section, tone)
    love.graphics.setShader(dashboard.metal_shader)
    local light = dashboard.surface_light
    dashboard.metal_shader:send("arch_base", { section.center_x, section.base_y })
    dashboard.metal_shader:send("arch_height", section.height)
    dashboard.metal_shader:send("arch_half_width", section.width / 2)
    dashboard.metal_shader:send("base_tone", M.METAL_TONE)
    dashboard.metal_shader:send("surface_light", { light[1], light[2], light[3] })
    dashboard.metal_shader:send("sheen_color", light.sheen)
    dashboard.metal_shader:send("highlight_along", light.highlight_along)
    dashboard.metal_shader:send("daylight", light.daylight)
    love.graphics.setColor(tone, tone, tone, 1)
    love.graphics.polygon("fill", arch.interior_polygon(section, 96))
    love.graphics.setShader()
    draw_band_edges(section)
end
-- }}}

-- {{{ local function draw_allies()
-- The allies' arches: dimmer, each labelled with its seat in its color.
-- Their buttons and dials are theirs; yours shows only their surface, their
-- band, and who they are.
local function draw_allies(dashboard, seat_colors)
    for _, shown_arch in ipairs(visible_arches(dashboard)) do
        if not shown_arch.own then
            draw_surface(dashboard, shown_arch.section, 0.55)
            local color = seat_colors[shown_arch.seat]
            local x, y = arch.at(shown_arch.section, 0, 0.30)
            local label = "SEAT " .. shown_arch.seat
            love.graphics.setFont(dashboard.fonts.big)
            love.graphics.setColor(color[1], color[2], color[3], 0.85)
            love.graphics.print(label, x - dashboard.fonts.big:getWidth(label) / 2, y)
        end
    end
end
-- }}}

-- {{{ local function draw_face()
local function draw_face(dashboard, state)
    local section = dashboard.section
    love.graphics.setCanvas(dashboard.face)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setScissor(clip(dashboard))

    draw_allies(dashboard, state.seat_colors)
    draw_surface(dashboard, section, 1)

    -- cut every window out of the metal: replace with nothing at all
    love.graphics.setBlendMode("replace")
    love.graphics.setColor(0, 0, 0, 0)
    for _, window in ipairs(windows_of(dashboard)) do
        fill_window(window)
    end
    love.graphics.setBlendMode("alpha")
    for _, window in ipairs(windows_of(dashboard)) do
        outline_window(window)
    end

    -- engraved labels
    for _, label in ipairs(M.LABELS) do
        if shown(dashboard, label.only) then
            local x, y = arch.at(section, label.across, label.up)
            engraved(dashboard.fonts.label, label.text, x, y)
        end
    end

    -- painted buttons, each in a metal bezel
    local label_font = dashboard.fonts.button
    for _, spot in ipairs(button_spots(dashboard, state.someone_named)) do
        local paint = spot.paint
        local strength = 1
        -- de-selected: still painted, but dimmer
        if spot.de_selected then
            strength = 0.55
        end
        local pressed = dashboard.pressed_verb == spot.verb
        -- pressed: the paint sinks and darkens
        if pressed then
            strength = strength * 0.7
        end
        love.graphics.setColor(0.16, 0.17, 0.18, 1)
        love.graphics.circle("fill", spot.x, spot.y, spot.radius * 1.12, 48)
        love.graphics.setColor(paint[1] * strength, paint[2] * strength, paint[3] * strength, 1)
        love.graphics.circle("fill", spot.x, spot.y + (pressed and 1.5 or 0), spot.radius, 48)
        -- hovered: the rim brightens
        if dashboard.hovered_verb == spot.verb then
            love.graphics.setColor(1, 1, 1, 0.75)
            love.graphics.setLineWidth(2)
            love.graphics.circle("line", spot.x, spot.y, spot.radius, 48)
        end
        -- a curved shine across the top of the paint
        love.graphics.setColor(1, 1, 1, 0.22 * strength)
        love.graphics.arc("fill", spot.x, spot.y - spot.radius * 0.1, spot.radius * 0.8,
            math.pi * 1.1, math.pi * 1.9, 24)
        love.graphics.setFont(label_font)
        love.graphics.setColor(0.05, 0.05, 0.06, 0.95)
        love.graphics.printf(spot.label, spot.x - spot.radius, spot.y - label_font:getHeight() / 2,
            spot.radius * 2, "center")
    end
    love.graphics.setLineWidth(1)
    love.graphics.setScissor()
end
-- }}}

-- {{{ local function draw_glass()
-- The glass and band layers change only when the windows or the chair do,
-- so they are redrawn only then.
local function draw_glass(dashboard)
    local key = tostring(dashboard.settings_open) .. string.format(":%.4f", dashboard.chair_offset)
    -- the windows and the chair are as they were last drawn: nothing to do
    if dashboard.glass_drawn_for == key then
        return
    end
    dashboard.glass_drawn_for = key
    local arches = visible_arches(dashboard)

    love.graphics.setScissor(clip(dashboard))
    love.graphics.setCanvas(dashboard.glass)
    love.graphics.clear(0, 0.5, 0.5, 0)
    -- "premultiplied": write the colors exactly as given. The default would
    -- multiply them by their alpha, and the band's alpha of 0.5 halved its
    -- "glass here" mark below the shader's threshold, so the band was never
    -- painted.
    love.graphics.setBlendMode("replace", "premultiplied")
    love.graphics.setColor(1, 1, 1, 1)
    local meshes = {}
    for _, shown_arch in ipairs(arches) do
        meshes[#meshes + 1] = band_glass_mesh(shown_arch.section)
    end
    for _, window in ipairs(windows_of(dashboard)) do
        meshes[#meshes + 1] = glass_mesh_for(window)
    end
    for _, mesh in ipairs(meshes) do
        love.graphics.draw(mesh)
        mesh:release()
    end

    -- where each band pixel paints on the map
    love.graphics.setCanvas(dashboard.band)
    love.graphics.clear(0, 0, 0, 0)
    for _, shown_arch in ipairs(arches) do
        local mesh = band_coordinates_mesh(shown_arch.section, (shown_arch.seat - 1) / dashboard.team_size)
        love.graphics.draw(mesh)
        mesh:release()
    end
    love.graphics.setBlendMode("alpha")
    love.graphics.setScissor()
end
-- }}}

-- {{{ function M.draw()
-- Draws all three layers. `state` (plain values): month (1..12),
-- weekday (1..7), day (1..31), fps (whole), frame_ms (number), unit_count,
-- cap (whole), named_text (string), someone_named (boolean),
-- seat_colors (list of {r, g, b}), delivered (four whole numbers: cuboids
-- resting in each section), surface_light (the metal's light this hour:
-- r, g, b at 1..3 and sheen {r, g, b}, highlight_along (-1..1), daylight
-- (0..1)). `seconds` is the frame's time.
function M.draw(dashboard, state, seconds)
    dashboard.look = state.look
    dashboard.surface_light = state.surface_light
    love.graphics.push("all")
    love.graphics.setDepthMode("always", false)
    draw_dials(dashboard, state, seconds)
    draw_face(dashboard, state)
    draw_glass(dashboard)
    love.graphics.pop()
end
-- }}}

-- {{{ function M.set_pointer()
-- Tells the dashboard where the mouse is and whether it is held, so buttons
-- can light up. Dials take no notice.
function M.set_pointer(dashboard, x, y, held, someone_named)
    local verb = M.button_under(dashboard, x, y, someone_named)
    dashboard.hovered_verb = verb
    -- held over a button: that button shows pressed
    if held then
        dashboard.pressed_verb = verb
    else
        dashboard.pressed_verb = nil
    end
end
-- }}}

-- {{{ function M.flash_name_someone()
function M.flash_name_someone(dashboard)
    dashboard.flash_seconds = 1.2
end
-- }}}

return M
