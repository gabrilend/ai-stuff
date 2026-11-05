-- 018-phase-1-series.lua - the scripted series the phase 1 demo plays.
--
-- In plain terms: three voices take turns editing one small canvas. This file
-- is the script of what they do, round by round, and the generator that turns
-- each round into the canvases the voices would send: whole canvases, with
-- their headers, named as rmail names an arrival. The script is short edits
-- (put a word here, erase one there) made on the version each voice started
-- from, so the canvases themselves are made, not written out by hand.
--
-- The series shows, in order: a first voice writing onto the empty canvas;
-- two single-word edits made on the same version, one replacing a word and
-- one erasing a word (the second lands on a
-- canvas newer than its base); a write that cuts a word, and a removal of
-- that word by another voice, which is a conflict; a voice on a stale base
-- whose write cuts a newer word, without bringing back what its old copy
-- still had; an oversized canvas, which is refused; a
-- turn that changes nothing; and a last new line.
--
--   local series = dofile(DIR .. "/src/018-phase-1-series.lua")
--   for number, round in ipairs(series.ROUNDS) do
--       local sent = series.arrivals(number, versions, latest)
--       -- sent[i].name, sent[i].text, sent[i].rows, sent[i].base, sent[i].oversized
--   end
--
-- `versions` maps a version number to its rows (as the blitter's log shows
-- them, trailing spaces dropped or not); `latest` is the newest number.
-- LuaJIT-compatible.

-- {{{ local DIR
-- Sibling files are found next to this one (as in 006).
local SOURCE = debug.getinfo(1, "S").source
local DIR = string.match(SOURCE, "^@(.+)/src/[^/]*$")
    or (string.match(SOURCE, "^@src/[^/]*$") and ".")
    or "/mnt/mtwo/programming/ai-stuff/guide-feature"
-- }}}

local utf8 = dofile(DIR .. "/src/005-utf8.lua")
local canvas = dofile(DIR .. "/src/006-canvas-text.lua")

local M = {}

-- {{{ the canvas and the voices
-- Small enough to draw beside its numbers in any terminal.
M.WIDTH, M.HEIGHT = 40, 6
M.VOICES = { "fg-sora-1", "fg-sora-2", "fg-sora-3" }
-- The demo's input/blitter: the size above, and the owner's rule.
M.SETTINGS = "canvas-size = " .. M.WIDTH .. "x" .. M.HEIGHT .. "\n"
    .. "merge-mode = \"newest\"\n"
    .. "collision-rule = \"blank-whole\"\n"
    .. "mark-lifetime = 12\n"
    .. "project = \"guide-feature\"\n"
    .. "voices = \"" .. table.concat(M.VOICES, " ") .. "\"\n"
-- input/to-voices for a throwaway project: the blitter run as a program
-- mails nothing (303).
M.TO_VOICES_OFF = "send = \"off\"\nmailbox = \"~/guide-mail\"\ntell-the-voice = \"off\"\n"
    .. "project-checkout = \".\"\n"
-- The first arrival's time in its name; each later one is a second after.
M.FIRST_TIME = 1793000000
-- }}}

