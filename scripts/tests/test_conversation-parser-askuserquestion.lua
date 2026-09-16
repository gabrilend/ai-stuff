#!/usr/bin/env lua
-- test_conversation-parser-askuserquestion.lua
-- Validates issue #019: the conversation parser rescues a question exchange -
-- the question, the options offered, what the user chose, and any note they
-- added - instead of dropping it with the rest of the tool stream, and leaves
-- sessions that never asked a question untouched.
--
-- WHY THE FIXTURES LOOK LIKE THIS. The harness records a question's outcome
-- twice: as an English sentence inside the tool result, and as structured data
-- on the message record under "toolUseResult". The parser used to read the
-- sentence, and lost answers in two ways that this file now pins down - an
-- answer with no quotes around it read as no answer at all, and an answer
-- containing a comma cut short at its own comma. It reads the structured copy
-- now, so both shapes survive, and so do the free-text notes that the sentence
-- never carried at all.
--
-- The fixtures therefore carry BOTH copies, exactly as a real log does, with
-- the sentence deliberately written in the shapes that used to defeat it. A
-- fixture carrying only the structured copy would pass without proving
-- anything.
--
-- Self-contained: it writes tiny fixture JSONL files, drives the parser the
-- same way the exporter does (as a subprocess: `lua parser in.jsonl out.md`),
-- and asserts on the produced markdown.
-- Run: `lua test_conversation-parser-askuserquestion.lua`.

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
    os.execute(string.format("lua %q %q %q >/dev/null 2>&1",
        PARSER, infile, outfile))
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

-- {{{ the fixtures
-- One user turn, an assistant asking three questions, and the result carrying
-- the outcomes. Each question is a shape that mattered:
--
--   Q1  answered by picking an option label -> must read as a Selection.
--   Q2  answered with free text CONTAINING A COMMA, and written into the
--       sentence unquoted, in the "(no option selected) notes:" form. Both
--       halves of that used to lose the answer. Also carries a note.
--   Q3  offered and never answered -> must say so rather than inventing one.
local ASKQ_FIXTURE = table.concat({
    '{"type":"user","message":{"role":"user","content":"Please decide."},"uuid":"u1","timestamp":"2026-07-07T00:00:00.000Z"}',
    '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"toolu_TEST","name":"AskUserQuestion","input":{"questions":[' ..
        '{"question":"Pick A?","header":"H1","multiSelect":false,"options":[{"label":"Option One","description":"first"},{"label":"Option Two","description":"second"}]},' ..
        '{"question":"Free?","header":"H2","multiSelect":false,"options":[{"label":"Yes","description":"y"},{"label":"No","description":"n"}]},' ..
        '{"question":"Skipped?","header":"H3","multiSelect":false,"options":[{"label":"Maybe","description":"m"}]}' ..
        ']}}]},"uuid":"a1","timestamp":"2026-07-07T00:01:00.000Z"}',
    '{"type":"user","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_TEST",' ..
        '"content":"Your questions have been answered: \\"Pick A?\\"=\\"Option Two\\", \\"Free?\\"=(no option selected) notes: my own words, with a comma. You can now continue with these answers in mind."}]},' ..
        '"toolUseResult":{"answers":{"Pick A?":"Option Two","Free?":"my own words, with a comma"},' ..
        '"annotations":{"Free?":{"notes":"because the options missed the point"}},' ..
        '"questions":[]},' ..
        '"uuid":"u2","timestamp":"2026-07-07T00:02:00.000Z"}',
}, "\n") .. "\n"

-- A control fixture with no question at all.
local PLAIN_FIXTURE = table.concat({
    '{"type":"user","message":{"role":"user","content":"hello there"},"uuid":"u1","timestamp":"2026-07-07T00:00:00.000Z"}',
    '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"general kenobi"}]},"uuid":"a1","timestamp":"2026-07-07T00:01:00.000Z"}',
}, "\n") .. "\n"
-- }}}

print("Question exchange rescue:")
local out = run_parser(ASKQ_FIXTURE)
check(out:find("%[Asked the user%]"), "renders an 'Asked the user' block")
check(out:find("Option One", 1, true) and out:find("Option Two", 1, true),
    "lists every option label")
check(out:find("first", 1, true) and out:find("second", 1, true),
    "includes option descriptions")
check(out:find("**Selected:** Option Two", 1, true),
    "marks a picked option as Selected")

print("The shapes the sentence-reading version lost:")
check(out:find("**Answered:** my own words, with a comma", 1, true),
    "recovers an UNQUOTED answer, which used to read as no answer at all")
check(out:find("with a comma", 1, true),
    "keeps the whole answer rather than stopping at its own comma")
check(out:find("**They added:** because the options missed the point", 1, true),
    "keeps the note the user typed alongside their pick")

print("Honesty about what was not answered:")
check(out:find("(no answer recorded)", 1, true),
    "says so for a question that was never answered")
check(not out:find("Selected:%*%* Maybe"),
    "does not invent an answer for it from the options offered")
check(not out:find("Selected:%*%* Yes") and not out:find("Selected:%*%* No"),
    "does not mislabel the free-text answer as one of the options")

print("No-question control:")
local plain = run_parser(PLAIN_FIXTURE)
check(not plain:find("Asked the user", 1, true),
    "leaves a plain session with no question block")
check(plain:find("general kenobi", 1, true),
    "still captures ordinary assistant prose")

print("")
if failures == 0 then
    print("PASS: all checks passed")
    os.exit(0)
else
    print("FAIL: " .. failures .. " check(s) failed")
    os.exit(1)
end
