#!/usr/bin/env luajit
-- brain.lua - what the stand-in model says (tests only).
--
-- server.c hands each chat request to this script on standard input. It
-- reads the system prompt's first line, "Task: NAME.", and answers with a
-- fixed, predictable rule for that task, so a test can say exactly what a
-- tool should do with the answer. It is not a language model and makes no
-- attempt to be one. A user message holding STAND-IN-FAIL gets an error
-- reply, so tools' failure paths can be tested too.
--
-- Tasks:
--   propose-guideline   "- " and the first line of the user text, without
--                       its "- " or "N x " prefix or a "(kind)" at its end
--   classify-section    one importance word for a transcript section, by
--                       the first marker it holds: "decided" ESSENTIAL,
--                       "implemented" IMPORTANT, "because" USEFUL, "let me
--                       try" VERBOSE, else NOISE
--   vision              a vision document built from the "subject: " lines
--   components          each phrase from a fixed list of component phrases
--                       that the user text holds, written as the text
--                       writes it (so "Thread-Pool" stays "Thread-Pool"),
--                       one per line; "none" when there are none
--   summarize-slice     "Slice of N request(s), opening with: " and the first
--                       six words of the slice's first user request
--   merge-summaries     "Merged N parts, first: " and the first eight words
--                       of the first part (parts are split at blank lines)
--   title               "Worked on " and what follows "opening with: " (or
--                       the first five words), then a second sentence, so a
--                       tool's one-sentence cut can be checked
--   blurb               "This session: " and the first twenty words
--   (anything else)     "stand-in reply: " and the first 60 characters
--
-- A user message holding STAND-IN-THINK gets its answer after a
-- <think>...</think> block, as Qwen3 writes one.

local root = os.getenv("AISTUFF_ROOT") or "/home/ritz/programming/ai-stuff"
package.path = root .. "/libs/lua/?.lua;" .. package.path
local json = require("dkjson")

-- {{{ local function reply()
local function reply(text)
    io.write(json.encode({ choices = { { message = { role = "assistant", content = text } } } }))
end
-- }}}

-- {{{ local function first_line()
local function first_line(text)
    for line in text:gmatch("[^\n]+") do
        if line:match("%S") then return (line:gsub("^%s+", ""):gsub("%s+$", "")) end
    end
    return ""
end
-- }}}

-- {{{ local function first_words()
local function first_words(text, count)
    local words = {}
    for word in text:gmatch("%S+") do
        words[#words + 1] = word
        if #words == count then break end
    end
    return table.concat(words, " ")
end
-- }}}

-- {{{ local function opening_request()
-- The first line of text after the first "### User Request" heading.
local function opening_request(text)
    local after = text:match("### User Request[^\n]*\n(.*)$")
    if not after then return text end
    for line in after:gmatch("[^\n]+") do
        if line:match("%S") and not line:match("^%-%-%-") and not line:match("^###") then return line end
    end
    return ""
end
-- }}}

-- {{{ Component phrases the stand-in recognises (Lua patterns, lower case)
local COMPONENTS = {
    "thread[%-_ ]?pool", "worker pool", "tui framework", "terminal ui", "json parser",
    "http client", "llm client", "chat client", "config parser",
}
-- }}}

local request = json.decode(io.read("*a")) or {}
local system, user = "", ""
for _, message in ipairs(request.messages or {}) do
    if message.role == "system" then system = message.content or "" end
    if message.role == "user" then user = message.content or "" end
end

if user:find("STAND-IN-FAIL", 1, true) then
    io.write(json.encode({ error = { message = "the stand-in was asked to fail" } }))
    return
end

local task = system:match("^Task: ([%w%-]+)%.") or ""

if user:find("STAND-IN-THINK", 1, true) then
    local plain_reply = reply
    reply = function(text) plain_reply("<think>\nworking it out\n</think>\n\n" .. text) end
end

if task == "propose-guideline" then
    local line = first_line(user):gsub("^%- ", ""):gsub("^%d+ x ", ""):gsub("%s*%([%a ]+%)$", "")
    reply("- " .. line)
elseif task == "classify-section" then
    local lower = user:lower()
    local word = "NOISE"
    for _, rule in ipairs({ { "decided", "ESSENTIAL" }, { "implemented", "IMPORTANT" },
                            { "because", "USEFUL" }, { "let me try", "VERBOSE" } }) do
        if lower:find(rule[1], 1, true) then word = rule[2] break end
    end
    reply(word)
elseif task == "vision" then
    local subjects = {}
    for subject in user:gmatch("subject: ([^\n]+)") do subjects[#subjects + 1] = subject end
    local out = { "# Vision", "", "## The original idea", "", subjects[1] or "(no commits)", "",
                  "## What it grew into", "" }
    for index = 2, #subjects do out[#out + 1] = "- " .. subjects[index] end
    reply(table.concat(out, "\n"))
elseif task == "components" then
    local lower, found = user:lower(), {}
    for _, pattern in ipairs(COMPONENTS) do
        local from, to = lower:find(pattern)
        if from then found[#found + 1] = user:sub(from, to) end
    end
    reply(#found > 0 and table.concat(found, "\n") or "none")
elseif task == "summarize-slice" then
    local _, requests = user:gsub("### User Request", "")
    reply(string.format("Slice of %d request(s), opening with: %s.", requests,
        first_words(opening_request(user), 6)))
elseif task == "merge-summaries" then
    local parts = 0
    for block in (user .. "\n\n"):gmatch("(.-)\n%s*\n") do
        if block:match("%S") then parts = parts + 1 end
    end
    reply(string.format("Merged %d parts, first: %s", parts, first_words(user, 8)))
elseif task == "title" then
    local topic = user:match("opening with: ([^%.]+)") or first_words(user, 5)
    reply("Worked on " .. topic .. ". It went well.")
elseif task == "blurb" then
    reply("This session: " .. first_words(user, 20) .. ".")
else
    reply("stand-in reply: " .. user:sub(1, 60))
end
