-- {{{ ask-for-value.lua
-- Issue 10-065a: one way for every program to settle a value that is missing
-- from its command line.
--
-- In general terms: a program that needs, say, a word count and was not given
-- one asks the person at the keyboard -- "How many words in the word cloud?
-- [200]" -- and Enter takes the number in brackets. If the program was started
-- with --yes it takes the default without asking and says so on one line. If
-- nobody can answer (run.sh started it, or its input is a pipe) it stops with
-- an error that names the flag, instead of guessing or hanging.
--
-- Before this, each program quietly filled a missing value from config.lua or
-- a number in its own code, and the person who ran it never saw which. The
-- default is still there; what changed is that it is shown and confirmed.
--
-- Usage:
--   local ask = require("ask-for-value")
--   local accept_defaults = ask.wants_defaults(arg)      -- --yes / -y present?
--   local words = ask.resolve({
--       flag = "--words", question = "How many words in the word cloud?",
--       kind = "count_or_all", given = CLI_MAX_WORDS,
--       default = 200, default_source = "config.lua word_cloud.max_words",
--       accept_defaults = accept_defaults,
--   })
-- }}}

local M = {}

-- {{{ local terminal
-- The real keyboard and screen. Tests replace these through M.set_terminal.
-- Questions and notices go to the error stream, so a program whose normal
-- output is piped somewhere still shows them to the person.
local function real_is_terminal()
    -- `test -t 0` asks whether standard input is a terminal. LuaJIT's
    -- os.execute returns the exit code (0 = yes); Lua 5.2+ style returns true.
    local result = os.execute("test -t 0")
    return result == 0 or result == true
end

local terminal = {
    is_terminal = real_is_terminal,
    read_line = function() return io.stdin:read("*l") end,
    write = function(text) io.stderr:write(text); io.stderr:flush() end,
    env = os.getenv,
}

-- Replace any of the four for a test: { is_terminal = fn, read_line = fn,
-- write = fn, env = fn }. Fields left out keep their real behaviour.
function M.set_terminal(replacements)
    for name, fn in pairs(replacements) do
        terminal[name] = fn
    end
end
-- }}}

-- {{{ local parsers
-- Turn a typed answer into a value. Each returns the value, or nil and a short
-- reason the answer was not accepted.
local parsers = {
    -- a whole number of 1 or more
    count = function(text)
        local n = tonumber(text)
        if n and n >= 1 and n == math.floor(n) then
            return n
        end
        return nil, "a whole number of 1 or more"
    end,
    -- a whole number of 1 or more, or the word "all" (no limit)
    count_or_all = function(text)
        if text:lower() == "all" then
            return "all"
        end
        local n = tonumber(text)
        if n and n >= 1 and n == math.floor(n) then
            return n
        end
        return nil, "a whole number of 1 or more, or \"all\""
    end,
    -- how many pages to build per poem, as the page builder reads it: a whole
    -- number of 1 or more ("2" = pages 1 and 2) or "all". Returned as text,
    -- the form the builder takes. (Ranges such as "2-5" were removed
    -- 2026-10-07: never used, and a reason a bare number got misread.)
    pages = function(text)
        local lower = text:lower()
        if lower == "all" then
            return "all"
        end
        local n = tonumber(text)
        if n and n >= 1 and n == math.floor(n) then
            return tostring(n)
        end
        return nil, "a whole number of pages per poem (1 or more), or \"all\""
    end,
    -- yes or no
    yesno = function(text)
        local lower = text:lower()
        if lower == "y" or lower == "yes" then
            return true
        end
        if lower == "n" or lower == "no" then
            return false
        end
        return nil, "y or n"
    end,
}
-- }}}

-- {{{ local function show
-- A value as the person would type it: "yes"/"no" for a yes/no question.
local function show(value)
    if value == true then
        return "yes"
    end
    if value == false then
        return "no"
    end
    return tostring(value)
end
-- }}}

-- {{{ function M.wants_defaults
-- Whether the command line asks to take every default without questions.
function M.wants_defaults(args)
    for _, a in ipairs(args or {}) do
        if a == "--yes" or a == "-y" then
            return true
        end
    end
    return false
end
-- }}}

-- {{{ function M.resolve
-- Settles one value. `spec` fields:
--   flag             string   the command-line flag that supplies it ("--words")
--   question         string   what to ask ("How many words in the word cloud?")
--   kind             string   "count", "count_or_all", "pages" or "yesno"
--   given            any      the value from the command line, or nil if absent
--   default          any      the value Enter or --yes takes, or nil if none
--   default_source   string   where the default came from, for the notice
--   accept_defaults  boolean  --yes was given
-- Returns the value. Raises an error when the value cannot be settled.
function M.resolve(spec)
    local parse = parsers[spec.kind]
    if not parse then
        error("ask-for-value: unknown kind '" .. tostring(spec.kind) .. "' for " .. spec.flag)
    end

    -- each situation, in order; the first that applies decides
    local situations = {
        -- given on the command line: nothing to settle
        function()
            if spec.given ~= nil then
                return true, spec.given
            end
        end,
        -- --yes: take the default, and say so
        function()
            if not spec.accept_defaults then
                return
            end
            if spec.default == nil then
                error(spec.flag .. " is missing and has no default for --yes to take; pass " .. spec.flag)
            end
            terminal.write(string.format("--yes: using %s for %s (%s)\n",
                show(spec.default), spec.flag, spec.default_source or "built-in default"))
            return true, spec.default
        end,
        -- started by run.sh: a value run.sh did not pass is run.sh's bug
        function()
            if terminal.env("NEOCITIES_NO_PROMPTS") == "1" then
                error(spec.flag .. " is missing. run.sh started this program and should have "
                    .. "passed it; this is a bug in run.sh, not a question to ask.")
            end
        end,
        -- nobody at the keyboard: stop rather than hang
        function()
            if not terminal.is_terminal() then
                local default_text = spec.default ~= nil
                    and (" (the default would be " .. show(spec.default) .. ")") or ""
                error(spec.flag .. " is missing and there is no one at the keyboard to ask"
                    .. default_text .. ". Pass " .. spec.flag .. ", or --yes to take the defaults.")
            end
        end,
    }
    for _, situation in ipairs(situations) do
        local settled, value = situation()
        if settled then
            return value
        end
    end

    -- ask until the answer is usable
    local bracket = spec.default ~= nil and (" [" .. show(spec.default) .. "]") or ""
    while true do
        terminal.write(spec.question .. bracket .. " ")
        local line = terminal.read_line()
        -- end of input (Ctrl+D): no answer is coming
        if line == nil then
            terminal.write("\n")
            error(spec.flag .. " was not answered (end of input).")
        end
        line = line:match("^%s*(.-)%s*$")
        -- Enter alone takes the default, when there is one
        if line == "" and spec.default ~= nil then
            return spec.default
        end
        if line ~= "" then
            local value, reason = parse(line)
            if value ~= nil then
                return value
            end
            terminal.write("  please answer with " .. reason .. "\n")
        end
    end
end
-- }}}

return M
