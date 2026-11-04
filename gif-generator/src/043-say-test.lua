-- 043-say-test.lua — the whole `say` run, end to end, with stand-ins.
--
-- What this is, generally: a scratch copy of the project's bones in RAM
-- (the format document, the example words, an open tracker, in a small
-- git repository), a stand-in `claude` that plays both a word session
-- and the director, and a stand-in viewer that only records how it was
-- opened. The prose "a spiral of ember light" has one unknown word; the
-- run must teach it, add it to the tracker, draw a gif, take one chat
-- message, and on /done keep the prose, score, gif and chat log and
-- write the goodbye. No real session or window is opened.
-- Run: luajit src/043-say-test.lua

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

local ROOT = DIR .. "/tmp/shared-memory/say-e2e-root"
local RUN = DIR .. "/tmp/shared-memory/say-e2e-run"
local KEEP = ROOT .. "/output/say/e2e"
local FAKE = DIR .. "/tmp/fake-say-claude"   -- exec tier: /dev/shm is noexec
local VIEWER = DIR .. "/tmp/fake-say-viewer"

-- {{{ the scratch project and the stand-ins
os.execute("rm -rf " .. q(ROOT) .. " " .. q(RUN))
os.execute("mkdir -p " .. q(ROOT .. "/words") .. " " .. q(ROOT .. "/docs") .. " "
           .. q(ROOT .. "/issues/completed") .. " " .. q(KEEP) .. " " .. q(RUN))
os.execute("cp " .. q(DIR .. "/words/ring.lua") .. " " .. q(DIR .. "/words/slowly.lua") .. " " .. q(ROOT .. "/words/"))
os.execute("cp " .. q(DIR .. "/docs/score-format.md") .. " " .. q(ROOT .. "/docs/"))
sessions.spit(ROOT .. "/issues/605-the-growing-vocabulary.md",
    "# 605\n\n## Status: open\n\n## Words\n\n| Word | Kind | First asked for in | Added |\n|------|------|------|------|\n")
os.execute("git -C " .. q(ROOT) .. " init -q && git -C " .. q(ROOT) .. " add -A && git -C "
           .. q(ROOT) .. " -c user.name=test -c user.email=test@test commit -q -m start")

sessions.spit(FAKE, [[#!/bin/bash
prompt="$2"
case "$prompt" in
    *director-brief.md*|*"wall refused"*|*"write the score again"*)
        run=$(printf '%s' "$prompt" | grep -o '/[^ ]*say-e2e-run' | head -1)
        size=20
        case "$prompt" in *bigger*) size=28 ;; esac
        cat > "$run/score.lua" <<EOF
canvas{ size = 64, fps = 25, length = 1.0, seed = 9 }
pattern{ name = "ring", at = 0.0, lasts = 0.8, color = "ember", center = {32, 32}, radius = $size }
EOF
        printf '{"is_error":false,"result":"a ring of radius %s","session_id":"fake-director"}\n' "$size"
        ;;
    *)
        brief=$(printf '%s' "$prompt" | sed -n 's/.*brief at \(.*\) and do.*/\1/p')
        word=$(basename "$brief" .md)
        printf 'return { word = "%s", aliases = {}, kind = "plain",\n  meaning = "drawn as a ring for now, by the stand-in" }\n' "$word" > "words/$word.lua"
        printf '{"is_error":false,"result":"taught %s","session_id":"fake-%s"}\n' "$word" "$word"
        ;;
esac
]])
sessions.spit(VIEWER, "#!/bin/bash\nprintf '%s\\n' \"$@\" > " .. q(RUN .. "/viewer-args") .. "\n")
os.execute("chmod +x " .. q(FAKE) .. " " .. q(VIEWER))
-- }}}

-- {{{ the run, fed from a pipe
local input = RUN .. "/typed"
sessions.spit(input, "a spiral of ember light\n\nmake it bigger\n/done\n")
local status = os.execute("SAY_CLAUDE=" .. q(FAKE) .. " SAY_VIEWER=" .. q(VIEWER)
    .. " luajit " .. q(DIR .. "/src/042-say.lua") .. " " .. q(ROOT) .. " " .. q(RUN) .. " " .. q(KEEP)
    .. " < " .. q(input) .. " > " .. q(RUN .. "/screen") .. " 2>&1")
local screen = sessions.slurp(RUN .. "/screen") or ""
check("say ended cleanly", status == 0 or status == true, screen)
check("the unknown word was found", screen:find("does not know yet: spiral", 1, true), screen)
check("and taught", screen:find("taught 'spiral' (plain)", 1, true))
check("its word file exists", io.open(ROOT .. "/words/spiral.lua") ~= nil)
check("the tracker has its row",
      (sessions.slurp(ROOT .. "/issues/605-the-growing-vocabulary.md") or ""):find("| spiral | plain |", 1, true))
check("the viewer was told to watch the draft",
      (sessions.slurp(RUN .. "/viewer-args") or ""):find("--watch=" .. RUN .. "/now.gif", 1, true))
check("the director's first words were shown", screen:find("a ring of radius 20", 1, true))
check("the chat message reached it", screen:find("a ring of radius 28", 1, true))
for _, name in ipairs({ "prose.txt", "score.lua", "now.gif", "chat.log" }) do
    check("kept: " .. name, io.open(KEEP .. "/" .. name) ~= nil)
end
check("the kept score is the last one", (sessions.slurp(KEEP .. "/score.lua") or ""):find("radius = 28", 1, true))
local bye = sessions.slurp(ROOT .. "/output/goodbye") or ""
check("the goodbye counts the run", bye:find("words taught: 1", 1, true) and bye:find("chat turns: 1", 1, true), bye)
-- }}}

print("say: " .. passed .. " passed, " .. failed .. " failed")
os.exit(failed == 0 and 0 or 1)
