#!/usr/bin/env lua
-- test_conversation-parser-narration-and-models.lua
-- Validates issues #023 and #028: the transcript says which model wrote what,
-- and tells the running commentary written while work was underway apart from
-- the considered answer at the end.
--
-- WHY THESE TWO TOGETHER. They are the same seam. Between two user turns the
-- model usually speaks several times - saying what it is about to do, reporting
-- what it found, then answering - and it can change model partway. Both facts
-- live in the same list of accumulated blocks, and both are lost by the same
-- mistake: joining those blocks into one lump. Testing them apart would let a
-- fix for one quietly undo the other.
--
-- Self-contained: writes a fixture JSONL, runs the parser as a subprocess the
-- way the exporter does, and asserts on the markdown produced.
-- Run: `lua test_conversation-parser-narration-and-models.lua`.

-- {{{ DIR + paths
local DIR = arg[1] or "/home/ritz/programming/ai-stuff/scripts"
local PARSER = DIR .. "/libs/conversation-parser.lua"
local TMP = os.getenv("TMPDIR") or "/tmp"
-- }}}

-- {{{ run_parser(jsonl_text) -> markdown
local function run_parser(jsonl_text)
    local infile  = TMP .. "/narration_fixture_in.jsonl"
    local outfile = TMP .. "/narration_fixture_out.md"
    local f = assert(io.open(infile, "w"))
    f:write(jsonl_text)
    f:close()
    os.execute(string.format("lua %q %q %q >/dev/null 2>&1",
        PARSER, infile, outfile))
    local g = assert(io.open(outfile, "r"))
    local s = g:read("*all")
    g:close()
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

-- {{{ line_holding(text, needle) -> the whole line containing needle
-- The assertions care where a line STARTS as much as what it says, since the
-- quote marker is a prefix, so they need the line rather than a substring hit.
local function line_holding(text, needle)
    for line in text:gmatch("[^\n]*") do
        if line:find(needle, 1, true) then return line end
    end
    return nil
end
-- }}}

-- {{{ the fixture
-- Turn one: three blocks from one model, so the first two are narration and
-- the third is the answer. Turn two: a single block from a DIFFERENT model, so
-- it is an answer rather than narration and a change has to be marked. Then a
-- notice the harness files under a placeholder model, which is neither.
local FIXTURE = table.concat({
    '{"type":"user","uuid":"u1","timestamp":"2026-07-07T00:00:00.000Z","message":{"role":"user","content":"first question"}}',
    '{"type":"assistant","uuid":"a1","timestamp":"2026-07-07T00:00:01.000Z","message":{"role":"assistant","model":"claude-alpha","content":[{"type":"text","text":"NARRATION ONE said before the work"}]}}',
    '{"type":"assistant","uuid":"a2","timestamp":"2026-07-07T00:00:02.000Z","message":{"role":"assistant","model":"claude-alpha","content":[{"type":"text","text":"NARRATION TWO said during the work"}]}}',
    '{"type":"assistant","uuid":"a3","timestamp":"2026-07-07T00:00:03.000Z","message":{"role":"assistant","model":"claude-alpha","content":[{"type":"text","text":"THE SETTLED ANSWER said after the work"}]}}',
    '{"type":"user","uuid":"u2","timestamp":"2026-07-07T00:00:04.000Z","message":{"role":"user","content":"second question"}}',
    '{"type":"assistant","uuid":"a4","timestamp":"2026-07-07T00:00:05.000Z","message":{"role":"assistant","model":"claude-beta","content":[{"type":"text","text":"LONE BLOCK and therefore an answer"}]}}',
    '{"type":"assistant","uuid":"a5","timestamp":"2026-07-07T00:00:06.000Z","message":{"role":"assistant","model":"<synthetic>","content":[{"type":"text","text":"HARNESS NOTICE about a session limit"}]}}',
}, "\n") .. "\n"
-- }}}

local out = run_parser(FIXTURE)

print("Narration is marked, the answer is not (issue 028):")
local n1 = line_holding(out, "NARRATION ONE")
local n2 = line_holding(out, "NARRATION TWO")
local ans = line_holding(out, "THE SETTLED ANSWER")
check(n1 and n1:sub(1, 1) == ">", "the first block is marked as narration")
check(n2 and n2:sub(1, 1) == ">", "the middle block is marked as narration")
check(ans and ans:sub(1, 1) ~= ">", "the last block is left plain as the answer")
check(ans and ans:sub(1, 1) ~= " ",
    "...and starts at the left margin, carrying no padding")

print("A turn with only one block is an answer, not narration:")
local lone = line_holding(out, "LONE BLOCK")
check(lone and lone:sub(1, 1) ~= ">",
    "a single block is not marked, since the session drew no distinction")

print("Blocks stay apart rather than being joined:")
check(n1 ~= n2, "two blocks do not end up on the same line as each other")

print("Which model wrote what (issue 023):")
check(out:find("Models: claude%-alpha, claude%-beta"),
    "the header lists both models in first-appearance order")
check(not out:find("synthetic", 1, true),
    "the harness placeholder is not listed as a model that served a reply")
check(out:find("*model: claude-beta*", 1, true),
    "a change of model is marked inline where it happened")
check(not out:find("*model: claude-alpha*", 1, true),
    "the opening model is not re-announced inline; the header already has it")

print("A harness notice is neither speaker:")
local notice = line_holding(out, "HARNESS NOTICE")
check(notice ~= nil, "the notice is kept rather than dropped")
check(notice and notice:sub(1, 1) ~= ">",
    "it is not mistaken for narration")
-- "Outside a response block" means a horizontal rule closed the last
-- response before this line arrived. Written as two positions rather than
-- as one pattern because Lua patterns match newlines, so a lazy ".-" between
-- a heading and this text spans whole sections and always finds a match.
local notice_at = out:find("HARNESS NOTICE", 1, true)
local heading_at, rule_at = nil, nil
for pos in out:gmatch("()### Assistant Response") do
    if pos < notice_at then heading_at = pos end
end
for pos in out:gmatch("()\n%-%-%-%-") do
    if pos < notice_at then rule_at = pos end
end
check(heading_at and rule_at and rule_at > heading_at,
    "it sits outside the response block, not inside it")

print("")
if failures == 0 then
    print("PASS: all checks passed")
    os.exit(0)
else
    print("FAIL: " .. failures .. " check(s) failed")
    os.exit(1)
end
