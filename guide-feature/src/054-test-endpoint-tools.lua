#!/usr/bin/env luajit
-- 054-test-endpoint-tools.lua
--
-- Tests issue 402, choosing endpoints at runtime: scripts/use-endpoint and
-- scripts/list-endpoints (053), keys for outside providers (046's load_key
-- and the client's Authorization header), and a voice finding its endpoint
-- in the canvas kuvalu sent it (046's from_canvas).
--
-- Three stand-in llama.cpp servers (047) run on 127.0.0.1: a chat server, a
-- second chat server that asks for a key (--key, as llama-server's --api-key
-- does with --api-key-file), and an embedding server. The key lives in a file outside the
-- throwaway project, as the owner's will live outside the repository.
--
-- For a general: switching which model a part of the project uses is one
-- command that checks the model is there and answering before it changes
-- anything; and a key for an outside model is read from a private file and
-- never shows anywhere another program could see it.
--
-- usage:
--   luajit 054-test-endpoint-tools.lua [--dir ROOT]

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
local function q(text) return "'" .. string.gsub(text, "'", "'\\''") .. "'" end
local function has(text, piece) return text ~= nil and string.find(text, piece, 1, true) ~= nil end
local function sleep(seconds) ffi.C.poll(nil, 0, math.floor(seconds * 1000)) end
local function write(path, text)
    local handle = assert(io.open(path, "wb"))
    handle:write(text)
    handle:close()
end
-- }}}

-- {{{ the throwaway project
local BASE = shell("mktemp -d")
BASE = shell("cd " .. q(BASE) .. " && pwd -P")
local ROOT = BASE .. "/project/guide-feature"
local HOME = BASE .. "/home"
shell("mkdir -p " .. q(ROOT .. "/input") .. " " .. q(ROOT .. "/output") .. " "
    .. q(BASE .. "/exec") .. " " .. q(BASE .. "/shm") .. " " .. q(BASE .. "/servers") .. " "
    .. q(HOME .. "/.config/guide-feature/keys"))
for _, name in ipairs({ "src", "libs", "scripts" }) do
    shell("ln -s " .. q(DIR .. "/" .. name) .. " " .. q(ROOT .. "/" .. name))
end
ffi.C.setenv("EXEC_TIER_ROOT", BASE .. "/exec", 1)
ffi.C.setenv("ARTIFACT_TIER_ROOT", BASE .. "/shm", 1)
-- `~` in a key-file path is the HOME of whoever runs the turn; here, a
-- folder of the throwaway, so no real home is read.
ffi.C.setenv("HOME", HOME, 1)
-- }}}

local tools = dofile(DIR .. "/src/053-endpoint-tools.lua")
local caller = dofile(DIR .. "/src/046-model-caller.lua")
local canvas = dofile(DIR .. "/src/006-canvas-text.lua")
local json = dofile(DIR .. "/libs/dkjson.lua")

-- {{{ stand-in servers
local SERVERS = {}
local function start_server(name, kind, replies, key)
    local folder = BASE .. "/servers/" .. name
    shell("mkdir -p " .. q(folder))
    local command = "luajit " .. q(DIR .. "/src/047-stand-in-llama.lua") .. " --kind " .. kind
        .. " --port-file " .. q(folder .. "/port") .. " --requests " .. q(folder .. "/requests")
        .. " --parent $PPID"
    if replies then
        write(folder .. "/replies", json.encode(replies))
        command = command .. " --replies " .. q(folder .. "/replies")
    end
    if key then command = command .. " --key-file " .. q(key) end
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
-- }}}

-- The key: made up for the test, long enough not to turn up by chance.
local KEY = "stand-in-key-7f3a9c2e51b04d68"
local KEY_FILE = HOME .. "/.config/guide-feature/keys/far-away"
-- Header files an earlier run that died left behind (/tmp/lua_* is shared),
-- so this run counts only its own.
local LEFT_BEFORE = select(1, shell("grep -lsF " .. q(KEY) .. " /tmp/lua_* || true")) or ""
write(KEY_FILE, KEY .. "\n")
shell("chmod 600 " .. q(KEY_FILE))

