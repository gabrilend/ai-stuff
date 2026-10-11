-- 016-the-game.lua - the whole program, wired together.
--
-- In plain terms: read the settings; make the shared memory and fill it with
-- units; start the worker threads; lay out the soramech stations (a clock,
-- one move station per unit, a join); then, every frame, let the stations
-- run, draw the world and the dashboard sheet over it, and wait out the rest
-- of the frame to hold the player's framerate cap. On closing, stop the
-- workers and write the goodbye note.
--
-- The soramech wiring of one step:
--
--   [clock] --step number--> [move unit 0] --done--> [join] --> (swap the
--      ^                      [move unit 1] --done-->   |       front and back
--      |                      ...                       |       blocks; apply
--      +------------------------------------------------+       orders)
--
-- The clock fires only when the join has heard "done" from every unit (the
-- join delivers to the clock's one slot). The move stations run in the pool:
-- each step's unit jobs are taken first come, first served by whichever
-- worker is free. The step covers all the time that passed since the last
-- step began, so motion is scaled by time no matter how fast frames come.
--
-- Orders follow the dashboard's rhythm: a map click names a unit, a button
-- click gives it an order. Both are written into shared memory only at the
-- swap, when no worker is writing.

local read_input = require("001-read-the-input")
local say_goodbye = require("002-say-goodbye")
local far_camera = require("003-the-far-camera")
local sphere_fold = require("004-the-sphere-fold")
local records = require("005-unit-records")
local seeding = require("007-seeding-the-units")
local stations = require("008-soramech-stations")
local frame_cap = require("010-the-frame-cap")
local world_renderer = require("013-the-world-renderer")
local dashboard_module = require("014-the-dashboard")
local view_plane = require("015-the-view-plane")

local game = {}

-- What each order verb does to a unit's speeds, as a dispatch table.
-- Advance and fall back move along the tiers; flanks move around the circle.
-- Attack, shield and build are mock-ups for now: the unit stops and the
-- order is recorded on it.
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

-- {{{ local function front_and_back()
-- The two unit blocks as record arrays, front first.
local function front_and_back()
    -- the header says 0: block A is the front
    if game.header[0].front < 0.5 then
        return game.records_a, game.records_b, game.block_a
    end
    -- the header says 1: block B is the front
    return game.records_b, game.records_a, game.block_b
end
-- }}}

-- {{{ local function at_the_swap()
-- The join's work, once every unit's update has arrived: the back block
-- becomes the front, then waiting orders and names are written into it.
local function at_the_swap()
    game.header[0].front = 1 - game.header[0].front
    game.steps_run = game.steps_run + 1
    local front = front_and_back()
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
    -- orders waiting for this swap
    for _, order in ipairs(game.pending_orders) do
        local unit = front[order.unit]
        ORDER_EFFECTS[order.verb](unit)
        unit.order_kind = ORDER_INDEX[order.verb]
    end
    game.pending_orders = {}
end
-- }}}

-- {{{ local function build_stations()
-- Lays out the step's wiring: clock, a move station per unit, join.
local function build_stations()
    local pool = love.thread.getChannel("soramech-pool")
    local map = stations.new_map(pool)
    game.map = map
    game.clock_station = stations.add_station(map, {
        name = "clock", slot_count = 1, where = "here",
        on_ready = function() game.ready_to_step = true end,
    })
    game.first_move_station = #map.stations + 1
    for index = 0, game.unit_count - 1 do
        stations.add_station(map, {
            name = "move unit " .. index, box = "move_unit", slot_count = 1,
            where = "pool", static = index,
        })
    end
    game.join_station = stations.add_station(map, {
        name = "join", slot_count = game.unit_count, where = "here",
        on_ready = function()
            at_the_swap()
            stations.deliver(map, game.clock_station, 1, true)
        end,
    })
    -- the first step may start straight away
    stations.deliver(map, game.clock_station, 1, true)
end
-- }}}

-- {{{ local function start_workers()
local function start_workers()
    local setup = love.thread.getChannel("worker-setup")
    game.workers = {}
    for worker = 1, game.settings.worker_count do
        setup:push({
            game.block_a, game.block_b, game.header_block,
            game.fold.strength, game.fold.tiers_shown, game.fold.hub_radius, game.fold.edge_radius,
            game.first_move_station, game.unit_count,
        })
        local thread = love.thread.newThread("009-soramech-worker.lua")
        thread:start()
        game.workers[worker] = thread
    end
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
    -- Scripted clicks and keys go through the same handlers as real ones.
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
    game.fold = sphere_fold.from_settings(settings)
    game.camera = far_camera.new(settings, width / height)

    -- shared memory: two unit blocks and a header
    game.block_a = love.data.newByteData(records.RECORD_BYTES * game.unit_count)
    game.block_b = love.data.newByteData(records.RECORD_BYTES * game.unit_count)
    game.header_block = love.data.newByteData(records.HEADER_BYTES)
    game.records_a = records.records_at(game.block_a:getFFIPointer())
    game.records_b = records.records_at(game.block_b:getFFIPointer())
    game.header = records.header_at(game.header_block:getFFIPointer())
    seeding.seed_units(game.records_a, game.unit_count, settings.seed, game.fold)
    for index = 0, game.unit_count - 1 do
        records.copy_record(game.records_b[index], game.records_a[index])
    end
    game.header[0].front = 0
    game.header[0].step_seconds = 0
    game.header[0].step_number = 0
    game.header[0].unit_count = game.unit_count

    game.pending_orders = {}
    game.pending_name = nil
    game.named = nil
    game.ready_to_step = false
    game.step_seconds_waiting = 0
    game.steps_run = 0
    game.frames_drawn = 0
    game.seconds_run = 0
    game.calendar_seconds = 0
    game.frame_times = {}
    game.measured_fps = 0
    game.measured_ms = 0

    build_stations()
    start_workers()

    -- the world canvas: drawn to with depth; the screen shows it as is
    game.world_canvas = love.graphics.newCanvas(width, height, { msaa = 4 })
    game.renderer = world_renderer.new(settings, game.camera, game.fold, game.unit_count)
    game.dashboard = dashboard_module.new(width, height, settings.dashboard_radius_fraction)
    game.plane = view_plane.new(game.camera, settings.view_plane_distance, game.dashboard)
end
-- }}}

-- {{{ local function take_done_reports()
-- Hands every "done" the workers have reported to the join station.
local function take_done_reports()
    local done = love.thread.getChannel("soramech-done")
    while true do
        local station_index = done:pop()
        -- nothing more reported this frame
        if station_index == nil then
            return
        end
        -- this unit's slot on the join is its place among the move stations
        stations.deliver(game.map, game.join_station, station_index - game.first_move_station + 1, true)
    end
end
-- }}}

-- {{{ local function start_a_step()
-- The clock's work: write the step's length into the header, then hand
-- every move station its input, which sends its job to the pool.
local function start_a_step()
    game.ready_to_step = false
    game.header[0].step_seconds = game.step_seconds_waiting
    game.header[0].step_number = game.header[0].step_number + 1
    game.step_seconds_waiting = 0
    for index = 0, game.unit_count - 1 do
        stations.deliver(game.map, game.first_move_station + index, 1, game.header[0].step_number)
    end
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

-- {{{ function game.update()
function game.update(seconds)
    game.seconds_run = game.seconds_run + seconds
    game.calendar_seconds = game.calendar_seconds + seconds
    game.step_seconds_waiting = game.step_seconds_waiting + seconds
    measure_frame(seconds)

    take_done_reports()
    -- the clock has fired (every unit reported done): begin the next step
    if game.ready_to_step then
        start_a_step()
    end

    local mouse_x, mouse_y = love.mouse.getPosition()
    dashboard_module.set_pointer(game.dashboard, mouse_x, mouse_y, love.mouse.isDown(1), game.named ~= nil)

    -- scripted clicks and keys whose time has come
    for _, event in ipairs(game.scripted) do
        if not event.done and game.seconds_run >= event.at then
            event.done = true
            -- a click goes where a real click would; a key likewise
            if event.kind == "click" then
                game.mousepressed(event.x, event.y, 1)
            else
                game.keypressed(event.key)
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
    local front = front_and_back()
    local unit = front[game.named]
    return string.format("%s - LEVEL %d", SEAT_NAMES[unit.owner + 1], unit.level)
end
-- }}}

-- {{{ function game.draw()
function game.draw()
    local _, _, front_block = front_and_back()
    local month, weekday, day = calendar_now()

    -- the dashboard's three layers first (they are textures for the sheet)
    dashboard_module.draw(game.dashboard, {
        month = month, weekday = weekday, day = day,
        fps = game.measured_fps, frame_ms = game.measured_ms,
        unit_count = game.unit_count, cap = game.cap,
        named_text = named_text(), someone_named = game.named ~= nil,
        settings_hint = "ESCAPE: SETTINGS",
    }, game.frame_times[#game.frame_times] or 0)

    -- the world, then the sheet in front of it, all in one 3D picture
    love.graphics.push("all")
    love.graphics.setCanvas({ game.world_canvas, depth = true })
    love.graphics.clear({ 0.03, 0.035, 0.045, 1 }, 0, 1)
    world_renderer.draw(game.renderer, front_block, game.FLIP_Y)
    view_plane.draw(game.plane, game.FLIP_Y)
    love.graphics.pop()

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(game.world_canvas)
    game.frames_drawn = game.frames_drawn + 1
end
-- }}}

-- Whether 3D drawing into a canvas must flip its rows. LÖVE stores canvas
-- rows the other way up from the window; drawing through our own projection
-- (which skips LÖVE's) has to account for that itself. Checked by eye in the
-- screenshot: north on the map, and the dashboard's text, must be upright.
game.FLIP_Y = -1

-- {{{ local function nearest_unit_on_screen()
-- The unit whose place on the ground is nearest the pixel, within a reach;
-- -1 if none is close enough (naming empty ground names no one).
local function nearest_unit_on_screen(x, y)
    local front = front_and_back()
    local width, height = love.graphics.getDimensions()
    local best, best_distance = -1, (game.dashboard.radius * 0.12) ^ 2
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
    -- an order: it waits for the swap; the name is spent
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
    -- on the dashboard: only a painted button answers; dials never do
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
    local pool = love.thread.getChannel("soramech-pool")
    for _ = 1, #game.workers do
        pool:push("stop")
    end
    for _, thread in ipairs(game.workers) do
        thread:wait()
        -- a worker that died with an error: say so, loudly
        local thread_error = thread:getError()
        if thread_error ~= nil then
            print("worker error: " .. thread_error)
        end
    end
    local log = io.open(game.project_dir .. "/tmp/shared-memory/run-log", "w")
    log:write(string.format("frames %d steps %d seconds %.2f cap %d last-fps %d tasks %d\n",
        game.frames_drawn, game.steps_run, game.seconds_run, game.cap, game.measured_fps,
        game.map.tasks_sent))
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
