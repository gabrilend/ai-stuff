-- 034-words.lua — the word files: one file per word in words/, saying
-- what the word means to the studio (issue 604a).
--
-- What this is, generally: a person's prose reaches for words the
-- score vocabulary has never heard of ("spiral", "rain"). Each such
-- word gets its own small file, words/<word>.lua, written once and kept.
-- A "pattern" word is a recipe that expands into strokes the score
-- already knows; a "plain" word is understood and needs nothing drawn,
-- only a sentence on how to read it. This module loads every word file,
-- holds each to the contract, and answers the score reader's question
-- "what does pattern X expand to".
--
-- Data-format notes worth knowing more than once:
--   * a word file returns a table: word, aliases, kind, meaning, and for
--     patterns fields, expand, example (see KIND_RULES below);
--   * word files are pure: they load in a sandbox holding only math,
--     string, table, ipairs, pairs, type, tostring, tonumber, error and
--     the score's shape constructors, so they cannot read files, run
--     commands, or keep state between calls;
--   * word files are named for their word, not numbered: they are found
--     by name and their order means nothing (like input/ scores).
--
-- As a command: luajit src/034-words.lua --check WORD [DIR]
--   loads one word file and, for a pattern, renders nothing but expands
--   its example and puts the strokes through the compiler's wall.
--   Prints "ok" or every problem; exit 0 or 1. Word sessions run this.

local DIR = "/mnt/mtwo/programming/ai-stuff/gif-generator"

local words = {}

