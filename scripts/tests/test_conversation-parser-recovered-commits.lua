-- test_conversation-parser-recovered-commits.lua
-- Validates issue #040: a commit command whose announcement is missing from
-- its output still gets its line in the transcript, when git holds exactly
-- one commit that fits -- and gets nothing when it does not.
--
-- WHY THIS MATTERS. The website links a commit to its conversation by this
-- line. Real sessions hid the announcement four ways: piping the commit
-- through `tail -3`; `git commit -q`; a loop over many repositories; and
-- catching commit-own-changes' report in a variable and printing it later.
-- A fifth made the commit with git's lower-level `commit-tree`. Each is a
-- case below. So are the ways the rule must say no: a commit made too late
-- to be this command's, two commits that both fit, a commit that was refused
-- and never happened. A line naming the wrong commit is worse than none.
--
-- In general terms: it builds small throwaway git repositories with commits
-- made at chosen moments, writes a pretend session log around each, runs
-- the parser, and reads the transcript it writes.
--
-- Run: `lua test_conversation-parser-recovered-commits.lua [scripts-dir]`.

-- {{{ DIR + paths
local DIR = arg[1] or "/home/ritz/programming/ai-stuff/scripts"
local PARSER = DIR .. "/libs/conversation-parser.lua"
local TMP = (os.getenv("TMPDIR") or "/tmp") .. "/recovered-commits-test-" .. os.time()
-- }}}

os.execute("rm -rf '" .. TMP .. "' && mkdir -p '" .. TMP .. "'")

