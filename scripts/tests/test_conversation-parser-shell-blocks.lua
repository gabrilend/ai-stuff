#!/usr/bin/env lua
-- test_conversation-parser-shell-blocks.lua
-- Validates issue #031: a command the person ran from Claude Code's shell
-- prompt, and what it printed, reach the transcript as a command and its
-- output rather than as raw <bash-input> / <bash-stdout> tags under the
-- person's name.
--
-- The shapes that are easy to get wrong, each built into the fixture below:
-- a command that printed nothing at all, a command that wrote only to the
-- error stream, output that contains the harness's own tag names as text, and
-- output read from a markdown file, whose ``` lines would otherwise end the
-- block they sit in. Then the site's markdown reader is handed the result to
-- show the block survives being drawn as a page.
--
-- Self-contained: writes a fixture JSONL, runs the parser as a subprocess the
-- way the exporter does, and asserts on the markdown produced.
-- Run: `lua test_conversation-parser-shell-blocks.lua [scripts-dir]`.

-- {{{ DIR + paths
local DIR = arg[1] or "/home/ritz/programming/ai-stuff/scripts"
local PARSER = DIR .. "/libs/conversation-parser.lua"
local MARKDOWN = DIR .. "/transcript-site/libs/markdown.lua"
local TMP = os.getenv("TMPDIR") or "/tmp"
-- }}}

-- {{{ run_parser(jsonl_text) -> markdown
local function run_parser(jsonl_text)
    local infile  = TMP .. "/shell_blocks_fixture_in.jsonl"
    local outfile = TMP .. "/shell_blocks_fixture_out.md"
    local f = assert(io.open(infile, "w"))
    f:write(jsonl_text)
    f:close()
    os.execute(string.format("lua %q %q %q >/dev/null 2>&1",
        PARSER, infile, outfile))
    local g = assert(io.open(outfile, "r"))
    local s = g:read("*all")
    g:close()
    os.remove(infile)
    os.remove(outfile)
    return s
end
-- }}}

local failures = 0
-- {{{ check(condition, description)
local function check(condition, description)
    if condition then
        print("  ok   - " .. description)
    else
        print("  FAIL - " .. description)
        failures = failures + 1
    end
end
-- }}}

-- {{{ json_string(s) -> a JSON string literal
-- The fixture's contents are easier to read as Lua strings than as
-- hand-escaped JSON, so they are escaped here.
local function json_string(s)
    s = s:gsub('[%c"\\]', function(c)
        if c == '"' then return '\\"' end
        if c == "\\" then return "\\\\" end
        if c == "\n" then return "\\n" end
        return string.format("\\u%04x", c:byte())
    end)
    return '"' .. s .. '"'
end
-- }}}

-- {{{ user_line(uuid, second, text) / assistant_line(uuid, second, text)
local function user_line(uuid, second, text)
    return string.format('{"type":"user","uuid":"%s","timestamp":"2026-07-07T00:00:%02d.000Z","message":{"role":"user","content":%s}}',
        uuid, second, json_string(text))
end
local function assistant_line(uuid, second, text)
    return string.format('{"type":"assistant","uuid":"%s","timestamp":"2026-07-07T00:00:%02d.000Z","message":{"role":"assistant","model":"claude-test-1","content":[{"type":"text","text":%s}]}}',
        uuid, second, json_string(text))
end
-- }}}

-- {{{ the fixture
-- Output that holds the harness's own tags as text: what printing a session
-- log with cat looks like, closing tags included.
local TAGGY = 'line one <bash-stderr>oops</bash-stderr>\n' ..
    '</bash-stdout><bash-stderr></bash-stderr> was in the log too'

-- Output read from a markdown file: three-backtick lines of its own.
local MARKDOWNY = '# notes\n```lua\nprint("hi")\n```\nafter the block'

local FIXTURE = table.concat({
    user_line("u1", 1, "my first real question"),
    assistant_line("a1", 2, "an answer"),
    -- the developer's example from the issue: pwd and its output
    user_line("s1", 3, "<bash-input>pwd</bash-input>"),
    user_line("s2", 4, "<bash-stdout>/home/ritz/games/tq</bash-stdout><bash-stderr></bash-stderr>"),
    -- a command that printed nothing at all
    user_line("s3", 5, "<bash-input>true</bash-input>"),
    user_line("s4", 6, "<bash-stdout></bash-stdout><bash-stderr></bash-stderr>"),
    -- a command that wrote only to the error stream, whose own text carries
    -- quotes and angle brackets that must not be re-read
    user_line("s5", 7, '<bash-input>ls "<nowhere>" 2>&1 >/dev/null</bash-input>'),
    user_line("s6", 8, "<bash-stdout></bash-stdout><bash-stderr>ls: cannot access '<nowhere>': No such file or directory</bash-stderr>"),
    -- output holding the harness's tag names as text
    user_line("s7", 9, "<bash-input>cat session.log</bash-input>"),
    user_line("s8", 10, "<bash-stdout>" .. TAGGY .. "</bash-stdout><bash-stderr></bash-stderr>"),
    -- output with its own fences, and a command holding a backtick
    user_line("s9", 11, "<bash-input>cat notes.md # see `notes`</bash-input>"),
    user_line("s10", 12, "<bash-stdout>" .. MARKDOWNY .. "</bash-stdout><bash-stderr></bash-stderr>"),
    user_line("u2", 13, "my second real question"),
    assistant_line("a2", 14, "a second answer"),
}, "\n") .. "\n"
-- }}}

local out = run_parser(FIXTURE)

print("No raw tags reach the page:")
check(not out:find("<bash%-input>"), "no <bash-input> tag")
check(not out:find("^<bash%-stdout>") and not out:find("\n<bash%-stdout>"),
    "no line opens with a <bash-stdout> tag")
local _, pairs_left = out:gsub("<bash%-stderr></bash%-stderr>", "")
check(pairs_left == 1,
    "every empty stderr pair is gone; the one left is text inside the cat output")

print("A command reads as a command that was run:")
check(out:find("`pwd` *(shell)*", 1, true), "pwd is a marked command line")
check(out:find("`pwd` *(shell)*\n\n```\n/home/ritz/games/tq\n```\n", 1, true),
    "its output is a block directly under it")

print("An empty stream emits nothing:")
check(out:find("`true` *(shell)*\n\n" .. string.rep("-", 80), 1, true),
    "a command that printed nothing is the command line alone")
check(not out:find("```\n```", 1, true), "no empty block anywhere")

print("Standard error is marked; the command is shown as typed:")
check(out:find('`ls "<nowhere>" 2>&1 >/dev/null` *(shell)*', 1, true),
    "quotes and angle brackets in the command are untouched")
check(out:find("*standard error:*\n\n```\nls: cannot access '<nowhere>'", 1, true),
    "stderr-only output is a block marked as the error stream")
