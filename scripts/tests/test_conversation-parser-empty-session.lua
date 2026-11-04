-- test_conversation-parser-empty-session.lua
-- Validates that a session in which nobody spoke gets no transcript.
--
-- WHY THIS MATTERS. Someone opens Claude Code, runs /config, closes it, and
-- says nothing. The log has system entries with times, but no turn. The
-- parser used to hand back dates for it, so the exporter wrote a transcript
-- with a header and nothing under it -- which double-diaper-dungeon's test of
-- its own transcripts caught. With no turn written, the parser now hands back
-- no dates, and the exporter's husk rule writes nothing and retires any old
-- file (issue 020).
--
-- Run: `lua test_conversation-parser-empty-session.lua [scripts-dir]`.

-- {{{ DIR + paths
local DIR = arg[1] or "/home/ritz/programming/ai-stuff/scripts"
local PARSER = DIR .. "/libs/conversation-parser.lua"
local TMP = os.getenv("TMPDIR") or "/tmp"
-- }}}

-- {{{ run_parser
-- Returns what the parser said on stderr, where its dates go.
local function run_parser(jsonl_text)
    local infile = TMP .. "/empty_session_in.jsonl"
    local errfile = TMP .. "/empty_session_err.txt"
    local f = assert(io.open(infile, "w"))
    f:write(jsonl_text)
    f:close()
    os.execute(string.format("lua %q %q %q >/dev/null 2>%q", PARSER, infile, TMP .. "/empty_session_out.md", errfile))
    local e = io.open(errfile, "r")
    local err = e and e:read("*all") or ""
    if e then e:close() end
    return err
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

local silent = run_parser(table.concat({
    '{"type":"system","subtype":"local_command","timestamp":"2026-10-02T10:00:00.000Z","content":"<command-name>/config</command-name>"}',
    '{"type":"system","subtype":"local_command","timestamp":"2026-10-02T10:00:05.000Z","content":"<local-command-stdout>Settings dialog dismissed</local-command-stdout>"}',
}, "\n") .. "\n")
check(not silent:find("START_DATE:", 1, true), "a session where nobody spoke hands back no start date")
check(not silent:find("FINAL_DATE:", 1, true), "... and no final date, so the exporter writes no file")

local spoken = run_parser(table.concat({
    '{"type":"user","uuid":"u1","timestamp":"2026-10-02T10:00:00.000Z","message":{"role":"user","content":"hello"}}',
    '{"type":"assistant","timestamp":"2026-10-02T10:00:01.000Z","message":{"role":"assistant","model":"m","content":[{"type":"text","text":"hi"}]}}',
}, "\n") .. "\n")
check(spoken:find("START_DATE:2026-10-02", 1, true) ~= nil, "a session where somebody spoke keeps its dates")

print("")
if failures == 0 then
    print("PASS: all checks passed")
    os.exit(0)
end
print("FAIL: " .. failures .. " check(s) failed")
os.exit(1)
