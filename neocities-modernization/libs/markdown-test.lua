-- markdown-test.lua
-- Unit tests for libs/markdown.lua (Issue 10-055). Pure string-in/string-out, so
-- this runs standalone with no project setup and never touches output/. Run:
--   luajit libs/markdown-test.lua
-- Each case asserts that a Markdown snippet renders to HTML containing the
-- expected fragment(s); failures print the actual HTML so the gap is obvious.

-- {{{ setup_dir_path()
local function setup_dir_path(provided)
    if provided then return provided end
    return "/mnt/mtwo/programming/ai-stuff/neocities-modernization"
end
-- }}}

local DIR = setup_dir_path(arg and arg[1])
package.path = DIR .. "/libs/?.lua;" .. package.path
local md = require("markdown")

local passed, failed = 0, 0

-- {{{ local function check()
-- Render `src` and assert every fragment in `wants` appears in the output.
local function check(name, src, wants)
    local html = md.render(src)
    local missing = {}
    for _, want in ipairs(wants) do
        if not html:find(want, 1, true) then missing[#missing + 1] = want end
    end
    if #missing == 0 then
        passed = passed + 1
        print("  ok  " .. name)
    else
        failed = failed + 1
        print("FAIL  " .. name)
        for _, m in ipairs(missing) do print("        missing: " .. m) end
        print("        got: " .. html)
    end
end
-- }}}

-- {{{ local function check_absent()
-- Render `src` and assert none of the fragments in `nots` appear (used to prove
-- markup inside code is NOT re-interpreted).
local function check_absent(name, src, nots)
    local html = md.render(src)
    local present = {}
    for _, no in ipairs(nots) do
        if html:find(no, 1, true) then present[#present + 1] = no end
    end
    if #present == 0 then
        passed = passed + 1
        print("  ok  " .. name)
    else
        failed = failed + 1
        print("FAIL  " .. name)
        for _, p in ipairs(present) do print("        should be absent: " .. p) end
        print("        got: " .. html)
    end
end
-- }}}

print("markdown renderer tests")

check("h1", "# Title", { "<h1>Title</h1>" })
check("h3", "### Three", { "<h3>Three</h3>" })
check("bold", "a **bold** word", { "<strong>bold</strong>" })
check("italic star", "a *slanted* word", { "<em>slanted</em>" })
check("italic underscore", "an _emphatic_ word", { "<em>emphatic</em>" })
check("snake_case survives", "a snake_case_name here", { "snake_case_name" })
check("inline code", "use `luajit -b` here", { "<code>luajit -b</code>" })
check("link", "see [the docs](https://example.com/x)", {
    '<a href="https://example.com/x">the docs</a>' })
check("image", "![a cat](cat.png)", { '<img src="cat.png" alt="a cat">' })
check("unordered list", "- one\n- two", { "<ul>", "<li>one</li>", "<li>two</li>", "</ul>" })
check("ordered list", "1. first\n2. second", { "<ol>", "<li>first</li>", "<li>second</li>" })
check("blockquote", "> quoted line", { "<blockquote>", "quoted line", "</blockquote>" })
check("hr", "above\n\n---\n\nbelow", { "<hr>" })
check("paragraph", "just a sentence.", { "<p>just a sentence.</p>" })
check("fenced code", "```lua\nlocal x = 1\n```", {
    '<pre><code class="lang-lua">', "local x = 1", "</code></pre>" })
check("table", "| A | B |\n|---|---|\n| 1 | 2 |", {
    "<table>", "<th>A</th>", "<th>B</th>", "<td>1</td>", "<td>2</td>", "</table>" })
check("escaping", "a < b & c > d", { "a &lt; b &amp; c &gt; d" })
check("table alignment colons", "| L | R |\n|:--|--:|\n| a | b |", { "<th>L</th>", "<td>a</td>" })

-- Markup inside code/fences must NOT be reinterpreted.
check_absent("no emphasis in inline code", "`a*b*c`", { "<em>" })
check_absent("no emphasis in fence", "```\nx = a*b*c\n```", { "<em>" })
check_absent("html in code escaped", "`<script>`", { "<script>" })

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
