-- 041-director-test.lua — proof for the director.
--
-- What this is, generally: a stand-in for `claude` plays the director.
-- Its first draft misspells a hue, so the wall must refuse it and send
-- the refusal back; the stand-in then writes a correct score, which is
-- rendered to now.gif. A chat message makes it change the colour, and
-- the gif is rendered again. No real session is started.
-- Run: luajit src/041-director-test.lua

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

local RUN = DIR .. "/tmp/shared-memory/director-test-run"
local FAKE = DIR .. "/tmp/fake-director"  -- exec tier: /dev/shm is noexec

-- the module reads SAY_CLAUDE; re-run this file with it set
if os.getenv("SAY_CLAUDE") ~= FAKE then
    os.execute("rm -rf " .. q(RUN))
    os.execute("mkdir -p " .. q(RUN))
    -- {{{ the stand-in director
    -- First prompt (the brief): a score with a misspelled hue. A prompt
    -- quoting the wall: the corrected score. Any other prompt (chat): the
    -- same picture in violet. Always answers as JSON with a session id.
    sessions.spit(FAKE, [[#!/bin/bash
prompt="$2"
run=$(printf '%s' "$prompt" | grep -o '/[^ ]*director-test-run' | head -1)
write() {
    cat > "$run/score.lua" <<EOF
canvas{ size = 64, fps = 25, length = 1.0, seed = 5 }
pattern{ name = "ring", at = 0.0, lasts = 0.8, color = "$1", center = {32, 32}, radius = 20 }
EOF
}
case "$prompt" in
    *"brief at"*)      write embr;   reply="a ring, drawn" ;;
    *"wall refused"*)  write ember;  reply="fixed the hue" ;;
    *)                 write violet; reply="made it violet" ;;
esac
printf '{"type":"result","is_error":false,"result":"%s","session_id":"fake-director-1"}\n' "$reply"
]])
    os.execute("chmod +x " .. q(FAKE))
    -- }}}
    local status = os.execute("SAY_CLAUDE=" .. q(FAKE) .. " luajit " .. q(arg[0]) .. " " .. q(DIR))
    os.exit((status == 0 or status == true) and 0 or 1)
end

local director = require("040-director")
local said = {}
local function say(line) said[#said + 1] = line end

local state = director.start(DIR, RUN, "a ring of light, slowly", say)
check("the session id is kept", state.session_id == "fake-director-1", state.session_id)
check("the director's words come back", state.reply == "a ring, drawn", state.reply)
check("the misspelled first draft was refused once",
      table.concat(said, "\n"):find("refused the score %(round 1"), table.concat(said, " | "))
check("the corrected draft was rendered", state.facts ~= nil, state.refusal)
local first = sessions.slurp(RUN .. "/now.gif")
check("now.gif exists and is a gif", first and first:sub(1, 6) == "GIF89a")
check("no partial file is left behind", io.open(RUN .. "/now.gif.partial") == nil)
check("the brief carries the prose and the words",
      (sessions.slurp(RUN .. "/director-brief.md") or ""):find("a ring of light, slowly", 1, true)
      and (sessions.slurp(RUN .. "/director-brief.md") or ""):find("**ring** (pattern)", 1, true))

local reply, facts = director.message(DIR, RUN, state, "make it purple", say)
check("a chat message gets a reply", reply == "made it violet", reply)
check("and the gif is rendered again", facts ~= nil)
check("with the change in it", sessions.slurp(RUN .. "/now.gif") ~= first)

print("director: " .. passed .. " passed, " .. failed .. " failed")
os.exit(failed == 0 and 0 or 1)
