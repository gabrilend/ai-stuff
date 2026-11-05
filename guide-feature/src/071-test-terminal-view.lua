#!/usr/bin/env luajit
-- 071-test-terminal-view.lua
--
-- Tests the terminal view (issue 801, src/070-terminal-view.lua,
-- scripts/terminal-view). Each test canvas every viewer shares
-- (assets/test-canvases/) is drawn and compared byte for byte with a
-- reference file in assets/test-terminal/: the border, the voices' colours,
-- word marks bright and sentence marks dim, stepping down with age, kuvalu's
-- colour. Then the settings' refusals, the too-small error naming both sizes,
-- --plain, a replay of a history folder, the live view redrawing when
-- canvas/current changes (and only then), the stop file, and the receipt.
--
-- For a general: the canvas can now be watched in any terminal on kuvalu,
-- each voice's fresh words in its own bright colour, fading as they age.
--
-- usage:
--   luajit 071-test-terminal-view.lua [--dir ROOT] [--write-references]
--   --write-references rewrites assets/test-terminal/ from what is drawn now
--   (look at them before committing: `cat` shows the colours).

-- {{{ DIR -- the project root, hard-coded, overridable by --dir
local DIR = "/mnt/mtwo/programming/ai-stuff/guide-feature"
local WRITE_REFERENCES = false
for index = 1, #arg do
    if arg[index] == "--dir" then DIR = arg[index + 1] end
    if arg[index] == "--write-references" then WRITE_REFERENCES = true end
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
local function visible(text) return (text:gsub("\27", "\\e"):gsub("\r\n", "\\r\\n\n")) end
-- }}}

-- {{{ the throwaway project
local BASE = shell("mktemp -d")
local ROOT = BASE .. "/project/guide-feature"
shell("mkdir -p " .. q(ROOT .. "/input") .. " " .. q(ROOT .. "/output") .. " "
    .. q(BASE .. "/exec") .. " " .. q(BASE .. "/shm"))
for _, name in ipairs({ "src", "libs", "scripts" }) do
    shell("ln -s " .. q(DIR .. "/" .. name) .. " " .. q(ROOT .. "/" .. name))
end
ffi.C.setenv("EXEC_TIER_ROOT", BASE .. "/exec", 1)
ffi.C.setenv("ARTIFACT_TIER_ROOT", BASE .. "/shm", 1)
local SETTINGS = slurp(DIR .. "/input/terminal-view")
write(ROOT .. "/input/terminal-view", SETTINGS)
local CANVAS = ROOT .. "/tmp/shared-memory/canvas"
shell("mkdir -p " .. q(CANVAS .. "/history"))
-- }}}

local view = dofile(DIR .. "/src/070-terminal-view.lua")
local viewer = dofile(DIR .. "/src/022-viewer.lua")
local goodbye = dofile(DIR .. "/src/002-goodbye.lua")

io.write("\n=== the shared test canvases, against their references ===\n")
-- {{{
local s = view.read_settings(ROOT)
local REFS = DIR .. "/assets/test-terminal"
if WRITE_REFERENCES then shell("mkdir -p " .. q(REFS)) end
for _, name in ipairs({ "01-empty", "02-kitten", "03-dog", "04-aging" }) do
    local v = viewer.read(slurp(DIR .. "/assets/test-canvases/" .. name .. ".canvas"), name)
    local screen, drawn = view.draw(v, { columns = 80, rows = 24, settings = s })
    if WRITE_REFERENCES then write(REFS .. "/" .. name .. ".screen", screen) end
    local reference = slurp(REFS .. "/" .. name .. ".screen")
    check(name .. " is drawn as its reference", drawn and screen == reference,
        "drawn:\n" .. visible(screen) .. "\nreference:\n" .. visible(reference or "(none)"))
end
-- }}}

