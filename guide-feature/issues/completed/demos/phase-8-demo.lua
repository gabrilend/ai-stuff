-- phase-8-demo.lua - three viewers, one canvas: the driver behind phase-8-demo.
--
-- In plain terms: the three viewers phase 8 built (the terminal view, the
-- Lua window, the HTML page) watch the same canvas at once. Versions are
-- written one after another, as the blitter writes them. Each viewer notes
-- the moment it drew each one. At the end the same version is
-- screenshotted in all three. Shown:
--   - the versions each viewer drew;
--   - how long after a version was written each viewer drew it;
--   - the three screenshots side by side, as text here and as a page filed
--     with the pictures.
--
-- The canvas: a recorded history replayed (assets/phase-8-history/, made by
-- the real blitter from the phase 1 series, or --from FOLDER), or, with
-- --attach FOLDER, a live canvas folder (the live system's
-- tmp/shared-memory/canvas), watched for --seconds without writing to it.
--
-- The HTML page: its own script, as the canvas server sends it, runs in node
-- for the numbers (phase-8-page.js), signed in with a key made for the demo.
-- Its screenshot is Firefox's, headless, where Firefox is installed. Without
-- Firefox, it is the page's own drawing written as HTML. Without node, the
-- page is left out and the demo says so.
--
-- Run by phase-8-demo, which makes the throwaway copy (ROOT, in BASE).
--   luajit phase-8-demo.lua --dir DIR --root ROOT --base BASE [--from FOLDER]
--       [--attach FOLDER] [--every SECONDS] [--seconds SECONDS] [--out FOLDER]

-- {{{ arguments
local DIR, ROOT, BASE, FROM, ATTACH, OUT
local EVERY, SECONDS = 1.0, 30
for index = 1, #arg do
    local value = arg[index + 1]
    if arg[index] == "--dir" then DIR = value
    elseif arg[index] == "--root" then ROOT = value
    elseif arg[index] == "--base" then BASE = value
    elseif arg[index] == "--from" then FROM = value
    elseif arg[index] == "--attach" then ATTACH = value
    elseif arg[index] == "--every" then EVERY = tonumber(value)
    elseif arg[index] == "--seconds" then SECONDS = tonumber(value)
    elseif arg[index] == "--out" then OUT = value
    end
end
FROM = FROM or (DIR .. "/assets/phase-8-history")
-- }}}

local socket = require("socket")
local settings = dofile(ROOT .. "/src/001-settings.lua")
local goodbye = dofile(ROOT .. "/src/002-goodbye.lua")
local viewer = dofile(ROOT .. "/src/022-viewer.lua")

