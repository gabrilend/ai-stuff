#!/usr/bin/env lua
-- test_conversation-parser-session-title.lua
-- Validates issue #037's second question: a session the person renamed shows
-- that name on a "Title:" line in the transcript's header, and the title
-- Claude Code writes by itself from the first message does not.
--
-- WHY THIS MATTERS. A rename is the person naming the conversation in their
-- own words, so it is worth a line. The machine's title only describes how
-- the session opened, and these sessions change purpose as they go - the same
-- reason it was declined as a filename (issue 025).
--
-- Self-contained: writes fixture JSONL, runs the parser as a subprocess the
-- way the exporter does, and asserts on the markdown produced.
-- Run: `lua test_conversation-parser-session-title.lua [scripts-dir]`.

-- {{{ DIR + paths
local DIR = arg[1] or "/home/ritz/programming/ai-stuff/scripts"
local PARSER = DIR .. "/libs/conversation-parser.lua"
local TMP = os.getenv("TMPDIR") or "/tmp"
-- }}}

-- {{{ run_parser
-- Returns the markdown written and whether the parser exited cleanly.
local function run_parser(jsonl_text)
    local infile  = TMP .. "/title_fixture_in.jsonl"
    local outfile = TMP .. "/title_fixture_out.md"
    os.remove(outfile)
    local f = assert(io.open(infile, "w"))
    f:write(jsonl_text)
    f:close()
    local ok = os.execute(string.format("lua %q %q %q >/dev/null 2>&1",
        PARSER, infile, outfile))
    -- LuaJIT's os.execute returns a number, Lua 5.1's too; 0 is success.
    local clean = (ok == 0 or ok == true)
    local g = io.open(outfile, "r")
    if not g then return "", clean end
    local s = g:read("*all")
    g:close()
    return s, clean
end
-- }}}

local failures = 0
-- {{{ check
local function check(condition, description)
    if condition then
        print("  ok   - " .. description)
    else
        print("  FAIL - " .. description)
        failures = failures + 1
    end
end
-- }}}

-- {{{ fixtures
local function user(uuid, ts, text)
    return string.format('{"type":"user","uuid":"%s","timestamp":"%s","message":{"role":"user","content":"%s"}}', uuid, ts, text)
end
local function assistant(ts, text)
    return string.format('{"type":"assistant","timestamp":"%s","message":{"role":"assistant","model":"claude-opus-5-5","content":[{"type":"text","text":"%s"}]}}', ts, text)
end
local function ai_title(text)
    return string.format('{"type":"ai-title","aiTitle":"%s","sessionId":"s1"}', text)
end
local function custom_title(text)
    return string.format('{"type":"custom-title","customTitle":"%s","sessionId":"s1"}', text)
end
local function conversation(extra)
    local lines = {
        user("u1", "2026-09-23T22:30:00.000Z", "Review the README."),
        assistant("2026-09-23T22:30:05.000Z", "Reviewed."),
    }
    for _, line in ipairs(extra) do
        table.insert(lines, 1, line)
    end
    return table.concat(lines, "\n") .. "\n"
end

-- The header: everything above the first rule.
local function header_of(md)
    return md:match("^(.-)\n%-%-%-%-%-%-%-%-%-%-") or ""
end
-- }}}

print("session title")

local md, clean = run_parser(conversation({ custom_title("Menu viewport work"), ai_title("Review the README") }))
check(clean, "renamed: the parser exits cleanly")
check(header_of(md):find("\nTitle: Menu viewport work\n", 1, true) ~= nil,
    "renamed: the person's name is on a Title line in the header")
check(not header_of(md):find("Review the README", 1, true),
    "renamed: the machine's own title is not in the header")
check(md:match("^# Conversation Summary: ") ~= nil, "renamed: line 1 is still the identity header")
local models_at = header_of(md):find("\nModels: ", 1, true)
local title_at = header_of(md):find("\nTitle: ", 1, true)
check(models_at and title_at and title_at > models_at, "renamed: the Title line follows the Models line")
check(md:find("### User Request 1", 1, true) ~= nil, "renamed: the body is still written")

md, clean = run_parser(conversation({ custom_title("Second name"), custom_title("First name") }))
check(clean, "renamed twice: the parser exits cleanly")
check(header_of(md):find("\nTitle: Second name\n", 1, true) ~= nil
    and not md:find("First name", 1, true),
    "renamed twice: the later name wins, and only it is written")

md, clean = run_parser(conversation({ ai_title("Review the README") }))
check(clean, "machine title only: the parser exits cleanly")
check(not header_of(md):find("Title:", 1, true), "machine title only: no Title line")

md, clean = run_parser(conversation({}))
check(clean, "no title records: the parser exits cleanly")
check(not header_of(md):find("Title:", 1, true), "no title records: no Title line")

md, clean = run_parser(conversation({ '{"type":"custom-title","sessionId":"s1"}' }))
check(not clean, "a custom-title record without its text is reported, not guessed")

print("")
if failures == 0 then
    print("PASS: all checks passed")
    os.exit(0)
end
print("FAIL: " .. failures .. " check(s) failed")
os.exit(1)
