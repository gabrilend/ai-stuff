-- phase-1-demo.lua - the body of phase-1-demo: three voices on one canvas.
--
-- phase-1-demo makes a throwaway project and runs this in it. This plays the
-- scripted series (src/018-phase-1-series.lua) into the real blitter's
-- arrivals folder, round by round, and draws what the blitter did: each
-- version at its real size with the cells it changed highlighted, the
-- blitter's own numbers for it, any refusal with the fit check's report as a
-- model would read it, and the goodbye receipt. Every number shown is read
-- from the blitter's log and receipt, never worked out here, and the last
-- lines check that the two agree.
--
-- usage (phase-1-demo does this):
--   luajit phase-1-demo.lua --dir PROJECT --root THROWAWAY --base TEMP [--plain]
-- --plain marks changed cells with ^ on a line below instead of highlighting
-- them; it is used whenever the output is not a terminal.

-- {{{ arguments
local DIR, ROOT, BASE, PLAIN
for index = 1, #arg do
    if arg[index] == "--dir" then DIR = arg[index + 1] end
    if arg[index] == "--root" then ROOT = arg[index + 1] end
    if arg[index] == "--base" then BASE = arg[index + 1] end
    if arg[index] == "--plain" then PLAIN = true end
end
if not (DIR and ROOT and BASE) then
    io.stderr:write("usage: luajit phase-1-demo.lua --dir PROJECT --root THROWAWAY "
        .. "--base TEMP [--plain]\n")
    os.exit(2)
end
-- }}}

local ffi = require("ffi")
pcall(ffi.cdef, "int poll(void *fds, unsigned long nfds, int timeout);")
pcall(ffi.cdef, "int isatty(int fd);")
if not PLAIN and ffi.C.isatty(1) == 0 then PLAIN = true end
if os.getenv("NO_COLOR") and os.getenv("NO_COLOR") ~= "" then PLAIN = true end

local series = dofile(ROOT .. "/src/018-phase-1-series.lua")
local fit = dofile(ROOT .. "/src/012-fit-check.lua")
local canvas = dofile(ROOT .. "/src/006-canvas-text.lua")
local goodbye = dofile(ROOT .. "/src/002-goodbye.lua")
local utf8 = dofile(ROOT .. "/src/005-utf8.lua")

local ARRIVALS = ROOT .. "/tmp/shared-memory/arrivals"
local LOG = ROOT .. "/tmp/shared-memory/blitter.log"
local RECEIPT = ROOT .. "/output/goodbye-blitter"
local W, H = series.WIDTH, series.HEIGHT

-- {{{ small helpers
local function shell(command)
    local pipe = io.popen(command .. " 2>&1")
    local text = pipe:read("*a")
    pipe:close()
    return (string.gsub(text, "\n$", ""))
end
local function quote(text)
    return "'" .. string.gsub(text, "'", "'\\''") .. "'"
end
local function exists(path)
    local handle = io.open(path, "r")
    if handle then handle:close() end
    return handle ~= nil
end
local function write(path, text)
    local handle = assert(io.open(path, "w"))
    handle:write(text)
    handle:close()
end
local function wait_until(test, seconds, what)
    for _ = 1, seconds * 20 do
        if test() then return end
        ffi.C.poll(nil, 0, 50)
    end
    if not test() then
        io.stderr:write("phase-1-demo: gave up waiting for " .. what .. "\n")
        os.exit(1)
    end
end
local function say(...) io.write(...) io.write("\n") end
-- A long line of prose, wrapped to the width of the drawing.
local function say_wrapped(text, indent)
    local line = ""
    for word in string.gmatch(text, "%S+") do
        if #line > 0 and #line + 1 + #word > 76 then
            say(line)
            line = indent .. word
        else
            line = #line > 0 and (line .. " " .. word) or word
        end
    end
    say(line)
end
-- }}}

