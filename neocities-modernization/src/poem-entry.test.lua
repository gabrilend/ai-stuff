-- Tests for poem-entry.lua, the one drawer for a poem's entry (Issue 8-058).
-- Each case pins one decision that used to differ between page types:
-- emphasis styled with its marks kept, a line exactly 80 wide kept whole, a
-- content warning boxed wherever it falls, golden walls around an indented
-- line, pictures before the navigation boxes, screen-reader labels on bars.
-- Run: luajit src/poem-entry.test.lua [project-dir]

-- {{{ local function setup_path()
local function setup_path()
    local this = debug.getinfo(1, "S").source:sub(2)
    local src_dir = this:match("(.*/)") or "./"
    local project_dir = arg[1] or src_dir:gsub("src/$", "")
    package.path = project_dir .. "/src/?.lua;" .. project_dir .. "/libs/?.lua;" .. package.path
end
-- }}}

setup_path()
local E = require("poem-entry")

local passed, failed = 0, 0
-- {{{ local function check()
local function check(name, cond, detail)
    if cond then
        passed = passed + 1
        print("  ok   " .. name)
    else
        failed = failed + 1
        print("  FAIL " .. name .. (detail and ("  -- " .. detail) or ""))
    end
end
-- }}}

-- {{{ local function visible_width()
-- Columns a line takes on screen: tags removed, entities as one character,
-- one column per UTF-8 character.
local function visible_width(s)
    local txt = s:gsub("<[^>]+>", ""):gsub("&%a+;", "x"):gsub("&#%d+;", "x")
    local _, n = txt:gsub("[^\128-\191]", "")
    return n
end
-- }}}

