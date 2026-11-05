-- phase-4-demo.lua - the body of phase-4-demo: the turn.
--
-- phase-4-demo makes a throwaway project and runs this in it. This starts
-- two stand-in llama.cpp servers on 127.0.0.1 (src/047-stand-in-llama.lua),
-- writes the throwaway's endpoints file with every voice on the first, and
-- runs the rehearsal (src/043-rehearsal.lua) with the real turn
-- (src/055-turn.lua) in all three voices. Each version is drawn as the
-- blitter makes it, with phase 2's marks, and under it the turn that made
-- it, from that voice's own turn log: its endpoint, its tries and why, and
-- the words it changed against the recommendation. Halfway through,
-- scripts/use-endpoint switches fg-sora-2 to the second server, in the
-- workspace's endpoints file, as the owner would on kuvalu.
--
-- Then, read from the turns' own logs and receipts:
--   - every turn, in a table;
--   - per voice and endpoint: turns, the model's seconds and tokens, and
--     fit tries per turn, where fg-sora-2's switch shows;
--   - the last turn's receipt of each voice, and each runner's counts.
--
-- usage (phase-4-demo does this):
--   luajit phase-4-demo.lua --dir PROJECT --root THROWAWAY [--minutes M] [--plain]

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
    io.stderr:write("usage: luajit phase-4-demo.lua --dir PROJECT --root THROWAWAY "
        .. "[--minutes M] [--plain]\n")
    os.exit(2)
end
-- }}}

local ffi = require("ffi")
pcall(ffi.cdef, "int isatty(int fd);")
pcall(ffi.cdef, "int poll(void *fds, unsigned long nfds, int timeout);")
if not PLAIN and ffi.C.isatty(1) == 0 then PLAIN = true end
if os.getenv("NO_COLOR") and os.getenv("NO_COLOR") ~= "" then PLAIN = true end

local canvas = dofile(ROOT .. "/src/006-canvas-text.lua")
local viewer = dofile(ROOT .. "/src/022-viewer.lua")
local goodbye = dofile(ROOT .. "/src/002-goodbye.lua")
local settings = dofile(ROOT .. "/src/001-settings.lua")
local rehearsal = dofile(ROOT .. "/src/043-rehearsal.lua")
local blitter = dofile(ROOT .. "/src/016-blitter.lua")
local ask = dofile(ROOT .. "/src/051-ask-until-it-fits.lua")
local json = dofile(ROOT .. "/libs/dkjson.lua")

local LIFETIME = settings.read("blitter", blitter.SETTINGS, { root = ROOT })["mark-lifetime"]
local TURN = settings.read("turn", ask.SETTINGS, { root = ROOT })
local MINUTES_RUN = MINUTES or 1

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
local function write(path, text)
    local handle = assert(io.open(path, "wb"))
    handle:write(text)
    handle:close()
end
local function q(text) return "'" .. string.gsub(text, "'", "'\\''") .. "'" end
local function shell(command)
    local pipe = io.popen(command .. " 2>&1; echo \"exit:$?\"")
    local text = pipe:read("*a")
    pipe:close()
    local body, status = string.match(text, "^(.-)\n?exit:(%d+)\n$")
    return body or text, tonumber(status)
end
local function sleep(seconds) ffi.C.poll(nil, 0, math.floor(seconds * 1000)) end
-- }}}

