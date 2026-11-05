#!/usr/bin/env luajit
-- 026-test-canvas-server.lua
--
-- Runs the real canvas server (025, through scripts/run-canvas-server) on
-- 127.0.0.1 only, beside a blitter on a throwaway project, and asks it with
-- curl and with raw sockets: each route; a waiting request answered by a new
-- version, two at once, one across a blitter restart; a wait timing out; a
-- waiter that hangs up; a bad route, a POST and a HEAD; a request too large,
-- too slow, and one connection too many. Then its log and goodbye receipt,
-- and a second run where this machine's requests are not logged.
--
-- For a general: this server is the one door anyone outside can knock on.
-- This proves it hands out the canvas and nothing else, the same bytes as
-- the files, and that it cannot be held open or filled up.
--
-- usage:
--   luajit 026-test-canvas-server.lua [--dir ROOT]

-- {{{ DIR -- the project root, hard-coded, overridable by --dir
local DIR = "/mnt/mtwo/programming/ai-stuff/guide-feature"
for index = 1, #arg do
    if arg[index] == "--dir" then DIR = arg[index + 1] end
end
-- }}}

local ffi = require("ffi")
pcall(ffi.cdef, "int setenv(const char *name, const char *value, int overwrite);")
local socket = require("socket")

local blitter = dofile(DIR .. "/src/016-blitter.lua")
local series = dofile(DIR .. "/src/018-phase-1-series.lua")
local canvas = dofile(DIR .. "/src/006-canvas-text.lua")
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

