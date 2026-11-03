#!/usr/bin/env luajit

-- Tests for how poems are named and numbered (Issue 8-019,
-- poem-extractor.number_poems): each poem's source key is its source and that
-- source's counting number; numbers are counted fresh in date order, a tie
-- broken by key; the numbering's fingerprint changes when the order does;
-- two poems with one key, or a poem with no date, stop the extraction.
--
-- Run directly:  luajit src/poem-extractor.numbering.test.lua [--dir PATH]

-- {{{ local function setup_path()
-- The project folder from --dir PATH, or nil when it was not given (the
-- default below is then used); a stray word on the command line stops the
-- program, named (libs/project-dir.lua, Issue 10-076).
local PROJECT_DIR_ARG = (function()
    local own = debug.getinfo(1, "S").source:sub(2):match("(.*/)") or "./"
    local dir = dofile(own .. "../libs/project-dir.lua").read(arg, "")
    if dir == "" then return nil end
    return dir
end)()

local function setup_path()
    local this = debug.getinfo(1, "S").source:sub(2)
    local src_dir = this:match("(.*/)") or "./"
    local project_dir = PROJECT_DIR_ARG and (PROJECT_DIR_ARG .. "/") or src_dir:gsub("src/$", "")
    project_dir = project_dir:gsub("/$", "")
    package.path = project_dir .. "/src/?.lua;" .. project_dir .. "/libs/?.lua;" .. package.path
    return project_dir
end
-- }}}

local DIR = setup_path()
arg = { DIR }
local X = require("poem-extractor")

local passed, failed = 0, 0
-- {{{ local function check()
local function check(name, cond, detail)
    if cond then
        passed = passed + 1
        print("  ok   " .. name)
    else
        failed = failed + 1
        print("  FAIL " .. name .. (detail and ("  -- " .. detail) or ""))
    end
end
-- }}}

-- {{{ local function fixtures()
local function fixtures()
    return {
        { category = "notes", id = 2, creation_date = "2024-01-03T00:00:00Z" },
        { category = "fediverse", id = 7, creation_date = "2024-01-01T10:00:00" },
        { category = "messages", id = 7, creation_date = "2024-01-02T00:00:00Z" },
        -- the same moment as fediverse-7: the key decides (fediverse < messages)
        { category = "messages", id = 3, creation_date = "2024-01-01T10:00:00" },
        { category = "bluesky", id = 1, creation_date = "2023-12-31T23:59:59.500Z" },
    }
end
-- }}}

local function order(list)
    local keys = {}
    for i, p in ipairs(list) do keys[i] = p.source_key end
    return table.concat(keys, " ")
end

do
    local numbered, fingerprint = X.number_poems(fixtures())
    check("each poem's key is its source and counting number",
        numbered[1].source_key == "bluesky-1" and numbered[5].source_key == "notes-2")
    check("numbers are counted in date order, a tie broken by key",
        order(numbered) == "bluesky-1 fediverse-7 messages-3 messages-7 notes-2", order(numbered))
    local ok = true
    for i, p in ipairs(numbered) do if p.poem_index ~= i then ok = false end end
    check("the numbers run 1..N in that order", ok)
    check("the fingerprint is a 16-digit code", type(fingerprint) == "string" and #fingerprint == 16)

    local again, fingerprint_again = X.number_poems(fixtures())
    check("the same poems give the same numbering and fingerprint",
        order(again) == order(numbered) and fingerprint_again == fingerprint)

    local more = fixtures()
    more[#more + 1] = { category = "notes", id = 1, creation_date = "2023-01-01T00:00:00Z" }
    local shifted, fingerprint_shifted = X.number_poems(more)
    check("an older note arriving takes number 1 and moves the rest",
        shifted[1].source_key == "notes-1" and shifted[2].source_key == "bluesky-1")
    check("a moved numbering has another fingerprint", fingerprint_shifted ~= fingerprint)
end

do
    local twice = fixtures()
    twice[#twice + 1] = { category = "fediverse", id = 7, creation_date = "2025-01-01T00:00:00" }
    local ok, err = pcall(X.number_poems, twice)
    check("two poems with one key stop the extraction", not ok)
    check("the error names the key", tostring(err):find("fediverse-7", 1, true) ~= nil, tostring(err))

    local undated = fixtures()
    undated[#undated + 1] = { category = "notes", id = 9, content = "no date anywhere" }
    ok, err = pcall(X.number_poems, undated)
    check("a poem with no date stops the extraction", not ok)
    check("the error names the poem", tostring(err):find("notes-9", 1, true) ~= nil, tostring(err))
end

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
