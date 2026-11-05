#!/usr/bin/env luajit
-- 048-test-model-caller.lua
--
-- Tests the way guide-feature reaches its models (issue 401b): this
-- project's copy of the llama.cpp client (libs/llama-chat-client.lua), the
-- model caller (046) that picks a role's endpoint from the project-root
-- `endpoints` file, the file itself, and scripts/refresh-vendored.
--
-- The real servers (401a) run on the owner's machine with real models, so
-- here two stand-in llama.cpp servers (047) are started on 127.0.0.1, one
-- chat and one embedding, and every call goes over HTTP through curl exactly
-- as it will to llama-server. The cases the issue names: a chat reply, a
-- token count, an embedding, a stopped server reported as unreachable, a
-- use. line naming an endpoint that does not exist. And around them: the
-- file read again on every call (a use. line edited between two calls
-- switches the role), no fallback to another endpoint, a call the endpoint
-- is not for, a server error, a request over its time limit, and the copies'
-- upstream notes refreshed from a throwaway upstream repository.
--
-- For a general: each part of the project talks to exactly the model the
-- endpoints file names for it, right now, and says plainly which one failed.
--
-- usage:
--   luajit 048-test-model-caller.lua [--dir ROOT]

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
local function starts(text, piece) return string.sub(tostring(text), 1, #piece) == piece end
-- }}}

-- {{{ the throwaway project
local BASE = shell("mktemp -d")
BASE = shell("cd " .. q(BASE) .. " && pwd -P")
local ROOT = BASE .. "/project/guide-feature"
shell("mkdir -p " .. q(ROOT .. "/input") .. " " .. q(ROOT .. "/output") .. " "
    .. q(BASE .. "/exec") .. " " .. q(BASE .. "/shm") .. " " .. q(BASE .. "/servers"))
shell("ln -s " .. q(DIR .. "/src") .. " " .. q(ROOT .. "/src"))
shell("ln -s " .. q(DIR .. "/libs") .. " " .. q(ROOT .. "/libs"))
ffi.C.setenv("EXEC_TIER_ROOT", BASE .. "/exec", 1)
ffi.C.setenv("ARTIFACT_TIER_ROOT", BASE .. "/shm", 1)

local function write(path, text)
    local handle = assert(io.open(path, "wb"))
    handle:write(text)
    handle:close()
end
-- }}}

local caller = dofile(DIR .. "/src/046-model-caller.lua")
local client = dofile(DIR .. "/libs/llama-chat-client.lua")
local stand_in = dofile(DIR .. "/src/047-stand-in-llama.lua")
local json = dofile(DIR .. "/libs/dkjson.lua")

-- {{{ stand-in servers
local SERVERS = {}
local function start_server(name, kind, replies)
    local folder = BASE .. "/servers/" .. name
    shell("mkdir -p " .. q(folder))
    local command = "luajit " .. q(DIR .. "/src/047-stand-in-llama.lua") .. " --kind " .. kind
        .. " --port-file " .. q(folder .. "/port") .. " --requests " .. q(folder .. "/requests")
        .. " --parent $PPID"
    if replies then
        write(folder .. "/replies", json.encode(replies))
        command = command .. " --replies " .. q(folder .. "/replies")
    end
    local pid = shell(command .. " >" .. q(folder .. "/out") .. " 2>&1 & echo $!")
    local port
    for _ = 1, 100 do
        port = slurp(folder .. "/port")
        if port then break end
        sleep(0.05)
    end
    local server = { name = name, pid = pid, folder = folder,
                     port = tonumber(port), url = "http://127.0.0.1:" .. tostring(port and port:match("%d+")) }
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
local function endpoints(text) write(ROOT .. "/endpoints", text) end
-- }}}

io.write("\n=== the copies and their notes ===\n")
-- {{{
for _, name in ipairs({ "llama-chat-client.lua", "dkjson.lua" }) do
    local note = slurp(DIR .. "/libs/" .. name .. ".upstream") or ""
    check(name .. " has its upstream note: source, commit, date, changes",
        note:match("^source: /%S+" .. name:gsub("%p", "%%%0") .. "\n")
        and note:match("\ncommit: %x+\n") and note:match("\ncopied: %d+%-%d+%-%d+\n")
        and note:match("\nchanges: "), note)
end
check("the client finds dkjson beside itself, not through another project",
    not has(slurp(DIR .. "/libs/llama-chat-client.lua"), "AISTUFF_ROOT")
    and not has(slurp(DIR .. "/libs/llama-chat-client.lua"), "INFERENCE_CHAT_HOST"))
-- }}}

