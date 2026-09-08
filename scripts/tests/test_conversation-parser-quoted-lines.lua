#!/usr/bin/env lua
-- test_conversation-parser-quoted-lines.lua
-- Validates issue #026: a line the user pasted back from the assistant's own
-- earlier answer is rendered as a blockquote, while the user's own words are
-- left alone. Also guards the line-splitter fix that came with it, which
-- stopped the wrapper emitting a phantom blank line after every source line.
--
-- Self-contained: it writes tiny fixture JSONL files, drives the parser the
-- same way the exporter does (as a subprocess: `lua parser in.jsonl out.md`),
-- and asserts on the produced markdown.
-- Run: `lua test_conversation-parser-quoted-lines.lua`.

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
local function run_parser(jsonl_text)
    local infile  = TMP .. "/quoted_fixture_in.jsonl"
    local outfile = TMP .. "/quoted_fixture_out.md"
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

-- The fixture reproduces every way a real paste differs from its source.
--
-- The assistant's answer carries **bold** markers and `backticks`, which the
-- terminal draws away, so the pasted copy has neither - this is the single
-- biggest cause of missed matches and the reason the comparison happens on a
-- reduced form rather than the raw text.
--
-- The user's reply then contains, in order:
--   1. two rows of that answer, broken where the terminal pane ended and
--      carrying its two-space left margin, the second row far too short to be
--      trusted on its own - it is kept only because the row above it is;
--   2. a short generic phrase that also appears inside the assistant's answer
--      purely by coincidence, sitting alone, which must NOT be marked;
--   3. the user's own question.
local QUOTE_FIXTURE = table.concat({
    '{"type":"user","message":{"role":"user","content":"how are the fonts installed?"},"uuid":"u1","timestamp":"2026-07-07T00:00:00.000Z"}',
    '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"**The fonts live in `fonts/` at the project root**, not `assets/fonts/` — assets is gitignored as a build product, and the fonts are an authored input. That is the whole reason."}]},"uuid":"a1","timestamp":"2026-07-07T00:01:00.000Z"}',
    '{"type":"user","message":{"role":"user","content":"  The fonts live in fonts/ at the project root, not assets/fonts/ — assets is gitignored as a build product, and the fonts are an authored input.\\n  That is the whole reason.\\n\\nthe whole reason\\n\\nokay but who creates that directory?"},"uuid":"u2","timestamp":"2026-07-07T00:02:00.000Z"}',
}, "\n") .. "\n"

-- A control with no pasting at all: the user simply answers in their own words.
local PLAIN_FIXTURE = table.concat({
    '{"type":"user","message":{"role":"user","content":"hello there"},"uuid":"u1","timestamp":"2026-07-07T00:00:00.000Z"}',
    '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"general kenobi, you are a bold one and this sentence is long enough to seed"}]},"uuid":"a1","timestamp":"2026-07-07T00:01:00.000Z"}',
    '{"type":"user","message":{"role":"user","content":"that was an entirely original thought of my own that borrows nothing"},"uuid":"u2","timestamp":"2026-07-07T00:02:00.000Z"}',
}, "\n") .. "\n"

-- Two paragraphs separated by exactly one blank line, to prove the splitter
-- no longer manufactures a second one.
local BLANK_FIXTURE = table.concat({
    '{"type":"user","message":{"role":"user","content":"first paragraph here\\n\\nsecond paragraph here"},"uuid":"u1","timestamp":"2026-07-07T00:00:00.000Z"}',
    '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"understood"}]},"uuid":"a1","timestamp":"2026-07-07T00:01:00.000Z"}',
}, "\n") .. "\n"

print("Quoting a pasted-back line:")
local out = run_parser(QUOTE_FIXTURE)
check(out:find("\n> The fonts live in fonts/", 1, true),
    "marks a pasted row whose source the model had emphasised")
-- The copied left margin is kept, so the marker is followed by however many
-- spaces the render put there; the assertion must not depend on that count.
check(out:find("\n>%s+That is the whole reason%."),
    "keeps the short tail row, because the row above it is quoted")
check(out:find("\nthe whole reason\n", 1, true),
    "leaves an isolated short coincidence unmarked")
check(out:find("\nokay but who creates that directory?", 1, true),
    "leaves the user's own question unmarked")
check(not out:find("> okay but who creates", 1, true),
    "the quote run stops rather than swallowing the reply beneath it")
check(out:find("**The fonts live in `fonts/`", 1, true),
    "the assistant's own answer keeps its markdown, unreduced")

print("No-pasting control:")
local plain = run_parser(PLAIN_FIXTURE)
check(not plain:find("\n>", 1, true), "adds no quote marks to a session with no pasting")
check(plain:find("entirely original thought", 1, true), "leaves the user's words intact")

-- Two whole paragraphs pasted together, with the authored blank between them.
-- Each paragraph seeds on its own; the blank is rejoined afterwards so the
-- pair reads as one quote rather than two. This is the path that replaced
-- letting the outward walk cross blank lines, which had let a run swallow the
-- reply written beneath the paste.
local TWO_PARAGRAPH_FIXTURE = table.concat({
    '{"type":"user","message":{"role":"user","content":"explain the two tiers"},"uuid":"u1","timestamp":"2026-07-07T00:00:00.000Z"}',
    '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"The **first tier** is for executable code and lives under the system temporary directory, where it is wiped between reboots.\\n\\nThe **second tier** is for artifacts and logs and lives in shared memory, which is guaranteed to be held in RAM."}]},"uuid":"a1","timestamp":"2026-07-07T00:01:00.000Z"}',
    '{"type":"user","message":{"role":"user","content":"  The first tier is for executable code and lives under the system temporary directory, where it is wiped between reboots.\\n\\n  The second tier is for artifacts and logs and lives in shared memory, which is guaranteed to be held in RAM.\\n\\nwho creates them at boot?"},"uuid":"u2","timestamp":"2026-07-07T00:02:00.000Z"}',
}, "\n") .. "\n"

print("A paste of two paragraphs stays one quote:")
local two = run_parser(TWO_PARAGRAPH_FIXTURE)
check(two:find("\n>%s+The first tier is for executable code"),
    "marks the first pasted paragraph")
check(two:find("\n>%s+The second tier is for artifacts"),
    "marks the second pasted paragraph")
check(two:find("\n>\n"),
    "keeps the blank between them inside the quote, so it reads as one block")
check(not two:find("> who creates them at boot", 1, true),
    "does not cross the final blank into the user's own question")

print("Blank lines are not manufactured:")
local blanks = run_parser(BLANK_FIXTURE)
check(blanks:find("first paragraph here\n\nsecond paragraph here", 1, true),
    "one authored blank line stays exactly one blank line")
check(not blanks:find("first paragraph here\n\n\nsecond", 1, true),
    "the splitter no longer emits a phantom line after every line")

print("")
if failures == 0 then
    print("PASS: all checks passed")
    os.exit(0)
else
    print("FAIL: " .. failures .. " check(s) failed")
    os.exit(1)
end
