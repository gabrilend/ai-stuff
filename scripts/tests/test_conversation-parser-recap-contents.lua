#!/usr/bin/env lua
-- test_conversation-parser-recap-contents.lua
-- Validates issue #037: the recaps Claude Code writes while the person is
-- away are listed, in order, in a Contents section at the top of the
-- transcript - each with its local time, the request it follows, and its
-- prose without the "(disable recaps in /config)" boilerplate.
--
-- WHY THIS MATTERS. Read in order, the recaps are a running summary of how a
-- conversation went, and they were being dropped entirely: the parser only
-- read user and assistant records.
--
-- Self-contained: writes fixture JSONL, runs the parser as a subprocess the
-- way the exporter does, and asserts on the markdown produced.
-- Run: `lua test_conversation-parser-recap-contents.lua [scripts-dir]`.

-- {{{ DIR + paths
local DIR = arg[1] or "/home/ritz/programming/ai-stuff/scripts"
local PARSER = DIR .. "/libs/conversation-parser.lua"
local TMP = os.getenv("TMPDIR") or "/tmp"
-- }}}

-- {{{ run_parser
-- Returns the markdown written and whether the parser exited cleanly.
local function run_parser(jsonl_text)
    local infile  = TMP .. "/recap_fixture_in.jsonl"
    local outfile = TMP .. "/recap_fixture_out.md"
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
    return string.format('{"type":"assistant","timestamp":"%s","message":{"role":"assistant","content":[{"type":"text","text":"%s"}]}}', ts, text)
end
local function recap(ts, text)
    return string.format('{"type":"system","subtype":"away_summary","timestamp":"%s","content":"%s (disable recaps in /config)"}', ts, text)
end

-- One recap before any request (a resumed session can do that), one after
-- the first answer, one after the second.
local WITH_RECAPS = table.concat({
    recap("2026-09-23T22:00:00.000Z", "Nothing has happened yet."),
    user("u1", "2026-09-23T22:30:00.000Z", "Review the README."),
    assistant("2026-09-23T22:30:05.000Z", "Reviewed."),
    recap("2026-09-23T22:40:45.000Z", "I reviewed the README. Next, I need your answer on the new folder."),
    user("u2", "2026-09-23T23:00:00.000Z", "It counts."),
    assistant("2026-09-23T23:00:05.000Z", "Figures updated."),
    recap("2026-09-23T23:33:48.000Z", "I updated the figures."),
}, "\n") .. "\n"

local WITHOUT_RECAPS = table.concat({
    user("u1", "2026-09-23T22:30:00.000Z", "Review the README."),
    assistant("2026-09-23T22:30:05.000Z", "Reviewed."),
}, "\n") .. "\n"
-- }}}

print("recap contents")

local md, clean = run_parser(WITH_RECAPS)
check(clean, "the parser exits cleanly")
check(md:match("^# Conversation Summary: ") ~= nil, "line 1 is still the identity header")

-- The times are written in local time; work out what this machine's clock
-- calls those instants rather than assuming a timezone.
local t2 = os.date("%Y-%m-%d %H:%M", 1790203245)
local t3 = os.date("%Y-%m-%d %H:%M", 1790206428)

local contents = md:match("## Contents\n\n(.-)\n\n%-%-%-%-")
check(contents ~= nil, "a Contents section sits between the header and the first rule")
contents = contents or ""
local flat = contents:gsub("\n%s*", " ")
check(flat:find("1. [%d-]+ [%d:]+, before Request 1 %- Nothing has happened yet%.") ~= nil,
    "a recap before any request says 'before Request 1'")
check(flat:find("2. " .. t2 .. ", after Request 1 - I reviewed the README. Next, I need your answer on the new folder.", 1, true) ~= nil,
    "the second recap has its local time, follows Request 1, and keeps its prose")
check(flat:find("3. " .. t3 .. ", after Request 2 - I updated the figures.", 1, true) ~= nil,
    "the third recap follows Request 2")
check(not md:find("disable recaps", 1, true), "the '(disable recaps in /config)' boilerplate is gone")
check(select(2, md:gsub("I updated the figures", "")) == 1, "the recap is listed once, not repeated in the body")
check(md:find("### User Request 2", 1, true) ~= nil, "the body is still written after the contents")

md, clean = run_parser(WITHOUT_RECAPS)
check(clean, "without recaps: the parser exits cleanly")
check(not md:find("## Contents", 1, true), "without recaps: no Contents heading is written")
check(md:find("### User Request 1", 1, true) ~= nil, "without recaps: the body is written")

print("")
if failures == 0 then
    print("PASS: all checks passed")
    os.exit(0)
end
print("FAIL: " .. failures .. " check(s) failed")
os.exit(1)
