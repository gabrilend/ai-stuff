#!/usr/bin/env lua
-- test_conversation-parser-pictures.lua
-- Validates scripts issue A10's middle part: when the agent looks at
-- something with see-in-3d, the transcript shows the picture it kept, in the
-- reply where it was made, between the words before and after -- and nothing
-- that only looks like a kept picture.
--
-- WHY THIS MATTERS. A reader of the story should see what the agent saw at
-- the moment it decided what it decided. A picture in the wrong reply, or a
-- picture invented from a log search that merely quoted the line, would tell
-- the story wrong.
--
-- Run: `lua test_conversation-parser-pictures.lua [scripts-dir]`.

-- {{{ DIR + paths
local DIR = arg[1] or "/home/ritz/programming/ai-stuff/scripts"
local PARSER = DIR .. "/libs/conversation-parser.lua"
local TMP = os.getenv("TMPDIR") or "/tmp"
-- }}}

-- {{{ run_parser
local function run_parser(jsonl_text)
    local infile  = TMP .. "/pictures_fixture_in.jsonl"
    local outfile = TMP .. "/pictures_fixture_out.md"
    os.remove(outfile)
    local f = assert(io.open(infile, "w"))
    f:write(jsonl_text)
    f:close()
    os.execute(string.format("lua %q %q %q >/dev/null 2>&1", PARSER, infile, outfile))
    local g = io.open(outfile, "r")
    if not g then return "" end
    local s = g:read("*all")
    g:close()
    return s
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

-- {{{ fixture builders
local function js(text)
    return '"' .. text:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n") .. '"'
end
local function user(uuid, text)
    return string.format('{"type":"user","uuid":"%s","timestamp":"2026-10-10T10:00:00.000Z","message":{"role":"user","content":%s}}', uuid, js(text))
end
local function said(text)
    return string.format('{"type":"assistant","timestamp":"2026-10-10T10:00:01.000Z","message":{"role":"assistant","model":"m","content":[{"type":"text","text":%s}]}}', js(text))
end
local function ran(id, command)
    return string.format('{"type":"assistant","timestamp":"2026-10-10T10:00:02.000Z","message":{"role":"assistant","model":"m","content":[{"type":"tool_use","id":"%s","name":"Bash","input":{"command":%s}}]}}', id, js(command))
end
local function output(id, stdout)
    return string.format('{"type":"user","timestamp":"2026-10-10T10:00:03.000Z","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"%s","content":"x"}]},"toolUseResult":{"stdout":%s,"stderr":""}}', id, js(stdout))
end
-- }}}

local md = run_parser(table.concat({
    user("u1", "What does the desk look like from the side?"),
    said("Rendering the desk from four sides."),
    ran("t1", "/home/ritz/programming/ai-stuff/scripts/see-in-3d render /tmp/desk.lua"),
    output("t1", "a desk with a lamp: 7 shapes, 804 triangles\n  sheet (front, right / top, angle): /tmp/desk.png\n" ..
        "see-in-3d: kept /p/mind/imagination-portraits/2026-10-10-100002-desk-views/views.jpg | a desk with a lamp [and a mug] -- front, right / top, angle"),
    ran("t2", "grep -h 'see-in-3d: kept' ~/.claude/projects/*/*.jsonl"),
    output("t2", "see-in-3d: kept /p/mind/imagination-portraits/old/views.jpg | an old picture"),
    said("From the side the legs are too short."),
}, "\n") .. "\n")

local picture = "![a desk with a lamp and a mug -- front, right / top, angle](/p/mind/imagination-portraits/2026-10-10-100002-desk-views/views.jpg)"
local at_picture = md:find(picture, 1, true)
check(at_picture ~= nil, "a kept picture becomes a markdown picture line, square brackets taken out of its caption")
check(md:find("old/views.jpg", 1, true) == nil, "a search that PRINTS a kept line is not a picture")
local before = md:find("Rendering the desk", 1, true)
local after = md:find("legs are too short", 1, true)
check(before and at_picture and after and before < at_picture and at_picture < after,
    "the picture sits between the words before the render and the words after it")

print(failures == 0 and "all passed" or (failures .. " failed"))
os.exit(failures == 0 and 0 or 1)
