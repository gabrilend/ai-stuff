#!/usr/bin/env luajit
-- 070-terminal-view.lua - the canvas, drawn in a terminal.
--
-- In plain terms: a viewer for any terminal on kuvalu, in st's plain style.
-- It draws the canvas inside a thin border at the canvas's own size. Cells
-- with no mark are in the terminal's default colour; a marked cell is in its
-- voice's colour, a `word` mark bright and a `sentence` mark dim, both
-- stepping down in brightness as the mark ages (a table from age to step,
-- in input/terminal-view). It reads tmp/shared-memory/canvas/current and
-- draws again whenever that changes. A terminal smaller than the canvas
-- shows an error naming both sizes, and nothing is cropped or rewrapped.
-- "Limited display features": no animation, no partial transparency. Plain
-- escape codes; no curses. (issue 801)
--
--   scripts/terminal-view [ROOT]              watch the live canvas; Ctrl-C stops
--   luajit src/070-terminal-view.lua --dir ROOT [--once] [--replay FOLDER]
--       [--size COLUMNSxROWS] [--for SECONDS] [--plain]
--     --once           draw the current canvas once and stop
--     --replay FOLDER  draw every version in a history folder, in order, then
--                      stop (canvas/history, or any folder of canvas files)
--     --size CxR       the terminal's size, instead of asking the terminal
--     --for SECONDS    stop after this long
--     --plain          no colour codes (marks are not shown)
--
-- A clean stop is a file named `stop` in tmp/shared-memory/terminal-view/
-- (scripts/terminal-view drops it on Ctrl-C or TERM). The goodbye receipt,
-- output/goodbye-terminal-view, counts versions-read, versions-drawn,
-- too-small (versions shown as the error instead), unreadable and
-- seconds-run.
--
--   local view = dofile(DIR .. "/src/070-terminal-view.lua")
--   view.draw(viewer_view, { columns = 80, rows = 24, settings = s })  -- the text
--
-- LuaJIT-compatible.

-- {{{ local DIR
local SOURCE = debug.getinfo(1, "S").source
local DIR = string.match(SOURCE, "^@(.+)/src/[^/]*$")
    or (string.match(SOURCE, "^@src/[^/]*$") and ".")
    or "/mnt/mtwo/programming/ai-stuff/guide-feature"
-- }}}

local ffi = require("ffi")
pcall(ffi.cdef, "int poll(void *fds, unsigned long nfds, int timeout);")
pcall(ffi.cdef, [[
struct guide_winsize { unsigned short rows, columns, xpixel, ypixel; };
int ioctl(int fd, unsigned long request, ...);
int isatty(int fd);
]])
pcall(ffi.cdef, [[
typedef struct { long tv_sec; long tv_nsec; } guide_view_timespec;
int clock_gettime(int clock, guide_view_timespec *spec);
]])

local settings = dofile(DIR .. "/src/001-settings.lua")
local goodbye = dofile(DIR .. "/src/002-goodbye.lua")
local utf8 = dofile(DIR .. "/src/005-utf8.lua")
local viewer = dofile(DIR .. "/src/022-viewer.lua")

local M = {}

-- {{{ M.SETTINGS
-- input/terminal-view.
--   colours        the standard colour code (30 to 37) of each voice, in
--                  the order of the canvas's voices: header
--   kuvalu-colour  the distiller's (601), which has no place in that header
--   word-steps     the step a `word` mark is drawn at, by age: the first for
--                  age 0, the next for age 1, ...; older marks take the last
--   sentence-steps the same for `sentence` (and `orphan`) marks
--   check-every    seconds between looks at canvas/current
-- A step is bright (the colour's bright code and bold), normal, or dim (the
-- colour, faint).
M.SETTINGS = {
    ["colours"]        = { type = "text", required = true },
    ["kuvalu-colour"]  = { type = "whole", required = true },
    ["word-steps"]     = { type = "text", required = true },
    ["sentence-steps"] = { type = "text", required = true },
    ["check-every"]    = { type = "decimal", required = true },
}
M.STEPS = { bright = true, normal = true, dim = true }
-- }}}

