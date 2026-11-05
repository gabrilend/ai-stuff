-- phase-2-demo.lua - the body of phase-2-demo: the canvas for viewers.
--
-- phase-2-demo makes a throwaway project and runs this in it. This starts
-- the real blitter, then the real canvas server on 127.0.0.1 and a free port,
-- then two readers (phase-2-file-reader.lua on the canvas files,
-- phase-2-http-reader.lua holding GET /canvas?after= on the server). It plays
-- the phase 1 series into the blitter round by round, with marks lasting
-- three versions so they can be seen to age and expire, and for each version
-- shows:
--   - the canvas, its marks coloured by voice and dimmed by age (or, plain,
--     letters under each row: the voice's number for a word mark, its letter
--     for a sentence mark);
--   - the blitter's own mark numbers for it, and the marks on it by age;
--   - how long it took to reach each reader, and whether the two copies are
--     byte for byte the same as each other and as canvas/history.
-- It ends with each program's numbers, checked against each other. Mark
-- numbers come from the blitter's log and receipt, request numbers from the
-- server's receipt and the HTTP reader's own count, never worked out here.
--
-- usage (phase-2-demo does this):
--   luajit phase-2-demo.lua --dir PROJECT --root THROWAWAY --base TEMP [--plain]

-- {{{ arguments
local DIR, ROOT, BASE, PLAIN
for index = 1, #arg do
    if arg[index] == "--dir" then DIR = arg[index + 1] end
    if arg[index] == "--root" then ROOT = arg[index + 1] end
    if arg[index] == "--base" then BASE = arg[index + 1] end
    if arg[index] == "--plain" then PLAIN = true end
end
if not (DIR and ROOT and BASE) then
    io.stderr:write("usage: luajit phase-2-demo.lua --dir PROJECT --root THROWAWAY "
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
local viewer = dofile(ROOT .. "/src/022-viewer.lua")
local goodbye = dofile(ROOT .. "/src/002-goodbye.lua")

local SHM = ROOT .. "/tmp/shared-memory"
local ARRIVALS = SHM .. "/arrivals"
local HISTORY = SHM .. "/canvas/history"
local W, H = series.WIDTH, series.HEIGHT
-- Marks last three versions here, not the series' twelve, so the eight
-- versions show them age and expire.
local LIFETIME = 3
local READERS = { files = BASE .. "/readers/files", http = BASE .. "/readers/http" }

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
local function slurp(path)
    local handle = io.open(path, "rb")
    if not handle then return nil end
    local text = handle:read("*a")
    handle:close()
    return text
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
        io.stderr:write("phase-2-demo: gave up waiting for " .. what .. "\n")
        os.exit(1)
    end
end
local function say(...) io.write(...) io.write("\n") end
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
local function start(command, name)
    local pid = shell("(" .. command .. " > " .. quote(BASE .. "/" .. name .. ".out")
        .. " 2>&1 & echo $!)")
    write(BASE .. "/" .. name .. ".pid", pid .. "\n")
end
-- }}}

-- {{{ what each reader received
-- OUT/received: "<version> <how> <time>" per version.
local function received(which)
    local out = {}
    for line in string.gmatch(slurp(READERS[which] .. "/received") or "", "[^\n]+") do
        local version, how, at = string.match(line, "^(%d+) (%S+) ([%d%.]+)$")
        if version then
            out[tonumber(version)] = { how = how, at = tonumber(at) }
        else
            out.unreadable = (out.unreadable or 0) + 1
        end
    end
    return out
end
-- When the blitter wrote a version: its history file's time, to the
-- nanosecond the file system keeps.
local function written_at(version)
    return tonumber(shell("stat -c %.9Y " .. quote(string.format("%s/%06d", HISTORY, version))))
end
-- }}}

-- {{{ the blitter's log, read as it grows
local log_offset = 0
local function new_log_lines(path)
    local handle = io.open(path, "r")
    if not handle then return {} end
    handle:seek("set", log_offset)
    local text = handle:read("*a")
    handle:close()
    local whole = string.match(text, "^(.*\n)") or ""
    log_offset = log_offset + #whole
    local lines = {}
    for line in string.gmatch(whole, "([^\n]*)\n") do
        lines[#lines + 1] = string.match(line, "^%S+ (.*)$") or line
    end
    return lines
end

local rows_of = {}       -- version -> rows, for the series to build on
local latest = 0
local events = {}        -- what to show, in the log's order, not shown yet
local made_by = {}       -- version -> { voice, turn, base }
local marks_of = {}      -- version -> { word, sentence, expired, runs }
local totals = { word = 0, sentence = 0, expired = 0, refused = 0, unchanged = 0 }
local pending_version, pending_rows, last_made

local function read_log()
    for _, line in ipairs(new_log_lines(SHM .. "/blitter.log")) do
        local version = string.match(line, "^version (%d+):$")
        local row = string.match(line, "^| ?(.*)$")
        local name, reason, detail = string.match(line, "^refused (%S+) %(([%w%-]+)%): (.*)$")
        local voice, turn, base, made = string.match(line,
            "^(%S+)%-%d+%-%w+: turn (%d+) on base (%d+), .-; now version (%d+)$")
        local word, sentence, expired, runs = string.match(line,
            "^marks: (%d+) cells word, (%d+) cells sentence, (%d+) expired, (%d+) runs$")
        if version then
            pending_version, pending_rows = tonumber(version), {}
        elseif row and pending_version then
            pending_rows[#pending_rows + 1] = row
            if #pending_rows == H then
                rows_of[pending_version], latest = pending_rows, pending_version
                events[#events + 1] = { version = pending_version }
                pending_version = nil
            end
        elseif name then
            totals.refused = totals.refused + 1
            events[#events + 1] = { text = string.format("%s's canvas was refused (%s): %s",
                string.match(name, "^(.-)%-%d+%-%w+$") or name, reason, detail) }
        elseif voice then
            last_made = tonumber(made)
            made_by[last_made] = { voice = voice, turn = tonumber(turn), base = tonumber(base) }
        elseif word and last_made then
            marks_of[last_made] = { word = tonumber(word), sentence = tonumber(sentence),
                                    expired = tonumber(expired), runs = tonumber(runs) }
            totals.word = totals.word + tonumber(word)
            totals.sentence = totals.sentence + tonumber(sentence)
            totals.expired = totals.expired + tonumber(expired)
        elseif string.match(line, "; nothing changed$") then
            totals.unchanged = totals.unchanged + 1
            local who, which = string.match(line, "^(%S+)%-%d+%-%w+: turn (%d+)")
            events[#events + 1] = { text = string.format("%s's turn %s changed nothing: "
                .. "no new version", who or "a voice", which or "?") }
        end
    end
end
-- }}}

-- {{{ drawing a version with its marks
-- A voice's colour: red, green, blue, then others, as 256-colour cube
-- steps (0 to 5 each) at full strength.
local HUES = { { 5, 1, 1 }, { 1, 5, 1 }, { 1, 2, 5 }, { 5, 4, 0 }, { 4, 1, 5 }, { 0, 5, 5 } }
local function shade(place, strength)
    local hue = HUES[((place or 1) - 1) % #HUES + 1]
    local function step(value) return math.floor(value * strength + 0.5) end
    return 16 + 36 * step(hue[1]) + 6 * step(hue[2]) + step(hue[3])
end
-- How strongly a mark is drawn: a word mark twice a sentence mark, fading
-- with age to a quarter just before it expires.
local function strength(mark)
    local fade = 1 - 0.75 * (mark.age / LIFETIME)
    return (mark.kind == "word" and 1 or 0.5) * fade
end

local function draw(view)
    local edge = "  +" .. string.rep("-", W) .. "+"
    say(edge)
    local by_age = {}
    for row = 1, view.height do
        local out, under, any = {}, {}, false
        for column = 1, view.width do
            local cell = view.cells[row][column]
            local mark = cell.mark
            if mark then
                any = true
                by_age[mark.age] = (by_age[mark.age] or 0) + 1
                local place = viewer.colour_of(view, mark.voice)
                if PLAIN then
                    under[column] = place and (mark.kind == "word" and tostring(place)
                        or string.char(96 + place)) or "?"
                    out[column] = cell.character
                else
                    out[column] = string.format("\27[48;5;%d;38;5;231m%s\27[0m",
                        shade(place, strength(mark)), cell.character)
                    under[column] = " "
                end
            else
                out[column] = cell.character
                under[column] = " "
            end
        end
        say("  |", table.concat(out), "|")
        if PLAIN and any then
            say("   ", (string.gsub(table.concat(under), " +$", "")))
        end
    end
    say(edge)
    return by_age
end
-- }}}

-- {{{ showing a version
local latency = { files = {}, http = {} }
local how_counts = { files = {}, http = {} }
local all_identical, shown_versions = true, 0
local before_readers = true   -- versions there before the readers started

local function seconds(value) return string.format("%.0f ms", value * 1000) end

local function show_version(number)
    local name = string.format("%06d", number)
    local history = slurp(HISTORY .. "/" .. name)
    local copies = { files = slurp(READERS.files .. "/" .. name),
                     http = slurp(READERS.http .. "/" .. name) }
    local view = viewer.read(copies.files, "the files reader's copy of version " .. number)
    local identical = copies.files == copies.http and copies.files == history
    all_identical = all_identical and identical
    shown_versions = shown_versions + 1
    say("")
    local by = made_by[number]
    if by then
        say(string.format("  version %d: %s's turn %d on base %d", number, by.voice, by.turn,
            by.base))
    else
        say(string.format("  version %d: the empty canvas the blitter starts with", number))
    end
    local by_age = draw(view)
    local m = marks_of[number]
    if m then
        say(string.format("  marks made: %d cells word, %d cells sentence; %d expired",
            m.word, m.sentence, m.expired))
    end
    local ages = {}
    for age = 0, LIFETIME do
        if by_age[age] then ages[#ages + 1] = string.format("age %d: %d", age, by_age[age]) end
    end
    say("  marks on the canvas by age: ", #ages > 0 and table.concat(ages, ", ") or "none")
    local at = written_at(number)
    local parts = {}
    for _, which in ipairs({ "files", "http" }) do
        local got = received(which)[number]
        local took = got.at - at
        if not before_readers then latency[which][#latency[which] + 1] = took end
        how_counts[which][got.how] = (how_counts[which][got.how] or 0) + 1
        parts[#parts + 1] = string.format("%s reader %s (%s)",
            which == "files" and "files" or "HTTP", seconds(took), got.how)
    end
    say("  reached the ", table.concat(parts, ", the "),
        before_readers and "; it was there before the readers started" or "")
    say(string.format("  the two copies and canvas/history: %s, %d bytes",
        identical and "byte for byte the same" or "DIFFERENT", #copies.files))
end
-- }}}

-- {{{ starting the blitter, the server and the readers
write(ROOT .. "/input/blitter", (string.gsub(series.SETTINGS, "mark%-lifetime = %d+",
    "mark-lifetime = " .. LIFETIME)))
write(ROOT .. "/input/to-voices", series.TO_VOICES_OFF)
write(ROOT .. "/input/canvas-server", table.concat({
    'listen-address = "127.0.0.1"', "port = 0", "max-connections = 8",
    "max-request-bytes = 4096", "request-seconds = 5", "wait-seconds = 60",
    "check-seconds = 0.05", 'local-addresses = "127.0.0.1"', "" }, "\n"))

say("Phase 2 demo: the canvas for viewers")
say("")
say_wrapped(string.format("The real blitter runs the phase 1 series on a %dx%d canvas, "
    .. "with marks lasting %d versions. The real canvas server serves its canvas files "
    .. "on 127.0.0.1. Two readers watch: one reads the files in RAM, one holds "
    .. "GET /canvas?after= requests on the server. Each version below is drawn from the "
    .. "readers' copies, its marks %s. A word mark is drawn stronger than a sentence "
    .. "mark, and marks fade as they age.", W, H, LIFETIME,
    PLAIN and "as letters under each row (the voice's number for a word mark, its "
        .. "letter for a sentence mark)" or "coloured by voice"), "")
say("")
for place, voice in ipairs(series.VOICES) do
    if PLAIN then
        say(string.format("  %s: word marks %d, sentence marks %s", voice, place,
            string.char(96 + place)))
    else
        say(string.format("  %s: word marks \27[48;5;%dm   \27[0m, sentence marks "
            .. "\27[48;5;%dm   \27[0m, fading", voice, shade(place, 1), shade(place, 0.5)))
    end
end

start("cd " .. quote(ROOT) .. " && scripts/run-blitter " .. quote(ROOT), "blitter")
wait_until(function()
    read_log()
    return latest >= 1
end, 10, "the blitter to start")

start("cd " .. quote(ROOT) .. " && scripts/run-canvas-server " .. quote(ROOT), "canvas-server")
local PORT
wait_until(function()
    PORT = string.match(slurp(SHM .. "/canvas-server.log") or "",
        "listening on 127%.0%.0%.1:(%d+)")
    return PORT ~= nil
end, 10, "the canvas server to start")

local READER_DIR = DIR .. "/issues/completed/demos"
start("luajit " .. quote(READER_DIR .. "/phase-2-file-reader.lua") .. " --root " .. quote(ROOT)
    .. " --out " .. quote(READERS.files), "files-reader")
start("luajit " .. quote(READER_DIR .. "/phase-2-http-reader.lua") .. " --root " .. quote(ROOT)
    .. " --out " .. quote(READERS.http) .. " --port " .. PORT, "http-reader")

local function both_have(version)
    return received("files")[version] ~= nil and received("http")[version] ~= nil
end
local function show_events()
    wait_until(function() return both_have(latest) end, 10,
        "both readers to receive version " .. latest)
    for _, event in ipairs(events) do
        if event.version then
            show_version(event.version)
        else
            say("")
            say("  ", event.text)
        end
    end
    events = {}
end
say("")
say("  the canvas server is on 127.0.0.1:" .. PORT)
show_events()
before_readers = false
-- }}}

-- {{{ the rounds
for number, round in ipairs(series.ROUNDS) do
    local sent = series.arrivals(number, rows_of, latest)
    say("")
    say(string.rep("=", W + 4))
    say_wrapped(string.format("round %d: %s", number, round.shows), "  ")
    for _, one in ipairs(sent) do
        write(ARRIVALS .. "/." .. one.name, one.text)
        assert(os.rename(ARRIVALS .. "/." .. one.name, ARRIVALS .. "/" .. one.name))
    end
    wait_until(function()
        for _, one in ipairs(sent) do
            if exists(ARRIVALS .. "/" .. one.name) then return false end
        end
        return true
    end, 10, "the blitter to take round " .. number)
    ffi.C.poll(nil, 0, 200)
    read_log()
    show_events()
end
-- }}}

-- {{{ stopping, readers first
say("")
say(string.rep("=", W + 4))
say("stopping the readers, then the server, then the blitter")
for _, folder in pairs(READERS) do write(folder .. "/stop", "") end
wait_until(function()
    return exists(READERS.files .. "/done") and exists(READERS.http .. "/done")
end, 10, "the readers to stop")
-- the server notices the HTTP reader hang up on its last held request
ffi.C.poll(nil, 0, 300)
write(SHM .. "/canvas-server.stop", "")
wait_until(function() return exists(ROOT .. "/output/goodbye-canvas-server") end, 10,
    "the canvas server's goodbye receipt")
write(ARRIVALS .. "/stop", "")
wait_until(function() return exists(ROOT .. "/output/goodbye-blitter") end, 10,
    "the blitter's goodbye receipt")
read_log()
-- }}}

-- {{{ the numbers
local function summary(list)
    local sorted = {}
    for index, value in ipairs(list) do sorted[index] = value end
    table.sort(sorted)
    if #sorted == 0 then return "none" end
    return string.format("fastest %s, median %s, slowest %s", seconds(sorted[1]),
        seconds(sorted[math.floor((#sorted + 1) / 2)]), seconds(sorted[#sorted]))
end
local function hows(which)
    local names, out = {}, {}
    for how in pairs(how_counts[which]) do names[#names + 1] = how end
    table.sort(names)
    for _, how in ipairs(names) do out[#out + 1] = how_counts[which][how] .. " " .. how end
    return table.concat(out, ", ")
end

local blitter = goodbye.read(ROOT .. "/output/goodbye-blitter").counters
local server = goodbye.read(ROOT .. "/output/goodbye-canvas-server").counters
local http_done = {}
for name, value in string.gmatch(slurp(READERS.http .. "/done") or "", "([%w%-]+) (%d+)\n") do
    http_done[name] = tonumber(value)
end
local files_got, http_got = received("files"), received("http")
local function count(list)
    local n = 0
    for key in pairs(list) do if type(key) == "number" then n = n + 1 end end
    return n
end

say("")
say("the two readers:")
say(string.format("  files reader  %d versions (%s)", count(files_got), hows("files")))
say(string.format("  HTTP reader   %d versions (%s)", count(http_got), hows("http")))
say("  from a version written to a reader holding it, for the versions made while they "
    .. "watched:")
say("    files reader  " .. summary(latency.files))
say("    HTTP reader   " .. summary(latency.http))
say("  every version both readers hold is byte for byte the same as the other's and as "
    .. "canvas/history: " .. (all_identical and "yes" or "NO"))

local names = {}
for counter in pairs(server) do names[#names + 1] = counter end
table.sort(names)
say("")
say("the canvas server's goodbye receipt (output/goodbye-canvas-server):")
for _, counter in ipairs(names) do say(string.format("  %-24s %d", counter, server[counter])) end

local requests = 0
for counter, value in pairs(server) do
    if string.match(counter, "^requests%-") then requests = requests + value end
end
local checks = {
    { "versions made, files reader", blitter["versions-in-history"] or 0, count(files_got) },
    { "versions made, HTTP reader", blitter["versions-in-history"] or 0, count(http_got) },
    { "versions shown", blitter["versions-in-history"] or 0, shown_versions },
    { "cells marked word", totals.word, blitter["cells-marked-word"] or 0 },
    { "cells marked sentence", totals.sentence, blitter["cells-marked-sentence"] or 0 },
    { "marks expired", totals.expired, blitter["marks-expired"] or 0 },
    { "requests, reader / server", http_done.requests or -1, requests },
    { "held requests answered", how_counts.http.wait or 0, server["waits-answered"] or 0 },
    { "missed versions fetched", how_counts.http.history or 0,
      server["requests-canvas-version"] or 0 },
    { "held requests timed out", http_done["answered-204"] or -1,
      server["waits-timed-out"] or 0 },
    { "requests refused", 0, (function()
        local refused = 0
        for counter, value in pairs(server) do
            if string.match(counter, "^refused%-") then refused = refused + value end
        end
        return refused
    end)() },
}
say("")
say("checked against each other (blitter log or reader / receipt):")
local agree = all_identical and not files_got.unreadable and not http_got.unreadable
for _, check in ipairs(checks) do
    local same = check[2] == check[3]
    agree = agree and same
    say(string.format("  %-30s %4d %4d   %s", check[1], check[2], check[3],
        same and "agree" or "DISAGREE"))
end
say("")
say(agree and "Both readers received every version, identical, while the marks aged; "
        .. "every number agrees."
    or "Something above DISAGREES.")
os.exit(agree and 0 or 1)
-- }}}
