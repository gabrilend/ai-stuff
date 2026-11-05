#!/usr/bin/env luajit
-- 052-test-ask-until-it-fits.lua
--
-- Tests asking until a reply fits (issue 404), first with a scripted
-- stand-in model in this process, as the issue's step 1 asks: too wide then
-- fits; too wide five times then fits; too many changes, accepted with the
-- advisory note. Around them: what goes back to the model each time (the
-- compiler-style report, the reply cut at the edge for one too large, the
-- owner's line), that a cut reply is never returned, look calls answered and
-- limited, a copied ruler, a fenced reply, a control character, too few and
-- too many rows, and the counts (asks, tries, problems by kind, look calls,
-- tokens, seconds). Then the same loop end to end: through the model caller
-- (046) and curl to a stand-in llama.cpp server (047) on 127.0.0.1, and the
-- module's command line, which is how the owner watches a real model being
-- corrected on kuvalu (step 2).
--
-- For a general: a voice's canvas is never sent until it fits, and a model
-- that keeps getting it wrong is told exactly why, every time.
--
-- usage:
--   luajit 052-test-ask-until-it-fits.lua [--dir ROOT]

-- {{{ DIR -- the project root, hard-coded, overridable by --dir
local DIR = "/mnt/mtwo/programming/ai-stuff/guide-feature"
for index = 1, #arg do
    if arg[index] == "--dir" then DIR = arg[index + 1] end
end
-- }}}

local ffi = require("ffi")
pcall(ffi.cdef, "int setenv(const char *name, const char *value, int overwrite);")
pcall(ffi.cdef, "int poll(void *fds, unsigned long nfds, int timeout);")

local ask = dofile(DIR .. "/src/051-ask-until-it-fits.lua")
local prompt = dofile(DIR .. "/src/049-turn-prompt.lua")
local canvas = dofile(DIR .. "/src/006-canvas-text.lua")
local fit = dofile(DIR .. "/src/012-fit-check.lua")
local shape = dofile(DIR .. "/src/027-exact-shape.lua")
local utf8 = dofile(DIR .. "/src/005-utf8.lua")

io.stdout:setvbuf("line")
local passed, failed = 0, 0

-- {{{ local function check()
local function check(name, ok, detail)
    if ok then
        passed = passed + 1
        io.write("  ok    ", name, "\n")
    else
        failed = failed + 1
        io.write("  FAIL  ", name, detail and ("\n        " .. tostring(detail)) or "", "\n")
    end
end
-- }}}

-- {{{ small helpers
local function shell(command)
    local pipe = io.popen(command .. " 2>&1; echo \"exit:$?\"")
    local text = pipe:read("*a")
    pipe:close()
    local body, status = string.match(text, "^(.-)\n?exit:(%d+)\n$")
    return body, tonumber(status)
end
local function slurp(path)
    local handle = io.open(path, "rb")
    if not handle then return nil end
    local text = handle:read("*a")
    handle:close()
    return text
end
local function write(path, text)
    local handle = assert(io.open(path, "wb"))
    handle:write(text)
    handle:close()
end
local function q(text) return "'" .. string.gsub(text, "'", "'\\''") .. "'" end
local function has(text, piece) return text ~= nil and string.find(text, piece, 1, true) ~= nil end
local function sleep(seconds) ffi.C.poll(nil, 0, math.floor(seconds * 1000)) end
-- }}}

-- {{{ the base canvas and a scripted model
local BASE_TEXT = table.concat({
    "canvas: 4", "size: 20x4", "mode: newest", "project: guide-feature 9f2c1e0",
    "endpoint: stand-in-chat http://127.0.0.1:1", "written: 2026-11-05T10:00:00Z", "",
    "the cat sat on the", "mat. it is very", "sleepy today.", "", "marks:",
}, "\n") .. "\n"
local BASE = canvas.read(BASE_TEXT, "to-voices", "base")
local RECOMMENDED = { words = 2, sentences = 1 }
local INSTRUCTIONS = prompt.read_instructions(DIR)
local OPENING = prompt.build({ instructions = INSTRUCTIONS, canvas = BASE, voice = "fg-sora-1",
    turn = 3, recommended = RECOMMENDED, look_limit = 2 })

local FITS = "the cat sat on the\nmat. it is not very\nsleepy today.\n\n"
local WIDE = "the cat sat on the mat\nmat. it is not very\nsleepy today.\n\n"

-- A model that answers from a list, and keeps every conversation it was sent.
local function scripted(replies)
    local model = { sent = {}, taken = 0 }
    model.call = function(conversation)
        model.taken = model.taken + 1
        -- The loop has no last try, so a test that never fits must stop itself.
        if model.taken > 50 then error("the scripted model was asked 50 times", 0) end
        model.sent[#model.sent + 1] = conversation
        local reply = replies[math.min(model.taken, #replies)]
        return reply, { usage = { prompt_tokens = 100, completion_tokens = 10 }, seconds = 0.5 }
    end
    return model
end
local function run(replies, extra)
    local model = scripted(replies)
    local logged = {}
    local opts = { call = model.call, conversation = OPENING, base = BASE, recommended = RECOMMENDED,
                   look_limit = 2, log = function(line) logged[#logged + 1] = line end }
    for name, value in pairs(extra or {}) do opts[name] = value end
    local ok, result = pcall(ask.until_fits, opts)
    return ok and result or nil, model, logged, (not ok) and result or nil
end
-- }}}

io.write("\n=== too wide, then fits ===\n")
-- {{{
local result, model, logged = run({ WIDE, FITS })
check("it fits on the second try", result and result.counts.tries == 2 and result.counts.asks == 2)
check("the rows are the reply that fit, padded to the width", result
    and result.rows[2] == utf8.pad("mat. it is not very", 20) and #result.rows == 4)
check("never the cut reply", result and result.rows[1] == utf8.pad("the cat sat on the", 20))
check("one too-wide problem counted", result and result.counts.problems["too-wide"] == 1)
local second = model.sent[2]
check("the second ask carries the opening, the reply and the report",
    #second == 4 and second[1].content == OPENING[1].content and second[2].content == OPENING[2].content
    and second[3].role == "assistant" and second[3].content == WIDE and second[4].role == "user")
local feedback = second[4].content
check("the report, like a compiler's", has(feedback, "the canvas does not fit:\n  row 1: 22 characters, "
    .. "2 over the width of 20") and has(feedback, "exactly 4 rows, each at most 20 characters"), feedback)
check("the reply cut at the edge, in the middle of a word, with the owner's line",
    has(feedback, "the cat sat on the m\nmat. it is not very") and has(feedback, shape.CUT_LINE)
    and has(feedback, "row 1 cut at the edge"), feedback)
check("a change within the recommendation leaves no note", result and result.note == nil)
check("its change counts", result and result.changes.words_changed == 2,
    result and result.changes.words_changed)
check("the log says each try", logged[1] == "ask 1: try 1 does not fit: too-wide"
    and logged[2] == "ask 2: try 2 fits", table.concat(logged, " / "))
check("tokens and seconds are summed over every ask", result and result.counts.tokens.prompt == 200
    and result.counts.tokens.completion == 20 and result.counts.seconds == 1.0)
check("the whole conversation comes back", result and #result.conversation == 5
    and result.conversation[5].content == FITS)
check("the caller's opening conversation is not changed", #OPENING == 2)
-- }}}

io.write("\n=== too wide five times, then fits ===\n")
-- {{{
result, model = run({ WIDE, WIDE, WIDE, WIDE, WIDE, FITS })
check("six tries, five problems, then the canvas", result and result.counts.tries == 6
    and result.counts.problems["too-wide"] == 5 and result.rows[2] == utf8.pad("mat. it is not very", 20))
check("each ask carries every try before it", #model.sent[6] == 2 + 2 * 5)
-- }}}

io.write("\n=== too many changes ===\n")
-- {{{
local REWRITTEN = "a dog ran by a tree\nand it was not tired\nat all, not one bit.\n\n"
result = run({ REWRITTEN })
local expected_note = fit.advice(fit.check(REWRITTEN, BASE, RECOMMENDED).counts, RECOMMENDED)
check("accepted on the first try", result and result.counts.tries == 1 and result.rows[1]
    == utf8.pad("a dog ran by a tree", 20))
check("with the advisory note for next turn", result and result.note ~= nil and result.note == expected_note,
    result and result.note)
-- }}}

io.write("\n=== look calls ===\n")
-- {{{
result, model, logged = run({ "look focused: the cat", FITS })
check("a look call is answered and the model asked again", result and result.counts.asks == 2
    and result.counts.tries == 1 and result.counts.look_calls == 1 and result.counts.looks.focused == 1)
check("until 503, the answer says the look tool is not built",
    model.sent[2][4].content == ask.NO_LOOK_TOOL and model.sent[2][3].content == "look focused: the cat")
check("the log names the look", logged[1] == "ask 1: look focused (the cat)", logged[1])
local asked_for
result, model = run({ "look broad: tides", "look focused: boats", "look broad: gulls", FITS }, {
    answer_look = function(look) asked_for = look; return "pieces about " .. look.words end,
})
check("a given answerer answers", model.sent[2][4].content == "pieces about tides"
    and model.sent[3][6].content == "pieces about boats")
check("it is handed the focus and the words", asked_for and asked_for.focus == "focused"
    and asked_for.words == "boats")
check("a look past the limit is not answered, and says so",
    model.sent[4][8].content == string.format(ask.LOOKS_USED, 2), model.sent[4][8].content)
check("all three counted as look calls, two answered", result and result.counts.look_calls == 3
    and result.counts.looks.broad == 1 and result.counts.looks.focused == 1)
-- }}}

io.write("\n=== other ways a reply does not fit ===\n")
-- {{{
local RULED = prompt.ruler(BASE)
local NUMBERED = "1 |the cat sat on\n2 |mat. it is very\n3 |sleepy today.\n4 |\n"
result, model = run({ RULED, NUMBERED, FITS })
check("a copied ruler is a problem, even when its rows fit the width", result
    and result.counts.tries == 3 and result.counts.problems.ruler == 2, result and result.counts.problems.ruler)
check("and the report says so", has(model.sent[3][6].content, "the ruler was copied"))
check("a whole ruled canvas is also too tall and too wide", result
    and result.counts.problems["wrong-height"] == 1 and result.counts.problems["too-wide"] == 6,
    result and result.counts.problems["too-wide"])

result, model = run({ "the cat sat on the\nmat. it is very\nsleepy today.\n", FITS })
check("too few rows: wrong height, and nothing to cut", result and result.counts.problems["wrong-height"] == 1
    and not has(model.sent[2][4].content, shape.CUT_LINE), model.sent[2][4].content)
result, model = run({ "the cat sat on the\nmat. it is very\nsleepy today.\n\nand more.\nand more.\n", FITS })
check("too many rows: the rows past the last dropped, shown cut",
    has(model.sent[2][4].content, "the canvas has 6 rows; it must have exactly 4")
    and has(model.sent[2][4].content, "2 rows past the last were dropped"), model.sent[2][4].content)
result, model = run({ "the cat\tsat on the\nmat. it is very\nsleepy today.\n\n", FITS })
check("a tab is a problem", result and result.counts.problems["bad-character"] == 1
    and has(model.sent[2][4].content, "row 1: a tab or other control character at column 8"))
result = run({ "```\n" .. FITS .. "```" })
check("a fenced reply is taken from inside its fence", result and result.counts.tries == 1
    and result.rows[2] == utf8.pad("mat. it is not very", 20))
result = run({ "```text\nthe cat sat on the\nmat. it is very\nsleepy today.\n\n```\n" })
check("a fence with a language name too", result and result.counts.tries == 1)
check("only a fence around the whole reply is taken off",
    select(2, ask.unfence("```\nrow\n")) == false and select(2, ask.unfence("row\n```\n")) == false)
local _, _, _, problem = run({ "anything" }, { call = function() error("endpoint 'x' (http://y): unreachable", 0) end })
check("a failed call is the turn's error; nothing is retried", problem == "endpoint 'x' (http://y): unreachable",
    problem)
-- }}}

io.write("\n=== end to end, through curl to a stand-in llama.cpp server ===\n")
-- {{{
local TMP = shell("mktemp -d")
TMP = shell("cd " .. q(TMP) .. " && pwd -P")
local ROOT = TMP .. "/project/guide-feature"
shell("mkdir -p " .. q(ROOT .. "/input") .. " " .. q(ROOT .. "/output") .. " "
    .. q(TMP .. "/exec") .. " " .. q(TMP .. "/shm") .. " " .. q(TMP .. "/server"))
shell("ln -s " .. q(DIR .. "/src") .. " " .. q(ROOT .. "/src"))
shell("ln -s " .. q(DIR .. "/libs") .. " " .. q(ROOT .. "/libs"))
ffi.C.setenv("EXEC_TIER_ROOT", TMP .. "/exec", 1)
ffi.C.setenv("ARTIFACT_TIER_ROOT", TMP .. "/shm", 1)
local caller = dofile(DIR .. "/src/046-model-caller.lua")
local json = dofile(DIR .. "/libs/dkjson.lua")
write(TMP .. "/server/replies", json.encode({ WIDE, FITS }))
local pid = shell("luajit " .. q(DIR .. "/src/047-stand-in-llama.lua") .. " --kind chat --port-file "
    .. q(TMP .. "/server/port") .. " --replies " .. q(TMP .. "/server/replies") .. " --requests "
    .. q(TMP .. "/server/requests") .. " --parent $PPID >/dev/null 2>&1 & echo $!")
local port
for _ = 1, 100 do
    port = slurp(TMP .. "/server/port")
    if port then break end
    sleep(0.05)
end
port = port and port:match("%d+")
write(ROOT .. "/endpoints", 'stand-in-chat.url = "http://127.0.0.1:' .. tostring(port) .. '"\n'
    .. 'stand-in-chat.kind = "chat"\nstand-in-chat.timeout = 10\nuse.fg-sora-1 = "stand-in-chat"\n')
local endpoint = caller.for_role(ROOT, "fg-sora-1")
local eok, eresult = pcall(ask.until_fits, { conversation = OPENING, base = BASE,
    recommended = RECOMMENDED, look_limit = 2,
    call = function(turns) return caller.chat(endpoint, turns) end })
check("the loop runs against the server and fits on the second try",
    eok and eresult.counts.tries == 2 and eresult.rows[2] == utf8.pad("mat. it is not very", 20),
    not eok and eresult or nil)
local sent = {}
for line in string.gmatch(slurp(TMP .. "/server/requests") or "", "[^\n]+") do sent[#sent + 1] = json.decode(line) end
check("the server was sent the report as the fourth turn of the second ask", #sent == 2
    and #sent[2].body.messages == 4 and sent[2].body.messages[3].role == "assistant"
    and has(sent[2].body.messages[4].content, "row 1: 22 characters, 2 over the width of 20"))
check("the server's token counts are summed", eok and eresult.counts.tokens.completion > 0
    and eresult.counts.tokens.prompt > 0 and eresult.counts.seconds > 0)

-- The command line, as the owner runs it on kuvalu against a real model.
write(TMP .. "/server/requests", "")
write(ROOT .. "/input/turn", slurp(DIR .. "/input/turn"))
write(ROOT .. "/input/turn-instructions", INSTRUCTIONS)
write(TMP .. "/base.canvas", BASE_TEXT)
shell("kill " .. pid)
for _ = 1, 100 do
    if select(2, shell("kill -0 " .. pid)) ~= 0 then break end
    sleep(0.05)
end
shell("rm -f " .. q(TMP .. "/server/port"))
pid = shell("luajit " .. q(DIR .. "/src/047-stand-in-llama.lua") .. " --kind chat --port-file "
    .. q(TMP .. "/server/port") .. " --replies " .. q(TMP .. "/server/replies") .. " --requests "
    .. q(TMP .. "/server/requests") .. " --parent $PPID >/dev/null 2>&1 & echo $!")
for _ = 1, 100 do
    port = slurp(TMP .. "/server/port")
    if port then break end
    sleep(0.05)
end
port = port and port:match("%d+")
write(ROOT .. "/endpoints", 'stand-in-chat.url = "http://127.0.0.1:' .. tostring(port) .. '"\n'
    .. 'stand-in-chat.kind = "chat"\nstand-in-chat.timeout = 10\nuse.fg-sora-1 = "stand-in-chat"\n')
local out, status = shell("luajit " .. q(DIR .. "/src/051-ask-until-it-fits.lua") .. " --dir " .. q(ROOT)
    .. " --role fg-sora-1 --canvas " .. q(TMP .. "/base.canvas") .. " --turn 3")
check("the command line prints each reply, each try and the canvas", status == 0
    and has(out, "asking 'stand-in-chat' (http://127.0.0.1:" .. tostring(port) .. ")")
    and has(out, "--- ask 1: try 1 does not fit: too-wide ---")
    and has(out, "--- the canvas ---\nthe cat sat on the  \nmat. it is not very")
    and has(out, "asks 2, tries 2, problems: too-wide 1, look calls 0"), out)
local cli_sent = json.decode((slurp(TMP .. "/server/requests") or ""):match("^[^\n]+") or "null")
local TURN = dofile(DIR .. "/src/001-settings.lua").read("turn", ask.SETTINGS, { root = ROOT })
local CLI_OPENING = prompt.build({ instructions = INSTRUCTIONS, canvas = BASE, voice = "fg-sora-1",
    turn = 3, recommended = { words = TURN["recommended-words"],
    sentences = TURN["recommended-sentences"] }, look_limit = TURN["look-limit"] })
check("it asks with the opening built from input/turn and input/turn-instructions",
    cli_sent and cli_sent.body.messages[1].content == CLI_OPENING[1].content
    and cli_sent.body.messages[2].content == CLI_OPENING[2].content)
shell("kill " .. pid)
out, status = shell("luajit " .. q(DIR .. "/src/051-ask-until-it-fits.lua") .. " --dir " .. q(ROOT)
    .. " --role fg-sora-1 --canvas " .. q(TMP .. "/base.canvas"))
check("a stopped server: exit 1, naming the endpoint", status == 1
    and has(out, "endpoint 'stand-in-chat'") and has(out, "unreachable"), out)
-- }}}

shell("rm -rf " .. q(TMP))
io.write(string.format("\nTests: %d passed, %d failed\n", passed, failed))
os.exit(failed == 0 and 0 or 1)