check(not out:find("(shell)*\n\n```\n\n", 1, true),
    "no empty stdout block stands in front of it")

print("Output holding the harness's own tags is kept whole:")
check(out:find(TAGGY, 1, true), "the cat output arrives byte for byte")

print("Output with its own fences stays inside its block:")
check(out:find("*(shell)*\n\n```sh\ncat notes.md # see `notes`\n```", 1, true),
    "a command with a backtick goes in a block instead of inline code")
check(out:find("````\n" .. MARKDOWNY .. "\n````", 1, true),
    "the output's fence is longer than any it contains")

print("Shell traffic takes no number in the person's sequence:")
check(out:find("### User Request 1\n\nmy first real question", 1, true),
    "the first question is request 1")
check(out:find("### User Request 2\n\nmy second real question", 1, true),
    "the second question is request 2, not request 7")
check(not out:find("### User Request 3", 1, true), "there is no request 3")

print("The order of the page follows the order of the log:")
local at_answer = out:find("an answer", 1, true) or math.huge
local at_pwd = out:find("`pwd` *(shell)*", 1, true) or 0
local at_second = out:find("my second real question", 1, true) or 0
check(at_answer < at_pwd and at_pwd < at_second,
    "the commands sit between the answer and the next question")

print("The site's markdown reader keeps a long fence closed only by its own kind:")
local md = dofile(MARKDOWN)
local html = md.render("````\n```lua\nprint(1)\n```\n````\nafter")
check(html:find("```lua", 1, true) ~= nil and html:find("<p>after</p>", 1, true) ~= nil,
    "inner ``` lines are code, and the paragraph after is prose")

print("")
if failures == 0 then
    print("PASS: all checks passed")
    os.exit(0)
else
    print("FAIL: " .. failures .. " check(s) failed")
    os.exit(1)
end
