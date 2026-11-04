-- reading-guide.lua - The guide's judgement: given where the reader is and
-- what they have been doing, where should the walk go next?
--
-- In plain terms: the walk follows the project's own order. A guide may step
-- off it: when a reader keeps asking for more at a stop -- where it is used,
-- why it is so, its code -- the part may not be landing, and an earlier, more
-- foundational stop (one this stop is built from) may be the thing to see
-- first. The guide reads only what the reader did of their own accord; it
-- never asks the reader a question whose answer it would judge (issue 065:
-- until "the future will decide", the guide asks nothing to grade).
--
-- The guide is whichever local AI is present. This file builds what the AI is
-- told and reads back what it chose; the AI itself is any function that takes
-- (system text, user text) and returns a reply. The default speaks to the
-- project's llama.cpp server through llama-chat-client.lua; a stand-in can be
-- given instead (tests use one; so can any other local model).
--
-- The AI may answer only with one of four moves, on one line:
--   NEXT          -- go on in the project's order
--   BACK <n>      -- step back to stop n, which must be one of the foundations offered
--   MORE          -- show the reader where this stop is used
--   SUMMARY       -- give the reader this stop's one-sentence summary, then go on

local M = {}

-- {{{ M.foundations(map, index)
-- The earlier stops this stop is built from: those used somewhere inside this
-- stop's own lines, and coming before it in the walk. Found from the map's use
-- lists (each stop knows where it is used; a use that falls inside this stop's
-- span means this stop uses it). At most eight, nearest first.
function M.foundations(map, index)
    local here = map.stops[index]
    local found = {}
    for earlier = index - 1, 1, -1 do
        local stop = map.stops[earlier]
        for _, use in ipairs(stop.uses) do
            if use.file == here.file and use.line >= here.line and use.line <= here.end_line then
                found[#found + 1] = earlier
                break
            end
        end
        if #found == 8 then break end
    end
    return found
end
-- }}}

-- {{{ M.system_text
M.system_text = [[You are a guide walking a reader through a computer program, one function or
datastructure at a time, in the order its author meant it to be read. You decide
where the walk goes next. You never ask the reader anything and never test them.
You judge only from what the reader chose to do at each stop: asking where a
thing is used, asking why it was done that way, asking for its code, or skipping.
Many requests at one stop can mean that part is not landing; a skip means the
reader has it. If the reader is struggling and one of the offered foundations
would make this stop clearer, step back to it. Otherwise go on.

Answer with exactly one line, one of:
NEXT
BACK <number>   (only a number from the list of foundations)
MORE
SUMMARY]]
-- }}}

-- {{{ M.user_text(map, index, recent)
-- What the AI is told about this moment: the stop, its summary, the
-- foundations it may step back to, and the reader's recent actions (a list of
-- strings, oldest first).
function M.user_text(map, index, recent)
    local here = map.stops[index]
    local lines = {
        string.format("Current stop %d of %d: %s (%s), in %s.", index, #map.stops, here.name, here.kind, here.file),
        "Summary: " .. here.summary,
        "",
        "Foundations it is built from (you may step BACK to these):",
    }
    local foundations = M.foundations(map, index)
    if #foundations == 0 then lines[#lines + 1] = "  (none)" end
    for _, earlier in ipairs(foundations) do
        local stop = map.stops[earlier]
        lines[#lines + 1] = string.format("  %d: %s -- %s", earlier, stop.name, stop.summary)
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "What the reader did recently, oldest first:"
    if #recent == 0 then lines[#lines + 1] = "  (nothing yet)" end
    for _, action in ipairs(recent) do lines[#lines + 1] = "  " .. action end
    return table.concat(lines, "\n")
end
-- }}}

-- {{{ M.parse(reply, foundations)
-- The AI's reply read as a move, or nil and the reason it could not be read.
-- A BACK to a stop not offered is refused: the guide may only step back to
-- something this stop is actually built from. The first line that holds a
-- move is used, so a model that thinks aloud before answering still counts.
local moves = {
    NEXT = function() return { move = "next" } end,
    MORE = function() return { move = "more" } end,
    SUMMARY = function() return { move = "summary" } end,
}
function M.parse(reply, foundations)
    local offered = {}
    for _, index in ipairs(foundations) do offered[index] = true end
    for line in (reply or ""):gmatch("[^\n]+") do
        local word, number = line:match("^%s*%**%s*(%u+)%s*(%d*)")
        if word == "BACK" then
            local target = tonumber(number)
            if target and offered[target] then return { move = "back", to = target } end
            return nil, "the guide stepped back to a stop that was not offered: " .. line
        elseif word and moves[word] then
            return moves[word]()
        end
    end
    return nil, "no move in the guide's reply: " .. (reply or ""):sub(1, 120)
end
-- }}}

-- {{{ M.llama_model(scripts_dir)
-- The default AI: the project's llama.cpp server, through the shared client.
-- Unreachable is an error the caller shows; nothing is guessed in its place.
-- Any server speaking the same chat protocol works: INFERENCE_CHAT_HOST points
-- the client at it (ollama listens on localhost:11434) and INFERENCE_CHAT_MODEL
-- names the model there (llama.cpp ignores the name; ollama needs it).
function M.llama_model(scripts_dir)
    local client = dofile(scripts_dir .. "/libs/llama-chat-client.lua")
    if not client.is_reachable() then
        return nil, "the local model at " .. client.endpoint() .. " is not answering " ..
            "(start it, or walk without --guide; set INFERENCE_CHAT_HOST to use another server)"
    end
    return function(system, user)
        return client.complete(system, user,
            { temperature = 0.2, max_tokens = 400, timeout = 300, model = os.getenv("INFERENCE_CHAT_MODEL") })
    end
end
-- }}}

-- {{{ M.choose(model, map, index, recent)
-- One decision: ask, then read the answer. Returns a move, or nil and why.
function M.choose(model, map, index, recent)
    local reply, problem = model(M.system_text, M.user_text(map, index, recent))
    if not reply then return nil, "the guide could not be asked: " .. tostring(problem) end
    return M.parse(reply, M.foundations(map, index))
end
-- }}}

return M
