-- 039-word-sessions-test.lua — proof for the word sessions and tracker.
--
-- What this is, generally: a scratch copy of the project's bones (the
-- format document, the two example words, a tracker sitting in
-- issues/completed/, all in a little git repository in RAM) and a
-- stand-in for `claude` that writes a word file as a real session
-- would. Three words go in at once: two are taught, one session writes a
-- broken file. Checks that both good words are judged taught, the broken
-- one is not, the tracker is moved back out of completed/ and reopened,
-- and both rows land in one write. No real session is started.
-- Run: luajit src/039-word-sessions-test.lua

local DIR = "/mnt/mtwo/programming/ai-stuff/gif-generator"
if arg and arg[1] then DIR = arg[1] end
package.path = DIR .. "/src/?.lua;" .. package.path

local sessions = require("038-word-sessions")
local q = sessions.shell_quote
local passed, failed = 0, 0

-- {{{ local function check()
local function check(name, condition, detail)
    if condition then
        passed = passed + 1
    else
        failed = failed + 1
        print("FAIL: " .. name .. (detail and (" — " .. tostring(detail)) or ""))
    end
end
-- }}}

-- {{{ the scratch project
local ROOT = DIR .. "/tmp/shared-memory/say-test-root"
local RUN = DIR .. "/tmp/shared-memory/say-test-run"
os.execute("rm -rf " .. q(ROOT) .. " " .. q(RUN))
os.execute("mkdir -p " .. q(ROOT .. "/words") .. " " .. q(ROOT .. "/docs")
           .. " " .. q(ROOT .. "/issues/completed") .. " " .. q(RUN))
os.execute("cp " .. q(DIR .. "/words/ring.lua") .. " " .. q(DIR .. "/words/slowly.lua")
           .. " " .. q(ROOT .. "/words/"))
os.execute("cp " .. q(DIR .. "/docs/score-format.md") .. " " .. q(ROOT .. "/docs/"))
sessions.spit(ROOT .. "/issues/completed/605-the-growing-vocabulary.md",
    "# 605\n\n## Status: completed\n\n## Words\n\n| Word | Kind | First asked for in | Added |\n|------|------|------|------|\n")
os.execute("git -C " .. q(ROOT) .. " init -q && git -C " .. q(ROOT)
           .. " add -A && git -C " .. q(ROOT)
           .. " -c user.name=test -c user.email=test@test commit -q -m start")
-- }}}

-- {{{ the stand-in for claude
-- Reads its prompt (the argument after --print), finds the brief's word,
-- and writes a word file into the folder it was started in. The word
-- "broken" gets a file that breaks the contract.
-- in the exec tier (tmp/, on /tmp): /dev/shm is mounted noexec, so a
-- program kept in shared-memory/ cannot be run at all
local FAKE = DIR .. "/tmp/fake-claude"
sessions.spit(FAKE, [[#!/bin/bash
prompt="$2"
brief=$(printf '%s' "$prompt" | sed -n 's/.*brief at \(.*\) and do.*/\1/p')
word=$(basename "$brief" .md)
if [ "$word" = "broken" ]; then
    printf 'return { word = "wrong" }\n' > "words/$word.lua"
else
    printf 'return { word = "%s", aliases = {}, kind = "plain",\n  meaning = "a word the stand-in understood without drawing" }\n' "$word" > "words/$word.lua"
fi
printf '{"result":"taught %s","session_id":"fake-%s"}\n' "$word" "$word"
]])
os.execute("chmod +x " .. q(FAKE))
-- }}}

-- {{{ the run
local env_before = os.getenv("SAY_CLAUDE")
local found = {
    { word = "drizzle", sentence = "a drizzle of ice" },
    { word = "broken", sentence = "something broken" },
    { word = "wobble", sentence = "the ring wobbles" },
}
-- os.getenv cannot be set from Lua; the module reads SAY_CLAUDE, so the
-- launcher script is checked to name the stand-in only through the test's
-- own wrapper, which re-runs this file with SAY_CLAUDE set.
if env_before ~= FAKE then
    local status = os.execute("SAY_CLAUDE=" .. q(FAKE) .. " luajit " .. q(arg[0])
                              .. " " .. q(DIR))
    os.exit((status == 0 or status == true) and 0 or 1)
end

local jobs = sessions.run_all(ROOT, RUN, found)
check("every word got a session", #jobs == 3)
check("the sessions ran", jobs[1].status == 0 and jobs[3].status == 0,
      tostring(jobs[1].status) .. " " .. tostring(jobs[3].status))
check("each brief names its word and sentence",
      (sessions.slurp(RUN .. "/drizzle.md") or ""):find("a drizzle of ice", 1, true))
sessions.judge(ROOT, jobs)
check("a good word is taught", jobs[1].ok and jobs[1].kind == "plain", table.concat(jobs[1].problems, "; "))
check("a broken file is not taught", not jobs[2].ok)
check("and the problem is named", (table.concat(jobs[2].problems, "; ")):find("must match"),
      table.concat(jobs[2].problems, "; "))

local path, reopened = sessions.update_tracker(ROOT, jobs, "2026-10-21")
check("the tracker was moved back out of completed/", reopened
      and path == ROOT .. "/issues/605-the-growing-vocabulary.md", path)
-- "R" for the rename; "RM" once the rows are written into it
check("git sees the move", io.popen("git -C " .. q(ROOT) .. " status --short"):read("*a"):find("R. issues/completed/605"),
      io.popen("git -C " .. q(ROOT) .. " status --short"):read("*a"))
local text = path and sessions.slurp(path) or ""
check("the tracker is open again", text:find("## Status: open", 1, true))
check("both taught words are rows", text:find("| drizzle | plain |", 1, true)
      and text:find("| wobble | plain |", 1, true))
check("the broken word is not a row", not text:find("| broken |", 1, true))
-- }}}

print("word sessions: " .. passed .. " passed, " .. failed .. " failed")
os.exit(failed == 0 and 0 or 1)
