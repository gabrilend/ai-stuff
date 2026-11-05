#!/usr/bin/env luajit
-- 030-test-phase-2-demo.lua
--
-- Runs the phase 2 demo as the owner would: once kept, to read the throwaway
-- project it leaves, and once through run-phase-demo, which must clean up
-- after itself. Checks that both readers received every version, that their
-- copies are byte for byte the canvas files (read here, not taken from the
-- demo's word), the marks it draws under each row and their ages, the
-- blitter's mark numbers against its receipt, the server's requests against
-- the HTTP reader's, and that nothing is left running. Then once in a
-- pseudo-terminal, where the marks are colours.
--
-- For a general: the demo is what the owner watches to see phase 2 work: a
-- canvas reaching two kinds of viewer, identical, with the marks that let a
-- reader skim it fading as it moves on. This proves the demo shows what the
-- programs really did.
--
-- usage:
--   luajit 030-test-phase-2-demo.lua [--dir ROOT]

-- {{{ DIR -- the project root, hard-coded, overridable by --dir
local DIR = "/mnt/mtwo/programming/ai-stuff/guide-feature"
for index = 1, #arg do
    if arg[index] == "--dir" then DIR = arg[index + 1] end
end
-- }}}

local ffi = require("ffi")
pcall(ffi.cdef, "int setenv(const char *name, const char *value, int overwrite);")

local series = dofile(DIR .. "/src/018-phase-1-series.lua")
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
local function has(text, piece)
    return text ~= nil and string.find(text, piece, 1, true) ~= nil
end
local function slurp(path)
    local handle = io.open(path, "rb")
    if not handle then return nil end
    local text = handle:read("*a")
    handle:close()
    return text
end
-- The block the demo shows for one version, up to the next blank line.
local function block(out, version)
    return string.match(out, "\n(  version " .. version .. ": .-)\n\n")
        or string.match(out, "\n(  version " .. version .. ": .-)$")
end
local W = series.WIDTH
local function row(text) return "  |" .. text .. string.rep(" ", W - #text) .. "|" end
-- }}}

