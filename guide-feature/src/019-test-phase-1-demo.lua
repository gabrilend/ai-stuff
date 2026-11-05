#!/usr/bin/env luajit
-- 019-test-phase-1-demo.lua
--
-- Checks the scripted series (018) on its own: every canvas it makes reads
-- back as a voice's canvas, named and numbered as the blitter takes them, and
-- its mistakes are refused. Then runs the phase 1 demo twice, as the owner
-- would: once kept, to read the throwaway project it leaves, and once through
-- run-phase-demo, which must clean up after itself. Checks every version it
-- draws, the cells it marks, the refusal with the fit check's report, and the
-- receipt it shows against the blitter's own.
--
-- For a general: the demo is what the owner watches to see phase 1 work. This
-- proves the demo shows what the blitter really did, not a story about it,
-- and leaves nothing running or lying around.
--
-- usage:
--   luajit 019-test-phase-1-demo.lua [--dir ROOT]

-- {{{ DIR -- the project root, hard-coded, overridable by --dir
local DIR = "/mnt/mtwo/programming/ai-stuff/guide-feature"
for index = 1, #arg do
    if arg[index] == "--dir" then DIR = arg[index + 1] end
end
-- }}}

local ffi = require("ffi")
pcall(ffi.cdef, "int setenv(const char *name, const char *value, int overwrite);")

local series = dofile(DIR .. "/src/018-phase-1-series.lua")
local blitter = dofile(DIR .. "/src/016-blitter.lua")
local canvas = dofile(DIR .. "/src/006-canvas-text.lua")
local fit = dofile(DIR .. "/src/012-fit-check.lua")
local goodbye = dofile(DIR .. "/src/002-goodbye.lua")

local passed, failed = 0, 0

-- {{{ local function check()
local function check(name, ok, detail)
    if ok then
        passed = passed + 1
        io.write("  ok    ", name, "\n")
    else
        failed = failed + 1
        io.write("  FAIL  ", name, detail and ("\n        " .. tostring(detail)) or "", "\n")
    end
end
-- }}}

-- {{{ local function shell()
local function shell(command)
    local pipe = io.popen(command .. " 2>&1; echo \"exit:$?\"")
    local text = pipe:read("*a")
    pipe:close()
    local body, status = string.match(text, "^(.-)\n?exit:(%d+)\n$")
    return body, tonumber(status)
end
-- }}}

-- {{{ local function find()
local function has(text, piece)
    return string.find(text, piece, 1, true) ~= nil
end
-- }}}

