#!/usr/bin/env luajit
-- 069-test-phase-6-demo.lua
--
-- Tests issues/completed/demos/phase-6-demo (issue 602). First on a
-- recording made by hand, three arrivals whose outcome is known: two voices
-- writing on the same word (newest mode: the later one wins, with a
-- conflict; distill mode: the stand-in distiller keeps the first, and makes
-- no version), and a third on its own row, whose distill runs past the edge
-- once and is asked again. The demo's numbers, side-by-side canvases and
-- survival counts are checked against those known outcomes. Then a recorded
-- rehearsal: the recording is saved, every arrival is shown in both modes,
-- and replaying the saved recording shows the same canvases and numbers
-- (only the seconds differ), which is what makes the comparison fair.
--
-- For a general: the demo is what the owner watches to see phase 6 work:
-- the same three voices' drafts, merged two ways, side by side. This proves
-- the demo shows what the two modes really did.
--
-- usage:
--   luajit 069-test-phase-6-demo.lua [--dir ROOT]
-- Its stand-in models and the rehearsal's mail listen on 127.0.0.1 only.

-- {{{ DIR -- the project root, hard-coded, overridable by --dir
local DIR = "/mnt/mtwo/programming/ai-stuff/guide-feature"
for index = 1, #arg do
    if arg[index] == "--dir" then DIR = arg[index + 1] end
end
-- }}}

local canvas = dofile(DIR .. "/src/006-canvas-text.lua")

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
local function count(text, piece)
    local n, at = 0, 1
    while true do
        local found = string.find(text, piece, at, true)
        if not found then return n end
        n, at = n + 1, found + 1
    end
end
-- }}}

local BASE = shell("mktemp -d")
local DEMO = DIR .. "/issues/completed/demos/phase-6-demo"

io.write("\n=== the voices' stand-in model, filling row by row (047) ===\n")
-- {{{
local stand_in = dofile(DIR .. "/src/047-stand-in-llama.lua")
local prompt = dofile(DIR .. "/src/049-turn-prompt.lua")
local function shown(rows)
    local r = canvas.blank(10, 3)
    for number, row in ipairs(rows) do r.rows[number] = row end
    return { { role = "user", content = prompt.ruler(r) } }
end
check("with fill, an empty nth row is started with the word",
    stand_in.rewrite(shown({ "oak" }), 2, "elm ash", false, true) == "oak\nash\n\n",
    stand_in.rewrite(shown({ "oak" }), 2, "elm ash", false, true))
check("with fill, a nth row with a word has its first word changed",
    stand_in.rewrite(shown({ "oak", "", "fir tree" }), 3, "elm ash", false, true)
        == "oak\n\nelm tree\n")
check("without fill, the next row with a word is changed, as before",
    stand_in.rewrite(shown({ "oak" }), 2, "elm ash", false) == "ash\n\n\n")
-- }}}

io.write("\n=== a recording made by hand ===\n")
-- {{{
local REC = BASE .. "/by-hand"
shell("mkdir -p " .. q(REC))
local function viewer_canvas(version, rows)
    local r = canvas.blank(40, 6, "for-viewers")
    for number, row in ipairs(rows) do r.rows[number] = row end
    r.headers = { canvas = version, size = { width = 40, height = 6 }, mode = "newest",
                  project = { name = "guide-feature", commit = "0000000" },
                  written = "2026-11-05T10:00:00Z", voices = { "fg-sora-1", "fg-sora-2", "fg-sora-3" } }
    r.marks = {}
    return canvas.write(r, "for-viewers")
end
local function voice_canvas(voice, turn, base, rows)
    local r = canvas.blank(40, 6, "from-voice")
    for number, row in ipairs(rows) do r.rows[number] = row end
    r.headers = { voice = voice, turn = turn, base = base, written = "2026-11-05T10:00:00Z" }
    return canvas.write(r, "from-voice")
end
-- 1: fg-sora-1 writes "alpha"; 2: fg-sora-2, from the same empty version,
-- writes "beta" on the same place; 3: fg-sora-3, from version 2 of the
-- recorded run, writes "gamma" on row 2
write(REC .. "/0001.base", viewer_canvas(1, {}))
write(REC .. "/0001.voice", voice_canvas("fg-sora-1", 1, 1, { "alpha" }))
write(REC .. "/0002.base", viewer_canvas(1, {}))
write(REC .. "/0002.voice", voice_canvas("fg-sora-2", 1, 1, { "beta" }))
write(REC .. "/0003.base", viewer_canvas(2, { "alpha" }))
write(REC .. "/0003.voice", voice_canvas("fg-sora-3", 1, 2, { "alpha", "gamma" }))
write(REC .. "/index", "0001 fg-sora-1-1000-a\n0002 fg-sora-2-1001-b\n0003 fg-sora-3-1002-c\n")
local out, status = shell(q(DEMO) .. " " .. q(DIR) .. " --from " .. q(REC) .. " --plain")
check("the demo replays a recording and ends cleanly", status == 0 and has(out,
    "Replaying the recording in ") and has(out, "Both modes replay the same 3 voice canvases"), out)
check("each arrival is named with its voice, turn, base and words",
    has(out, 'Arrival 1: fg-sora-1 turn 1, on version 1 (wrote "alpha")')
    and has(out, 'Arrival 2: fg-sora-2 turn 1, on version 1 (wrote "beta")')
    and has(out, 'Arrival 3: fg-sora-3 turn 1, on version 2 (wrote "gamma")'), out)
check("newest mode: each arrival a version; the second one's write cuts into the first's word",
    has(out, "newest: v2, 1 word changed, 0 conflicts, 0 words written over\n")
    and has(out, "newest: v3, 1 word changed, 0 conflicts, 1 word written over\n")
    and has(out, "newest: v4, 1 word changed, 0 conflicts, 0 words written over\n"), out)
check("distill mode: the second makes no version, the distiller keeping the first voice's "
    .. "word on the contested place",
    out:match("distill: v2, 1 word changed, fit at the first try, [%d%.]+ s") ~= nil
    and out:match("distill: no new version %(fit at the first try, [%d%.]+ s%)") ~= nil
    and out:match("distill: v3, 1 word changed, fit at the first try, [%d%.]+ s") ~= nil, out)
check("the second pair shows the two modes apart, the differing row starred",
    has(out, "|beta                                    | * |alpha                                   |"),
    out)
check("the changed cells are marked under their row in plain output",
    has(out, "\n   ^^^^^" .. string.rep(" ", 35) .. "     ^^^^^\n")
    and has(out, "\n   ^^^^^\n"), out)
local third = out:match("Arrival 3:.-Totals") or ""
local _, carets = third:gsub("%^", "")
check("only the cells a version wrote are marked, not the rest of their sentence",
    carets == 10, third)
check("the totals", has(out, "newest:  3 versions, 3 words changed, 0 conflicts, "
        .. "1 word written over\n")
    and out:match("distill: 2 versions, 2 words changed, 3 distills, 0 fit retries, [%d%.]+ s "
        .. "distilling") ~= nil, out)
check("what survived, per voice and mode", has(out, "fg-sora-1: newest 0 of 1, distill 1 of 1")
    and has(out, "fg-sora-2: newest 1 of 1, distill 0 of 1")
    and has(out, "fg-sora-3: newest 1 of 1, distill 1 of 1"), out)
check("the final canvases, side by side", has(out, "newest, v4") and has(out, "distill, v3")
    and has(out, "|gamma                                   |   |gamma                                   |"))
check("a folder that is not a recording is refused", (function()
    shell("mkdir -p " .. q(BASE .. "/empty"))
    local text, code = shell(q(DEMO) .. " " .. q(DIR) .. " --from " .. q(BASE .. "/empty") .. " --plain")
    return code ~= 0 and has(text, "is not a recording")
end)())
-- }}}

