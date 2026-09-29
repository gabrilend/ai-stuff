-- main.lua - The gif viewer's window: watch a folder of gifs, one at a time
-- or all at once.
--
-- In general terms: opens a black window on a folder of gifs and plays them.
-- Left and right (or space) step through them; g flips to a grid where every
-- gif plays at once in miniature; esc or q closes it. The unpacking of the
-- gifs happens on background workers (decode-worker.lua), so the window
-- never freezes while thirty files are being read.
--
-- Keys:
--   single view:  ←/→ previous/next   space next   g grid   esc/q quit
--   grid view:    arrows move the highlight   space next   enter or click
--                 opens it   g back to single view   esc/q quit
--
-- Memory: full-size frames are kept for only a few gifs at once (the one on
-- screen and its neighbours; the least recently seen is dropped). The grid
-- uses small copies, every second frame, made once and kept for the session.
--
-- Arguments (after the viewer folder): an optional gif folder, and
-- --selftest, which loads everything, prints what it found, and quits --
-- used by test-gif-viewer.sh to prove the window runs.

local DEFAULT_FOLDER = "/home/ritz/pictures/shape-gifs"
local THUMB_SIZE = 128        -- grid copies are shrunk to fit this square
local THUMB_FRAME_STEP = 2    -- and keep every second frame
local FULL_KEPT = 5           -- gifs held at full size at once
local UPLOAD_BUDGET = 48      -- decoded frames turned into textures per tick
local GRID_CELL = 170         -- target grid cell width, in pixels
local FOOTER = 56             -- room kept below the picture for its name
local SELFTEST_TIMEOUT = 90   -- seconds

local HIGHLIGHT = { 1.0, 0.85, 0.2 }   -- the house yellow
local QUIET = { 0.55, 0.55, 0.6 }

local state = {
    folder = DEFAULT_FOLDER,
    entries = {},       -- { name, path, full = slot, thumb = slot }
    mode = "single",
    current = 1,
    selected = 1,
    grid_scroll = 0,    -- first visible grid row
    clock = 0,
    generation = 0,
    seen_counter = 0,
    selftest = false,
    workers = {},
}

local channels = {}
local fonts = {}

