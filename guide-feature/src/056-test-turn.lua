#!/usr/bin/env luajit
-- 056-test-turn.lua
--
-- Tests the real turn (issue 405, src/055-turn.lua, scripts/turn) against
-- stand-in llama.cpp servers (047) on 127.0.0.1 whose model edits the canvas
-- it is shown one word at a time, and now and then writes past the edge.
--
-- One turn by hand: the canvas read, the voice's own endpoint from the
-- canvas, the prompt with the canvas in its ruler, a reply that does not fit
-- sent back and asked again, the voice's canvas written with base set and
-- read back, the receipt and log naming the endpoint and the numbers; the
-- advisory note kept for the next turn's prompt and dropped after; a voice
-- with a key; refusals (no endpoint line, a model error). The newer-canvas
-- setting: "keep-going" (the owner's word) asks on with a newer canvas
-- waiting; "give-way" stops, writes nothing and exits 3, which the runner
-- counts and sends nothing for. Then the whole round: the rehearsal with the
-- real turn in every voice, and one voice switched to another endpoint
-- with scripts/use-endpoint while it runs, the switch showing in that
-- voice's next turns' log.
--
-- For a general: each voice now really asks a model for its edit, keeps
-- asking until the edit fits the screen, and records which model wrote it.
--
-- usage:
--   luajit 056-test-turn.lua [--dir ROOT]

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
-- }}}

-- {{{ the throwaway project
local BASE = shell("mktemp -d")
BASE = shell("cd " .. q(BASE) .. " && pwd -P")
local ROOT = BASE .. "/project/guide-feature"
local HOME = BASE .. "/home"
shell("mkdir -p " .. q(ROOT .. "/input") .. " " .. q(ROOT .. "/output") .. " "
    .. q(BASE .. "/exec") .. " " .. q(BASE .. "/shm") .. " " .. q(BASE .. "/servers") .. " "
    .. q(HOME .. "/keys"))
for _, name in ipairs({ "src", "libs", "scripts" }) do
    shell("ln -s " .. q(DIR .. "/" .. name) .. " " .. q(ROOT .. "/" .. name))
end
ffi.C.setenv("EXEC_TIER_ROOT", BASE .. "/exec", 1)
ffi.C.setenv("ARTIFACT_TIER_ROOT", BASE .. "/shm", 1)
ffi.C.setenv("HOME", HOME, 1)
local SHM = BASE .. "/shm/guide-feature"
-- KEEP=1 in the environment leaves the throwaway folder after a failure, to read
local KEEP = (os.getenv("KEEP") or "") ~= ""
local TURN_SETTINGS = slurp(DIR .. "/input/turn")
write(ROOT .. "/input/turn", TURN_SETTINGS)
write(ROOT .. "/input/turn-instructions", slurp(DIR .. "/input/turn-instructions"))
local function turn_settings(over)
    local text = TURN_SETTINGS
    for name, value in pairs(over or {}) do
        text = text:gsub("\n" .. name:gsub("%-", "%%-") .. "%s*= [^\n]*", "\n" .. name .. " = " .. value)
    end
    write(ROOT .. "/input/turn", text)
end
-- }}}

local goodbye = dofile(DIR .. "/src/002-goodbye.lua")
local canvas = dofile(DIR .. "/src/006-canvas-text.lua")
local runner = dofile(DIR .. "/src/038-turn-runner.lua")
local turn_module = dofile(DIR .. "/src/055-turn.lua")
local json = dofile(DIR .. "/libs/dkjson.lua")

