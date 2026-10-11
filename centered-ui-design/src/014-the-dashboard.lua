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

-- The layout below is for a wide, low arch (a fifth of the window high,
-- the window wide: about eight times wider than tall), laid out in rows
-- across: the calendar in the middle, readouts to its left, section counts
-- to its right, four order buttons at each end, the named slot beneath the
-- calendar (issue 302: "40% as much dashboard"). Arch units are shares of
-- the arch's height, so at a fifth of a 1000-pixel window one unit is 200
-- pixels; sizes here were chosen to keep the pixel sizes of the earlier,
-- taller console. The tests check every piece lies on the surface and no
-- two shown together overlap.

-- The center the calendar rings turn around (arch units).
M.CALENDAR_CENTER = { 0, 0.0 }

-- The order buttons: verb, label, paint, and where they sit (arch units):
-- a row of four at each end of the arch.
M.ORDER_BUTTONS = {
    { verb = "advance",     label = "ADVANCE",   paint = { 0.20, 0.85, 0.35 }, across = -2.60, up = 0.16 },
    { verb = "attack",      label = "ATTACK",    paint = { 0.95, 0.20, 0.18 }, across = -2.35, up = 0.16 },
    { verb = "hold",        label = "HOLD",      paint = { 1.00, 0.72, 0.10 }, across = -2.10, up = 0.16 },
    { verb = "fall_back",   label = "FALL BACK", paint = { 0.20, 0.45, 1.00 }, across = -1.85, up = 0.16 },
    { verb = "flank_left",  label = "FLANK L",   paint = { 0.10, 0.85, 0.90 }, across = 1.85,  up = 0.16 },
    { verb = "flank_right", label = "FLANK R",   paint = { 0.65, 0.35, 1.00 }, across = 2.10,  up = 0.16 },
    { verb = "shield",      label = "SHIELD",    paint = { 0.15, 0.80, 0.65 }, across = 2.35,  up = 0.16 },
    { verb = "build",       label = "BUILD",     paint = { 1.00, 0.45, 0.10 }, across = 2.60,  up = 0.16 },
}
M.ORDER_BUTTON_RADIUS = 0.10

-- The settings menu's buttons (arch units).
M.SETTINGS_BUTTONS = {
    { verb = "cap_minus_10",   label = "-10",  paint = { 0.20, 0.45, 1.00 }, across = -0.60, up = 0.55 },
    { verb = "cap_plus_10",    label = "+10",  paint = { 1.00, 0.45, 0.10 }, across = 0.60,  up = 0.55 },
    { verb = "cap_minus_1",    label = "-1",   paint = { 0.10, 0.85, 0.90 }, across = -0.35, up = 0.55 },
    { verb = "cap_plus_1",     label = "+1",   paint = { 1.00, 0.72, 0.10 }, across = 0.35,  up = 0.55 },
    { verb = "close_settings", label = "BACK", paint = { 0.20, 0.85, 0.35 }, across = -1.80, up = 0.20 },
    { verb = "quit",           label = "QUIT", paint = { 0.95, 0.20, 0.18 }, across = 1.80,  up = 0.20 },
    -- the look toggles (issue 214): each shows its current choice
    { verb = "toggle_depth",    look = "depth",    paint = { 0.65, 0.35, 1.00 }, across = -0.40, up = 0.20 },
    { verb = "toggle_standing", look = "standing", paint = { 0.15, 0.80, 0.65 }, across = 0,     up = 0.20 },
    { verb = "toggle_blur",     look = "blur",     paint = { 0.10, 0.85, 0.90 }, across = 0.40,  up = 0.20 },
}

-- What a look toggle's button says for each choice.
M.LOOK_WORDS = {
    depth = { flat = "FLAT VIEW", hub = "HUB VIEW", slant = "SLANT VIEW", arch = "ARCH VIEW" },
    standing = { upright = "UPRIGHT", outward = "OUTWARD" },
    blur = { on = "BLUR ON", off = "BLUR OFF" },
}
M.SETTINGS_BUTTON_RADIUS = 0.105