-- {{{ local function lines_of()
local function lines_of(s)
    local out = {}
    for line in (s .. "\n"):gmatch("(.-)\n") do out[#out + 1] = line end
    return out
end
-- }}}

-- {{{ configure is required
do
    local ok = pcall(E.format_entry, { content = "x" }, {})
    check("drawing before configure is refused", not ok)
    local ok2 = pcall(E.configure, { palette = { gray = "#787878" } })
    check("configure without every setting is refused", not ok2)
end
-- }}}

E.configure({
    palette = { gray = "#787878", blue = "#3c78dc", yellow = "#c8b428" },
    boost_palette = { arrow = "#dc3c3c", outer_frame = "#3c78dc",
        inner_box = "#2aa198", content_text = "#c8b428" },
    text_width = 80,
})

local LINKS = {
    similar_link = "<a href='../similar/0007-01.html'>similar</a>",
    different_link = "<a href='../different/0007-01.html'>different</a>",
}
-- {{{ local function entry()
local function entry(color, pct, chrono)
    return { color_name = color, progress_pct = pct,
        similar_link = LINKS.similar_link, different_link = LINKS.different_link,
        chrono_link = chrono }
end
-- }}}

-- {{{ emphasis: styled, marks kept (Issue 4-003)
do
    local out = E.format_entry({ poem_index = 7, content = "I *love* the rain" },
        entry("blue", 40, false))
    check("emphasis is styled with its marks kept", out:find("%*<em>love</em>%*", 1) ~= nil, out)
    local plain = E.format_entry({ poem_index = 7, content = "2 * 3 * 4" }, entry("blue", 40, false))
    check("arithmetic is not emphasis", not plain:find("<em>"))
end
-- }}}

-- {{{ a line exactly 80 wide stays on one line
do
    local line80 = string.rep("word ", 15) .. "abcde"     -- 80 characters
    assert(#line80 == 80)
    local out = E.format_entry({ poem_index = 7, content = line80 }, entry("gray", 10, false))
    local found = false
    for _, l in ipairs(lines_of(out)) do
        if l == "  " .. line80 then found = true end
    end
    check("an 80-wide line is kept whole, after the 2-column indent", found)
end
-- }}}

-- {{{ a line's trailing spaces are dropped (owner, 2026-10-25)
do
    local line80 = string.rep("word ", 15) .. "abcde"     -- 80 characters
    local out = E.format_entry({ poem_index = 7, content = "@user-803 \n" .. line80 .. "   " },
        entry("gray", 10, false))
    local kept_short, kept_long, any_trailing = false, false, false
    for _, l in ipairs(lines_of(out)) do
        local plain = l:gsub("<[^>]+>", "")
        if plain == "  @user-803" then kept_short = true end
        if plain == "  " .. line80 then kept_long = true end
        if plain:find("[^%s] +$") and not plain:find("[│║┐┘┤]") then any_trailing = true end
    end
    check("a short line loses its trailing space", kept_short)
    check("an 80-wide line with spaces after it stays one 80-wide line", kept_long)
    check("no text line ends in a space", not any_trailing)
end
-- }}}

-- {{{ content warnings: the post's own, and one written partway down
do
    local out = E.format_entry({ poem_index = 7, content_warning = "loss & grief",
        content = "first line\nCW: a later warning\nlast line" }, entry("gray", 10, false))
    check("the post's warning is boxed", out:find("CW: loss &amp; grief", 1, true) ~= nil, out)
    -- the later warning sits on a box line (│ ... │), not as plain text
    local boxed = false
    for _, l in ipairs(lines_of(out)) do
        if l:find("CW: a later warning", 1, true) and l:find("│", 1, true) then boxed = true end
    end
    check("a warning partway down the poem is boxed where it stands", boxed, out)
end
-- }}}

-- {{{ golden poems: walls, width, indent kept, picture before the nav boxes
do
    local poem = { poem_index = 7, metadata = { is_golden_poem = true },
        content = "    an indented line\nplain",
        attachments = { { media_type = "image/png", relative_path = "files/a/b/abc.png",
            description = 'a "quoted"\nalt' } } }
    local out = E.format_entry(poem, entry("yellow", 60, "<a href='../chronological/01.html#poem-7'>chronological</a>"))
    local ls = lines_of(out)
    local walled, widths_ok, indent_kept = 0, true, false
    for _, l in ipairs(ls) do
        if l:find("║</b></font> ", 1, true) and l:sub(-3) == "│" then
            walled = walled + 1
            if visible_width(l) ~= 84 then widths_ok = false end
            if l:find("║</b></font>     an indented line", 1, true) then indent_kept = true end
        end
    end
    check("golden text lines are walled", walled >= 2, out)
    check("golden walled lines are 84 wide", widths_ok)
    check("a golden poem keeps an indented line's indent", indent_kept, out)
    local img_at, nav_at
    for i, l in ipairs(ls) do
        if l:find("<img ", 1, true) then img_at = i end
        if l:find("similar", 1, true) and l:find("different", 1, true) then nav_at = i end
    end
    check("a golden poem's picture comes before its nav boxes", img_at and nav_at and img_at < nav_at)
    check("picture alt text is one line with quotes escaped",
        out:find('alt="a &quot;quoted&quot; alt"', 1, true) ~= nil)
end
-- }}}

-- {{{ bars carry screen-reader labels; regular nav boxes; no trailing newline
do
    local out = E.format_entry({ poem_index = 7, content = "hello" }, entry("blue", 50, false))
    local ls = lines_of(out)
    check("the top bar carries a screen-reader label", ls[1]:find('aria-label="eighty dashes. blue."', 1, true) ~= nil)
    check("the bottom bar carries a screen-reader label", ls[#ls]:find('aria-label=', 1, true) ~= nil)
    check("the text has a 2-column indent", ls[2] == "  hello")
    check("the entry ends without a newline", out:sub(-1) ~= "\n")
    check("no chronological link on a chronological page", not out:find("chronological", 1, true))
end
-- }}}

-- {{{ boosts: the boost frame, text with emphasis
do
    local out = E.format_entry({ poem_index = 7, metadata = { is_boost = true },
        content = "shared *thing*" }, entry("gray", 30, false))
    -- each letter of the label carries its own colour tag, so read it untagged
    check("a boost draws the boost frame", out:gsub("<[^>]+>", ""):find("[BOOST]", 1, true) ~= nil)
    check("a boost's emphasis is styled", out:find("<em>thing</em>", 1, true) ~= nil)
    local blank = E.format_entry({ poem_index = 8, metadata = { is_boost = true,
        original_uri = "https://example.social/@a/1" }, content = "" }, entry("gray", 30, false))
    check("a boost with lost text names where it came from", blank:find("example.social", 1, true) ~= nil)
end
-- }}}

-- {{{ escaping: Windows line endings, and the post's own warning
do
    check("Windows line endings become plain newlines", E.escape_html("a\r\nb\rc") == "a\nb\nc")
    local out = E.format_entry({ poem_index = 7, content = "x", content_warning = "a => b <c>" },
        entry("gray", 10, false))
    check("the post's warning is escaped", out:find("a =&gt; b &lt;c&gt;", 1, true) ~= nil)
end
-- }}}

-- {{{ plain text for the exports (Issue 8-013)
do
    local function plain(poem, color, pct)
        local e = entry(color, pct, false)
        e.plain = true
        return E.format_entry(poem, e)
    end
    local function widest(s)
        local w = 0
        for _, l in ipairs(lines_of(s)) do w = math.max(w, visible_width(l)) end
        return w
    end
    local golden = plain({ poem_index = 9, metadata = { is_golden_poem = true },
        content = "a & b < c, *soft*", content_warning = "grief",
        attachments = { { media_type = "image/png", relative_path = "x/a.png", description = 'a "big" sky' } } },
        "yellow", 60)
    check("plain text holds no tags", not golden:find("<[%a/]"))
    check("plain text holds no entities", not golden:find("&%a+;") and not golden:find("&#%d+;"))
    check("entities become their characters", golden:find("a & b < c", 1, true) ~= nil)
    check("emphasis keeps its marks as text", golden:find("*soft*", 1, true) ~= nil)
    check("a picture becomes its description", golden:find('[Image: a "big" sky]', 1, true) ~= nil, golden)
    check("the golden walls stay", golden:find("║", 1, true) ~= nil and golden:find("│", 1, true) ~= nil)
    check("no navigation boxes in plain text", not golden:find("similar", 1, true) and not golden:find("different", 1, true))
    check("plain golden lines are at most 84 wide", widest(golden) <= 84, tostring(widest(golden)))
    local ls = lines_of(golden)
    -- (each junction looked for whole: a Lua [set] matches single bytes, and
    -- these characters share bytes with ═)
    local bottom_line = ls[#ls]
    check("the golden bottom is the plain one (no box junctions)",
        not bottom_line:find("╩", 1, true) and not bottom_line:find("╧", 1, true)
        and not bottom_line:find("┴", 1, true), bottom_line)
    local regular = plain({ poem_index = 9, content = "hello" }, "blue", 30)
    check("a regular entry keeps its bars", lines_of(regular)[1]:find("═", 1, true) ~= nil)
    check("a regular entry's text is indented as on a page", lines_of(regular)[2] == "  hello")
    local boost = plain({ poem_index = 9, metadata = { is_boost = true }, content = "shared" }, "gray", 30)
    check("a boost keeps its frame in plain text", boost:find("[BOOST]", 1, true) ~= nil and not boost:find("similar", 1, true))
    check("a code point becomes UTF-8", E.utf8_char(0x1F5BC) == "\240\159\150\188")
    -- a description quoting code: "<stdio.h>" must count its columns
    local code = plain({ poem_index = 9, content = "x", attachments = { { media_type = "image/png",
        relative_path = "x/c.png", description = string.rep("lines of C code here ", 3)
            .. "#include <stdio.h> int main(void) { return 0; }" } } }, "gray", 10)
    check("a description quoting <code> wraps inside the frame", widest(code) <= 84, tostring(widest(code)))
    check("the quoted code reads as written", code:find("<stdio.h>", 1, true) ~= nil)
end
-- }}}

-- {{{ an unknown colour is an error, not grey
do
    local ok = pcall(E.format_entry, { poem_index = 7, content = "x" }, entry("teal", 10, false))
    check("an unknown colour is refused", not ok)
end
-- }}}

-- {{{ a golden poem's right wall stays put on a line with an emoji
do
    local out = E.format_entry({ poem_index = 7, content = "sun 😀 and moon", metadata = { is_golden_poem = true } },
        entry("gray", 10, false))
    local walled
    for _, l in ipairs(lines_of(out)) do if l:find("moon", 1, true) then walled = l end end
    local tf = require("text-formatter")
    check("the emoji is boxed in the poem's line", walled and walled:find('<span class="e">😀</span>', 1, true) ~= nil)
    check("and the line is still the frame's 84 columns", walled and tf.calculate_visible_width(walled) == 84)
end
-- }}}

-- {{{ regular and golden text start in the same column (owner, 2026-10-25)
do
    local function text_column(out, word)
        for _, l in ipairs(lines_of(out)) do
            local plain = l:gsub("<[^>]+>", "")
            local at = plain:find(word, 1, true)
            if at then
                local col = 0
                for _ in plain:sub(1, at - 1):gmatch("[%z\1-\127\194-\244][\128-\191]*") do col = col + 1 end
                return col
            end
        end
    end
    local regular = E.format_entry({ poem_index = 7, content = "alignment" }, entry("gray", 10, false))
    local golden = E.format_entry({ poem_index = 7, content = "alignment", metadata = { is_golden_poem = true } },
        entry("gray", 10, false))
    check("a regular poem's text starts in the golden poem's column",
        text_column(regular, "alignment") ~= nil and text_column(regular, "alignment") == text_column(golden, "alignment"))
end
-- }}}

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