-- {{{ stand-in servers
local SERVERS = {}
local function start_server(name, replies, key_file)
    local folder = BASE .. "/servers/" .. name
    shell("mkdir -p " .. q(folder))
    write(folder .. "/replies", json.encode(replies))
    local command = "luajit " .. q(DIR .. "/src/047-stand-in-llama.lua") .. " --kind chat"
        .. " --port-file " .. q(folder .. "/port") .. " --requests " .. q(folder .. "/requests")
        .. " --replies " .. q(folder .. "/replies") .. " --parent $PPID"
    if key_file then command = command .. " --key-file " .. q(key_file) end
    local pid = shell(command .. " >" .. q(folder .. "/out") .. " 2>&1 & echo $!")
    local port
    for _ = 1, 100 do
        port = slurp(folder .. "/port")
        if port then break end
        sleep(0.05)
    end
    local server = { name = name, pid = pid, folder = folder,
                     url = "http://127.0.0.1:" .. tostring(port and port:match("%d+")) }
    SERVERS[name] = server
    return server
end
local function stop_server(server)
    shell("kill " .. server.pid)
    for _ = 1, 100 do
        local _, status = shell("kill -0 " .. server.pid)
        if status ~= 0 then break end
        sleep(0.05)
    end
end
local function requests(server)
    local list = {}
    for line in string.gmatch(slurp(server.folder .. "/requests") or "", "[^\n]+") do
        list[#list + 1] = json.decode(line)
    end
    return list
end
local function chats(server)
    local list = {}
    for _, r in ipairs(requests(server)) do
        if r.path == "/v1/chat/completions" then list[#list + 1] = r end
    end
    return list
end
-- }}}

local KEY = "stand-in-key-405-c0ffee"
write(HOME .. "/keys/far", KEY .. "\n")
shell("chmod 600 " .. q(HOME .. "/keys/far"))
-- every second request runs past the edge
local house = start_server("house", { { rewrite = "lamp harbor kitten orchard", wide_every = 2 } })
local far = start_server("far", { { rewrite = "meadow" } }, HOME .. "/keys/far")
local broken = start_server("broken", { { status = 500, error = "the model fell over" } })
-- two replies past the edge, then fitting ones
local slow = start_server("slow", { { rewrite = "slate", wide_every = 1, delay = 0.2 },
    { rewrite = "slate", wide_every = 1 }, { rewrite = "slate" } })

-- {{{ a canvas from kuvalu
local CANVAS_TEXT = slurp(DIR .. "/assets/test-prompts/01-turn-prompt.canvas")
local function canvas_with(lines)
    return (CANVAS_TEXT:gsub("endpoints:\n.*$", "endpoints:\n" .. table.concat(lines, "\n") .. "\n"))
end
local GIVEN = BASE .. "/given"
write(GIVEN, canvas_with({
    "endpoint: fg-sora-1 stand-in-house 5 " .. house.url,
    "endpoint: fg-sora-2 far-away 5 " .. far.url .. " ~/keys/far",
    "endpoint: fg-sora-3 broken-chat 5 " .. broken.url,
}))
local GIVEN_RECORD = canvas.read(slurp(GIVEN), "to-voices")
local OUT = BASE .. "/out"
local TURN = q(ROOT .. "/scripts/turn")
local function turn(voice, number, file)
    os.remove(OUT)
    return shell(TURN .. " --voice " .. voice .. " --turn " .. number .. " --canvas "
        .. q(file or GIVEN) .. " --out " .. q(OUT))
end
local function receipt(voice) return goodbye.read(ROOT .. "/output/goodbye-turn-" .. voice) end
local function turn_log(voice) return slurp(SHM .. "/turn-" .. voice .. ".log") or "" end
-- }}}

io.write("\n=== one turn ===\n")
-- {{{
local out, status = turn("fg-sora-1", 1)
check("the turn runs and exits 0", status == 0, out)
local mine_ok, mine = pcall(canvas.read, slurp(OUT) or "", "from-voice")
check("it writes the voice's canvas: voice, turn, base the version read, the size",
    mine_ok and mine.headers.voice == "fg-sora-1" and mine.headers.turn == 1
    and mine.headers.base == 18 and mine.width == 40 and mine.height == 6, mine)
check("with the model's edit in it: one word changed, the row cut at the edge",
    mine_ok and mine.rows[1] == "lamp kitten  on the mat is very sleepy. "
    and mine.rows[3] == GIVEN_RECORD.rows[3], mine_ok and mine.rows[1])
local sent = chats(house)
check("the model was asked with the opening conversation, the canvas in its ruler",
    #sent == 1 and sent[1].body.messages[1].role == "system"
    and has(sent[1].body.messages[2].content, "\n1 |the kitten  on the mat is very sleepy.  |"),
    #sent)
check("only this voice's endpoint was asked", #chats(far) == 0 and #chats(broken) == 0)
local r1 = receipt("fg-sora-1")
check("the receipt names the endpoint and counts the turn",
    r1 and r1.counters["endpoint-stand-in-house"] == 1 and r1.counters.asks == 1
    and r1.counters.tries == 1 and (r1.counters["words-changed"] or 0) >= 1
    and r1.counters["over-recommended"] == 0 and (r1.counters["tokens-prompt"] or 0) > 0
    and (r1.counters["tokens-completion"] or 0) > 0, r1 and json.encode(r1.counters))
local log = turn_log("fg-sora-1")
check("the log names the endpoint and gives the numbers",
    has(log, "turn 1 on version 18: endpoint 'stand-in-house' (" .. house.url .. ")")
    and has(log, "turn 1 on version 18 fits: endpoint stand-in-house (" .. house.url
        .. "), asks 1, tries 1, problems: none, look calls 0, tokens ")
    and has(log, " sentences changed (12 and 1 recommended)"), log)
check("with no clone settings here, it says there is no clone and goes on (501)",
    has(log, "turn 1 on version 18: no clone of the project: ")
    and r1.counters["clone-failed"] == 1, log)
-- }}}

io.write("\n=== a reply that does not fit ===\n")
-- {{{
out, status = turn("fg-sora-1", 2)
sent = chats(house)
local r2 = receipt("fg-sora-1")
check("a reply past the edge is sent back and the model asked again",
    status == 0 and r2.counters.asks == 2 and r2.counters.tries == 2
    and r2.counters["problems-too-wide"] == 1, out)
check("the second ask holds the first reply and the compiler-style report", #sent == 3
    and #sent[3].body.messages == 4 and sent[3].body.messages[3].role == "assistant"
    and has(sent[3].body.messages[3].content, "past the edge")
    and has(sent[3].body.messages[4].content, "over the width of 40"),
    #sent == 3 and sent[3].body.messages[4] and sent[3].body.messages[4].content)
mine_ok, mine = pcall(canvas.read, slurp(OUT) or "", "from-voice")
check("what is written is the reply that fits", mine_ok and mine.headers.turn == 2
    and not has(table.concat(mine.rows, "\n"), "past the edge"))
check("the log has both tries", has(turn_log("fg-sora-1"), "try 1 does not fit: too-wide")
    and has(turn_log("fg-sora-1"), "try 2 fits"))
-- }}}

io.write("\n=== the advisory note ===\n")
-- {{{
local NOTE = ROOT .. "/output/turn-note-fg-sora-1"
check("no note after a turn within the recommendation", slurp(NOTE) == nil)
turn_settings({ ["recommended-words"] = "0" })
out, status = turn("fg-sora-1", 3)
check("a turn over the recommendation keeps its note for the next",
    status == 0 and has(slurp(NOTE), "last turn you changed ")
    and has(slurp(NOTE), "(0 recommended)")
    and receipt("fg-sora-1").counters["over-recommended"] == 1, slurp(NOTE) or out)
local NOTE_TEXT = slurp(NOTE)
turn_settings()
local before = #chats(house)
out, status = turn("fg-sora-1", 4)
sent = chats(house)
check("the next turn's prompt holds it", status == 0 and #sent > before
    and has(sent[before + 1].body.messages[2].content,
        ((NOTE_TEXT or "?"):gsub("%s+$", ""))),
    sent[before + 1] and sent[before + 1].body.messages[2].content)
check("and a turn within the recommendation drops it", slurp(NOTE) == nil)
check("the log says the note went in", has(turn_log("fg-sora-1"),
    "turn 4 on version 18: last turn's note is in the prompt"))
-- }}}

io.write("\n=== a voice with a key, and refusals ===\n")
-- {{{
out, status = turn("fg-sora-2", 1)
local far_sent = chats(far)
check("fg-sora-2 asks its own endpoint, with its key", status == 0 and #far_sent == 1
    and far_sent[1].authorized == true and receipt("fg-sora-2").counters["endpoint-far-away"] == 1,
    out)
check("its log says the key was used, and never shows it",
    has(turn_log("fg-sora-2"), "endpoint 'far-away' (" .. far.url .. "), with its key")
    and not has(turn_log("fg-sora-2"), KEY))
out, status = turn("fg-sora-3", 1)
check("a model error fails the turn, naming the endpoint, and writes nothing",
    status == 1 and has(out, "endpoint 'broken-chat' (" .. broken.url .. ")")
    and has(out, "the model fell over") and slurp(OUT) == nil, out)
check("its receipt counts the failure", receipt("fg-sora-3").counters.failed == 1)
local NO_LINE = BASE .. "/no-line"
write(NO_LINE, canvas_with({ "endpoint: fg-sora-2 far-away 5 " .. far.url .. " ~/keys/far" }))
out, status = turn("fg-sora-1", 5, NO_LINE)
check("a canvas with no endpoint line for this voice fails the turn, saying so",
    status == 1 and has(out, "the canvas names no endpoint for fg-sora-1") and slurp(OUT) == nil, out)
write(NO_LINE, "not a canvas\n")
out, status = turn("fg-sora-1", 5, NO_LINE)
check("a canvas that does not read fails the turn", status == 1 and slurp(OUT) == nil, out)
out, status = shell(TURN .. " --voice fg-sora-1")
check("missing arguments: the usage, exit 2", status == 2 and has(out, "usage: turn"), out)
-- }}}

io.write("\n=== a newer canvas while the model is still asked ===\n")
-- {{{
local SLOW = BASE .. "/slow"
write(SLOW, canvas_with({ "endpoint: fg-sora-1 slow-chat 5 " .. slow.url }))
local WAITING = runner.folder(ROOT, "fg-sora-1") .. "/waiting"
shell("mkdir -p " .. q(runner.folder(ROOT, "fg-sora-1")))
write(WAITING, CANVAS_TEXT)
turn_settings({ ["newer-canvas"] = '"give-way"' })
out, status = turn("fg-sora-1", 6, SLOW)
local gave = receipt("fg-sora-1")
check("give-way: after a reply that does not fit, it stops, exits 3 and writes nothing",
    status == turn_module.GAVE_WAY and slurp(OUT) == nil and gave.counters["gave-way"] == 1
    and gave.counters.asks == 1 and #chats(slow) == 1, out)
check("and says why", has(turn_log("fg-sora-1"), "after ask 1: gave way: a newer canvas is waiting")
    and has(turn_log("fg-sora-1"), "turn 6 on version 18 gave way"))
turn_settings()
out, status = turn("fg-sora-1", 6, SLOW)
local kept = receipt("fg-sora-1")
check("keep-going, the owner's word: it asks on with the newer canvas waiting, and sends",
    status == 0 and slurp(OUT) ~= nil and kept.counters.asks == 2
    and kept.counters["problems-too-wide"] == 1 and kept.counters["gave-way"] == nil, out)
os.remove(WAITING)
turn_settings({ ["newer-canvas"] = '"give-way"' })
out, status = turn("fg-sora-1", 7, SLOW)
check("give-way with nothing waiting goes on as keep-going does", status == 0
    and slurp(OUT) ~= nil, out)
turn_settings()

-- the runner, given a turn that gave way
local GAVE_SCRIPT = BASE .. "/gives-way"
write(GAVE_SCRIPT, "#!/bin/sh\nexit 3\n")
shell("chmod +x " .. q(GAVE_SCRIPT))
local run = goodbye.start("turn-runner-test", { root = ROOT })
local ctx = { root = ROOT, mailbox = BASE .. "/mailbox", voice = "fg-sora-1", guide = "guide",
        turn = GAVE_SCRIPT, folder = runner.folder(ROOT, "fg-sora-1") }
local counter_before = slurp(runner.counter_path(ROOT, "fg-sora-1"))
local what, base, number, line = runner.turn_once(ctx, run, GIVEN)
run:finish()
local rr = goodbye.read(ROOT .. "/output/goodbye-turn-runner-test")
check("the runner counts a turn that gave way, sends nothing and keeps the turn number",
    what == "gave-way" and base == 18 and number == nil
    and has(line, "gave way to a newer canvas") and rr.counters["turns-gave-way"] == 1
    and (rr.counters["turns-failed"] or 0) == 0
    and slurp(BASE .. "/mailbox/outbox/canvas") == nil
    and slurp(runner.counter_path(ROOT, "fg-sora-1")) == counter_before, line)
-- }}}

io.write("\n=== the whole round, with the real turn ===\n")
-- {{{
local series = dofile(DIR .. "/src/018-phase-1-series.lua")
local CHECKOUT = BASE .. "/the-project"
shell("mkdir -p " .. q(CHECKOUT) .. " && git -C " .. q(CHECKOUT) .. " init -q && git -C "
    .. q(CHECKOUT) .. " -c user.name=test -c user.email=test@localhost commit -q --allow-empty -m one")
local other = start_server("other", { { rewrite = "willow aspen" } })
write(ROOT .. "/endpoints", table.concat({
    'stand-in-house.url = "' .. house.url .. '"', 'stand-in-house.kind = "chat"',
    "stand-in-house.timeout = 5",
    'other-chat.url = "' .. other.url .. '"', 'other-chat.kind = "chat"',
    "other-chat.timeout = 5",
    'use.fg-sora-1 = "stand-in-house"', 'use.fg-sora-2 = "stand-in-house"',
    'use.fg-sora-3 = "stand-in-house"',
}, "\n") .. "\n")
write(ROOT .. "/input/blitter", series.SETTINGS)
write(ROOT .. "/input/turn-runner", slurp(DIR .. "/input/turn-runner"))
write(ROOT .. "/input/stand-in-turn", 'words = "unused"\nseconds = 0\n')
write(ROOT .. "/input/to-voices", 'send = "off"\nmailbox = "~/guide-mail"\ntell-the-voice = "on"\n'
    .. 'project-checkout = "' .. CHECKOUT .. '"\n')
write(ROOT .. "/input/rehearsal", 'minutes = 0.5\ncarrier = "stand-in"\nfirst-port = 41323\n'
    .. 'pace = 1\njitter = 0.5\nrmail = "luajit /nowhere/rmail.lua"\n')
check("the project's turn runner runs the real turn", has(slurp(ROOT .. "/input/turn-runner"),
    'turn = "scripts/turn"'))
local WS = SHM .. "/rehearsal"
local WS_ROOT = WS .. "/project/guide-feature"
-- in the background, so this test can switch an endpoint while it runs
shell("( " .. q(ROOT .. "/scripts/rehearse") .. " " .. q(ROOT) .. " --keep > "
    .. q(BASE .. "/rehearsal.out") .. " 2>&1; echo $? > " .. q(BASE .. "/rehearsal.status")
    .. " ) > /dev/null 2>&1 &")
-- halfway, fg-sora-2 is switched to the other endpoint, on kuvalu's file
for _ = 1, 150 do
    if slurp(WS_ROOT .. "/endpoints") then break end
    sleep(0.1)
end
sleep(14)
local use_out, use_status = shell("EXEC_TIER_ROOT=" .. q(WS .. "/exec") .. " ARTIFACT_TIER_ROOT="
    .. q(WS .. "/shm") .. " " .. q(WS_ROOT .. "/scripts/use-endpoint") .. " fg-sora-2 other-chat")
check("use-endpoint switches fg-sora-2 while the round runs", use_status == 0
    and use_out == "use.fg-sora-2: stand-in-house -> other-chat", use_out)
for _ = 1, 400 do
    if slurp(BASE .. "/rehearsal.status") then break end
    sleep(0.1)
end
local rout = slurp(BASE .. "/rehearsal.out") or ""
check("the rehearsal runs to its end", (slurp(BASE .. "/rehearsal.status") or ""):match("^0") ~= nil,
    rout)
local blitted = {}
for line in string.gmatch(slurp(SHM .. "/rehearsal-timings") or "", "[^\n]+") do
    local voice, outcome = line:match("^(%S+) %S+ %S+ %S+ (%S+)")
    if outcome == "blitted" then blitted[voice] = (blitted[voice] or 0) + 1 end
end
check("every voice's real turns came back as new versions",
    (blitted["fg-sora-1"] or 0) >= 1 and (blitted["fg-sora-2"] or 0) >= 1
    and (blitted["fg-sora-3"] or 0) >= 1, slurp(SHM .. "/rehearsal-timings"))
local WS_SHM = WS .. "/shm/guide-feature"
local before_switch, after_switch = 0, 0
for at, rest in string.gmatch(slurp(WS_SHM .. "/turn-fg-sora-2.log") or "", "(%S+) ([^\n]*)") do
    local name = rest:match("fits: endpoint (%S+)")
    if name then
        if name == "stand-in-house" then before_switch = before_switch + 1 end
        if name == "other-chat" then after_switch = after_switch + 1 end
    end
end
check("fg-sora-2's log shows turns on the house endpoint, then on the other after the switch",
    before_switch >= 1 and after_switch >= 1, slurp(WS_SHM .. "/turn-fg-sora-2.log"))
local others = 0
for _, r in ipairs(chats(other)) do
    others = others + 1
    local voice = r.body.messages[1].content:match("fg%-sora%-%d")
    if voice ~= "fg-sora-2" then others = -1000 end
end
check("only fg-sora-2 asked the other endpoint", others >= 1, others)
local r_ok = true
for _, voice in ipairs({ "fg-sora-1", "fg-sora-3" }) do
    local rlog = slurp(WS_SHM .. "/turn-" .. voice .. ".log") or ""
    if not has(rlog, "fits: endpoint stand-in-house") or has(rlog, "other-chat") then r_ok = false end
end
check("the other voices stayed on the house endpoint", r_ok)
local runner_log = slurp(WS_SHM .. "/turn-runner-fg-sora-1.log") or ""
check("the runner sent the real turns, and none failed",
    runner_log:match("turn %d+ on version %d+ sent") ~= nil and not has(runner_log, "failed"),
    runner_log:sub(-400))
if failed > 0 and KEEP then io.write("kept ", WS, "\n") else shell("rm -rf " .. q(WS)) end
-- }}}

for _, server in pairs(SERVERS) do stop_server(server) end
if failed > 0 and KEEP then io.write("kept ", BASE, "\n") else shell("rm -rf " .. q(BASE)) end
io.write(string.format("\nTests: %d passed, %d failed\n", passed, failed))
os.exit(failed == 0 and 0 or 1)