-- {{{ run_parser
-- Writes the log, runs the parser with the given search roots, and returns
-- the transcript and what the parser said on stderr.
local function run_parser(jsonl_text, roots)
    local infile  = TMP .. "/in.jsonl"
    local outfile = TMP .. "/out.md"
    local errfile = TMP .. "/err.txt"
    os.remove(outfile)
    local f = assert(io.open(infile, "w"))
    f:write(jsonl_text)
    f:close()
    os.execute(string.format("TRANSCRIPT_SEARCH_ROOTS=%q lua %q %q %q >/dev/null 2>%q",
        roots or TMP, PARSER, infile, outfile, errfile))
    local g = io.open(outfile, "r")
    local md = g and g:read("*all") or ""
    if g then g:close() end
    local e = io.open(errfile, "r")
    local err = e and e:read("*all") or ""
    if e then e:close() end
    return md, err
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

-- {{{ repository builders
-- A throwaway repository with an llm-transcripts/ folder, so the loop
-- search finds it, and a commit with the given subject at the given moment.
local function repo(name)
    local path = TMP .. "/" .. name
    os.execute("mkdir -p '" .. path .. "/llm-transcripts' && git -C '" .. path .. "' init -q"
        .. " && git -C '" .. path .. "' config user.email t@t && git -C '" .. path .. "' config user.name t")
    return path
end
-- Each commit adds a file named after its repository and moment: two empty
-- commits with one subject at one moment in two repositories are the SAME
-- commit to git, hash and all, which no real pair of repositories produces.
local function commit_at(path, subject, when)
    local file = path .. "/" .. path:match("([^/]+)$") .. "-" .. when:gsub("%W", "")
    os.execute("echo x > '" .. file .. "' && git -C '" .. path .. "' add -A")
    os.execute(string.format("GIT_COMMITTER_DATE=%q GIT_AUTHOR_DATE=%q git -C %q commit -q --allow-empty -m %q",
        when, when, path, subject))
    local p = io.popen("git -C '" .. path .. "' rev-parse HEAD")
    local hash = p:read("*l")
    p:close()
    return hash
end
-- }}}

-- {{{ log fixture builders
-- The command runs at 10:00:02; a commit at 10:00:05 is three seconds after.
local function js(text)
    return '"' .. text:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n") .. '"'
end
local function user(text)
    return string.format('{"type":"user","uuid":"u1","timestamp":"2026-09-26T10:00:00.000Z","message":{"role":"user","content":%s}}', js(text))
end
local function said(text)
    return string.format('{"type":"assistant","timestamp":"2026-09-26T10:00:01.000Z","message":{"role":"assistant","model":"m","content":[{"type":"text","text":%s}]}}', js(text))
end
local function ran(id, command, cwd)
    return string.format('{"type":"assistant","timestamp":"2026-09-26T10:00:02.000Z","cwd":%s,"message":{"role":"assistant","model":"m","content":[{"type":"tool_use","id":"%s","name":"Bash","input":{"command":%s}}]}}',
        js(cwd or TMP), id, js(command))
end
local function wrote(id, path, content)
    return string.format('{"type":"assistant","timestamp":"2026-09-26T10:00:01.500Z","message":{"role":"assistant","model":"m","content":[{"type":"tool_use","id":"%s","name":"Write","input":{"file_path":%s,"content":%s}}]}}',
        id, js(path), js(content))
end
local function output(id, stdout)
    return string.format('{"type":"user","timestamp":"2026-09-26T10:00:03.000Z","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"%s","content":"x"}]},"toolUseResult":{"stdout":%s,"stderr":""}}', id, js(stdout))
end
local function session(parts)
    return table.concat(parts, "\n") .. "\n"
end
-- }}}

local THREE_AFTER = "2026-09-26T10:00:05Z"

print("== a single repository ==")

local a = repo("a")
local tailed = commit_at(a, "Tailed away", THREE_AFTER)
local md, err = run_parser(session({
    user("Commit it."), said("Committing."),
    ran("w1", "cat > /tmp/s/msg1.txt <<'PIECE'\nTailed away\n\nbody\nPIECE"),
    output("w1", ""),
    ran("c1", "git -C " .. a .. " commit -F /tmp/s/msg1.txt -- x 2>&1 | tail -3"),
    output("c1", " 1 file changed, 2 insertions(+)"),
    said("Done."),
}))
check(md:find("*[commit] " .. tailed:sub(1, 9) .. " - Tailed away*", 1, true) ~= nil,
    "-F a heredoc's file, announcement cut by tail: recorded, nine-character hash")

local b = repo("b")
local written = commit_at(b, "Written by the Write tool", THREE_AFTER)
md = run_parser(session({
    user("Commit it."), said("Committing."),
    wrote("w1", "/tmp/s/commit-message-5", "Written by the Write tool\n\nbody"),
    ran("c1", "git -C " .. b .. " commit -q -F /tmp/s/commit-message-5"),
    output("c1", ""),
    said("Done."),
}))
check(md:find("*[commit] " .. written:sub(1, 9) .. " - Written by the Write tool*", 1, true) ~= nil,
    "-F a file the Write tool wrote, quiet commit: recorded")

local c = repo("c")
local stdin = commit_at(c, "From standard input", THREE_AFTER)
local by_m = commit_at(c, "By dash m", THREE_AFTER)
md = run_parser(session({
    user("Commit both."), said("Committing."),
    ran("c1", "git -C " .. c .. " commit -q -F - <<'EOF'\nFrom standard input\nEOF"),
    output("c1", ""),
    ran("c2", "git -C " .. c .. " commit -q -m 'By dash m'"),
    output("c2", ""),
    said("Done."),
}))
check(md:find(stdin:sub(1, 9) .. " - From standard input", 1, true) ~= nil, "-F - with a heredoc: recorded")
check(md:find(by_m:sub(1, 9) .. " - By dash m", 1, true) ~= nil, "-m: recorded")

local d = repo("d")
local late = commit_at(d, "Too late", "2026-09-26T10:11:42Z")
md, err = run_parser(session({
    user("Commit it."), said("Committing."),
    ran("c1", "git -C " .. d .. " commit -q -m 'Too late'"),
    output("c1", ""),
    said("Done."),
}))
check(md:find(late:sub(1, 7), 1, true) == nil, "a commit 700 seconds later: nothing")
check(err:find("RECOVERY_UNMATCHED:1", 1, true) ~= nil, "... and it is counted")

local e = repo("e")
commit_at(e, "Twice over", THREE_AFTER)
commit_at(e, "Twice over", "2026-09-26T10:00:09Z")
md, err = run_parser(session({
    user("Commit it."), said("Committing."),
    ran("c1", "git -C " .. e .. " commit -q -m 'Twice over'"),
    output("c1", ""),
    said("Done."),
}))
check(md:find("[commit]", 1, true) == nil, "two commits that both fit: nothing")
check(err:find("RECOVERY_UNMATCHED:1", 1, true) ~= nil, "... and it is counted")

local f = repo("f")
md = run_parser(session({
    user("Commit it."), said("Committing."),
    ran("c1", "git -C " .. f .. " commit -m 'Refused by the gate'"),
    output("c1", "refused: this commit holds lines another session wrote"),
    said("It was refused."),
}))
check(md:find("[commit]", 1, true) == nil, "a refused commit, never made: nothing")

local g = repo("g")
local quoted = commit_at(g, "Quoted in a search", THREE_AFTER)
md = run_parser(session({
    user("Look."), said("Looking."),
    ran("c1", "git -C " .. g .. " log --grep=commit --oneline"),
    output("c1", quoted:sub(1, 7) .. " Quoted in a search"),
    said("Found it."),
}))
check(md:find("[commit]", 1, true) == nil, "git log --grep=commit is not a commit")

local h = repo("h")
local announced = commit_at(h, "Announced plainly", THREE_AFTER)
md = run_parser(session({
    user("Commit it."), said("Committing."),
    ran("c1", "git -C " .. h .. " commit -m 'Announced plainly'"),
    output("c1", "[main " .. announced:sub(1, 7) .. "] Announced plainly\n 1 file changed"),
    said("Done."),
}))
local _, times = md:gsub("Announced plainly%*", "")
check(times == 1, "the announcement present: recorded once, by the usual route")

local h2 = repo("h2")
local retried = commit_at(h2, "Announced only later", THREE_AFTER)
md = run_parser(session({
    user("Commit it."), said("Committing."),
    ran("c1", "git -C " .. h2 .. " commit -q -m 'Announced only later'"),
    output("c1", ""),
    ran("c2", "git -C " .. h2 .. " commit -m 'Announced only later'"),
    output("c2", "[main " .. retried:sub(1, 7) .. "] Announced only later"),
    said("Done."),
}))
local _, twice = md:gsub("Announced only later%*", "")
check(twice == 1, "a commit announced by a LATER command is not also recovered: one line")

local i = repo("i")
local later = commit_at(i, "The second draft", THREE_AFTER)
md = run_parser(session({
    user("Commit it."), said("Committing."),
    ran("w1", "cat > /tmp/s/msg.txt <<'EOF'\nThe first draft\nEOF"), output("w1", ""),
    ran("w2", "cat > /tmp/s/msg.txt <<'EOF'\nThe second draft\nEOF"), output("w2", ""),
    ran("c1", "MSG=/tmp/s/msg.txt\ngit -C " .. i .. " commit -q -F \"$MSG\""), output("c1", ""),
    said("Done."),
}))
check(md:find(later:sub(1, 9) .. " - The second draft", 1, true) ~= nil,
    "a message file written twice, named through a variable: the later subject")

local j = repo("j")
local tree = commit_at(j, "Made from the parts", THREE_AFTER)
md = run_parser(session({
    user("Commit it."), said("Committing."),
    ran("c1", "git -C " .. j .. " commit-tree abc123 -p HEAD -F /tmp/s/commit-message-6"),
    output("c1", tree),
    said("Done."),
}))
check(md:find(tree:sub(1, 9) .. " - Made from the parts", 1, true) ~= nil,
    "git commit-tree, which prints only the full hash: recorded")

print("== many repositories ==")

local loops = TMP .. "/loops"
os.execute("mkdir -p '" .. loops .. "'")
local one = repo("loops/one")
local two = repo("loops/two")
repo("loops/three")
local in_one = commit_at(one, "Everywhere at once", THREE_AFTER)
local in_two = commit_at(two, "Everywhere at once", THREE_AFTER)
md = run_parser(session({
    user("Commit everywhere."), said("Committing."),
    ran("w1", "cat > /tmp/s/all.txt <<'MSG'\nEverywhere at once\nMSG"), output("w1", ""),
    ran("c1", "MSG=/tmp/s/all.txt\nfor R in " .. one .. " " .. two .. "; do\n  git -C \"$R\" commit -q -F \"$MSG\"\ndone"),
    output("c1", ""),
    said("Done."),
}), loops)
check(md:find(in_one:sub(1, 9) .. " in one - Everywhere at once", 1, true) ~= nil,
    "a loop with -C \"$R\": the first repository's commit, naming it")
check(md:find(in_two:sub(1, 9) .. " in two - Everywhere at once", 1, true) ~= nil,
    "... and the second's")
check(select(2, md:gsub("%[commit%]", "")) == 2, "... and nothing for the repository with no match")

local k = repo("k")
local caught = commit_at(k, "Caught in a variable", THREE_AFTER)
md = run_parser(session({
    user("Commit it."), said("Committing."),
    ran("c1", "out=$(/x/commit-own-changes " .. k .. " -F - <<'EOF'\nCaught in a variable\nEOF\n); echo \"0 " .. k
        .. " :: $out\""),
    output("c1", "0 " .. k .. " :: commit-own-changes: committed " .. caught:sub(1, 9) .. " on main in " .. k),
    said("Done."),
}))
check(md:find(caught:sub(1, 9) .. " in k - Caught in a variable", 1, true) ~= nil,
    "commit-own-changes' report caught and printed with a prefix: recorded, naming the repository")

os.execute("rm -rf '" .. TMP .. "'")

print("")
if failures == 0 then
    print("PASS: all checks passed")
    os.exit(0)
end
print("FAIL: " .. failures .. " check(s) failed")
os.exit(1)
