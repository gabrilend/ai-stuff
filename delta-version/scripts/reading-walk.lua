#!/usr/bin/env luajit
-- reading-walk.lua - Walks a reader through a project, one function or
-- datastructure at a time, in the order the project is meant to be read.
--
-- In plain terms: reading-walk-map.lua turns a project into a list of stops.
-- This shows them one at a time. At each stop the reader picks from a short
-- list: go on, see where else it is used, see why it was done this way and not
-- another (only what someone wrote down), see its own lines of code, skip it
-- (its one-sentence summary is shown on the way past -- skipping is allowed,
-- skipping to nothing is not), skip the rest of the file (every remaining
-- summary shown), go back, or stop. Walking to the end is a full reading. No
-- question is asked of the reader, and nothing is graded.
--
-- There is no AI in this version; the order is the project's own index order.
-- A guide that steps back to foundations when a part is not landing is issue
-- 065g, and builds on this.
--
-- Usage:
--   reading-walk.lua <project-dir>                 -- walk (builds the map if there is none)
--   reading-walk.lua <project-dir> --rebuild       -- rebuild the map first
--   reading-walk.lua <project-dir> --start=N       -- begin at stop N
--   reading-walk.lua <project-dir> --choices=nmwsq -- take choices from the string, no person
--                                                    (one letter per choice; for tests and demos)
--   reading-walk.lua ... --map=FILE                -- walk a map kept somewhere else
--   reading-walk.lua ... --dir=PATH                -- delta-version's home
--
-- See reading-walk.info.md, and delta-version/issues/065d-the-walk-without-an-ai.md.

-- {{{ DIR Configuration
local DIR = "/mnt/mtwo/programming/ai-stuff/delta-version"
local TARGET = nil
local MAP_PATH = nil
local REBUILD = false
local START = 1
local SCRIPTED = nil
for _, argument in ipairs(arg) do
    local dir_value = argument:match("^%-%-dir=(.+)$")
    local map_value = argument:match("^%-%-map=(.+)$")
    local start_value = argument:match("^%-%-start=(%d+)$")
    local choices_value = argument:match("^%-%-choices=(.*)$")
    -- each option sets one setting; anything else is the project to walk
    if dir_value then DIR = dir_value
    elseif map_value then MAP_PATH = map_value
    elseif start_value then START = tonumber(start_value)
    elseif choices_value then SCRIPTED = choices_value
    elseif argument == "--rebuild" then REBUILD = true
    else TARGET = argument end
end
-- }}}

-- {{{ local function fail()
local function fail(message)
    io.stderr:write("reading-walk: ", message, "\n")
    os.exit(1)
end
-- }}}

-- {{{ local function shell_quote()
local function shell_quote(text)
    return "'" .. text:gsub("'", "'\\''") .. "'"
end
-- }}}