-- {{{ local function listing()
-- The word files present, sorted. `ls` reads the directory and nothing
-- else; an absent words/ folder is an error, because the project ships it.
local function listing(dir)
    local names = {}
    local pipe = io.popen("ls -1 '" .. dir .. "/words'")
    for line in pipe:lines() do
        local name = line:match("^([a-z][a-z%-]*)%.lua$")
        if name then names[#names + 1] = name end
    end
    local ok = pipe:close()
    if not ok then
        error("words: cannot list " .. dir .. "/words — the folder ships "
              .. "with the project; it should not be missing")
    end
    table.sort(names)
    return names
end
-- }}}

-- {{{ local function distance()
-- Edit distance, for "nearest word" teaching.
local function distance(a, b)
    local prev = {}
    for j = 0, #b do prev[j] = j end
    for i = 1, #a do
        local cur = { [0] = i }
        for j = 1, #b do
            local cost = (a:sub(i, i) == b:sub(j, j)) and 0 or 1
            cur[j] = math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost)
        end
        prev = cur
    end
    return prev[#b]
end
-- }}}

-- {{{ local function sandbox()
-- The only things a word file may touch. A fresh table per file, so one
-- file cannot leave anything behind for the next.
local function sandbox(score)
    local env = score.shapes()
    env.math, env.string, env.table = math, string, table
    env.ipairs, env.pairs, env.type = ipairs, pairs, type
    env.tostring, env.tonumber, env.error = tostring, tonumber, error
    return env
end
-- }}}

-- {{{ KIND_RULES -- what each kind of word must carry
-- A dispatch table: a new kind of word is one new row. Each rule returns
-- a list of problems with the entry (empty when it is sound).
local KIND_RULES = {
    -- {{{ pattern
    pattern = function(e)
        local problems = {}
        if type(e.expand) ~= "function" then
            problems[#problems + 1] = "a pattern needs expand = function(call) ... end"
        end
        if type(e.fields) ~= "table" then
            problems[#problems + 1] = "a pattern needs fields = { name = \"what it is\", ... }"
        else
            for k, v in pairs(e.fields) do
                if type(k) ~= "string" or type(v) ~= "string" then
                    problems[#problems + 1] = "fields must map names to one-line descriptions"
                    break
                end
            end
        end
        if type(e.example) ~= "string" or not e.example:match("pattern%s*{") then
            problems[#problems + 1] = "a pattern needs example = 'pattern{ name = ..., ... }'"
        end
        return problems
    end,
    -- }}}
    -- {{{ plain
    plain = function(e)
        local problems = {}
        if e.expand ~= nil then
            problems[#problems + 1] = "a plain word draws nothing; it has no expand"
        end
        return problems
    end,
    -- }}}
}
-- }}}

-- {{{ local function check_entry()
-- The fields every word carries, then its kind's own rule.
local function check_entry(name, e)
    local problems = {}
    if type(e) ~= "table" then
        return { "the file must return a table" }
    end
    if e.word ~= name then
        problems[#problems + 1] = "word = \"" .. tostring(e.word)
            .. "\" but the file is " .. name .. ".lua; they must match"
    end
    if type(e.aliases) ~= "table" then
        problems[#problems + 1] = "aliases must be a list (it may be empty: {})"
    else
        for _, a in ipairs(e.aliases) do
            if type(a) ~= "string" or not a:match("^[a-z][a-z%-]*$") then
                problems[#problems + 1] = "aliases are lower-case words; '"
                    .. tostring(a) .. "' is not"
            end
        end
    end
    if type(e.meaning) ~= "string" or #e.meaning < 10 then
        problems[#problems + 1] = "meaning must be a sentence saying what the word means"
    end
    local rule = KIND_RULES[e.kind]
    if not rule then
        local kinds = {}
        for k in pairs(KIND_RULES) do kinds[#kinds + 1] = k end
        table.sort(kinds)
        problems[#problems + 1] = "kind must be one of: " .. table.concat(kinds, ", ")
    else
        for _, p in ipairs(rule(e)) do problems[#problems + 1] = p end
    end
    return problems
end
-- }}}

-- {{{ function words.load_one()
-- One word file → its entry, or nil and the list of problems.
function words.load_one(dir, name)
    local score = require("022-score")
    local path = dir .. "/words/" .. name .. ".lua"
    local chunk, load_err = loadfile(path)
    if not chunk then
        return nil, { "cannot load " .. path .. ": " .. tostring(load_err) }
    end
    setfenv(chunk, sandbox(score))
    local ok, entry = pcall(chunk)
    if not ok then
        return nil, { name .. ".lua failed while loading: " .. tostring(entry) }
    end
    local problems = check_entry(name, entry)
    if #problems > 0 then
        return nil, problems
    end
    return entry
end
-- }}}

-- {{{ function words.load_all()
-- Every word file. Returns a table:
--   entries   word → entry
--   patterns  word or alias → entry, for pattern words only
--   forms     every word and alias → the word it belongs to
--   nearest(name) → the closest pattern word, for teaching
-- Any file that breaks the contract stops the load, with every problem
-- of every file listed: a half-loaded vocabulary would draw some words
-- and silently skip others.
function words.load_all(dir)
    local result = { entries = {}, patterns = {}, forms = {} }
    local problems = {}
    for _, name in ipairs(listing(dir)) do
        local entry, why = words.load_one(dir, name)
        if not entry then
            for _, p in ipairs(why) do
                problems[#problems + 1] = "words/" .. name .. ".lua: " .. p
            end
        else
            result.entries[name] = entry
            result.forms[name] = name
            for _, a in ipairs(entry.aliases) do result.forms[a] = name end
            if entry.kind == "pattern" then
                result.patterns[name] = entry
                for _, a in ipairs(entry.aliases) do result.patterns[a] = entry end
            end
        end
    end
    if #problems > 0 then
        error("words: the word files break the contract:\n  "
              .. table.concat(problems, "\n  "), 0)
    end
    -- {{{ nearest()
    result.nearest = function(name)
        local best, best_d
        for form in pairs(result.patterns) do
            local d = distance(name, form)
            if not best_d or d < best_d or (d == best_d and form < best) then
                best, best_d = form, d
            end
        end
        return best
    end
    -- }}}
    return result
end
-- }}}

-- {{{ function words.check()
-- The full check a word session runs on its own file: the contract, and
-- for a pattern, its example expanded and compiled by the real wall.
-- Returns true, or false and a list of problems.
function words.check(dir, name)
    local entry, why = words.load_one(dir, name)
    if not entry then return false, why end
    if entry.kind ~= "pattern" then return true end

    local score = require("022-score")
    local compile = require("024-compile")
    local raw = { strokes = {} }
    local env = score.shapes()
    local one = { patterns = { [name] = entry }, nearest = function() return name end }
    for _, a in ipairs(entry.aliases) do one.patterns[a] = entry end
    env.pattern = function(t)
        local ok, strokes = pcall(entry.expand, t)
        if not ok then error("expand failed: " .. tostring(strokes), 0) end
        for _, s in ipairs(strokes) do raw.strokes[#raw.strokes + 1] = s end
    end
    local chunk, load_err = loadstring(entry.example)
    if not chunk then return false, { "the example does not parse: " .. tostring(load_err) } end
    setfenv(chunk, env)
    local ok, run_err = pcall(chunk)
    if not ok then return false, { "the example failed: " .. tostring(run_err) } end
    if #raw.strokes == 0 then return false, { "the example expanded to no strokes" } end

    -- a canvas long enough for every stroke, in tenths
    local ends = 0
    for _, s in ipairs(raw.strokes) do
        if type(s.at) == "number" and type(s.lasts) == "number" then
            ends = math.max(ends, s.at + s.lasts)
        end
    end
    raw.canvas = { size = 256, fps = 25, length = math.ceil(ends * 10 + 5) / 10, seed = 1 }
    local compiled_ok, compile_err = pcall(compile.score, raw)
    if not compiled_ok then
        return false, { "the wall refused the example's strokes:\n" .. tostring(compile_err) }
    end
    return true
end
-- }}}

-- {{{ the command
if arg and arg[0] and arg[0]:match("034%-words%.lua$") then
    if arg[1] ~= "--check" or not arg[2] then
        print("usage: luajit src/034-words.lua --check WORD [DIR]")
        os.exit(2)
    end
    if arg[3] and arg[3] ~= "" then DIR = arg[3] end
    package.path = DIR .. "/src/?.lua;" .. package.path
    local ok, problems = words.check(DIR, arg[2])
    if ok then
        print("ok: words/" .. arg[2] .. ".lua keeps the contract")
        os.exit(0)
    end
    print("words/" .. arg[2] .. ".lua is not ready:")
    for _, p in ipairs(problems) do print("  " .. p) end
    os.exit(1)
end
-- }}}

return words
