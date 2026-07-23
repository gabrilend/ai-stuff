#!/usr/bin/env lua
-- test_conversation-parser-askuserquestion.lua
-- Validates issue #019: the conversation parser rescues AskUserQuestion
-- exchanges (question, options, and the selected option OR a typed correction)
-- instead of dropping them with the rest of the tool stream, and leaves
-- sessions that never used AskUserQuestion untouched.
--
-- Self-contained: it writes tiny fixture JSONL files, drives the parser the
-- same way the exporter does (as a subprocess: `lua parser in.jsonl out.md`),
-- and asserts on the produced markdown. Run: `lua test_conversation-parser-askuserquestion.lua`.

-- {{{ DIR + paths
-- Hard-coded default root, overridable by argument, so the test runs from any
-- directory (house convention).
local DIR = arg[1] or "/home/ritz/programming/ai-stuff/scripts"
local PARSER = DIR .. "/libs/conversation-parser.lua"
local TMP = os.getenv("TMPDIR") or "/tmp"
-- }}}

-- {{{ write_file(path, text)
local function write_file(path, text)
    local f = assert(io.open(path, "w"))
    f:write(text)
    f:close()
end
-- }}}

-- {{{ read_file(path)
local function read_file(path)
    local f = assert(io.open(path, "r"))
    local s = f:read("*all")
    f:close()
    return s
end
-- }}}

-- {{{ run_parser(jsonl_text) -> markdown
-- Materialize a fixture, run the parser as a subprocess, return its output.
local function run_parser(jsonl_text)
    local infile  = TMP .. "/askq_fixture_in.jsonl"
    local outfile = TMP .. "/askq_fixture_out.md"
    write_file(infile, jsonl_text)
    os.execute(string.format("lua %q %q %q >/dev/null 2>&1", PARSER, infile, outfile))
    return read_file(outfile)
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

-- The fixture: one user turn, an assistant AskUserQuestion with two questions,
-- and the tool-result carrying the answers. Question 1 is answered by picking an
-- option label; question 2 is answered with free text that CONTAINS A COMMA, to
-- prove the anchor-based extraction is not fooled by commas inside answers.
local ASKQ_FIXTURE = table.concat({
    '{"type":"user","message":{"role":"user","content":"Please decide."},"uuid":"u1","timestamp":"2026-07-07T00:00:00.000Z"}',
    '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"toolu_TEST","name":"AskUserQuestion","input":{"questions":[' ..
        '{"question":"Pick A?","header":"H1","multiSelect":false,"options":[{"label":"Option One","description":"first"},{"label":"Option Two","description":"second"}]},' ..
        '{"question":"Free?","header":"H2","multiSelect":false,"options":[{"label":"Yes","description":"y"},{"label":"No","description":"n"}]}' ..
        ']}}]},"uuid":"a1","timestamp":"2026-07-07T00:01:00.000Z"}',
    '{"type":"user","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_TEST","content":"Your questions have been answered: \\"Pick A?\\"=\\"Option Two\\", \\"Free?\\"=\\"my own words, with a comma\\". You can now continue with these answers in mind."}]},"uuid":"u2","timestamp":"2026-07-07T00:02:00.000Z"}',
}, "\n") .. "\n"

-- A control fixture with no AskUserQuestion at all.
local PLAIN_FIXTURE = table.concat({
    '{"type":"user","message":{"role":"user","content":"hello there"},"uuid":"u1","timestamp":"2026-07-07T00:00:00.000Z"}',
    '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"general kenobi"}]},"uuid":"a1","timestamp":"2026-07-07T00:01:00.000Z"}',
}, "\n") .. "\n"

print("AskUserQuestion rescue:")
local out = run_parser(ASKQ_FIXTURE)
check(out:find("%[Asked the user%]"),          "renders an 'Asked the user' block")
check(out:find("Option One", 1, true) and out:find("Option Two", 1, true), "lists every option label")
check(out:find("first", 1, true) and out:find("second", 1, true), "includes option descriptions")
check(out:find("→ **Selected:** Option Two", 1, true),  "marks a picked option as Selected")
check(out:find("→ **Answered:** my own words, with a comma", 1, true),
                                                "extracts a comma-containing typed correction verbatim, marked Answered")
check(not out:find("Selected:%*%* Yes") and not out:find("Selected:%*%* No"),
                                                "does not mislabel the free-text answer as an option")

print("No-AskUserQuestion control:")
local plain = run_parser(PLAIN_FIXTURE)
check(not plain:find("Asked the user", 1, true), "leaves a plain session with no Q&A block")
check(plain:find("general kenobi", 1, true),     "still captures ordinary assistant prose")

print("")
if failures == 0 then
    print("PASS: all checks passed")
    os.exit(0)
else
    print("FAIL: " .. failures .. " check(s) failed")
    os.exit(1)
end
