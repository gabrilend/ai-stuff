#!/usr/bin/env luajit
-- ask-for-value.test.lua (Issue 10-065a) -- proves the shared value-asker
-- behaves as the issue's table says in every situation: a given value is used;
-- --yes takes the default and says so; a program started by run.sh, or one with
-- nobody at the keyboard, stops with an error naming the flag; otherwise it
-- asks, Enter takes the default, a bad answer is asked again, and end of input
-- is an error. The keyboard and screen are replaced with scripted ones.
--
-- Run: luajit libs/ask-for-value.test.lua [--dir PATH]

-- The project folder from --dir PATH, or nil when it was not given (the
-- default below is then used); a stray word on the command line stops the
-- program, named (libs/project-dir.lua, Issue 10-076).
local PROJECT_DIR_ARG = (function()
    local own = debug.getinfo(1, "S").source:sub(2):match("(.*/)") or "./"
    local dir = dofile(own .. "../libs/project-dir.lua").read(arg, "")
    if dir == "" then return nil end
    return dir
end)()

local DIR = PROJECT_DIR_ARG or "/mnt/mtwo/programming/ai-stuff/neocities-modernization"
package.path = DIR .. "/libs/?.lua;" .. package.path
local ask = require("ask-for-value")

local passed, failed = 0, 0
-- {{{ local function check
local function check(label, ok)
    if ok then
        passed = passed + 1
        print("  ok   - " .. label)
    else
        failed = failed + 1
        print("  FAIL - " .. label)
    end
end
-- }}}

-- {{{ local function scripted
-- A pretend terminal: answers to type, whether input is a terminal, and the
-- environment. Returns a table whose .shown collects everything written.
local function scripted(answers, at_keyboard, env)
    local screen = { shown = "" }
    local next_answer = 0
    ask.set_terminal({
        is_terminal = function() return at_keyboard end,
        read_line = function()
            next_answer = next_answer + 1
            return answers[next_answer]
        end,
        write = function(text) screen.shown = screen.shown .. text end,
        env = function(name) return (env or {})[name] end,
    })
    return screen
end
-- }}}

local function words(overrides)
    local spec = {
        flag = "--words", question = "How many words in the word cloud?",
        kind = "count_or_all", default = 200, default_source = "config.lua word_cloud.max_words",
    }
    for k, v in pairs(overrides or {}) do
        spec[k] = v
    end
    return spec
end

-- a value on the command line is used, and nothing is asked
local screen = scripted({}, true)
check("a given value is used", ask.resolve(words({ given = 50 })) == 50)
check("nothing is asked when the value is given", screen.shown == "")

-- --yes takes the default and says which, and from where
screen = scripted({}, false)
check("--yes takes the default", ask.resolve(words({ accept_defaults = true })) == 200)
check("--yes says what it used and where it came from",
    screen.shown:find("--yes: using 200 for --words (config.lua word_cloud.max_words)", 1, true) ~= nil)

-- --yes with no default is an error, not a guess
scripted({}, true)
local no_default = words({ accept_defaults = true })
no_default.default = nil  -- set after: an override table cannot carry "nothing"
local ok, err = pcall(ask.resolve, no_default)
check("--yes with no default is an error", not ok and err:find("no default", 1, true) ~= nil)

-- started by run.sh: an error naming run.sh, even at a keyboard
scripted({ "7" }, true, { NEOCITIES_NO_PROMPTS = "1" })
ok, err = pcall(ask.resolve, words())
check("under run.sh a missing value is an error", not ok and err:find("bug in run.sh", 1, true) ~= nil)

-- nobody at the keyboard: an error naming the flag and the default
scripted({ "7" }, false)
ok, err = pcall(ask.resolve, words())
check("with no keyboard a missing value is an error naming the flag",
    not ok and err:find("--words is missing", 1, true) ~= nil and err:find("200", 1, true) ~= nil)

-- at a keyboard: the question shows the default in brackets; Enter takes it
screen = scripted({ "" }, true)
check("Enter takes the default", ask.resolve(words()) == 200)
check("the question shows the default in brackets",
    screen.shown:find("How many words in the word cloud? [200]", 1, true) ~= nil)

-- a typed answer is used; "all" is accepted where it means no limit
scripted({ "75" }, true)
check("a typed number is used", ask.resolve(words()) == 75)
scripted({ "ALL" }, true)
check("\"all\" is accepted for count-or-all", ask.resolve(words()) == "all")

-- a bad answer is asked again, with what would be accepted
screen = scripted({ "lots", "0", "12" }, true)
check("bad answers are asked again until a good one", ask.resolve(words()) == 12)
check("a bad answer says what is accepted", screen.shown:find("please answer with", 1, true) ~= nil)

-- a count question refuses "all"
scripted({ "all", "3" }, true)
check("a count question refuses \"all\"", ask.resolve(words({ kind = "count" })) == 3)

-- yes/no: Enter takes the default shown as yes/no; y and n are understood
screen = scripted({ "" }, true)
local boosts = { flag = "--include-boosts", question = "Include reblogged posts?", kind = "yesno",
    default = false, default_source = "config.lua privacy.include_boosts" }
check("Enter takes a yes/no default", ask.resolve(boosts) == false)
check("a yes/no default is shown as no", screen.shown:find("[no]", 1, true) ~= nil)
scripted({ "y" }, true)
check("y means yes", ask.resolve(boosts) == true)

-- pages: a number or "all"; a range is no longer a pages value, so it is asked again
local pages = { flag = "--pages", question = "Which pages?", kind = "pages",
    default = "1", default_source = "config.lua pagination.minimum_pages" }
scripted({ "3" }, true)
check("pages: a number is accepted, as text", ask.resolve(pages) == "3")
scripted({ "all" }, true)
check("pages: \"all\" is accepted", ask.resolve(pages) == "all")
scripted({ "2-5", "4" }, true)
check("pages: a range is refused, a number accepted", ask.resolve(pages) == "4")

-- end of input (Ctrl+D) is an error, not the default
scripted({}, true)
ok, err = pcall(ask.resolve, words())
check("end of input is an error", not ok and err:find("not answered", 1, true) ~= nil)

-- --yes / -y are recognised on a command line
check("--yes is recognised", ask.wants_defaults({ "x", "--yes" }))
check("-y is recognised", ask.wants_defaults({ "-y" }))
check("no flag means ask", not ask.wants_defaults({ "--words", "5" }))

print(string.format("passed %d, failed %d", passed, failed))
os.exit(failed == 0 and 0 or 1)
