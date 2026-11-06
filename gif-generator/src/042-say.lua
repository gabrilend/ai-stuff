-- 042-say.lua — say it and see it: the terminal front door (issue 604e).
--
-- What this is, generally: a box in the terminal to type into. What you
-- type is checked word by word; every word the studio does not know is
-- handed, all at once, to its own headless Claude Code session, which
-- teaches the studio that word in a file of its own; the words taught are
-- added to the tracker issue in one pass. Then a director session draws
-- the whole thing as a gif, which opens in the LÖVE viewer. After that
-- the terminal is a chat: each message goes to the director, which may
-- change anything, and the viewer shows each new draft as it lands.
-- /done keeps the prose, the score, the gif and the chat in output/say/.
--
-- Started by the root `say` script, which makes the folders first:
--   luajit src/042-say.lua DIR RUN_DIR KEEP_DIR
-- RUN_DIR is in RAM (briefs, session output, drafts); KEEP_DIR is
-- output/say/<run>/, where the result is kept.
--
-- Two stand-ins, for tests only: SAY_CLAUDE names a program to run in
-- place of `claude`; SAY_VIEWER names one to run in place of the viewer.

local DIR, RUN_DIR, KEEP_DIR = arg[1], arg[2], arg[3]
if not (DIR and RUN_DIR and KEEP_DIR) then
    print("usage: luajit src/042-say.lua DIR RUN_DIR KEEP_DIR (the say script passes these)")
    os.exit(2)
end
-- the studio's code is found beside this file; DIR is only where the
-- words, documents, tracker and output live (the same place, normally)
local SRC = arg[0]:match("^(.*)/[^/]+$") or "."
package.path = SRC .. "/?.lua;" .. package.path

local words = require("034-words")
local lexicon = require("036-lexicon")
local sessions = require("038-word-sessions")
local director = require("040-director")
local q = sessions.shell_quote

local VIEWER = "/mnt/mtwo/programming/ai-stuff/gif-generator/view-gifs"
local WIDTH = 72

-- {{{ terminal drawing
-- Plain ANSI: bold and dim, and box lines. No curses, so it works in any
-- terminal and in a test that feeds it from a pipe.
local BOLD, DIM, RESET = "\27[1m", "\27[2m", "\27[0m"

local function status(line)
    io.write(DIM, "  · ", line, RESET, "\n")
    io.flush()
end

local function chat_line(who, text, log)
    local label = (who == "you") and "you:    " or "studio: "
    local first = true
    for line in (text .. "\n"):gmatch("(.-)\n") do
        io.write(first and (BOLD .. label .. RESET) or "        ", line, "\n")
        first = false
    end
    io.flush()
    log:write(label, (text:gsub("\n", "\n        ")), "\n")
    log:flush()
end
-- }}}

