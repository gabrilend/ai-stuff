-- Tests for poem-bars.lua. The bug these guard against: the bar width drifting
-- (88 chars, doubled ╧╧) instead of a fixed width with two single junctions.
-- The width is the owner's rule (2026-10-25): a wall, a space, up to 80
-- characters of text, a space, a wall -- 84 columns for every poem, regular
-- or golden.
-- Run: luajit src/poem-bars.test.lua
-- The project folder from --dir PATH, or nil when it was not given (the
-- default below is then used); a stray word on the command line stops the
-- program, named (libs/project-dir.lua, Issue 10-076).
local PROJECT_DIR_ARG = (function()
    local own = debug.getinfo(1, "S").source:sub(2):match("(.*/)") or "./"
    local dir = dofile(own .. "../libs/project-dir.lua").read(arg, "")
    if dir == "" then return nil end
    return dir
end)()

package.path = "./src/?.lua;./libs/?.lua;" .. package.path
local B = require("poem-bars")
local ok_unconfigured = pcall(B.corner_box_bottom)
B.configure({ gray = "#868E96", blue = "#74C0FC" }, 80)

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; print("  FAIL: " .. name) end
end

-- Strip HTML tags, then count UTF-8 codepoints (box chars are 3 bytes each).
local function visible(s)
    local txt = s:gsub("<[^>]+>", "")
    local _, n = txt:gsub("[^\128-\191]", "")  -- count non-continuation bytes = codepoints
    return n, txt
end
local function count(s, ch)
    local _, n = s:gsub(ch, "")
    return n
end

