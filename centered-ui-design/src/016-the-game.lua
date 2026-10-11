-- 016-the-game.lua - the whole program, wired together.
--
-- In plain terms: read the settings; make the shared memory and fill it
-- with units and cuboids; start the ceramic engine (soramech's C engine, on
-- its own worker threads); then, every frame, let the engine take the world
-- one step on, draw the world and the console's sheet over it, and wait out
-- the rest of the frame to hold the player's framerate cap. On closing, stop
-- the engine and write the goodbye note.
--
-- This thread (LÖVE's main thread) is the render thread only — the ceramic
-- shape: it never does the world's work. Each frame it asks the engine how
-- far the step in flight has got (023), hands in the next stage when one has
-- wholly landed, and when a step is done swaps the front and back blocks
-- and writes in the frame's orders. It never waits for the workers.
--
-- One step:
--
--   hand in the unit chunks ──▶ (workers: each unit thinks and moves)
--   all landed ──▶ hand in the cuboid chunks ──▶ (workers: cuboids settle)
--   all landed ──▶ swap front and back; write in names and orders; next step
--
-- The step covers all the time since the last step began, so motion is
-- scaled by time however fast frames come.
--
-- Orders follow the console's rhythm: a map click names a unit, a button
-- click gives it an order. Both are written into shared memory only between
-- steps, when no worker is writing.
--
-- The chair: scrolling turns the player's chair about the hub. The world
-- turns with it (the camera's turn) and the row of arches slides (the
-- console's offset), so the player can look along to an ally's quadrant.

local read_input = require("001-read-the-input")
local say_goodbye = require("002-say-goodbye")
local far_camera = require("003-the-far-camera")
local sphere_fold = require("004-the-sphere-fold")
local records = require("005-unit-records")
local seeding = require("007-seeding-the-units")
local frame_cap = require("010-the-frame-cap")
local world_renderer = require("013-the-world-renderer")
local dashboard_module = require("014-the-dashboard")
local view_plane = require("015-the-view-plane")
local ceramic_host = require("023-the-ceramic-host")
local map_from_beyond = require("024-the-map-from-beyond")
local ffi = require("ffi")

local game = {}

local TWO_PI = math.pi * 2

-- What each order verb does to a unit's speeds, as a dispatch table.
-- Advance and fall back move along the tiers; flanks move around the circle.
-- Attack, shield and build are mock-ups for now: the unit stops and the
-- order is recorded on it. Any order also stops it hauling cuboids.
local ORDER_EFFECTS = {
    advance     = function(unit) unit.speed_r = 0.22;  unit.speed_angle = 0 end,
    fall_back   = function(unit) unit.speed_r = -0.22; unit.speed_angle = 0 end,
    flank_left  = function(unit) unit.speed_r = 0;     unit.speed_angle = -0.09 end,
    flank_right = function(unit) unit.speed_r = 0;     unit.speed_angle = 0.09 end,
    hold        = function(unit) unit.speed_r = 0;     unit.speed_angle = 0 end,
    attack      = function(unit) unit.speed_r = 0;     unit.speed_angle = 0 end,
    shield      = function(unit) unit.speed_r = 0;     unit.speed_angle = 0 end,
    build       = function(unit) unit.speed_r = 0;     unit.speed_angle = 0 end,
}
local ORDER_INDEX = { advance = 1, attack = 2, hold = 3, fall_back = 4,
    flank_left = 5, flank_right = 6, shield = 7, build = 8 }

-- What each settings button does to the cap, as a dispatch table.
local CAP_CHANGES = {
    cap_minus_10 = -10, cap_minus_1 = -1, cap_plus_1 = 1, cap_plus_10 = 10,
}

local SEAT_NAMES = { "SEAT 1", "SEAT 2", "SEAT 3", "SEAT 4", "A FOE" }

-- How far one notch of the scroll wheel turns the chair, as a share of one
-- ally's quadrant; and how quickly the chair catches up with where the
-- wheel has left it.
local CHAIR_STEP = 0.125
local CHAIR_EASE = 7

-- {{{ local function blocks()
-- The current front and back blocks: unit arrays, cuboid arrays, and the
-- front byte data (for the graphics card).
local function blocks()
    -- front is A
    if game.front == 0 then
        return game.units_a, game.units_b, game.cubes_a, game.cubes_b, game.unit_block_a, game.cube_block_a
    end
    -- front is B
    return game.units_b, game.units_a, game.cubes_b, game.cubes_a, game.unit_block_b, game.cube_block_b
end
-- }}}

-- {{{ local function between_steps()
-- A step has wholly landed: the back blocks become the front, then waiting
-- names and orders are written into the new front.
local function between_steps()
    game.front = 1 - game.front
    game.steps_run = game.steps_run + 1
    local front = blocks()
    -- a new unit was named: clear the old name, mark the new one
    if game.pending_name ~= nil then
        for index = 0, game.unit_count - 1 do
            front[index].named = 0
        end
        -- naming empty ground (-1) leaves no one named
        if game.pending_name >= 0 then
            front[game.pending_name].named = 1
        end
        game.named = game.pending_name >= 0 and game.pending_name or nil
        game.pending_name = nil
    end
    -- orders waiting for this moment
    for _, order in ipairs(game.pending_orders) do
        local unit = front[order.unit]
        ORDER_EFFECTS[order.verb](unit)
        unit.order_kind = ORDER_INDEX[order.verb]
    end
    game.pending_orders = {}
end
-- }}}

-- {{{ local function point_engine_at_blocks()
-- Tells the engine which blocks are front and back for the step about to go in.
local function point_engine_at_blocks()
    local units_front, units_back, cubes_front, cubes_back = blocks()
    game.engine.library.ceramics_set_world(units_front, units_back, cubes_front, cubes_back)
end
-- }}}

-- {{{ function game.load()
function game.load(arguments)
    game.project_dir = arguments[1]
    -- no project folder given: the run script always passes one
    if game.project_dir == nil then
        error("the game needs the project folder as its first argument (use the run script)", 0)
    end
    -- the first thing: read input/
    game.settings = read_input.read(game.project_dir)
    local tiers = dofile("/mnt/mtwo/programming/ai-stuff/scripts/libs/ensure-ram-tiers.lua")
    tiers.ensure(game.project_dir)

    -- Options for checking the game without a person at the mouse:
    --   --screenshot SECONDS   save a picture of the window then close
    --   --click SECONDS X Y    click the main button at pixel X, Y
    --   --key SECONDS NAME     press a key
    --   --wheel SECONDS NOTCHES  turn the scroll wheel
    -- Scripted input goes through the same handlers as real input.
    game.scripted = {}
    for index = 2, #arguments do
        local option = arguments[index]
        -- a picture at a given time
        if option == "--screenshot" then
            game.screenshot_after = tonumber(arguments[index + 1])
        elseif option == "--click" then
            -- a click at a given time and place
            game.scripted[#game.scripted + 1] = { at = tonumber(arguments[index + 1]), kind = "click",
                x = tonumber(arguments[index + 2]), y = tonumber(arguments[index + 3]) }
        elseif option == "--key" then
            -- a key press at a given time
            game.scripted[#game.scripted + 1] = { at = tonumber(arguments[index + 1]), kind = "key",
                key = arguments[index + 2] }
        elseif option == "--wheel" then
            -- a turn of the wheel at a given time
            game.scripted[#game.scripted + 1] = { at = tonumber(arguments[index + 1]), kind = "wheel",
                notches = tonumber(arguments[index + 2]) }
        end
    end

    local settings = game.settings
    love.window.setMode(settings.window_width, settings.window_height, {
        vsync = 0, resizable = false, highdpi = false, msaa = 4, depth = 24,
    })
    love.window.setTitle("centered-ui-design")
    local width, height = love.graphics.getDimensions()

    game.cap = settings.max_framerate
    game.unit_count = settings.unit_count
    game.cuboid_count = settings.cuboid_count
    game.fold = sphere_fold.from_settings(settings)
    game.camera = far_camera.new(settings, width / height)

    -- shared memory: two blocks of units and two of cuboids
    game.unit_block_a = love.data.newByteData(records.RECORD_BYTES * game.unit_count)
    game.unit_block_b = love.data.newByteData(records.RECORD_BYTES * game.unit_count)
    game.cube_block_a = love.data.newByteData(records.CUBOID_BYTES * game.cuboid_count)
    game.cube_block_b = love.data.newByteData(records.CUBOID_BYTES * game.cuboid_count)
    game.units_a = records.records_at(game.unit_block_a:getFFIPointer())
    game.units_b = records.records_at(game.unit_block_b:getFFIPointer())
    game.cubes_a = records.cuboids_at(game.cube_block_a:getFFIPointer())
    game.cubes_b = records.cuboids_at(game.cube_block_b:getFFIPointer())
    seeding.seed_units(game.units_a, game.unit_count, settings.seed, game.fold)
    seeding.seed_cuboids(game.cubes_a, game.cuboid_count, settings.seed, game.fold)
    -- the back blocks start as copies of the front
    ffi.copy(game.units_b, game.units_a, records.RECORD_BYTES * game.unit_count)
    ffi.copy(game.cubes_b, game.cubes_a, records.CUBOID_BYTES * game.cuboid_count)
    game.front = 0

    game.pending_orders = {}
    game.pending_name = nil
    game.named = nil
    game.step_seconds_waiting = 0
    game.steps_run = 0
    game.frames_drawn = 0
    game.seconds_run = 0
    game.calendar_seconds = 0
    game.frame_times = {}
    game.measured_fps = 0
    game.measured_ms = 0

    -- the chair: facing the middle of this player's own quadrant
    game.quadrant = TWO_PI / settings.team_size
    game.home_turn = (settings.seat - 0.5) * game.quadrant
    game.chair = game.home_turn
    game.chair_target = game.home_turn
    game.camera.turn = game.chair

    -- the world's engine
    game.engine = ceramic_host.start(ceramic_host.load(game.project_dir), {
        fold = game.fold,
        figure_scale = world_renderer.UNIT_WORLD_SCALE,
        sections = seeding.SECTIONS,
        workers = settings.worker_count,
        unit_count = game.unit_count,
        cuboid_count = game.cuboid_count,
        seed = settings.seed,
    })

    -- the world canvas: drawn to with depth; the screen shows it as is
    game.world_canvas = love.graphics.newCanvas(width, height, { msaa = 4 })
    game.renderer = world_renderer.new(settings, game.camera, game.fold, game.unit_count,
        game.cuboid_count, seeding.SECTIONS)
    game.beyond = map_from_beyond.new(1024, game.renderer.flat_map)
    game.dashboard = dashboard_module.new(width, height, settings.team_size, settings.seat)
    game.plane = view_plane.new(game.camera, settings.view_plane_distance, game.dashboard)
end
-- }}}

-- {{{ local function measure_frame()
-- Keeps half a second of frame times and works out frames per second and
-- milliseconds per frame from them.
local function measure_frame(seconds)
    local times = game.frame_times
    times[#times + 1] = seconds
    local total = 0
    for index = 1, #times do
        total = total + times[index]
    end
    -- more than half a second kept: drop the oldest
    while total > 0.5 and #times > 1 do
        total = total - table.remove(times, 1)
    end
    game.measured_fps = math.floor(#times / total + 0.5)
    game.measured_ms = 1000 * total / #times
end
-- }}}

-- {{{ local function calendar_now()
-- The game calendar: day 0 is Saturday 10 October; one day per
-- calendar_seconds_per_day seconds. Returns month (1-12), weekday (1-7,
-- Monday first), day of month (1-31).
local function calendar_now()
    local days = math.floor(game.calendar_seconds / game.settings.calendar_seconds_per_day)
    local month = 10
    local day = 10 + days
    -- walk forward through the months until the day fits in its month
    while day > dashboard_module.MONTH_DAYS[month] do
        day = day - dashboard_module.MONTH_DAYS[month]
        month = month % 12 + 1
    end
    local weekday = (5 + days) % 7 + 1  -- 10 October 2026 is a Saturday (6)
    return month, weekday, day
end
-- }}}

-- {{{ local function turn_chair()
-- Eases the chair toward where the wheel left it, and moves everything that
-- follows the chair: the world's turn, the console's row of arches.
local function turn_chair(seconds)
    game.chair = game.chair + (game.chair_target - game.chair) * (1 - math.exp(-seconds * CHAIR_EASE))
    game.camera.turn = game.chair
    dashboard_module.set_chair(game.dashboard, (game.chair - game.home_turn) / game.quadrant)
end
-- }}}

-- {{{ function game.update()
function game.update(seconds)
    game.seconds_run = game.seconds_run + seconds
    game.calendar_seconds = game.calendar_seconds + seconds
    game.step_seconds_waiting = game.step_seconds_waiting + seconds
    measure_frame(seconds)

    -- The engine: look a few times this frame, never waiting — a stage that
    -- lands while we look lets the next go in at once, instead of a frame
    -- later. Stop looking as soon as a look changes nothing.
    for _ = 1, 4 do
        local finished, began = ceramic_host.advance(game.engine, game.step_seconds_waiting, point_engine_at_blocks)
        -- a step has begun: the time waiting is now in flight
        if began then
            game.step_seconds_waiting = 0
        end
        -- a step has finished: swap and write in orders (the next look begins one)
        if finished then
            between_steps()
        end
        -- nothing happened on this look: the workers are still at it
        if not finished and not began and not game.engine.just_handed_in then
            break
        end
    end

    turn_chair(seconds)
    local mouse_x, mouse_y = love.mouse.getPosition()
    dashboard_module.set_pointer(game.dashboard, mouse_x, mouse_y, love.mouse.isDown(1), game.named ~= nil)

    -- scripted input whose time has come
    for _, event in ipairs(game.scripted) do
        if not event.done and game.seconds_run >= event.at then
            event.done = true
            -- a click, a key, or the wheel, each where real input would go
            if event.kind == "click" then
                game.mousepressed(event.x, event.y, 1)
            elseif event.kind == "key" then
                game.keypressed(event.key)
            else
                game.wheelmoved(0, event.notches)
            end
        end
    end

    -- screenshot mode: when the time comes, save the window and close
    if game.screenshot_after ~= nil and game.seconds_run >= game.screenshot_after then
        game.screenshot_after = nil
        love.graphics.captureScreenshot(function(image)
            local path = game.project_dir .. "/tmp/shared-memory/screenshot.png"
            local file = io.open(path, "wb")
            file:write(image:encode("png"):getString())
            file:close()
            love.event.quit()
        end)
    end
end
-- }}}

-- {{{ local function named_text()
local function named_text()
    -- no one named: say how to name someone
    if game.named == nil then
        return "CLICK A UNIT"
    end
    local front = blocks()
    local unit = front[game.named]
    return string.format("%s - LEVEL %d", SEAT_NAMES[unit.owner + 1], unit.level)
end
-- }}}

-- {{{ local function delivered_counts()
-- How many cuboids rest in each color's section now.
local function delivered_counts()
    local _, _, cubes = blocks()
    local counts = { 0, 0, 0, 0 }
    for index = 0, game.cuboid_count - 1 do
        local cuboid = cubes[index]
        if cuboid.state == records.CUBE_DELIVERED then
            counts[cuboid.color + 1] = counts[cuboid.color + 1] + 1
        end
    end
    return counts
end
-- }}}

-- {{{ function game.draw()
function game.draw()
    local units, _, cubes, _, unit_block, cube_block = blocks()
    local month, weekday, day = calendar_now()

    -- the map from beyond, then the console's layers (textures for the sheet)
    map_from_beyond.draw(game.beyond, units, game.unit_count, cubes, game.cuboid_count,
        game.fold.tiers_shown, world_renderer.OWNER_COLORS)
    dashboard_module.draw(game.dashboard, {
        month = month, weekday = weekday, day = day,
        fps = game.measured_fps, frame_ms = game.measured_ms,
        unit_count = game.unit_count, cap = game.cap,
        named_text = named_text(), someone_named = game.named ~= nil,
        seat_colors = world_renderer.OWNER_COLORS,
        delivered = delivered_counts(),
    }, game.frame_times[#game.frame_times] or 0)

    -- the world, in its own picture with depth
    love.graphics.push("all")
    love.graphics.setCanvas({ game.world_canvas, depth = true })
    love.graphics.clear({ 0.03, 0.035, 0.045, 1 }, 0, 1)
    world_renderer.draw(game.renderer, unit_block, cube_block, game.FLIP_Y_IN_CANVAS)
    love.graphics.pop()

    -- then the world on screen, and the console's sheet in front of it
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(game.world_canvas)
    view_plane.draw(game.plane, game.FLIP_Y_ON_SCREEN, game.beyond.canvas)
    game.frames_drawn = game.frames_drawn + 1
end
-- }}}

-- Whether 3D drawing must flip its rows. LÖVE stores canvas rows the other
-- way up from the window; drawing through our own projection (which skips
-- LÖVE's) has to account for that itself, differently for a canvas and for
-- the window. Checked by eye in the screenshot: north on the map, and the
-- console's text, must be upright.
game.FLIP_Y_IN_CANVAS = -1
game.FLIP_Y_ON_SCREEN = 1

-- {{{ local function nearest_unit_on_screen()
-- The unit whose place on the ground is nearest the pixel, within a reach;
-- -1 if none is close enough (naming empty ground names no one).
local function nearest_unit_on_screen(x, y)
    local front = blocks()
    local width, height = love.graphics.getDimensions()
    local best, best_distance = -1, (game.dashboard.section.height * 0.05) ^ 2
    for index = 0, game.unit_count - 1 do
        local unit = front[index]
        local ground_x, ground_z = sphere_fold.ground_position(game.fold, unit.r, unit.angle)
        local ndc_x, ndc_y = far_camera.project(game.camera, ground_x, 0, ground_z)
        local px, py = far_camera.ndc_to_pixels(ndc_x, ndc_y, width, height)
        local distance = (px - x) ^ 2 + (py - y) ^ 2
        if distance < best_distance then
            best, best_distance = index, distance
        end
    end
    return best
end
-- }}}

-- {{{ local function press_button()
-- What a button press means: a settings change, or an order for the named unit.
local function press_button(verb)
    -- a framerate cap change
    if CAP_CHANGES[verb] ~= nil then
        game.cap = frame_cap.clamp_cap(game.cap + CAP_CHANGES[verb])
        return
    end
    -- closing the settings menu
    if verb == "close_settings" then
        game.dashboard.settings_open = false
        return
    end
    -- quitting
    if verb == "quit" then
        love.event.quit()
        return
    end
    -- an order with no one named: remind, and do nothing else
    if game.named == nil then
        dashboard_module.flash_name_someone(game.dashboard)
        return
    end
    -- an order: it waits for the step to end; the name is spent
    game.pending_orders[#game.pending_orders + 1] = { unit = game.named, verb = verb }
    game.pending_name = -1
end
-- }}}

-- {{{ function game.mousepressed()
function game.mousepressed(x, y, button)
    -- only the main button does anything
    if button ~= 1 then
        return
    end
    -- on the console: only a painted button answers; dials and bands never do
    if dashboard_module.covers(game.dashboard, x, y) then
        local verb = dashboard_module.button_under(game.dashboard, x, y, game.named ~= nil)
        if verb ~= nil then
            press_button(verb)
        end
        return
    end
    -- on the map, with the settings menu shut: name whoever is there
    if not game.dashboard.settings_open then
        game.pending_name = nearest_unit_on_screen(x, y)
    end
end
-- }}}

-- {{{ function game.wheelmoved()
-- The scroll wheel turns the chair (one notch, an eighth of a quadrant).
-- Rolling away from you turns you clockwise, toward the next seat.
function game.wheelmoved(_, notches)
    game.chair_target = game.chair_target - notches * CHAIR_STEP * game.quadrant
end
-- }}}

-- {{{ function game.keypressed()
function game.keypressed(key)
    -- Escape opens or shuts the settings menu
    if key == "escape" then
        game.dashboard.settings_open = not game.dashboard.settings_open
    end
end
-- }}}

-- {{{ function game.quit()
function game.quit()
    ceramic_host.stop(game.engine)
    local log = io.open(game.project_dir .. "/tmp/shared-memory/run-log", "w")
    local delivered = delivered_counts()
    log:write(string.format("frames %d steps %d seconds %.2f cap %d last-fps %d delivered %d %d %d %d\n",
        game.frames_drawn, game.steps_run, game.seconds_run, game.cap, game.measured_fps,
        delivered[1], delivered[2], delivered[3], delivered[4]))
    -- what the haulers and cuboids are doing at the end, by kind
    local units, _, cubes = blocks()
    local jobs, states = { [0] = 0, 0, 0 }, { [0] = 0, 0, 0 }
    for index = 0, game.unit_count - 1 do
        jobs[units[index].job] = jobs[units[index].job] + 1
    end
    for index = 0, game.cuboid_count - 1 do
        states[cubes[index].state] = states[cubes[index].state] + 1
    end
    log:write(string.format("units idle %d fetching %d carrying %d; cuboids lying %d carried %d delivered %d\n",
        jobs[0], jobs[1], jobs[2], states[0], states[1], states[2]))
    log:close()
    -- the last thing: goodbye
    say_goodbye.write(game.project_dir, {
        seed = game.settings.seed, frames_drawn = game.frames_drawn,
        steps_run = game.steps_run, seconds_run = game.seconds_run,
    })
    return false
end
-- }}}

-- {{{ function game.run()
-- LÖVE's frame loop, replaced so the framerate cap is held exactly: handle
-- events, update with the real time passed, draw, show, then wait out the
-- rest of this frame's slot (if there is a cap).
function game.run()
    game.load(love.arg.parseGameArguments(arg))
    love.timer.step()
    local deadline = love.timer.getTime()
    return function()
        love.event.pump()
        for name, a, b, c, d, e, f in love.event.poll() do
            -- the window is closing: finish and leave
            if name == "quit" then
                game.quit()
                return 0
            end
            love.handlers[name](a, b, c, d, e, f)
        end
        local seconds = love.timer.step()
        game.update(seconds)
        love.graphics.origin()
        love.graphics.clear(0, 0, 0, 1)
        game.draw()
        love.graphics.present()

        local budget = frame_cap.frame_budget(game.cap)
        -- a cap is set: wait for this frame's slot to end
        if budget ~= nil then
            deadline = frame_cap.next_deadline(deadline, budget, love.timer.getTime())
            frame_cap.wait_until(deadline, love.timer.getTime, love.timer.sleep)
        else
            -- no cap: keep the schedule at now, so a new cap starts cleanly
            deadline = love.timer.getTime()
        end
    end
end
-- }}}

return game