-- {{{ local function read_box()
-- The box: a top edge, a line to type on per row, finished by an empty
-- line; a bottom edge. Returns the prose, or nil at end of input.
local function read_box()
    io.write("\n", BOLD, "say what you want to see", RESET, DIM,
             "  (an empty line finishes)", RESET, "\n")
    io.write("┌", string.rep("─", WIDTH), "┐\n")
    local lines = {}
    while true do
        io.write("│ ")
        io.flush()
        local line = io.read("*l")
        if line == nil then break end
        if line == "" then
            if #lines > 0 then break end
        else
            lines[#lines + 1] = line
        end
    end
    io.write("└", string.rep("─", WIDTH), "┘\n\n")
    if #lines == 0 then return nil end
    return table.concat(lines, "\n")
end
-- }}}

-- {{{ local function teach()
-- Every unknown word to its own session, all at once; the files judged;
-- the tracker written once. Returns the jobs.
local function teach(prose)
    local unknown = lexicon.unknown(prose, words.load_all(DIR))
    if #unknown == 0 then
        status("the studio knows every word")
        return {}
    end
    local names = {}
    for _, f in ipairs(unknown) do names[#names + 1] = f.word end
    status(#unknown .. " word(s) the studio does not know yet: " .. table.concat(names, ", "))
    status("teaching them, one session each, all at once")
    local jobs = sessions.judge(DIR, sessions.run_all(DIR, RUN_DIR, unknown))
    for _, job in ipairs(jobs) do
        if job.ok then
            status("taught '" .. job.word .. "' (" .. job.kind .. ")")
        else
            status("could not teach '" .. job.word .. "': " .. table.concat(job.problems, "; "))
        end
    end
    local tracker, reopened = sessions.update_tracker(DIR, jobs, os.date("%Y-%m-%d"))
    if tracker then
        status("tracker updated" .. (reopened and ", and reopened from completed/" or "")
               .. ": " .. tracker:gsub("^" .. DIR:gsub("%p", "%%%0") .. "/", ""))
    end
    return jobs
end
-- }}}

-- {{{ local function open_viewer()
-- The viewer, in the background, watching the run's now.gif. Its process
-- id is kept so /done can close it.
local function open_viewer()
    local viewer = os.getenv("SAY_VIEWER") or VIEWER
    os.execute(q(viewer) .. " --watch=" .. q(RUN_DIR .. "/now.gif")
               .. " > " .. q(RUN_DIR .. "/viewer.out") .. " 2>&1 & echo $! > "
               .. q(RUN_DIR .. "/viewer.pid"))
    status("the viewer is open; it shows each new draft as it lands")
end
-- }}}

-- {{{ local function keep()
-- Copies the result out of RAM into output/say/<run>/.
local function keep()
    local kept = {}
    for _, name in ipairs({ "prose.txt", "score.lua", "now.gif", "chat.log" }) do
        local text = sessions.slurp(RUN_DIR .. "/" .. name)
        if text then
            sessions.spit(KEEP_DIR .. "/" .. name, text)
            kept[#kept + 1] = name
        end
    end
    return kept
end
-- }}}

-- {{{ the run
local prose = read_box()
if not prose then
    print("nothing was said; nothing to draw")
    os.exit(0)
end
sessions.spit(RUN_DIR .. "/prose.txt", prose .. "\n")
local log = assert(io.open(RUN_DIR .. "/chat.log", "w"))
chat_line("you", prose, log)

local jobs = teach(prose)
open_viewer()

local ok, state = pcall(director.start, DIR, RUN_DIR, prose, status)
if not ok then
    status("the director could not start: " .. tostring(state))
    os.exit(1)
end
chat_line("studio", state.reply, log)
if not state.facts then
    status("the wall still refuses the score:\n" .. tostring(state.refusal))
end

local turns = 0
while true do
    io.write(BOLD, "you> ", RESET)
    io.flush()
    local message = io.read("*l")
    if message == nil or message == "/done" then break end
    if message ~= "" then
        log:write("you:    ", message, "\n")
        turns = turns + 1
        local turn_ok, reply, facts, refusal = pcall(director.message, DIR, RUN_DIR, state, message, status)
        if not turn_ok then
            status("that message did not get through: " .. tostring(reply))
        else
            chat_line("studio", reply, log)
            if not facts then status("the wall still refuses the score:\n" .. tostring(refusal)) end
        end
    end
end
log:close()

local kept = keep()
local pid = (sessions.slurp(RUN_DIR .. "/viewer.pid") or ""):match("%d+")
if pid then os.execute("kill " .. pid .. " 2>/dev/null") end

local taught = 0
for _, job in ipairs(jobs) do if job.ok then taught = taught + 1 end end
local bye = table.concat({
    "goodbye from say",
    "ended: " .. os.date("%Y-%m-%d %H:%M:%S"),
    "run: " .. RUN_DIR,
    "words found unknown: " .. #jobs,
    "words taught: " .. taught,
    "chat turns: " .. turns,
    "kept in " .. KEEP_DIR .. ": " .. table.concat(kept, ", "),
    "",
}, "\n")
sessions.spit(DIR .. "/output/goodbye", bye)
io.write("\n", bye)
-- }}}