local chat = start_server("chat", "chat")
local far = start_server("far", "chat", { "from far away", { content = "slowly", delay = 2 },
                                          "from far away" }, KEY_FILE)
local embed = start_server("embed", "embedding")
-- A port nothing listens on: a stopped stand-in's.
local gone = start_server("gone", "chat")
stop_server(gone)

local GOOD = table.concat({
    "# the endpoints, as the test's stand-ins",
    'stand-in-chat.url    = "' .. chat.url .. '"',
    'stand-in-chat.kind   = "chat"',
    "stand-in-chat.timeout = 5",
    'far-away.url         = "' .. far.url .. '"',
    'far-away.kind        = "chat"',
    "far-away.timeout     = 5",
    'far-away.key-file    = "~/.config/guide-feature/keys/far-away"',
    'stand-in-embed.url   = "' .. embed.url .. '"',
    'stand-in-embed.kind  = "embedding"',
    "stand-in-embed.timeout = 5",
    'gone-chat.url        = "' .. gone.url .. '"',
    'gone-chat.kind       = "chat"',
    "gone-chat.timeout    = 2",
    'no-limit.url         = "' .. chat.url .. '"',
    'no-limit.kind        = "chat"',
    "",
    'use.fg-sora-1  = "stand-in-chat"   # the house model',
    'use.fg-sora-10 = "stand-in-chat"',
    'use.embedder   = "stand-in-embed"',
}, "\n") .. "\n"
local ENDPOINTS = ROOT .. "/endpoints"
write(ENDPOINTS, GOOD)

io.write("\n=== the use. line, rewritten ===\n")
-- {{{
local text = tools.rewrite(GOOD, "fg-sora-1", "far-away")
check("only the one line changes, its spacing and comment kept",
    text == (GOOD:gsub('use.fg%-sora%-1  = "stand%-in%-chat"   # the house model',
        'use.fg-sora-1  = "far-away"   # the house model')) and text ~= GOOD, text)
check("a role whose name starts another's leaves that one alone",
    has(text, 'use.fg-sora-10 = "stand-in-chat"'))
local added = tools.rewrite(GOOD, "distiller", "stand-in-chat")
check("a role with no line gets one at the end",
    added == GOOD .. 'use.distiller = "stand-in-chat"\n', added)
check("a file with no last newline still ends in one",
    tools.rewrite('use.a = "x"', "a", "y") == 'use.a = "y"\n')
-- }}}