io.write("\n=== the scripted series ===\n")
-- {{{
-- The series played against itself: each round's bases are versions the
-- rounds before would make. Only shapes are checked here; what the blitter
-- does with them is checked through the demo below.
local EMPTY = {}
for row = 1, series.HEIGHT do EMPTY[row] = "" end
local versions, latest = { [1] = EMPTY }, 1
local all, readable, named, sized = {}, true, true, true
for number = 1, #series.ROUNDS do
    for _, one in ipairs(series.arrivals(number, versions, latest)) do
        all[#all + 1] = one
        local ok, record = pcall(canvas.read, one.text, "from-voice", one.name)
        if not ok or record.headers.voice ~= one.voice or record.headers.turn ~= one.turn
            or record.headers.base ~= one.base then
            readable = false
        end
        local parts = blitter.arrival_name(one.name)
        if not parts or parts.sender ~= one.voice then named = false end
        if ok and not one.oversized and (record.width ~= series.WIDTH
            or record.height ~= series.HEIGHT) then
            sized = false
        end
        -- the next version, for the next round's bases: this canvas, if it fits
        if not one.oversized then
            latest = latest + 1
            versions[latest] = one.rows
        end
    end
end
check("six rounds, nine canvases", #series.ROUNDS == 6 and #all == 9, #all)
check("every canvas reads back as a voice's canvas with its voice, turn and base", readable)
check("every name is one the blitter takes, sent by its voice", named)
check("every canvas but the oversized one is the canvas's size", sized)

local rising, turns_rise, last_turn, previous = true, true, {}, 0
for _, one in ipairs(all) do
    local time = tonumber(blitter.arrival_name(one.name).time)
    if time <= previous then rising = false end
    previous = time
    if last_turn[one.voice] and one.turn <= last_turn[one.voice] then turns_rise = false end
    last_turn[one.voice] = one.turn
end
check("the times in the names rise through the series", rising)
check("each voice's turns rise", turns_rise)

local oversized = {}
for _, one in ipairs(all) do
    if one.oversized then oversized[#oversized + 1] = one end
end
check("exactly one canvas is oversized, wider than the canvas",
    #oversized == 1 and canvas.read(oversized[1].text, "from-voice").width > series.WIDTH)

local stale = false
for _, one in ipairs(all) do
    if one.base == 2 and one.turn == 2 then stale = true end
end
check("one canvas is made on a stale base (version 2, in a later round)", stale)

check("a round that is not there is refused", not pcall(series.arrivals, 7, versions, latest))
check("a base that is not there is refused", not pcall(series.arrivals, 2, { [1] = EMPTY }, 9))
series.ROUNDS[#series.ROUNDS + 1] = { shows = "too wide", sent = {
    { voice = "fg-sora-1", turn = 9, base = "latest", edits = {
        { "put", 1, 1, string.rep("x", series.WIDTH + 1) } } } } }
check("a canvas written past the width, not meant to be oversized, is refused",
    not pcall(series.arrivals, #series.ROUNDS, versions, latest))
series.ROUNDS[#series.ROUNDS] = nil
-- }}}

io.write("\n=== the demo, kept ===\n")
-- {{{
local TMP = shell("mktemp -d")
ffi.C.setenv("TMPDIR", TMP, 1)
local DEMO = DIR .. "/issues/completed/demos/phase-1-demo"
local out, status = shell("'" .. DEMO .. "' '" .. DIR .. "' --keep --plain")
check("it runs to the end and exits 0", status == 0, out)
local kept = string.match(out, "kept the throwaway project at (%S+)")
check("with --keep it says where its throwaway project is", kept ~= nil)

-- {{{ every version drawn
local drawn = {}
for number in string.gmatch(out, "\n  version (%d+): ") do drawn[#drawn + 1] = tonumber(number) end
check("it draws versions 1 to 8, each once, in order",
    table.concat(drawn, ",") == "1,2,3,4,5,6,7,8", table.concat(drawn, ","))
local rows_drawn, right_width = 0, true
for line in string.gmatch(out, "\n(  |[^\n]*)") do
    rows_drawn = rows_drawn + 1
    if #line ~= series.WIDTH + 4 or string.sub(line, -1) ~= "|" then right_width = false end
end
check("each drawn at the canvas's real size, every row inside its frame",
    rows_drawn == 8 * series.HEIGHT and right_width
    and has(out, "  +" .. string.rep("-", series.WIDTH) .. "+\n"), rows_drawn)
-- }}}

-- {{{ the cells marked
check("the kitten version marks the cells kitten changed and the t of sat it blanked",
    has(out, "  |the kitten  on the mat.                 |\n"
        .. "       ^^ ^^^^\n"))
check("the dog version marks dog and the ten of kitten blanked whole",
    has(out, "  |the dog     on the mat.                 |\n"
        .. "       ^^^^^^\n"))
check("a row a version did not change has no marks under it",
    has(out, "  |a dog       by the door.                |\n"
        .. "  |it was a windy day.                     |\n"))
check("plain output has no terminal highlighting in it", not has(out, "\27["))
-- }}}

-- {{{ the numbers under each version
check("the numbers for kitten: one written, one blanked whole",
    has(out, "written 1, blanked whole 1, removals 0, conflicts 0 (6 cells changed)"))
check("the numbers for the conflicting removal: two written, one conflict",
    has(out, "written 2, blanked whole 0, removals 0, conflicts 1 (7 cells changed)"))
check("the numbers for the erased word: one removal",
    has(out, "written 0, blanked whole 0, removals 1, conflicts 0 (5 cells changed)"))
check("the turn that changed nothing is said, with no version",
    has(out, "fg-sora-2's turn 3 on base 7 changed nothing: no new version"))
-- }}}

-- {{{ the refusal and the fit check's report
local refused = oversized[1]
check("the oversized canvas is refused with the blitter's own reason",
    has(out, "REFUSED fg-sora-3-")
    and has(out, "the blitter's log: wrong-size: the canvas is 47 characters wide; "
        .. "it must be exactly 40"))
local base = canvas.blank(series.WIDTH, series.HEIGHT)
local reply = {}
for number, row in ipairs(refused.rows) do reply[number] = (string.gsub(row, " +$", "")) end
local report = fit.report(fit.check(table.concat(reply, "\n") .. "\n", base,
    { words = 12, sentences = 1 }).problems, series.WIDTH, series.HEIGHT)
local quoted = string.gsub(report, "([^\n]*)\n", "    > %1\n")
check("the fit check's report is shown word for word, as the model reads it",
    has(out, quoted) and has(report, "row 4: 47 characters, 7 over the width of 40"), quoted)
-- }}}

-- {{{ the receipt, against the kept project's own
local receipt = kept and goodbye.read(kept .. "/output/goodbye-blitter")
local shown = true
if receipt then
    for counter, value in pairs(receipt.counters) do
        if not has(out, string.format("  %-22s %d\n", counter, value)) then shown = false end
    end
end
check("the receipt it shows is the blitter's own, every counter", receipt ~= nil and shown)
local c = receipt and receipt.counters or {}
check("the receipt: 9 taken, 7 made, 8 in the history",
    c["arrivals-taken"] == 9 and c["versions-made"] == 7 and c["versions-in-history"] == 8)
check("the receipt: 26 written, 2 blanked whole, 1 removal, 1 conflict",
    c["words-written"] == 26 and c["cut-blanked"] == 2 and c["removals-applied"] == 1
    and c["conflicts"] == 1)
check("the receipt: 1 refused for its size, 1 turn that changed nothing",
    c["refused-wrong-size"] == 1 and c["unchanged-turns"] == 1)
local _, agree = string.gsub(out, "   agree\n", "")
check("the log, added up, agrees with the receipt on all seven lines",
    agree == 7 and not has(out, "DISAGREE")
    and has(out, "Every number above is the blitter's own, and its log and receipt agree."))
check("the oversized canvas was put aside, not lost",
    kept ~= nil and (shell("ls '" .. kept .. "/tmp/shared-memory/arrivals-refused'"))
        == refused.name)
check("the blitter it started has ended", select(2,
    shell("pgrep -f '[l]uajit " .. (kept or "none") .. "/src/016-blitter.lua'")) ~= 0)
-- }}}
if kept then shell("rm -rf '" .. string.match(kept, "^(.*)/[^/]+$") .. "'") end
-- }}}

io.write("\n=== the demo through run-phase-demo ===\n")
-- {{{
local listed = shell("'" .. DIR .. "/run-phase-demo' '" .. DIR .. "' 9")
check("run-phase-demo offers phase 1", has(listed, "Phases with one: 1"), listed)
local again, again_status = shell("'" .. DIR .. "/run-phase-demo' '" .. DIR .. "' 1")
check("run-phase-demo runs it, plain when the output is not a terminal",
    again_status == 0 and has(again, "are marked ^ below them") and not has(again, "\27["))
check("the same series gives the same canvas every time",
    string.match(again, "  version 8:.-\n  %+%-+%+\n") == string.match(out, "  version 8:.-\n  %+%-+%+\n"))
check("without --keep, its throwaway project is removed", shell("ls -A '" .. TMP .. "'") == "")

local wrong, wrong_status = shell("'" .. DEMO .. "' '" .. TMP .. "'")
check("given a folder that is not the project, it says so and stops",
    wrong_status ~= 0 and has(wrong, "is not the guide-feature project"))
shell("rm -rf '" .. TMP .. "'")
-- }}}

io.write(string.format("\nTests: %d passed, %d failed\n", passed, failed))
os.exit(failed == 0 and 0 or 1)
