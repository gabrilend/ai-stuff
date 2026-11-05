#!/usr/bin/env luajit
-- 080-test-phase-8-demo.lua
--
-- Runs the phase 8 demo as the owner would, but quicker (a version each
-- half second). Once kept, to check what it showed against the programs'
-- own record (read here, not taken from the demo's word):
--   - each viewer's log: versions 1 to 8 drawn, each once, in order;
--   - the delays, worked out again from those logs and the canvas files'
--     own times, agree with the table, and each is under a second;
--   - the receipts of the terminal view, the Lua window and the server;
--   - the page went the way a browser away from home goes: a session, and
--     every canvas asked for with it;
--   - each screenshot filed shows version 8's characters, as the
--     viewer-side reader (022) reads the canvas file;
--   - the side by side, and the note filed with the pictures.
-- Then: without node (the page left out, said so, the demo still passes);
-- attached to a pretend live canvas folder, which is left as it was;
-- refused arguments; through run-phase-demo, filed in development-history
-- and nothing left behind; and the recording made again by its recorder.
--
-- For a general: the demo is what the owner watches to see phase 8 work:
-- three different viewers keeping up with one canvas, and agreeing on it.
-- This proves the demo shows what the viewers did.
--
-- usage:
--   luajit 080-test-phase-8-demo.lua [--dir ROOT]

-- {{{ DIR -- the project root, hard-coded, overridable by --dir
local DIR = "/mnt/mtwo/programming/ai-stuff/guide-feature"
for index = 1, #arg do
    if arg[index] == "--dir" then DIR = arg[index + 1] end
end
-- }}}

local goodbye = dofile(DIR .. "/src/002-goodbye.lua")
local viewer = dofile(DIR .. "/src/022-viewer.lua")

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
local function has(text, piece) return text ~= nil and string.find(text, piece, 1, true) ~= nil end
local function q(text) return "'" .. string.gsub(text, "'", "'\\''") .. "'" end
local function utf8_chars(text)
    local out = {}
    for character in string.gmatch(text, "[%z\1-\127\194-\244][\128-\191]*") do out[#out + 1] = character end
    return out
end
local function lines(text)
    local out = {}
    for line in string.gmatch((text or "") .. "\n", "([^\n]*)\n") do out[#out + 1] = line end
    return out
end
-- "drew version N at T" lines: the versions in the order drawn, and when each first was
local function draws(text)
    local order, at = {}, {}
    for version, when in string.gmatch(text or "", "drew version (%d+) at ([%d%.]+)") do
        version = tonumber(version)
        order[#order + 1] = version
        at[version] = at[version] or tonumber(when)
    end
    return order, at
end
local function median(list)
    table.sort(list)
    return list[math.floor((#list + 1) / 2)]
end
-- the processes whose command line names this place
local function running(where)
    local n = 0
    for _ = 1, 30 do
        n = 0
        for pid in string.gmatch(select(1, shell("ls /proc")) or "", "%d+") do
            if has(slurp("/proc/" .. pid .. "/cmdline") or "", where) then n = n + 1 end
        end
        if n == 0 then return 0 end
        shell("sleep 0.1")
    end
    return n
end
-- }}}

-- {{{ a copy of the project to run the demo against
local BASE = shell("mktemp -d")
local PROJECT = BASE .. "/guide-feature"
local TMP = BASE .. "/tmp"       -- where the demo makes its throwaway copies
shell("mkdir -p " .. q(PROJECT .. "/input") .. " " .. q(TMP))
for _, link in ipairs({ "src", "libs", "scripts", "issues", "assets", "run-phase-demo" }) do
    shell("ln -s " .. q(DIR .. "/" .. link) .. " " .. q(PROJECT .. "/" .. link))
end
for _, name in ipairs({ "terminal-view", "lua-window" }) do
    write(PROJECT .. "/input/" .. name, slurp(DIR .. "/input/" .. name))
end
local ENV = "TMPDIR=" .. q(TMP) .. " "
local DEMO = PROJECT .. "/issues/completed/demos/phase-8-demo"
local HISTORY = DIR .. "/assets/phase-8-history"
local NODE = select(1, shell("command -v node")) ~= ""
-- version 8's rows, as the viewer-side reader reads the recorded file
local final = viewer.read(slurp(HISTORY .. "/000008"))
local TRUTH = {}
for row = 1, final.height do
    local text = {}
    for column = 1, final.width do text[column] = final.cells[row][column].character end
    TRUTH[row] = (string.gsub(table.concat(text), " +$", ""))
end
-- the rows inside a screenshot's border, from its first border line
local function inside(text)
    local all = lines(text)
    for index, line in ipairs(all) do
        if string.match(line, "^[+┌]") then
            local rows = {}
            for row = index + 1, index + final.height do
                local characters = utf8_chars(all[row] or "")
                table.remove(characters, 1)
                table.remove(characters)
                rows[#rows + 1] = (string.gsub(table.concat(characters), " +$", ""))
            end
            return rows
        end
    end
    return {}
end
local function same_rows(rows)
    for row = 1, final.height do
        if rows[row] ~= TRUTH[row] then return false end
    end
    return true
end
-- }}}

io.write("\n=== the demo, kept ===\n")
-- {{{
local OUT = BASE .. "/out"
local out, status = shell(ENV .. q(DEMO) .. " " .. q(PROJECT) .. " --every 0.5 --out " .. q(OUT) .. " --keep")
check("it runs to the end and exits 0", status == 0, string.sub(out or "", -2500))
local ROOT = string.match(out or "", "kept the throwaway project at (%S+)")
check("with --keep it says where its throwaway copy is", ROOT ~= nil and slurp(ROOT .. "/input/canvas-server") ~= nil)
ROOT = ROOT or "/nowhere"
local KEPT = string.match(ROOT, "^(.*)/guide%-feature$") or "/nowhere"
local SHM = ROOT .. "/tmp/shared-memory"
local CANVAS = SHM .. "/canvas"

-- what each viewer's own log says it drew
local LOGS = { terminal = SHM .. "/terminal-view.log", window = SHM .. "/lua-window.log",
               page = KEPT .. "/page.log" }
local NAMES = { terminal = "terminal view", window = "Lua window", page = "HTML page" }
local WHICH = { "terminal", "window" }
if NODE then WHICH[3] = "page" end
for _, which in ipairs(WHICH) do
    local order = draws(slurp(LOGS[which]))
    check("the " .. NAMES[which] .. " drew versions 1 to 8, each once, in order",
        table.concat(order, " ") == "1 2 3 4 5 6 7 8", table.concat(order, " "))
end

-- the delays again: from each canvas file's own time to the viewer's first frame of it
local function written(version)
    return tonumber((shell(string.format("date -r %s +%%s.%%N", q(string.format("%s/history/%06d",
        CANVAS, version))))))
end
for _, which in ipairs(WHICH) do
    local _, at = draws(slurp(LOGS[which]))
    local delays, longest = {}, 0
    for version = 2, 8 do
        local delay = at[version] and written(version) and (at[version] - written(version)) * 1000
        delays[#delays + 1] = delay or 1e9
        longest = math.max(longest, delay or 1e9)
    end
    local middle = median(delays)
    local shown_middle, shown_longest = string.match(out or "",
        NAMES[which] .. " +8 of 8 +median (%d+) ms, longest (%d+) ms")
    check("the " .. NAMES[which] .. "'s delays in the table are the logs' and the files' own",
        shown_middle and math.abs(tonumber(shown_middle) - middle) <= 25
        and math.abs(tonumber(shown_longest) - longest) <= 25,
        string.format("table %s %s, worked out %.0f %.0f", tostring(shown_middle),
            tostring(shown_longest), middle, longest))
    check("the " .. NAMES[which] .. " drew each version under a second after it was written",
        longest > 0 and longest < 1000, longest)
end
if not NODE then
    check("(no node here: the page is left out, and the demo says so)",
        has(out, "not run: node is not installed"))
end

-- the receipts
local terminal = goodbye.read(ROOT .. "/output/goodbye-terminal-view")
local window = goodbye.read(ROOT .. "/output/goodbye-lua-window")
local server = goodbye.read(ROOT .. "/output/goodbye-canvas-server")
check("the terminal view's receipt: 8 versions read, 8 drawn",
    terminal and terminal.counters["versions-read"] == 8 and terminal.counters["versions-drawn"] == 8)
check("the Lua window's receipt: 8 received, 8 drawn, none cut short, one screenshot",
    window and window.counters["versions-received"] == 8 and window.counters["versions-drawn"] == 8
    and window.counters["cut-short"] == 0 and window.counters.screenshots == 1)
check("each stopped cleanly, the server too",
    terminal and window and server and has(slurp(SHM .. "/canvas-server.log"), "stop file found"))

-- the page, as a browser away from home
local settings = slurp(ROOT .. "/input/canvas-server") or ""
local log = slurp(SHM .. "/canvas-server.log") or ""
check("the demo's server counts 127.0.0.1 as outside the house",
    has(settings, 'listen-address = "127.0.0.1"') and not string.find(
        string.match(settings, 'local%-addresses = "([^"]*)"') or "127.0.0.1", "127.0.0.1", 1, true))
if NODE then
    local plain_asks, sealed_asks = 0, 0
    for path in string.gmatch(log, "127%.0%.0%.1 GET (/canvas%S*) HTTP") do
        if string.find(path, "session=%x+") then sealed_asks = sealed_asks + 1 else plain_asks = plain_asks + 1 end
    end
    check("the page signed in as its viewer and asked for every canvas with its session",
        has(log, "GET /session?viewer=demo HTTP/1.1 200") and sealed_asks >= 9 and plain_asks == 0,
        sealed_asks .. " with a session, " .. plain_asks .. " without")
    check("the server's receipt: sessions started, the long polls answered",
        server and server.counters["sessions-started"] >= 2 and server.counters["waits-answered"] >= 7)
    check("the demo's key was kept outside its project, readable by its owner only",
        has(log, "viewers in " .. KEPT .. "/keys/viewers")
        and select(1, shell("stat -c %a " .. q(KEPT .. "/keys/viewers"))) == "600")
end

-- the screenshots, each against the canvas file as 022 reads it
local SHOWN = tonumber(string.match(out or "", "The screenshots at version (%d+), side by side"))
check("the screenshots are all at version 8, the last", SHOWN == 8, SHOWN)
check("the terminal view's: version 8's characters, row for row",
    same_rows(inside(slurp(OUT .. "/terminal-view.txt"))), slurp(OUT .. "/terminal-view.txt"))
local ansi = slurp(OUT .. "/terminal-view.ansi") or ""
check("its .ansi is the screen as the terminal got it: colour codes and all, the same text under them",
    select(2, string.gsub(ansi, "\27%[[%d;]*m", "")) > 2 and string.gsub(string.gsub(ansi,
        "\27%[[%d;?]*%a", ""), "\r", "") == slurp(OUT .. "/terminal-view.txt"))
local png = slurp(OUT .. "/lua-window.png") or ""
check("the Lua window's: a PNG, and its text grid version 8's characters",
    string.sub(png, 1, 8) == "\137PNG\r\n\26\n" and same_rows(inside(slurp(OUT .. "/lua-window.txt")))
    and has(slurp(OUT .. "/lua-window.txt"), "version 8"))
if NODE then
    local page_rows = {}
    for index, line in ipairs(lines(slurp(OUT .. "/html-page.txt"))) do
        page_rows[index] = (string.gsub(line, " +$", ""))
    end
    check("the page's, drawn by its own script: version 8's characters, row for row",
        same_rows(page_rows), slurp(OUT .. "/html-page.txt"))
    local html = slurp(OUT .. "/html-page.html") or ""
    local _, spans = string.gsub(html, "<span", "")
    local _, coloured = string.gsub(html, "<span style=\"background%-color: ", "")
    check("and as the page paints it: a span a cell, the marked cells coloured",
        spans == final.width * final.height and coloured > 0 and has(html, "version 8"), spans .. " " .. coloured)
end
local has_firefox = select(1, shell("command -v firefox")) ~= ""
check("without Firefox it says the page's picture is its own drawing; with it, Firefox's",
    has_firefox and slurp(OUT .. "/html-page.png") ~= nil or (not has_firefox and has(out, "Firefox is not installed")))

-- the side by side
check("side by side, the three at version 8, and it says they agree",
    has(out, "terminal view") and has(out, "Lua window") and has(out, "HTML page")
    and has(out, "|" .. TRUTH[1] .. string.rep(" ", final.width - #utf8_chars(TRUTH[1])) .. "|")
    and has(out, NODE and "All three show the canvas's own characters" or "Both viewers that ran show"))
local side = slurp(OUT .. "/side-by-side.html") or ""
check("side-by-side.html shows the three together",
    has(side, "lua-window.png") and has(side, NODE and "html-page." or "not run") and has(side, "the end."))
local note = slurp(OUT .. ".info.md") or ""
check("a note beside the folder says what made it and from what",
    has(note, "phase-8-demo") and has(note, "version 8") and has(note, "replayed from " .. PROJECT .. "/assets/phase-8-history"), note)
shell("rm -rf " .. q(KEPT))
-- }}}

io.write("\n=== without node ===\n")
-- {{{
local path = {}
for folder in string.gmatch(os.getenv("PATH") or "", "[^:]+") do
    if not io.open(folder .. "/node") then path[#path + 1] = folder end
end
local OUT2 = BASE .. "/out-no-node"
out, status = shell("PATH=" .. q(table.concat(path, ":")) .. " " .. ENV .. q(DEMO) .. " " .. q(PROJECT)
    .. " --every 0.5 --out " .. q(OUT2))
check("the page is left out and the demo says so", has(out, "not run: node is not installed"), out)
check("the other two still agree with the canvas, so it still exits 0",
    status == 0 and has(out, "Both viewers that ran show the canvas's own characters"), string.sub(out or "", -1500))
check("no page files are made", slurp(OUT2 .. "/html-page.html") == nil and slurp(OUT2 .. "/lua-window.png") ~= nil)
-- }}}

io.write("\n=== attached to a live canvas ===\n")
-- {{{
local LIVE = BASE .. "/live"
shell("mkdir -p " .. q(LIVE .. "/history"))
for version = 1, 5 do
    shell(string.format("cp %s/%06d %s/history/", q(HISTORY), version, q(LIVE)))
end
shell(string.format("cp %s/000005 %s/current", q(HISTORY), q(LIVE)))
-- the live system writes version 6 while the demo watches
shell("(sleep 3.5; cp " .. q(HISTORY .. "/000006") .. " " .. q(LIVE .. "/history/") .. "; cp "
    .. q(HISTORY .. "/000006") .. " " .. q(LIVE .. "/.current") .. "; mv " .. q(LIVE .. "/.current")
    .. " " .. q(LIVE .. "/current") .. ") > /dev/null 2>&1 &")
local before = select(1, shell("cd " .. q(LIVE) .. " && find . -type f | sort | xargs sha256sum"))
local OUT3 = BASE .. "/out-live"
out, status = shell(ENV .. q(DEMO) .. " " .. q(PROJECT) .. " --attach " .. q(LIVE) .. " --seconds 7 --out " .. q(OUT3))
check("it runs and exits 0", status == 0, string.sub(out or "", -1500))
check("it says it watches the live folder and writes nothing to it",
    has(out, "Watching the live canvas in " .. LIVE) and has(out, "nothing is written to it"))
check("each viewer drew the version it found and the one written while it watched",
    select(2, string.gsub(out or "", " 2 of 2 +median %d+ ms", "")) == #WHICH, out)
check("the screenshots are at version 6", has(out, "The screenshots at version 6"))
local after = select(1, shell("cd " .. q(LIVE) .. " && find . -type f | sort | xargs sha256sum"))
check("the live folder holds only what the live system wrote: version 6 added, nothing else",
    has(after, "./history/000006") and #lines(after) == #lines(before) + 1
    and not has(after, "./history/000007"), after)
check("and it is still there after the demo's copy is removed", slurp(LIVE .. "/current") == slurp(HISTORY .. "/000006"))
-- }}}

io.write("\n=== what it refuses ===\n")
-- {{{
out, status = shell(ENV .. q(DEMO) .. " " .. q(PROJECT) .. " --every soon")
check("--every that is not a number of seconds", status ~= 0 and has(out, "--every takes a number of seconds"), out)
out, status = shell(ENV .. q(DEMO) .. " " .. q(PROJECT) .. " --from " .. q(BASE .. "/nowhere"))
check("--from a folder that is not there", status ~= 0 and has(out, "no folder at"), out)
shell("mkdir -p " .. q(BASE .. "/one") .. " && cp " .. q(HISTORY .. "/000001") .. " " .. q(BASE .. "/one/"))
out, status = shell(ENV .. q(DEMO) .. " " .. q(PROJECT) .. " --from " .. q(BASE .. "/one"))
check("a folder with fewer than two canvases", status ~= 0 and has(out, "fewer than two canvases"), out)
out, status = shell(ENV .. q(DEMO) .. " " .. q(BASE))
check("a folder that is not the project", status ~= 0 and has(out, "is not the guide-feature project"), out)
shell("mkdir -p " .. q(BASE .. "/older/src") .. " && cp " .. q(DIR .. "/src/070-terminal-view.lua") .. " "
    .. q(BASE .. "/older/src/"))
out, status = shell(ENV .. q(DEMO) .. " " .. q(BASE .. "/older"))
check("a project from before the HTML page (803)", status ~= 0 and has(out, "is not the guide-feature project"), out)
-- }}}

io.write("\n=== through run-phase-demo ===\n")
-- {{{
local listing = select(1, shell(ENV .. q(PROJECT .. "/run-phase-demo") .. " " .. q(PROJECT) .. " 99 < /dev/null"))
check("run-phase-demo offers phase 8", listing ~= nil and listing:match("Phases with one:[%d ]* 8") ~= nil, listing)
out, status = shell(ENV .. q(PROJECT .. "/run-phase-demo") .. " " .. q(PROJECT) .. " 8")
check("and runs it to the end", status == 0, string.sub(out or "", -1500))
local filed = PROJECT .. "/development-history/001-phase-8-demo"
check("by default it files in the project's development-history, numbered, with its note",
    slurp(filed .. "/lua-window.png") ~= nil and slurp(filed .. "/side-by-side.html") ~= nil
    and slurp(filed .. ".info.md") ~= nil and has(out, "Filed in " .. filed))
check("its throwaway copies are all removed", select(1, shell("ls -A " .. q(TMP))) == "",
    select(1, shell("ls -A " .. q(TMP))))
check("and nothing it started is still running", running(TMP) == 0)
-- }}}

io.write("\n=== the recording ===\n")
-- {{{
local AGAIN = BASE .. "/again"
out, status = shell(ENV .. "luajit " .. q(DIR .. "/issues/completed/demos/phase-8-record.lua") .. " "
    .. q(DIR) .. " " .. q(AGAIN))
local alike = status == 0
for version = 1, 8 do
    local name = string.format("/%06d", version)
    local one = string.gsub(slurp(HISTORY .. name) or "x", "\nwritten: [^\n]*", "")
    local two = string.gsub(slurp(AGAIN .. name) or "y", "\nwritten: [^\n]*", "")
    alike = alike and one == two
end
check("the recorder makes assets/phase-8-history again, but for the written: lines", alike, out)
check("eight canvases, each read by the viewer-side reader as its own version", (function()
    for version = 1, 8 do
        local view = viewer.read(slurp(string.format("%s/%06d", HISTORY, version)))
        if not view or view.version ~= version then return false end
    end
    return true
end)())
-- }}}

shell("rm -rf " .. q(BASE))
io.write(string.format("\nTests: %d passed, %d failed\n", passed, failed))
os.exit(failed == 0 and 0 or 1)
