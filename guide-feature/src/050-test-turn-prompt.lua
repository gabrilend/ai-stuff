#!/usr/bin/env luajit
-- 050-test-turn-prompt.lua
--
-- Tests the turn prompt (issue 403): src/049-turn-prompt.lua with this
-- project's own input/turn-instructions. First the reference: the whole
-- conversation for a fixed canvas (assets/test-prompts/), so any change to
-- the prompt, in source or in the instruction file, shows up as a
-- difference. Then what the issue asks of it: the parts in the order of
-- docs/datapath-voice-turn.md step 4; the owner's central instruction; the
-- canvas exactly as its rows, inside a ruler of column and row numbers that
-- is explained as not part of the canvas; a reply that copies the ruler
-- found, and reported by the fit check; the markers filled, with an absent
-- note or look part leaving no gap; the instruction file's refusals; and
-- the look call's form.
--
-- For a general: every voice is told the same rules in the same words, and
-- those words can be changed in one file without touching the program.
--
-- usage:
--   luajit 050-test-turn-prompt.lua [--dir ROOT] [--write-reference]

-- {{{ DIR -- the project root, hard-coded, overridable by --dir
local DIR = "/mnt/mtwo/programming/ai-stuff/guide-feature"
local WRITE = false
for index = 1, #arg do
    if arg[index] == "--dir" then DIR = arg[index + 1] end
    if arg[index] == "--write-reference" then WRITE = true end
end
-- }}}

local prompt = dofile(DIR .. "/src/049-turn-prompt.lua")
local canvas = dofile(DIR .. "/src/006-canvas-text.lua")
local fit = dofile(DIR .. "/src/012-fit-check.lua")
local shape = dofile(DIR .. "/src/027-exact-shape.lua")
local utf8 = dofile(DIR .. "/src/005-utf8.lua")

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
local function slurp(path)
    local handle = io.open(path, "rb")
    if not handle then return nil end
    local text = handle:read("*a")
    handle:close()
    return text
end
local function has(text, piece) return text ~= nil and string.find(text, piece, 1, true) ~= nil end
local function before(text, first, second)
    local a, b = string.find(text, first, 1, true), string.find(text, second, 1, true)
    return a ~= nil and b ~= nil and a < b
end
local function lines(text)
    local list = {}
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do list[#list + 1] = line end
    return list
end
-- }}}

local INSTRUCTIONS = prompt.read_instructions(DIR)
local REFERENCE = DIR .. "/assets/test-prompts/01-turn-prompt"
local RECORD = canvas.read(slurp(REFERENCE .. ".canvas"), "to-voices", "01-turn-prompt.canvas")
local NOTE = fit.advice({ words_changed = 31, sentences_rewritten = 3 }, { words = 12, sentences = 1 })
local SETTINGS = { instructions = INSTRUCTIONS, canvas = RECORD, voice = "fg-sora-1", turn = 7,
                   recommended = { words = 12, sentences = 1 }, look_limit = 3, note = NOTE }
local function build(changes)
    local opts = {}
    for name, value in pairs(SETTINGS) do opts[name] = value end
    for name, value in pairs(changes or {}) do opts[name] = value end
    return prompt.build(opts)
