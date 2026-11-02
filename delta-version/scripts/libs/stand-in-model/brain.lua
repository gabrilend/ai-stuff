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
--   (anything else)     "stand-in reply: " and the first 60 characters

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
else
    reply("stand-in reply: " .. user:sub(1, 60))
end
