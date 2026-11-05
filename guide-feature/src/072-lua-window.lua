#!/usr/bin/env luajit
-- 072-lua-window.lua - the canvas, drawn as a picture, for a desktop window.
--
-- In plain terms: the recommended viewer (issue 802). It draws the canvas in
-- a monospace font at its exact size, each marked cell with its voice's
-- colour behind it, fading as the mark ages; a `word` mark stronger than a
-- `sentence` mark. When a new version arrives, each changed run of cells is
-- written over what was in that slot, left to right, over a fraction of a
-- second, so the eye catches each change.
--
-- WHAT IS BUILT AND WHAT IS NOT. Everything but the window itself. The owner
-- said no to raylib, and no SDL or LÖVE is kept in the monorepo to copy, so
-- this draws into its own picture (pixels in memory) and has one backend,
-- `headless`, which shows no window: it saves the picture when asked (a
-- screenshot, a PNG and a text grid of the same frame). A window backend
-- needs only to show that picture each frame and pass on key presses; what
-- it needs on kuvalu is in issues/completed/802-the-lua-window.md. The
-- letters are the monorepo's own 8x8 pictures (libs/bitmap-font.lua, from
-- every-software-image-able), so no font library is needed either.
--
--   scripts/lua-window [ROOT] [OPTIONS]    run it, then file its screenshots
--   luajit src/072-lua-window.lua --dir ROOT [--replay FOLDER]
--       [--screenshot SECONDS]... [--key SECONDS NAME]... [--for SECONDS]
--       [--fast] [--file-screenshots [MADE-BY]]
--     --replay FOLDER      draw every version in a history folder, in order,
--                          one each replay-every seconds, then stop
--                          (canvas/history, or any folder of canvas files)
--     --screenshot SECONDS save the frame shown at that time in the run
--     --key SECONDS NAME   press a key at that time: q or escape stops,
--                          space pauses or resumes a replay, s screenshots
--     --for SECONDS        stop after this long
--     --fast               run on a pretend clock: no waiting, the same frames
--     --file-screenshots   file the screenshots waiting in
--                          tmp/shared-memory/lua-window/screenshots/ into
--                          development-history/, numbered, each with a note
-- Without --replay it watches tmp/shared-memory/canvas/current. A clean stop
-- is a file named `stop` in tmp/shared-memory/lua-window/ (scripts/lua-window
-- drops it on Ctrl-C). The goodbye receipt, output/goodbye-lua-window,
-- counts versions-received, versions-drawn (written over in full),
-- cut-short (a newer version came first), frames-drawn, screenshots,
-- keys-pressed, unreadable and seconds-run.
--
--   local window = dofile(DIR .. "/src/072-lua-window.lua")
--   local s = window.read_settings(root)
--   local writing = window.animation(view, previous, now, s.write_seconds)
--   local frame = window.frame(writing, now + 0.1, s)  -- cells to draw
--   local picture = window.raster(frame, s)            -- pixels
--   window.png(picture)                                -- the PNG's bytes
--
-- LuaJIT-compatible.

-- {{{ local DIR
local SOURCE = debug.getinfo(1, "S").source
local DIR = string.match(SOURCE, "^@(.+)/src/[^/]*$")
    or (string.match(SOURCE, "^@src/[^/]*$") and ".")
    or "/mnt/mtwo/programming/ai-stuff/guide-feature"
-- }}}

local ffi = require("ffi")
local bit = require("bit")
pcall(ffi.cdef, "int poll(void *fds, unsigned long nfds, int timeout);")
pcall(ffi.cdef, [[
typedef struct { long tv_sec; long tv_nsec; } guide_view_timespec;
int clock_gettime(int clock, guide_view_timespec *spec);
]])

local settings = dofile(DIR .. "/src/001-settings.lua")
local goodbye = dofile(DIR .. "/src/002-goodbye.lua")
local viewer = dofile(DIR .. "/src/022-viewer.lua")
local font = dofile(DIR .. "/libs/bitmap-font.lua")

local M = {}