io.write("\n=== what the references hold ===\n")
-- {{{
local aging = viewer.read(slurp(DIR .. "/assets/test-canvases/04-aging.canvas"), "04-aging")
local screen = view.draw(aging, { columns = 80, rows = 24, settings = s })
local lines = {}
for line in screen:gmatch("([^\n]*)\n") do lines[#lines + 1] = line end
check("the screen is cleared and the border is the canvas's size",
    screen:sub(1, 7) == "\27[H\27[2J" and lines[1]:sub(8) == "┌" .. string.rep("─", 16) .. "┐\r"
    and lines[5] == "└" .. string.rep("─", 16) .. "┘\r", visible(screen))
-- 04-aging is version 9: fg-sora-3's word mark of age 0, fg-sora-1's word of
-- age 2 and sentence of age 2, fg-sora-2's sentence of age 6 and orphan of
-- age 1, kuvalu's word of age 0
check("a word mark of age 0: its voice's bright colour, bold (fg-sora-3: 34 -> 94)",
    has(lines[2], "\27[0;1;94mgo.\27[0m"), visible(lines[2]))
check("a word mark of age 2: the plain colour (word-steps' third step; fg-sora-1: 31)",
    has(lines[3], "\27[0;31mnow\27[0m"), visible(lines[3]))
check("a sentence mark of age 2: dim, its last step", has(lines[3], "\27[0;2;31mwe"),
    visible(lines[3]))
check("an older sentence mark: dim in its own voice's colour (fg-sora-2: 32)",
    has(lines[3], "\27[0;2;32mwait."), visible(lines[3]))
check("an orphan is drawn as a sentence mark: fg-sora-2's, age 1, dim",
    has(lines[4], "caf\27[0;2;32mé\27[0m"), visible(lines[4]))
check("kuvalu's word mark is in kuvalu's colour, bright (35 -> 95)",
    has(lines[4], "\27[0;1;95molé\27[0m"), visible(lines[4]))
check("cells with no mark are in the default colour, with no code",
    lines[3]:match("^│\27") ~= nil and has(lines[3], "\27[0m \27[0;2;31m"), visible(lines[3]))
local plain = view.draw(aging, { columns = 80, rows = 24, settings = s, plain = true })
check("--plain draws no colour", not plain:sub(8):find("\27", 1, true)
    and has(plain, "│now we wait.    │"), visible(plain))
local more = viewer.read((slurp(DIR .. "/assets/test-canvases/04-aging.canvas")
    :gsub("voices: fg%-sora%-1 fg%-sora%-2 fg%-sora%-3", "voices: a b c fg-sora-1 fg-sora-2 fg-sora-3")), "x")
check("a voice past the colours list takes the colours round again (fifth voice: the second colour)",
    view.style(more, { voice = "fg-sora-2", age = 0, kind = "word" }, s) == "1;92")
local edge = viewer.read((slurp(DIR .. "/assets/test-canvases/04-aging.canvas")
    :gsub("\ngo%.\n", "\ngo.          end\n"):gsub("mark: 1 1 3 fg%-sora%-3 9 word",
        "mark: 1 1 3 fg-sora-3 9 word\nmark: 1 14 3 fg-sora-1 9 word")), "edge")
local edge_line = view.draw(edge, { columns = 80, rows = 24, settings = s }):match("\n([^\n]*)\n")
check("a mark that reaches the row's end is closed before the border",
    edge_line == "│\27[0;1;94mgo.\27[0m          \27[0;1;91mend\27[0m│\r", visible(edge_line or ""))
-- }}}

io.write("\n=== too small, and the settings ===\n")
-- {{{
local small, drawn = view.draw(aging, { columns = 17, rows = 5, settings = s })
check("a terminal smaller than the canvas and its border shows an error naming both sizes",
    not drawn and small == "\27[H\27[2Jthe canvas is 16x3 (18x5 with its border); this terminal "
    .. "is 17x5\r\n", visible(small))
check("one exactly the size fits", select(2, view.draw(aging, { columns = 18, rows = 5, settings = s })))
local function refusal(name, value)
    write(ROOT .. "/input/terminal-view", (SETTINGS:gsub("\n" .. name:gsub("%-", "%%-") .. "%s*= [^\n]*",
        "\n" .. name .. " = " .. value)))
    local problem = refused(view.read_settings, ROOT)
    write(ROOT .. "/input/terminal-view", SETTINGS)
    return problem
end
check("a colour that is not 30 to 37 is refused", has(refusal("colours", '"31 92 34"'),
    "input/terminal-view: colours: '92' is not a colour code from 30 to 37"))
check("a step that is not bright, normal or dim is refused", has(refusal("word-steps",
    '"bright loud"'), "word-steps: 'loud' is not bright, normal or dim"))
check("an empty list is refused", has(refusal("sentence-steps", '""'), "sentence-steps: no step given"))
check("a missing setting is refused, by the settings reader", has(refusal("kuvalu-colour", "")
    or refused(view.read_settings, ROOT) or "", "input/terminal-view"))
-- }}}

io.write("\n=== the program: a replay, the live view, the receipt ===\n")
-- {{{
local REPLAY = BASE .. "/replay"
shell("mkdir -p " .. q(REPLAY))
for number, name in ipairs({ "02-kitten", "03-dog", "04-aging" }) do
    write(string.format("%s/%06d", REPLAY, number), slurp(DIR .. "/assets/test-canvases/" .. name .. ".canvas"))
end
write(REPLAY .. "/000004", "not a canvas\n")
local out, status = shell("luajit " .. q(DIR .. "/src/070-terminal-view.lua") .. " --dir " .. q(ROOT)
    .. " --replay " .. q(REPLAY) .. " --size 80x24")
local clears = select(2, out:gsub("\27%[H\27%[2J", ""))
check("--replay draws every version in the folder, in order, and stops", status == 0 and clears == 3
    and out:find("kitten", 1, true) < out:find("olé", 1, true), visible(out:sub(1, 400)))
local receipt = goodbye.read(ROOT .. "/output/goodbye-terminal-view")
check("its receipt counts versions read and drawn, and the one that did not read",
    receipt and receipt.counters["versions-read"] == 4 and receipt.counters["versions-drawn"] == 3
    and receipt.counters["unreadable"] == 1 and receipt.counters["seconds-run"] ~= nil)
local small_out = shell("luajit " .. q(DIR .. "/src/070-terminal-view.lua") .. " --dir " .. q(ROOT)
    .. " --replay " .. q(REPLAY) .. " --size 10x4")
receipt = goodbye.read(ROOT .. "/output/goodbye-terminal-view")
check("in a terminal too small, every version is the error, counted as too-small",
    has(small_out, "this terminal is 10x4") and receipt.counters["too-small"] == 3
    and (receipt.counters["versions-drawn"] or 0) == 0)

-- the live view, through scripts/terminal-view, in the background
write(CANVAS .. "/current", slurp(DIR .. "/assets/test-canvases/02-kitten.canvas"))
local LIVE = BASE .. "/live.out"
shell("( " .. q(ROOT .. "/scripts/terminal-view") .. " " .. q(ROOT) .. " --size 80x24 > " .. q(LIVE)
    .. " 2>&1; echo $? > " .. q(BASE .. "/live.status") .. " ) > /dev/null 2>&1 &")
local function wait_for(test)
    for _ = 1, 100 do
        if test() then return true end
        sleep(0.05)
    end
    return false
end
check("the live view draws canvas/current", wait_for(function() return has(slurp(LIVE), "kitten") end))
sleep(0.8)
local before = select(2, (slurp(LIVE) or ""):gsub("\27%[H\27%[2J", ""))
check("and does not draw again while it is unchanged", before == 1, before)
-- the blitter replaces current whole, by rename
write(CANVAS .. "/.current", slurp(DIR .. "/assets/test-canvases/03-dog.canvas"))
os.rename(CANVAS .. "/.current", CANVAS .. "/current")
check("a new version is drawn when canvas/current changes", wait_for(function()
    return select(2, (slurp(LIVE) or ""):gsub("\27%[H\27%[2J", "")) == 2 end), visible(slurp(LIVE) or ""))
shell("mkdir -p " .. q(ROOT .. "/tmp/shared-memory/terminal-view") .. " && : > "
    .. q(ROOT .. "/tmp/shared-memory/terminal-view/stop"))
check("the stop file ends it cleanly", wait_for(function()
    return (slurp(BASE .. "/live.status") or ""):match("^0") ~= nil end))
receipt = goodbye.read(ROOT .. "/output/goodbye-terminal-view")
check("its receipt: two versions drawn", receipt and receipt.counters["versions-drawn"] == 2
    and has(slurp(ROOT .. "/tmp/shared-memory/terminal-view.log") or "", "stop file found"))
local once = shell("luajit " .. q(DIR .. "/src/070-terminal-view.lua") .. " --dir " .. q(ROOT)
    .. " --once --size 80x24 --plain")
check("--once draws the current canvas once and stops", has(once, "│") and
    select(2, once:gsub("\27%[H\27%[2J", "")) == 1)
-- }}}

if failed > 0 then io.write("kept ", BASE, "\n") else shell("rm -rf " .. q(BASE)) end
io.write(string.format("\nTests: %d passed, %d failed\n", passed, failed))
os.exit(failed == 0 and 0 or 1)