-- {{{ function M.read_settings()
-- input/terminal-view, with its lists taken apart and checked. Refused, naming
-- the file: a colour that is not 30 to 37, a step that is not one of the three,
-- an empty list.
function M.read_settings(root)
    local values = settings.read("terminal-view", M.SETTINGS, { root = root })
    local function fail(text) error("input/terminal-view: " .. text, 0) end
    local colours = {}
    for word in string.gmatch(values.colours, "%S+") do
        local code = tonumber(word)
        if not code or code < 30 or code > 37 or code ~= math.floor(code) then
            fail("colours: '" .. word .. "' is not a colour code from 30 to 37")
        end
        colours[#colours + 1] = code
    end
    if #colours == 0 then fail("colours: no colour given") end
    local kuvalu = values["kuvalu-colour"]
    if kuvalu < 30 or kuvalu > 37 then fail("kuvalu-colour: not a colour code from 30 to 37") end
    local function steps(name)
        local list = {}
        for word in string.gmatch(values[name], "%S+") do
            if not M.STEPS[word] then
                fail(name .. ": '" .. word .. "' is not bright, normal or dim")
            end
            list[#list + 1] = word
        end
        if #list == 0 then fail(name .. ": no step given") end
        return list
    end
    return { colours = colours, kuvalu = kuvalu, word = steps("word-steps"),
             sentence = steps("sentence-steps"), check_every = values["check-every"] }
end
-- }}}

-- {{{ function M.style()
-- The escape code's parameters for a mark: its voice's colour at the step its
-- age gives, or nil for no mark (the default colour). A voice with no colour
-- of its own (more voices than colours) takes the colours round again.
function M.style(view, mark, s)
    if not mark then return nil end
    local code
    if mark.voice == "kuvalu" then
        code = s.kuvalu
    else
        local place = viewer.colour_of(view, mark.voice)
        if not place then return nil end
        code = s.colours[(place - 1) % #s.colours + 1]
    end
    local list = mark.kind == "word" and s.word or s.sentence
    local step = list[math.min(mark.age + 1, #list)]
    if step == "bright" then return "1;" .. (code + 60) end
    if step == "dim" then return "2;" .. code end
    return tostring(code)
end
-- }}}

-- {{{ function M.border_size()
-- The terminal size the canvas needs: its own, and the border round it.
function M.border_size(view)
    return view.width + 2, view.height + 2
end
-- }}}

-- {{{ function M.too_small()
-- The error a terminal too small for the canvas shows, or nil when it fits.
function M.too_small(view, columns, rows)
    local need_columns, need_rows = M.border_size(view)
    if columns >= need_columns and rows >= need_rows then return nil end
    return string.format("the canvas is %dx%d (%dx%d with its border); this terminal is %dx%d",
        view.width, view.height, need_columns, need_rows, columns, rows)
end
-- }}}

-- {{{ function M.draw()
-- The whole screen for a view, as text to write: clear, then the canvas in
-- its border at the top left, each run of cells with one style written with
-- one escape code. opts: columns, rows (the terminal's size), settings
-- (read_settings), plain (no colour). A terminal too small gets the error,
-- alone. Returns the text and whether the canvas was drawn.
function M.draw(view, opts)
    local out = { "\27[H\27[2J" }
    local problem = M.too_small(view, opts.columns, opts.rows)
    if problem then
        out[#out + 1] = problem .. "\r\n"
        return table.concat(out), false
    end
    out[#out + 1] = "\226\148\140" .. string.rep("\226\148\128", view.width) .. "\226\148\144\r\n"
    for row = 1, view.height do
        out[#out + 1] = "\226\148\130"
        local current
        for column = 1, view.width do
            local cell = view.cells[row][column]
            local style = not opts.plain and M.style(view, cell.mark, opts.settings) or nil
            if style ~= current then
                out[#out + 1] = style and ("\27[0;" .. style .. "m") or "\27[0m"
                current = style
            end
            out[#out + 1] = cell.character
        end
        if current then out[#out + 1] = "\27[0m" end
        out[#out + 1] = "\226\148\130\r\n"
    end
    out[#out + 1] = "\226\148\148" .. string.rep("\226\148\128", view.width) .. "\226\148\152\r\n"
    return table.concat(out), true
end
-- }}}

-- {{{ function M.terminal_size()
-- The terminal's columns and rows, from the terminal itself, or from
-- COLUMNS and LINES, or nil.
function M.terminal_size()
    local size = ffi.new("struct guide_winsize")
    -- TIOCGWINSZ on Linux
    if ffi.C.ioctl(1, 0x5413, size) == 0 and size.columns > 0 then
        return size.columns, size.rows
    end
    local columns, rows = tonumber(os.getenv("COLUMNS") or ""), tonumber(os.getenv("LINES") or "")
    if columns and rows then return columns, rows end
    return nil
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
local function now()
    local spec = ffi.new("guide_view_timespec")
    ffi.C.clock_gettime(1, spec)   -- CLOCK_MONOTONIC
    return tonumber(spec.tv_sec) + tonumber(spec.tv_nsec) / 1e9
end
local function sleep(seconds) ffi.C.poll(nil, 0, math.floor(seconds * 1000)) end
-- The wall clock, to the millisecond, for the log's "drew version" lines:
-- the phase 8 demo sets them beside when each version was written.
local function wall()
    local spec = ffi.new("guide_view_timespec")
    ffi.C.clock_gettime(0, spec)   -- CLOCK_REALTIME
    return tonumber(spec.tv_sec) + tonumber(spec.tv_nsec) / 1e9
end
local function list_folder(path)
    local names = {}
    local pipe = io.popen("ls -1A '" .. string.gsub(path, "'", "'\\''") .. "' 2>/dev/null")
    for name in pipe:lines() do
        if string.sub(name, 1, 1) ~= "." then names[#names + 1] = name end
    end
    pipe:close()
    table.sort(names)
    return names
end
-- }}}

-- {{{ function M.run()
-- The program. opts: root, once, replay (a folder), columns and rows (else
-- the terminal's), seconds (a time limit), plain, write (where the screen
-- goes; default io.write), clock (tests). Returns the receipt's path.
function M.run(opts)
    local root = opts.root or DIR
    local s = M.read_settings(root)
    local run = goodbye.start("terminal-view", { root = root, clock = opts.clock })
    local write = opts.write or function(text) io.write(text) io.flush() end
    local started = now()
    local stop_folder = root .. "/tmp/shared-memory/terminal-view"
    os.execute("mkdir -p '" .. string.gsub(stop_folder, "'", "'\\''") .. "'")
    os.remove(stop_folder .. "/stop")
    local current_path = root .. "/tmp/shared-memory/canvas/current"
    local size_note
    local function size()
        if opts.columns and opts.rows then return opts.columns, opts.rows end
        local columns, rows = M.terminal_size()
        if not columns then
            columns, rows = 80, 24
            if not size_note then
                size_note = true
                run:log("the terminal's size could not be read; drawing for 80x24")
            end
        end
        return columns, rows
    end
    local function show(text, source)
        run:count("versions-read")
        local ok, view = pcall(viewer.read, text, source)
        if not ok then
            run:count("unreadable")
            run:log(source .. " does not read: " .. tostring(view))
            return
        end
        local columns, rows = size()
        local screen, drawn = M.draw(view, { columns = columns, rows = rows, settings = s,
                                            plain = opts.plain })
        write(screen)
        if drawn then
            run:count("versions-drawn")
            run:log(string.format("drew version %d at %.3f", view.version, wall()))
        else
            run:count("too-small")
            run:log(string.format("version %d: %s", view.version, M.too_small(view, columns, rows)))
        end
        return view
    end

    run:log(opts.replay and ("replaying " .. opts.replay) or ("watching " .. current_path))
    if opts.replay then
        for _, name in ipairs(list_folder(opts.replay)) do
            show(slurp(opts.replay .. "/" .. name) or "", name)
            if opts.seconds and now() - started >= opts.seconds then break end
        end
    else
        local last, last_size = nil, nil
        while true do
            local text = slurp(current_path)
            local columns, rows = size()
            local this_size = columns .. "x" .. rows
            -- drawn again when the canvas changes, or the terminal is resized
            if text and (text ~= last or this_size ~= last_size) then
                show(text, "canvas/current")
                last, last_size = text, this_size
            end
            if opts.once then break end
            if slurp(stop_folder .. "/stop") then
                os.remove(stop_folder .. "/stop")
                run:log("stop file found")
                break
            end
            if opts.seconds and now() - started >= opts.seconds then break end
            sleep(s.check_every)
        end
    end
    if not opts.plain and not opts.write then write("\27[0m") end
    run:count("seconds-run", math.floor(now() - started + 0.5))
    return run:finish()
end
-- }}}

-- {{{ run as a program
if arg and arg[0] and string.match(arg[0], "070%-terminal%-view%.lua$") then
    local opts, index = { root = DIR }, 1
    while arg[index] do
        local name, value = arg[index], arg[index + 1]
        if name == "--dir" then opts.root = value; index = index + 1
        elseif name == "--once" then opts.once = true
        elseif name == "--replay" then opts.replay = value; index = index + 1
        elseif name == "--for" then opts.seconds = tonumber(value); index = index + 1
        elseif name == "--plain" then opts.plain = true
        elseif name == "--size" then
            local columns, rows = string.match(value or "", "^(%d+)x(%d+)$")
            if not columns then
                io.stderr:write("--size is COLUMNSxROWS, like 80x24\n")
                os.exit(2)
            end
            opts.columns, opts.rows = tonumber(columns), tonumber(rows)
            index = index + 1
        else
            io.stderr:write("unknown argument: ", name, "\n")
            os.exit(2)
        end
        index = index + 1
    end
    local ok, problem = pcall(M.run, opts)
    if not ok then
        io.stderr:write("terminal-view: ", tostring(problem), "\n")
        os.exit(1)
    end
end
-- }}}

return M
