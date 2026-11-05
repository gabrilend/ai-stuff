#!/usr/bin/env luajit
-- 078-test-html-page.lua
--
-- Runs the real canvas server (025, through scripts/run-canvas-server) on
-- 127.0.0.1, with this machine counted as outside the house, and checks the
-- HTML page's way in (issue 803):
--   - GET / is one HTML page with the copied libraries inside it, sent with
--     a policy that lets it load nothing from anywhere else;
--   - outside the four machines the canvas is never sent plain;
--   - scripts/add-viewer makes a key viewer (an address to bookmark) and a
--     password viewer (the password read from standard input), in a file
--     outside the project that only its owner can read;
--   - a session: its key arrives locked with the viewer's key; each canvas
--     route sends the canvas locked with the session's key, which unlocks
--     to the server's own bytes in that session only; a session ends when
--     unused, or when too many are open; a wrong session is refused;
--   - malformed queries, a broken viewers file, the log and the receipt;
--   - the copied libraries are as their notes say, and refresh-vendored
--     leaves them be.
-- Then, where node is installed, 079-test-html-page.js runs the page's own
-- JavaScript against the same server: the parser against the shared test
-- canvases and against 022's answer for each of this file's own canvases,
-- the decryptor against the standard's examples, a whole session, and what
-- it paints.
--
-- For a general: this is the one door from outside, now with a lock on it.
-- This proves the lock holds where it should and opens where it should, and
-- that the page behind it reads the canvas exactly as every other viewer does.
--
-- usage:
--   luajit 078-test-html-page.lua [--dir ROOT]

-- {{{ DIR
local DIR = "/mnt/mtwo/programming/ai-stuff/guide-feature"
for index = 1, #arg do
    if arg[index] == "--dir" then DIR = arg[index + 1] end
end
-- }}}

local ffi = require("ffi")
pcall(ffi.cdef, "int setenv(const char *name, const char *value, int overwrite);")
local socket = require("socket")

local crypto = dofile(DIR .. "/src/074-crypto.lua")
local page = dofile(DIR .. "/src/076-html-page.lua")
local viewer = dofile(DIR .. "/src/022-viewer.lua")
local goodbye = dofile(DIR .. "/src/002-goodbye.lua")
local json = dofile(DIR .. "/libs/dkjson.lua")

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

-- {{{ helpers
local function shell(command)
    local pipe = io.popen(command .. " 2>&1")
    local text = pipe:read("*a")
    pipe:close()
    return (string.gsub(text, "\n$", ""))
end
local function q(text) return "'" .. string.gsub(text, "'", "'\\''") .. "'" end
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
local function has(text, part) return string.find(text or "", part, 1, true) ~= nil end
local function wait_until(test, seconds)
    local deadline = socket.gettime() + seconds
    while socket.gettime() < deadline do
        if test() then return true end
        socket.sleep(0.05)
    end
    return test()
end
local function fields(text)
    local out = {}
    for name, value in string.gmatch(text or "", "([%a-]+): ([^\n]*)\n") do out[name] = value end
    return out
end
-- }}}

-- {{{ a throwaway project, with this machine outside the four
local BASE = shell("mktemp -d")
local ROOT = BASE .. "/project/guide-feature"
shell("mkdir -p " .. q(ROOT .. "/input") .. " " .. q(ROOT .. "/output") .. " "
    .. q(BASE .. "/exec") .. " " .. q(BASE .. "/shm") .. " " .. q(BASE .. "/cases"))
for _, link in ipairs({ "src", "libs", "scripts" }) do
    shell("ln -s " .. q(DIR .. "/" .. link) .. " " .. q(ROOT .. "/" .. link))
end
ffi.C.setenv("EXEC_TIER_ROOT", BASE .. "/exec", 1)
ffi.C.setenv("ARTIFACT_TIER_ROOT", BASE .. "/shm", 1)
local VIEWERS = BASE .. "/keys/viewers"
local SETTINGS = "listen-address = \"127.0.0.1\"\nport = 0\nmax-connections = 16\n"
    .. "max-request-bytes = 2048\nrequest-seconds = 2\nwait-seconds = 1\ncheck-seconds = 0.05\n"
    .. "local-addresses = \"192.168.1.100\"\nsend-plain = \"local\"\n"
    .. "viewers-file = \"" .. VIEWERS .. "\"\nsession-seconds = 2\nmax-sessions = 3\n"
    .. "password-rounds = 2000\n"
write(ROOT .. "/input/canvas-server", SETTINGS)
local LOG = ROOT .. "/tmp/shared-memory/canvas-server.log"
local CANVAS = ROOT .. "/tmp/shared-memory/canvas"
local TESTS = DIR .. "/assets/test-canvases/"
-- }}}