-- {{{ local function wrap()
-- Text broken into lines no wider than the given width, each indented.
local function wrap(text, width, indent)
    local lines, current = {}, ""
    for word in text:gmatch("%S+") do
        if #current + #word + 1 > width and #current > 0 then
            lines[#lines + 1] = indent .. current
            current = word
        else
            current = (#current > 0) and (current .. " " .. word) or word
        end
    end
    if #current > 0 then lines[#lines + 1] = indent .. current end
    return table.concat(lines, "\n")
end
-- }}}

-- {{{ local function load_map()
-- The map for the project: the one given, or the one in delta-version's RAM
-- tier, built first when it is missing (a reboot empties the tier) or when
-- --rebuild asks.
local function load_map()
    if not MAP_PATH then
        if not TARGET then fail("usage: reading-walk.lua <project-dir> [--start=N] [--choices=LETTERS] [--rebuild]") end
        local project = TARGET:gsub("/+$", "")
        local name = project:match("([^/]+)$")
        MAP_PATH = DIR .. "/tmp/shared-memory/reading-walk/" .. name .. ".map.lua"
        local present = io.open(MAP_PATH, "r")
        if present then present:close() end
        if REBUILD or not present then
            local builder = DIR .. "/scripts/reading-walk-map.lua"
            local status = os.execute(string.format("luajit %s %s --dir=%s >&2",
                shell_quote(builder), shell_quote(project), shell_quote(DIR)))
            if status ~= 0 and status ~= true then fail("the map builder failed") end
        end
    end
    local chunk, problem = loadfile(MAP_PATH)
    if not chunk then fail("cannot read the map " .. MAP_PATH .. ": " .. tostring(problem)) end
    setfenv(chunk, {})
    return chunk()
end
-- }}}

-- {{{ local function show_stop()
local function show_stop(map, stop)
    local total = #map.stops
    io.write("\n", string.rep("-", 72), "\n")
    io.write(string.format("stop %d of %d   %s:%d\n", stop.index, total, stop.file, stop.line))
    io.write(string.format("chapter: %s %s\n", stop.chapter.date, stop.chapter.subject))
    io.write("\n  ", stop.name, "   (", stop.kind, ")\n\n")
    -- the description says where it came from when it is not the .info.md
    -- page, so a missing page entry is visible rather than papered over
    if stop.description_source == "info.md" then
        io.write(wrap(stop.description, 68, "  "), "\n")
    elseif stop.description_source == "source comment" then
        io.write(wrap(stop.description, 68, "  "), "\n")
        io.write("  (from the source comment: the .info.md page has no entry for this)\n")
    else
        io.write("  (nothing describes this: no .info.md entry and no comment)\n")
    end
    io.write(string.format("\n  used in %d places   recorded reasons: %d\n", #stop.uses, #stop.alternatives))
end
-- }}}

-- {{{ local function show_uses()
local function show_uses(stop)
    if #stop.uses == 0 then io.write("\n  not used anywhere in the source\n") return end
    io.write("\n  where it is used:\n")
    for _, use in ipairs(stop.uses) do
        io.write(string.format("    %s:%d   %s\n", use.file, use.line, use.text))
    end
end
-- }}}

-- {{{ local function show_reasons()
local function show_reasons(stop)
    if #stop.alternatives == 0 then
        io.write("\n  no alternative was recorded here -- this choice was not written down\n")
        return
    end
    io.write("\n  why it was done this way (as written down):\n")
    for _, reason in ipairs(stop.alternatives) do
        io.write(string.format("\n    %s:%d\n", reason.source, reason.line))
        io.write(wrap(reason.text, 64, "      "), "\n")
    end
end
-- }}}

-- {{{ local function show_code()
-- The stop's own lines, from its fold marker to its closing marker.
local function show_code(map, stop)
    local handle = io.open(map.project .. "/" .. stop.file, "r")
    if not handle then io.write("\n  the file is gone: ", stop.file, "\n") return end
    local number = 0
    io.write("\n")
    for line in handle:lines() do
        number = number + 1
        if number >= stop.line and number <= stop.end_line then
            io.write(string.format("  %5d  %s\n", number, line))
        end
    end
    handle:close()
end
-- }}}

-- {{{ local function choice_reader()
-- Where choices come from: the person at the terminal, or a scripted string,
-- one letter per choice. A script that runs out quits, so a test cannot hang.
local function choice_reader()
    if SCRIPTED then
        local position = 0
        return function()
            position = position + 1
            local letter = SCRIPTED:sub(position, position)
            if letter == "" then return "q" end
            io.write(letter, "\n")
            return letter
        end
    end
    return function()
        local line = io.read("*l")
        if not line then return "q" end
        line = line:lower():gsub("^%s+", "")
        -- "yeah yeah I get it" is a skip, by her rule: the reader may always
        -- say it, and then the summary must be given
        if line:match("^yeah") then return "s" end
        return line:sub(1, 1)
    end
end
-- }}}

-- {{{ local function walk()
-- The walk. Each choice is an entry in a table; each returns the next stop's
-- index (or nil to end). Counts of what the reader did are kept for the
-- receipt printed at the end.
local function walk(map)
    local stops = map.stops
    if #stops == 0 then fail("the map has no stops") end
    local counts = { shown = 0, skipped = 0, more = 0, why = 0, code = 0 }
    local current = START
    if current > #stops then fail("there are only " .. #stops .. " stops") end
    local next_choice = choice_reader()

    local actions = {
        n = function(index) return index + 1 end,
        m = function(index) counts.more = counts.more + 1; show_uses(stops[index]); return index, true end,
        w = function(index) counts.why = counts.why + 1; show_reasons(stops[index]); return index, true end,
        c = function(index) counts.code = counts.code + 1; show_code(map, stops[index]); return index, true end,
        s = function(index)
            counts.skipped = counts.skipped + 1
            io.write("\n  in short: ", stops[index].summary, "\n")
            return index + 1
        end,
        f = function(index)
            local file = stops[index].file
            io.write("\n  the rest of ", file, ", in short:\n")
            while stops[index] and stops[index].file == file do
                counts.skipped = counts.skipped + 1
                io.write(wrap(stops[index].name .. ": " .. stops[index].summary, 68, "    "), "\n")
                index = index + 1
            end
            return index
        end,
        b = function(index) return (index > 1) and (index - 1) or 1 end,
        q = function() return nil end,
    }

    local stay = false
    while current and current <= #stops do
        -- a choice that only shows more of this stop (uses, reasons, code)
        -- keeps the stop on screen without drawing it again
        if not stay then
            show_stop(map, stops[current])
            counts.shown = counts.shown + 1
        end
        io.write("\n  [n]ext  [m]ore uses  [w]hy  [c]ode  [s]kip  [f] skip file  [b]ack  [q]uit > ")
        io.flush()
        local action = actions[next_choice()]
        if action then
            current, stay = action(current)
        else
            io.write("\n  (choose one of the letters in brackets)\n")
            stay = true
        end
    end

    local reached_end = current ~= nil and current > #stops
    io.write("\n", string.rep("-", 72), "\n")
    -- a walk is complete only when it began at the first stop and passed the last
    if reached_end and START == 1 then io.write("  walk complete: every stop was read or summarized.\n")
    elseif reached_end then io.write("  reached the end, having started at stop ", START, ".\n")
    else io.write("  walk paused.\n") end
    io.write(string.format("  stops shown %d, skipped with summary %d, uses looked at %d, reasons looked at %d, code looked at %d\n",
        counts.shown, counts.skipped, counts.more, counts.why, counts.code))
end
-- }}}

walk(load_map())