-- {{{ the log, read as it grows
local log_offset = 0
local function new_log_lines()
    local handle = io.open(LOG, "r")
    if not handle then return {} end
    handle:seek("set", log_offset)
    local text = handle:read("*a")
    handle:close()
    -- only whole lines: a line still being written waits for the next read
    local whole = string.match(text, "^(.*\n)") or ""
    log_offset = log_offset + #whole
    local lines = {}
    for line in string.gmatch(whole, "([^\n]*)\n") do
        lines[#lines + 1] = string.match(line, "^%S+ (.*)$") or line
    end
    return lines
end
-- }}}

-- {{{ drawing
local versions = {}      -- version number -> rows, as the log shows them
local latest = 0
local sent_by_name = {}  -- arrival name -> what the series sent
local totals = { written = 0, removed = 0, conflicts = 0, cut = 0, versions = 0,
                 refused = 0, unchanged = 0 }
local rule

local function cells(row)
    local characters = utf8.split(row) or {}
    for column = #characters + 1, W do characters[column] = " " end
    return characters
end

local function draw(number)
    local now, before = versions[number], versions[number - 1]
    local edge = "  +" .. string.rep("-", W) .. "+"
    say(edge)
    local changed_cells = 0
    for row = 1, H do
        local here = cells(now[row])
        local there = before and cells(before[row]) or nil
        local out, marks, any = {}, {}, false
        for column = 1, W do
            local changed = there ~= nil and here[column] ~= there[column]
            if changed then
                changed_cells = changed_cells + 1
                any = true
            end
            if changed and not PLAIN then
                out[column] = "\27[7m" .. here[column] .. "\27[0m"
            else
                out[column] = here[column]
            end
            marks[column] = changed and "^" or " "
        end
        say("  |", table.concat(out), "|")
        if PLAIN and any then
            say("   ", (string.gsub(table.concat(marks), " +$", "")))
        end
    end
    say(edge)
    return changed_cells
end
-- }}}

-- {{{ reading what the blitter did
-- Goes through new log lines in order: a refusal, a turn's summary, a
-- version's rows. Draws each version once all its rows are in.
local pending_version, pending_rows, pending_summary
local function show_log()
    for _, line in ipairs(new_log_lines()) do
        local name, reason, detail = string.match(line, "^refused (%S+) %(([%w%-]+)%): (.*)$")
        local row = string.match(line, "^| ?(.*)$")
        local version = string.match(line, "^version (%d+):$")
        if name then
            totals.refused = totals.refused + 1
            say("")
            say("  REFUSED ", name)
            say("  the blitter's log: ", reason, ": ", detail)
            local sent = sent_by_name[name]
            if sent and reason == "wrong-size" then
                -- what the voice's model is told, from the canvas it wrote
                local reply = {}
                for number, text in ipairs(sent.rows) do
                    reply[number] = (string.gsub(text, " +$", ""))
                end
                local base = canvas.blank(W, H)
                for number, text in ipairs(versions[sent.base]) do base.rows[number] = text end
                local result = fit.check(table.concat(reply, "\n") .. "\n", base,
                    { words = 12, sentences = 1 })
                say("  the fit check's report, exactly as the model reads it:")
                say("")
                io.write((string.gsub(fit.report(result.problems, W, H), "([^\n]*)\n",
                    "    > %1\n")))
            end
        elseif version then
            pending_version, pending_rows = tonumber(version), {}
        elseif row and pending_version then
            pending_rows[#pending_rows + 1] = row
            if #pending_rows == H then
                local number = pending_version
                versions[number], latest = pending_rows, number
                pending_version = nil
                totals.versions = totals.versions + 1
                say("")
                if pending_summary then
                    say(string.format("  version %d: %s's turn %d on base %d",
                        number, pending_summary.voice, pending_summary.turn, pending_summary.base))
                else
                    say(string.format("  version %d: the empty canvas the blitter starts with",
                        number))
                end
                local changed = draw(number)
                if pending_summary then
                    local s = pending_summary
                    -- under blank-whole every cut word is blanked whole
                    say(string.format("  written %d, %s %d, removals %d, conflicts %d "
                        .. "(%d cells changed)", s.written,
                        rule == "blank-whole" and "blanked whole" or ("cut under " .. tostring(rule)),
                        s.cut, s.removed, s.conflicts, changed))
                end
                pending_summary = nil
            end
        else
            local turn_name, turn, base, written, removed, conflicts, cut, rest = string.match(line,
                "^(%S+): turn (%d+) on base (%d+), (%d+) written, (%d+) removed, "
                .. "(%d+) conflicts, (%d+) cut; (.*)$")
            if turn_name then
                local s = { voice = string.match(turn_name, "^(.-)%-%d+%-%w+$"),
                            turn = tonumber(turn), base = tonumber(base),
                            written = tonumber(written), removed = tonumber(removed),
                            conflicts = tonumber(conflicts), cut = tonumber(cut) }
                totals.written = totals.written + s.written
                totals.removed = totals.removed + s.removed
                totals.conflicts = totals.conflicts + s.conflicts
                totals.cut = totals.cut + s.cut
                if rest == "nothing changed" then
                    totals.unchanged = totals.unchanged + 1
                    say("")
                    say(string.format("  %s's turn %d on base %d changed nothing: "
                        .. "no new version", s.voice, s.turn, s.base))
                else
                    pending_summary = s
                end
            end
            local named_rule = string.match(line, "collision rule ([%w%-]+)")
            if named_rule then rule = named_rule end
        end
    end
end
-- }}}

-- {{{ starting the blitter
write(ROOT .. "/input/blitter", series.SETTINGS)
write(ROOT .. "/input/to-voices", series.TO_VOICES_OFF)
local pid = shell("cd " .. quote(ROOT) .. " && (scripts/run-blitter " .. quote(ROOT)
    .. " > " .. quote(BASE .. "/blitter.out") .. " 2>&1 & echo $!)")
write(BASE .. "/blitter.pid", pid .. "\n")

say("Phase 1 demo: three voices on one canvas")
say("")
say_wrapped(string.format("The real blitter (src/016-blitter.lua, through "
    .. "scripts/run-blitter) runs on a %dx%d canvas. Each round drops voice canvases "
    .. "into its arrivals folder, as rmail would; what follows is read back from its "
    .. "log. Cells a version changed are %s. Under each version: words written, "
    .. "words blanked whole by the collision rule, removals applied, and conflicts "
    .. "(removals of a word no longer there).", W, H,
    PLAIN and "marked ^ below them" or "highlighted"), "")
wait_until(function()
    local handle = io.open(LOG, "r")
    local text = handle and handle:read("*a") or ""
    if handle then handle:close() end
    return string.find(text, "now version 1\n", 1, true) ~= nil
        and select(2, string.gsub(text, "\n%S+ |[^\n]*", "")) >= H
end, 10, "the blitter to start")
show_log()
say("")
say("  the blitter's collision rule: ", rule or "(not in its log)")
-- }}}

-- {{{ the rounds
for number, round in ipairs(series.ROUNDS) do
    local sent = series.arrivals(number, versions, latest)
    say("")
    say(string.rep("=", W + 4))
    say_wrapped(string.format("round %d: %s", number, round.shows), "  ")
    for _, one in ipairs(sent) do
        sent_by_name[one.name] = one
        say(string.format("  %s sends turn %d on base %d%s", one.voice, one.turn, one.base,
            one.oversized and string.format(" (%d characters wide)", utf8.length(one.rows[1]))
                or ""))
        -- written under a dot name and renamed, as the rmail hook does
        write(ARRIVALS .. "/." .. one.name, one.text)
        assert(os.rename(ARRIVALS .. "/." .. one.name, ARRIVALS .. "/" .. one.name))
    end
    wait_until(function()
        for _, one in ipairs(sent) do
            if exists(ARRIVALS .. "/" .. one.name) then return false end
        end
        return true
    end, 10, "the blitter to take round " .. number)
    -- the last version's rows are logged just after the arrival is gone
    ffi.C.poll(nil, 0, 200)
    show_log()
end
-- }}}

-- {{{ the goodbye
say("")
say(string.rep("=", W + 4))
say("stopping the blitter with its stop file")
write(ARRIVALS .. "/stop", "")
wait_until(function() return exists(RECEIPT) end, 10, "the goodbye receipt")
show_log()
local receipt = goodbye.read(RECEIPT)
say("")
say("its goodbye receipt (output/goodbye-blitter):")
local names = {}
for counter in pairs(receipt.counters) do names[#names + 1] = counter end
table.sort(names)
for _, counter in ipairs(names) do
    say(string.format("  %-22s %d", counter, receipt.counters[counter]))
end

-- the log, added up, against the receipt
local c = receipt.counters
local checks = {
    { "words written", totals.written, c["words-written"] or 0 },
    { "removals", totals.removed, c["removals-applied"] or 0 },
    { "conflicts", totals.conflicts, c["conflicts"] or 0 },
    { "cut words", totals.cut, (c["cut-blanked"] or 0) + (c["cut-kept"] or 0) },
    { "versions", totals.versions, c["versions-in-history"] or 0 },
    { "turns that changed nothing", totals.unchanged, c["unchanged-turns"] or 0 },
}
local refused = 0
for counter, value in pairs(c) do
    if string.match(counter, "^refused%-") then refused = refused + value end
end
checks[#checks + 1] = { "refusals", totals.refused, refused }
say("")
say("the log, added up, against the receipt:")
local agree = true
for _, check in ipairs(checks) do
    local same = check[2] == check[3]
    agree = agree and same
    say(string.format("  %-28s log %3d   receipt %3d   %s", check[1], check[2], check[3],
        same and "agree" or "DISAGREE"))
end
say("")
say(agree and "Every number above is the blitter's own, and its log and receipt agree."
    or "The log and the receipt DISAGREE.")
os.exit(agree and 0 or 1)
-- }}}