-- {{{ M.ROUNDS
-- Each round: what it shows, and the canvases sent in it, in the order sent.
-- A canvas is a voice, its turn, its base ("latest" for the newest version
-- when the round starts, or a version's number) and its edits on that base,
-- in order: { "put", row, column, text } writes text over what is there;
-- { "erase", row, column, length } blanks cells. `oversized` makes the canvas
-- as wide as its widest row instead of the canvas's width.
M.ROUNDS = {
    {
        shows = "a voice writes onto the empty canvas",
        sent = {
            { voice = "fg-sora-1", turn = 1, base = "latest", edits = {
                { "put", 1, 1, "the cat sat on the mat." },
                { "put", 2, 1, "a dog slept by the door." },
                { "put", 3, 1, "it was a quiet day." },
            } },
        },
    },
    {
        shows = "two single-word edits made on the same version, a word replaced "
            .. "and a word erased; the second lands on a newer canvas than its "
            .. "base and keeps the first",
        sent = {
            { voice = "fg-sora-2", turn = 1, base = "latest", edits = {
                { "put", 3, 10, "windy" },
            } },
            { voice = "fg-sora-3", turn = 1, base = "latest", edits = {
                { "erase", 2, 7, 5 },
            } },
        },
    },
    {
        shows = "a longer word cuts the next one, which is blanked whole; another "
            .. "voice, on the same base, erased that word: a conflict",
        sent = {
            { voice = "fg-sora-1", turn = 2, base = "latest", edits = {
                { "put", 1, 5, "kitten " },
            } },
            { voice = "fg-sora-2", turn = 2, base = "latest", edits = {
                { "erase", 1, 9, 3 },
                { "put", 5, 1, "the end." },
            } },
        },
    },
    {
        shows = "a voice still on version 2 writes dog over cat: only its own "
            .. "change lands, so dog cuts kitten, which is blanked whole, and the "
            .. "sat its old copy still had is not brought back",
        sent = {
            { voice = "fg-sora-3", turn = 2, base = 2, edits = {
                { "put", 1, 5, "dog" },
            } },
        },
    },
    {
        shows = "an oversized canvas is refused",
        sent = {
            { voice = "fg-sora-3", turn = 3, base = "latest", oversized = true, edits = {
                { "put", 4, 1, "and then a very long sentence ran off the edge." },
            } },
        },
    },
    {
        shows = "a turn that changes nothing, then a last new line",
        sent = {
            { voice = "fg-sora-2", turn = 3, base = "latest", edits = {} },
            { voice = "fg-sora-1", turn = 3, base = "latest", edits = {
                { "put", 4, 1, "and then it rained." },
            } },
        },
    },
}
-- }}}

-- {{{ local function edit()
-- A base's rows, as grids of characters at least `width` wide, with the
-- edits made. Returns the rows as text.
local function edit(rows, edits, width)
    local grid = {}
    for number = 1, M.HEIGHT do
        local characters = utf8.split(rows[number] or "")
        if not characters then
            error("series: row " .. number .. " of the base is not valid UTF-8", 3)
        end
        grid[number] = characters
    end
    for _, step in ipairs(edits) do
        local kind, row, column = step[1], step[2], step[3]
        local line = grid[row]
        if kind == "put" then
            for offset, character in ipairs(utf8.split(step[4])) do
                line[column + offset - 1] = character
            end
        elseif kind == "erase" then
            for at = column, column + step[4] - 1 do line[at] = " " end
        else
            error("series: no edit called '" .. tostring(kind) .. "'", 3)
        end
        for at = 1, #line do line[at] = line[at] or " " end
    end
    local widest = width
    for number = 1, M.HEIGHT do widest = math.max(widest, #grid[number]) end
    local out = {}
    for number = 1, M.HEIGHT do
        local line = grid[number]
        for at = #line + 1, widest do line[at] = " " end
        out[number] = table.concat(line)
    end
    return out, widest
end
-- }}}

-- {{{ function M.arrivals()
-- The canvases sent in round `number`: { name, text, rows, base, voice, turn,
-- oversized }, in the order sent. Each is a from-voice canvas (006), named
-- <sender>-<unix time>-<random> (302) with times that rise through the series.
function M.arrivals(number, versions, latest)
    local round = M.ROUNDS[number]
    if not round then
        error("series: there is no round " .. tostring(number), 2)
    end
    local before = 0
    for earlier = 1, number - 1 do before = before + #M.ROUNDS[earlier].sent end

    local out = {}
    for index, spec in ipairs(round.sent) do
        local base = spec.base == "latest" and latest or spec.base
        local base_rows = versions[base]
        if not base_rows then
            error("series: round " .. number .. " needs version " .. tostring(base)
                .. ", which is not there", 2)
        end
        local rows, widest = edit(base_rows, spec.edits, M.WIDTH)
        local width = spec.oversized and widest or M.WIDTH
        if not spec.oversized and widest > M.WIDTH then
            error("series: round " .. number .. " writes past the canvas's width", 2)
        end

        local record = canvas.blank(width, M.HEIGHT, "from-voice")
        local time = M.FIRST_TIME + before + index - 1
        record.headers = { voice = spec.voice, turn = spec.turn, base = base,
                           written = os.date("!%Y-%m-%dT%H:%M:%SZ", time) }
        record.rows = rows
        out[index] = {
            name = string.format("%s-%d-r%ds%d", spec.voice, time, number, index),
            text = canvas.write(record), rows = rows, base = base,
            voice = spec.voice, turn = spec.turn, oversized = spec.oversized or false,
        }
    end
    return out
end
-- }}}

return M
