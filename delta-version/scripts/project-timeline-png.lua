#!/usr/bin/env luajit
-- project-timeline-png.lua - Paints the project timeline as a PNG picture.
--
-- In plain terms: it reads the timeline data the gatherer wrote (when each
-- project began, which days it was worked on) and paints one column per
-- project. Columns stand left to right in the order the projects were born.
-- Each column is a dark bar that rises from the project's first day to today;
-- every day the project was worked on is lit across the bar's width. Labels are
-- drawn with a tiny built-in pixel font, so no font library or image program
-- is needed: the picture is pixels written straight into a PNG file.
--
-- Both axes are time, used differently:
--   X  --x=order     columns evenly spaced, in birth order (default)
--      --x=time      a column stands at its birth date on a calendar scale;
--                    columns born on the same day stand side by side
--   Y  --y=age       every bar starts at the baseline; height is days since
--                    birth, so two bars at the same height are the same age
--                    (default)
--      --y=calendar  the Y axis is the calendar; a bar starts at its birth
--                    date, so the bars climb like stairs and one horizontal
--                    line is one day across every project
--
-- Usage:
--   project-timeline-png.lua [--in=FILE] [--out=FILE] [--x=order|time] [--y=age|calendar]
--                            [--sources=commit,transcript,sweep] [--day-pixels=N]
--                            [--column=N] [--gap=N] [--dir=PATH] [--help]
--
-- See project-timeline-png.info.md, and issue 067 for why.

-- {{{ DIR Configuration
local DIR = "/mnt/mtwo/programming/ai-stuff/delta-version"
local options = {
    input = nil, output = nil, x = "order", y = "age",
    sources = "commit,transcript,sweep", day_pixels = 2, column = 12, gap = 3,
    help = false,
}
-- each option name maps to the field it sets and how to read its value; an
-- argument matching none of them stops the program
local option_readers = {
    ["dir"] = function(value) DIR = value end,
    ["in"] = function(value) options.input = value end,
    ["out"] = function(value) options.output = value end,
    ["x"] = function(value) options.x = value end,
    ["y"] = function(value) options.y = value end,
    ["sources"] = function(value) options.sources = value end,
    ["day-pixels"] = function(value) options.day_pixels = tonumber(value) end,
    ["column"] = function(value) options.column = tonumber(value) end,
    ["gap"] = function(value) options.gap = tonumber(value) end,
}
for _, argument in ipairs(arg) do
    local name, value = argument:match("^%-%-([%w-]+)=(.+)$")
    if argument == "--help" or argument == "-h" then
        options.help = true
    elseif name and option_readers[name] then
        option_readers[name](value)
    else
        io.stderr:write("project-timeline-png: unknown argument: " .. argument .. "\n")
        os.exit(2)
    end
end
local ASSET_DIR = DIR .. "/assets/project-timeline"
options.input = options.input or (ASSET_DIR .. "/timeline.json")
options.output = options.output or (ASSET_DIR .. "/timeline-" .. options.x .. "-" .. options.y .. ".png")
package.path = "/home/ritz/programming/ai-stuff/libs/lua/?.lua;"
    .. "/home/ritz/programming/ai-stuff/scripts/libs/?.lua;" .. package.path
-- }}}

local ffi = require("ffi")
local json = require("dkjson")
local png = require("png-writer")

-- {{{ local function print_help()
local function print_help()
    print([[
project-timeline-png.lua - paint the project timeline as a PNG

  --in=FILE           timeline JSON (default assets/project-timeline/timeline.json)
  --out=FILE          picture to write (default assets/project-timeline/timeline-X-Y.png)
  --x=order|time      columns evenly spaced in birth order, or placed on a calendar
  --y=age|calendar    bars rise from a shared baseline by age, or start at their
                      birth date on a calendar
  --sources=LIST      which footprints light a day: commit, transcript, sweep
                      (comma separated; default all three)
  --day-pixels=N      pixels per day up the Y axis (default 2)
  --column=N          column width in pixels (default 12)
  --gap=N             pixels between columns (default 3)
  --dir=PATH          the delta-version folder
  --help              this text]])
end
-- }}}