-- {{{ Folder

-- {{{ local function list_gifs()
-- Every .gif directly in the folder, sorted by name. The folder is outside
-- LÖVE's own sandbox, so it is listed with ls rather than love.filesystem.
local function list_gifs(folder)
    local pipe = io.popen("ls -1 '" .. folder:gsub("'", "'\\''") .. "' 2>&1")
    local names = {}
    for line in pipe:lines() do
        if line:lower():match("%.gif$") then names[#names + 1] = line end
    end
    pipe:close()
    table.sort(names)
    return names
end
-- }}}

-- }}}

-- {{{ Decoding requests and replies

-- {{{ local function request()
-- Asks the workers for one gif at one size, unless it is already held or on
-- its way. Each request gets a fresh generation number, so replies for a slot
-- that was dropped in the meantime are recognised and thrown away.
local function request(index, kind, urgent)
    local entry = state.entries[index]
    if entry[kind] then return end
    state.generation = state.generation + 1
    entry[kind] = { frames = {}, delays = {}, total_cs = 0, done = false,
                    generation = state.generation, last_seen = 0 }
    local message = { id = index, path = entry.path, kind = kind, generation = state.generation,
                      max_size = kind == "thumb" and THUMB_SIZE or nil,
                      frame_step = kind == "thumb" and THUMB_FRAME_STEP or 1 }
    ;(urgent and channels.urgent or channels.background):push(message)
end
-- }}}

-- {{{ local function drop()
-- Lets go of a slot's textures, returning their memory straight away.
local function drop(entry, kind)
    local slot = entry[kind]
    if not slot then return end
    for _, image in pairs(slot.frames) do image:release() end
    entry[kind] = nil
end
-- }}}

-- {{{ local function keep_full_sizes_few()
-- Full-size frames cost about 400 KB each; a whole gif, tens of megabytes.
-- Only the FULL_KEPT most recently seen are held; the oldest others go.
-- A gif still being decoded is never dropped half-way, since its frames are
-- arriving and would only be requested again.
local function keep_full_sizes_few()
    local held = {}
    for index, entry in ipairs(state.entries) do
        if entry.full then held[#held + 1] = { index = index, slot = entry.full } end
    end
    if #held <= FULL_KEPT then return end
    table.sort(held, function(a, b) return a.slot.last_seen < b.slot.last_seen end)
    for i = 1, #held - FULL_KEPT do
        local candidate = held[i]
        if candidate.index ~= state.current and candidate.slot.done then
            drop(state.entries[candidate.index], "full")
        end
    end
end
-- }}}

-- {{{ local function look_at()
-- Makes a gif the one on screen: its full size first and urgently, then its
-- neighbours in the background so stepping to them is instant.
local function look_at(index)
    local count = #state.entries
    state.current = ((index - 1) % count) + 1
    request(state.current, "full", true)
    request(state.current % count + 1, "full", false)
    request((state.current - 2) % count + 1, "full", false)
    state.seen_counter = state.seen_counter + 1
    state.entries[state.current].full.last_seen = state.seen_counter
    keep_full_sizes_few()
end
-- }}}

-- {{{ local function receive()
-- Takes finished frames from the workers and turns them into textures, a
-- limited number per tick so a burst of arrivals never stutters the window.
local function receive()
    for _ = 1, UPLOAD_BUDGET do
        local message = channels.results:pop()
        if not message then return end
        local entry = state.entries[message.id]
        local slot = entry and entry[message.kind]
        if not slot or slot.generation ~= message.generation then
            -- a reply for something since dropped
            if message.image then message.image:release() end
        elseif message.failed then
            slot.failed = message.failed
            slot.done = true
            io.stderr:write("gif-viewer: " .. entry.name .. ": " .. message.failed .. "\n")
        elseif message.done then
            slot.done = true
            slot.count = message.count
        else
            local image = love.graphics.newImage(message.image)
            image:setFilter("nearest", "nearest")
            message.image:release()
            slot.frames[message.index] = image
            slot.delays[message.index] = message.delay_cs
            slot.total_cs = slot.total_cs + message.delay_cs
        end
    end
end
-- }}}

-- }}}

-- {{{ Playback

-- {{{ local function frame_now()
-- The frame a slot should show at the shared clock. Every gif runs on the
-- same clock, so the grid's copies keep time with each other. Three paths:
-- nothing arrived yet (nil), still arriving (the newest frame, so the gif
-- appears as it loads), complete (by its own delays, looping).
local function frame_now(slot)
    if not slot or #slot.frames == 0 then return nil end
    if not slot.done or slot.total_cs == 0 then return slot.frames[#slot.frames] end
    local at = (state.clock * 100) % slot.total_cs
    for i = 1, #slot.frames do
        at = at - slot.delays[i]
        if at < 0 then return slot.frames[i] end
    end
    return slot.frames[#slot.frames]
end
-- }}}

-- {{{ local function draw_fitted()
-- Draws a picture as large as fits the box, centred. Whole-number scales
-- when enlarging keep every pixel square and crisp.
local function draw_fitted(image, x, y, box_width, box_height)
    local width, height = image:getDimensions()
    local scale = math.min(box_width / width, box_height / height)
    if scale >= 1 then scale = math.floor(scale) end
    love.graphics.draw(image, x + (box_width - width * scale) / 2,
                       y + (box_height - height * scale) / 2, 0, scale, scale)
end
-- }}}

-- }}}

-- {{{ Grid layout

-- {{{ local function grid_shape()
local function grid_shape()
    local width, height = love.graphics.getDimensions()
    local columns = math.max(1, math.floor(width / GRID_CELL))
    local cell = width / columns
    local visible_rows = math.max(1, math.floor((height - FOOTER) / cell))
    return columns, cell, visible_rows
end
-- }}}

-- {{{ local function keep_selection_visible()
local function keep_selection_visible()
    local columns, _, visible_rows = grid_shape()
    local row = math.floor((state.selected - 1) / columns)
    if row < state.grid_scroll then state.grid_scroll = row end
    if row >= state.grid_scroll + visible_rows then state.grid_scroll = row - visible_rows + 1 end
end
-- }}}

-- {{{ local function move_selection()
local function move_selection(step)
    local count = #state.entries
    state.selected = ((state.selected - 1 + step) % count) + 1
    keep_selection_visible()
end
-- }}}

-- }}}

-- {{{ Keys
-- One table per view; a key missing from a view's table does nothing there.

local function quit() love.event.quit() end

-- {{{ local function toggle_grid()
local function toggle_grid()
    if state.mode == "single" then
        state.mode = "grid"
        state.selected = state.current
        keep_selection_visible()
    else
        state.mode = "single"
        look_at(state.selected)
    end
end
-- }}}

-- {{{ local function open_selected()
local function open_selected()
    state.mode = "single"
    look_at(state.selected)
end
-- }}}

local keys = {
    single = {
        left = function() look_at(state.current - 1) end,
        right = function() look_at(state.current + 1) end,
        space = function() look_at(state.current + 1) end,
        g = toggle_grid, escape = quit, q = quit,
    },
    grid = {
        left = function() move_selection(-1) end,
        right = function() move_selection(1) end,
        space = function() move_selection(1) end,
        up = function() move_selection(-(grid_shape())) end,
        down = function() move_selection(grid_shape()) end,
        ["return"] = open_selected, kpenter = open_selected,
        g = toggle_grid, escape = quit, q = quit,
    },
}

-- }}}

-- {{{ LÖVE callbacks

-- {{{ function love.load()
function love.load(args)
    for _, argument in ipairs(args) do
        local screenshots = argument:match("^%-%-screenshots=(.+)$")
        if argument == "--selftest" then
            state.selftest = true
        elseif screenshots then
            state.screenshots = screenshots
        else
            state.folder = argument
        end
    end

    for _, name in ipairs(list_gifs(state.folder)) do
        state.entries[#state.entries + 1] = { name = name, path = state.folder .. "/" .. name }
    end
    if #state.entries == 0 then
        error("no .gif files in " .. state.folder, 0)
    end

    love.graphics.setBackgroundColor(0, 0, 0)
    fonts.name = love.graphics.newFont(18)
    fonts.hint = love.graphics.newFont(13)

    channels.urgent = love.thread.getChannel("gif-viewer-urgent")
    channels.background = love.thread.getChannel("gif-viewer-background")
    channels.results = love.thread.getChannel("gif-viewer-results")
    channels.control = love.thread.getChannel("gif-viewer-control")
    channels.control:clear()

    -- One worker per core but one: the window keeps a core to itself.
    local viewer_dir = love.filesystem.getSource()
    local worker_count = math.max(1, love.system.getProcessorCount() - 1)
    for i = 1, worker_count do
        local worker = love.thread.newThread("decode-worker.lua")
        worker:start(viewer_dir)
        state.workers[i] = worker
    end

    look_at(1)
    for index = 1, #state.entries do request(index, "thumb", false) end
end
-- }}}

-- {{{ function love.update()
function love.update(dt)
    state.clock = state.clock + dt
    receive()
    for _, worker in ipairs(state.workers) do
        local failure = worker:getError()
        if failure then error("a decode worker failed: " .. failure, 0) end
    end

    if state.selftest then
        local thumbs_done, frames = 0, 0
        for _, entry in ipairs(state.entries) do
            if entry.thumb and entry.thumb.done then
                thumbs_done = thumbs_done + 1
                if entry.thumb.failed then
                    print("selftest: FAILED " .. entry.name .. ": " .. entry.thumb.failed)
                    love.event.quit(1)
                end
            end
        end
        local current = state.entries[state.current].full
        if thumbs_done == #state.entries and current and current.done then
            -- Three steps once everything is loaded: capture the single view,
            -- flip to the grid and capture it, then report and quit. Captures
            -- go to --screenshots=<folder> when given, so a person (or a test)
            -- can look at what was actually drawn.
            local stage = state.selftest_stage or "single"
            if stage == "single" then
                if state.screenshots then
                    love.graphics.captureScreenshot(function(picture)
                        local handle = assert(io.open(state.screenshots .. "/single.png", "wb"))
                        handle:write(picture:encode("png"):getString())
                        handle:close()
                    end)
                end
                state.selftest_stage = "grid"
            elseif stage == "grid" then
                state.mode = "grid"
                state.selftest_stage = "grid-capture"
            elseif stage == "grid-capture" then
                if state.screenshots then
                    love.graphics.captureScreenshot(function(picture)
                        local handle = assert(io.open(state.screenshots .. "/grid.png", "wb"))
                        handle:write(picture:encode("png"):getString())
                        handle:close()
                    end)
                end
                state.selftest_stage = "report"
            else
                for _, entry in ipairs(state.entries) do frames = frames + #entry.thumb.frames end
                print(string.format("selftest: %d gifs, %d grid frames, first gif %d full frames",
                    #state.entries, frames, #current.frames))
                love.event.quit(0)
            end
        elseif state.clock > SELFTEST_TIMEOUT then
            print("selftest: timed out")
            love.event.quit(1)
        end
    end
end
-- }}}

-- {{{ local function draw_single()
local function draw_single()
    local width, height = love.graphics.getDimensions()
    local entry = state.entries[state.current]
    local slot = entry.full
    local frame = frame_now(slot)
    love.graphics.setColor(1, 1, 1)
    if frame then
        draw_fitted(frame, 0, 0, width, height - FOOTER)
    end
    if slot and slot.failed then
        love.graphics.setColor(1, 0.35, 0.35)
        love.graphics.setFont(fonts.name)
        love.graphics.printf("could not read: " .. slot.failed, 20, height / 2, width - 40, "center")
    elseif not frame or not slot.done then
        love.graphics.setColor(QUIET)
        love.graphics.setFont(fonts.hint)
        love.graphics.printf(string.format("decoding… %d frames", slot and #slot.frames or 0),
            0, height - FOOTER - 20, width, "center")
    end

    love.graphics.setFont(fonts.name)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(string.format("%d / %d   %s", state.current, #state.entries,
        entry.name:gsub("%.gif$", "")), 0, height - FOOTER + 6, width, "center")
    love.graphics.setFont(fonts.hint)
    love.graphics.setColor(QUIET)
    -- words, not arrow symbols: LÖVE's built-in font has no arrow glyphs
    love.graphics.printf("left / right  step    space  next    g  grid    q  quit",
        0, height - FOOTER + 32, width, "center")
end
-- }}}

-- {{{ local function draw_grid()
local function draw_grid()
    local width, height = love.graphics.getDimensions()
    local columns, cell, visible_rows = grid_shape()
    local pad = 8
    for index, entry in ipairs(state.entries) do
        local position = index - 1
        local row = math.floor(position / columns) - state.grid_scroll
        if row >= 0 and row < visible_rows + 1 then
            local x = (position % columns) * cell
            local y = row * cell
            local frame = frame_now(entry.thumb)
            love.graphics.setColor(1, 1, 1)
            if frame then
                draw_fitted(frame, x + pad, y + pad, cell - 2 * pad, cell - 2 * pad)
            else
                love.graphics.setColor(QUIET)
                love.graphics.setFont(fonts.hint)
                love.graphics.printf("…", x, y + cell / 2 - 8, cell, "center")
            end
            if index == state.selected then
                love.graphics.setColor(HIGHLIGHT)
                love.graphics.setLineWidth(3)
                love.graphics.rectangle("line", x + 3, y + 3, cell - 6, cell - 6, 6, 6)
            end
        end
    end

    -- the footer sits over any partly visible last row
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("fill", 0, height - FOOTER, width, FOOTER)
    local entry = state.entries[state.selected]
    love.graphics.setFont(fonts.name)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(string.format("%d / %d   %s", state.selected, #state.entries,
        entry.name:gsub("%.gif$", "")), 0, height - FOOTER + 6, width, "center")
    love.graphics.setFont(fonts.hint)
    love.graphics.setColor(QUIET)
    love.graphics.printf("arrows  move    enter  open    g  back    q  quit",
        0, height - FOOTER + 32, width, "center")
end
-- }}}

-- {{{ function love.draw()
function love.draw()
    if state.mode == "grid" then draw_grid() else draw_single() end
end
-- }}}

-- {{{ function love.keypressed()
function love.keypressed(key)
    local handler = keys[state.mode][key]
    if handler then handler() end
end
-- }}}

-- {{{ function love.mousepressed()
-- In the grid, a click opens the gif under the pointer.
function love.mousepressed(x, y, button)
    if state.mode ~= "grid" or button ~= 1 then return end
    local columns, cell = grid_shape()
    local column = math.floor(x / cell)
    local row = math.floor(y / cell) + state.grid_scroll
    local index = row * columns + column + 1
    if column < columns and index >= 1 and index <= #state.entries then
        state.selected = index
        open_selected()
    end
end
-- }}}

-- {{{ function love.wheelmoved()
function love.wheelmoved(_, y)
    if state.mode ~= "grid" then return end
    local columns = grid_shape()
    move_selection(-y * columns)
end
-- }}}

-- {{{ function love.resize()
function love.resize()
    if state.mode == "grid" then keep_selection_visible() end
end
-- }}}

-- {{{ function love.quit()
function love.quit()
    channels.control:push("stop")
    return false
end
-- }}}

-- }}}
