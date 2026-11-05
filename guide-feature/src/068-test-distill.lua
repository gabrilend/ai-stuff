#!/usr/bin/env luajit
-- 068-test-distill.lua
--
-- Tests distill mode (issue 601): the blitter keeping each voice's newest
-- canvas, the distiller's prompt built from input/distill-instructions
-- (src/067-distill.lua), the stand-in distiller (047's `distill` reply), the
-- blitter in distill mode (arrivals held, one distill for all of them, the
-- distilled canvas blitted on the current canvas under the name kuvalu, a
-- reply that does not fit asked again, a distiller that is down retried),
-- the distiller endpoint asked over 127.0.0.1, and then the owner's rule: a
-- rehearsal run whose merge mode is switched from newest to distill and
-- back while it runs, with both modes making valid versions.
--
-- For a general: kuvalu can now combine the three voices' latest drafts into
-- one, instead of only taking each draft as it lands, and the switch between
-- the two can be made while everything runs.
--
-- usage:
--   luajit 068-test-distill.lua [--dir ROOT]
-- The rehearsal's daemons listen on 127.0.0.1 only.

-- {{{ DIR -- the project root, hard-coded, overridable by --dir
local DIR = "/mnt/mtwo/programming/ai-stuff/guide-feature"
for index = 1, #arg do
    if arg[index] == "--dir" then DIR = arg[index + 1] end
end
-- }}}

local ffi = require("ffi")
pcall(ffi.cdef, "int setenv(const char *name, const char *value, int overwrite);")
pcall(ffi.cdef, "int poll(void *fds, unsigned long nfds, int timeout);")

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

-- {{{ small helpers
local function shell(command)
    local pipe = io.popen(command .. " 2>&1; echo \"exit:$?\"")
    local text = pipe:read("*a")
    pipe:close()
    local body, status = string.match(text, "^(.-)\n?exit:(%d+)\n$")
    return body, tonumber(status)
end
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
local function has(text, piece) return text ~= nil and string.find(text, piece, 1, true) ~= nil end
local function sleep(seconds) ffi.C.poll(nil, 0, math.floor(seconds * 1000)) end
local function refused(f, ...)
    local ok, problem = pcall(f, ...)
    return not ok and tostring(problem) or nil
end
-- }}}

-- {{{ the throwaway project
local BASE = shell("mktemp -d")
BASE = shell("cd " .. q(BASE) .. " && pwd -P")
local ROOT = BASE .. "/project/guide-feature"
shell("mkdir -p " .. q(ROOT .. "/input") .. " " .. q(ROOT .. "/output") .. " "
    .. q(BASE .. "/exec") .. " " .. q(BASE .. "/shm") .. " " .. q(BASE .. "/servers"))
for _, name in ipairs({ "src", "libs", "scripts" }) do
    shell("ln -s " .. q(DIR .. "/" .. name) .. " " .. q(ROOT .. "/" .. name))
end
ffi.C.setenv("EXEC_TIER_ROOT", BASE .. "/exec", 1)
ffi.C.setenv("ARTIFACT_TIER_ROOT", BASE .. "/shm", 1)
local SHM = BASE .. "/shm/guide-feature"
local KEEP = (os.getenv("KEEP") or "") ~= ""
write(ROOT .. "/input/distill", slurp(DIR .. "/input/distill"))
write(ROOT .. "/input/distill-instructions", slurp(DIR .. "/input/distill-instructions"))
-- }}}

local canvas = dofile(DIR .. "/src/006-canvas-text.lua")
local changes = dofile(DIR .. "/src/010-changes.lua")
local goodbye = dofile(DIR .. "/src/002-goodbye.lua")
local prompt = dofile(DIR .. "/src/049-turn-prompt.lua")
local distill = dofile(DIR .. "/src/067-distill.lua")
local stand_in = dofile(DIR .. "/src/047-stand-in-llama.lua")
local blitter = dofile(DIR .. "/src/016-blitter.lua")
local json = dofile(DIR .. "/libs/dkjson.lua")

-- {{{ canvases
local function record(rows, width, height, version)
    local r = canvas.blank(width or 20, height or 3)
    for number, row in ipairs(rows) do r.rows[number] = row end
    r.headers = { canvas = version or 1 }
    return r
end
local function voice_text(voice, turn, base, rows)
    local r = canvas.blank(20, 3, "from-voice")
    r.headers = { voice = voice, turn = turn, base = base, written = "2026-11-05T10:00:00Z" }
    for number, row in ipairs(rows) do r.rows[number] = row end
    return canvas.write(r)
end
local function trimmed(rows)
    local out = {}
    for number, row in ipairs(rows) do out[number] = (string.gsub(row, " +$", "")) end
    return table.concat(out, "|")
end
-- }}}

io.write("\n=== the distiller's words (067) ===\n")
-- {{{
local INSTRUCTIONS = slurp(DIR .. "/input/distill-instructions")
local parts = distill.parse(INSTRUCTIONS)
check("the project's input/distill-instructions reads, in three parts",
    parts.system and parts.user and parts.voice and has(parts.user, "{{voices}}"))
check("an unknown marker is refused, naming the file and line",
    has(refused(distill.parse, "[system]\n{{width}} {{height}}\n[user]\n{{canvas}} {{voices}}\n"
        .. "[voice]\n{{name}} {{voice-canvas}} {{look}}\n"),
        "input/distill-instructions:6: {{look}} is not a marker this file can use"))
check("a missing [voice] part is refused",
    has(refused(distill.parse, "[system]\n{{width}} {{height}}\n[user]\n{{canvas}} {{voices}}\n"),
        "input/distill-instructions: there is no [voice] part"))
check("a [user] part without {{voices}} is refused", has(refused(distill.parse,
    "[system]\n{{width}} {{height}}\n[user]\n{{canvas}}\n[voice]\n{{name}} {{voice-canvas}}\n"),
    "the [user] part has no {{voices}}"))
check("an unknown part names this file's parts", has(refused(distill.parse,
    "[look]\nx\n"), "the parts are [system], [user] and [voice]"))
check("the turn's own file is still read by its own parts", has(refused(prompt.parse,
    "[voice]\n"), "input/turn-instructions:1: [voice] is not a part; the parts are [system], "
    .. "[user] and [look]"))

local base = record({ "the cat sat on", "a mat." }, 20, 3, 4)
local mine = record({ "the dog sat on", "a mat. ok" }, 20, 3)
local found = changes.find(base, mine)
check("a voice's changed words: erased before written, each in reading order",
    distill.changes_text(found) == 'erased "cat" at row 1, column 5\n'
    .. 'wrote "dog" at row 1, column 5\nwrote "ok" at row 2, column 8',
    distill.changes_text(found))
check("no changed words is said so", distill.changes_text(changes.find(base, base))
    == "(no words changed against that version)")

local current = record({ "the cat sat on", "a mat.", "end" }, 20, 3, 9)
local conversation = distill.build({ instructions = INSTRUCTIONS, current = current,
    recommended = { words = 36, sentences = 3 },
    newest = {
        { voice = "fg-sora-1", canvas = mine, found = found, turn = 5, base = 4 },
        { voice = "fg-sora-3", canvas = record({ "the cat sat on", "a mat.", "fin" }),
          found = changes.find(current, record({ "the cat sat on", "a mat.", "fin" })),
          turn = 2, base = 9 },
    } })
local system, user = conversation[1].content, conversation[2].content
check("the system turn has the size, the counts and how many voices wrote",
    conversation[1].role == "system" and has(system, "exactly 20 characters wide and 3 rows")
    and has(system, "words changed: 36") and has(system, "sentences rewritten: 3")
    and has(system, "the newest canvas from each of the\n2 voices"), system)
check("the user turn shows the current canvas first, in its ruler", conversation[2].role
    == "user" and table.concat(prompt.unruler(user), "|") == table.concat(
        { "the cat sat on      ", "a mat.              ", "end                 " }, "|")
    and has(user, "version 9"), user)
local one, three = user:find("fg-sora-1's newest canvas", 1, true),
    user:find("fg-sora-3's newest canvas", 1, true)
check("then each voice's newest, in the order given, with its turn, base and words",
    one and three and one < three and has(user, "from its turn 5, which started from\nversion 4")
    and has(user, 'wrote "dog" at row 1, column 5') and has(user, 'wrote "fin" at row 3, column 1')
    and has(user, "1 |the dog sat on      |"), user)
check("no marker is left unfilled", not has(system .. user, "{{"))
check("build refuses no voices", has(refused(distill.build, { instructions = INSTRUCTIONS,
    current = current, newest = {}, recommended = { words = 1, sentences = 1 } }),
    "there is no voice canvas to distill"))
-- }}}

io.write("\n=== the stand-in distiller (047) ===\n")
-- {{{
local merged = stand_in.distill(conversation)
check("it applies every voice's changes to the current canvas",
    merged == "the dog sat on\na mat. ok\nfin\n", merged)
local stale = distill.build({ instructions = INSTRUCTIONS, recommended = { words = 1, sentences = 1 },
    current = record({ "the bird sat on", "a mat.", "end" }, 20, 3, 10),
    newest = {
        { voice = "fg-sora-1", canvas = mine, found = found, turn = 5, base = 4 },
        { voice = "fg-sora-2", canvas = record({ "the cat sat on", "a mat. no" }),
          found = changes.find(base, record({ "the cat sat on", "a mat. no" })), turn = 3, base = 4 },
    } })
check("a voice's change lands even when its base is behind (the word under it is blanked), "
    .. "and the voice listed first keeps a contested place", stand_in.distill(stale)
    == "the dog  sat on\na mat. ok\nend\n", stand_in.distill(stale))
local claimed = distill.build({ instructions = INSTRUCTIONS, recommended = { words = 1, sentences = 1 },
    current = record({ "willow tree" }, 20, 3, 12),
    newest = {
        { voice = "fg-sora-1", canvas = record({ "lantern tree" }),
          found = changes.find(record({ "oak tree" }), record({ "lantern tree" })), turn = 2, base = 9 },
        { voice = "fg-sora-2", canvas = record({ "willow tree" }),
          found = changes.find(record({ "lantern tree" }), record({ "willow tree" })), turn = 4, base = 11 },
    } })
check("an older change never writes over a word another voice's newest wrote",
    stand_in.distill(claimed) == "willow tree\n\n\n", stand_in.distill(claimed))
local wide = stand_in.distill(conversation, true)
check("wide: the first row runs past the edge", has(wide, "the dog sat on       past the edge"))
local server = stand_in.new({ kind = "chat", replies = { { distill = true, wide_every = 2 } } })
local first = server:next_reply(conversation).content
local second = server:next_reply(conversation).content
check("as a scripted reply, every wide_every-th runs wide", first == merged
    and has(second, "past the edge"))
-- }}}

io.write("\n=== the blitter in distill mode ===\n")
-- {{{
local function settings_file(mode)
    write(ROOT .. "/input/blitter", "canvas-size = 20x3\nmerge-mode = \"" .. mode
        .. "\"\ncollision-rule = \"blank-whole\"\nmark-lifetime = 12\n"
        .. "project = \"guide-feature\"\nvoices = \"fg-sora-1 fg-sora-2 fg-sora-3\"\n")
end
settings_file("newest")
local ARRIVALS = ROOT .. "/tmp/shared-memory/arrivals"
local function arrive(name, text) write(ARRIVALS .. "/" .. name, text) end
-- the distiller, in the process: the stand-in's merge, or what a test says
local asked, scripted = {}, {}
local function distill_call(turns)
    asked[#asked + 1] = turns
    local reply = table.remove(scripted, 1)
    if reply == "down" then error("the distiller is down", 0) end
    return reply or stand_in.distill(turns), { seconds = 0.25, usage = { prompt_tokens = 10,
        completion_tokens = 4 } }
end
local minute = 0
local function clock()
    minute = minute + 1
    return string.format("2026-11-05T%02d:%02d:00Z", 10 + math.floor(minute / 60), minute % 60)
end
local b = blitter.new({ root = ROOT, clock = clock, wait = function() end, commit = "abc1234",
    distill_call = distill_call })

arrive("fg-sora-1-1000-a", voice_text("fg-sora-1", 1, 1, { "the cat sat.", "", "" }))
b:step()
check("in newest mode an arrival is blitted as before, and kept as its voice's newest",
    b.version == 2 and b.newest["fg-sora-1"] and b.newest["fg-sora-1"].turn == 1
    and #b.newest["fg-sora-1"].found.written == 3 and #asked == 0)

settings_file("distill")
arrive("fg-sora-2-1001-b", voice_text("fg-sora-2", 1, 2, { "the cat sat.", "a dog ran.", "" }))
arrive("fg-sora-3-1002-c", voice_text("fg-sora-3", 1, 1, { "", "", "the end." }))
arrive("fg-sora-2-1003-d", voice_text("fg-sora-2", 2, 2, { "the cat sat.", "a cow ran.", "" }))
local outcomes = {}
for _, name in ipairs(blitter.pending(ARRIVALS)) do outcomes[#outcomes + 1] = b:take(name) end
check("in distill mode each arrival is held, not blitted", table.concat(outcomes, " ")
    == "held held held" and b.version == 2 and #asked == 0, table.concat(outcomes, " "))
check("only each voice's newest is kept: a second arrival replaces the first held",
    b.held["fg-sora-2"].turn == 2 and b.run.counters["held-replaced"] == 1
    and b.newest["fg-sora-2"].turn == 2)
local result, held, replaced = b:distill_held()
check("one distill for all of them, a new version", result == "blitted" and #asked == 1
    and b.version == 3 and #held == 2 and #replaced == 1 and replaced[1].turn == 1)
check("the distiller was shown every voice's newest, in the voices' order, fg-sora-1's "
    .. "too", has(asked[1][2].content, "fg-sora-1's newest canvas, from its turn 1")
    and asked[1][2].content:find("fg-sora-1's newest", 1, true)
        < asked[1][2].content:find("fg-sora-2's newest", 1, true)
    and has(asked[1][2].content, "fg-sora-2's newest canvas, from its turn 2")
    and not has(asked[1][2].content, "a dog ran"), asked[1][2].content)
check("the distilled canvas is blitted on the current one",
    trimmed(b.current.rows) == "the cat sat.|a cow ran.|the end.", trimmed(b.current.rows))
local voices_marked = {}
for _, mark in ipairs(b.current.marks) do voices_marked[mark.voice] = true end
check("its marks carry the name kuvalu, not a voice's", voices_marked.kuvalu
    and not voices_marked["fg-sora-2"] and not voices_marked["fg-sora-3"])
local back = canvas.read(slurp(ROOT .. "/tmp/shared-memory/canvas/current"), "for-viewers")
check("the version as viewers read it says distill mode and keeps kuvalu's marks",
    back.headers.canvas == 3 and back.headers.mode == "distill" and (function()
        for _, mark in ipairs(back.marks) do
            if mark.version == 3 and mark.voice == "kuvalu" then return true end
        end
    end)(), json.encode({ back.headers.canvas, back.headers.mode, back.marks }))
check("nothing is held after the distill, and a step with nothing held asks nothing",
    next(b.held) == nil and b:distill_held() == nil and #asked == 1)

-- a reply that does not fit is sent back and asked again (404's loop)
arrive("fg-sora-1-1004-e", voice_text("fg-sora-1", 2, 3, { "the cat sat down.", "a cow ran.", "the end." }))
scripted = { "the cat sat down, and then some more words past the edge\na cow ran.\nthe end.\n" }
b:step()
check("a distilled canvas past the edge is asked again; the fitting one is blitted",
    #asked == 3 and b.version == 4 and has(asked[3][#asked[3]].content, "")
    and trimmed(b.current.rows) == "the cat sat down.|a cow ran.|the end.", trimmed(b.current.rows))
check("the retry went back with the fit check's report", asked[3][3].role == "assistant"
    and asked[3][4].role == "user" and has(asked[3][4].content, "row 1"), asked[3][4]
    and asked[3][4].content)

-- the distiller has no look tool: a look call is told the limit is 0
arrive("fg-sora-2-1004-x", voice_text("fg-sora-2", 3, 4, { "the cat sat down.", "a cow ran.", "the end." }))
scripted = { "look focused: the canvas" }
local asks_now = #asked
b:step()
check("a look call from the distiller is answered as past a limit of 0, and it is asked again",
    #asked == asks_now + 2 and has(asked[#asked][4].content, "the limit is 0")
    and b.run.counters["unchanged-distills"] == 1, asked[#asked][4] and asked[#asked][4].content)

-- a distiller that is down: logged, counted, held for the next step
arrive("fg-sora-3-1005-f", voice_text("fg-sora-3", 2, 4, { "the cat sat down.", "a cow ran.", "the end!" }))
scripted = { "down" }
b:step()
check("a distiller that is down makes no version; the arrival stays held",
    b.version == 4 and b.held["fg-sora-3"] and b.run.counters["distills-failed"] == 1)
b:step()
check("and the next step distills it", b.version == 5 and next(b.held) == nil
    and trimmed(b.current.rows) == "the cat sat down.|a cow ran.|the end!", trimmed(b.current.rows))

-- a distill that changes nothing makes no version
arrive("fg-sora-2-1006-g", voice_text("fg-sora-2", 4, 5, { "the cat sat down.", "a cow ran.", "the end!" }))
b:step()
check("a distill that changes nothing makes no version", b.version == 5
    and b.run.counters["unchanged-distills"] == 2)

-- switched back: the next arrival is blitted under its voice's name
settings_file("newest")
arrive("fg-sora-1-1007-h", voice_text("fg-sora-1", 3, 5, { "a cat sat down.", "a cow ran.", "the end!" }))
local asks_before = #asked
b:step()
local fg1 = false
for _, mark in ipairs(b.current.marks) do
    if mark.voice == "fg-sora-1" and mark.version == 6 then fg1 = true end
end
check("switched back to newest, the next arrival is blitted under its voice's name, "
    .. "with no distill", b.version == 6 and fg1 and #asked == asks_before
    and b.current.headers.mode == "newest")
local log = slurp(SHM .. "/blitter.log") or ""
check("the log says each switch, each hold and each distill", has(log, "merge-mode is now distill")
    and has(log, "merge-mode is now newest") and has(log, "held for the next distill")
    and has(log, "replaces turn 1 from fg-sora-2")
    and has(log, "distill of fg-sora-2 turn 2, fg-sora-3 turn 1 on (given) (3 voices' newest)")
    and has(log, "failed; they stay held") and has(log, "distill: ask 1: try 1 does not fit"), log)
local receipt = goodbye.read(b:finish())
local c = receipt.counters
check("the receipt counts holds, distills, asks, tries and the distiller's time",
    c["arrivals-held"] == 7 and c["held-replaced"] == 1 and c["distills"] == 5
    and c["distills-failed"] == 1 and c["distill-asks"] == 7 and c["distill-tries"] == 6
    and c["distill-milliseconds"] == 1750 and c["versions-made"] == 5, json.encode(c))
-- }}}

io.write("\n=== the distiller endpoint, over 127.0.0.1 ===\n")
-- {{{
local SERVERS = {}
local function start_server(name, replies)
    local folder = BASE .. "/servers/" .. name
    shell("mkdir -p " .. q(folder))
    write(folder .. "/replies", json.encode(replies))
    local pid = shell("luajit " .. q(DIR .. "/src/047-stand-in-llama.lua") .. " --kind chat"
        .. " --port-file " .. q(folder .. "/port") .. " --requests " .. q(folder .. "/requests")
        .. " --replies " .. q(folder .. "/replies") .. " --parent $PPID >" .. q(folder .. "/out")
        .. " 2>&1 & echo $!")
    local port
    for _ = 1, 100 do
        port = slurp(folder .. "/port")
        if port then break end
        sleep(0.05)
    end
    local s = { name = name, pid = pid, folder = folder,
                url = "http://127.0.0.1:" .. tostring(port and port:match("%d+")) }
    SERVERS[#SERVERS + 1] = s
    return s
end
local function chats(s)
    local list = {}
    for line in string.gmatch(slurp(s.folder .. "/requests") or "", "[^\n]+") do
        local r = json.decode(line)
        if r.path == "/v1/chat/completions" then list[#list + 1] = r end
    end
    return list
end
local distiller = start_server("distiller", { { distill = true, wide_every = 3 } })
local voices_server = start_server("voices", { { rewrite = "unused" } })
check("the stand-in distiller listens on 127.0.0.1", distiller.url:match("^http://127%.0%.0%.1:%d+$"))
write(ROOT .. "/endpoints", table.concat({
    'stand-in-distiller.url = "' .. distiller.url .. '"', 'stand-in-distiller.kind = "chat"',
    "stand-in-distiller.timeout = 5",
    'stand-in-voices.url = "' .. voices_server.url .. '"', 'stand-in-voices.kind = "chat"',
    "stand-in-voices.timeout = 5",
    'use.distiller = "stand-in-distiller"', 'use.fg-sora-1 = "stand-in-voices"',
    'use.fg-sora-2 = "stand-in-voices"', 'use.fg-sora-3 = "stand-in-voices"',
}, "\n") .. "\n")
settings_file("distill")
shell("rm -rf " .. q(SHM .. "/canvas"))
local e = blitter.new({ root = ROOT, clock = clock, wait = function() end, commit = "abc1234" })
local v = e.version
arrive("fg-sora-1-2000-a", voice_text("fg-sora-1", 10, v, { "over the wire", "", "" }))
arrive("fg-sora-2-2001-b", voice_text("fg-sora-2", 10, v, { "", "", "and back" }))
e:step()
local asked_over = chats(distiller)
check("with no call given, the blitter asks the endpoint use.distiller names",
    #asked_over == 1 and e.version == v + 1
    and trimmed(e.current.rows) == "over the wire||and back", trimmed(e.current.rows))
check("the request is the distiller's prompt", asked_over[1]
    and has(asked_over[1].body.messages[1].content, "You are kuvalu, the distiller")
    and has(asked_over[1].body.messages[2].content, "fg-sora-2's newest canvas"))
check("the log names the endpoint", has(slurp(SHM .. "/blitter.log"),
    "on stand-in-distiller (2 voices' newest)"))
e:finish()
-- }}}

io.write("\n=== the owner's rule: both modes in one rehearsal ===\n")
-- {{{
local series = dofile(DIR .. "/src/018-phase-1-series.lua")
local rehearsal = dofile(DIR .. "/src/043-rehearsal.lua")
local CHECKOUT = BASE .. "/the-project"
shell("mkdir -p " .. q(CHECKOUT) .. " && git -C " .. q(CHECKOUT) .. " init -q && git -C "
    .. q(CHECKOUT) .. " -c user.name=test -c user.email=test@localhost commit -q --allow-empty -m one")
write(ROOT .. "/input/blitter", series.SETTINGS)
write(ROOT .. "/input/turn-runner", (slurp(DIR .. "/input/turn-runner")
    :gsub('\nturn = "[^"]*"', '\nturn = "scripts/stand-in-turn"')))
write(ROOT .. "/input/stand-in-turn", 'words = "lantern harbor kitten orchard ember meadow"\n'
    .. "seconds = 0.3\n")
write(ROOT .. "/input/to-voices", 'send = "off"\nmailbox = "~/guide-mail"\ntell-the-voice = "on"\n'
    .. 'project-checkout = "' .. CHECKOUT .. '"\n')
write(ROOT .. "/input/rehearsal", 'minutes = 0.75\ncarrier = "stand-in"\nfirst-port = 41423\n'
    .. 'pace = 1\njitter = 0.5\nrmail = "luajit /nowhere/rmail.lua"\n')
-- the switch: newest for the first versions, then distill, then newest again
local seen, phase, problems = {}, "newest", {}
local by_phase = { newest = 0, distill = 0, again = 0 }
local function set_mode(b2, mode)
    local text = slurp(b2.root .. "/input/blitter")
    write(b2.root .. "/input/blitter", (text:gsub('merge%-mode = "%a+"', 'merge-mode = "' .. mode .. '"')))
end
local ok, summary = pcall(rehearsal.run, { root = ROOT, keep = true,
    on_version = function(r, voice, b2)
        -- every version must read back as viewers read it, at the canvas's size
        local text = canvas.write(r, "for-viewers")
        local good, back2 = pcall(canvas.read, text, "for-viewers")
        if not good or back2.width ~= series.WIDTH or back2.height ~= series.HEIGHT then
            problems[#problems + 1] = "version " .. tostring(r.headers.canvas) .. " does not read"
        end
        if r.headers.canvas ~= (seen[#seen] and seen[#seen].version or r.headers.canvas - 1) + 1 then
            problems[#problems + 1] = "version " .. r.headers.canvas .. " is out of order"
        end
        seen[#seen + 1] = { version = r.headers.canvas, voice = voice, mode = r.headers.mode }
        if voice then
            local key = phase == "newest" and by_phase.distill > 0 and "again" or phase
            by_phase[key] = by_phase[key] + 1
        end
        if phase == "newest" and by_phase.distill == 0 and by_phase.newest >= 4 then
            phase = "distill"
            set_mode(b2, "distill")
        elseif phase == "distill" and by_phase.distill >= 3 then
            phase = "newest"
            set_mode(b2, "newest")
        end
    end })
check("the rehearsal runs to its end", ok, summary)
summary = ok and summary or { turns = {}, versions = {} }
local modes = {}
for _, s in ipairs(seen) do modes[#modes + 1] = (s.voice == "kuvalu" and "k" or s.voice and "v" or "-") end
check("its versions are newest's, then distill's, then newest's again",
    by_phase.newest >= 4 and by_phase.distill >= 3 and by_phase.again >= 1,
    table.concat(modes) .. " " .. json.encode(by_phase))
local voice_marked, kuvalu_marked = true, true
for _, s in ipairs(seen) do
    if s.voice == "kuvalu" and s.mode ~= "distill" then kuvalu_marked = false end
    if s.voice and s.voice ~= "kuvalu" and s.mode ~= "newest" then voice_marked = false end
end
check("each version names the mode it was made in", voice_marked and kuvalu_marked)
check("every version reads back as viewers read it, in order, at the canvas's size",
    #problems == 0 and #seen >= 8, table.concat(problems, "; "))
local counts = { blitted = 0, distilled = 0 }
for line in string.gmatch(slurp(SHM .. "/rehearsal-timings") or "", "[^\n]+") do
    local outcome = line:match("^%S+ %S+ %S+ %S+ (%S+)")
    if counts[outcome] then counts[outcome] = counts[outcome] + 1 end
end
check("the timings show turns blitted and turns distilled", counts.blitted >= 5
    and counts.distilled >= 3, slurp(SHM .. "/rehearsal-timings"))
local WS_SHM = SHM .. "/rehearsal/shm/guide-feature"
local rlog = slurp(WS_SHM .. "/blitter.log") or ""
check("the blitter's log shows the switches and the distills, and no refusal",
    has(rlog, "merge-mode is now distill") and has(rlog, "merge-mode is now newest")
    and has(rlog, "on stand-in-distiller") and not has(rlog, "refused"), rlog:sub(-1500))
check("the distiller was asked over 127.0.0.1, and a reply past the edge asked again",
    #chats(distiller) >= by_phase.distill + 1 and has(rlog, "does not fit"))
local voices_got_it = true
for _, voice in ipairs({ "fg-sora-1", "fg-sora-2", "fg-sora-3" }) do
    local events = slurp(SHM .. "/rehearsal/project/guide-feature/tmp/shared-memory/turn/"
        .. voice .. "/events") or slurp(WS_SHM .. "/turn/" .. voice .. "/events") or ""
    local last_kuvalu
    for _, s in ipairs(seen) do if s.voice == "kuvalu" then last_kuvalu = s.version end end
    if not last_kuvalu or not events:match(" received " .. last_kuvalu .. "\n") then
        -- a voice may still have been mid-turn: any distilled version received counts
        local any = false
        for _, s in ipairs(seen) do
            if s.voice == "kuvalu" and events:match(" received " .. s.version .. "%s") then any = true end
        end
        voices_got_it = voices_got_it and any
    end
end
check("the voices were sent the distilled versions and took turns on them", voices_got_it)
if failed > 0 and KEEP then io.write("kept ", SHM .. "/rehearsal", "\n")
else shell("rm -rf " .. q(SHM .. "/rehearsal")) end
-- }}}

for _, s in ipairs(SERVERS) do shell("kill " .. s.pid) end
if failed > 0 and KEEP then io.write("kept ", BASE, "\n") else shell("rm -rf " .. q(BASE)) end
io.write(string.format("\nTests: %d passed, %d failed\n", passed, failed))
os.exit(failed == 0 and 0 or 1)