-- {{{ M.SETTINGS
-- input/lua-window.
--   voice-colours       each voice's colour, #rrggbb, in the order of the
--                       canvas's voices: header
--   kuvalu-colour       the distiller's (601), which has no place there
--   background          behind unmarked cells
--   ink                 the letters
--   word-strengths      how much of the voice's colour is behind a `word`
--                       mark, by age: the first for age 0, then age 1, ...;
--                       older marks take the last (0 none, 1 all)
--   sentence-strengths  the same for `sentence` (and `orphan`) marks
--   letter-scale        each 8x8 letter drawn this many times bigger
--   write-seconds       how long a changed run takes to be written over
--   frames-per-second   how often the frame is drawn while writing
--   check-every         seconds between looks at canvas/current
--   replay-every        seconds between versions in --replay
M.SETTINGS = {
    ["voice-colours"]      = { type = "text", required = true },
    ["kuvalu-colour"]      = { type = "text", required = true },
    ["background"]         = { type = "text", required = true },
    ["ink"]                = { type = "text", required = true },
    ["word-strengths"]     = { type = "text", required = true },
    ["sentence-strengths"] = { type = "text", required = true },
    ["letter-scale"]       = { type = "whole", required = true },
    ["write-seconds"]      = { type = "decimal", required = true },
    ["frames-per-second"]  = { type = "whole", required = true },
    ["check-every"]        = { type = "decimal", required = true },
    ["replay-every"]       = { type = "decimal", required = true },
}
-- }}}

-- {{{ function M.parse_colour()
-- "#rrggbb" as { r, g, b }, each 0 to 255, or nil.
function M.parse_colour(text)
    local r, g, b = string.match(text or "", "^#(%x%x)(%x%x)(%x%x)$")
    if not r then return nil end
    return { tonumber(r, 16), tonumber(g, 16), tonumber(b, 16) }
end
-- }}}

