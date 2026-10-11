-- 017-the-tests.test.lua - checks for every part that can be checked without a window.
--
-- In plain terms: plain LuaJIT runs this file (no LÖVE, no graphics card).
-- It checks the settings reader, the far camera's arithmetic, the sphere
-- fold, the unit records and the move box, the soramech stations, the seed
-- scatter, the frame cap's arithmetic and the spheroid's shape. Each check
-- prints PASS or FAIL with what it found; the file exits non-zero if any fail.
--
-- Run it with scripts/run-tests, which passes the project folder.

local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/centered-ui-design"
package.path = DIR .. "/src/?.lua;" .. package.path

local ffi = require("ffi")
local read_input = require("001-read-the-input")
local far_camera = require("003-the-far-camera")
local sphere_fold = require("004-the-sphere-fold")
local records = require("005-unit-records")
local move_box = require("006-the-move-box")
local seeding = require("007-seeding-the-units")
local stations = require("008-soramech-stations")
local frame_cap = require("010-the-frame-cap")
local spheroid = require("011-the-spheroid")

local passed, failed = 0, 0

-- {{{ local function check()
local function check(name, ok, detail)
    -- the check held
    if ok then
        passed = passed + 1
        print("PASS  " .. name)
    else
        failed = failed + 1
        print("FAIL  " .. name .. (detail and ("  (" .. detail .. ")") or ""))
    end
end
-- }}}

-- {{{ local function good_settings()
-- A full, valid settings table (the shipped input file).
local function good_settings()
    return read_input.read(DIR)
end
-- }}}

-- the settings reader --------------------------------------------------------

do
    local settings = good_settings()
    check("the shipped settings file reads cleanly", settings.unit_count >= 1)

    local missing = good_settings()
    missing.seed = nil
    local ok, message = pcall(read_input.check_settings, missing, "test")
    check("a missing seed stops the program, naming it", not ok and message:find("'seed'") ~= nil, message)

    local too_fast = good_settings()
    too_fast.max_framerate = 241
    ok, message = pcall(read_input.check_settings, too_fast, "test")
    check("a framerate cap above 240 is refused", not ok, message)

    local fractional = good_settings()
    fractional.unit_count = 2.5
    ok = pcall(read_input.check_settings, fractional, "test")
    check("a fractional unit count is refused", not ok)
end

-- the far camera ------------------------------------------------------------

do
    local settings = good_settings()
    for _, case in ipairs({
        { distance = 1e7, half_height = 78, plane = 300 },
        { distance = 1e9, half_height = 20, plane = 350 },
        { distance = 2000, half_height = 140, plane = 100 },
    }) do
        settings.camera_distance = case.distance
        settings.view_half_height = case.half_height
        local camera = far_camera.new(settings, 1.6)
        local corners = far_camera.view_plane_corners(camera, case.plane)
        local expected = { { -1, 1 }, { 1, 1 }, { 1, -1 }, { -1, -1 } }
        local worst = 0
        for index, corner in ipairs(corners) do
            local x, y = far_camera.project(camera, corner[1], corner[2], corner[3])
            worst = math.max(worst, math.abs(x - expected[index][1]), math.abs(y - expected[index][2]))
        end
        -- a hundredth of a pixel on a 1600-pixel-wide window is 1.25e-5 in ndc
        check(string.format("the view plane fills the view exactly (distance %g, zoom %g)",
            case.distance, case.half_height), worst < 1.25e-5, "worst corner error " .. worst)
    end

    settings = good_settings()
    local camera = far_camera.new(settings, 1600 / 1000)
    local worst = 0
    for _, spot in ipairs({ { 10, -20 }, { -50, 33 }, { 0, 0 }, { 70, 70 } }) do
        local x, y = far_camera.project(camera, spot[1], 0, spot[2])
        local px, py = far_camera.ndc_to_pixels(x, y, 1600, 1000)
        local gx, gz = far_camera.ground_point_under_pixel(camera, px, py, 1600, 1000)
        worst = math.max(worst, math.abs(gx - spot[1]), math.abs(gz - spot[2]))
    end
    check("a click finds the ground point it was drawn at", worst < 0.01, "worst " .. worst)

    local _, _, near_depth = far_camera.project(camera, 0, 50, 0)
    local _, _, far_depth = far_camera.project(camera, 0, -50, 0)
    check("higher things are nearer the camera in depth", near_depth < far_depth)