-- Every window, in arch units. `only` says when it is shown: "always",
-- "orders" (settings shut) or "settings" (settings open).
--   arc:   around the calendar center, between two radii and two angles
--          (degrees, screen convention: -90 is straight up)
--   round: a circular hole
--   slot:  a rounded rectangle
M.WINDOWS = {
    { dial = "month",    shape = "arc",   only = "orders", inner = 0.68, outer = 0.82, from = -110, to = -70 },
    { dial = "weekday",  shape = "arc",   only = "orders", inner = 0.50, outer = 0.64, from = -114, to = -66 },
    { dial = "day",      shape = "round", only = "orders", across = 0, up = 0.40, radius = 0.085 },
    { dial = "fps",      shape = "round", only = "always", across = -1.35, up = 0.42, radius = 0.1375 },
    { dial = "frame_ms", shape = "round", only = "always", across = -0.95, up = 0.42, radius = 0.1375 },
    { dial = "units",    shape = "round", only = "always", across = 0.95,  up = 0.42, radius = 0.1375 },
    { dial = "named",    shape = "slot",  only = "orders", across = 0, up = 0.13, half_width = 0.425, half_height = 0.0875 },
    { dial = "cap",      shape = "round", only = "settings", across = 0, up = 0.55, radius = 0.1875 },
    -- the view dials (issue 214): turned by the wheel with A or S held
    { dial = "view_reach", shape = "round", only = "always", across = -1.70, up = 0.42, radius = 0.085 },
    { dial = "view_span",  shape = "round", only = "always", across = -2.15, up = 0.42, radius = 0.085 },
    -- how many cuboids rest in each color's section (ink in that color)
    { dial = "section_1", shape = "round", only = "orders", across = 1.30, up = 0.42, radius = 0.07 },
    { dial = "section_2", shape = "round", only = "orders", across = 1.50, up = 0.42, radius = 0.07 },
    { dial = "section_3", shape = "round", only = "orders", across = 1.70, up = 0.42, radius = 0.07 },
    { dial = "section_4", shape = "round", only = "orders", across = 1.90, up = 0.42, radius = 0.07 },
}

-- Engraved labels (arch units, centered there).
M.LABELS = {
    { text = "FRAMES / S", across = -1.35, up = 0.235, only = "always" },
    { text = "FRAME MS",   across = -0.95, up = 0.235, only = "always" },
    { text = "UNITS",      across = 0.95,  up = 0.235, only = "always" },
    { text = "A: DISTANCE", across = -1.70, up = 0.54, only = "always" },
    { text = "S: FIELD",    across = -2.15, up = 0.54, only = "always" },
    { text = "NEXT ORDER GOES TO", across = 0, up = 0.265, only = "orders" },
    { text = "ESCAPE: SETTINGS",   across = 1.15, up = 0.08, only = "orders" },
    { text = "MAXIMUM FRAMERATE   (0 = NO CAP)", across = 0, up = 0.80, only = "settings" },
}