-- {{{ helpers, and the throwaway project (as in 017)
local function shell(command)
    local pipe = io.popen(command .. " 2>&1")
    local text = pipe:read("*a")
    pipe:close()
    return (string.gsub(text, "\n$", ""))
end
local function slurp(path)
    local handle = io.open(path, "r")
    if not handle then return nil end
    local text = handle:read("*a")
    handle:close()
    return text
end
local function write(path, text)
    local handle = assert(io.open(path, "w"))
    handle:write(text)
    handle:close()
end
local function wait_until(test, seconds)
    local deadline = socket.gettime() + seconds
    while socket.gettime() < deadline do
        if test() then return true end
        socket.sleep(0.05)
    end
    return test()
end

local BASE = shell("mktemp -d")
local ROOT = BASE .. "/project/guide-feature"
shell("mkdir -p '" .. ROOT .. "/input' '" .. ROOT .. "/output' '" .. BASE .. "/exec' '"
    .. BASE .. "/shm'")
for _, link in ipairs({ "src", "libs", "scripts" }) do
    shell("ln -s '" .. DIR .. "/" .. link .. "' '" .. ROOT .. "/" .. link .. "'")
end
ffi.C.setenv("EXEC_TIER_ROOT", BASE .. "/exec", 1)
ffi.C.setenv("ARTIFACT_TIER_ROOT", BASE .. "/shm", 1)
write(ROOT .. "/input/blitter", series.SETTINGS)
local function server_settings(locals)
    write(ROOT .. "/input/canvas-server", "listen-address = \"127.0.0.1\"\nport = 0\n"
        .. "max-connections = 4\nmax-request-bytes = 512\nrequest-seconds = 1\n"
        .. "wait-seconds = 2\ncheck-seconds = 0.05\nlocal-addresses = \"" .. locals .. "\"\n")
end
local ARRIVALS = ROOT .. "/tmp/shared-memory/arrivals"
local CANVAS = ROOT .. "/tmp/shared-memory/canvas"
local LOG = ROOT .. "/tmp/shared-memory/canvas-server.log"

local turn = 0
local function arrive(b, row_text)
    turn = turn + 1
    local made = canvas.blank(series.WIDTH, series.HEIGHT, "from-voice")
    made.headers = { voice = "fg-sora-1", turn = turn, base = b.version,
                     written = "2026-11-05T10:00:00Z" }
    local rows = b.current.rows
    for number = 1, series.HEIGHT do made.rows[number] = rows[number] end
    made.rows[1] = row_text .. string.sub(rows[1], #row_text + 1)
    write(ARRIVALS .. "/fg-sora-1-" .. (1000 + turn) .. "-a", canvas.write(made))
    b:step()
end
-- }}}

-- {{{ clients: curl, and a raw socket
local PORT
local function curl(target, background_to)
    local command = "curl -s -D '" .. BASE .. "/head' -o '" .. BASE .. "/body' "
        .. "-w '%{http_code} %{time_total}' 'http://127.0.0.1:" .. PORT .. target .. "'"
    if background_to then
        return shell("(curl -s -o '" .. background_to .. ".body' -w '%{http_code} %{time_total}' "
            .. "'http://127.0.0.1:" .. PORT .. target .. "' > '" .. background_to
            .. ".status' 2> /dev/null < /dev/null &)")
    end
    local status, seconds = string.match(shell(command), "^(%d+) ([%d%.]+)$")
    return tonumber(status), slurp(BASE .. "/body"), slurp(BASE .. "/head") or "", tonumber(seconds)
end
local function raw(text, linger)
    local sock = assert(socket.connect("127.0.0.1", PORT))
    sock:settimeout(5)
    local started = socket.gettime()
    if text then sock:send(text) end
    if linger then socket.sleep(linger) end
    local answer = sock:receive("*a") or ""
    sock:close()
    return tonumber(string.match(answer, "^HTTP/1%.1 (%d+)")), answer, socket.gettime() - started
end
-- }}}

-- {{{ the blitter makes versions 1 to 3, then the server starts
local b = blitter.new({ root = ROOT, commit = "abc1234", wait = function() end })
arrive(b, "one.")
arrive(b, "two.")
server_settings("192.168.1.100")
local pid = shell("cd '" .. ROOT .. "' && (scripts/run-canvas-server '" .. ROOT
    .. "' > '" .. BASE .. "/server.out' 2>&1 & echo $!)")
local started = wait_until(function()
    PORT = string.match(slurp(LOG) or "", "listening on 127%.0%.0%.1:(%d+)")
    return PORT ~= nil
end, 10)
-- }}}

io.write("\n=== starting ===\n")
-- {{{
check("it starts, on 127.0.0.1 and a free port, and says so in its log",
    started and tonumber(PORT) > 0, slurp(BASE .. "/server.out"))
check("its log says how it notices versions, and that the canvas is plain text for now",
    string.find(slurp(LOG), "(no inotify binding in this project)", 1, true) ~= nil
    and string.find(slurp(LOG), "the encrypted canvas comes with the HTML page (803)", 1, true) ~= nil)
-- }}}

io.write("\n=== the routes ===\n")
-- {{{
local status, body, head = curl("/canvas")
check("GET /canvas: 200, the newest version, byte for byte as canvas/current",
    status == 200 and body == slurp(CANVAS .. "/current") and string.find(body, "^canvas: 3\n"))
check("as text/plain in UTF-8, with its length, and the connection closed after",
    string.find(head, "Content-Type: text/plain; charset=utf-8", 1, true) ~= nil
    and string.find(head, "Content-Length: " .. #body, 1, true) ~= nil
    and string.find(head, "Connection: close", 1, true) ~= nil)
status, body = curl("/canvas/2")
check("GET /canvas/2: version 2 from history, byte for byte",
    status == 200 and body == slurp(CANVAS .. "/history/000002"))
check("GET /canvas/99: not in history, 404", curl("/canvas/99") == 404)
check("GET /canvas/02: a number with a leading zero is not a version, 404",
    curl("/canvas/02") == 404)
status, body = curl("/canvas?after=1")
check("GET /canvas?after=1: a newer version is there, so it answers at once",
    status == 200 and body == slurp(CANVAS .. "/current"))
status, body = curl("/")
check("GET /: 404 until the HTML page (803) exists, saying so",
    status == 404 and string.find(body, "803", 1, true) ~= nil)
check("GET /nothing: 404", curl("/nothing") == 404)
check("GET /canvas?after=x, ?after=, ?after=01, ?other=1 and /canvas/: each 404",
    curl("/canvas?after=x") == 404 and curl("/canvas?after=") == 404
    and curl("/canvas?after=01") == 404
    and curl("/canvas?other=1") == 404 and curl("/canvas/") == 404)
-- }}}

io.write("\n=== waiting for a new version ===\n")
-- {{{
local WAIT = BASE .. "/wait"
curl("/canvas?after=3", WAIT .. "1")
curl("/canvas?after=3", WAIT .. "2")
socket.sleep(0.5)
check("two waiting requests have no answer yet", slurp(WAIT .. "1.status") == "")
local made_at = socket.gettime()
arrive(b, "three.")
local both = wait_until(function()
    return (slurp(WAIT .. "1.status") or "") ~= "" and (slurp(WAIT .. "2.status") or "") ~= ""
end, 5)
local took = socket.gettime() - made_at
check("a new version answers both, with version 4, byte for byte",
    both and string.match(slurp(WAIT .. "1.status"), "^200") and string.match(slurp(WAIT .. "2.status"), "^200")
    and slurp(WAIT .. "1.body") == slurp(CANVAS .. "/history/000004")
    and slurp(WAIT .. "2.body") == slurp(CANVAS .. "/history/000004"))
check("within half a second of the version being written", took < 0.5, took)

local timed, timed_body, _, waited = curl("/canvas?after=4")
check("with no newer version, a wait ends after wait-seconds with 204 and no body",
    timed == 204 and timed_body == "" and waited >= 1.9 and waited < 3, waited)

curl("/canvas?after=4", WAIT .. "3")
socket.sleep(0.3)
b:finish()
local b2 = blitter.new({ root = ROOT, commit = "abc1234", wait = function() end })
check("a wait is answered across a blitter restart, by the new run's version 5",
    wait_until(function() return string.match(slurp(WAIT .. "3.status") or "", "^200") end, 3)
    and string.find(slurp(WAIT .. "3.body"), "^canvas: 5\n") ~= nil and b2.version == 5)

local leaving = assert(socket.connect("127.0.0.1", PORT))
leaving:send("GET /canvas?after=5 HTTP/1.1\r\nHost: x\r\n\r\n")
socket.sleep(0.3)
leaving:close()
socket.sleep(0.3)
-- }}}

io.write("\n=== what it refuses ===\n")
-- {{{
local code, answer = raw("POST /canvas HTTP/1.1\r\nHost: x\r\nContent-Length: 2\r\n\r\nhi")
check("POST /canvas: 405, naming GET as the one method", code == 405
    and string.find(answer, "Allow: GET", 1, true) ~= nil)
check("HEAD /canvas: 405", raw("HEAD /canvas HTTP/1.1\r\nHost: x\r\n\r\n") == 405)
check("a line that is not a request: 404", raw("hello there\r\n\r\n") == 404)
check("a request larger than max-request-bytes: 413",
    raw("GET /canvas HTTP/1.1\r\nX-Pad: " .. string.rep("a", 600) .. "\r\n\r\n") == 413)
check("a request far larger still gets its 413, not a reset connection",
    raw("GET /canvas HTTP/1.1\r\nX-Pad: " .. string.rep("a", 20000) .. "\r\n\r\n") == 413)
local slow, _, slow_seconds = raw("GET /canvas HTTP/1.1\r\n")
check("a request that does not finish within request-seconds: 408, after about a second",
    slow == 408 and slow_seconds >= 0.9 and slow_seconds < 2, slow_seconds)
local idle = {}
for index = 1, 4 do
    idle[index] = assert(socket.connect("127.0.0.1", PORT))
end
socket.sleep(0.2)
local busy, busy_answer = raw("GET /canvas HTTP/1.1\r\n\r\n")
check("with max-connections open, one more is answered 503 and closed",
    busy == 503 and string.find(busy_answer, "too many", 1, true) ~= nil, tostring(busy) .. " " .. busy_answer)
local idle_codes = {}
for index = 1, 4 do
    idle[index]:settimeout(3)
    idle_codes[index] = string.match(idle[index]:receive("*a") or "", "^HTTP/1%.1 (%d+)")
    idle[index]:close()
end
check("and the four that never sent a request are closed with 408",
    table.concat(idle_codes, " ") == "408 408 408 408", table.concat(idle_codes, " "))
check("after which it answers again", curl("/canvas") == 200)
-- }}}

io.write("\n=== its log and its goodbye ===\n")
-- {{{
local log = slurp(LOG)
check("one log line per request from outside the four machines: address, request, answer",
    string.find(log, " 127.0.0.1 GET /canvas HTTP/1.1 200\n", 1, true) ~= nil
    and string.find(log, " 127.0.0.1 GET /canvas?after=4 HTTP/1.1 204\n", 1, true) ~= nil
    and string.find(log, " 127.0.0.1 POST /canvas HTTP/1.1 405\n", 1, true) ~= nil
    and string.find(log, " 127.0.0.1 - 503\n", 1, true) ~= nil
    and string.find(log, " 127.0.0.1 GET /canvas?after=5 HTTP/1.1 closed\n", 1, true) ~= nil, log)
shell("kill -TERM " .. pid)
local receipt
check("a TERM through run-canvas-server stops it cleanly, with a goodbye", wait_until(function()
    receipt = goodbye.read(ROOT .. "/output/goodbye-canvas-server")
    return receipt ~= nil
end, 5))
local expected_counts = {
    ["requests-canvas"] = 2, ["requests-canvas-version"] = 2, ["requests-canvas-after"] = 6,
    ["requests-page"] = 1, ["waits-answered"] = 4, ["waits-timed-out"] = 1,
    ["waits-abandoned"] = 1, ["refused-not-found"] = 8, ["refused-method"] = 2,
    ["refused-too-large"] = 2, ["refused-too-slow"] = 5, ["refused-too-many"] = 1,
}
local wrong = {}
for name, value in pairs(expected_counts) do
    if receipt and receipt.counters[name] ~= value then
        wrong[#wrong + 1] = name .. "=" .. tostring(receipt.counters[name]) .. " not " .. value
    end
end
for name in pairs(receipt and receipt.counters or {}) do
    if expected_counts[name] == nil then wrong[#wrong + 1] = name .. " not expected" end
end
check("the receipt counts requests by route, waits, and refusals by reason",
    receipt ~= nil and #wrong == 0, table.concat(wrong, "; "))
-- }}}

io.write("\n=== this machine's own requests ===\n")
-- {{{
server_settings("127.0.0.1 192.168.1.100")
local before = #slurp(LOG)
pid = shell("cd '" .. ROOT .. "' && (scripts/run-canvas-server '" .. ROOT
    .. "' > '" .. BASE .. "/server.out' 2>&1 & echo $!)")
wait_until(function()
    PORT = string.match(string.sub(slurp(LOG) or "", before), "listening on 127%.0%.0%.1:(%d+)")
    return PORT ~= nil
end, 10)
status, body = curl("/canvas")
check("a server started alone serves the files the blitter left",
    status == 200 and string.find(body, "^canvas: 5\n") ~= nil)
shell("kill -TERM " .. pid)
wait_until(function()
    return string.find(string.sub(slurp(LOG), before), "ended; goodbye", 1, true) ~= nil
end, 5)
check("a request from one of the four machines is not logged",
    string.find(string.sub(slurp(LOG), before), "GET /canvas", 1, true) == nil)
b2:finish()
-- }}}

shell("rm -rf '" .. BASE .. "'")
io.write(string.format("\nTests: %d passed, %d failed\n", passed, failed))
os.exit(failed == 0 and 0 or 1)