-- {{{ function M.read_settings()
-- input/lua-window, with its lists taken apart and checked. Refused, naming
-- the file: a colour that is not #rrggbb, a strength outside 0 to 1, an
-- empty list, a scale or frame rate below 1, a time not above 0.
function M.read_settings(root)
    local values = settings.read("lua-window", M.SETTINGS, { root = root })
    local function fail(text) error("input/lua-window: " .. text, 0) end
    local function colour(name, word)
        local rgb = M.parse_colour(word)
        if not rgb then fail(name .. ": '" .. tostring(word) .. "' is not a colour written #rrggbb") end
        return rgb
    end
    local voices = {}
    for word in string.gmatch(values["voice-colours"], "%S+") do
        voices[#voices + 1] = colour("voice-colours", word)
    end
    if #voices == 0 then fail("voice-colours: no colour given") end
    local function strengths(name)
        local list = {}
        for word in string.gmatch(values[name], "%S+") do
            local number = tonumber(word)
            if not number or number < 0 or number > 1 then
                fail(name .. ": '" .. word .. "' is not a strength from 0 to 1")
            end
            list[#list + 1] = number
        end
        if #list == 0 then fail(name .. ": no strength given") end
        return list
    end
    local s = {
        voices = voices,
        kuvalu = colour("kuvalu-colour", values["kuvalu-colour"]),
        background = colour("background", values["background"]),
        ink = colour("ink", values["ink"]),
        word = strengths("word-strengths"),
        sentence = strengths("sentence-strengths"),
        scale = values["letter-scale"],
        write_seconds = values["write-seconds"],
        fps = values["frames-per-second"],
        check_every = values["check-every"],
        replay_every = values["replay-every"],
    }
    if s.scale < 1 then fail("letter-scale: must be at least 1") end
    if s.fps < 1 then fail("frames-per-second: must be at least 1") end
    for _, name in ipairs({ "write-seconds", "check-every", "replay-every" }) do
        local key = ({ ["write-seconds"] = "write_seconds", ["check-every"] = "check_every",
                       ["replay-every"] = "replay_every" })[name]
        if s[key] <= 0 then fail(name .. ": must be above 0") end
    end
    return s
end
-- }}}

-- {{{ function M.blend()
-- `over` laid on `under` at strength t (0 under alone, 1 over alone), each
-- channel rounded.
function M.blend(under, over, t)
    local out = {}
    for channel = 1, 3 do
        out[channel] = math.floor(under[channel] + (over[channel] - under[channel]) * t + 0.5)
    end
    return out
end
-- }}}

-- {{{ function M.strength()
-- How much of its voice's colour a mark puts behind its cell: from the
-- word or sentence list, by age; older marks take the last. 0 for no mark.
function M.strength(mark, s)
    if not mark then return 0 end
    local list = mark.kind == "word" and s.word or s.sentence
    return list[math.min(mark.age + 1, #list)]
end
-- }}}

-- {{{ function M.voice_colour()
-- A mark's voice's colour: kuvalu's own, or by the voice's place in the
-- voices: header, the colours taken round again when there are more voices
-- than colours. nil for a voice the header does not list.
function M.voice_colour(view, mark, s)
    if mark.voice == "kuvalu" then return s.kuvalu end
    local place = viewer.colour_of(view, mark.voice)
    if not place then return nil end
    return s.voices[(place - 1) % #s.voices + 1]
end
-- }}}

-- {{{ function M.background()
-- The colour behind a cell with this mark (nil for none).
function M.background(view, mark, s)
    if not mark then return s.background end
    local colour = M.voice_colour(view, mark, s)
    if not colour then return s.background end
    return M.blend(s.background, colour, M.strength(mark, s))
end
-- }}}

-- {{{ function M.animation()
-- The writing-over of one new version. A run is the changed cells of one
-- word: changed cells on one row with nothing between them but letters that
-- did not change ("sat" to "ran" is one run of three, though its "a" stayed).
-- Each run is written left to right over `seconds`: the cell k places into a
-- run L long turns to its new character at started + k/L * seconds; until
-- then it shows what was there. Every run is written at once, so a version
-- takes `seconds` whatever its number of changes. With no previous view (or
-- one of another size), every cell that is not a space is new, written over
-- a blank. Returns { view, previous, started, seconds, ends, flips, changes,
-- runs } where flips[row][column] is a changed cell's time.
function M.animation(view, previous, started, seconds)
    local changes = viewer.changed(view, previous)
    local comparable = previous ~= nil and previous.width == view.width
        and previous.height == view.height
    local function joined(row, from, to)
        -- only unchanged letters (no spaces) between columns from and to
        for column = from + 1, to - 1 do
            if view.cells[row][column].character == " " then return false end
        end
        return true
    end
    local flips, runs = {}, 0
    local index = 1
    while index <= #changes do
        local first = changes[index]
        local last = index
        while changes[last + 1] and changes[last + 1].row == first.row
            and joined(first.row, changes[last].column, changes[last + 1].column) do
            last = last + 1
        end
        local length = changes[last].column - first.column + 1
        flips[first.row] = flips[first.row] or {}
        for at = index, last do
            local place = changes[at].column - first.column + 1
            flips[first.row][changes[at].column] = started + place / length * seconds
        end
        runs = runs + 1
        index = last + 1
    end
    return { view = view, previous = comparable and previous or nil, started = started,
             seconds = seconds, ends = started + seconds, flips = flips,
             changes = #changes, runs = runs }
end
-- }}}

-- {{{ function M.frame()
-- What is on screen at time t: cells[row][column] = { character, background,
-- ink, writing } (writing true while the cell still shows what was there).
-- Returns { width, height, version, cells, done } (done once every change
-- is written).
function M.frame(writing, t, s)
    local view, previous = writing.view, writing.previous
    local cells = {}
    for row = 1, view.height do
        cells[row] = {}
        local flips = writing.flips[row]
        for column = 1, view.width do
            local flip = flips and flips[column]
            local cell
            if flip and t < flip then
                local old = previous and previous.cells[row][column]
                cell = { character = old and old.character or " ",
                         background = old and M.background(previous, old.mark, s) or s.background,
                         ink = s.ink, writing = true }
            else
                local now = view.cells[row][column]
                cell = { character = now.character,
                         background = M.background(view, now.mark, s), ink = s.ink }
            end
            cells[row][column] = cell
        end
    end
    return { width = view.width, height = view.height, version = view.version,
             cells = cells, done = t >= writing.ends }
end
-- }}}

-- {{{ M.EXTRA_PICTURES
-- The printable characters libs/bitmap-font.lua has no picture for, drawn
-- here in its style (eight rows of eight, `#` lit), so a canvas's $ or @
-- shows as itself. Anything else it has no picture for (a letter beyond
-- ASCII) is drawn as the font's own hollow box: something the font has no
-- shape for, never a blank.
M.EXTRA_PICTURES = {
    ["$"] = "...##...,..#####.,.##.....,..####..,.....##.,.#####..,...##...,........",
    ["%"] = ".##...##,.##..##.,....##..,...##...,..##....,.##..##.,##...##.,........",
    ["&"] = "..###...,.##.##..,..###...,.###.##.,##.###..,##..##..,.###.##.,........",
    ["@"] = "..####..,.##..##.,.##.###.,.##.#.#.,.##.###.,.##.....,..####..,........",
    ["\\"] = "##......,.##.....,..##....,...##...,....##..,.....##.,......##,........",
    ["^"] = "...#....,..###...,.##.##..,##...##.,........,........,........,........",
    ["`"] = "..##....,...##...,....##..,........,........,........,........,........",
    ["{"] = "....###.,...##...,...##...,.###....,...##...,...##...,....###.,........",
    ["|"] = "...##...,...##...,...##...,...##...,...##...,...##...,...##...,........",
    ["}"] = ".###....,...##...,...##...,....###.,...##...,...##...,.###....,........",
    ["~"] = ".###.##.,##.###..,........,........,........,........,........,........",
}
-- }}}

-- {{{ function M.glyph()
-- A character's eight row bytes (high bit leftmost), and whether the font
-- has it (false: the box stands in).
local glyphs = {}
function M.glyph(character)
    local known = glyphs[character]
    if known then return known.rows, known.found end
    local rows, found = font.rows(character), true
    if not rows and M.EXTRA_PICTURES[character] then
        rows = font.rows_of_picture(M.EXTRA_PICTURES[character], character)
    end
    if not rows then
        rows, found = font.rows_of_picture(font.MISSING, character), false
    end
    glyphs[character] = { rows = rows, found = found }
    return rows, found
end
-- }}}

-- {{{ function M.raster()
-- A frame as pixels: each cell 8 x letter-scale wide and tall, its
-- background, then its letter in ink. Returns { width, height, pixels }
-- (pixels: width*height*3 bytes, rows top to bottom, red green blue).
function M.raster(frame, s)
    local size = font.WIDTH * s.scale
    local width, height = frame.width * size, frame.height * size
    local pixels = ffi.new("uint8_t[?]", width * height * 3)
    for row = 1, frame.height do
        for column = 1, frame.width do
            local cell = frame.cells[row][column]
            local bytes = M.glyph(cell.character)
            local left, top = (column - 1) * size, (row - 1) * size
            for y = 0, size - 1 do
                local byte = bytes[math.floor(y / s.scale) + 1]
                local at = ((top + y) * width + left) * 3
                for x = 0, size - 1 do
                    local lit = bit.band(byte, bit.rshift(0x80, math.floor(x / s.scale))) ~= 0
                    local colour = lit and cell.ink or cell.background
                    pixels[at], pixels[at + 1], pixels[at + 2] = colour[1], colour[2], colour[3]
                    at = at + 3
                end
            end
        end
    end
    return { width = width, height = height, pixels = pixels }
end
-- }}}

-- {{{ PNG writing
-- A PNG with no compression (deflate's stored blocks), so it needs no
-- library: what the picture is, plainly.
local crc_table
local function crc32(data, length, crc)
    if not crc_table then
        crc_table = ffi.new("uint32_t[256]")
        for n = 0, 255 do
            local c = n
            for _ = 1, 8 do
                if bit.band(c, 1) ~= 0 then c = bit.bxor(0xEDB88320, bit.rshift(c, 1))
                else c = bit.rshift(c, 1) end
            end
            crc_table[n] = c
        end
    end
    crc = bit.bnot(crc or 0)
    for index = 0, length - 1 do
        crc = bit.bxor(crc_table[bit.band(bit.bxor(crc, data[index]), 0xFF)], bit.rshift(crc, 8))
    end
    return bit.bnot(crc)
end
local function be32(n)
    n = tonumber(ffi.cast("uint32_t", n))
    return string.char(math.floor(n / 16777216) % 256, math.floor(n / 65536) % 256,
                       math.floor(n / 256) % 256, n % 256)
end
local function chunk(kind, data)
    local whole = kind .. data
    local buffer = ffi.new("uint8_t[?]", #whole)
    ffi.copy(buffer, whole, #whole)
    return be32(#data) .. whole .. be32(crc32(buffer, #whole))
end

-- {{{ function M.png()
-- A raster (M.raster) as the bytes of a PNG file.
function M.png(picture)
    local line = picture.width * 3 + 1
    local length = line * picture.height
    local raw = ffi.new("uint8_t[?]", length)
    for y = 0, picture.height - 1 do
        raw[y * line] = 0   -- no filter
        ffi.copy(raw + y * line + 1, picture.pixels + y * picture.width * 3, picture.width * 3)
    end
    -- the zlib stream: header, stored blocks of at most 65535, Adler-32
    local parts = { "\120\1" }
    local a, b = 1, 0
    for index = 0, length - 1 do
        a = (a + raw[index]) % 65521
        b = (b + a) % 65521
    end
    local at = 0
    repeat
        local size = math.min(65535, length - at)
        local final = at + size >= length and 1 or 0
        local inverse = 65535 - size
        parts[#parts + 1] = string.char(final, size % 256, math.floor(size / 256),
                                        inverse % 256, math.floor(inverse / 256))
        parts[#parts + 1] = ffi.string(raw + at, size)
        at = at + size
    until at >= length
    parts[#parts + 1] = be32(b * 65536 + a)
    local header = be32(picture.width) .. be32(picture.height) .. "\8\2\0\0\0"
    return "\137PNG\r\n\26\n" .. chunk("IHDR", header) .. chunk("IDAT", table.concat(parts))
        .. chunk("IEND", "")
end
-- }}}
-- }}}

-- {{{ function M.text_grid()
-- A frame as text, for reading a screenshot without looking at it: the
-- characters in a border, then the same grid showing what is behind each
-- cell: `.` nothing, a voice's place (1, 2, 3 ...) for a word mark and its
-- letter (a, b, c ...) for a sentence or orphan mark, K or k for kuvalu's,
-- and `~` for a cell still showing what was there (being written over).
function M.text_grid(frame, writing)
    local view = writing.view
    local lines = { string.format("version %d, %dx%d", frame.version, frame.width, frame.height) }
    local function border(corner_left, corner_right)
        lines[#lines + 1] = corner_left .. string.rep("-", frame.width) .. corner_right
    end
    border("+", "+")
    for row = 1, frame.height do
        local text = {}
        for column = 1, frame.width do text[column] = frame.cells[row][column].character end
        lines[#lines + 1] = "|" .. table.concat(text) .. "|"
    end
    border("+", "+")
    for row = 1, frame.height do
        local text = {}
        for column = 1, frame.width do
            local cell = frame.cells[row][column]
            local mark = view.cells[row][column].mark
            local sign = "."
            if cell.writing then
                sign = "~"
            elseif mark then
                local word = mark.kind == "word"
                if mark.voice == "kuvalu" then
                    sign = word and "K" or "k"
                else
                    local place = viewer.colour_of(view, mark.voice)
                    if place then
                        sign = word and tostring(place % 10) or string.char(96 + (place - 1) % 26 + 1)
                    end
                end
            end
            text[column] = sign
        end
        lines[#lines + 1] = "|" .. table.concat(text) .. "|"
    end
    border("+", "+")
    return table.concat(lines, "\n") .. "\n"
end
-- }}}

-- {{{ small helpers
local function slurp(path)
    local handle = io.open(path, "rb")
    if not handle then return nil end
    local text = handle:read("*a")
    handle:close()
    return text
end
local function spit(path, text)
    local handle = assert(io.open(path, "wb"))
    handle:write(text)
    handle:close()
end
local function q(text) return "'" .. string.gsub(text, "'", "'\\''") .. "'" end
local function list_folder(path)
    local names = {}
    local pipe = io.popen("ls -1A " .. q(path) .. " 2>/dev/null")
    for name in pipe:lines() do
        if string.sub(name, 1, 1) ~= "." then names[#names + 1] = name end
    end
    pipe:close()
    table.sort(names)
    return names
end
-- }}}

-- {{{ clocks
-- The wall clock, to the millisecond, for the log's "drew version" lines:
-- the phase 8 demo sets them beside when each version was written.
local function wall()
    local spec = ffi.new("guide_view_timespec")
    ffi.C.clock_gettime(0, spec)   -- CLOCK_REALTIME
    return tonumber(spec.tv_sec) + tonumber(spec.tv_nsec) / 1e9
end

-- The run's clock: the real one (monotonic, sleeping), and a pretend one
-- for --fast and the tests: sleeping moves it on at once, so a run draws the
-- same frames without the waiting.
function M.real_clock()
    local clock = {}
    function clock.now()
        local spec = ffi.new("guide_view_timespec")
        ffi.C.clock_gettime(1, spec)   -- CLOCK_MONOTONIC
        return tonumber(spec.tv_sec) + tonumber(spec.tv_nsec) / 1e9
    end
    function clock.sleep(seconds)
        if seconds > 0 then ffi.C.poll(nil, 0, math.ceil(seconds * 1000)) end
    end
    return clock
end
function M.pretend_clock()
    local clock, t = {}, 0
    function clock.now() return t end
    function clock.sleep(seconds) if seconds > 0 then t = t + seconds end end
    return clock
end
-- }}}

-- {{{ M.BACKENDS
-- Where frames go. A backend is { open(width, height), show(frame, raster),
-- keys(), close() }: show is handed each frame (and a function that turns it
-- into pixels, for a backend that needs them), keys returns the keys pressed
-- since it was last asked. `headless` shows nothing and has no keys of its
-- own; screenshots and --key work the same with any backend. A window
-- backend (SDL2 through LuaJIT's FFI, or LÖVE) goes here once kuvalu has one.
M.BACKENDS = {
    headless = function()
        return { open = function() end, show = function() end,
                 keys = function() return {} end, close = function() end }
    end,
}
-- }}}

-- {{{ function M.run()
-- The program. opts: root, replay (a folder), screenshots (a list of
-- seconds), keys (a list of { seconds, name }), seconds (a time limit),
-- clock (M.real_clock() unless given; --fast gives M.pretend_clock()),
-- backend (a name in M.BACKENDS; headless). Returns the receipt's path.
function M.run(opts)
    local root = opts.root or DIR
    local s = M.read_settings(root)
    local clock = opts.clock or M.real_clock()
    local run = goodbye.start("lua-window", { root = root, clock = opts.goodbye_clock })
    local make = M.BACKENDS[opts.backend or "headless"]
    if not make then error("no backend named " .. tostring(opts.backend), 0) end
    local backend = make()
    local folder = root .. "/tmp/shared-memory/lua-window"
    local shots = folder .. "/screenshots"
    os.execute("mkdir -p " .. q(shots))
    os.remove(folder .. "/stop")
    local current_path = root .. "/tmp/shared-memory/canvas/current"
    local started = clock.now()
    local function elapsed() return clock.now() - started end
    local EARLY = 1e-9
    for _, name in ipairs({ "versions-received", "versions-drawn", "cut-short", "frames-drawn",
                            "screenshots", "keys-pressed", "unreadable" }) do
        run:count(name, 0)
    end

    -- {{{ the schedule: screenshots and key presses, each at its time
    local schedule = {}
    for _, seconds in ipairs(opts.screenshots or {}) do
        schedule[#schedule + 1] = { at = seconds, shot = true }
    end
    for _, key in ipairs(opts.keys or {}) do
        schedule[#schedule + 1] = { at = key[1], key = key[2] }
    end
    table.sort(schedule, function(a, b)
        if a.at ~= b.at then return a.at < b.at end
        return (a.key and 1 or 0) < (b.key and 1 or 0)   -- a screenshot before a key at one time
    end)
    local last_scheduled = #schedule > 0 and schedule[#schedule].at or 0
    -- }}}

    local writing          -- the version being drawn (M.animation)
    local shown            -- the newest version written over in full
    local next_frame
    local frame_step = 1 / s.fps
    local opened = false
    local stopping = false
    -- numbered after any screenshots still waiting to be filed
    local shot_number = 0
    for _, name in ipairs(list_folder(shots)) do
        local number = tonumber(string.match(name, "^(%d+)%-") or "")
        if number and number > shot_number then shot_number = number end
    end

    local function draw(t)
        local frame = M.frame(writing, t, s)
        backend.show(frame, function() return M.raster(frame, s) end)
        run:count("frames-drawn")
        return frame
    end
    local function receive(text, source)
        run:count("versions-received")
        local ok, view = pcall(viewer.read, text, source)
        if not ok then
            run:count("unreadable")
            run:log(source .. " does not read: " .. tostring(view))
            return
        end
        local t = elapsed()
        if writing and not writing.finished then
            -- a newer version before this one was written in full: it is
            -- shown in full at once, and the new one written over it
            run:count("cut-short")
            run:log(string.format("version %d cut short by version %d", writing.view.version,
                view.version))
            shown = writing.view
        end
        if not opened then
            backend.open(view.width * font.WIDTH * s.scale, view.height * font.HEIGHT * s.scale)
            opened = true
        end
        writing = M.animation(view, shown, t, s.write_seconds)
        draw(t)
        next_frame = t + frame_step
    end
    local function screenshot(t)
        if not writing then
            run:log(string.format("no screenshot at %.2f s: no version has arrived", t))
            return
        end
        local frame = M.frame(writing, t, s)
        shot_number = shot_number + 1
        local base = string.format("%s/%02d-at-%06.2fs-version-%d", shots, shot_number, t,
            frame.version)
        spit(base .. ".png", M.png(M.raster(frame, s)))
        spit(base .. ".txt", M.text_grid(frame, writing))
        run:count("screenshots")
        run:log(string.format("screenshot at %.2f s: %s.png", t, base))
    end
    local paused_at
    local next_version = 0   -- when the replay's next version arrives
    local function press(name, t)
        run:count("keys-pressed")
        local key = string.lower(name)
        if key == "q" or key == "escape" then
            run:log(string.format("%s pressed at %.2f s: stopping", name, t))
            stopping = true
        elseif key == "space" then
            if paused_at then
                run:log(string.format("space at %.2f s: replay resumed", t))
                next_version = next_version + (t - paused_at)
                paused_at = nil
            else
                run:log(string.format("space at %.2f s: replay paused", t))
                paused_at = t
            end
        elseif key == "s" then
            screenshot(t)
        else
            run:log(string.format("key %s at %.2f s does nothing", name, t))
        end
    end

    -- {{{ where versions come from
    local versions, version_index = {}, 1
    if opts.replay then
        for _, name in ipairs(list_folder(opts.replay)) do versions[#versions + 1] = name end
        run:log(string.format("replaying %s: %d versions, one each %.2f s", opts.replay,
            #versions, s.replay_every))
    else
        run:log("watching " .. current_path)
    end
    local last_text
    local next_check = 0
    -- }}}

    while true do
        local t = elapsed()
        -- {{{ a new version
        if opts.replay then
            while not paused_at and versions[version_index] and t >= next_version - EARLY do
                local name = versions[version_index]
                receive(slurp(opts.replay .. "/" .. name) or "", name)
                version_index = version_index + 1
                next_version = next_version + s.replay_every
            end
        elseif t >= next_check - EARLY then
            local text = slurp(current_path)
            if text and text ~= last_text then
                receive(text, "canvas/current")
                last_text = text
            end
            next_check = t + s.check_every
            if slurp(folder .. "/stop") then
                os.remove(folder .. "/stop")
                run:log("stop file found")
                stopping = true
            end
        end
        -- }}}
        -- {{{ the next frame of the writing-over
        if writing and not writing.finished and t >= next_frame - EARLY then
            local frame = draw(math.min(t, writing.ends))
            if not writing.logged then
                -- its first frame: the new version is on the screen from here
                writing.logged = true
                run:log(string.format("drew version %d at %.3f", writing.view.version, wall()))
            end
            if frame.done then
                writing.finished = true
                shown = writing.view
                run:count("versions-drawn")
            else
                next_frame = math.min(next_frame + frame_step, writing.ends)
            end
        end
        -- }}}
        -- {{{ screenshots and keys that are due
        for _, event in ipairs(backend.keys()) do press(event, t) end
        while schedule[1] and t >= schedule[1].at - EARLY do
            local event = table.remove(schedule, 1)
            if event.shot then screenshot(event.at) else press(event.key, event.at) end
        end
        -- }}}
        -- {{{ whether to stop
        if opts.seconds and t >= opts.seconds - EARLY then
            run:log(string.format("stopped after %.2f s (--for)", t))
            stopping = true
        end
        local replay_over = opts.replay and not versions[version_index]
            and (not writing or writing.finished) and t >= last_scheduled - EARLY
        if replay_over then run:log("the replay is over") end
        if stopping or replay_over then break end
        -- }}}
        -- {{{ sleep until the next thing to do
        local wake = math.huge
        if opts.replay and not paused_at and versions[version_index] then
            wake = math.min(wake, next_version)
        end
        if not opts.replay then wake = math.min(wake, next_check) end
        if writing and not writing.finished then wake = math.min(wake, next_frame) end
        if schedule[1] then wake = math.min(wake, schedule[1].at) end
        if opts.seconds then wake = math.min(wake, opts.seconds) end
        if wake == math.huge then
            -- paused with nothing scheduled: only a key or --for can end it
            wake = t + s.check_every
        end
        clock.sleep(math.max(0, wake - elapsed()))
        -- }}}
    end
    backend.close()
    run:count("seconds-run", math.floor(elapsed() + 0.5))
    return run:finish()
end
-- }}}

-- {{{ function M.file_screenshots()
-- Files every screenshot waiting in tmp/shared-memory/lua-window/screenshots/
-- into ROOT/development-history/ (the project's record of the pictures it
-- takes of itself; none is a throwaway): NNN-lua-window-<its name>.png and
-- .txt, NNN one more than the highest number already there, three digits,
-- and NNN-...info.md naming what made it (made_by), the commit and the
-- date. The waiting copies are moved, not copied. Returns the filed names.
function M.file_screenshots(root, made_by, date)
    local from = root .. "/tmp/shared-memory/lua-window/screenshots"
    local to = root .. "/development-history"
    os.execute("mkdir -p " .. q(to))
    local highest = 0
    for _, name in ipairs(list_folder(to)) do
        local number = tonumber(string.match(name, "^(%d%d%d)%-") or "")
        if number and number > highest then highest = number end
    end
    local commit = io.popen("git -C " .. q(root) .. " rev-parse --short HEAD 2>/dev/null")
    local head = (commit:read("*l") or "")
    commit:close()
    if head == "" then head = "not a git checkout" end
    local filed = {}
    for _, name in ipairs(list_folder(from)) do
        local stem = string.match(name, "^(.+)%.png$")
        if stem then
            highest = highest + 1
            local base = string.format("%03d-lua-window-%s", highest, stem)
            spit(to .. "/" .. base .. ".png", slurp(from .. "/" .. name))
            os.remove(from .. "/" .. name)
            local grid = slurp(from .. "/" .. stem .. ".txt")
            if grid then
                spit(to .. "/" .. base .. ".txt", grid)
                os.remove(from .. "/" .. stem .. ".txt")
            end
            local at, version = string.match(stem, "at%-([%d%.]+)s%-version%-(%d+)")
            at = tonumber(at or "") and string.format("%.2f", tonumber(at)) or "?"
            spit(to .. "/" .. base .. ".info.md", table.concat({
                "# " .. base,
                "",
                "A screenshot by the Lua window (src/072-lua-window.lua, issue 802): version "
                    .. tostring(version) .. " of the canvas, " .. tostring(at)
                    .. " s into the run.",
                "",
                "- made by: " .. (made_by or "src/072-lua-window.lua"),
                "- commit: " .. head,
                "- filed: " .. (date or os.date("!%Y-%m-%dT%H:%M:%SZ")),
                "- " .. base .. ".txt: the same frame as text (the characters, then what is "
                    .. "behind each cell)",
                "",
            }, "\n"))
            filed[#filed + 1] = base
        end
    end
    return filed
end
-- }}}

-- {{{ run as a program
if arg and arg[0] and string.match(arg[0], "072%-lua%-window%.lua$") then
    local opts, index = { root = DIR, screenshots = {}, keys = {} }, 1
    local file_only, made_by
    local function usage(text)
        io.stderr:write(text, "\n")
        os.exit(2)
    end
    local function seconds(value, name)
        local number = tonumber(value or "")
        if not number or number < 0 then usage(name .. " takes a number of seconds") end
        return number
    end
    while arg[index] do
        local name, value = arg[index], arg[index + 1]
        if name == "--dir" then opts.root = value; index = index + 1
        elseif name == "--replay" then opts.replay = value; index = index + 1
        elseif name == "--for" then opts.seconds = seconds(value, "--for"); index = index + 1
        elseif name == "--screenshot" then
            opts.screenshots[#opts.screenshots + 1] = seconds(value, "--screenshot")
            index = index + 1
        elseif name == "--key" then
            local key = arg[index + 2]
            if not key then usage("--key takes SECONDS NAME, like --key 3 q") end
            opts.keys[#opts.keys + 1] = { seconds(value, "--key"), key }
            index = index + 2
        elseif name == "--fast" then opts.clock = M.pretend_clock()
        elseif name == "--file-screenshots" then
            file_only = true
            if value and string.sub(value, 1, 2) ~= "--" then made_by = value; index = index + 1 end
        else
            usage("unknown argument: " .. name)
        end
        index = index + 1
    end
    if file_only then
        for _, base in ipairs(M.file_screenshots(opts.root, made_by)) do
            io.write("filed development-history/", base, ".png\n")
        end
        os.exit(0)
    end
    io.stderr:write("lua-window: no window backend is built yet (issue 802); drawing "
        .. "headless, for screenshots\n")
    local ok, problem = pcall(M.run, opts)
    if not ok then
        io.stderr:write("lua-window: ", tostring(problem), "\n")
        os.exit(1)
    end
    io.write(problem, "\n")
end
-- }}}

return M
