-- 020-checking-kit.lua
--
-- The small set of tools every check file uses: say a check passed or
-- failed, compare values, expect an error, and get a scratch folder in RAM
-- that is removed afterwards. A check file loads this with dofile, runs its
-- checks, and ends with kit.finish(), which exits non-zero if any failed.
-- The test runner (tests/run-tests) runs every check file and counts.

local kit = {}

local DIR = arg[1]
if not DIR then
    io.stderr:write("a check file is run by tests/run-tests, which passes the project folder\n")
    os.exit(2)
end
kit.DIR = DIR

local paths_module = dofile(DIR .. "/src/013-paths.lua")
paths_module.set_search_path(DIR)
kit.project = paths_module.for_project(DIR)
kit.fs = require("017-the-filesystem")

local passed, failed = 0, 0
local scratch_folders = {}
-- Cases whose design scratch space (in /tmp and /dev/shm, outside the
-- check's own scratch folder) must also go when the check ends.
local fixture_cases = {}

-- {{{ function kit.check
function kit.check(condition, name)
    if condition then
        passed = passed + 1
    else
        failed = failed + 1
        io.write("  FAIL ", name, "\n")
    end
    return condition
end
-- }}}

-- {{{ function kit.equal
function kit.equal(found, expected, name)
    if found == expected then
        passed = passed + 1
        return true
    end
    failed = failed + 1
    io.write("  FAIL ", name, "\n    expected: ", tostring(expected), "\n    found:    ", tostring(found), "\n")
    return false
end
-- }}}

-- {{{ function kit.raises
-- The function must raise an error whose message contains `pattern` (a
-- plain substring, not a Lua pattern).
function kit.raises(fn, pattern, name)
    local ok, err = pcall(fn)
    if ok then
        failed = failed + 1
        io.write("  FAIL ", name, " (no error raised)\n")
        return false
    end
    if pattern and not tostring(err):find(pattern, 1, true) then
        failed = failed + 1
        io.write("  FAIL ", name, "\n    expected an error containing: ", pattern, "\n    got: ", tostring(err), "\n")
        return false
    end
    passed = passed + 1
    return true
end
-- }}}

-- {{{ function kit.scratch
-- A fresh folder under the project's RAM scratch space, removed by finish().
function kit.scratch(label)
    local base = kit.project.scratch .. "/checks"
    kit.fs.make_folder(base)
    local folder = string.format("%s/%s-%d-%d", base, label, os.time(), math.random(1, 1e9))
    kit.fs.make_folder(folder)
    scratch_folders[#scratch_folders + 1] = folder
    return folder
end
-- }}}

-- {{{ function kit.project_copy
-- A paths table like the project's, but with its cases folder inside a
-- scratch folder, so checks never touch the real cases/.
function kit.project_copy(label)
    local folder = kit.scratch(label)
    local copy = {}
    for k, v in pairs(kit.project) do
        copy[k] = v
    end
    copy.cases = folder .. "/cases"
    return copy, folder
end
-- }}}

-- {{{ function kit.write_file
function kit.write_file(path, text)
    local folder = path:match("^(.*)/[^/]*$")
    if folder then
        kit.fs.make_folder(folder)
    end
    local file = assert(io.open(path, "wb"))
    file:write(text)
    file:close()
end
-- }}}

-- {{{ function kit.fixture_case
-- A case on a scratch copy of the tiny-notes fixture, played by the stand-in
-- with the fixture script and the given options (Lua table text, without the
-- braces), surveyed. Returns the project copy and the case.
function kit.fixture_case(label, options_text)
    local case = require("018-the-case")
    local survey = require("029-the-survey")
    local summary = require("030-the-survey-summary")
    local fixtures = kit.project.fixtures
    local project, folder = kit.project_copy(label)
    local src = folder .. "/tiny-notes"
    kit.fs.run("cp -r " .. kit.fs.quote(fixtures .. "/tiny-notes") .. " " .. kit.fs.quote(src))
    local record = case.open(project, label, src, "stand-in")
    kit.write_file(record.folder .. "/stand-in.lua", "return dofile(" .. string.format("%q", fixtures .. "/tiny-notes.stand-in.lua")
        .. ")({ root = " .. string.format("%q", fixtures) .. ", " .. (options_text or "") .. " })\n")
    survey.run(project, record, 2)
    summary.write(record.survey)
    fixture_cases[#fixture_cases + 1] = record
    return project, record
end
-- }}}

-- {{{ function kit.turns_of
-- How many turns of a kind a case has run.
function kit.turns_of(record, kind)
    local n = 0
    for _, name in ipairs(kit.fs.list(record.turns)) do
        if name:match("^%d+%-" .. kind .. "%-") then n = n + 1 end
    end
    return n
end
-- }}}

-- {{{ function kit.finish
function kit.finish()
    for _, folder in ipairs(scratch_folders) do
        kit.fs.remove_tree(folder)
    end
    local design_folder = require("048-the-design-folder")
    for _, record in ipairs(fixture_cases) do
        local key = design_folder.scratch_key(record)
        for _, root in ipairs({ "/tmp/burner-of-down-things/cases/", "/dev/shm/burner-of-down-things/cases/" }) do
            if kit.fs.is_folder(root .. key) then
                kit.fs.remove_tree(root .. key)
            end
        end
    end
    io.write(string.format("  %d passed, %d failed\n", passed, failed))
    os.exit(failed == 0 and 0 or 1)
end
-- }}}

math.randomseed(os.time())
return kit
