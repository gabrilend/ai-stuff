-- Tests for boost-bars.lua. These guard the boost frame against the drift that
-- mangled it in three independent copies: misaligned walls (body ║ at col 0 but
-- top ╦ at col 2), the wrong bottom-bar junction columns (71 copied from the
-- golden layout instead of 67), and ▢ replacement chars from byte-slicing the
-- multibyte ═ in the [BOOST] bar.
--
-- The frame is ASYMMETRIC: left edge always double, right edge a FILL FRONTIER
-- (single ┐│┤┴ until the bar fills the far-right column, then double ╗║╣╩).
-- Run: luajit src/boost-bars.test.lua
package.path = "./src/?.lua;./libs/?.lua;" .. package.path
local B = require("boost-bars")
B.configure({ arrow = "#dc3c3c", outer_frame = "#74C0FC", inner_box = "#38D9A9" })

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; print("  FAIL: " .. name) end
end

-- Strip HTML, then count UTF-8 codepoints (box chars are 3 bytes each).
local function visible(s)
    local txt = s:gsub("<[^>]+>", "")
    local _, n = txt:gsub("[^\128-\191]", "")  -- non-continuation bytes = codepoints
    return n, txt
end
-- Count how many times a (literal) substring char appears.
local function count(s, ch)
    local _, n = s:gsub(ch, "")
    return n
end
-- Walk codepoints, return 0-indexed column of the Nth occurrence of any char in set.
local function columns_of(txt, set)
    local col, cols = 0, {}
    for cp in txt:gmatch("[\1-\127\194-\244][\128-\191]*") do
        if set[cp] then cols[#cols + 1] = col end
        col = col + 1
    end
    return cols
end

local SIM = "<a href='s'>similar</a>"
local DIF = "<a href='d'>different</a>"
local CHR = "<a href='c'>chronological</a>"

-- The body lines (cols 2..81 framed) are 82 wide; the top arrow ◀═ replaces the
-- 2-space indent (also 82); the bottom adds a trailing ─▶ (84).
for _, pct in ipairs({0, 0.01, 0.37, 0.5, 0.99, 1.0}) do
    local pc = math.floor(pct * 78)
    check("top_border 82 wide @ " .. pct, visible(B.top_border(pct)) == 82)
    check("inner_top 82 wide @ " .. pct, visible(B.inner_top(pc)) == 82)
    check("inner_bottom 82 wide @ " .. pct, visible(B.inner_bottom(pc)) == 82)
    check("content_line 82 wide @ " .. pct, visible(B.content_line("hello world", pc)) == 82)
    check("nav_separator 82 wide @ " .. pct, visible(B.nav_separator(pc)) == 82)
    check("nav_line(with chrono) 82 wide @ " .. pct, visible(B.nav_line(SIM, DIF, CHR, pc)) == 82)
    check("nav_line(no chrono) 82 wide @ " .. pct, visible(B.nav_line(SIM, DIF, nil, pc)) == 82)
    check("bottom_border 84 wide @ " .. pct, visible(B.bottom_border(pct)) == 84)
end

-- No U+FFFD / ▢ anywhere (the byte-slice corruption produced these).
for _, line in ipairs({
    B.top_border(0.4), B.inner_top(30), B.content_line("x", 30),
    B.nav_separator(30), B.nav_line(SIM, DIF, CHR, 30), B.bottom_border(0.4),
}) do
    check("no replacement char in line", not line:find("\239\191\189", 1, true) and not line:find("▢", 1, true))
end

-- Left edge is ALWAYS double (╦ top, ║ body/nav, ╠ sep, ╚ bottom).
do
    local _, top = visible(B.top_border(0.1))
    local _, sep = visible(B.nav_separator(5))
    local _, bot = visible(B.bottom_border(0.1))
    check("top-left is ╦", top:find("╦", 1, true) ~= nil)
    check("nav-sep-left is ╠", sep:find("╠", 1, true) ~= nil)
    check("bottom-left is ╚", bot:find("╚", 1, true) ~= nil)
end

-- Fill frontier: at LOW progress the right edge is single; at FULL it doubles.
do
    local _, top_lo = visible(B.top_border(0.1))
    local _, top_hi = visible(B.top_border(1.0))
    check("low progress: top-right single ┐ (no ╗)",
        top_lo:find("┐", 1, true) ~= nil and top_lo:find("╗", 1, true) == nil)
    check("full progress: top-right double ╗", top_hi:find("╗", 1, true) ~= nil)

    local _, body_lo = visible(B.content_line("x", 5))
    local _, body_hi = visible(B.content_line("x", 78))
    check("low progress: body-right single │ (no ║ on right)", body_lo:sub(-#"│") == "│")
    check("full progress: body-right double ║", body_hi:sub(-#"║") == "║")

    local _, sep_hi = visible(B.nav_separator(78))
    check("full progress: nav-sep-right double ╣", sep_hi:find("╣", 1, true) ~= nil)
    local _, bot_lo = visible(B.bottom_border(0.1))
    local _, bot_hi = visible(B.bottom_border(1.0))
    check("low progress: bottom-right single ┴ before arrow", bot_lo:find("┴─▶", 1, true) ~= nil)
    check("full progress: bottom-right double ╩ before arrow", bot_hi:find("╩─▶", 1, true) ~= nil)
end

-- Bottom-bar junctions sit at columns 12 and 69 (under the nav-box walls),
-- i.e. bar-index 10 and 67 -- NOT the golden layout's 71.
do
    local _, bot = visible(B.bottom_border(1.0))  -- fully filled -> junctions are ╧
    local cols = columns_of(bot, { ["╧"] = true, ["┴"] = true })
    -- cols[1..2] are the two junctions; the trailing ╩ corner is also ┴-family
    -- so filter to the two that fall at 12 and 69.
    local has12, has69 = false, false
    for _, c in ipairs(cols) do
        if c == 12 then has12 = true end
        if c == 69 then has69 = true end
    end
    check("bottom junctions at columns 12 and 69", has12 and has69)
end

-- Nav line: similar/different walls align with the separator corners (col 12/69).
do
    local _, sep = visible(B.nav_separator(5))
    local _, nav = visible(B.nav_line(SIM, DIF, CHR, 5))
    local sep_cols = columns_of(sep, { ["┐"] = true })   -- similar box right corner
    local nav_cols = columns_of(nav, { ["│"] = true })   -- green box walls
    check("separator similar-box corner at col 12", sep_cols[1] == 12)
    check("nav-line green walls at cols 12 and 69", nav_cols[1] == 12 and nav_cols[2] == 69)
end

-- format_boost assembles top + inner + content* + inner + nav + bottom.
do
    local frame = B.format_boost({ "line one", "line two" }, 0.5, SIM, DIF, CHR, true)
    local lines = {}
    for l in (frame .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = l end
    check("assembled frame has 8 lines (top+itop+2content+ibot+sep+nav+bottom)", #lines == 8)
    check("assembled first line is the top border", lines[1]:find("╦", 1, true) ~= nil)
    check("assembled last line is the bottom border", lines[#lines]:find("─▶", 1, true) ~= nil)
end

print(string.format("\nboost-bars: %d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