end
local function whole(conversation)
    local out = {}
    for _, turn in ipairs(conversation) do
        out[#out + 1] = "=== " .. turn.role .. "\n" .. turn.content
    end
    return table.concat(out, "\n") .. "\n"
end

io.write("\n=== the reference prompt ===\n")
-- {{{
local conversation = build()
local text = "# voice fg-sora-1, turn 7, recommended 12 words and 1 sentence, look limit 3, "
    .. "with last turn's note\n" .. whole(conversation)
if WRITE then
    local handle = assert(io.open(REFERENCE .. ".expected", "wb"))
    handle:write(text)
    handle:close()
    io.write("  wrote ", REFERENCE, ".expected\n")
end
local expected = slurp(REFERENCE .. ".expected")
local first_difference
if expected ~= text then
    local want, got = lines(expected or ""), lines(text)
    for number = 1, math.max(#want, #got) do
        if want[number] ~= got[number] then
            first_difference = string.format("line %d: expected %q, built %q", number,
                tostring(want[number]), tostring(got[number]))
            break
        end
    end
end
check("the prompt is the reference prompt, byte for byte", expected == text, first_difference)
check("the same turn always gives the same prompt", whole(build()) == whole(conversation))
-- }}}

io.write("\n=== its parts, in order ===\n")
-- {{{
local system, user = conversation[1].content, conversation[2].content
check("a system turn, then a user turn", #conversation == 2 and conversation[1].role == "system"
    and conversation[2].role == "user")
check("who the voice is, and that two others edit the same canvas",
    has(system, "You are fg-sora-1") and has(system, "two\nother voices edit the same canvas"))
check("the owner's central instruction", has(system, "Change as little as possible")
    and has(system, "Edit single words before you\nchange sentences")
    and has(system, '"very" becomes "not very"'))
check("the recommended change counts", has(system, "words changed: 12")
    and has(system, "whole sentences rewritten: 1"))
check("the size", has(system, "exactly 40 characters wide and 6 rows tall")
    and has(system, "exactly 6 rows"))
check("the look tool, with its limit", has(system, "look focused: WORDS")
    and has(system, "look broad: WORDS") and has(system, "up to 3 times a turn"))
local shown_shape = system:match(shape.EXAMPLE_LINE .. ":\n\n(.*)$")
local example = shape.example(40, 6, 7)
check("the exact shape, fresh for the turn", shown_shape == table.concat(example, "\n"),
    shown_shape)
check("in the order of step 4: who, rules, size and counts, look, shape",
    before(system, "You are", "Change as little") and before(system, "Change as little", "words changed")
    and before(system, "words changed", "40 characters wide") and before(system, "40 characters wide", "look focused")
    and before(system, "look focused", shape.EXAMPLE_LINE))
check("the user turn: the version, the note, the cuts, then the canvas",
    has(user, "version 18") and before(user, "version 18", NOTE) and before(user, NOTE, "Your edit")
    and before(user, "Your edit", "  |123456789"))
check("only this voice's own cuts", has(user, 'Your edit at version 17 cut the word "cat" at row 1, column 5.')
    and not has(user, "lamp"))
check("no marker is left unfilled", not has(system, "{{") and not has(user, "{{")
    and not has(system, "}}") and not has(user, "}}"))
check("comments in the instruction file are not sent", not has(system, "filled in")
    and not has(user, "# "))
local other = build({ turn = 8 })
check("another turn gets another example", other[1].content ~= system
    and other[2].content == user)
-- }}}

io.write("\n=== the canvas and its ruler ===\n")
-- {{{
local ruled = prompt.ruler(RECORD)
check("the canvas is in the prompt with its ruler", has(user, ruled))
local ruled_lines = lines(ruled)
check("two lines of column numbers, then one line a row", #ruled_lines == 2 + 6)
check("the tens line", ruled_lines[1] == "  |         1         2         3         4", ruled_lines[1])
check("the ones line", ruled_lines[2] == "  |" .. string.rep("1234567890", 4), ruled_lines[2])
local exact = true
for row = 1, 6 do
    exact = exact and ruled_lines[2 + row] == string.format("%d |%s|", row, utf8.pad(RECORD.rows[row], 40))
end
check("every row exactly as it is, padded to the width, between the bars", exact,
    ruled_lines[3])
check("a word's column is the number above it",
    ruled_lines[3]:sub(4 + 4, 4 + 4 + 5) == "kitten" and ruled_lines[2]:sub(4 + 4, 4 + 4) == "5")
check("the ruler is explained as not part of the canvas", has(user, "They are not part of the canvas")
    and before(user, "not part of the canvas", ruled))
local tall = canvas.blank(120, 12, "to-voices")
tall.headers = { canvas = 1 }
local tall_lines = lines(prompt.ruler(tall))
check("over 100 columns, a hundreds line comes first", #tall_lines == 3 + 12
    and tall_lines[1]:sub(4 + 100, 4 + 100) == "1" and tall_lines[1]:sub(4 + 99, 4 + 99) == " "
    and tall_lines[2]:sub(4 + 110, 4 + 110) == "1" and tall_lines[2]:sub(4 + 100, 4 + 100) == "0",
    tall_lines[1])
check("row numbers are right-aligned to the widest", tall_lines[4]:sub(1, 4) == " 1 |"
    and tall_lines[15]:sub(1, 4) == "12 |", tall_lines[4])
-- }}}

io.write("\n=== the ruler read back (405's stand-in model) ===\n")
-- {{{
local back = prompt.unruler("some words first\n7 |not a row|\n" .. prompt.ruler(RECORD) .. "\nafter")
local same = back ~= nil and #back == RECORD.height
for row = 1, RECORD.height do
    same = same and back[row] == RECORD.rows[row]
end
check("unruler gives back the rows a ruler holds, numbered from 1, nothing else", same,
    back and table.concat(back, "/"))
check("and nil for a text with none", prompt.unruler("no canvas here") == nil)
-- }}}

io.write("\n=== a reply that copies the ruler ===\n")
-- {{{
local clean = table.concat(RECORD.rows, "\n")
check("a clean reply has no ruler", prompt.ruler_problem(clean) == nil)
check("the ruled canvas copied whole", (prompt.ruler_problem(ruled) or {}).kind == "ruler")
local numbered = {}
for row = 1, 6 do numbered[row] = row .. " |" .. RECORD.rows[row]:sub(1, 30):gsub("%s+$", "") end
local small = table.concat(numbered, "\n")
local fits = fit.check(small, RECORD, { words = 12, sentences = 1 })
local problem = prompt.ruler_problem(small)
check("row numbers alone, though they fit the size, are found", fits.fits and problem
    and #problem.rows == 6, problem and table.concat(problem.rows, ","))
local barred = {}
for row = 1, 6 do barred[row] = "|" .. RECORD.rows[row]:sub(1, 30) .. "|" end
check("the bars alone are found", (prompt.ruler_problem(table.concat(barred, "\n")) or {}).kind == "ruler")
check("the column numbers alone are found", (prompt.ruler_problem(
    "  |" .. string.rep("1234567890", 3) .. "\n" .. clean) or { rows = {} }).rows[1] == 1)
local report = fit.report({ prompt.ruler_problem(ruled) }, 40, 6)
check("the fit check reports it like a compiler",
    has(report, "rows 1, 2, 3, 4, 5, 6, 7, 8: the ruler was copied") and has(report, "exactly 6 rows"),
    report)
check("a canvas that only mentions a number is not a ruler",
    prompt.ruler_problem("we counted 3 boats\nand 12 gulls | one heron") == nil)
-- }}}

io.write("\n=== markers left empty ===\n")
-- {{{
local quiet = build({ note = false, look_limit = 0, canvas = canvas.read(
    (slurp(REFERENCE .. ".canvas"):gsub("cut: fg%-sora%-1 17 1 5 cat\n", ""))
    , "to-voices", "x") })
local qs, qu = quiet[1].content, quiet[2].content
check("with no look calls, the look part is left out", not has(qs, "look focused")
    and not has(qs, "{{"))
check("with no note and no cuts, their lines are gone", not has(qu, "last turn") and not has(qu, "Your edit"))
check("and leave no gap", not has(qs, "\n\n\n") and not has(qu, "\n\n\n")
    and has(qu, "version 18 of the canvas.\n\nThe numbers"), qu)
-- }}}

local custom = prompt.build({ instructions = "[system]\n{{width}} {{height}} {{words}} {{sentences}}\n"
    .. "[user]\nbefore\n{{note}}\nafter\n{{canvas}}\n[look]\nlook\n", canvas = RECORD, voice = "v",
    turn = 1, recommended = { words = 1, sentences = 1 }, look_limit = 0 })
check("an empty marker alone on its line takes the line with it",
    custom[2].content:match("^before\nafter\n") ~= nil, custom[2].content)

io.write("\n=== the instruction file ===\n")
-- {{{
local function refused(name, text, part)
    local ok, message = pcall(prompt.parse, text)
    check(name, not ok and string.sub(tostring(message), 1, #prompt.SOURCE) == prompt.SOURCE
        and has(message, part), ok and "it was accepted" or message)
end
local MINIMAL = "[system]\n{{width}} {{height}} {{words}} {{sentences}}\n[user]\n{{canvas}}\n[look]\nlook\n"
local ok, parts = pcall(prompt.parse, "# a comment\n\n" .. MINIMAL)
check("a minimal file", ok and parts.user == "{{canvas}}" and parts.look == "look", parts)
refused("an unknown marker", (MINIMAL:gsub("look\n", "{{mood}}\n")), "6: {{mood}} is not a marker")
refused("an unknown part", MINIMAL .. "[assistant]\nhi\n", "7: [assistant] is not a part")
refused("a part given twice", MINIMAL .. "[user]\n{{canvas}}\n", "7: [user] is given twice")
refused("a missing part", (MINIMAL:gsub("%[look%]\nlook\n", "")), "there is no [look] part")
refused("text before the first part", "hello\n" .. MINIMAL, ":1: text before the first part")
refused("the canvas left out", (MINIMAL:gsub("{{canvas}}", "nothing")), "3: the [user] part has no {{canvas}}")
refused("the size left out", (MINIMAL:gsub("{{width}} ", "")), "1: the [system] part has no {{width}}")
refused("a marker not closed", (MINIMAL:gsub("look\n", "{{look-limit\n")), "6: a marker is not closed")
local nok, nproblem = pcall(prompt.read_instructions, "/nonexistent-root")
check("no instruction file", not nok and has(nproblem, "there is no instruction file"), nproblem)
local bok, bproblem = pcall(prompt.build, { instructions = INSTRUCTIONS, canvas = RECORD,
    voice = "fg-sora-1", turn = 1, recommended = { words = 1.5, sentences = 1 }, look_limit = 0 })
check("recommended counts must be whole numbers", not bok and has(bproblem, "recommended"), bproblem)
-- }}}

io.write("\n=== the look call ===\n")
-- {{{
local call = prompt.look_call("look focused: the harbor door")
check("look focused", call and call.focus == "focused" and call.words == "the harbor door")
call = prompt.look_call("\n  LOOK Broad :  Tide Tables  \n\n")
check("look broad, any case, blank lines around", call and call.focus == "broad"
    and call.words == "Tide Tables", call and call.words)
check("another focus is not a look call", prompt.look_call("look sideways: x") == nil)
check("no words is not a look call", prompt.look_call("look focused:") == nil)
check("a canvas holding such a line among its rows is not a look call",
    prompt.look_call("the sea\nlook focused: boats\nand gulls") == nil
    and prompt.look_call("look focused: boats\nand gulls") == nil)
-- }}}

io.write(string.format("\nTests: %d passed, %d failed\n", passed, failed))
os.exit(failed == 0 and 0 or 1)
