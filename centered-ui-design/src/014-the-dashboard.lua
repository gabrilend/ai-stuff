-- 014-the-dashboard.lua - the glass-and-metal dashboard, drawn as three layers.
--
-- In plain terms: the dashboard over the hub is drawn into three pictures the
-- size of the window, which the view plane (015) later lays over the world:
--
--   face   the brushed-metal body, with windows cut out of it, painted
--          buttons, bezels and engraved labels
--   dials  what lies beneath the windows: paper-thin discs with words and
--          numbers inscribed on them, turned by the game to show a value
--   glass  for each window, how strongly and which way its glass bends what
--          is beneath it (red = glass here; green and blue = the direction of
--          the bend, 0.5 meaning none)
--
-- The player clicks only painted buttons. Dials are information: they ignore
-- the mouse completely. The settings menu (Escape) is a panel of painted
-- buttons around one dial showing the framerate cap.
--
-- This is viewing code. Clicks on buttons are reported back to the game as
-- verbs; the game decides what they mean.

local M = {}

M.MONTHS = { "JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE", "JULY",
    "AUGUST", "SEPTEMBER", "OCTOBER", "NOVEMBER", "DECEMBER" }
M.MONTH_DAYS = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
M.WEEKDAYS = { "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY", "SUNDAY" }