-- {{{ local palette
-- Colours as {red, green, blue}, 0-255. A day lit by two sources at once
-- takes the "both" colour so overlap reads as its own thing, not as whichever
-- source was painted last. A sweep only shows where nothing else lit the day.
local palette = {
    background = { 14, 17, 22 },
    bar        = { 34, 41, 54 },
    grid       = { 26, 31, 40 },
    axis       = { 90, 98, 112 },
    text       = { 200, 205, 214 },
    faint_text = { 120, 128, 142 },
    commit     = { 240, 180, 41 },
    transcript = { 79, 195, 247 },
    both       = { 255, 244, 214 },
    sweep      = { 88, 96, 112 },
}
-- }}}

-- {{{ local glyphs
-- A 3-wide, 5-tall pixel font: each glyph is five rows of three characters,
-- "#" lit and "." dark. Upper case only; lower case is folded up before
-- drawing. A character with no glyph here is an error rather than a blank,
-- so a missing letter is noticed the first time it is needed.
local glyphs = {
    ["0"] = "###/#.#/#.#/#.#/###", ["1"] = ".#./##./.#./.#./###",
    ["2"] = "###/..#/###/#../###", ["3"] = "###/..#/.##/..#/###",
    ["4"] = "#.#/#.#/###/..#/..#", ["5"] = "###/#../###/..#/###",
    ["6"] = "###/#../###/#.#/###", ["7"] = "###/..#/.#./.#./.#.",
    ["8"] = "###/#.#/###/#.#/###", ["9"] = "###/#.#/###/..#/###",
    A = ".#./#.#/###/#.#/#.#", B = "##./#.#/##./#.#/##.", C = ".##/#../#../#../.##",
    D = "##./#.#/#.#/#.#/##.", E = "###/#../##./#../###", F = "###/#../##./#../#..",
    G = ".##/#../#.#/#.#/.##", H = "#.#/#.#/###/#.#/#.#", I = "###/.#./.#./.#./###",
    J = "..#/..#/..#/#.#/.#.", K = "#.#/#.#/##./#.#/#.#", L = "#../#../#../#../###",
    M = "#.#/###/###/#.#/#.#", N = "##./#.#/#.#/#.#/#.#", O = ".#./#.#/#.#/#.#/.#.",
    P = "##./#.#/##./#../#..", Q = ".#./#.#/#.#/##./.##", R = "##./#.#/##./#.#/#.#",
    S = ".##/#../.#./..#/##.", T = "###/.#./.#./.#./.#.", U = "#.#/#.#/#.#/#.#/###",
    V = "#.#/#.#/#.#/#.#/.#.", W = "#.#/#.#/###/###/#.#", X = "#.#/#.#/.#./#.#/#.#",
    Y = "#.#/#.#/.#./.#./.#.", Z = "###/..#/.#./#../###",
    [" "] = ".../.../.../.../...", ["-"] = ".../.../###/.../...",
    ["/"] = "..#/..#/.#./#../#..", ["."] = ".../.../.../.../.#.",
    ["_"] = ".../.../.../.../###", [":"] = ".../.#./.../.#./...",
    ["("] = ".#./#../#../#../.#.", [")"] = ".#./..#/..#/..#/.#.",
    [","] = ".../.../.../.#./#..", ["+"] = ".../.#./###/.#./...",
}
-- }}}

-- {{{ local function day_number(text)
-- "YYYY-MM-DD" to a whole number of days, so subtracting two gives the days
-- between them. Noon avoids a daylight-saving hour tipping a day over.
local function day_number(text)
    local year, month, day = text:match("^(%d+)-(%d+)-(%d+)$")
    return math.floor(os.time({ year = tonumber(year), month = tonumber(month),
                                day = tonumber(day), hour = 12 }) / 86400)
end
-- }}}