-- {{{ the server, and curl
local PORT, pid
local function start_server()
    pid = shell("cd " .. q(ROOT) .. " && (scripts/run-canvas-server " .. q(ROOT) .. " > "
        .. q(BASE .. "/server.out") .. " 2>&1 & echo $!)")
    return wait_until(function()
        PORT = string.match(slurp(LOG) or "", "listening on 127%.0%.0%.1:(%d+)")
        return PORT ~= nil and has(slurp(LOG), "the page is ")
    end, 10)
end
local function curl(target)
    local status = shell("curl -s -D " .. q(BASE .. "/head") .. " -o " .. q(BASE .. "/body")
        .. " -w '%{http_code}' " .. q("http://127.0.0.1:" .. PORT .. target))
    return tonumber(status), slurp(BASE .. "/body"), slurp(BASE .. "/head") or ""
end
-- }}}

io.write("\n=== the page ===\n")
-- {{{
check("the server starts on 127.0.0.1", start_server(), slurp(BASE .. "/server.out"))
shell("mkdir -p " .. q(CANVAS .. "/history"))
for version, name in ipairs({ "01-empty", "02-kitten", "03-dog" }) do
    write(string.format("%s/history/%06d", CANVAS, version), slurp(TESTS .. name .. ".canvas"))
end
write(CANVAS .. "/current", slurp(TESTS .. "03-dog.canvas"))
check("its log says there are no viewers yet, and plain text goes to the four machines only",
    has(slurp(LOG), "viewers in " .. VIEWERS .. ": none yet (scripts/add-viewer)")
    and has(slurp(LOG), "plain text goes to the four machines only"), slurp(LOG))

local status, body, head = curl("/")
check("GET /: 200, text/html, the page as built from 077 and the copied libraries",
    status == 200 and has(head, "Content-Type: text/html; charset=utf-8")
    and body == page.build(ROOT), status)
check("it may load nothing from anywhere else (Content-Security-Policy), and sends no referrer",
    has(head, "Content-Security-Policy: default-src 'none'; script-src 'unsafe-inline'; "
        .. "style-src 'unsafe-inline'; connect-src 'self';")
    and has(head, "Referrer-Policy: no-referrer"), head)
local inside = 0
for _, entry in ipairs(page.NOBLE) do
    if has(body, "NOBLE[\"" .. entry[1] .. "\"] = function (exports, require) {") then inside = inside + 1 end
end
check("all ten library files are inside it, without their source-map lines",
    inside == 10 and not has(body, "sourceMappingURL"), inside)
-- }}}