-- {{{ the two stand-in models
-- Each edits like a voice: one word a turn, from its own words, so the
-- canvas shows which model wrote what. The first runs past the edge every
-- third request, the second every second, and the second is slower, so the
-- switch shows in the tries and the seconds.
local MODELS = {
    { name = "stand-in-a", words = "lantern harbor kitten orchard", wide_every = 3, delay = 0.2 },
    { name = "stand-in-b", words = "willow meadow heron", wide_every = 2, delay = 0.6 },
}
for _, model in ipairs(MODELS) do
    local folder = ROOT .. "/models/" .. model.name
    shell("mkdir -p " .. q(folder))
    write(folder .. "/replies", json.encode({ { rewrite = model.words,
        wide_every = model.wide_every, delay = model.delay } }))
    shell("luajit " .. q(ROOT .. "/src/047-stand-in-llama.lua") .. " --kind chat --port-file "
        .. q(folder .. "/port") .. " --replies " .. q(folder .. "/replies")
        .. " --parent $PPID > " .. q(folder .. "/out") .. " 2>&1 &")
    for _ = 1, 100 do
        model.port = tonumber((slurp(folder .. "/port") or ""):match("%d+"))
        if model.port then break end
        sleep(0.05)
    end
    if not model.port then
        io.stderr:write("phase-4-demo: the stand-in model ", model.name, " did not start\n")
        os.exit(1)
    end
    model.url = "http://127.0.0.1:" .. model.port
end
local lines = { "# the demo's endpoints: two stand-in llama.cpp servers on 127.0.0.1" }
for _, model in ipairs(MODELS) do
    lines[#lines + 1] = model.name .. '.url = "' .. model.url .. '"'
    lines[#lines + 1] = model.name .. '.kind = "chat"'
    lines[#lines + 1] = model.name .. ".timeout = 30"
end
for _, voice in ipairs(rehearsal.VOICES) do
    lines[#lines + 1] = "use." .. voice .. ' = "stand-in-a"'
end
write(ROOT .. "/endpoints", table.concat(lines, "\n") .. "\n")
-- }}}

-- {{{ drawing a version with its marks (as phase 2's and 3's demos draw them)
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

-- {{{ the turns' logs
-- A turn that fitted ends with one line of its numbers (src/055-turn.lua):
-- turn N on version V fits: endpoint NAME (URL), asks A, tries T, problems:
-- P, look calls L..., tokens X + Y, S seconds, W words and Z sentences
-- changed (RW and RS recommended)
local TURN_LINE = "turn (%d+) on version (%d+) fits: endpoint (%S+) %((%S+)%), asks (%d+), "
    .. "tries (%d+), problems: (.-), look calls (%d+)[^,]*, tokens (%d+) %+ (%d+), ([%d%.]+) "
    .. "seconds, (%d+) words and (%d+) sentences changed"
local function read_turns(shm, voice)
    local list = {}
    for line in string.gmatch(slurp(shm .. "/turn-" .. voice .. ".log") or "", "[^\n]+") do
        local turn, version, endpoint, url, asks, tries, problems, looks, prompt, completion,
            seconds, words, sentences = line:match(TURN_LINE)
        if turn then
            list[#list + 1] = { voice = voice, turn = tonumber(turn), version = tonumber(version),
                endpoint = endpoint, url = url, asks = tonumber(asks), tries = tonumber(tries),
                problems = problems, looks = tonumber(looks), prompt = tonumber(prompt),
                completion = tonumber(completion), seconds = tonumber(seconds),
                words = tonumber(words), sentences = tonumber(sentences) }
        end
    end
    return list
end
local function find_turn(shm, voice, number)
    local found
    for _, t in ipairs(read_turns(shm, voice)) do
        if t.turn == number then found = t end
    end
    return found
end
local function describe(t)
    local tries = t.tries == 1 and "fit at the first try"
        or string.format("fit at try %d (sent back: %s)", t.tries, t.problems)
    return string.format("%s, %s; %s and %s changed (%d and %d recommended)%s",
        t.endpoint, tries, plural(t.words, "word", "words"),
        plural(t.sentences, "sentence", "sentences"), TURN["recommended-words"],
        TURN["recommended-sentences"],
        (t.words > TURN["recommended-words"] or t.sentences > TURN["recommended-sentences"])
            and ", over: the voice is told next turn" or "")
end
-- }}}

-- {{{ the rehearsal, each version drawn as it is made
say("Phase 4: the turn")
say("")
say(string.format("The rehearsal runs for %s minutes with the real turn (scripts/turn) in all "
    .. "three voices.", MINUTES_RUN))
say("Each voice's model is asked for its edit until the edit fits the canvas. The models are")
say("two stand-in llama.cpp servers on this machine, which answer llama-server's routes and")
say("edit like a voice: one word a turn, now and then past the edge.")
for _, model in ipairs(MODELS) do
    say(string.format("  %s  %s  words: %s; past the edge every %s request; %.1f s a reply",
        model.name, model.url, model.words, model.wide_every == 2 and "second" or "third",
        model.delay))
end
say("Every voice starts on stand-in-a. Halfway through, scripts/use-endpoint switches "
    .. "fg-sora-2 to stand-in-b.")

local base = shell("mkdir -p " .. q(ROOT .. "/tmp/shared-memory/rehearsal") .. " && cd "
    .. q(ROOT .. "/tmp/shared-memory/rehearsal") .. " && pwd -P")
local WS_ROOT = base .. "/project/guide-feature"
local WS_SHM = base .. "/shm/guide-feature"
local clock = dofile(ROOT .. "/src/038-turn-runner.lua").now
local started = clock()
local half = MINUTES_RUN * 60 / 2
local switched
local drawn = 0
local result = rehearsal.run({ root = ROOT, minutes = MINUTES_RUN, keep = true,
    on_version = function(record, voice, b, row)
        drawn = drawn + 1
        local view = viewer.read(canvas.write(record, "for-viewers"), "version "
            .. record.headers.canvas)
        say("")
        if voice then
            local t = find_turn(WS_SHM, voice, b.last_turn[voice])
            say(string.format("  version %d: %s's turn %d%s", record.headers.canvas, voice,
                b.last_turn[voice], row and row.base and (" on version " .. row.base) or ""))
            if t then say("    " .. describe(t)) end
        else
            say(string.format("  version %d: the empty canvas the blitter starts with",
                record.headers.canvas))
        end
        draw(view)
        if not switched and clock() - started >= half then
            -- kuvalu's endpoints file is the workspace's; the turns read it
            -- through the canvas, from the next version on
            local out = shell(q(WS_ROOT .. "/scripts/use-endpoint") .. " fg-sora-2 stand-in-b")
            switched = { at = clock() - started, version = record.headers.canvas, said = out }
            say("")
            say(string.format("  >>> %.0f s in, on kuvalu: scripts/use-endpoint fg-sora-2 "
                .. "stand-in-b", switched.at))
            say("  >>> " .. out)
        end
    end })
-- }}}

-- {{{ every turn
local all = {}
for _, voice in ipairs(rehearsal.VOICES) do
    for _, t in ipairs(read_turns(WS_SHM, voice)) do all[#all + 1] = t end
end
table.sort(all, function(a, b)
    if a.version ~= b.version then return a.version < b.version end
    return a.voice < b.voice
end)
say("")
say("Every turn, from the turns' own logs (tmp/shared-memory/turn-<voice>.log)")
say("")
say(string.format("  %-9s %4s %7s  %-10s %5s  %-20s %5s %9s %6s", "voice", "turn", "version",
    "endpoint", "tries", "sent back for", "words", "tokens", "secs"))
for _, t in ipairs(all) do
    say(string.format("  %-9s %4d %7d  %-10s %5d  %-20s %2d/%-2d %4d+%-4d %6.2f", t.voice, t.turn,
        t.version, t.endpoint, t.tries, t.problems, t.words, TURN["recommended-words"],
        t.prompt, t.completion, t.seconds))
end
if #all == 0 then say("  none") end
-- }}}

-- {{{ per voice and endpoint
say("")
say("Per voice and endpoint: the model's seconds and tokens, and tries, per turn")
say("")
say(string.format("  %-9s %-10s %5s %9s %9s %11s %9s", "voice", "endpoint", "turns",
    "secs/turn", "tries/turn", "prompt/turn", "reply/turn"))
for _, voice in ipairs(rehearsal.VOICES) do
    for _, model in ipairs(MODELS) do
        local n, seconds, tries, prompt, completion = 0, 0, 0, 0, 0
        for _, t in ipairs(all) do
            if t.voice == voice and t.endpoint == model.name then
                n = n + 1
                seconds, tries = seconds + t.seconds, tries + t.tries
                prompt, completion = prompt + t.prompt, completion + t.completion
            end
        end
        if n > 0 then
            say(string.format("  %-9s %-10s %5d %9.2f %9.2f %11.0f %9.1f", voice, model.name, n,
                seconds / n, tries / n, prompt / n, completion / n))
        end
    end
end
if switched then
    say("")
    say(string.format("  fg-sora-2 was switched %.0f s in, after version %d: its turns from the "
        .. "next version on asked stand-in-b.", switched.at, switched.version))
else
    say("")
    say("  the rehearsal ended before the switch")
end
-- }}}

-- {{{ the receipts
say("")
say("The last turn's receipt of each voice (output/goodbye-turn-<voice>)")
for _, voice in ipairs(rehearsal.VOICES) do
    local receipt = goodbye.read(WS_ROOT .. "/output/goodbye-turn-" .. voice)
    if receipt then
        local names = {}
        for name in pairs(receipt.counters) do names[#names + 1] = name end
        table.sort(names)
        local parts = {}
        for _, name in ipairs(names) do parts[#parts + 1] = name .. " " .. receipt.counters[name] end
        say("  " .. voice .. ": " .. table.concat(parts, ", "))
    else
        say("  " .. voice .. ": none")
    end
end
say("")
local p = result.per
for _, voice in ipairs(rehearsal.VOICES) do
    say(string.format("  %-9s %s received, %s run, %s sent", voice,
        plural(p[voice].received, "canvas", "canvases"), plural(p[voice].turns, "turn", "turns"),
        plural(p[voice].sent, "canvas", "canvases")))
end
say("")
say(string.format("%s drawn, %s read from the turn logs. The workspace's logs and receipts are "
    .. "in tmp/shared-memory/rehearsal/ of the throwaway copy (kept with --keep).",
    plural(drawn, "version", "versions"), plural(#all, "turn", "turns")))
-- }}}