io.write("\n=== a recorded rehearsal, then the same recording replayed ===\n")
-- {{{
local SAVED = BASE .. "/saved"
local live, live_status = shell(q(DEMO) .. " " .. q(DIR) .. " --minutes 0.5 --save " .. q(SAVED)
    .. " --plain")
local recorded = tonumber(live:match("Recorded (%d+) voice canvas") or "")
check("it records a rehearsal with the real turn and saves the recording", live_status == 0
    and recorded and recorded >= 6 and slurp(SAVED .. "/index") ~= nil
    and has(live, "with the real turn (scripts/turn)"), live:sub(1, 3000))
local index_lines = count(slurp(SAVED .. "/index") or "", "\n")
check("every recorded canvas is shown, once each, in both modes", recorded == index_lines
    and count(live, "\nArrival ") == recorded
    and count(live, "\n  newest: v") + count(live, "\n  newest: no new") == recorded
    and count(live, "\n  distill: v") + count(live, "\n  distill: no new") == recorded,
    recorded .. " " .. index_lines)
local voices = 0
for _, voice in ipairs({ "fg-sora-1", "fg-sora-2", "fg-sora-3" }) do
    if live:match("Arrival %d+: " .. voice:gsub("%-", "%%-") .. " turn") then voices = voices + 1 end
end
check("all three voices' canvases were recorded", voices == 3)
check("the distiller ran past the edge now and then, and was asked again, shown on its arrival",
    tonumber(live:match("distills?, (%d+) fit retr") or 0) > 0 and has(live, ", fit at try 2, "),
    live:match("Totals.-\n\n"))
local bases_match, checked = true, 0
for number in string.gmatch(slurp(SAVED .. "/index") or "", "(%d+) %S+") do
    local base = (slurp(SAVED .. "/" .. number .. ".base") or ""):match("^canvas: (%d+)\n")
    local wanted = (slurp(SAVED .. "/" .. number .. ".voice") or ""):match("\nbase: (%d+)\n")
    checked = checked + 1
    if not base or base ~= wanted then bases_match = false end
end
check("each recorded canvas is saved with the version it started from", bases_match
    and checked == recorded)
check("the voices met on the same words: in newest mode some were written over",
    tonumber(live:match("newest:  %d+ versions?, %d+ words? changed, %d+ conflicts?, (%d+) "
        .. "words? written over") or 0) > 0,
    live:match("Totals.-\n\n"))
local again, again_status = shell(q(DEMO) .. " " .. q(DIR) .. " --from " .. q(SAVED) .. " --plain")
local function replayed(text)
    local from = text:find("Both modes replay", 1, true)
    return from and (text:sub(from):gsub("[%d%.]+ s", "S s"):gsub("Each mode's blitter log.*$", ""))
end
check("replaying the saved recording shows the same canvases and numbers (only the seconds "
    .. "differ)", again_status == 0 and replayed(live) ~= nil and replayed(live) == replayed(again))
check("the throwaway copies are removed", not has(live, "kept the throwaway"))
-- }}}

io.write("\n=== the front door ===\n")
-- {{{
local listing = shell("echo | " .. q(DIR .. "/run-phase-demo") .. " " .. q(DIR))
check("run-phase-demo offers phase 6", listing:match("Phases with a demo:[%d ]* 6") ~= nil, listing)
-- }}}

shell("rm -rf " .. q(BASE))
io.write(string.format("\nTests: %d passed, %d failed\n", passed, failed))
os.exit(failed == 0 and 0 or 1)