io.write("\n=== outside the four machines, never plain ===\n")
-- {{{
local refused_plain = {}
for _, target in ipairs({ "/canvas", "/canvas?after=1", "/canvas/1" }) do
    local code, text = curl(target)
    refused_plain[#refused_plain + 1] = code .. (has(text, "only locked") and "" or "?")
end
check("GET /canvas, ?after=1, /canvas/1 with no session: 403 at once, saying open the page",
    table.concat(refused_plain, " ") == "403 403 403", table.concat(refused_plain, " "))
check("a viewer the server does not have: 404", curl("/session?viewer=phone") == 404)
-- }}}

io.write("\n=== setting viewers up ===\n")
-- {{{
local added = shell("printf '' | " .. q(ROOT .. "/scripts/add-viewer") .. " " .. q(ROOT) .. " phone --address 192.168.1.100")
local KEY = string.match(added, "http://192%.168%.1%.100:0/#phone:(%x+)\n?$")
check("add-viewer phone: a key, and the address to bookmark with it after #",
    KEY and #KEY == 64, added)
check("the viewers file is made outside the project, readable by its owner only",
    shell("stat -c %a " .. q(VIEWERS)) == "600"
    and slurp(VIEWERS) == "viewer: phone key " .. tostring(KEY) .. "\n", slurp(VIEWERS))
local PASSWORD = "correct horse battery"
added = shell("printf '%s\\n%s\\n' " .. q(PASSWORD) .. " " .. q(PASSWORD) .. " | "
    .. q(ROOT .. "/scripts/add-viewer") .. " " .. q(ROOT) .. " ritz --password")
local line = string.match(slurp(VIEWERS), "\n(viewer: ritz [^\n]*)\n$") or ""
local salt, rounds, made = string.match(line, "^viewer: ritz password (%x+) (%d+) (%x+)$")
check("add-viewer ritz --password: the password from standard input, then a salt, the rounds, "
    .. "and the key made from them", salt and #salt == 32 and rounds == "2000"
    and made == crypto.to_hex(crypto.pbkdf2_sha256(PASSWORD, crypto.from_hex(salt), 2000, 32))
    and has(added, "sign in as ritz"), line .. " / " .. added)
check("the password is nowhere in the file", not has(slurp(VIEWERS), "horse"))
local before = slurp(VIEWERS)
local mismatch = shell("(printf 'one\\ntwo\\n' | " .. q(ROOT .. "/scripts/add-viewer") .. " "
    .. q(ROOT) .. " other --password) 2>&1; echo \"status $?\"")
local again = shell("(" .. q(ROOT .. "/scripts/add-viewer") .. " " .. q(ROOT) .. " phone < /dev/null) 2>&1; echo \"status $?\"")
local badname = shell("(" .. q(ROOT .. "/scripts/add-viewer") .. " " .. q(ROOT) .. " 'a b' < /dev/null) 2>&1; echo \"status $?\"")
check("two passwords that differ, a name already there, a name with a space: refused, nothing added",
    has(mismatch, "not the same; nothing added") and has(mismatch, "status 1")
    and has(again, "already a viewer called phone") and has(again, "status 1")
    and has(badname, "letters, digits") and has(badname, "status 1") and slurp(VIEWERS) == before,
    mismatch .. " / " .. again .. " / " .. badname)
local in_project, why = page.viewers_path(ROOT .. "/viewers", ROOT)
check("a viewers file inside the project is refused (keys live outside it)",
    in_project == nil and has(why, "inside the project"), why)
local home = page.viewers_path("~/.config/guide-feature/viewers", ROOT)
check("~/ is the home folder", home == os.getenv("HOME") .. "/.config/guide-feature/viewers", home)
-- }}}

io.write("\n=== a session ===\n")
-- {{{
local viewer_key = crypto.from_hex(KEY or "")
local function begin(name)
    local code, text = curl("/session?viewer=" .. name)
    local f = fields(text)
    return code, f, f.key and crypto.from_hex(f.key)
end
local code, session, locked = begin("phone")
local SESSION = session.session or ""
local session_key = locked and crypto.open(viewer_key, locked, "guide-feature session " .. SESSION)
check("GET /session?viewer=phone: a session id, and its key locked with phone's key",
    code == 200 and #SESSION == 32 and session.kind == "key" and session.salt == "-"
    and session_key and #session_key == 32, code .. " " .. tostring(body))
check("the session key does not unlock bound to another session's id",
    locked and crypto.open(viewer_key, locked, "guide-feature session " .. string.rep("0", 32)) == nil)
local function opened(target, key, id)
    local got_code, got = curl(target)
    local sealed = got and crypto.from_hex(string.gsub(got, "\n$", ""))
    return got_code, sealed and crypto.open(key or session_key, sealed,
        "guide-feature canvas " .. (id or SESSION))
end
local c1, text1 = opened("/canvas?session=" .. SESSION)
check("GET /canvas?session=ID: the canvas locked, as hex; it unlocks to canvas/current, byte for byte",
    c1 == 200 and text1 == slurp(CANVAS .. "/current"), c1)
local c2, text2 = opened("/canvas/1?session=" .. SESSION)
check("GET /canvas/1?session=ID: version 1 from history", c2 == 200 and text2 == slurp(TESTS .. "01-empty.canvas"))
local c3, text3 = opened("/canvas?after=2&session=" .. SESSION)
local c4, text4 = opened("/canvas?session=" .. SESSION .. "&after=2")
check("GET /canvas?after=2&session=ID, in either order: the newer version at once",
    c3 == 200 and c4 == 200 and text3 == text1 and text4 == text1)
local started = socket.gettime()
local c5 = curl("/canvas?after=3&session=" .. SESSION)
check("nothing newer: 204 after wait-seconds", c5 == 204 and socket.gettime() - started >= 0.9)
local raw = select(2, curl("/canvas?session=" .. SESSION))
check("the same canvas twice is locked differently each time (a fresh nonce)",
    raw ~= select(2, curl("/canvas?session=" .. SESSION)))
local other_code, other_session, other_locked = begin("phone")
local other_key = other_locked and crypto.open(viewer_key, other_locked,
    "guide-feature session " .. other_session.session)
check("a second session has a key of its own; one session's canvas does not unlock in the other",
    other_code == 200 and other_key ~= session_key and select(2, opened("/canvas?session=" .. SESSION,
        other_key, other_session.session)) == nil)
check("a session the server never made: 403 at once, saying to start one",
    curl("/canvas?session=" .. string.rep("ab", 16)) == 403
    and has(select(2, curl("/canvas/1?session=" .. string.rep("ab", 16))), "start one at /session"))

local p_code, p_session, p_locked = begin("ritz")
local from_password = crypto.pbkdf2_sha256(PASSWORD, crypto.from_hex(p_session.salt or ""),
    tonumber(p_session.rounds) or 1, 32)
local wrong_password = crypto.pbkdf2_sha256(PASSWORD .. "!", crypto.from_hex(p_session.salt or ""),
    tonumber(p_session.rounds) or 1, 32)
check("a password viewer's session sends the salt and the rounds, never the key",
    p_code == 200 and p_session.kind == "password" and p_session.salt == salt
    and p_session.rounds == "2000" and not has(select(2, curl("/session?viewer=ritz")), made or "x"))
check("the key made from the password unlocks its session key; a wrong password's does not",
    p_locked and crypto.open(from_password, p_locked, "guide-feature session " .. p_session.session)
    and crypto.open(wrong_password, p_locked, "guide-feature session " .. p_session.session) == nil)

-- every session so far ends unused; then three, and a fourth
socket.sleep(2.3)
check("a session unused for session-seconds (2) has ended: 403",
    curl("/canvas?session=" .. SESSION) == 403)
local first, second, third = select(2, begin("phone")), select(2, begin("phone")), select(2, begin("ritz"))
socket.sleep(0.05)
curl("/canvas?session=" .. first.session)
curl("/canvas?session=" .. third.session)
local fourth = select(2, begin("phone"))
check("max-sessions 3: a fourth drops the one used longest ago, and only it",
    curl("/canvas?session=" .. second.session) == 403 and curl("/canvas?session=" .. first.session) == 200
    and curl("/canvas?session=" .. third.session) == 200 and curl("/canvas?session=" .. fourth.session) == 200)
-- }}}

io.write("\n=== what it refuses ===\n")
-- {{{
local refusals = {}
for _, target in ipairs({ "/session", "/session?viewer=", "/session?viewer=a&viewer=b",
        "/session?viewer=phone&after=1", "/session?viewer=a%20b", "/canvas?session=zz",
        "/canvas?other=1", "/canvas?after=1&after=2", "/canvas?session=ab&viewer=c",
        "/canvas/01?session=ab", "/?session=ab", "/canvas?after=01&session=ab" }) do
    refusals[#refusals + 1] = curl(target)
end
check("a malformed query or a parameter where it does not belong: 404, each of twelve",
    table.concat(refusals, " ") == string.rep("404 ", 11) .. "404", table.concat(refusals, " "))
local post = shell("curl -s -o /dev/null -w '%{http_code}' -X POST "
    .. q("http://127.0.0.1:" .. PORT .. "/session?viewer=phone"))
check("POST /session: 405", post == "405")
write(VIEWERS, before .. "viewer: broken\n")
local broken_code, broken = curl("/session?viewer=phone")
check("a viewers file with a wrong line: 500, and the log names the line",
    broken_code == 500 and has(broken, "see its log") and has(slurp(LOG), VIEWERS .. ":3: a viewer line is"),
    broken)
write(VIEWERS, before .. "viewer: phone key " .. string.rep("ab", 32) .. "\n")
local twice_code = curl("/session?viewer=phone")
write(VIEWERS, before .. "viewer: short key abcd\n")
local short_code = curl("/session?viewer=phone")
check("a viewer named twice, or a key shorter than 64 hex digits: 500 too",
    twice_code == 500 and short_code == 500 and has(slurp(LOG), VIEWERS .. ":3: the viewer phone is here twice"),
    twice_code .. " " .. short_code)
write(VIEWERS, before)
check("put right, it is read again at the next request; no restart needed",
    curl("/session?viewer=phone") == 200)
-- }}}

io.write("\n=== the page's own JavaScript, in node ===\n")
-- {{{
local NODE = shell("command -v node")
if NODE == "" then
    io.write("  SKIP  node is not on this machine, so the page's JavaScript was not run here;\n"
        .. "        its own checks (src/079-test-html-page.js) need node 18 or newer\n")
else
    -- 078's own canvases, each with what the Lua reader (022) says of it
    local HEAD = "canvas: 5\nsize: 8x2\nmode: newest\nproject: guide-feature 9f2c1e0\n"
        .. "written: 2026-11-05T10:00:00Z\nvoices: fg-sora-1 fg-sora-2\n\n"
    local function make(rows, marks) return HEAD .. rows .. "marks:\n" .. (marks or "") end
    local OK_ROWS = "go now.\nok\n"
    local cases = {
        make(OK_ROWS, "mark: 1 1 2 fg-sora-1 5 word\nmark: 1 4 4 fg-sora-2 3 sentence\n"),
        string.gsub(make(OK_ROWS, "mark: 1 1 2 fg-sora-1 5 word\n"), "\n$", ""),
        make("\n\n"),
        make(OK_ROWS, "mark: 1 1 7 fg-sora-1 4 sentence\nmark: 1 2 2 fg-sora-2 5 word\n"),
        make(OK_ROWS, "mark: 2 1 1 kuvalu 5 word\nmark: 2 2 1 zz 0 orphan\n"),
        make("été ö€\n𝄞x\n", "mark: 1 1 3 fg-sora-2 5 word\n"),
        string.gsub(make(OK_ROWS), "^canvas: 5\nsize: 8x2", "size: 8x2\ncanvas: 5"),
        string.gsub(make(OK_ROWS), "\n\n", "\ncolour: red\n\n"),
        string.gsub(make(OK_ROWS), "mode: newest\n", "mode: newest\nmode: newest\n"),
        string.gsub(make(OK_ROWS), "8x2", "0x2"),
        string.gsub(make(OK_ROWS), "8x2", "08x2"),
        string.gsub(make(OK_ROWS), "fg%-sora%-1 fg%-sora%-2", "fg-sora-1  fg-sora-2"),
        string.gsub(make(OK_ROWS), "fg%-sora%-1 fg%-sora%-2", "a a"),
        "\239\187\191" .. make(OK_ROWS),
        string.gsub(make(OK_ROWS), "\n", "\r\n"),
        string.gsub(make(OK_ROWS), "\n\n", "\n"),
        HEAD .. "one row\n",
        make("go now. ok\nok\n"),
        make("go now.x\nok\n"),
        make("go now.xy\nok\n"),
        make("go\tnow.\nok\n"),
        make("go \255\nok\n"),
        make("go \192\175\nok\n"),
        make("go \237\160\128\nok\n"),
        HEAD .. "go\nok\nthird\nmarks:\n",
        make(OK_ROWS, "mark: 0 1 2 fg-sora-1 5 word\n"),
        make(OK_ROWS, "mark: 1 5 5 fg-sora-1 5 word\n"),
        make(OK_ROWS, "mark: 1 1 2 fg-sora-1 5 x\n"),
        make(OK_ROWS, "mark: 1 1 2 a/b 5 word\n"),
        make(OK_ROWS, "mark: 1 1 2 fg-sora-1 05 word\n"),
        make(OK_ROWS, "mark: 1 1 2 fg-sora-1 9 word\nmark: 1 1 2 fg-sora-1\n"),
        make(OK_ROWS, "mark: 1 1 2 fg-sora-1 5 word\nmark: 2 1 2 fg-sora-2 6 word\n"),
        make(OK_ROWS, "cuts:\n"),
        make(OK_ROWS, "endpoints:\n"),
        make(OK_ROWS, "mark: 1 1 2 fg-sora-1 5 word extra\n"),
        "",
        "canvas: 5\n",
        string.gsub(make(OK_ROWS), "newest", "fast"),
        string.gsub(make(OK_ROWS), "2026%-11%-05T10:00:00Z", "yesterday"),
        string.gsub(make(OK_ROWS), "guide%-feature 9f2c1e0", "guide-feature"),
        HEAD .. "go\nmarks:\nmark: 1 1 2 fg-sora-1 5 word\n",
        make(OK_ROWS, "mark: 1 1 2 fg-sora-1 5 word\n\n"),
        string.gsub(make(OK_ROWS), "canvas: 5\n", "canvas: 5\r\n"),
        make(OK_ROWS, "mark: 1 1 1 fg-sora-1 0 word\n"),
        make("go\127\nok\n"),
        make(OK_ROWS, "mark: 2 2 2 fg-sora-2 5 sentence"),
    }
    local function code_point(character)
        local b = { string.byte(character, 1, -1) }
        if b[1] < 0x80 then return b[1] end
        if b[1] < 0xE0 then return (b[1] - 0xC0) * 64 + (b[2] - 0x80) end
        if b[1] < 0xF0 then return ((b[1] - 0xE0) * 64 + (b[2] - 0x80)) * 64 + (b[3] - 0x80) end
        return (((b[1] - 0xF0) * 64 + (b[2] - 0x80)) * 64 + (b[3] - 0x80)) * 64 + (b[4] - 0x80)
    end
    local refused_count = 0
    for index, text in ipairs(cases) do
        local name = string.format("%s/case-%02d", BASE .. "/cases", index)
        write(name .. ".canvas", text)
        local ok, view = pcall(viewer.read, text)
        local out = {}
        if not ok then
            out[1] = "refused " .. (string.match(view, "^canvas:(%d+):") or "?")
            refused_count = refused_count + 1
        else
            out = { "version " .. view.version, "size " .. view.width .. "x" .. view.height,
                    "voices " .. table.concat(view.voices, " ") }
            for row = 1, view.height do
                for column = 1, view.width do
                    local cell = view.cells[row][column]
                    local cell_line = string.format("cell %d %d %d", row, column, code_point(cell.character))
                    if cell.mark then
                        cell_line = cell_line .. string.format(" %s %d %s %d", cell.mark.voice,
                            cell.mark.version, cell.mark.kind, cell.mark.age)
                    end
                    out[#out + 1] = cell_line
                end
            end
        end
        write(name .. ".lua-says", table.concat(out, "\n") .. "\n")
    end
    check("078's " .. #cases .. " canvases: the Lua reader takes " .. (#cases - refused_count)
        .. " and refuses " .. refused_count .. ", each by its line", refused_count >= 30
        and refused_count < #cases, refused_count)

    -- where 022 lays a 16x3 canvas out, for the page to agree with
    local layouts = {}
    for _, case in ipairs({ { 800, 600, 0.6, 1.2, 32, 6 }, { 300, 100, 0.6, 1.2, 32, 6 },
                            { 50, 20, 0.6, 1.2, 32, 6 }, { 1001, 77, 0.55, 1.25, 20, 0.5 } }) do
        local letter = { across = case[3], down = case[4], max = case[5], min = case[6] }
        local box, problem = viewer.layout({ width = 16, height = 3 }, case[1], case[2], letter)
        layouts[#layouts + 1] = { case[1], case[2], letter, box or { problem = problem } }
    end
    local config = { port = tonumber(PORT), canvas = CANVAS, assets = DIR .. "/assets/test-canvases",
        cases = BASE .. "/cases", keyViewer = "phone", key = KEY, passwordViewer = "ritz",
        password = PASSWORD, waitSeconds = 1, layouts = layouts }
    write(BASE .. "/node-config.json", json.encode(config))
    local out = shell("cd " .. q(BASE) .. " && timeout 120 node " .. q(DIR .. "/src/079-test-html-page.js")
        .. " " .. q(BASE .. "/node-config.json"))
    io.write(string.gsub(out, "\nnode: %d+ passed, %d+ failed$", ""), "\n")
    local node_passed, node_failed = string.match(out, "\nnode: (%d+) passed, (%d+) failed$")
    check("the page's own checks ran to the end in node", node_passed ~= nil, out)
    passed = passed + (tonumber(node_passed) or 0)
    failed = failed + (tonumber(node_failed) or 0)
end
-- }}}

io.write("\n=== the copies, the log, the goodbye ===\n")
-- {{{
local unchanged, listed = true, 0
for _, package in ipairs({ "noble-ciphers", "noble-hashes" }) do
    local note = slurp(DIR .. "/libs/" .. package .. ".upstream") or ""
    check(package .. ": its note gives the registry tarball, the exact version and its integrity",
        string.match(note, "^source: https://registry%.npmjs%.org/@noble/[%a]+/%-/[%a]+%-%d+%.%d+%.%d+%.tgz\n")
        and string.match(note, "\nversion: %d+%.%d+%.%d+\n")
        and string.match(note, "\nintegrity: sha512%-[%w%+/]+=*\n"), note)
    for sum, file in string.gmatch(note, "\n  (%x+)  ([%w%._]+)") do
        listed = listed + 1
        local actual = string.match(shell("sha256sum " .. q(DIR .. "/libs/" .. package .. "/" .. file)), "^%x+")
        if actual ~= sum then unchanged = false end
    end
end
check("every copied file is as its note's hash says (12 files, copied unchanged)",
    unchanged and listed == 12, listed)
local refresh = shell(q(DIR .. "/scripts/refresh-vendored") .. " --dir " .. q(DIR)
    .. " --check noble-ciphers noble-hashes; echo \"status $?\"")
check("refresh-vendored names them as copied from a registry and leaves them be",
    has(refresh, "noble-ciphers: copied from a package registry (1.3.0); refreshed by hand")
    and has(refresh, "noble-hashes: copied from a package registry (1.8.0)") and has(refresh, "status 0"),
    refresh)

local log = slurp(LOG)
check("its log has one line per request from outside, sessions included",
    has(log, " 127.0.0.1 GET /session?viewer=phone HTTP/1.1 200\n")
    and has(log, " 127.0.0.1 GET /canvas HTTP/1.1 403\n"), log)
check("and never a key: not the viewer's, not a session's", not has(log, KEY or "x")
    and not has(log, crypto.to_hex(session_key or "x")))
shell("kill -TERM " .. pid)
local receipt
check("a TERM stops it cleanly, with a goodbye", wait_until(function()
    receipt = goodbye.read(ROOT .. "/output/goodbye-canvas-server")
    return receipt ~= nil
end, 5))
local counts = receipt and receipt.counters or {}
check("the goodbye counts sessions and what it refused",
    (counts["sessions-started"] or 0) >= 6 and (counts["refused-plain"] or 0) == 3
    and (counts["refused-no-viewer"] or 0) >= 1 and (counts["refused-no-session"] or 0) >= 4,
    json.encode(counts))
-- }}}

if failed == 0 then shell("rm -rf " .. q(BASE)) else io.write("kept ", BASE, "\n") end
io.write(string.format("\nTests: %d passed, %d failed\n", passed, failed))
os.exit(failed == 0 and 0 or 1)
