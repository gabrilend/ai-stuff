-- project-dir.lua: every program's project folder, read from --dir PATH.
--
-- WHAT IT DOES (for a CEO): each program in the project has to know where
-- the project is before it can load anything else. This reads it from the
-- program's command line the one way every program now spells it -- --dir
-- PATH -- and stops the program on any word that is neither a flag nor a
-- flag's value, naming the word. A stray word is almost always a flag that
-- lost its dashes, and taking it as the project folder (the old way) hid the
-- mistake behind an error about something else (Issue 10-076: "64" became
-- the project folder, and the build stopped on a missing library under
-- "64/scripts/").
--
-- It is loaded by file path, not require(): a program builds package.path
-- FROM the folder this returns, so nothing is on package.path yet.
--   local DIR, rest = dofile(<the program's own folder> .. "../libs/project-dir.lua")
--       .read(arg, DEFAULT_DIR, { ["--threads"] = true })
-- It needs no other library.

local M = {}

-- boolean: false (a person at a terminal) -- a refusal prints its one-line
-- message and exits 1, with no Lua stack trace in the way of the word it
-- names; true (a test) -- a refusal is an error() a pcall can catch.
M.raise_errors = false

-- {{{ local function fail()
-- Stops the program with a message that names the program and the word.
local function fail(program, message)
    if M.raise_errors then error(program .. ": " .. message, 0) end
    io.stderr:write(program, ": ", message, "\n")
    os.exit(1)
end
-- }}}

-- {{{ function M.read()
-- args        : array of strings, the command line (normally the global arg;
--               arg[0] names the program in messages)
-- default_dir : string, the project folder when --dir is not given
-- value_flags : table, set of this program's flags that take a value in the
--               next word ({ ["--threads"] = true }), so that value is not
--               taken for a stray word; nil when the program has none;
--               the string "*" when EVERY flag of the program takes the next
--               word as its value, even an empty one (scripts/write-run-overrides,
--               whose every "--key value" pair is a setting).
--               A "--flag=value" word needs no entry: it is one word.
-- returns     : dir  (string) -- the project folder, without a trailing "/"
--               rest (array of strings) -- every other word, in order, for
--                    the program's own parser; --dir and its value removed
-- errors      : "--dir" with no folder after it, or a flag after it;
--               "--dir=" with nothing after the "=";
--               a word that is not a flag and not the value of a value flag.
function M.read(args, default_dir, value_flags)
    value_flags = value_flags or {}
    local program = (args[0] or "program"):match("([^/]+)$")
    local dir = default_dir
    local rest = {}
    local i = 1
    while args[i] ~= nil do
        local word = args[i]
        if word == "--dir" then
            local value = args[i + 1]
            -- no folder after --dir, or another flag where the folder belongs:
            -- both would otherwise make a nonsense project folder
            if value == nil or value == "" or value:sub(1, 1) == "-" then
                fail(program, "--dir needs a folder after it (--dir PATH)")
            end
            dir = value
            i = i + 2
        elseif word:match("^%-%-dir=") then
            local value = word:match("^%-%-dir=(.*)$")
            if value == "" then fail(program, "--dir= needs a folder after the '='") end
            dir = value
            i = i + 1
        elseif word:sub(1, 1) == "-" then
            -- a flag of the program's own: kept for its parser, with its
            -- value when it is one that takes the next word
            rest[#rest + 1] = word
            local takes_value = (value_flags == "*" and not word:find("=", 1, true)) or
                (type(value_flags) == "table" and value_flags[word])
            if takes_value and args[i + 1] ~= nil then
                rest[#rest + 1] = args[i + 1]
                i = i + 2
            else
                i = i + 1
            end
        else
            -- a word with no flag in front of it: the mistake this reader
            -- exists to catch
            fail(program, "unexpected word on the command line: " .. word
                .. " -- every value follows its flag, and the project folder is --dir PATH")
        end
    end
    dir = dir:gsub("(.)/+$", "%1")
    return dir, rest
end
-- }}}

-- {{{ function M.read_if_run()
-- For a file that is both a program and a library other programs load
-- (src/semantic-color-calculator.lua, src/similarity-engine.lua, ...): it
-- reads the command line only when it is the program that was started. A
-- library that read the global arg whenever it was loaded would read its
-- PARENT's command line -- the parent's flags and values -- and either stop
-- on a value it does not know or take one for its project folder. Same test
-- as libs/script-help.lua's handle_if_run.
-- When loaded, it still takes the parent's --dir PATH if there is one: that
-- flag means the project folder in every program now, so it is safe to
-- read from any command line, and a build started with --dir elsewhere does
-- not split across two folders. Every other word of the parent's is left
-- alone -- they are the parent's to judge.
-- args        : the arg table (arg[0] is the started program's path)
-- self        : this file's own path (debug.getinfo(1, "S").source:sub(2))
-- default_dir, value_flags : as M.read
-- returns     : dir, rest -- from the command line when run; when loaded,
--               the parent's --dir (or default_dir) and an empty rest
function M.read_if_run(args, self, default_dir, value_flags)
    if not args or not args[0] then return default_dir, {} end   -- an embedding host: not run
    local function real(path)
        local p = io.popen("readlink -f " .. string.format("%q", path))
        local out = p:read("*l")
        p:close()
        return out or path
    end
    -- run: the started program is this file; loaded: it is another
    if real(args[0]) == real(self) then return M.read(args, default_dir, value_flags) end
    return M.find_dir(args, default_dir), {}
end
-- }}}

-- {{{ function M.find_dir()
-- Only the --dir PATH (or --dir=PATH) in a command line, judging nothing
-- else: for a library loaded by a program, reading its parent's folder.
-- args : array of strings; default_dir : string
-- returns : the folder named by --dir, or default_dir; a --dir with no
--           usable folder after it is left for the parent to report
function M.find_dir(args, default_dir)
    local i = 1
    while args[i] ~= nil do
        local word = args[i]
        if word == "--dir" and args[i + 1] and args[i + 1] ~= "" and args[i + 1]:sub(1, 1) ~= "-" then
            return (args[i + 1]:gsub("(.)/+$", "%1"))
        end
        local value = word:match("^%-%-dir=(.+)$")
        if value then return (value:gsub("(.)/+$", "%1")) end
        i = i + 1
    end
    return default_dir
end
-- }}}

return M
