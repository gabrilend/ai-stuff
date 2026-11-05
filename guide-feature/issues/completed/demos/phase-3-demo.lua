-- phase-3-demo.lua - the body of phase-3-demo: the round trip through rmail.
--
-- phase-3-demo makes a throwaway project and runs this in it. This runs the
-- rehearsal (src/043-rehearsal.lua) and draws every version as the blitter
-- makes it: the canvas with phase 2's marks (coloured by voice and dimmed
-- by age, or, plain, letters under each row: the voice's number for a word
-- mark, its letter for a sentence mark), who made it, on which base, and
-- how long that round trip took. Then, from the rehearsal's own timings,
-- events and receipt:
--   - per voice, a timeline: r a canvas received, = a turn running,
--     S a canvas sent, u a turn that changed nothing, x a canvas replaced
--     before use;
--   - the round trip from a version published to a voice's edit of it
--     blitted, as a histogram, with the leg that waits for rmail's timer
--     (the voice's canvas from finished to delivered) beside it;
--   - the canvases that waited, and the ones replaced before use;
--   - the counts from output/goodbye-rehearsal.
--
-- usage (phase-3-demo does this):
--   luajit phase-3-demo.lua --dir PROJECT --root THROWAWAY [--minutes M] [--plain]

-- {{{ arguments
local DIR, ROOT, PLAIN, MINUTES
local index = 1
while index <= #arg do
    if arg[index] == "--dir" then DIR = arg[index + 1]; index = index + 1
    elseif arg[index] == "--root" then ROOT = arg[index + 1]; index = index + 1
    elseif arg[index] == "--minutes" then MINUTES = tonumber(arg[index + 1]); index = index + 1
    elseif arg[index] == "--plain" then PLAIN = true end
    index = index + 1
end
if not (DIR and ROOT) then
    io.stderr:write("usage: luajit phase-3-demo.lua --dir PROJECT --root THROWAWAY "
        .. "[--minutes M] [--plain]\n")
    os.exit(2)
end
-- }}}

local ffi = require("ffi")
pcall(ffi.cdef, "int isatty(int fd);")
if not PLAIN and ffi.C.isatty(1) == 0 then PLAIN = true end
if os.getenv("NO_COLOR") and os.getenv("NO_COLOR") ~= "" then PLAIN = true end

local canvas = dofile(ROOT .. "/src/006-canvas-text.lua")
local viewer = dofile(ROOT .. "/src/022-viewer.lua")
local goodbye = dofile(ROOT .. "/src/002-goodbye.lua")
local settings = dofile(ROOT .. "/src/001-settings.lua")
local rehearsal = dofile(ROOT .. "/src/043-rehearsal.lua")
local blitter = dofile(ROOT .. "/src/016-blitter.lua")

local values = settings.read("rehearsal", rehearsal.SETTINGS, { root = ROOT })
local LIFETIME = settings.read("blitter", blitter.SETTINGS, { root = ROOT })["mark-lifetime"]

-- {{{ small helpers
local function plural(n, one, many) return n .. " " .. (n == 1 and one or many) end
local function say(...) io.write(...) io.write("\n") io.flush() end
local function slurp(path)
    local handle = io.open(path, "rb")
    if not handle then return nil end
    local text = handle:read("*a")
    handle:close()
    return text
end
-- }}}

-- {{{ drawing a version with its marks (as phase 2's demo draws them)
local HUES = { { 5, 1, 1 }, { 1, 5, 1 }, { 1, 2, 5 }, { 5, 4, 0 }, { 4, 1, 5 }, { 0, 5, 5 } }
local function shade(place, strength)
    local hue = HUES[((place or 1) - 1) % #HUES + 1]
    local function step(value) return math.floor(value * strength + 0.5) end
    return 16 + 36 * step(hue[1]) + 6 * step(hue[2]) + step(hue[3])
end
local function strength(mark)
    local fade = 1 - 0.75 * (mark.age / math.max(1, LIFETIME))
    return (mark.kind == "word" and 1 or 0.5) * fade
end
local marked_cells = 0
local function draw(view)
    local edge = "  +" .. string.rep("-", view.width) .. "+"
    say(edge)
    for row = 1, view.height do
        local out, under, any = {}, {}, false
        for column = 1, view.width do
            local cell = view.cells[row][column]
            local mark = cell.mark
            if mark then
                any = true
                marked_cells = marked_cells + 1
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
        if PLAIN and any then say("   ", (string.gsub(table.concat(under), " +$", ""))) end
    end
    say(edge)
end
-- }}}

-- {{{ the rehearsal, each version drawn as it is made
local minutes = MINUTES or values.minutes
say("Phase 3: the round trip through rmail")
say("")
say(string.format("The rehearsal runs for %s minutes: kuvalu's guide mailbox and three stand-in", minutes))
say("voices, made in RAM by the mailbox setup, with their hooks, turn runners and the")
say(string.format("blitter. The mail is carried by %s, on this machine only;",
    values.carrier == "stand-in" and "the stand-in carrier" or "real rmail daemons"))
if values.carrier == "stand-in" then
    say(string.format("a contact is due %s s after an exchange, give or take %s s, as rmail's timers.",
        values.pace, values.jitter))
end
local drawn = 0
local result = rehearsal.run({ root = ROOT, minutes = minutes,
    on_version = function(record, voice, b, row)
        drawn = drawn + 1
        local view = viewer.read(canvas.write(record, "for-viewers"), "version "
            .. record.headers.canvas)
        say("")
        if voice then
            local trip = row and row.published and row.blitted
                and string.format(", %.1f s after version %d was published", row.blitted
                - row.published, row.base) or ""
            say(string.format("  version %d: %s's turn %d%s", record.headers.canvas, voice,
                b.last_turn[voice], trip))
        else
            say(string.format("  version %d: the empty canvas the blitter starts with",
                record.headers.canvas))
        end
        draw(view)
    end })
-- }}}

local start = result.start
local turns = result.turns

-- {{{ round trips
say("")
say("Round trips")
say("")
local trips, waits = {}, {}
for _, r in ipairs(turns) do
    if r.version and r.published and r.blitted then
        trips[#trips + 1] = { voice = r.voice, turn = r.turn, base = r.base, version = r.version,
            seconds = r.blitted - r.published }
    end
    if r.finished and r.delivered then waits[#waits + 1] = r.delivered - r.finished end
end
table.sort(trips, function(a, b) return a.version < b.version end)
for _, t in ipairs(trips) do
    say(string.format("  version %3d from %s's turn %d on version %d: %6.1f s after version %d "
        .. "was published", t.version, t.voice, t.turn, t.base, t.seconds, t.base))
end
-- }}}

-- {{{ the histogram
local function histogram(title, list)
    say("")
    say(title)
    if #list == 0 then say("  none") return end
    local top = 0
    for _, v in ipairs(list) do top = math.max(top, v) end
    local width = 1
    for _, step in ipairs({ 1, 2, 5, 10, 15, 20, 30, 60 }) do
        width = step
        if top / step <= 12 then break end
    end
    local buckets, tallest = {}, 0
    for _, v in ipairs(list) do
        local b = math.floor(v / width)
        buckets[b] = (buckets[b] or 0) + 1
        tallest = math.max(tallest, buckets[b])
    end
    local sum = 0
    for _, v in ipairs(list) do sum = sum + v end
    table.sort(list)
    for b = 0, math.floor(top / width) do
        local n = buckets[b] or 0
        local bar = string.rep("#", math.ceil(n * 40 / tallest))
        say(string.format("  %4d-%-4d s | %-40s %d", b * width, (b + 1) * width, bar, n))
    end
    say(string.format("  %d in all; median %.1f s, mean %.1f s, longest %.1f s", #list,
        list[math.floor((#list + 1) / 2)], sum / #list, list[#list]))
end
local seconds = {}
for _, t in ipairs(trips) do seconds[#seconds + 1] = t.seconds end
histogram("Round trip, version published to the voice's edit of it blitted", seconds)
histogram("Of which waiting for rmail's timer: the voice's canvas, finished to delivered", waits)
-- }}}

-- {{{ per voice: a timeline
say("")
say("Each voice, over the rehearsal (one column is "
    .. string.format("%.1f s", math.max(1, minutes * 60) / 60)
    .. "): r received, = turn, S sent, u unchanged, x replaced")
local COLUMNS = 60
local span = math.max(1, minutes * 60)
local function column(at) return math.max(1, math.min(COLUMNS, math.floor((at - start) / span * COLUMNS) + 1)) end
for _, voice in ipairs(rehearsal.VOICES) do
    local line = {}
    for c = 1, COLUMNS do line[c] = "." end
    local taken
    for _, e in ipairs(result.events) do
        if e.voice == voice then
            if e.what == "taken" then taken = e.at
            elseif e.what == "sent" or e.what == "unchanged" or e.what == "failed" then
                if taken then
                    for c = column(taken), column(e.at) do line[c] = "=" end
                end
                line[column(e.at)] = e.what == "sent" and "S" or "u"
                taken = nil
            end
        end
    end
    for _, e in ipairs(result.events) do
        if e.voice == voice and e.what == "received" and line[column(e.at)] ~= "S" then
            line[column(e.at)] = "r"
        end
    end
    for _, e in ipairs(result.events) do
        if e.voice == voice and e.what == "replaced" then line[column(e.at)] = "x" end
    end
    local p = result.per[voice]
    say(string.format("  %-9s %s", voice, table.concat(line)))
    say(string.format("  %-9s %s received, %s run, %s sent", "",
        plural(p.received, "canvas", "canvases"), plural(p.turns, "turn", "turns"),
        plural(p.sent, "canvas", "canvases")))
end
-- }}}

-- {{{ canvases that waited, and those replaced
say("")
say("Canvases that waited (arrived while the voice's turn ran)")
local busy, waited_list, replaced_list = {}, {}, {}
for _, e in ipairs(result.events) do
    if result.per[e.voice] then
        if e.what == "taken" then busy[e.voice] = e.version
        elseif e.what == "sent" or e.what == "unchanged" or e.what == "failed"
            or e.what == "refused" then busy[e.voice] = nil
        elseif e.what == "received" and busy[e.voice] then
            waited_list[#waited_list + 1] = string.format("  %6.1f s  %s: version %s waited "
                .. "for the turn on version %s", e.at - start, e.voice, tostring(e.version),
                tostring(busy[e.voice]))
        elseif e.what == "replaced" then
            replaced_list[#replaced_list + 1] = string.format("  %6.1f s  %s: version %s "
                .. "replaced before use, by a newer one", e.at - start, e.voice, tostring(e.version))
        end
    end
end
for _, line in ipairs(waited_list) do say(line) end
if #waited_list == 0 then say("  none") end
say("")
say("Canvases replaced before use (only the newest is ever taken)")
for _, line in ipairs(replaced_list) do say(line) end
if #replaced_list == 0 then say("  none") end
local superseded = 0
for _, r in ipairs(turns) do if r.outcome == "superseded" then superseded = superseded + 1 end end
say(string.format("  and %d of the voices' own canvases were superseded in their outbox by "
    .. "their next before rmail carried them", superseded))
-- }}}

-- {{{ the counts
say("")
say("The rehearsal's receipt (output/goodbye-rehearsal)")
local receipt = goodbye.read(ROOT .. "/output/goodbye-rehearsal")
local names = {}
for name in pairs(receipt.counters) do names[#names + 1] = name end
table.sort(names)
for _, name in ipairs(names) do say(string.format("  %-28s %d", name, receipt.counters[name])) end
say("")
say(string.format("%s drawn, %s timed. The rehearsal's timings, events and log are in "
    .. "tmp/shared-memory/ of the throwaway copy (kept with --keep).",
    plural(drawn, "version", "versions"), plural(#trips, "round trip", "round trips")))
-- }}}