-- {{{ local function day_text(number)
local function day_text(number)
    return os.date("%Y-%m-%d", number * 86400 + 43200)
end
-- }}}

-- {{{ local function new_canvas(width, height)
-- The picture as one flat run of bytes, three per pixel, rows from the top:
-- the layout png-writer expects, so no copy is made before encoding.
local function new_canvas(width, height)
    local pixels = ffi.new("uint8_t[?]", width * height * 3)
    local canvas = { width = width, height = height, pixels = pixels }
    -- {{{ canvas.fill(x, y, w, h, colour)
    function canvas.fill(x, y, w, h, colour)
        local x0, y0 = math.max(0, x), math.max(0, y)
        local x1, y1 = math.min(width, x + w), math.min(height, y + h)
        for row = y0, y1 - 1 do
            local base = row * width * 3
            for column = x0, x1 - 1 do
                local at = base + column * 3
                pixels[at], pixels[at + 1], pixels[at + 2] = colour[1], colour[2], colour[3]
            end
        end
    end
    -- }}}
    -- {{{ canvas.text(x, y, text, colour, scale, upright)
    -- upright = false writes the text rotated a quarter turn counter-clockwise,
    -- reading bottom to top, starting at (x, y) and climbing; used for project
    -- names under narrow columns.
    function canvas.text(x, y, text, colour, scale, upright)
        local advance = 4 * scale
        for index = 1, #text do
            local character = text:sub(index, index):upper()
            local glyph = glyphs[character]
            if not glyph then error("project-timeline-png: no glyph for '" .. character .. "' in " .. text) end
            local row_index = 0
            for row in glyph:gmatch("[^/]+") do
                for column_index = 0, 2 do
                    if row:sub(column_index + 1, column_index + 1) == "#" then
                        local offset = (index - 1) * advance
                        if upright then
                            canvas.fill(x + offset + column_index * scale, y + row_index * scale, scale, scale, colour)
                        else
                            -- rotated: the glyph's columns run up the page,
                            -- its rows run left to right
                            canvas.fill(x + row_index * scale, y - offset - (column_index + 1) * scale,
                                        scale, scale, colour)
                        end
                    end
                end
                row_index = row_index + 1
            end
        end
    end
    -- }}}
    return canvas
end
-- }}}

-- {{{ local function read_timeline(path)
local function read_timeline(path)
    local file = io.open(path, "r")
    if not file then
        io.stderr:write("project-timeline-png: no timeline data at " .. path
            .. " (run project-timeline-gather.lua --out=" .. path .. " first)\n")
        os.exit(1)
    end
    local text = file:read("*a")
    file:close()
    local data, _, problem = json.decode(text)
    if not data then
        io.stderr:write("project-timeline-png: " .. path .. " is not JSON: " .. tostring(problem) .. "\n")
        os.exit(1)
    end
    if #data.projects == 0 then
        io.stderr:write("project-timeline-png: " .. path .. " lists no dated projects\n")
        os.exit(1)
    end
    return data
end
-- }}}

-- {{{ local function parse_sources(list)
local function parse_sources(list)
    local wanted = {}
    for name in list:gmatch("[^,]+") do
        if name ~= "commit" and name ~= "transcript" and name ~= "sweep" then
            io.stderr:write("project-timeline-png: unknown source '" .. name .. "' (commit, transcript, sweep)\n")
            os.exit(2)
        end
        wanted[name] = true
    end
    return wanted
end
-- }}}