-- The width must hold at every progress level (the drift made it vary / overrun).
for _, pct in ipairs({0, 1, 37, 50, 99, 100}) do
    local bar = B.progress_dashes({ percentage = pct }, "blue", false, "bottom", true)
    local n, txt = visible(bar.visual)
    check("regular bottom bar is 84 wide @ " .. pct .. "%", n == 84)
    -- Exactly two junctions (╧ when in progress, ┴ when not) -- never ╧╧ doubled.
    local junctions = count(txt, "╧") + count(txt, "┴")
    check("regular bottom bar has exactly 2 junctions @ " .. pct .. "%", junctions == 2)
    check("regular bottom bar starts with left corner ╘ @ " .. pct .. "%", txt:sub(1, #"╘") == "╘")
end

-- Junctions must land at columns 10 and 71 (under the inner box walls),
-- the same columns as a golden poem's.
do
    local bar = B.progress_dashes({ percentage = 0 }, "gray", false, "bottom", true)
    local _, txt = visible(bar.visual)
    -- Walk codepoints, record junction columns (0-indexed).
    local col, cols = 0, {}
    for cp in txt:gmatch("[\1-\127\194-\244][\128-\191]*") do
        if cp == "╧" or cp == "┴" then cols[#cols + 1] = col end
        col = col + 1
    end
    check("junctions at columns 10 and 71", cols[1] == 10 and cols[2] == 71)
end

-- Corner box top is 84 wide.
do
    local n = visible(B.corner_box_top(40, "#74C0FC"))
    check("corner box top is 84 wide", n == 84)
end

-- Nav line is 84 wide WITH and WITHOUT the center chronological link.
do
    local sim = "<a href='x'>similar</a>"
    local dif = "<a href='y'>different</a>"
    local chrono = "<a href='z'>chronological</a>"
    local n_with = visible(B.corner_box_nav_line(sim, dif, chrono, 40, "#74C0FC"))
    local n_without = visible(B.corner_box_nav_line(sim, dif, nil, 40, "#74C0FC"))
    check("nav line 84 wide with center link", n_with == 84)
    check("nav line 84 wide without center link", n_without == 84)
end

-- A drawer that was never told the text width refuses to guess it.
check("drawing before configure() is an error", not ok_unconfigured)

-- The frame follows the text width: wall, space, text, space, wall.
do
    local f = B.frame(80)
    check("an 80-character text gives an 84-wide frame", f.width == 84)
    check("the right box starts at column 71", f.right_junction == 71)
    check("a 60-character text gives a 64-wide frame", B.frame(60).width == 64)
end

-- The centre link sits in the same column on regular and golden nav lines.
do
    local sim, dif = "<a href='x'>similar</a>", "<a href='y'>different</a>"
    local chrono = "<a href='z'>chronological</a>"
    local _, regular = visible(B.corner_box_nav_line(sim, dif, chrono, 40, "#74C0FC"))
    local _, golden = visible(B.golden_corner_box_nav_line(sim, dif, chrono, "#74C0FC"))
    local function column(t) local c = 0; for cp in t:gmatch("[\1-\127\194-\244][\128-\191]*") do if cp == "c" then return c end; c = c + 1 end end
    check("chronological starts in the same column on both", column(regular) == column(golden))
end

-- Golden bottom bar is 84 wide (╚ + 82 interior + ┘) with two junctions.
do
    local bar = B.progress_dashes({ percentage = 50 }, "blue", true, "bottom", true)
    local n, txt = visible(bar.visual)
    check("golden bottom bar is 84 wide", n == 84)
    -- Golden: left junction is double-up (╩/╨), right is single-up (╧/┴).
    check("golden bottom bar has 2 junctions",
        count(txt, "╩") + count(txt, "╨") + count(txt, "╧") + count(txt, "┴") == 2)
    check("golden left junction is double-up", count(txt, "╩") + count(txt, "╨") == 1)
end

-- Golden nav builders are 84 wide (golden poems carry two outer ║ walls).
do
    local sim, dif = "<a href='x'>similar</a>", "<a href='y'>different</a>"
    local chrono = "<a href='z'>chronological</a>"
    check("golden separator is 84 wide", visible(B.golden_corner_box_separator("#74C0FC")) == 84)
    check("golden nav line 84 with center", visible(B.golden_corner_box_nav_line(sim, dif, chrono, "#74C0FC")) == 84)
    check("golden nav line 84 without center", visible(B.golden_corner_box_nav_line(sim, dif, nil, "#74C0FC")) == 84)
end

-- Fill frontier: the similar box's RIGHT edge (col 10) is single until the
-- progress sweeps past it, then double. Left edge (frame) is always double.
do
    local sep_low = B.golden_corner_box_separator("#74C0FC", 4):gsub("<[^>]+>", "")
    check("low progress: right corner single (┐, no ╗)",
        sep_low:find("┐", 1, true) ~= nil and sep_low:find("╗", 1, true) == nil)
    check("low progress: left corner still double (╠)", sep_low:find("╠", 1, true) ~= nil)
    local sep_hi = B.golden_corner_box_separator("#74C0FC", 40):gsub("<[^>]+>", "")
    check("high progress: right corner double (╗)", sep_hi:find("╗", 1, true) ~= nil)
    local nav_low = B.golden_corner_box_nav_line("<a>similar</a>", "<a>different</a>", nil, "#74C0FC", 4):gsub("<[^>]+>", "")
    check("low progress: nav right wall single (║ similar │)", nav_low:find("║ similar │", 1, true) ~= nil)
end

-- Issue 8-045: the ends of the range draw; anything outside it is refused.
do
    local empty = B.progress_dashes({ percentage = 0 }, "gray", false, "top")
    check("0% top bar is 84 wide", visible(empty.visual) == 84)
    local full = B.progress_dashes({ percentage = 100 }, "gray", false, "top")
    check("100% top bar is 84 wide", visible(full.visual) == 84)
    local full_golden = B.progress_dashes({ percentage = 100 }, "gray", true, "top")
    check("100% golden top bar is 84 wide (82 cells + 2 corners)", visible(full_golden.visual) == 84)

    local ok, err = pcall(B.progress_dashes, { percentage = 117, poem_id = 7996 }, "gray", false, "top")
    check("117% is refused (messages/1514's bar ran 14 columns past its box)", not ok)
    check("the refusal names the poem", tostring(err):find("7996", 1, true) ~= nil)
    check("-5% is refused", not pcall(B.progress_dashes, { percentage = -5 }, "gray", false, "top"))
    check("a missing percentage is refused", not pcall(B.progress_dashes, {}, "gray", false, "top"))
    check("NaN is refused", not pcall(B.progress_dashes, { percentage = 0/0 }, "gray", false, "top"))
end

print(string.format("\npoem-bars: %d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
