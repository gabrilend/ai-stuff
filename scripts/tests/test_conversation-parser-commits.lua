#!/usr/bin/env lua
-- test_conversation-parser-commits.lua
-- Validates issue #035's first half: the transcript records the commits its
-- conversation made, at the reply where each was made, and nothing that only
-- looks like one.
--
-- WHY THIS MATTERS. The pages decide which conversation made a commit from
-- these lines. The rule they replaced - the conversation whose transcript a
-- commit happened to touch - hung 220 commits off a one-turn transcript. A
-- false line is as bad: the first version of this capture recorded five
-- commits for a session that had made none, because it had searched old logs
-- for these very lines and the search printed them.
--
-- Run: `lua test_conversation-parser-commits.lua [scripts-dir]`.

-- {{{ DIR + paths
local DIR = arg[1] or "/home/ritz/programming/ai-stuff/scripts"
local PARSER = DIR .. "/libs/conversation-parser.lua"
local TMP = os.getenv("TMPDIR") or "/tmp"
-- }}}

-- {{{ run_parser
local function run_parser(jsonl_text)
    local infile  = TMP .. "/commits_fixture_in.jsonl"
    local outfile = TMP .. "/commits_fixture_out.md"
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
-- A JSON string literal, so commands and output can hold newlines and quotes.
local function js(text)
    return '"' .. text:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n") .. '"'
end
local function user(uuid, text)
    return string.format('{"type":"user","uuid":"%s","timestamp":"2026-09-26T10:00:00.000Z","message":{"role":"user","content":%s}}', uuid, js(text))
end
local function said(text)
    return string.format('{"type":"assistant","timestamp":"2026-09-26T10:00:01.000Z","message":{"role":"assistant","model":"m","content":[{"type":"text","text":%s}]}}', js(text))
end
local function ran(id, command)
    return string.format('{"type":"assistant","timestamp":"2026-09-26T10:00:02.000Z","message":{"role":"assistant","model":"m","content":[{"type":"tool_use","id":"%s","name":"Bash","input":{"command":%s}}]}}', id, js(command))
end
local function output(id, stdout)
    return string.format('{"type":"user","timestamp":"2026-09-26T10:00:03.000Z","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"%s","content":"x"}]},"toolUseResult":{"stdout":%s,"stderr":""}}', id, js(stdout))
end
-- }}}

local md = run_parser(table.concat({
    user("u1", "Commit the work."),
    said("Committing now."),
    ran("t1", "/home/ritz/programming/ai-stuff/scripts/commit-own-changes /mnt/mtwo/programming/ai-stuff -F - <<'EOF'\nClose *four* issues\nEOF"),
    output("t1", "commit-own-changes: committed 8a235a0fe on main in /mnt/mtwo/programming/ai-stuff\n  Close *four* issues\n  ours           a.md (1 of 1 change blocks)"),
    ran("t2", "cd /tmp/x && git add -A && git commit -m 'First commit'"),
    output("t2", "[main (root-commit) 1a2b3c4] First commit\n 1 file changed"),
    ran("t3", "grep -h 'commit-own-changes: committed' ~/.claude/projects/*/*.jsonl"),
    output("t3", "commit-own-changes: committed 99a2c77c0 on main in /mnt/mtwo/programs/rao-chat\n  Phase 1 built twice"),
    ran("t4", "git log --oneline -3"),
    output("t4", "[main 6b80531] One service per mailbox"),
    said("Both are committed."),
}, "\n") .. "\n")

check(md:find("*[commit] 8a235a0fe in ai-stuff - Close \\*four\\* issues*", 1, true) ~= nil,
    "commit-own-changes: hash, repository name and subject, asterisks escaped")
check(md:find("*[commit] 1a2b3c4 - First commit*", 1, true) ~= nil,
    "plain git commit, first commit of a repository")
check(md:find("99a2c77c0", 1, true) == nil,
    "a search that PRINTS a commit report is not a commit")
check(md:find("6b80531", 1, true) == nil,
    "a git command that is not a commit is not a commit")
local reply = md:match("### Assistant Response 1\n\n(.-)\n%-%-%-%-")
check(reply ~= nil and reply:find("^> Committing now%.") ~= nil,
    "prose before the commits is narration")
check(reply ~= nil and reply:find("\nBoth are committed%.") ~= nil and not reply:find("> Both are committed", 1, true),
    "the last prose is the answer, not narration")

md = run_parser(table.concat({
    user("u1", "Commit it."),
    said("Done, see below."),
    ran("t1", "commit-own-changes -F - <<'EOF'\nOne thing\nEOF"),
    output("t1", "commit-own-changes: committed abcdef123 on main in /r/repo\n  One thing"),
}, "\n") .. "\n")
check(md:find("\nDone, see below%.") ~= nil and not md:find("> Done, see below", 1, true),
    "a reply that ENDS with a commit keeps its prose as the answer")

print("")
if failures == 0 then
    print("PASS: all checks passed")
    os.exit(0)
end
print("FAIL: " .. failures .. " check(s) failed")
os.exit(1)