-- {{{ local column_placers
-- How each --x mode turns a project's birth day into a left edge. Both get the
-- projects already sorted by birth, so a placer only decides spacing.
local column_placers = {
    -- {{{ order
    order = function(projects, left, layout)
        local stride = options.column + options.gap
        for index, project in ipairs(projects) do project.x = left + (index - 1) * stride end
        layout.x_day_pixels = nil
    end,
    -- }}}
    -- {{{ time
    -- One calendar day is x_day_pixels wide; a column that would overlap its
    -- left neighbour is pushed right just far enough to stand beside it, so
    -- a burst of births on one day reads as a cluster, not a pile.
    time = function(projects, left, layout)
        local stride = options.column + options.gap
        local x_day_pixels = 3
        local next_free = left
        for _, project in ipairs(projects) do
            local wanted = left + (project.birth - layout.earliest) * x_day_pixels
            project.x = math.max(wanted, next_free)
            next_free = project.x + stride
        end
        layout.x_day_pixels = x_day_pixels
    end,
    -- }}}
}
-- }}}

-- {{{ local row_placers
-- How each --y mode turns (project, day) into a pixel row, counted up from
-- the baseline. Returns the bar's bottom and top in days-from-baseline.
local row_placers = {
    -- age: every bar starts at 0
    age = function(project, layout) return 0, layout.today - project.birth end,
    -- calendar: a bar starts at its birth day on the shared calendar
    calendar = function(project, layout)
        return project.birth - layout.earliest, layout.today - layout.earliest
    end,
}
-- }}}