io.write("\n=== use-endpoint ===\n")
-- {{{
local USE = q(ROOT .. "/scripts/use-endpoint")
local LIST = q(ROOT .. "/scripts/list-endpoints")
local out, status = shell(USE .. " fg-sora-1 far-away")
check("it switches a voice to the outside provider and says what changed",
    status == 0 and out == "use.fg-sora-1: stand-in-chat -> far-away", out)
check("the file has the new line, with its comment",
    has(slurp(ENDPOINTS), 'use.fg-sora-1  = "far-away"   # the house model'))
check("and nothing else in it changed", slurp(ENDPOINTS) == text)
check("no endpoints.part is left behind", slurp(ENDPOINTS .. ".part") == nil)
check("the role's next turn reads it, with nothing restarted",
    caller.for_role(ROOT, "fg-sora-1").name == "far-away")
check("the check asked the endpoint, with the key",
    #requests(far) >= 2 and requests(far)[#requests(far)].path == "/tokenize"
    and requests(far)[#requests(far)].authorized == true, json.encode(requests(far)))
local inode = select(1, shell("stat -c %i " .. q(ENDPOINTS)))
out, status = shell(USE .. " fg-sora-1 far-away")
check("the same choice again says so and writes nothing",
    status == 0 and out == "use.fg-sora-1: far-away (already)"
    and select(1, shell("stat -c %i " .. q(ENDPOINTS))) == inode, out)
out, status = shell(USE .. " distiller stand-in-chat")
check("a role with no line gets one", status == 0
    and out == "use.distiller: unset -> stand-in-chat"
    and caller.for_role(ROOT, "distiller").name == "stand-in-chat", out)
out, status = shell(USE .. " fg-sora-1 stand-in-chat")
check("and back again", status == 0 and out == "use.fg-sora-1: far-away -> stand-in-chat"
    and caller.for_role(ROOT, "fg-sora-1").name == "stand-in-chat", out)
check("switching does not touch fg-sora-10",
    caller.for_role(ROOT, "fg-sora-10").name == "stand-in-chat")
-- }}}

io.write("\n=== use-endpoint refuses, and writes nothing ===\n")
-- {{{
write(ENDPOINTS, GOOD)
local REFUSALS = {}
local function refused(name, args, part, setup)
    if setup then setup() end
    local held = slurp(ENDPOINTS)
    local rout, rstatus = shell(USE .. " " .. args)
    check(name, rstatus == 1 and has(rout, part) and slurp(ENDPOINTS) == held
        and slurp(ENDPOINTS .. ".part") == nil, rout)
    REFUSALS[#REFUSALS + 1] = rout or ""
    return rout
end
local rout = refused("an endpoint that is not in the file", "fg-sora-1 kuvalu-gone",
    "use.fg-sora-1 stays stand-in-chat: there is no endpoint 'kuvalu-gone' in endpoints")
check("and it lists the endpoints there are", has(rout, "far-away, gone-chat, no-limit, "
    .. "stand-in-chat, stand-in-embed"), rout)
refused("a voice pointed at an embedding endpoint", "fg-sora-1 stand-in-embed",
    "'stand-in-embed' is an embedding endpoint, and fg-sora-1 needs a chat one")
refused("the embedder pointed at a chat endpoint", "embedder stand-in-chat",
    "use.embedder stays stand-in-embed: 'stand-in-chat' is a chat endpoint, and embedder "
    .. "needs an embedding one")
refused("an endpoint with no timeout", "fg-sora-1 no-limit", "has no no-limit.timeout")
refused("an endpoint that does not answer", "fg-sora-1 gone-chat",
    "endpoint 'gone-chat' (" .. gone.url .. ") does not answer now")
refused("a role name that is not one", "'fg sora' stand-in-chat", "'fg sora' is not a role name")
-- A rewrite that went wrong (here, made to): the new file is read back
-- before it replaces the old one, so it never does.
local rewrite = tools.rewrite
tools.rewrite = function(old_text) return old_text .. "use.fg-sora-1 = 12\n" end
local held = slurp(ENDPOINTS)
local bok, bproblem = pcall(tools.use, ROOT, "fg-sora-1", "far-away")
tools.rewrite = rewrite
check("a rewritten file that does not read back is never put in place",
    not bok and has(bproblem, "use.fg-sora-1 stays stand-in-chat: the rewritten file did not "
        .. "read back as it should") and slurp(ENDPOINTS) == held
    and slurp(ENDPOINTS .. ".part") == nil, bproblem)
local out2, status2 = shell(USE .. " fg-sora-1")
check("too few words: the usage, and exit 2", status2 == 2 and has(out2, "usage:"), out2)
-- }}}

io.write("\n=== keys ===\n")
-- {{{
local function with_key_file(path)
    return function()
        write(ENDPOINTS, (GOOD:gsub('far%-away%.key%-file    = "[^"]*"',
            'far-away.key-file    = "' .. path .. '"')))
    end
end
refused("a key file that is missing", "fg-sora-1 far-away",
    "its key file " .. BASE .. "/nowhere is missing or cannot be read",
    with_key_file(BASE .. "/nowhere"))
write(BASE .. "/wrong-key", "not-the-key\n")
refused("a key the provider does not take", "fg-sora-1 far-away",
    "server error (HTTP 401): Invalid API Key", with_key_file(BASE .. "/wrong-key"))
check("the stand-in saw that request as not authorized",
    requests(far)[#requests(far)].authorized == false)
write(ROOT .. "/input/far-away-key", KEY .. "\n")
refused("a key file inside the project", "fg-sora-1 far-away",
    "is inside the project; keys live outside the repository",
    with_key_file(ROOT .. "/input/far-away-key"))
shell("rm " .. q(ROOT .. "/input/far-away-key"))
write(BASE .. "/two-keys", "one two\n")
refused("a key file that holds more than one key", "fg-sora-1 far-away",
    "does not hold one key on one line", with_key_file(BASE .. "/two-keys"))
write(BASE .. "/empty-key", "\n")
refused("an empty key file", "fg-sora-1 far-away", "does not hold one key on one line",
    with_key_file(BASE .. "/empty-key"))
write(ENDPOINTS, GOOD)
check("no refusal ever shows the key", not has(table.concat(REFUSALS, "\n"), KEY))

-- An endpoint with no key file is sent no key.
local plain = caller.for_role(ROOT, "fg-sora-10")
caller.count_tokens(plain, "a b")
check("an endpoint with no key file is sent no Authorization header",
    requests(chat)[#requests(chat)].authorized == nil and plain.key == nil)

-- The key while a request is in flight: a chat to far-away that the
-- stand-in answers after a second, run in another process, so this one can
-- look meanwhile at every process's command line and at the header file.
write(ENDPOINTS, (GOOD:gsub('use.fg%-sora%-1  = "stand%-in%-chat"', 'use.fg-sora-1  = "far-away"')))
local far_endpoint = caller.for_role(ROOT, "fg-sora-1")
check("the key is read from its file into the endpoint", far_endpoint.key == KEY)
local first = caller.chat(far_endpoint, { { role = "user", content = "hello" } })
check("a chat with the key is answered", first == "from far away", first)
write(BASE .. "/in-flight.lua", table.concat({
    "local caller = dofile(" .. string.format("%q", DIR .. "/src/046-model-caller.lua") .. ")",
    "local e = caller.for_role(" .. string.format("%q", ROOT) .. ", 'fg-sora-1')",
    "io.write((caller.chat(e, { { role = 'user', content = 'slow' } })))",
}, "\n"))
shell("luajit " .. q(BASE .. "/in-flight.lua") .. " > " .. q(BASE .. "/in-flight.out")
    .. " 2>&1 & echo $! > " .. q(BASE .. "/in-flight.pid"))
sleep(0.5)
local on_command_lines = false
for pid in string.gmatch(select(1, shell("ls /proc")) or "", "%d+") do
    local line = slurp("/proc/" .. pid .. "/cmdline")
    if line and has(line, KEY) then on_command_lines = true end
end
check("while a request is in flight, the key is on no process's command line",
    not on_command_lines)
local header_files = select(1, shell("grep -lsF " .. q(KEY) .. " /tmp/lua_* || true"))
for path in string.gmatch(LEFT_BEFORE, "[^\n]+") do
    header_files = header_files:gsub(path:gsub("%p", "%%%0") .. "\n?", "")
end
local modes_ok, header_count = true, 0
for path in string.gmatch(header_files or "", "[^\n]+") do
    header_count = header_count + 1
    local mode = select(1, shell("stat -c %a " .. q(path)))
    if mode ~= "600" then modes_ok = false end
end
check("the header is in a temporary file only its owner can read",
    header_count == 1 and modes_ok, header_files)
for _ = 1, 60 do
    if (slurp(BASE .. "/in-flight.out") or "") ~= "" then break end
    sleep(0.1)
end
check("the slow request was answered", slurp(BASE .. "/in-flight.out") == "slowly",
    slurp(BASE .. "/in-flight.out"))
local left = select(1, shell("grep -lsF " .. q(KEY) .. " /tmp/lua_* || true"))
for path in string.gmatch(LEFT_BEFORE, "[^\n]+") do
    left = left:gsub(path:gsub("%p", "%%%0") .. "\n?", "")
end
check("and afterwards the header file is gone", left == "", left)
local logged = slurp(far.folder .. "/requests") or ""
check("the stand-in's request log never holds the key", not has(logged, KEY))
write(ENDPOINTS, GOOD)
-- }}}

io.write("\n=== a voice's endpoint, from the canvas ===\n")
-- {{{
local CANVAS = (slurp(DIR .. "/assets/test-prompts/01-turn-prompt.canvas") or "")
    :gsub("endpoints:\n.*$", "endpoints:\n"
        .. "endpoint: fg-sora-1 stand-in-chat 5 " .. chat.url .. "\n"
        .. "endpoint: fg-sora-2 far-away 5 " .. far.url .. " ~/.config/guide-feature/keys/far-away\n")
local rok, record = pcall(canvas.read, CANVAS, "to-voices")
check("the canvas reads", rok, record)
if rok then
    local one = caller.from_canvas(record, "fg-sora-1", ROOT)
    check("fg-sora-1 gets its own line: name, address, timeout, a chat endpoint",
        one.name == "stand-in-chat" and one.url == chat.url and one.timeout == 5
        and one.kind == "chat" and one.role == "fg-sora-1" and one.key == nil)
    check("and it answers", caller.chat(one, { { role = "user", content = "hi" } }) ~= nil)
    local two = caller.from_canvas(record, "fg-sora-2", ROOT)
    check("fg-sora-2 gets the outside provider, its key read on this machine",
        two.name == "far-away" and two.url == far.url and two.key == KEY)
    check("and a chat with that key is answered",
        caller.chat(two, { { role = "user", content = "hi" } }) == "from far away")
    local tok, problem = pcall(caller.from_canvas, record, "fg-sora-3", ROOT)
    check("a voice the canvas names no endpoint for is refused, saying why",
        not tok and has(problem, "the canvas names no endpoint for fg-sora-3"), problem)
    local moved = (CANVAS:gsub(" ~/.config/guide%-feature/keys/far%-away", " " .. BASE .. "/nowhere"))
    local mok, mrecord = pcall(canvas.read, moved, "to-voices")
    local kok, kproblem = pcall(caller.from_canvas, mrecord, "fg-sora-2", ROOT)
    check("a key file the voice does not have is an error for that turn",
        mok and not kok and has(kproblem, "endpoint 'far-away' (" .. far.url .. ")")
        and has(kproblem, "is missing"), kproblem)
end
-- }}}

io.write("\n=== list-endpoints ===\n")
-- {{{
local rows = tools.list(ROOT)
local by = {}
for _, row in ipairs(rows) do by[row.name] = row end
check("every endpoint, sorted by name", #rows == 5 and rows[1].name == "far-away"
    and rows[5].name == "stand-in-embed")
check("each with its kind, address, and the roles that use it",
    by["stand-in-chat"].kind == "chat" and by["stand-in-chat"].url == chat.url
    and table.concat(by["stand-in-chat"].roles, ",") == "fg-sora-1,fg-sora-10"
    and table.concat(by["stand-in-embed"].roles, ",") == "embedder"
    and #by["far-away"].roles == 0)
check("whether it answers now", by["stand-in-chat"].answers and by["far-away"].answers
    and by["stand-in-embed"].answers and not by["gone-chat"].answers)
check("and why not", by["gone-chat"].problem == "does not answer now"
    and by["no-limit"].problem == "no no-limit.timeout")
out, status = shell(LIST)
check("the script prints one line each, then any problem under it", status == 0
    and has(out, "stand-in-chat   chat       answers      " .. chat.url
        .. "  used by: fg-sora-1, fg-sora-10")
    and has(out, "gone-chat       chat       no answer    " .. gone.url .. "  used by: nothing\n"
        .. "                does not answer now")
    and has(out, "stand-in-embed  embedding  answers"), out)
write(ENDPOINTS, (GOOD:gsub('far%-away%.key%-file    = "[^"]*"',
    'far-away.key-file    = "' .. BASE .. '/nowhere"')))
out, status = shell(LIST)
check("an endpoint whose key file cannot be read is listed with the reason",
    status == 0 and has(out, "far-away        chat       no answer")
    and has(out, "its key file " .. BASE .. "/nowhere is missing"), out)
write(ENDPOINTS, "this is not an endpoints file\n")
out, status = shell(LIST)
check("a broken file is an error, exit 1", status == 1 and has(out, "endpoints:1:"), out)
write(ENDPOINTS, GOOD)
-- }}}

for _, server in pairs(SERVERS) do stop_server(server) end
shell("rm -rf " .. q(BASE))
io.write(string.format("\nTests: %d passed, %d failed\n", passed, failed))
os.exit(failed == 0 and 0 or 1)