io.write("\n=== the stand-in servers ===\n")
-- {{{
local chat = start_server("chat", "chat", {
    "the canvas, edited",
    { status = 500, error = "the model fell over" },
    { content = "too late", delay = 3 },
    "after the slow one",
})
local embed = start_server("embed", "embedding")
local other = start_server("other", "chat", { "from the other one" })
check("the stand-ins listen on 127.0.0.1, on ports the system gave",
    chat.port and embed.port and other.port and chat.port ~= embed.port,
    tostring(chat.port) .. " " .. tostring(embed.port))
-- Every listening socket on the stand-ins' ports, from /proc/net/tcp and tcp6:
-- the local address must be 127.0.0.1 (0100007F) and nothing else.
local addresses = {}
for _, file in ipairs({ "/proc/net/tcp", "/proc/net/tcp6" }) do
    for line in string.gmatch(slurp(file) or "", "[^\n]+") do
        local address, port, state = string.match(line, "^%s*%d+:%s+(%x+):(%x+)%s+%x+:%x+%s+(%x+)")
        if state == "0A" then
            for _, server in ipairs({ chat, embed, other }) do
                if tonumber(port, 16) == server.port then addresses[#addresses + 1] = address end
            end
        end
    end
end
local only_loopback = #addresses == 3
for _, address in ipairs(addresses) do only_loopback = only_loopback and address == "0100007F" end
check("nothing listens on another address", only_loopback, table.concat(addresses, " "))
-- }}}

local GOOD = table.concat({
    "# the endpoints, as the test's stand-ins",
    'stand-in-chat.url      = "' .. chat.url .. '"',
    'stand-in-chat.kind     = "chat"',
    "stand-in-chat.timeout  = 2",
    'stand-in-embed.url     = "' .. embed.url .. '/"     # a trailing slash is fine',
    'stand-in-embed.kind    = "embedding"',
    "stand-in-embed.timeout = 5",
    'other-chat.url         = "' .. other.url .. '"',
    'other-chat.kind        = "chat"',
    "other-chat.timeout     = 5",
    'use.fg-sora-1 = "stand-in-chat"',
    'use.fg-sora-2 = "other-chat"',
    'use.embedder  = "stand-in-embed"',
}, "\n") .. "\n"
endpoints(GOOD)

io.write("\n=== a role's endpoint ===\n")
-- {{{
local ok, voice = pcall(caller.for_role, ROOT, "fg-sora-1")
check("a voice's endpoint is the one its use. line names", ok and voice.name == "stand-in-chat"
    and voice.url == chat.url and voice.kind == "chat" and voice.timeout == 2
    and voice.role == "fg-sora-1", voice)
check("it is described by name and address",
    ok and caller.describe(voice) == "'stand-in-chat' (" .. chat.url .. ")")
local embedder = caller.for_role(ROOT, "embedder")
check("the embedder's endpoint", embedder.name == "stand-in-embed" and embedder.kind == "embedding")
check("both answer", caller.reachable(voice) and caller.reachable(embedder))
-- }}}

io.write("\n=== a chat reply ===\n")
-- {{{
local conversation = {
    { role = "system", content = "you are fg-sora-1" },
    { role = "user", content = "the canvas:\nhello there world" },
}
local cok, text, info = pcall(caller.chat, voice, conversation)
check("the reply is the server's", cok and text == "the canvas, edited", text)
check("the token usage comes back", cok and info.usage.prompt_tokens == 8
    and info.usage.completion_tokens == 3 and info.usage.total_tokens == 11,
    cok and json.encode(info.usage))
check("the seconds and the endpoint's name come back",
    cok and type(info.seconds) == "number" and info.seconds >= 0 and info.endpoint == "stand-in-chat")
local sent = requests(chat)
local last = sent[#sent]
check("the whole conversation was sent, in order, to /v1/chat/completions",
    last and last.path == "/v1/chat/completions" and #last.body.messages == 2
    and last.body.messages[1].role == "system" and last.body.messages[2].content
        == "the canvas:\nhello there world" and last.body.stream == false,
    last and json.encode(last))
check("the model is named after the endpoint", last and last.body.model == "stand-in-chat")
local bad_byte = "caf\233 ok"
pcall(caller.chat, voice, { { role = "user", content = bad_byte } })
sent = requests(chat)
check("a broken UTF-8 byte is replaced before it is sent",
    sent[#sent].body.messages[1].content == "caf\239\191\189 ok", sent[#sent].body.messages[1].content)
-- }}}

io.write("\n=== a server error, and a request over its limit ===\n")
-- {{{
-- The broken-byte call above took the 500 reply; the next is the slow one.
local sok, problem = pcall(caller.chat, voice, conversation)
check("a request past the endpoint's timeout is an error naming the endpoint",
    not sok and starts(problem, "endpoint 'stand-in-chat' (" .. chat.url .. "): unreachable")
    and has(problem, "timed out"), problem)
local fresh = start_server("errors", "chat", { { status = 500, error = "the model fell over" } })
endpoints(GOOD .. 'errors.url = "' .. fresh.url .. '"\nerrors.kind = "chat"\nerrors.timeout = 5\n'
    .. 'use.fg-sora-3 = "errors"\n')
local eok, eproblem = pcall(caller.chat, caller.for_role(ROOT, "fg-sora-3"), conversation)
check("a server error is an error naming the endpoint and the server's words",
    not eok and starts(eproblem, "endpoint 'errors' (" .. fresh.url .. "): server error (HTTP 500)")
    and has(eproblem, "the model fell over"), eproblem)
stop_server(fresh)
endpoints(GOOD)
-- }}}

io.write("\n=== a token count ===\n")
-- {{{
local tok, count = pcall(caller.count_tokens, voice, "one two three four")
check("the server's count", tok and count == 4, count)
check("empty text is 0 with no request", caller.count_tokens(voice, "") == 0)
check("an embedding server counts too, with its own model",
    caller.count_tokens(embedder, "one two") == 2)
sent = requests(chat)
check("the count went to /tokenize", sent[#sent].path == "/tokenize"
    and sent[#sent].body.content == "one two three four")
-- }}}

io.write("\n=== an embedding ===\n")
-- {{{
local TEXTS = { "the red door", "a blue window", "green" }
local vok, vectors = pcall(caller.embed, embedder, TEXTS)
check("one vector per text", vok and #vectors == 3, vectors)
if vok then
    check("each vector has the server's length", #vectors[1] == 8 and #vectors[3] == 8)
    -- The stand-in lists its vectors last first, as the API allows: each
    -- belongs to the text its index names, not to its place in the list.
    local matches = true
    for number, text in ipairs(TEXTS) do
        local expected = stand_in.embedding(text, 8)
        for index = 1, 8 do
            matches = matches and math.abs(vectors[number][index] - expected[index]) < 1e-9
        end
    end
    check("each vector is the server's own for its text, in the order sent", matches)
    local again = caller.embed(embedder, { "green", "the red door" })
    local same = true
    for index = 1, 8 do
        same = same and again[2][index] == vectors[1][index] and again[1][index] == vectors[3][index]
    end
    check("the same text gives the same vector", same)
    local differs = false
    for index = 1, 8 do differs = differs or vectors[1][index] ~= vectors[2][index] end
    check("different texts give different vectors", differs)
end
local one = caller.embed(embedder, "just one")
check("a single text gives a list of one vector", #one == 1 and #one[1] == 8)
sent = requests(embed)
check("the texts went to /v1/embeddings as a list", sent[#sent].path == "/v1/embeddings"
    and type(sent[#sent].body.input) == "table" and sent[#sent].body.input[1] == "just one")
-- }}}

io.write("\n=== a call the endpoint is not for ===\n")
-- {{{
local before = #requests(embed)
local kok, kproblem = pcall(caller.chat, embedder, conversation)
check("chat on an embedding endpoint is refused before anything is sent",
    not kok and starts(kproblem, "endpoint 'stand-in-embed' (" .. embedder.url .. "):")
    and has(kproblem, "it is an embedding endpoint, and a chat call needs a chat endpoint") and #requests(embed) == before, kproblem)
local k2ok, k2problem = pcall(caller.embed, voice, "text")
check("an embedding on a chat endpoint is refused", not k2ok
    and has(k2problem, "it is a chat endpoint, and an embedding call needs an embedding endpoint"),
    k2problem)
local vectors2, server_says = client.embed(voice, "text")
check("a chat server asked for embeddings says so, as llama-server does",
    vectors2 == nil and has(server_says, "server error (HTTP 501)")
    and has(server_says, "--embeddings"), server_says)
-- }}}

io.write("\n=== read on every call ===\n")
-- {{{
endpoints((GOOD:gsub('use.fg%-sora%-1 = "stand%-in%-chat"', 'use.fg-sora-1 = "other-chat"')))
local switched = caller.for_role(ROOT, "fg-sora-1")
check("an edited use. line switches the role on the next call, with nothing restarted",
    switched.name == "other-chat" and select(1, caller.chat(switched, conversation))
        == "from the other one")
endpoints(GOOD)
check("and back again", caller.for_role(ROOT, "fg-sora-1").name == "stand-in-chat")
-- }}}

io.write("\n=== refused endpoints ===\n")
-- {{{
local function refused(name, text, role, start, part)
    endpoints(text)
    local rok, message = pcall(caller.for_role, ROOT, role)
    check(name, not rok and starts(message, start) and has(message, part), message)
end
refused("a use. line naming an endpoint that does not exist",
    GOOD .. 'use.fg-sora-3 = "kuvalu-gone"\n', "fg-sora-1",
    "endpoints:14:", "use.fg-sora-3 names 'kuvalu-gone', which is not an endpoint in this file")
refused("a role with no use. line", GOOD, "distiller",
    "endpoints:", "there is no use.distiller line")
refused("an endpoint with no timeout",
    (GOOD:gsub("stand%-in%-chat%.timeout  = 2\n", "")), "fg-sora-1",
    "endpoints:", "has no stand-in-chat.timeout")
refused("an endpoint that needs a key, before 402",
    GOOD .. 'stand-in-chat.key-file = "/nowhere/key"\n', "fg-sora-1",
    "endpoint 'stand-in-chat' (" .. chat.url .. "):", "issue 402")
refused("a voice pointed at an embedding endpoint",
    (GOOD:gsub('use.fg%-sora%-2 = "other%-chat"', 'use.fg-sora-2 = "stand-in-embed"')), "fg-sora-1",
    "endpoints:12:", "needs a chat endpoint")
shell("rm " .. q(ROOT .. "/endpoints"))
local nok, nproblem = pcall(caller.for_role, ROOT, "fg-sora-1")
check("no endpoints file", not nok and has(nproblem, "no endpoints file"), nproblem)
endpoints(GOOD)
-- }}}

io.write("\n=== a stopped server ===\n")
-- {{{
stop_server(chat)
local down = caller.for_role(ROOT, "fg-sora-1")
check("a stopped server does not answer", not caller.reachable(down))
local others_before = #requests(other)
local dok, dproblem = pcall(caller.chat, down, conversation)
check("a chat to it is an error naming the endpoint and its address",
    not dok and starts(dproblem, "endpoint 'stand-in-chat' (" .. chat.url .. "): unreachable: "
        .. chat.url .. "/v1/chat/completions"), dproblem)
check("there is no fallback: the other chat endpoint was not asked",
    #requests(other) == others_before)
local tok2, tproblem = pcall(caller.count_tokens, down, "a b")
check("a token count to it is an error too", not tok2 and has(tproblem, "unreachable"), tproblem)
-- }}}

io.write("\n=== the client by hand ===\n")
-- {{{
local CLIENT = "luajit " .. q(DIR .. "/libs/llama-chat-client.lua")
local out, status = shell(CLIENT .. " --url " .. q(other.url) .. " --timeout 5 --ping")
check("--ping says reachable", status == 0 and has(out, "reachable: " .. other.url), out)
out, status = shell(CLIENT .. " --url " .. q(chat.url) .. " --timeout 5 --ping")
check("--ping on a stopped server exits 1", status == 1 and has(out, "UNREACHABLE"), out)
out, status = shell(CLIENT .. " --url " .. q(other.url) .. " --timeout 5 --tokens 'a b c'")
check("--tokens prints the count", status == 0 and out == "3", out)
out, status = shell(CLIENT .. " --url " .. q(embed.url) .. " --timeout 5 --embed 'a b'")
check("--embed prints a vector", status == 0 and out:match("^%[.*%]$") ~= nil, out)
out, status = shell(CLIENT .. " --ping")
check("without --url it says what it needs", status == 2 and has(out, "--url URL"), out)
-- }}}

io.write("\n=== this project's endpoints file ===\n")
-- {{{
-- Read in the throwaway root, so the project's own tmp/ is never touched.
write(ROOT .. "/endpoints", slurp(DIR .. "/endpoints") or "")
local pok, project = pcall(caller.read, ROOT)
check("it is well formed", pok, project)
if pok then
    for _, role in ipairs({ "fg-sora-1", "fg-sora-2", "fg-sora-3", "distiller", "embedder" }) do
        local rok, record = pcall(caller.for_role, ROOT, role)
        check("use." .. role .. " names an endpoint with a timeout", rok and record.timeout ~= nil, record)
    end
    for name, one in pairs(project.endpoints) do
        check(name .. " gives its port in its url", has(one.url, ":" .. tostring(one.port)), one.url)
    end
end
-- }}}

io.write("\n=== refresh-vendored ===\n")
-- {{{
-- A throwaway upstream repository with two files, copied into a throwaway
-- project's libs/ at the first commit, one unchanged and one with this
-- project's own change; then the upstream moves on.
local UP = BASE .. "/upstream"
local LIBS = BASE .. "/vendor/libs"
shell("mkdir -p " .. q(UP) .. " " .. q(LIBS) .. " " .. q(BASE .. "/vendor/scripts"))
shell("cp " .. q(DIR .. "/scripts/refresh-vendored") .. " " .. q(BASE .. "/vendor/scripts/"))
local GIT = "git -C " .. q(UP) .. " -c user.name=test -c user.email=test@invalid "
shell(GIT .. "init -q")
write(UP .. "/plain.lua", "one\ntwo\nthree\n")
write(UP .. "/changed.lua", "alpha\nbeta\ngamma\ndelta\nepsilon\n")
shell(GIT .. "add plain.lua changed.lua && " .. GIT .. "commit -q -m first")
local FIRST = shell(GIT .. "rev-parse HEAD")
write(LIBS .. "/plain.lua", "one\ntwo\nthree\n")
write(LIBS .. "/changed.lua", "alpha\nbeta, ours\ngamma\ndelta\nepsilon\n")
local function note(name, changes)
    write(LIBS .. "/" .. name .. ".upstream", "source: " .. UP .. "/" .. name .. "\ncommit: "
        .. FIRST .. "\ncopied: 2026-01-01\nchanges: " .. changes .. "\n")
end
note("plain.lua", "none.")
note("changed.lua", "beta is ours.")
local REFRESH = q(BASE .. "/vendor/scripts/refresh-vendored") .. " --dir " .. q(BASE .. "/vendor")
out, status = shell(REFRESH)
check("nothing moved: both up to date", status == 0 and has(out, "plain.lua: up to date")
    and has(out, "changed.lua: up to date"), out)

write(UP .. "/plain.lua", "one\ntwo\nthree\nfour\n")
write(UP .. "/changed.lua", "alpha\nbeta\ngamma\ndelta\nepsilon, theirs\n")
shell(GIT .. "commit -q -am second")
local SECOND = shell(GIT .. "rev-parse HEAD")
out, status = shell(REFRESH .. " --check")
check("--check says which are behind and changes nothing", status == 0
    and has(out, "plain.lua: the upstream moved") and slurp(LIBS .. "/plain.lua") == "one\ntwo\nthree\n"
    and has(slurp(LIBS .. "/plain.lua.upstream"), FIRST), out)
out, status = shell(REFRESH .. " plain.lua")
check("a copy with no changes of its own is replaced and its note moved on", status == 0
    and slurp(LIBS .. "/plain.lua") == "one\ntwo\nthree\nfour\n"
    and has(slurp(LIBS .. "/plain.lua.upstream"), "commit: " .. SECOND)
    and has(slurp(LIBS .. "/plain.lua.upstream"), "changes: none.")
    and not has(slurp(LIBS .. "/plain.lua.upstream"), "copied: 2026-01-01"), out)
check("the upstream's changes were shown", has(out, "+four"), out)
check("naming one copy leaves the other alone", has(slurp(LIBS .. "/changed.lua.upstream"), FIRST))
out, status = shell(REFRESH)
check("a copy with changes of its own gets the upstream's changes and keeps its own",
    status == 0 and slurp(LIBS .. "/changed.lua") == "alpha\nbeta, ours\ngamma\ndelta\nepsilon, theirs\n"
    and has(slurp(LIBS .. "/changed.lua.upstream"), "commit: " .. SECOND)
    and has(slurp(LIBS .. "/changed.lua.upstream"), "changes: beta is ours."), out)

write(UP .. "/changed.lua", "alpha\nbeta, theirs\ngamma\ndelta\nepsilon, theirs\n")
shell(GIT .. "commit -q -am third")
out, status = shell(REFRESH)
check("a conflict leaves the copy and its note alone, and the merge beside them",
    status == 1 and slurp(LIBS .. "/changed.lua") == "alpha\nbeta, ours\ngamma\ndelta\nepsilon, theirs\n"
    and has(slurp(LIBS .. "/changed.lua.upstream"), "commit: " .. SECOND)
    and has(slurp(LIBS .. "/changed.lua.merge"), "<<<<<<< this project"), out)
-- }}}

for _, server in pairs(SERVERS) do stop_server(server) end
shell("rm -rf " .. q(BASE))
io.write(string.format("\nTests: %d passed, %d failed\n", passed, failed))
os.exit(failed == 0 and 0 or 1)