-- {{{ local function draw(data)
local function draw(data)
    local place_columns = column_placers[options.x]
    local place_rows = row_placers[options.y]
    if not place_columns then io.stderr:write("project-timeline-png: --x must be order or time\n") os.exit(2) end
    if not place_rows then io.stderr:write("project-timeline-png: --y must be age or calendar\n") os.exit(2) end
    local wanted = parse_sources(options.sources)

    local layout = { today = day_number(data.today) }
    local projects = {}
    for index, entry in ipairs(data.projects) do
        local project = { name = entry.name, birth = day_number(entry.first_day), lit = {} }
        -- lit[day offset from birth] = set of sources that lit it
        for _, source in ipairs({ "commit", "transcript", "sweep" }) do
            if wanted[source] then
                for _, day in ipairs(entry[source .. "_days"]) do
                    local offset = day_number(day) - project.birth
                    project.lit[offset] = project.lit[offset] or {}
                    project.lit[offset][source] = true
                end
            end
        end
        projects[index] = project
        if not layout.earliest or project.birth < layout.earliest then layout.earliest = project.birth end
    end

    local scale = 2                          -- font pixels per glyph dot
    local advance = 4 * scale
    local longest_name = 0
    for _, project in ipairs(projects) do longest_name = math.max(longest_name, #project.name) end
    local left, top = 90, 70
    local span_days = layout.today - layout.earliest
    local plot_height = (span_days + 1) * options.day_pixels
    place_columns(projects, left, layout)
    local plot_right = projects[#projects].x + options.column
    local tick_band = 8 + 5 * scale + 8     -- tick mark, a date label, spacing
    local name_band = longest_name * advance + 10
    local width = plot_right + 40
    local height = top + plot_height + tick_band + name_band + 20
    local baseline = top + plot_height       -- first pixel row below the plot

    local canvas = new_canvas(width, height)
    canvas.fill(0, 0, width, height, palette.background)

    -- {{{ horizontal grid and Y labels
    -- age: a line every 30 days labelled "N D"; calendar: a line at each
    -- month's first day labelled with the month
    if options.y == "age" then
        for days = 0, span_days, 30 do
            local row = baseline - (days + 1) * options.day_pixels
            canvas.fill(left - 6, row, plot_right - left + 6, 1, palette.grid)
            if days % 60 == 0 then canvas.text(10, row - 4, days .. " D", palette.faint_text, scale, true) end
        end
    else
        for days = 0, span_days do
            local date = day_text(layout.earliest + days)
            if date:sub(9, 10) == "01" then
                local row = baseline - (days + 1) * options.day_pixels
                canvas.fill(left - 6, row, plot_right - left + 6, 1, palette.grid)
                canvas.text(10, row - 4, date:sub(1, 7), palette.faint_text, scale, true)
            end
        end
    end
    -- }}}

    -- {{{ bars and lit days
    local counts = { lit_days = 0, both = 0 }
    for _, project in ipairs(projects) do
        local bottom, top_day = place_rows(project, layout)
        local bar_top = baseline - (top_day + 1) * options.day_pixels
        local bar_bottom = baseline - bottom * options.day_pixels
        canvas.fill(project.x, bar_top, options.column, bar_bottom - bar_top, palette.bar)
        for offset, sources in pairs(project.lit) do
            -- a day after "today" (clock skew, a pinned --today) is outside the bar
            if offset >= 0 and bottom + offset <= top_day then
                local colour
                if sources.commit and sources.transcript then
                    colour = palette.both
                    counts.both = counts.both + 1
                elseif sources.commit then colour = palette.commit
                elseif sources.transcript then colour = palette.transcript
                else colour = palette.sweep end
                local row = baseline - (bottom + offset + 1) * options.day_pixels
                canvas.fill(project.x, row, options.column, options.day_pixels, colour)
                counts.lit_days = counts.lit_days + 1
            end
        end
    end
    -- }}}

    -- {{{ axes, X ticks, names
    canvas.fill(left - 6, baseline, plot_right - left + 6, 1, palette.axis)
    -- a tick under the first column born in each month, labelled with that month
    local last_month = nil
    local label_free_x = 0
    for _, project in ipairs(projects) do
        local month = day_text(project.birth):sub(1, 7)
        if month ~= last_month then
            canvas.fill(project.x, baseline + 1, 1, 6, palette.axis)
            -- skip the label (keep the tick) where it would overprint the last one
            if project.x >= label_free_x then
                canvas.text(project.x, baseline + 9, month, palette.faint_text, scale, true)
                label_free_x = project.x + #month * advance + advance
            end
            last_month = month
        end
    end
    local name_top = baseline + tick_band
    for _, project in ipairs(projects) do
        local name_x = project.x + math.floor((options.column - 5 * scale) / 2)
        canvas.text(name_x, name_top + #project.name * advance, project.name, palette.text, scale, false)
    end
    -- }}}

    -- {{{ title and legend
    local x_words = { order = "BIRTH ORDER", time = "BIRTH DATE" }
    local y_words = { age = "DAYS SINCE BIRTH", calendar = "CALENDAR" }
    canvas.text(left, 14, string.format("PROJECT TIMELINE  %s TO %s  %d PROJECTS",
        day_text(layout.earliest), data.today, #projects), palette.text, scale, true)
    canvas.text(left, 32, "X: " .. x_words[options.x] .. "   Y: " .. y_words[options.y],
        palette.faint_text, scale, true)
    local legend_x = left
    local legend = {
        { "commit", "COMMIT" }, { "transcript", "CONVERSATION" },
        { "both", "BOTH" }, { "sweep", "SWEEP" },
    }
    for _, item in ipairs(legend) do
        -- "both" needs commit and transcript; the others need themselves
        local shown = (item[1] == "both" and wanted.commit and wanted.transcript) or wanted[item[1]]
        if shown then
            canvas.fill(legend_x, 48, 10, 10, palette[item[1]])
            canvas.text(legend_x + 14, 49, item[2], palette.faint_text, scale, true)
            legend_x = legend_x + 14 + #item[2] * advance + 16
        end
    end
    -- }}}

    return canvas, projects, counts
end
-- }}}

-- {{{ local function main()
local function main()
    if options.help then print_help() return end
    local data = read_timeline(options.input)
    local canvas, projects, counts = draw(data)
    png.write(options.output, canvas.width, canvas.height,
              ffi.string(canvas.pixels, canvas.width * canvas.height * 3))
    print(string.format("project-timeline-png: %dx%d, %d columns, %d lit days (%d lit by both), x=%s y=%s",
        canvas.width, canvas.height, #projects, counts.lit_days, counts.both, options.x, options.y))
    print("  wrote " .. options.output)
end
-- }}}

main()