end

-- the sphere fold ------------------------------------------------------------

do
    local fold = sphere_fold.from_settings(good_settings())
    local worst = 0
    for r = 0, fold.tiers_shown, 0.37 do
        worst = math.max(worst, math.abs(sphere_fold.tier_distance(fold, sphere_fold.radius(fold, r)) - r))
    end
    check("the fold runs backwards exactly", worst < 1e-9, "worst " .. worst)

    local inner_band = sphere_fold.radius(fold, 1) - sphere_fold.radius(fold, 0)
    local outer_band = sphere_fold.radius(fold, fold.tiers_shown) - sphere_fold.radius(fold, fold.tiers_shown - 1)
    check("outer tiers are folded narrower than inner ones", outer_band < inner_band)

    local flat = { strength = 0, tiers_shown = 6, hub_radius = 10, edge_radius = 70 }
    check("with no fold every tier is equally wide",
        math.abs((sphere_fold.radius(flat, 2) - sphere_fold.radius(flat, 1)) - 10) < 1e-12)
    check("size scale is 1 at the edge of tier 1", math.abs(sphere_fold.size_scale(fold, 1) - 1) < 1e-12)
end

-- the move box: time scaling and first-come-first-served order -------------

do
    local fold = sphere_fold.from_settings(good_settings())
    local positions = {}
    for _, steps_per_second in ipairs({ 20, 60, 240 }) do
        local a = ffi.new("unit_record[1]")
        local b = ffi.new("unit_record[1]")
        a[0].r = 2; a[0].angle = 1; a[0].length = 2; a[0].width = 1
        a[0].speed_r = 0.1; a[0].speed_angle = 0.05
        local front, back = a, b
        for _ = 1, steps_per_second do
            move_box.move_unit(front, back, 0, 1 / steps_per_second, fold)
            front, back = back, front
        end
        positions[#positions + 1] = { front[0].r, front[0].angle }
    end
    local spread = 0
    for index = 2, #positions do
        spread = math.max(spread, math.abs(positions[index][1] - positions[1][1]),
            math.abs(positions[index][2] - positions[1][2]))
    end
    -- The records are 32-bit floats: each step rounds the position to the
    -- nearest float, about 2.4e-7 apart near tier 2 (2^-22). Over 240 steps
    -- that rounding can add up to 240 * 2^-22, about 5.7e-5 of a tier — far
    -- below a pixel, but it means a run at 240 frames per second lands a
    -- hair away from one at 20. Exact agreement across framerates needs the
    -- fixed step of issue 102 (see issue 111's open questions).
    local rounding_bound = 240 * 2 ^ -22
    check("one second of motion is the same at 20, 60 and 240 steps (to float rounding)",
        spread < rounding_bound, "spread " .. spread .. ", bound " .. rounding_bound)

    local count = 64
    local front = ffi.new("unit_record[?]", count)
    seeding.seed_units(front, count, 99, fold)
    local back_in_order = ffi.new("unit_record[?]", count)
    local back_shuffled = ffi.new("unit_record[?]", count)
    for index = 0, count - 1 do
        move_box.move_unit(front, back_in_order, index, 1 / 30, fold)
    end
    local order = {}
    for index = 0, count - 1 do
        order[#order + 1] = (index * 37) % count  -- a scrambled order
    end
    for _, index in ipairs(order) do
        move_box.move_unit(front, back_shuffled, index, 1 / 30, fold)
    end
    local same = (function()
        for index = 0, count - 1 do
            if back_in_order[index].r ~= back_shuffled[index].r
                or back_in_order[index].angle ~= back_shuffled[index].angle
                or back_in_order[index].heading ~= back_shuffled[index].heading then
                return false
            end
        end
        return true
    end)()
    check("units taken in any order give the same step", same)
    check("a unit record is 48 bytes (three groups of four floats)", records.RECORD_BYTES == 48)
end

-- the soramech stations -------------------------------------------------------

do
    local pushed = {}
    local pool = { push = function(_, task) pushed[#pushed + 1] = task end }
    local map = stations.new_map(pool)
    local ran = 0
    local join = stations.add_station(map, { name = "join", slot_count = 3, where = "here",
        on_ready = function() ran = ran + 1 end })
    stations.deliver(map, join, 1, true)
    stations.deliver(map, join, 3, true)
    check("a station with an empty slot does not run", ran == 0)
    stations.deliver(map, join, 2, true)
    check("a station runs the moment its last slot fills", ran == 1)
    stations.deliver(map, join, 1, true)
    stations.deliver(map, join, 1, true)
    check("extra values wait in their slot's queue", ran == 1)

    local mover = stations.add_station(map, { name = "move", box = "move_unit", slot_count = 1, where = "pool" })
    stations.deliver(map, mover, 1, 7)
    check("a pool station sends its job to the pool", #pushed == 1 and pushed[1][1] == mover and pushed[1][2] == 7)

    local ok = pcall(stations.add_station, map, { name = "typo", slot_count = 1, where = "pol" })
    check("a station that runs nowhere is refused", not ok)
end

-- the seed scatter ---------------------------------------------------------------

do
    local fold = sphere_fold.from_settings(good_settings())
    local one = ffi.new("unit_record[?]", 32)
    local two = ffi.new("unit_record[?]", 32)
    seeding.seed_units(one, 32, 1234, fold)
    seeding.seed_units(two, 32, 1234, fold)
    local same = true
    for index = 0, 31 do
        if one[index].r ~= two[index].r or one[index].angle ~= two[index].angle then
            same = false
        end
    end
    check("the same seed scatters the same units", same)
end

-- the frame cap -----------------------------------------------------------------

do
    check("0 means no cap", frame_cap.frame_budget(0) == nil)
    check("240 means 1/240 of a second per frame", math.abs(frame_cap.frame_budget(240) - 1 / 240) < 1e-15)
    check("caps stay within 0..240", frame_cap.clamp_cap(-5) == 0 and frame_cap.clamp_cap(300) == 240)
    check("the schedule keeps fixed slots", math.abs(frame_cap.next_deadline(10, 0.01, 10.005) - 10.01) < 1e-12)
    check("the schedule restarts after a long stall", math.abs(frame_cap.next_deadline(10, 0.01, 11) - 11.01) < 1e-12)

    local clock = 0
    frame_cap.wait_until(0.05, function() clock = clock + 0.0001; return clock end,
        function(seconds) clock = clock + seconds end)
    check("waiting ends at the deadline", clock >= 0.05 and clock < 0.0502, "ended at " .. clock)
end

-- the spheroid ------------------------------------------------------------------

do
    local vertices, triangles = spheroid.build(12, 18)
    local worst = 0
    local u_low, u_high, v_low, v_high = 1, 0, 1, 0
    for _, vertex in ipairs(vertices) do
        local length = math.sqrt(vertex[1] ^ 2 + vertex[2] ^ 2 + vertex[3] ^ 2)
        worst = math.max(worst, math.abs(length - 1))
        u_low, u_high = math.min(u_low, vertex[4]), math.max(u_high, vertex[4])
        v_low, v_high = math.min(v_low, vertex[5]), math.max(v_high, vertex[5])
    end
    check("every spheroid vertex lies on the unit sphere", worst < 1e-12)
    check("texture coordinates span 0..1", u_low == 0 and u_high == 1 and v_low == 0 and v_high == 1)
    check("triangles come in threes", #triangles % 3 == 0 and #triangles == 12 * 18 * 6)
end

-- the body plan --------------------------------------------------------------

do
    local body_plan = require("018-the-body-plan")
    local vertices = body_plan.figure_vertices(8, 10)
    local parts_seen, worst = {}, 0
    for _, vertex in ipairs(vertices) do
        parts_seen[vertex[6]] = true
        worst = math.max(worst, math.abs(math.sqrt(vertex[1] ^ 2 + vertex[2] ^ 2 + vertex[3] ^ 2) - 1))
    end
    local part_count = 0
    for _ in pairs(parts_seen) do
        part_count = part_count + 1
    end
    check("the figure mesh holds six parts, each on the unit sphere", part_count == 6 and worst < 1e-12)

    local leg = body_plan.PARTS[6]
    local hip_x, hip_y, hip_z = body_plan.bend(leg, 0, 1, 0, math.pi / 2, 1)
    local still_x, still_y, still_z = body_plan.bend(leg, 0, 1, 0, 0, 0)
    check("bending leaves the hip where it is",
        hip_x == still_x and hip_y == still_y and hip_z == still_z)
    -- at swing = sin(pi/2) = 1 and full pace, the foot (y = -1, s = 1) moves
    -- forward by stride x length and up by lift x length
    local _, foot_y, foot_z = body_plan.bend(leg, 0, -1, 0, math.pi / 2, 1)
    local length = 2 * leg.radii[2]
    check("the foot travels stride x length forward and lift x length up",
        math.abs(foot_z - (leg.center[3] + leg.stride * length)) < 1e-12
        and math.abs(foot_y - (leg.center[2] - leg.radii[2] + leg.lift * length)) < 1e-12)
    local _, _, back_foot_z = body_plan.bend(leg, 0, -1, 0, -math.pi / 2, 1)
    check("on the back swing the foot goes back and does not lift",
        back_foot_z < leg.center[3])

    local fold = sphere_fold.from_settings(good_settings())
    local phases = {}
    for _, speed in ipairs({ 0, 0.05, 0.2 }) do
        local a = ffi.new("unit_record[1]")
        local b = ffi.new("unit_record[1]")
        a[0].r = 2; a[0].angle = 1; a[0].length = 2; a[0].width = 1; a[0].phase = 0
        a[0].speed_r = speed
        move_box.move_unit(a, b, 0, 0.1, fold)
        phases[#phases + 1] = b[0].phase
    end
    check("the walking phase turns faster the faster a unit goes",
        phases[1] > 0 and phases[2] > phases[1] and phases[3] > phases[2])
end

-- the arch -------------------------------------------------------------------

do
    local arch = require("019-the-arch")
    local dashboard = require("014-the-dashboard")
    local section = arch.new(800, 870, 740, dashboard.ARCH_WIDTH_SHARE, dashboard.ARCH_BAND_SHARE)

    local overlap = false
    for x = 400, 1200, 7 do
        for y = 100, 880, 7 do
            if arch.in_interior(section, x, y) and arch.in_band(section, x, y) then
                overlap = true
            end
        end
    end
    check("the arch's surface and its band never overlap", not overlap)

    local neighbour = arch.shifted(section, 1)
    check("a neighbour's foot lands exactly on yours (the M's middle stroke)",
        math.abs((neighbour.center_x - neighbour.width / 2)
            - (section.center_x + section.width / 2 - section.band)) < 1e-9)

    -- {{{ local function fits()
    -- Whether a circle (arch units) lies wholly on the surface.
    local function fits(across, up, radius)
        for step = 0, 15 do
            local a = 2 * math.pi * step / 16
            local x = across + radius * math.cos(a)
            local u = up + radius * math.sin(a)
            if u < 0 or math.abs(x) > arch.interior_half_width(section, u) then
                return false
            end
        end
        return true
    end
    -- }}}
    local all_fit = true
    for _, button in ipairs(dashboard.ORDER_BUTTONS) do
        all_fit = all_fit and fits(button.across, button.up, dashboard.ORDER_BUTTON_RADIUS)
    end
    for _, button in ipairs(dashboard.SETTINGS_BUTTONS) do
        all_fit = all_fit and fits(button.across, button.up, dashboard.SETTINGS_BUTTON_RADIUS)
    end
    for _, window in ipairs(dashboard.WINDOWS) do
        -- round windows are checked as circles; slots by their corners
        if window.shape == "round" then
            all_fit = all_fit and fits(window.across, window.up, window.radius)
        elseif window.shape == "slot" then
            all_fit = all_fit and fits(window.across - window.half_width, window.up, window.half_height)
                and fits(window.across + window.half_width, window.up, window.half_height)
        else
            -- arc slots: their four corners around the calendar center
            for _, radius in ipairs({ window.inner, window.outer }) do
                for _, angle in ipairs({ window.from, window.to }) do
                    local a = math.rad(angle)
                    all_fit = all_fit and fits(dashboard.CALENDAR_CENTER[1] + radius * math.cos(a),
                        dashboard.CALENDAR_CENTER[2] - radius * math.sin(a), 0)
                end
            end
        end
    end
    check("every button and window lies wholly on the arch's surface", all_fit)
end

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