io.write("\n=== the demo, kept ===\n")
-- {{{
local TMP = shell("mktemp -d")
ffi.C.setenv("TMPDIR", TMP, 1)
local DEMO = DIR .. "/issues/completed/demos/phase-2-demo"
local out, status = shell("'" .. DEMO .. "' '" .. DIR .. "' --keep --plain")
check("it runs to the end and exits 0", status == 0, out)
local kept = string.match(out, "kept the throwaway project at (%S+)")
check("with --keep it says where its throwaway project is", kept ~= nil)
local BASE = kept and string.match(kept, "^(.*)/[^/]+$") or "/nonexistent"

-- {{{ every version drawn
local drawn = {}
for number in string.gmatch(out, "\n  version (%d+): ") do drawn[#drawn + 1] = tonumber(number) end
check("it draws versions 1 to 8, each once, in order",
    table.concat(drawn, ",") == "1,2,3,4,5,6,7,8", table.concat(drawn, ","))
local rows_drawn, right_width = 0, true
for line in string.gmatch(out, "\n(  |[^\n]*)") do
    rows_drawn = rows_drawn + 1
    if #line ~= W + 4 or string.sub(line, -1) ~= "|" then right_width = false end
end
check("each drawn at the canvas's real size, every row inside its frame",
    rows_drawn == 8 * series.HEIGHT and right_width, rows_drawn)
check("it says the server is on 127.0.0.1", string.match(out, "server is on 127%.0%.0%.1:%d+\n"))
check("plain output has no terminal colours in it", not has(out, "\27["))
-- }}}

-- {{{ the marks, by voice and kind
check("a voice's first words are word marks in its number",
    has(block(out, 2), row("the cat sat on the mat.") .. "\n   111 111 111 11 111 1111\n"))
check("a changed word is a word mark, the rest of its sentence a sentence mark in its letter",
    has(block(out, 3), row("it was a windy day.") .. "\n   bb bbb b 22222 bbbb\n"))
check("a cell blanked by a voice is marked by it; one it did not touch keeps its older mark",
    has(block(out, 7), row("the dog     on the mat.") .. "\n   ccc 3333331 cc ccc cccc\n"))
check("marks older than their lifetime are gone: the windy row has none by version 7",
    has(block(out, 7), row("it was a windy day.") .. "\n" .. row("") .. "\n"))
check("and the dog row none by version 8, while the newer ones stay",
    has(block(out, 8), row("a dog       by the door.") .. "\n" .. row("it was a windy day."))
    and has(block(out, 8), row("and then it rained.") .. "\n   111 1111 11 1111111\n"))
check("the refused canvas and the turn that changed nothing are said, with no version",
    has(out, "fg-sora-3's canvas was refused (wrong-size): the canvas is 47 characters wide; "
        .. "it must be exactly 40")
    and has(out, "fg-sora-2's turn 3 changed nothing: no new version"))
check("the empty canvas has no marks", has(block(out, 1), "marks on the canvas by age: none"))
-- }}}

-- {{{ the mark numbers
check("each version's marks made are the blitter's: 52 word cells for the first words",
    has(block(out, 2), "marks made: 52 cells word, 0 cells sentence; 0 expired"))
check("marks expire as the canvas moves on: 15 at version 7, 19 at version 8",
    has(block(out, 7), "marks made: 6 cells word, 12 cells sentence; 15 expired")
    and has(block(out, 8), "marks made: 16 cells word, 0 cells sentence; 19 expired"))
check("the marks on each canvas are counted by age, up to the lifetime",
    has(block(out, 6), "marks on the canvas by age: age 0: 7, age 1: 19, age 2: 19, age 3: 15"))
local receipt = kept and goodbye.read(kept .. "/output/goodbye-blitter")
local c = receipt and receipt.counters or {}
check("the blitter's receipt: 98 word cells, 48 sentence cells, 34 expired",
    c["cells-marked-word"] == 98 and c["cells-marked-sentence"] == 48
    and c["marks-expired"] == 34 and c["versions-in-history"] == 8)
-- }}}

-- {{{ the two readers, checked here against the files
local same, readable, how = true, true, { files = {}, http = {} }
for version = 1, 8 do
    local name = string.format("%06d", version)
    local history = kept and slurp(kept .. "/tmp/shared-memory/canvas/history/" .. name)
    local files = slurp(BASE .. "/readers/files/" .. name)
    local http = slurp(BASE .. "/readers/http/" .. name)
    if not history or files ~= history or http ~= history then same = false end
    local view = files and viewer.read(files, name)
    if not view or view.version ~= version then readable = false end
end
for _, which in ipairs({ "files", "http" }) do
    for line in string.gmatch(slurp(BASE .. "/readers/" .. which .. "/received") or "", "[^\n]+") do
        local way = string.match(line, "^%d+ (%S+) ")
        how[which][way or "unreadable"] = (how[which][way or "unreadable"] or 0) + 1
    end
end
check("both readers hold versions 1 to 8, each byte for byte its canvas/history file", same)
check("each copy reads back through the viewer-side reader as its own version", readable)
check("the HTTP reader got versions by holding ?after= requests, the files reader from current",
    (how.http.wait or 0) >= 4 and how.http.first == 1 and (how.files.current or 0) >= 4
    and not how.files.unreadable and not how.http.unreadable)
local identical = select(2, string.gsub(out, "the two copies and canvas/history: byte for "
    .. "byte the same, %d+ bytes\n", ""))
check("the demo says so for every version, and never DIFFERENT",
    identical == 8 and not has(out, "DIFFERENT"), identical)
local times, quick = 0, true
for files_ms, http_ms in string.gmatch(out, "reached the files reader (%d+) ms %(%a+%), the HTTP "
    .. "reader (%d+) ms") do
    times = times + 1
    if tonumber(files_ms) > 2000 or tonumber(http_ms) > 2000 then quick = false end
end
check("how long each version took to reach each reader is shown, each under two seconds",
    times == 8 and quick, times)
check("version 1 is left out of the times, being there before the readers started",
    has(block(out, 1), "it was there before the readers started")
    and string.match(out, "for the versions made while they watched:\n    files reader  "
        .. "fastest %d+ ms, median %d+ ms, slowest %d+ ms\n    HTTP reader   fastest %d+ ms"))
-- }}}

-- {{{ the server, against the HTTP reader
local served = kept and goodbye.read(kept .. "/output/goodbye-canvas-server")
local s = served and served.counters or {}
local refused = 0
for counter, value in pairs(s) do
    if string.match(counter, "^refused%-") then refused = refused + value end
end
check("the server sent every version once: 1 first, the rest held or fetched from history",
    (s["requests-canvas"] or 0) + (s["waits-answered"] or 0)
        + (s["requests-canvas-version"] or 0) == 8, served and served.counters)
check("the reader's last held request was abandoned when it stopped, and none refused",
    s["waits-abandoned"] == 1 and refused == 0)
local _, agree = string.gsub(out, "   agree\n", "")
check("every number agrees, on all eleven lines", agree == 11 and not has(out, "DISAGREE")
    and has(out, "Both readers received every version, identical, while the marks aged; "
        .. "every number agrees."), agree)
check("both readers stopped by their stop files",
    has(slurp(BASE .. "/readers/files/done"), "stopped at version 8")
    and has(slurp(BASE .. "/readers/http/done"), "stopped at version 8"))
check("the blitter, the server and the readers it started have all ended", select(2,
    shell("pgrep -f '[l]uajit .*" .. (kept and string.match(kept, "[^/]+/[^/]+$") or "none")
        .. "'")) ~= 0)
-- }}}
if kept then shell("rm -rf '" .. BASE .. "'") end
-- }}}

io.write("\n=== the demo through run-phase-demo ===\n")
-- {{{
local listed = shell("'" .. DIR .. "/run-phase-demo' '" .. DIR .. "' 9")
check("run-phase-demo offers phase 2", has(listed, "Phases with one: 1 2"), listed)
local again, again_status = shell("'" .. DIR .. "/run-phase-demo' '" .. DIR .. "' 2")
check("run-phase-demo runs it, plain when the output is not a terminal",
    again_status == 0 and has(again, "as letters under each row") and not has(again, "\27["))
-- every version's block, but for how long it took to reach the readers
local function canvases(text)
    local blocks = {}
    for version = 1, 8 do
        blocks[version] = string.gsub(block(text, version) or "", "\n  reached the [^\n]*", "")
    end
    return table.concat(blocks, "\n")
end
check("the same series gives the same canvases and marks every time",
    canvases(again) == canvases(out) and #canvases(out) > 0)
check("without --keep, its throwaway project is removed", shell("ls -A '" .. TMP .. "'") == "")
local wrong, wrong_status = shell("'" .. DEMO .. "' '" .. TMP .. "'")
check("given a folder that is not the project, it says so and stops",
    wrong_status ~= 0 and has(wrong, "is not the guide-feature project"))
-- }}}

io.write("\n=== the demo in a terminal ===\n")
-- {{{
local _, have_script = shell("command -v script")
if have_script == 0 then
    local coloured, coloured_status = shell("script -qc \"'" .. DEMO .. "' '" .. DIR
        .. "'\" /dev/null")
    check("in a terminal it runs to the end", coloured_status == 0
        and has(coloured, "every number agrees"))
    -- fg-sora-1: red, cube step 5,1,1 at full strength (203), its sentence
    -- marks at half (131); fg-sora-2's word marks green (83)
    -- version 5's first row: "the" a fresh sentence mark, "kitten" a fresh
    -- word mark, both fg-sora-1's
    local five = string.match(coloured, "version 5:.-\n  |([^\n]*)") or ""
    local the = string.match(five, "^\27%[48;5;(%d+);38;5;231mt")
    local kitten = string.match(five, "\27%[48;5;(%d+);38;5;231mk")
    check("marks are coloured by voice, a word mark stronger than a sentence mark",
        kitten == "203" and the == "131" and has(coloured, "\27[48;5;83;38;5;231mw"),
        tostring(the) .. " " .. tostring(kitten))
    -- the first words, at version 2 (age 0, 203) and version 4 (age 2, fainter)
    local young = string.match(coloured, "version 2:.-\27%[48;5;(%d+);38;5;231mt")
    local old = string.match(coloured, "version 4:.-\27%[48;5;(%d+);38;5;231mt")
    check("and dimmed by age", young == "203" and old ~= nil and tonumber(old) < 203,
        tostring(young) .. " " .. tostring(old))
    check("with no letters under the rows", not string.find(coloured, "\n   111 ", 1, true))
else
    check("script, to give the demo a terminal, is not installed; skipped", true)
end
shell("rm -rf '" .. TMP .. "'")
-- }}}

io.write(string.format("\nTests: %d passed, %d failed\n", passed, failed))
os.exit(failed == 0 and 0 or 1)