-- The order buttons: verb, label, paint, and where they sit on the face (an
-- angle in degrees, LÖVE's convention: 0 = right, 90 = down).
M.ORDER_BUTTONS = {
    { verb = "advance",   label = "ADVANCE",  paint = { 0.20, 0.85, 0.35 }, at = 140 },
    { verb = "attack",    label = "ATTACK",   paint = { 0.95, 0.20, 0.18 }, at = 167 },
    { verb = "hold",      label = "HOLD",     paint = { 1.00, 0.72, 0.10 }, at = 194 },
    { verb = "fall_back", label = "FALL BACK", paint = { 0.20, 0.45, 1.00 }, at = 221 },
    { verb = "flank_left", label = "FLANK L", paint = { 0.10, 0.85, 0.90 }, at = -41 },
    { verb = "flank_right", label = "FLANK R", paint = { 0.65, 0.35, 1.00 }, at = -14 },
    { verb = "shield",    label = "SHIELD",   paint = { 0.15, 0.80, 0.65 }, at = 13 },
    { verb = "build",     label = "BUILD",    paint = { 1.00, 0.45, 0.10 }, at = 40 },
}

-- The settings menu's buttons: what each does to the framerate cap, and
-- where it sits (offset from the dashboard's center, in dashboard radii).
M.SETTINGS_BUTTONS = {
    { verb = "cap_minus_10", label = "-10", paint = { 0.20, 0.45, 1.00 }, dx = -0.42, dy = 0.11 },
    { verb = "cap_minus_1",  label = "-1",  paint = { 0.10, 0.85, 0.90 }, dx = -0.24, dy = 0.30 },
    { verb = "cap_plus_1",   label = "+1",  paint = { 1.00, 0.72, 0.10 }, dx = 0.24,  dy = 0.30 },
    { verb = "cap_plus_10",  label = "+10", paint = { 1.00, 0.45, 0.10 }, dx = 0.42,  dy = 0.11 },
    { verb = "close_settings", label = "BACK", paint = { 0.20, 0.85, 0.35 }, dx = -0.13, dy = 0.50 },
    { verb = "quit",         label = "QUIT", paint = { 0.95, 0.20, 0.18 }, dx = 0.13,  dy = 0.50 },
}

local METAL_PIXEL = [[
uniform vec2 face_center;
uniform float face_radius;
uniform vec3 base_tone;

// Circular brushing: fine concentric streaks (their brightness depends only
// on distance from the center), and two broad highlights on opposite sides,
// the way light catches a brushed watch dial.
vec4 effect(vec4 color, Image t, vec2 uv, vec2 screen) {
    vec2 d = screen - face_center;
    float reach = length(d) / face_radius;
    float a = atan(d.y, d.x);
    float streak = fract(sin(floor(reach * 420.0) * 12.9898) * 43758.5453);
    float glint = pow(max(cos(a + 2.3), 0.0), 5.0) * 0.22
                + pow(max(cos(a - 0.85), 0.0), 5.0) * 0.12;
    vec3 tone = base_tone * (0.88 + 0.12 * streak) + glint;
    return vec4(tone, color.a);
}
]]

-- {{{ function M.new()
function M.new(width, height, radius_fraction)
    local dashboard = {
        width = width,
        height = height,
        center_x = width / 2,
        center_y = height / 2,
        radius = height * radius_fraction,
        face = love.graphics.newCanvas(width, height),
        dials = love.graphics.newCanvas(width, height),
        glass = love.graphics.newCanvas(width, height),
        metal_shader = love.graphics.newShader(METAL_PIXEL),
        dial_angles = { month = 0, weekday = 0, day = 0 },
        settings_open = false,
        hovered_verb = nil,
        pressed_verb = nil,
        flash_seconds = 0,
    }
    local radius = dashboard.radius
    dashboard.fonts = {
        label = love.graphics.newFont(math.max(9, math.floor(radius * 0.034))),
        dial = love.graphics.newFont(math.max(10, math.floor(radius * 0.05))),
        small = love.graphics.newFont(math.max(9, math.floor(radius * 0.036))),
        readout = love.graphics.newFont(math.max(12, math.floor(radius * 0.07))),
        big = love.graphics.newFont(math.max(16, math.floor(radius * 0.13))),
    }
    return dashboard
end
-- }}}

-- {{{ local function windows_of()
-- Every window cut into the face, as plain shapes in window pixels. A
-- window is either an arc slot (between two angles and two radii, around the
-- dashboard's center) or a round hole. `dial` names what lies beneath.
local function windows_of(dashboard)
    local cx, cy, R = dashboard.center_x, dashboard.center_y, dashboard.radius
    local windows = {
        { shape = "arc", dial = "month", from = -112, to = -68, inner = R * 0.80, outer = R * 0.92 },
        { shape = "arc", dial = "weekday", from = 68, to = 112, inner = R * 0.80, outer = R * 0.92 },
        { shape = "round", dial = "day", x = cx, y = cy + R * 0.69, radius = R * 0.066 },
        { shape = "round", dial = "fps", x = cx - R * 0.24, y = cy - R * 0.30, radius = R * 0.105 },
        { shape = "round", dial = "frame_ms", x = cx, y = cy - R * 0.40, radius = R * 0.105 },
        { shape = "round", dial = "units", x = cx + R * 0.24, y = cy - R * 0.30, radius = R * 0.105 },
    }
    -- the settings menu shows one large round window for the cap, in place
    -- of the named stand's window (orders cannot be given while it is open)
    if dashboard.settings_open then
        windows[#windows + 1] = { shape = "round", dial = "cap", x = cx, y = cy + R * 0.06, radius = R * 0.17 }
    else
        windows[#windows + 1] = { shape = "arc", dial = "named", from = 48, to = 132, inner = R * 0.30, outer = R * 0.42 }
    end
    return windows
end
-- }}}

-- {{{ local function arc_outline()
-- The outline of an arc slot as a flat list of x, y pairs (for polygons).
local function arc_outline(cx, cy, window, steps)
    local points = {}
    for step = 0, steps do
        local a = math.rad(window.from + (window.to - window.from) * step / steps)
        points[#points + 1] = cx + window.outer * math.cos(a)
        points[#points + 1] = cy + window.outer * math.sin(a)
    end
    for step = steps, 0, -1 do
        local a = math.rad(window.from + (window.to - window.from) * step / steps)
        points[#points + 1] = cx + window.inner * math.cos(a)
        points[#points + 1] = cy + window.inner * math.sin(a)
    end
    return points
end
-- }}}

-- {{{ local function fill_window()
-- Fills a window's shape with the current color (used to cut it from the
-- face). Arc slots are drawn as a strip of quads so they stay exact.
local function fill_window(dashboard, window)
    -- a round hole
    if window.shape == "round" then
        love.graphics.circle("fill", window.x, window.y, window.radius, 64)
        return
    end
    -- an arc slot
    local cx, cy = dashboard.center_x, dashboard.center_y
    local steps = 32
    for step = 0, steps - 1 do
        local a1 = math.rad(window.from + (window.to - window.from) * step / steps)
        local a2 = math.rad(window.from + (window.to - window.from) * (step + 1) / steps)
        love.graphics.polygon("fill",
            cx + window.inner * math.cos(a1), cy + window.inner * math.sin(a1),
            cx + window.outer * math.cos(a1), cy + window.outer * math.sin(a1),
            cx + window.outer * math.cos(a2), cy + window.outer * math.sin(a2),
            cx + window.inner * math.cos(a2), cy + window.inner * math.sin(a2))
    end
end
-- }}}

-- {{{ local function glass_mesh_for()
-- A mesh covering the window whose colors say how the glass bends: red 1
-- everywhere; green and blue encode the outward direction, strongest at the
-- glass's edge and zero across its middle — so refraction grows toward the
-- rim, the way a lens's does.
local function glass_mesh_for(dashboard, window)
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
    -- an arc slot: a strip whose inner edge leans inward and outer edge outward
    local cx, cy = dashboard.center_x, dashboard.center_y
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

-- {{{ local function engraved()
-- Text cut into metal: a dark line with a faint light edge below it.
local function engraved(font, text, x, y, width, align)
    love.graphics.setFont(font)
    love.graphics.setColor(1, 1, 1, 0.18)
    love.graphics.printf(text, x, y + 1, width, align)
    love.graphics.setColor(0.08, 0.09, 0.1, 0.85)
    love.graphics.printf(text, x, y, width, align)
end
-- }}}

-- {{{ local function button_spots()
-- Where every clickable button is right now: a list of
-- { verb, label, paint, x, y, radius, de_selected }.
local function button_spots(dashboard, someone_named)
    local cx, cy, R = dashboard.center_x, dashboard.center_y, dashboard.radius
    local spots = {}
    -- the settings menu is open: only its buttons can be pressed
    if dashboard.settings_open then
        for _, button in ipairs(M.SETTINGS_BUTTONS) do
            spots[#spots + 1] = {
                verb = button.verb, label = button.label, paint = button.paint,
                x = cx + button.dx * R, y = cy + button.dy * R, radius = R * 0.075,
                de_selected = false,
            }
        end
        return spots
    end
    -- the order buttons: de-selected (dimmer) until someone is named
    for _, button in ipairs(M.ORDER_BUTTONS) do
        local a = math.rad(button.at)
        spots[#spots + 1] = {
            verb = button.verb, label = button.label, paint = button.paint,
            x = cx + R * 0.64 * math.cos(a), y = cy + R * 0.64 * math.sin(a),
            radius = R * 0.088, de_selected = not someone_named,
        }
    end
    return spots
end
-- }}}

-- {{{ function M.button_under()
-- The verb of the button under a pixel, or nil. Dials never answer.
function M.button_under(dashboard, x, y, someone_named)
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
-- Whether a pixel lies on the dashboard (so a click there is not a map click).
function M.covers(dashboard, x, y)
    local dx, dy = x - dashboard.center_x, y - dashboard.center_y
    return dx * dx + dy * dy <= dashboard.radius * dashboard.radius
end
-- }}}

-- {{{ local function turn_dial()
-- Turns a dial toward its target angle with weight: quickly when far, then
-- settling, never jumping. Angles in degrees.
local function turn_dial(dashboard, name, target, seconds)
    local current = dashboard.dial_angles[name]
    -- go the short way round
    local difference = (target - current + 540) % 360 - 180
    local eased = difference * (1 - math.exp(-seconds * 6))
    dashboard.dial_angles[name] = current + eased
end
-- }}}

-- {{{ local function draw_ring_dial()
-- A paper disc concentric with the dashboard, inscribed with words spaced
-- evenly around it; turned so `index` sits at `window_angle`. Words at the
-- bottom of the dashboard are turned to read upright.
local function draw_ring_dial(dashboard, words, angle, radius, reads_at_bottom)
    local cx, cy = dashboard.center_x, dashboard.center_y
    local spacing = 360 / #words
    love.graphics.setFont(dashboard.fonts.dial)
    for index, word in ipairs(words) do
        local a = math.rad(angle + (index - 1) * spacing)
        local x = cx + radius * math.cos(a)
        local y = cy + radius * math.sin(a)
        local turn = a + math.pi / 2
        -- at the bottom, words run the other way so they are not upside down
        if reads_at_bottom then
            turn = a - math.pi / 2
        end
        local w = dashboard.fonts.dial:getWidth(word)
        local h = dashboard.fonts.dial:getHeight()
        love.graphics.setColor(0.12, 0.12, 0.14, 1)
        love.graphics.print(word, x, y, turn, 1, 1, w / 2, h / 2)
    end
end
-- }}}
-- {{{ local function window_named()
-- The window a dial lies under, found by the dial's name.
local function window_named(dashboard, dial)
    for _, window in ipairs(windows_of(dashboard)) do
        if window.dial == dial then
            return window
        end
    end
    error("dashboard: no window shows the dial '" .. dial .. "'")
end
-- }}}

-- {{{ local function under_window()
-- Draws `draw_contents` clipped to one window's shape. Each dial is its own
-- disc at its own level; clipping each to its window keeps one disc's
-- inscriptions from showing through another disc's window.
local function under_window(dashboard, dial, draw_contents)
    local window = window_named(dashboard, dial)
    love.graphics.stencil(function()
        fill_window(dashboard, window)
    end, "replace", 1)
    love.graphics.setStencilTest("greater", 0)
    draw_contents(window)
    love.graphics.setStencilTest()
end
-- }}}

-- {{{ local function draw_dials()
-- The layer beneath the windows. `state` carries the values to show (see
-- M.draw).
local function draw_dials(dashboard, state, seconds)
    local cx, cy, R = dashboard.center_x, dashboard.center_y, dashboard.radius
    love.graphics.setCanvas({ dashboard.dials, stencil = true })
    love.graphics.clear(0, 0, 0, 0)

    -- months: a cream paper ring, its month's word turned to the top window
    turn_dial(dashboard, "month", -90 - (state.month - 1) * 30, seconds)
    under_window(dashboard, "month", function()
        love.graphics.setColor(0.86, 0.83, 0.76, 1)
        love.graphics.circle("fill", cx, cy, R * 0.95, 256)
        draw_ring_dial(dashboard, M.MONTHS, dashboard.dial_angles.month, R * 0.86, false)
    end)

    -- weekdays: a second ring at its own level, its word turned to the
    -- bottom window
    turn_dial(dashboard, "weekday", 90 - (state.weekday - 1) * (360 / 7), seconds)
    under_window(dashboard, "weekday", function()
        love.graphics.setColor(0.84, 0.81, 0.74, 1)
        love.graphics.circle("fill", cx, cy, R * 0.95, 256)
        draw_ring_dial(dashboard, M.WEEKDAYS, dashboard.dial_angles.weekday, R * 0.86, true)
    end)

    -- the day number: one level lower, on a smaller, darker disc whose rim
    -- passes under the round hole; the disc turns so today's number is there
    turn_dial(dashboard, "day", 90 - (state.day - 1) * (360 / 31), seconds)
    under_window(dashboard, "day", function(window)
        local disc_x, disc_y = window.x, window.y - R * 0.30
        love.graphics.setColor(0.66, 0.63, 0.57, 1)
        love.graphics.circle("fill", disc_x, disc_y, R * 0.36, 96)
        love.graphics.setFont(dashboard.fonts.dial)
        for number = 1, 31 do
            local a = math.rad(dashboard.dial_angles.day + (number - 1) * (360 / 31))
            local text = tostring(number)
            local w = dashboard.fonts.dial:getWidth(text)
            local h = dashboard.fonts.dial:getHeight()
            love.graphics.setColor(0.1, 0.1, 0.12, 1)
            love.graphics.print(text, disc_x + R * 0.30 * math.cos(a), disc_y + R * 0.30 * math.sin(a),
                a - math.pi / 2, 1, 1, w / 2, h / 2)
        end
    end)

    -- the readout dials: paper discs with a number on each
    local readouts = {
        { dial = "fps", text = string.format("%d", state.fps) },
        { dial = "frame_ms", text = string.format("%.1f", state.frame_ms) },
        { dial = "units", text = string.format("%d", state.unit_count) },
    }
    -- the settings menu shows the cap on its large dial
    if dashboard.settings_open then
        readouts[#readouts + 1] = { dial = "cap", text = tostring(state.cap), big = true }
    end
    for _, readout in ipairs(readouts) do
        under_window(dashboard, readout.dial, function(window)
            local font = readout.big and dashboard.fonts.big or dashboard.fonts.readout
            love.graphics.setColor(0.9, 0.88, 0.82, 1)
            love.graphics.circle("fill", window.x, window.y, window.radius, 64)
            love.graphics.setColor(0.1, 0.1, 0.12, 1)
            love.graphics.setFont(font)
            love.graphics.printf(readout.text, window.x - window.radius, window.y - font:getHeight() / 2,
                window.radius * 2, "center")
        end)
    end

    -- the named stand's ring: who the next order goes to, or a reminder
    local named_text = state.named_text
    -- a button was pressed with no one named: the reminder flashes
    if dashboard.flash_seconds > 0 then
        named_text = "NAME SOMEONE FIRST"
        dashboard.flash_seconds = dashboard.flash_seconds - seconds
    end
    -- the settings menu covers this window: nothing to draw beneath it
    if dashboard.settings_open then
        return
    end
    under_window(dashboard, "named", function()
        love.graphics.setColor(0.86, 0.83, 0.76, 1)
        love.graphics.circle("fill", cx, cy, R * 0.45, 192)
        love.graphics.setColor(0.12, 0.12, 0.14, 1)
        love.graphics.setFont(dashboard.fonts.small)
        love.graphics.printf(named_text, cx - R * 0.5, cy + R * 0.36 - dashboard.fonts.small:getHeight() / 2, R, "center")
    end)
end
-- }}}
-- {{{ local function draw_face()
local function draw_face(dashboard, state)
    local cx, cy, R = dashboard.center_x, dashboard.center_y, dashboard.radius
    love.graphics.setCanvas(dashboard.face)
    love.graphics.clear(0, 0, 0, 0)

    -- the body: an outer gunmetal bezel and a steel face, brushed in circles
    love.graphics.setShader(dashboard.metal_shader)
    dashboard.metal_shader:send("face_center", { cx, cy })
    dashboard.metal_shader:send("face_radius", R)
    dashboard.metal_shader:send("base_tone", { 0.24, 0.25, 0.27 })
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle("fill", cx, cy, R, 256)
    dashboard.metal_shader:send("base_tone", { 0.52, 0.54, 0.57 })
    love.graphics.circle("fill", cx, cy, R * 0.955, 256)
    love.graphics.setShader()

    -- a thin chrome edge where bezel meets face
    love.graphics.setColor(0.9, 0.92, 0.95, 0.55)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", cx, cy, R * 0.955, 256)

    -- cut every window out of the metal: replace with nothing at all
    love.graphics.setBlendMode("replace")
    love.graphics.setColor(0, 0, 0, 0)
    for _, window in ipairs(windows_of(dashboard)) do
        fill_window(dashboard, window)
    end
    love.graphics.setBlendMode("alpha")

    -- bezels: a dark inner edge and a bright outer lip around each window
    for _, window in ipairs(windows_of(dashboard)) do
        -- a round window's bezel is two circles
        if window.shape == "round" then
            love.graphics.setColor(0.08, 0.08, 0.09, 0.9)
            love.graphics.setLineWidth(3)
            love.graphics.circle("line", window.x, window.y, window.radius + 1, 64)
            love.graphics.setColor(0.92, 0.94, 0.97, 0.6)
            love.graphics.setLineWidth(1.5)
            love.graphics.circle("line", window.x, window.y, window.radius + 4, 64)
        else
            -- an arc slot's bezel is its outline
            love.graphics.setColor(0.08, 0.08, 0.09, 0.9)
            love.graphics.setLineWidth(3)
            love.graphics.polygon("line", arc_outline(cx, cy, window, 32))
        end
    end

    -- engraved labels above the readouts
    local label_font = dashboard.fonts.label
    engraved(label_font, "FRAMES / S", cx - R * 0.39, cy - R * 0.45, R * 0.3, "center")
    engraved(label_font, "FRAME MS", cx - R * 0.15, cy - R * 0.555, R * 0.3, "center")
    engraved(label_font, "UNITS", cx + R * 0.09, cy - R * 0.45, R * 0.3, "center")
    -- the settings menu's own label replaces the order labels while open
    if dashboard.settings_open then
        engraved(label_font, "MAXIMUM FRAMERATE   (0 = NO CAP)", cx - R * 0.45, cy - R * 0.15, R * 0.9, "center")
    else
        engraved(label_font, "NEXT ORDER GOES TO", cx - R * 0.3, cy + R * 0.13, R * 0.6, "center")
        engraved(label_font, state.settings_hint, cx - R * 0.4, cy + R * 0.50, R * 0.8, "center")
    end

    -- painted buttons, each in a metal bezel
    for _, spot in ipairs(button_spots(dashboard, state.someone_named)) do
        local paint = spot.paint
        local strength = 1
        -- de-selected: still painted, but dimmer
        if spot.de_selected then
            strength = 0.55
        end
        love.graphics.setColor(0.16, 0.17, 0.18, 1)
        love.graphics.circle("fill", spot.x, spot.y, spot.radius * 1.12, 48)
        local pressed = dashboard.pressed_verb == spot.verb
        -- pressed: the paint sinks and darkens
        if pressed then
            strength = strength * 0.7
        end
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
        love.graphics.arc("fill", spot.x, spot.y - spot.radius * 0.1, spot.radius * 0.8, math.pi * 1.1, math.pi * 1.9, 24)
        love.graphics.setFont(label_font)
        love.graphics.setColor(0.05, 0.05, 0.06, 0.95)
        love.graphics.printf(spot.label, spot.x - spot.radius, spot.y - label_font:getHeight() / 2,
            spot.radius * 2, "center")
    end
    love.graphics.setLineWidth(1)
end
-- }}}

-- {{{ local function draw_glass()
-- The glass layer changes only when the set of windows does (the settings
-- menu opening or closing), so it is redrawn only then.
local function draw_glass(dashboard)
    -- the windows are as they were last drawn: nothing to do
    if dashboard.glass_drawn_for == dashboard.settings_open then
        return
    end
    dashboard.glass_drawn_for = dashboard.settings_open
    love.graphics.setCanvas(dashboard.glass)
    love.graphics.clear(0, 0.5, 0.5, 0)
    love.graphics.setBlendMode("replace")
    love.graphics.setColor(1, 1, 1, 1)
    for _, window in ipairs(windows_of(dashboard)) do
        local mesh = glass_mesh_for(dashboard, window)
        love.graphics.draw(mesh)
        mesh:release()
    end
    love.graphics.setBlendMode("alpha")
end
-- }}}

-- {{{ function M.draw()
-- Draws all three layers. `state` (plain values): month (1..12),
-- weekday (1..7), day (1..31), fps (whole), frame_ms (number), unit_count,
-- cap (whole), named_text (string), someone_named (boolean),
-- settings_hint (string). `seconds` is the frame's time, for dial motion.
function M.draw(dashboard, state, seconds)
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