-- Lettering is sized by the window, not the arch, so it stays readable
-- however low the arch is: this share of the window's height plays the
-- part the arch's height used to.
M.LETTERING_SHARE = 0.5

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
    local lettering = height * M.LETTERING_SHARE
    dashboard.fonts = {
        label = love.graphics.newFont(math.max(9, math.floor(lettering * 0.019))),
        dial = love.graphics.newFont(math.max(10, math.floor(lettering * 0.026))),
        small = love.graphics.newFont(math.max(9, math.floor(lettering * 0.022))),
        readout = love.graphics.newFont(math.max(12, math.floor(lettering * 0.037))),
        big = love.graphics.newFont(math.max(16, math.floor(lettering * 0.065))),
        seat = love.graphics.newFont(math.max(10, math.floor(lettering * 0.024))),
        button = love.graphics.newFont(math.max(8, math.floor(lettering * 0.0145))),
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

-- {{{ function M.arch_spacing()
-- How far apart (pixels) the row's arches stand: one seat's turn of the
-- chair slides the row this far.
function M.arch_spacing(dashboard)
    return dashboard.section.width - dashboard.section.band
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

-- {{{ local function window_layout()
-- A window's layout entry (arch units) by its dial's name; a name with no
-- window is a mistake in this file.
local function window_layout(name)
    for _, window in ipairs(M.WINDOWS) do
        if window.dial == name then
            return window
        end
    end
    error("dashboard: no window for the dial '" .. name .. "'", 2)
end
-- }}}

-- {{{ local function draw_dials()
-- The layer beneath one arch's windows (the arch in dashboard.section),
-- onto the dials canvas already set. `state` carries the values to show;
-- `seconds` turns the dials (0 for every arch after the first, so they
-- turn once a frame).
local function draw_dials(dashboard, state, seconds)
    local section = dashboard.section
    local H = section.height
    local cx, cy = arch.at(section, M.CALENDAR_CENTER[1], M.CALENDAR_CENTER[2])

    -- months: a cream paper ring, its month's word turned to the top window
    turn_dial(dashboard, "month", -90 - (state.month - 1) * 30, seconds)
    under_window(dashboard, "month", function()
        love.graphics.setColor(0.86, 0.83, 0.76, 1)
        local month = window_layout("month")
        love.graphics.circle("fill", cx, cy, (month.outer + 0.08) * H, 256)
        draw_ring_dial(dashboard, M.MONTHS, cx, cy, dashboard.dial_angles.month,
            (month.inner + month.outer) / 2 * H)
    end)

    -- weekdays: a second ring at its own level, one window lower
    turn_dial(dashboard, "weekday", -90 - (state.weekday - 1) * (360 / 7), seconds)
    under_window(dashboard, "weekday", function()
        love.graphics.setColor(0.80, 0.77, 0.70, 1)
        local weekday = window_layout("weekday")
        love.graphics.circle("fill", cx, cy, (weekday.outer + 0.08) * H, 256)
        draw_ring_dial(dashboard, M.WEEKDAYS, cx, cy, dashboard.dial_angles.weekday,
            (weekday.inner + weekday.outer) / 2 * H)
    end)

    -- the day number: one level lower again, on a darker disc whose rim passes
    -- under the round hole; the disc turns so today's number is there
    turn_dial(dashboard, "day", 90 - (state.day - 1) * (360 / 31), seconds)
    under_window(dashboard, "day", function(window)
        -- the numbers' ring and the disc, in proportion to the hole (a ring
        -- 4.6 holes out, a disc 5.7), so they follow the hole's size
        local ring = window.radius * 4.6
        local disc_x, disc_y = window.x, window.y - ring
        local font = dashboard.fonts.dial
        love.graphics.setColor(0.66, 0.63, 0.57, 1)
        love.graphics.circle("fill", disc_x, disc_y, window.radius * 5.7, 96)
        love.graphics.setFont(font)
        love.graphics.setColor(0.1, 0.1, 0.12, 1)
        for number = 1, 31 do
            local a = math.rad(dashboard.dial_angles.day + (number - 1) * (360 / 31))
            local text = tostring(number)
            love.graphics.print(text, disc_x + ring * math.cos(a), disc_y + ring * math.sin(a),
                a - math.pi / 2, 1, 1, font:getWidth(text) / 2, font:getHeight() / 2)
        end
    end)

    -- the readout dials: paper discs with a number on each
    local readouts = {
        { dial = "fps", text = string.format("%d", state.fps) },
        { dial = "frame_ms", text = string.format("%.1f", state.frame_ms) },
        { dial = "units", text = string.format("%d", state.unit_count) },
        { dial = "cap", text = tostring(state.cap), big = true },
        -- the reach in map-edges: 1.0 puts the map's edge on the top row
        { dial = "view_reach", text = string.format("%.1f", state.view_reach_edges), small = true },
        { dial = "view_span", text = string.format("%d", state.view_span_degrees + 0.5), small = true },
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
    -- a button was pressed with no one named: the reminder flashes (on your
    -- own arch only)
    if state.own and dashboard.flash_seconds > 0 then
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

-- {{{ local function draw_face()
-- One arch's face (the arch in dashboard.section) onto the face canvas
-- already set: metal, windows cut out, labels, painted buttons. Every arch
-- is drawn the same way — "the arc that it has now is the exact same arc
-- that it should have when the other player's orbit past" — and only your
-- own arch's buttons light when hovered or pressed.
local function draw_face(dashboard, state)
    local section = dashboard.section
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
        local pressed = state.own and dashboard.pressed_verb == spot.verb
        -- pressed: the paint sinks and darkens
        if pressed then
            strength = strength * 0.7
        end
        love.graphics.setColor(0.16, 0.17, 0.18, 1)
        love.graphics.circle("fill", spot.x, spot.y, spot.radius * 1.12, 48)
        love.graphics.setColor(paint[1] * strength, paint[2] * strength, paint[3] * strength, 1)
        love.graphics.circle("fill", spot.x, spot.y + (pressed and 1.5 or 0), spot.radius, 48)
        -- hovered: the rim brightens
        if state.own and dashboard.hovered_verb == spot.verb then
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
    local own = dashboard.section
    for _, shown_arch in ipairs(arches) do
        dashboard.section = shown_arch.section
        for _, window in ipairs(windows_of(dashboard)) do
            meshes[#meshes + 1] = glass_mesh_for(window)
        end
    end
    dashboard.section = own
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
    -- every arch in view, each drawn as an arch of its own seat: yours with
    -- the game's state, an ally's naming its seat in the named slot
    local own = dashboard.section
    local arches = visible_arches(dashboard)
    local function state_for(shown_arch)
        local arch_state = setmetatable({ own = shown_arch.own }, { __index = state })
        -- an ally's arch: its slot names whose seat it is
        if not shown_arch.own then
            arch_state.named_text = "SEAT " .. shown_arch.seat
            arch_state.someone_named = true
        end
        return arch_state
    end
    love.graphics.setCanvas({ dashboard.dials, stencil = true })
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setScissor(clip(dashboard))
    for index, shown_arch in ipairs(arches) do
        dashboard.section = shown_arch.section
        draw_dials(dashboard, state_for(shown_arch), index == 1 and seconds or 0)
    end
    love.graphics.setCanvas(dashboard.face)
    love.graphics.clear(0, 0, 0, 0)
    for _, shown_arch in ipairs(arches) do
        dashboard.section = shown_arch.section
        draw_face(dashboard, state_for(shown_arch))
    end
    love.graphics.setScissor()
    dashboard.section = own
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
