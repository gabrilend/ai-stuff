-- 017-the-tests.test.lua - checks for every part that can be checked without a window.
--
-- In plain terms: plain LuaJIT runs this file (no LÖVE, no graphics card).
-- It checks the settings reader, the far camera's arithmetic, the sphere
-- fold, the unit records and the move box, the ceramic engine's C boxes (run
-- inline through LuaJIT's FFI: their motion against the Lua twin, chunk order,
-- claims, carrying, delivery), the seed scatter, the frame cap's arithmetic,
-- the spheroid's shape, the body plan and the arch.
-- Each check prints PASS or FAIL with what it found; the file exits non-zero
-- if any fail.
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

    local wrong_word = good_settings()
    wrong_word.view_depth = "sideways"
    ok, message = pcall(read_input.check_settings, wrong_word, "test")
    check("a view that is not one of the allowed words is refused, naming them",
        not ok and message:find("flat, hub") ~= nil, message)
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
            local x, y = far_camera.project_fixed(camera, corner[1], corner[2], corner[3])
            worst = math.max(worst, math.abs(x - expected[index][1]), math.abs(y - expected[index][2]))
        end
        -- a hundredth of a pixel on a 1600-pixel-wide window is 1.25e-5 in ndc
        check(string.format("the view plane fills the view exactly (distance %g, zoom %g)",
            case.distance, case.half_height), worst < 1.25e-5, "worst corner error " .. worst)
    end

    settings = good_settings()
    local camera = far_camera.new(settings, 1600 / 1000)
    camera.view = "flat"  -- these checks are of the far camera
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

    -- the hub camera (issue 214)
    local hub = far_camera.new(good_settings(), 1600 / 1000)
    hub.view = "hub"
    hub.turn = math.pi / 4
    worst = 0
    for _, spot in ipairs({ { 20, -20 }, { 40, -10 }, { 15, -45 }, { 60, -55 } }) do
        local x, y = far_camera.project(hub, spot[1], 0, spot[2])
        local px, py = far_camera.ndc_to_pixels(x, y, 1600, 1000)
        local gx, gz = far_camera.ground_point_under_pixel(hub, px, py, 1600, 1000)
        worst = math.max(worst, math.abs(gx - spot[1]), math.abs(gz - spot[2]))
    end
    check("under the hub camera, a click finds the ground point it was drawn at", worst < 1e-6, "worst " .. worst)
    -- facing north-east (the chair at 45 degrees), a point straight ahead is centred
    local ahead_x = far_camera.project(hub, 50 * math.sin(math.pi / 4), 0, -50 * math.cos(math.pi / 4))
    check("the hub camera aims along the chair", math.abs(ahead_x) < 1e-9)
    local _, _, near_ground = far_camera.project(hub, 20 * math.sin(math.pi / 4), 0, -20 * math.cos(math.pi / 4))
    local _, _, far_ground = far_camera.project(hub, 90 * math.sin(math.pi / 4), 0, -90 * math.cos(math.pi / 4))
    check("under the hub camera, nearer ground is nearer in depth", near_ground < far_ground)

    -- the slant view (issue 214): the hub on the bottom row, the reach on
    -- the top row, straight along the chair, and no shrinking with distance
    local slant = far_camera.new(good_settings(), 1600 / 1000)
    slant.view = "slant"
    slant.turn = math.pi / 4
    local reach = slant.slant_reach
    local along_x, along_z = math.sin(math.pi / 4), -math.cos(math.pi / 4)
    local hub_x, hub_y = far_camera.project(slant, 0, 0, 0)
    check("under the slant view, the hub is on the bottom row, centred",
        math.abs(hub_y + 1) < 1e-9 and math.abs(hub_x) < 1e-9, hub_x .. " " .. hub_y)
    local top_x, top_y = far_camera.project(slant, reach * along_x, 0, reach * along_z)
    check("under the slant view, the reach along the chair is on the top row",
        math.abs(top_y - 1) < 1e-9 and math.abs(top_x) < 1e-9, top_x .. " " .. top_y)
    local _, near_foot = far_camera.project(slant, 20 * along_x, 0, 20 * along_z)
    local _, near_head = far_camera.project(slant, 20 * along_x, 3, 20 * along_z)
    local _, far_foot = far_camera.project(slant, 100 * along_x, 0, 100 * along_z)
    local _, far_head = far_camera.project(slant, 100 * along_x, 3, 100 * along_z)
    check("under the slant view, a thing far out is as tall on screen as one near",
        math.abs((near_head - near_foot) - (far_head - far_foot)) < 1e-9)
    local _, _, near_depth = far_camera.project(slant, 20 * along_x, 0, 20 * along_z)
    local _, _, far_depth = far_camera.project(slant, 100 * along_x, 0, 100 * along_z)
    check("under the slant view, nearer ground is nearer in depth", near_depth < far_depth)
    worst = 0
    for _, spot in ipairs({ { 0, -60 }, { 37, -12 }, { -25, -90 }, { 80, -40 } }) do
        local x, y = far_camera.project(slant, spot[1], 0, spot[2])
        local px, py = far_camera.ndc_to_pixels(x, y, 1600, 1000)
        local gx, gz = far_camera.ground_point_under_pixel(slant, px, py, 1600, 1000)
        worst = math.max(worst, math.abs(gx - spot[1]), math.abs(gz - spot[2]))
    end
    check("under the slant view, a click finds the ground point it was drawn at", worst < 1e-6, "worst " .. worst)

    -- the arch view (issue 214): rings grown from the console's arch
    local arch_view = far_camera.new(good_settings(), 1600 / 1000)
    arch_view.view = "arch"
    arch_view.turn = math.pi / 4
    far_camera.set_arch(arch_view, { center_x = 800, base_y = 1000, height = 500, width = 1700, band = 40 }, 1600, 1000)
    local hub_r = arch_view.arch_hub_radius
    local function pixel_of(radius, angle, height)
        local x, y = far_camera.project(arch_view, radius * math.sin(angle), height or 0, -radius * math.cos(angle))
        return far_camera.ndc_to_pixels(x, y, 1600, 1000)
    end
    local apex_x, apex_y = pixel_of(hub_r, math.pi / 4)
    check("under the arch view, the hub straight ahead lands on the arch's apex",
        math.abs(apex_x - 800) < 1e-6 and math.abs(apex_y - 500) < 1e-6, apex_x .. " " .. apex_y)
    -- just inside the span's end, the hub lands on the arch's foot
    arch_view.arch_span = math.rad(170)
    local foot_x, foot_y = pixel_of(hub_r, math.pi / 4 + math.rad(85) * 0.9999)
    check("under the arch view, the hub at the span's end lands on the arch's foot",
        math.abs(foot_x - (800 + 850)) < 0.01 and math.abs(foot_y - 1000) < 0.01, foot_x .. " " .. foot_y)
    arch_view.arch_span = math.rad(450)
    local top_x, top_y = pixel_of(arch_view.arch_reach, math.pi / 4)
    check("under the arch view, the reach straight ahead is on the top row",
        math.abs(top_y) < 1e-6 and math.abs(top_x - 800) < 1e-6, top_x .. " " .. top_y)
    local _, near_feet = pixel_of(30, math.pi / 4)
    local _, near_top = pixel_of(30, math.pi / 4, 3)
    local _, far_feet = pixel_of(100, math.pi / 4)
    local _, far_top = pixel_of(100, math.pi / 4, 3)
    check("under the arch view, a thing far out is as tall on screen as one near",
        math.abs((near_feet - near_top) - (far_feet - far_top)) < 1e-9)
    local near_a = pixel_of(30, math.pi / 4)
    local near_b = pixel_of(30, math.pi / 4 + 0.05)
    local far_a = pixel_of(100, math.pi / 4)
    local far_b = pixel_of(100, math.pi / 4 + 0.05)
    check("under the arch view, the same turn of angle crosses more screen far out",
        math.abs(far_b - far_a) > 1.5 * math.abs(near_b - near_a))
    -- spots on screen and in front (off the screen's sides, a neighbour's
    -- nearer ground covers ours, and a click there finds that instead)
    worst = 0
    for _, spot in ipairs({ { 20, 0.3 }, { 60, 0.9 }, { 95, 0.85 }, { 40, 0.5 } }) do
        local px, py = pixel_of(spot[1], spot[2])
        local gx, gz = far_camera.ground_point_under_pixel(arch_view, px, py, 1600, 1000)
        worst = math.max(worst, math.abs(gx - spot[1] * math.sin(spot[2])), math.abs(gz + spot[1] * math.cos(spot[2])))
    end
    check("under the arch view, a click finds the ground point it was drawn at", worst < 1e-6, "worst " .. worst)
    -- clicking: a figure drawn at either end of a magic circle can be picked
    -- there, and the reach is tied to the window, not the console
    local behind = { 50 * math.sin(math.pi / 4 + math.pi), 2, -50 * math.cos(math.pi / 4 + math.pi) }
    local elsewhere = { 30 * math.sin(math.pi / 4), 2, -30 * math.cos(math.pi / 4) }
    local places = far_camera.screen_places(arch_view, behind[1], behind[2], behind[3], 1600, 1000)
    check("under a span past 360 degrees, a figure behind the chair is drawn in two places", #places == 2)
    local picked_both = true
    for _, place in ipairs(places) do
        picked_both = picked_both and far_camera.pick_nearest(arch_view, { elsewhere, behind },
            place[1] + 8, place[2] - 6, 1600, 1000) == 2
    end
    check("a click a few pixels off either copy of a figure picks it", picked_both)
    check("a click on empty ground picks no one",
        far_camera.pick_nearest(arch_view, { elsewhere, behind }, 800, 20, 1600, 1000) == nil)

    -- the view dials: the reach and span keep within their limits, and a
    -- farther reach presses the far rings closer together on screen
    local dialled = far_camera.new(good_settings(), 1600 / 1000)
    dialled.view = "arch"
    far_camera.set_arch(dialled, { center_x = 800, base_y = 1000, height = 500, width = 1700, band = 40 }, 1600, 1000)
    far_camera.set_arch_reach(dialled, 1e9)
    far_camera.set_arch_span(dialled, 0)
    check("the view dials keep within their limits",
        dialled.arch_reach == far_camera.ARCH_REACH_LIMITS[2] and dialled.arch_span == far_camera.ARCH_SPAN_LIMITS[1])
    local function ring_gap(reach)
        far_camera.set_arch_reach(dialled, reach)
        local _, y80 = far_camera.project(dialled, 0, 0, -80)
        local _, y90 = far_camera.project(dialled, 0, 0, -90)
        return math.abs(y90 - y80)
    end
    check("a farther view distance presses the far rings closer together", ring_gap(200) < ring_gap(112))

    -- a magic circle: with a span past a full turn, ground straight behind
    -- the chair shows twice, at both ends of the span
    local behind_x, behind_z = 50 * math.sin(math.pi / 4 + math.pi), -50 * math.cos(math.pi / 4 + math.pi)
    local _, _, _, _, _, _, inside_back = far_camera.arch_place(arch_view, behind_x, behind_z, -1)
    local _, _, _, _, _, _, inside_here = far_camera.arch_place(arch_view, behind_x, behind_z, 0)
    local left_x = far_camera.arch_place(arch_view, behind_x, behind_z, 0)
    local right_x = far_camera.arch_place(arch_view, behind_x, behind_z, -1)
    check("under a span past 360 degrees, ground behind the chair shows at both ends",
        inside_back and inside_here and math.abs(left_x + right_x - 1600) < 1e-6, left_x .. " " .. right_x)
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

    -- the size law: shrinking far out, or (slant view) full size everywhere
    local shrinking = sphere_fold.from_settings(good_settings())
    shrinking.size_keep = 0
    local keeping = sphere_fold.from_settings(good_settings())
    keeping.size_keep = 1
    check("far things shrink under the shrinking size law",
        sphere_fold.size_scale(shrinking, shrinking.tiers_shown) < 0.9)
    check("far things keep full size under the keeping size law",
        sphere_fold.size_scale(keeping, keeping.tiers_shown) == 1)

    -- walking on the sphere: per tier walked, how far a walker crosses the
    -- map sideways (folded radius / lap radius) and outward (the fold's
    -- slope), near the hub and far out
    local near_r, far_r = 1, fold.tiers_shown - 0.3
    local near_sideways = sphere_fold.radius(fold, near_r) / sphere_fold.side_radius(fold, near_r)
    local far_sideways = sphere_fold.radius(fold, far_r) / sphere_fold.side_radius(fold, far_r)
    check("far out, a walker crosses the map sideways faster than near the hub",
        far_sideways > 1.5 * near_sideways, near_sideways .. " " .. far_sideways)
    check("far out, outward steps stay dense (cross less of the map)",
        sphere_fold.slope(fold, far_r) < sphere_fold.slope(fold, near_r))
end

-- the land as lit points (issue 214) ---------------------------------------

do
    local terrain = require("026-the-terrain")
    local fold = sphere_fold.from_settings(good_settings())
    local a = terrain.build(5, fold)
    local b = terrain.build(5, fold)
    local same = #a == #b and #a > 1000
    for index = 1, #a do
        same = same and a[index].angle == b[index].angle and a[index].height == b[index].height
    end
    check("the same seed makes the same land", same, #a .. " points")
    -- points evenly along every ring: a ring holds as many as its length at
    -- the spacing, so the outermost ring holds several times the innermost
    local by_ring = {}
    for _, point in ipairs(a) do
        local key = string.format("%.6f", point.r)
        by_ring[key] = (by_ring[key] or 0) + 1
    end
    local fewest, most = math.huge, 0
    for _, count in pairs(by_ring) do
        fewest = math.min(fewest, count)
        most = math.max(most, count)
    end
    check("longer rings far out hold more points than short ones near the hub", most > 4 * fewest,
        fewest .. " to " .. most)
    -- a mesa rises above the land around it
    local hills = terrain.mesas(5, fold)
    local hill = hills[1]
    -- the lake's points are water, made the same way every time
    local _, water_a = terrain.build(5, fold)
    local _, water_b = terrain.build(5, fold)
    local lake_same = #water_a > 20 and #water_a == #water_b
    for index = 1, #water_a do
        lake_same = lake_same and water_a[index].wave_phase == water_b[index].wave_phase
    end
    check("the same seed makes the same lake", lake_same, #water_a .. " water points")
    check("every sheen-point records its own two colours",
        a[1].sun_color ~= nil and a[1].shade_color ~= nil and water_a[1].shade_color ~= nil)
    check("a mesa's top stands above the land beside it",
        terrain.height_at(hills, hill.x, hill.z) > terrain.height_at(hills, hill.x + hill.radius * 3, hill.z) + 2)
    -- a slope facing east turns its bright pole up in the morning and its
    -- dark pole up at evening; at midnight everything turns dark-up
    local function turn(facing, hour)
        local x, y, z = terrain.sun_direction(hour)
        return math.abs(terrain.shade_turn(facing[1], facing[2], facing[3], x, y, z, 1))
    end
    -- the sun circles the hub: a slope facing east is lit when the sun's
    -- bearing is east (a quarter day after its north) and in shadow half a
    -- day later, when the sun is in the west
    local east = { 0.7071, 0.7071, 0 }
    check("a slope facing east is lit when the sun is east, in shadow when it is west",
        turn(east, math.pi / 2) < math.pi / 4 and turn(east, -math.pi / 2) > math.pi / 2,
        turn(east, math.pi / 2) .. " " .. turn(east, -math.pi / 2))
    local ax, _, az = terrain.sun_direction(0.3)
    local bx, _, bz = terrain.sun_direction(0.3 + math.pi)
    check("the sun goes all the way round the hub in a day",
        math.abs(ax + bx) < 1e-9 and math.abs(az + bz) < 1e-9)
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
    check("a unit record is 64 bytes and a cuboid 48 (groups of four floats)",
        records.RECORD_BYTES == 64 and records.CUBOID_BYTES == 48)
end
-- the ceramic engine's boxes (C), run inline from here ----------------------

do
    local host = require("023-the-ceramic-host")
    local library = host.load(DIR)
    local settings = good_settings()
    local fold = sphere_fold.from_settings(settings)
    library.ceramics_set_fold(fold.strength, fold.tiers_shown, fold.hub_radius, fold.edge_radius, 5.0)
    library.ceramics_set_size_keep(fold.size_keep)
    library.ceramics_set_far_pole(fold.far_pole)
    for index, section in ipairs(seeding.SECTIONS) do
        library.ceramics_set_section(index - 1, section.r, section.angle, section.radius)
    end

    -- the C motion against its Lua twin, over many seeded units
    local count = 64
    local front = ffi.new("unit_record[?]", count)
    seeding.seed_units(front, count, 4242, fold)
    local lua_back = ffi.new("unit_record[?]", count)
    local c_back = ffi.new("unit_record[?]", count)
    local worst = 0
    for index = 0, count - 1 do
        move_box.move_unit(front, lua_back, index, 1 / 30, fold)
        library.ceramics_move_reference(front + index, c_back + index, 1 / 30)
        for _, field in ipairs({ "r", "angle", "heading", "phase", "speed_r" }) do
            worst = math.max(worst, math.abs(lua_back[index][field] - c_back[index][field]))
        end
    end
    check("the C motion matches its Lua twin", worst < 1e-5, "worst " .. worst)

    worst = 0
    for r = 0, fold.tiers_shown, 0.29 do
        worst = math.max(worst, math.abs(library.ceramics_side_radius(r) - sphere_fold.side_radius(fold, r)))
    end
    check("the C lap radius matches its Lua twin", worst < 1e-12, "worst " .. worst)

    -- and under the other size law (the stride is sized by it)
    local other_law = 1 - fold.size_keep
    local other_fold = sphere_fold.from_settings(settings)
    other_fold.size_keep = other_law
    library.ceramics_set_size_keep(other_law)
    worst = 0
    for index = 0, count - 1 do
        move_box.move_unit(front, lua_back, index, 1 / 30, other_fold)
        library.ceramics_move_reference(front + index, c_back + index, 1 / 30)
        for _, field in ipairs({ "r", "angle", "heading", "phase", "speed_r" }) do
            worst = math.max(worst, math.abs(lua_back[index][field] - c_back[index][field]))
        end
    end
    check("the C motion matches its Lua twin under the other size law", worst < 1e-5, "worst " .. worst)
    library.ceramics_set_size_keep(fold.size_keep)

    -- {{{ local function world_of()
    -- A small seeded world in fresh blocks: units, cuboids, front and back.
    local function world_of(unit_count, cuboid_count, seed)
        local world = {
            units = { ffi.new("unit_record[?]", unit_count), ffi.new("unit_record[?]", unit_count) },
            cubes = { ffi.new("cuboid_record[?]", cuboid_count), ffi.new("cuboid_record[?]", cuboid_count) },
            unit_count = unit_count, cuboid_count = cuboid_count, front = 1,
        }
        seeding.seed_units(world.units[1], unit_count, seed, fold)
        seeding.seed_cuboids(world.cubes[1], cuboid_count, seed, fold)
        return world
    end
    -- }}}

    -- {{{ local function run_steps()
    -- Runs `steps` whole steps inline; `reversed` runs every stage's chunks
    -- backwards, as workers finishing in another order would.
    local function run_steps(world, steps, reversed)
        library.ceramics_set_counts(world.unit_count, world.cuboid_count, 99)
        for _ = 1, steps do
            local front, back = world.front, 3 - world.front
            library.ceramics_set_world(world.units[front], world.units[back], world.cubes[front], world.cubes[back])
            library.ceramics_run_inline(0, 1 / 60, reversed and 1 or 0)
            library.ceramics_run_inline(1, 1 / 60, reversed and 1 or 0)
            world.front = back
        end
    end
    -- }}}

    local forward_world = world_of(150, 40, 31)
    local reversed_world = world_of(150, 40, 31)
    run_steps(forward_world, 600, false)
    run_steps(reversed_world, 600, true)
    local identical = ffi.string(forward_world.units[forward_world.front], 150 * records.RECORD_BYTES)
        == ffi.string(reversed_world.units[reversed_world.front], 150 * records.RECORD_BYTES)
        and ffi.string(forward_world.cubes[forward_world.front], 40 * records.CUBOID_BYTES)
        == ffi.string(reversed_world.cubes[reversed_world.front], 40 * records.CUBOID_BYTES)
    check("chunks run in any order give the same world, byte for byte (600 steps)", identical)

    -- claims: two units fetching one cuboid; the lower-numbered one gets it
    local claim = world_of(2, 1, 5)
    local units, cubes = claim.units[1], claim.cubes[1]
    for index = 0, 1 do
        units[index].owner = 0
        units[index].order_kind = 0
        units[index].r = 2
        units[index].angle = 0.5 + index * 0.01
        units[index].job = 0
        units[index].target = -1
    end
    cubes[0].r = 2.05
    cubes[0].angle = 0.505
    -- step until it is lifted (at most 4 seconds), and look then: a fixed
    -- wait can overshoot into delivery once haulers walk faster
    for _ = 1, 240 do
        run_steps(claim, 1, false)
        if claim.cubes[claim.front][0].state ~= records.CUBE_LYING then
            break
        end
    end
    -- a few more steps, so the losing unit hears it lost and the cuboid is
    -- carried along a little
    run_steps(claim, 10, false)
    local claimed = claim.cubes[claim.front][0]
    check("two units after one cuboid: the lower-numbered unit carries it",
        claimed.state == records.CUBE_CARRIED and claimed.carrier == 0,
        "state " .. claimed.state .. " carrier " .. claimed.carrier)
    check("the other gives up and goes back to looking",
        claim.units[claim.front][1].job == records.JOB_IDLE)

    -- a carried cuboid rides with its carrier
    local carrier = claim.units[claim.front][0]
    local cx, cz = sphere_fold.ground_position(fold, carrier.r, carrier.angle)
    local bx, bz = sphere_fold.ground_position(fold, claimed.r, claimed.angle)
    local apart = math.sqrt((cx - bx) ^ 2 + (cz - bz) ^ 2)
    check("a carried cuboid stays in front of its carrier", apart < 4, "apart " .. apart)

    -- personal space: two units on top of each other part, to a distance
    -- that grows with their ring — closer near the hub than far out
    local function settled_apart(r)
        local pair = world_of(2, 1, 9)
        for index = 0, 1 do
            local unit = pair.units[1][index]
            unit.owner = 4          -- foes do not haul: they only stand
            unit.order_kind = 0
            unit.r = r
            unit.angle = 1.0 + index * 1e-4
            unit.speed_r = 0
            unit.speed_angle = 0
        end
        run_steps(pair, 120, false)
        local a, b = pair.units[pair.front][0], pair.units[pair.front][1]
        local ax, az = sphere_fold.ground_position(fold, a.r, a.angle)
        local bx, bz = sphere_fold.ground_position(fold, b.r, b.angle)
        return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2)
    end
    local near_apart, far_apart = settled_apart(1.0), settled_apart(5.0)
    check("two units on one spot part, closer near the hub than far out",
        near_apart > 1 and far_apart > 1.5 * near_apart, near_apart .. " " .. far_apart)

    -- the moving surfaces (issue 214): the engine's water turn matches its
    -- Lua twin, and the sheen stage gives the same water in any chunk order
    local terrain = require("026-the-terrain")
    local fx, fy, fz = ffi.new("double[1]"), ffi.new("double[1]"), ffi.new("double[1]")
    local sx, sy, sz = terrain.sun_direction(-0.6)
    worst = 0
    for step = 1, 40 do
        local x, z, t, phase = step * 3.1 - 60, 40 - step * 1.7, step * 0.37, step * 0.9
        local c = library.ceramics_water_lean(x, z, t, phase, sx, sy, sz, fx, fy, fz)
        local l, lx, ly, lz = terrain.water_lean(x, z, t, phase, sx, sy, sz)
        worst = math.max(worst, math.abs(c - l), math.abs(fx[0] - lx), math.abs(fy[0] - ly), math.abs(fz[0] - lz))
    end
    check("the engine's water turn matches its Lua twin", worst < 1e-9, "worst " .. worst)
    local _, water = terrain.build(5, fold)
    -- {{{ local function water_after()
    -- Runs the sheen stage inline for some steps over fresh water blocks,
    -- chunks in order or reversed; returns the final front block.
    local function water_after(reversed)
        local count = #water
        local blocks = { ffi.new("sheen_record[?]", count), ffi.new("sheen_record[?]", count) }
        for index, point in ipairs(water) do
            local w = blocks[1][index - 1]
            w.r, w.angle, w.driven, w.wave_phase, w.facing_y = point.r, point.angle, 1, point.wave_phase, 1
        end
        library.ceramics_set_sheen_count(count)
        library.ceramics_set_sun(sx, sy, sz)
        local front = 1
        for _ = 1, 30 do
            library.ceramics_set_sheen_world(blocks[front], blocks[3 - front])
            library.ceramics_run_inline(2, 1 / 60, reversed and 1 or 0)
            front = 3 - front
        end
        library.ceramics_set_sheen_count(0)
        return blocks[front], count
    end
    -- }}}
    local forward, count = water_after(false)
    local backward = water_after(true)
    check("the sheen stage gives the same water in any chunk order",
        count > 20 and ffi.string(forward, count * records.SHEEN_BYTES) == ffi.string(backward, count * records.SHEEN_BYTES),
        count .. " water points")

    -- a delivered cuboid rests in its own color's section
    local deliveries = 0
    local all_home = true
    local settled = world_of(60, 30, 77)
    run_steps(settled, 4000, false)
    local final = settled.cubes[settled.front]
    for index = 0, 29 do
        local cuboid = final[index]
        if cuboid.state == records.CUBE_DELIVERED then
            deliveries = deliveries + 1
            local section = seeding.SECTIONS[cuboid.color + 1]
            local sx, sz = sphere_fold.ground_position(fold, section.r, section.angle)
            local x, z = sphere_fold.ground_position(fold, cuboid.r, cuboid.angle)
            local reach = sphere_fold.slope(fold, section.r) * section.radius
            if math.sqrt((sx - x) ^ 2 + (sz - z) ^ 2) > reach then
                all_home = false
            end
        end
    end
    check("cuboids get delivered", deliveries > 0, deliveries .. " delivered")
    check("every delivered cuboid rests inside its own color's section", all_home)
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
    -- the shipped window: 1600 by 1000, the arch half its height, full width
    -- the arch as the settings make it, in a 1600 x 1000 window
    local share = good_settings().arch_height_share
    local section = arch.new(800, 1000, 1000 * share, dashboard.width_share_for(1600, 1000, share),
        dashboard.ARCH_BAND_SHARE)

    local overlap = false
    for x = 0, 1600, 7 do
        for y = 400, 1000, 7 do
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

    -- no two pieces shown together overlap (the layout is packed in rows
    -- across a low arch, so this is easy to get wrong)
    -- {{{ local function shape_of()
    -- A piece as a test of whether a point (arch units) lies inside it, and
    -- a list of points along its edge.
    local function shape_of(kind, piece, radius)
        local edge = {}
        -- a circle: buttons and round windows
        if kind == "circle" then
            for step = 0, 23 do
                local a = 2 * math.pi * step / 24
                edge[#edge + 1] = { piece.across + radius * math.cos(a), piece.up + radius * math.sin(a) }
            end
            return function(x, u)
                return (x - piece.across) ^ 2 + (u - piece.up) ^ 2 < radius * radius
            end, edge
        end
        -- a slot: a rectangle
        if kind == "slot" then
            for _, corner in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 }, { 0, 1 }, { 0, -1 } }) do
                edge[#edge + 1] = { piece.across + corner[1] * piece.half_width, piece.up + corner[2] * piece.half_height }
            end
            return function(x, u)
                return math.abs(x - piece.across) < piece.half_width and math.abs(u - piece.up) < piece.half_height
            end, edge
        end
        -- an arc slot round the calendar center (screen angles: -90 is up)
        local cx, cu = dashboard.CALENDAR_CENTER[1], dashboard.CALENDAR_CENTER[2]
        for step = 0, 12 do
            local a = math.rad(piece.from + (piece.to - piece.from) * step / 12)
            for _, r in ipairs({ piece.inner, piece.outer }) do
                edge[#edge + 1] = { cx + r * math.cos(a), cu - r * math.sin(a) }
            end
        end
        return function(x, u)
            local r = math.sqrt((x - cx) ^ 2 + (u - cu) ^ 2)
            local a = math.deg(math.atan2(-(u - cu), x - cx))
            return r > piece.inner and r < piece.outer and a > piece.from and a < piece.to
        end, edge
    end
    -- }}}
    local overlapping = {}
    for _, mode in ipairs({ "orders", "settings" }) do
        local pieces = {}
        local buttons = mode == "orders" and dashboard.ORDER_BUTTONS or dashboard.SETTINGS_BUTTONS
        local button_radius = mode == "orders" and dashboard.ORDER_BUTTON_RADIUS or dashboard.SETTINGS_BUTTON_RADIUS
        for _, button in ipairs(buttons) do
            local inside, edge = shape_of("circle", button, button_radius)
            pieces[#pieces + 1] = { name = button.verb, inside = inside, edge = edge }
        end
        -- engraved labels, as rectangles about the size their letters take
        -- (a letter about 0.035 arch units wide, a line 0.05 high)
        for _, label in ipairs(dashboard.LABELS) do
            if label.only == "always" or label.only == mode then
                local inside, edge = shape_of("slot", { across = label.across, up = label.up,
                    half_width = #label.text * 0.0175, half_height = 0.025 })
                pieces[#pieces + 1] = { name = label.text, inside = inside, edge = edge }
            end
        end
        for _, window in ipairs(dashboard.WINDOWS) do
            -- shown in this mode
            if window.only == "always" or window.only == mode then
                local kind = window.shape == "round" and "circle" or window.shape
                local inside, edge = shape_of(kind, window, window.radius)
                pieces[#pieces + 1] = { name = window.dial, inside = inside, edge = edge }
            end
        end
        for i = 1, #pieces do
            for j = 1, #pieces do
                if i ~= j then
                    for _, point in ipairs(pieces[i].edge) do
                        if pieces[j].inside(point[1], point[2]) then
                            overlapping[#overlapping + 1] = mode .. ": " .. pieces[i].name .. "/" .. pieces[j].name
                            break
                        end
                    end
                end
            end
        end
    end
    -- spinning along the curve (issue 302): no spin is no change; half a
    -- seat's spin carries the arch's apex to the next seat's foot
    local still = { section = section, chair_offset = 0 }
    local worst_still = 0
    for _, spot in ipairs({ { 800, 960 }, { 500, 930 }, { 1250, 985 }, { 800, 820 } }) do
        local hx, hy, seat = dashboard.unwarp(still, spot[1], spot[2])
        worst_still = math.max(worst_still, math.abs(hx - spot[1]), math.abs(hy - spot[2]), math.abs(seat))
    end
    check("an unspun console is drawn where it is", worst_still < 1e-6, "worst " .. worst_still)
    -- just before half a seat the apex shows this seat's right foot; just
    -- past it, the next seat is in front and the apex shows its left foot
    local apex_y = section.base_y - section.height + 1
    local before = { section = section, chair_offset = 0.5 - 1e-9 }
    local bx, by, bseat = dashboard.unwarp(before, section.center_x, apex_y)
    local after = { section = section, chair_offset = 0.5 + 1e-9 }
    local ax, ay, aseat = dashboard.unwarp(after, section.center_x, apex_y)
    check("half a seat's spin carries the apex to a foot: this seat's right, then the next one's left",
        bseat == 0 and bx > section.center_x + section.width / 2 - 6 and math.abs(by - section.base_y) < 2
            and aseat == 0 and ax < section.center_x - section.width / 2 + 6 and math.abs(ay - section.base_y) < 2,
        bx .. " " .. by .. " / " .. ax .. " " .. ay)

    check("no two buttons, windows or labels shown together overlap", #overlapping == 0,
        table.concat(overlapping, ", "))
end

-- the light dials (issue 213) ------------------------------------------------

do
    local made_by_formula = require("012-made-by-formula")
    local function brightness(material, x, y)
        local r, g, b = made_by_formula.light_at(material, x, y)
        return r + g + b
    end
    local all_ordered = true
    for _, material in ipairs({ "metal", "glaze", "earth" }) do
        -- noon at the top, midnight at the bottom, both looked at from the same reach
        local noon = brightness(material, 0, 0.6)
        local dusk = brightness(material, 0.6, 0)
        local midnight = brightness(material, 0, -0.6)
        all_ordered = all_ordered and noon > dusk and dusk > midnight
    end
    check("every dial is brighter at noon than at dusk, and at dusk than at midnight", all_ordered)
    -- the window's reach: its far edge (center + radius) must stay within the dial
    local renderer = require("013-the-world-renderer")
    local renderer_window = renderer.WINDOW_CENTER + renderer.WINDOW_RADIUS
    check("the light window never reaches past the dial's rim", renderer_window <= 1)

-- the console's metal is lit by a twin of the shaders' dial lookup: at
-- noon its spot matches the painter's formula at the rotated point
do
    local made = require("012-made-by-formula")
    local r1, g1, b1 = made.dial_light("metal", 0, 0.47, 0, 0.52, 0.44)
    local r2, g2, b2 = made.light_at("metal", 0, 0.52 + 0.47 * 0.44)
    check("the console's dial light at noon is the dial straight up",
        math.abs(r1 - r2) + math.abs(g1 - g2) + math.abs(b1 - b2) < 1e-12)
    local nr = made.dial_light("metal", 0, 0.47, math.pi, 0.52, 0.44)
    check("the console's metal is darker at midnight than at noon", nr < r1)
end
end

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
