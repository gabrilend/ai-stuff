#!/usr/bin/env luajit
-- 051-ask-until-it-fits.lua - ask the voice's model for the edited canvas
-- until a reply fits.
--
-- In plain terms: the owner: "if their output doesn't fit it is returned
-- mechanically and run again with a description of why. Like a compiler
-- error." So a turn asks its model with the opening conversation (403); a
-- reply that is a look call is answered and the model asked again, up to the
-- look limit; a canvas reply goes through the fit check (105) against the
-- canvas the turn started from. A reply that fits is the turn's canvas, and
-- its change counts become next turn's advisory note. One that does not goes
-- back with the compiler-style report, the reply too large cut at the edge,
-- "even in the middle of the word!", and the model is asked again. There is
-- no last try: "it will just keep spinning until it gets it right." A cut
-- reply is only ever shown to the model, never returned. (issue 404)
--
--   local ask = dofile(DIR .. "/src/051-ask-until-it-fits.lua")
--   local result = ask.until_fits({
--       call = function(conversation) return caller.chat(endpoint, conversation) end,
--       conversation = prompt.build({...}),            -- 403
--       base = record,                                 -- the canvas it started from
--       recommended = { words = 12, sentences = 1 },
--       look_limit = 3,
--       answer_look = function(look) return text end,  -- the look tool (503, 055's looker);
--                                                      -- without one, ask.NO_LOOK_TOOL
--       log = function(line) run:log(line) end,        -- optional
--       give_way = function() return reason or nil end, -- optional (405)
--   })
--   result.rows, result.note, result.counts, result.conversation
--
-- give_way, when given, is asked before every ask but the first; when it
-- gives a reason (a newer canvas is waiting), the loop stops there and
-- returns { gave_way = reason, counts, conversation } with no rows. Without
-- it the loop keeps going, as the owner said (issue 405).
--
-- result.counts, for the turn's log and receipt: asks (every call to the
-- model), tries (canvas replies checked), problems (kind -> how many),
-- look_calls, looks (focus -> how many), tokens { prompt, completion },
-- seconds (the model's, summed).
--
-- Run directly, it is one turn's asking against a role's endpoint, printed as
-- it goes, to watch a real model being corrected (issue 404, step 2):
--   luajit src/051-ask-until-it-fits.lua --dir ROOT --role fg-sora-1 \
--          --canvas FILE [--turn N]
-- LuaJIT-compatible.

-- {{{ local DIR
local SOURCE = debug.getinfo(1, "S").source
local DIR = string.match(SOURCE, "^@(.+)/src/[^/]*$")
    or (string.match(SOURCE, "^@src/[^/]*$") and ".")
    or "/mnt/mtwo/programming/ai-stuff/guide-feature"
-- }}}

local fit = dofile(DIR .. "/src/012-fit-check.lua")
local shape = dofile(DIR .. "/src/027-exact-shape.lua")
local prompt = dofile(DIR .. "/src/049-turn-prompt.lua")

local M = {}

-- {{{ the answers the loop gives of its own
-- A look call with no look tool given is answered with this (the turn gives
-- one since 503).
M.NO_LOOK_TOOL = "the look tool is not built yet, so there is nothing to show. "
    .. "write the whole canvas again now, with your change in it."
-- A look call past the turn's limit is answered with this.
M.LOOKS_USED = "this turn's look calls are used up (the limit is %d). write the whole "
    .. "canvas again now, with your change in it."
-- }}}

-- {{{ M.SETTINGS
-- The turn's knobs this loop uses, in input/turn (the turn's own settings,
-- issue 405): the two recommended change counts (docs/fit-check.md), the
-- look limit (docs/datapath-voice-turn.md, step 5), and what a turn still
-- asking does when a newer canvas arrives: "keep-going" (the owner's word)
-- or "give-way" (issue 405; the turn passes give_way then).
M.SETTINGS = {
    ["recommended-words"]     = { type = "whole", required = true },
    ["recommended-sentences"] = { type = "whole", required = true },
    ["look-limit"]            = { type = "whole", required = true },
    ["newer-canvas"]          = { type = "choice", of = { "keep-going", "give-way" },
                                  required = true },
}
-- }}}

-- {{{ function M.unfence()
-- A reply wrapped in one Markdown code fence (a line of ``` with or without a
-- language name before, and a line of ``` after) as the rows inside it. Models
-- fence text by habit; the fence lines are never canvas. Nothing else in a
-- reply is changed: a blank line is an empty row.
function M.unfence(reply)
    local lines = fit.lines_of(reply)
    if #lines >= 2 and lines[1]:match("^%s*```[%w%-]*%s*$") and lines[#lines]:match("^%s*```%s*$") then
        local inside = {}
        for index = 2, #lines - 1 do inside[#inside + 1] = lines[index] end
        -- Each row ends with its line ending, so a last empty row is kept.
        return #inside > 0 and (table.concat(inside, "\n") .. "\n") or "", true
    end
    return reply, false
end
-- }}}

-- {{{ function M.check()
-- One canvas reply against its base: the fit check, plus the ruler the prompt
-- drew (403), which short rows can copy and still fit the width. Returns the
-- fit check's result, with any ruler problem first among its problems.
function M.check(reply, base, recommended)
    local result = fit.check(reply, base, recommended)
    local ruler = prompt.ruler_problem(reply)
    if ruler then
        result.fits, result.rows = false, nil
        result.problems = result.problems or {}
        table.insert(result.problems, 1, ruler)
    end
    return result
end
-- }}}

-- {{{ function M.feedback()
-- What goes back to the model for a reply that does not fit: the report, and
-- for a reply too large, the reply cut to the canvas with the owner's line
-- (027's cut message).
function M.feedback(reply, problems, width, height)
    local text = fit.report(problems, width, height)
    local cut = shape.cut(reply, width, height)
    if cut.was_cut then
        text = text .. "\n" .. cut.message
    end
    return text
end
-- }}}

-- {{{ local function copy()
local function copy(conversation)
    local list = {}
    for index, turn in ipairs(conversation) do
        list[index] = { role = turn.role, content = turn.content }
    end
    return list
end
-- }}}

-- {{{ local function whole()
local function whole(value)
    return type(value) == "number" and value >= 0 and value == math.floor(value)
end
-- }}}

-- {{{ function M.until_fits()
function M.until_fits(opts)
    if type(opts.call) ~= "function" then error("ask.until_fits: call is not a function", 2) end
    if type(opts.conversation) ~= "table" then error("ask.until_fits: no conversation", 2) end
    if type(opts.base) ~= "table" or not opts.base.rows then
        error("ask.until_fits: base is not a canvas record", 2)
    end
    if not whole(opts.look_limit) then error("ask.until_fits: look_limit is not a whole number", 2) end
    local log = opts.log or function() end
    local answer_look = opts.answer_look or function() return M.NO_LOOK_TOOL end
    local base = opts.base
    local conversation = copy(opts.conversation)
    local counts = { asks = 0, tries = 0, problems = {}, look_calls = 0, looks = {},
                     tokens = { prompt = 0, completion = 0 }, seconds = 0 }

    while true do
        if opts.give_way and counts.asks > 0 then
            local reason = opts.give_way()
            if reason then
                log(string.format("after ask %d: gave way: %s", counts.asks, reason))
                return { gave_way = reason, counts = counts, conversation = conversation }
            end
        end
        local reply, info = opts.call(copy(conversation))
        counts.asks = counts.asks + 1
        info = info or {}
        local usage = info.usage or {}
        counts.tokens.prompt = counts.tokens.prompt + (tonumber(usage.prompt_tokens) or 0)
        counts.tokens.completion = counts.tokens.completion + (tonumber(usage.completion_tokens) or 0)
        counts.seconds = counts.seconds + (tonumber(info.seconds) or 0)
        conversation[#conversation + 1] = { role = "assistant", content = reply }

        local look = prompt.look_call(reply)
        if look then
            counts.look_calls = counts.look_calls + 1
            local answer
            if counts.look_calls > opts.look_limit then
                answer = string.format(M.LOOKS_USED, opts.look_limit)
                log(string.format("ask %d: look %s (%s), past the limit of %d", counts.asks,
                    look.focus, look.words, opts.look_limit))
            else
                counts.looks[look.focus] = (counts.looks[look.focus] or 0) + 1
                answer = answer_look(look)
                log(string.format("ask %d: look %s (%s)", counts.asks, look.focus, look.words))
            end
            conversation[#conversation + 1] = { role = "user", content = answer }
        else
            counts.tries = counts.tries + 1
            local canvas_text, fenced = M.unfence(reply)
            local result = M.check(canvas_text, base, opts.recommended)
            if result.fits then
                log(string.format("ask %d: try %d fits%s%s", counts.asks, counts.tries,
                    fenced and " (its fence taken off)" or "",
                    result.note and "; over the recommended changes" or ""))
                return { rows = result.rows, note = result.note, counts = counts,
                         changes = result.counts, conversation = conversation }
            end
            local kinds = {}
            for _, problem in ipairs(result.problems) do
                counts.problems[problem.kind] = (counts.problems[problem.kind] or 0) + 1
                kinds[#kinds + 1] = problem.kind
            end
            log(string.format("ask %d: try %d does not fit: %s", counts.asks, counts.tries,
                table.concat(kinds, ", ")))
            conversation[#conversation + 1] = { role = "user",
                content = M.feedback(canvas_text, result.problems, base.width, base.height) }
        end
    end
end
-- }}}

-- {{{ command line
-- One turn's asking against a role's endpoint, printed as it goes.
if arg and arg[0] and string.match(arg[0], "051%-ask%-until%-it%-fits%.lua$") then
    local root, role, canvas_file, turn = DIR, nil, nil, 1
    local index = 1
    while arg[index] do
        local name, value = arg[index], arg[index + 1]
        if name == "--dir" then root = value
        elseif name == "--role" then role = value
        elseif name == "--canvas" then canvas_file = value
        elseif name == "--turn" then turn = tonumber(value)
        else
            io.stderr:write("unknown argument: ", name, "\n")
            os.exit(2)
        end
        index = index + 2
    end
    if not role or not canvas_file then
        io.stderr:write("usage: 051-ask-until-it-fits.lua --dir ROOT --role ROLE --canvas FILE [--turn N]\n")
        os.exit(2)
    end
    local settings = dofile(DIR .. "/src/001-settings.lua")
    local canvas = dofile(DIR .. "/src/006-canvas-text.lua")
    local caller = dofile(DIR .. "/src/046-model-caller.lua")
    local values = settings.read("turn", M.SETTINGS, { root = root })
    local handle = assert(io.open(canvas_file, "rb"))
    local record = canvas.read(handle:read("*a"), "to-voices", canvas_file)
    handle:close()
    local endpoint = caller.for_role(root, role)
    local recommended = { words = values["recommended-words"],
                          sentences = values["recommended-sentences"] }
    local conversation = prompt.build({ instructions = prompt.read_instructions(root),
        canvas = record, voice = role, turn = turn, recommended = recommended,
        look_limit = values["look-limit"] })
    print("asking " .. caller.describe(endpoint))
    local ok, result = pcall(M.until_fits, {
        conversation = conversation, base = record, recommended = recommended,
        look_limit = values["look-limit"],
        call = function(turns)
            local text, info = caller.chat(endpoint, turns)
            print("--- reply ---\n" .. text)
            return text, info
        end,
        log = function(line) print("--- " .. line .. " ---") end,
    })
    if not ok then
        io.stderr:write(tostring(result), "\n")
        os.exit(1)
    end
    print("--- the canvas ---\n" .. table.concat(result.rows, "\n"))
    if result.note then print("--- the note for next turn ---\n" .. result.note) end
    local kinds = {}
    for kind, n in pairs(result.counts.problems) do kinds[#kinds + 1] = kind .. " " .. n end
    table.sort(kinds)
    print(string.format("asks %d, tries %d, problems: %s, look calls %d, tokens %d + %d, %.1f seconds",
        result.counts.asks, result.counts.tries, #kinds > 0 and table.concat(kinds, ", ") or "none",
        result.counts.look_calls, result.counts.tokens.prompt, result.counts.tokens.completion,
        result.counts.seconds))
end
-- }}}

return M