-- {{{ helpers
local function shell(command)
    local pipe = io.popen(command .. " 2>&1")
    local text = pipe:read("*a")
    pipe:close()
    return (string.gsub(text, "\n$", ""))
end
local function q(text) return "'" .. string.gsub(text, "'", "'\\''") .. "'" end
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
local function list(path)
    local names = {}
    for name in string.gmatch(shell("ls -1A " .. q(path) .. " 2>/dev/null") .. "\n", "([^\n]+)\n") do
        names[#names + 1] = name
    end
    return names
end
local function wait_until(test, seconds)
    local deadline = socket.gettime() + seconds
    while socket.gettime() < deadline do
        if test() then return true end
        socket.sleep(0.05)
    end
    return test()
end
local function say(...) io.write(...) io.write("\n") io.flush() end
-- the text a terminal shows: no escape codes, no carriage returns
local function plain(text) return (string.gsub(string.gsub(text or "", "\27%[[%d;?]*%a", ""), "\r", "")) end
local function utf8_chars(text)
    local out = {}
    for character in string.gmatch(text, "[%z\1-\127\194-\244][\128-\191]*") do out[#out + 1] = character end
    return out
end
-- }}}

-- {{{ the copy's settings, and its canvas folder
local KEYS = BASE .. "/keys"
write(ROOT .. "/input/canvas-server", table.concat({
    'listen-address = "127.0.0.1"', "port = 0", "max-connections = 16",
    "max-request-bytes = 4096", "request-seconds = 5", "wait-seconds = 30", "check-seconds = 0.05",
    -- 127.0.0.1 is counted as outside, so the page goes the way a browser away from home does
    'local-addresses = "192.168.1.100"', 'send-plain = "local"',
    'viewers-file = "' .. KEYS .. '/viewers"', "session-seconds = 3600", "max-sessions = 8",
    "password-rounds = 1000", "" }, "\n"))
for _, name in ipairs({ "terminal-view", "lua-window" }) do
    shell("cp " .. q(DIR .. "/input/" .. name) .. " " .. q(ROOT .. "/input/" .. name))
end
settings.ensure_tiers(ROOT)
local SHM = ROOT .. "/tmp/shared-memory"
local CANVAS = SHM .. "/canvas"

local published = {}       -- version -> the second it was written
local history = {}         -- { version, text }, in order (replay)
if ATTACH then
    shell("rm -rf " .. q(CANVAS) .. " && ln -s " .. q(ATTACH) .. " " .. q(CANVAS))
else
    for _, name in ipairs(list(FROM)) do
        local text = slurp(FROM .. "/" .. name)
        local version = tonumber(string.match(text or "", "^canvas: (%d+)\n"))
        if version then history[#history + 1] = { version = version, text = text } end
    end
    table.sort(history, function(a, b) return a.version < b.version end)
    if #history < 2 then
        say("phase-8-demo: ", FROM, " holds fewer than two canvases; nothing to replay")
        os.exit(1)
    end
    shell("mkdir -p " .. q(CANVAS .. "/history"))
end

-- As the blitter writes a version: history first, then current, each by rename.
local function publish(entry)
    local name = string.format("%06d", entry.version)
    write(CANVAS .. "/history/." .. name, entry.text)
    os.rename(CANVAS .. "/history/." .. name, CANVAS .. "/history/" .. name)
    write(CANVAS .. "/.current", entry.text)
    os.rename(CANVAS .. "/.current", CANVAS .. "/current")
    published[entry.version] = socket.gettime()
end
-- }}}

-- {{{ the canvas server and a viewer key for the page
local LOGS = { terminal = SHM .. "/terminal-view.log", window = SHM .. "/lua-window.log",
               page = BASE .. "/page.log", server = SHM .. "/canvas-server.log" }
if not ATTACH then publish(history[1]) end
local server_pid = shell("(" .. q(ROOT .. "/scripts/run-canvas-server") .. " " .. q(ROOT) .. " > "
    .. q(BASE .. "/server.out") .. " 2>&1 & echo $!)")
write(BASE .. "/canvas-server.pid", server_pid .. "\n")
local PORT
if not wait_until(function()
    PORT = string.match(slurp(LOGS.server) or "", "listening on 127%.0%.0%.1:(%d+)")
    return PORT ~= nil
end, 10) then
    say("phase-8-demo: the canvas server did not start: ", slurp(BASE .. "/server.out") or "")
    os.exit(1)
end
local added = shell(q(ROOT .. "/scripts/add-viewer") .. " " .. q(ROOT) .. " demo --address 127.0.0.1 < /dev/null")
local KEY = string.match(added, "#demo:(%x+)")
-- }}}

-- {{{ the three viewers
local NODE = shell("command -v node") ~= ""
local FIREFOX = shell("command -v firefox") ~= ""
local first = ATTACH and nil or history[1]
local count = ATTACH and 0 or #history
-- the schedule, from the viewers' start: they settle, then a version each EVERY seconds
local SETTLE = 3.0
local LAST = ATTACH and (SECONDS - 0.5) or (SETTLE + (count - 2) * EVERY)
local SHOT = ATTACH and (SECONDS - 0.5) or (LAST + 1.5)
local started = socket.gettime()
-- each in the background, its process number in BASE/NAME.pid for phase-8-demo's clean-up
local function start(command, name)
    write(BASE .. "/" .. name .. ".pid", shell("(" .. command .. " > " .. q(BASE .. "/" .. name .. ".out")
        .. " 2>&1 & echo $!)") .. "\n")
end
start("luajit " .. q(ROOT .. "/src/070-terminal-view.lua") .. " --dir " .. q(ROOT) .. " --size 160x50",
    "terminal")
start("luajit " .. q(ROOT .. "/src/072-lua-window.lua") .. " --dir " .. q(ROOT)
    .. string.format(" --screenshot %.2f", SHOT), "lua-window")
if NODE then
    start("node " .. q(DIR .. "/issues/completed/demos/phase-8-page.js") .. " follow " .. PORT
        .. " demo " .. KEY .. " " .. q(LOGS.page) .. " " .. q(BASE .. "/page.stop"), "page")
end

-- each "drew version N at T" line of a viewer's log
local function draws(which)
    local seen = {}
    for version, at in string.gmatch(slurp(LOGS[which]) or "", "drew version (%d+) at ([%d%.]+)") do
        version = tonumber(version)
        seen[version] = seen[version] or tonumber(at)
    end
    return seen
end
local VIEWERS = { "terminal", "window" }
if NODE then VIEWERS[#VIEWERS + 1] = "page" end
local NAMES = { terminal = "terminal view", window = "Lua window", page = "HTML page" }
-- }}}

-- {{{ the run
say("Phase 8: three viewers, one canvas.")
if ATTACH then
    say("Watching the live canvas in ", ATTACH, " for ", SECONDS, " s; nothing is written to it.")
else
    say(string.format("Replaying %d versions from %s, one each %.1f s, after %.0f s for the "
        .. "viewers to start.", count, FROM, EVERY, SETTLE))
    wait_until(function()
        for _, which in ipairs(VIEWERS) do
            if not draws(which)[first.version] then return false end
        end
        return true
    end, SETTLE)
    for index = 2, count do
        local due = started + SETTLE + (index - 2) * EVERY
        socket.sleep(math.max(0, due - socket.gettime()))
        publish(history[index])
    end
end
socket.sleep(math.max(0, started + SHOT + 0.8 - socket.gettime()))
-- }}}

-- {{{ the screenshots, all at the version the Lua window shows
local shots = list(SHM .. "/lua-window/screenshots")
local SHOWN
for _, name in ipairs(shots) do
    SHOWN = tonumber(string.match(name, "version%-(%d+)%.png$")) or SHOWN
end
if not OUT then
    local highest = 0
    shell("mkdir -p " .. q(DIR .. "/development-history"))
    for _, name in ipairs(list(DIR .. "/development-history")) do
        highest = math.max(highest, tonumber(string.match(name, "^(%d%d%d)%-") or "") or 0)
    end
    OUT = string.format("%s/development-history/%03d-phase-8-demo", DIR, highest + 1)
end
shell("mkdir -p " .. q(OUT))
local files = {}
for _, name in ipairs(shots) do
    local ending = string.match(name, "%.(%a+)$")
    shell("cp " .. q(SHM .. "/lua-window/screenshots/" .. name) .. " " .. q(OUT .. "/lua-window." .. ending))
    files["lua-window." .. ending] = true
end
-- the terminal view's last screen, as it was written to the terminal
local screens = slurp(BASE .. "/terminal.out") or ""
local last_screen = string.match(screens, ".*\27%[H\27%[2J(.*)$") or ""
write(OUT .. "/terminal-view.ansi", "\27[H\27[2J" .. last_screen)
write(OUT .. "/terminal-view.txt", plain(last_screen))
local page_shot = "none"
if NODE and SHOWN then
    shell("node " .. q(DIR .. "/issues/completed/demos/phase-8-page.js") .. " still " .. PORT
        .. " demo " .. KEY .. " " .. SHOWN .. " " .. q(OUT .. "/html-page"))
    page_shot = "html-page.html"
    if FIREFOX then
        shell("mkdir -p " .. q(BASE .. "/firefox") .. " && cd " .. q(BASE) .. " && timeout 90 firefox --headless "
            .. "--no-remote --profile " .. q(BASE .. "/firefox") .. " --window-size=1200,500 --screenshot "
            .. q(OUT .. "/html-page.png") .. " " .. q("http://127.0.0.1:" .. PORT .. "/#demo:" .. KEY .. ":" .. SHOWN))
        if io.open(OUT .. "/html-page.png") then page_shot = "html-page.png" end
    end
end
-- }}}

-- {{{ stopping: each viewer by its stop file, then the server
shell("mkdir -p " .. q(SHM .. "/terminal-view") .. " " .. q(SHM .. "/lua-window"))
write(SHM .. "/terminal-view/stop", "")
write(SHM .. "/lua-window/stop", "")
write(BASE .. "/page.stop", "")
local receipts = {}
local stopped = wait_until(function()
    receipts.terminal = goodbye.read(ROOT .. "/output/goodbye-terminal-view")
    receipts.window = goodbye.read(ROOT .. "/output/goodbye-lua-window")
    return receipts.terminal and receipts.window
end, 10)
if not stopped then
    say("phase-8-demo: ", receipts.terminal and "the Lua window" or "the terminal view",
        " did not stop at its stop file within 10 s")
end
write(SHM .. "/canvas-server.stop", "")
wait_until(function() return goodbye.read(ROOT .. "/output/goodbye-canvas-server") ~= nil end, 10)
shell("kill " .. server_pid .. " 2>/dev/null")
-- }}}

-- {{{ the numbers
-- When a version was written: as the demo wrote it, or, attached, its history file's time.
local function written_at(version)
    if published[version] then return published[version] end
    local path = string.format("%s/history/%06d", CANVAS, version)
    return tonumber(shell("date -r " .. q(path) .. " +%s.%N 2>/dev/null")) or nil
end
local function median(list)
    table.sort(list)
    if #list == 0 then return nil end
    return list[math.floor((#list + 1) / 2)]
end
local all_versions = {}
for _, which in ipairs(VIEWERS) do
    for version in pairs(draws(which)) do all_versions[version] = true end
end
local total = 0
for _ in pairs(all_versions) do total = total + 1 end
if not ATTACH then total = count end

say("")
say(string.format("%-14s %-17s %-28s %s", "viewer", "versions drawn", "delay, written to drawn", "screenshot"))
local SHOT_NAMES = { terminal = "terminal-view.txt", window = files["lua-window.png"] and "lua-window.png" or "none",
                     page = page_shot }
for _, which in ipairs(VIEWERS) do
    local seen, delays, drawn = draws(which), {}, 0
    for version, at in pairs(seen) do
        drawn = drawn + 1
        local was = written_at(version)
        -- only versions written while the viewer watched: the first was there before it began
        if was and was > started then delays[#delays + 1] = (at - was) * 1000 end
    end
    local longest = 0
    for _, d in ipairs(delays) do longest = math.max(longest, d) end
    local middle = median(delays)
    say(string.format("%-14s %-17s %-28s %s", NAMES[which], drawn .. " of " .. total,
        middle and string.format("median %d ms, longest %d ms", math.floor(middle + 0.5),
            math.floor(longest + 0.5)) or "-", SHOT_NAMES[which]))
end
if not NODE then
    say(string.format("%-14s %-17s %-28s %s", "HTML page", "-", "-", "not run: node is not installed"))
end
say("")
say("The terminal view and the Lua window look at canvas/current every 0.25 s (check-every);")
say("the page holds /canvas?after=N open on the canvas server, which looks every 0.05 s.")
say("Each delay counts from the version's file being written to the viewer's first frame of it.")
-- }}}

-- {{{ side by side
local function rows_between_borders(text, height)
    local rows = {}
    for line in string.gmatch((text or "") .. "\n", "([^\n]*)\n") do rows[#rows + 1] = line end
    for index, line in ipairs(rows) do
        if string.match(line, "^[+┌]") then
            local out = {}
            for row = index + 1, index + height do
                local characters = utf8_chars(rows[row] or "")
                table.remove(characters, 1)
                table.remove(characters)
                out[#out + 1] = (string.gsub(table.concat(characters), " +$", ""))
            end
            return out
        end
    end
    return {}
end
local view = SHOWN and viewer.read(slurp(string.format("%s/history/%06d", CANVAS, SHOWN)))
local same = false
if view then
    local truth = {}
    for row = 1, view.height do
        local text = {}
        for column = 1, view.width do text[column] = view.cells[row][column].character end
        truth[row] = (string.gsub(table.concat(text), " +$", ""))
    end
    local columns = {
        { "terminal view", rows_between_borders(plain(last_screen), view.height) },
        { "Lua window", rows_between_borders(slurp(OUT .. "/lua-window.txt"), view.height) },
        { "HTML page", {} },
    }
    for line in string.gmatch((slurp(OUT .. "/html-page.txt") or "") .. "", "([^\n]*)\n") do
        table.insert(columns[3][2], (string.gsub(line, " +$", "")))
    end
    -- the viewers that ran (without node, the page did not) each show the canvas's characters
    same = true
    for index, column in ipairs(columns) do
        for row = 1, view.height do
            if (index < 3 or NODE) and column[2][row] ~= truth[row] then same = false end
        end
    end
    say("")
    say(string.format("The screenshots at version %d, side by side (the characters; the "
        .. "colours are in the pictures):", SHOWN))
    local width = view.width
    local function cell(text)
        local length = #utf8_chars(text)
        return text .. string.rep(" ", width - length)
    end
    say("  " .. table.concat({ cell(columns[1][1]), cell(columns[2][1]), cell(columns[3][1]) }, "   "))
    for row = 1, view.height do
        local parts = {}
        for index, column in ipairs(columns) do
            parts[index] = "|" .. cell(column[2][row] or (index == 3 and not NODE and "(not run)" or "")) .. "|"
        end
        say("  " .. table.concat(parts, " "))
    end
    say(same and (NODE and "All three show" or "Both viewers that ran show")
        .. " the canvas's own characters, row for row."
        or "They differ from the canvas's own characters: see the files.")
end
-- }}}

-- {{{ the page beside the pictures, and its note
local page_figure = page_shot == "html-page.png" and '<img src="html-page.png" alt="the HTML page">'
    or (page_shot == "html-page.html" and '<iframe src="html-page.html" title="the HTML page"></iframe>'
    or "<p>not run: node is not installed</p>")
write(OUT .. "/side-by-side.html", table.concat({
    "<!doctype html>", '<html lang="en"><head><meta charset="utf-8">',
    "<title>Three viewers, one canvas</title>",
    "<style>body { background: #101418; color: #e8e8e8; font-family: monospace; margin: 16px; }",
    "figure { display: inline-block; vertical-align: top; margin: 0 16px 16px 0; }",
    "pre { margin: 0; line-height: 1.2; } iframe { width: 1100px; height: 260px; border: 0; }",
    "img { image-rendering: pixelated; } figcaption { color: #8a96a3; margin-top: 4px; }</style>",
    "</head><body>", "<h1>Three viewers, one canvas: version " .. tostring(SHOWN) .. "</h1>",
    "<figure><pre>" .. string.gsub(string.gsub(plain(last_screen), "&", "&amp;"), "<", "&lt;")
        .. "</pre><figcaption>the terminal view</figcaption></figure>",
    '<figure><img src="lua-window.png" alt="the Lua window"><figcaption>the Lua window '
        .. "(headless)</figcaption></figure>",
    "<figure>" .. page_figure .. "<figcaption>the HTML page" .. (page_shot == "html-page.png"
        and " in Firefox" or " (its own drawing; Firefox is not installed)") .. "</figcaption></figure>",
    "</body></html>", "" }, "\n"))
local commit = shell("git -C " .. q(DIR) .. " rev-parse --short HEAD 2>/dev/null")
write(OUT .. ".info.md", table.concat({
    "# " .. string.match(OUT, "[^/]+$"), "",
    "The phase 8 demo (issue 804): the terminal view, the Lua window and the HTML page "
        .. "watching one canvas, each screenshotted at version " .. tostring(SHOWN) .. ".", "",
    "- made by: issues/completed/demos/phase-8-demo",
    "- commit: " .. (commit ~= "" and commit or "not a git checkout"),
    "- filed: " .. os.date("!%Y-%m-%dT%H:%M:%SZ"),
    "- canvas: " .. (ATTACH and ("the live canvas in " .. ATTACH) or ("replayed from " .. FROM)),
    "- side-by-side.html: the three together",
    "- terminal-view.txt (.ansi: as written to the terminal), lua-window.png and .txt, "
        .. (page_shot == "html-page.png" and "html-page.png (Firefox) and html-page.html" or "html-page.html"),
    "", }, "\n"))
say("")
say("Filed in ", OUT, " (side-by-side.html shows the three together).")
if not FIREFOX then
    say("Firefox is not installed here, so the page's picture is its own drawing as HTML, not a")
    say("screenshot; on kuvalu, with Firefox, it is Firefox's.")
end
-- }}}

os.exit((SHOWN and same and stopped) and 0 or 1)
