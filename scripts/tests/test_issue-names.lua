#!/usr/bin/env luajit
-- test_issue-names.lua
-- Validates the shared issue-name reader (libs/issue-names.lua) that the
-- progress dashboard and validate-issues both stand on.
--
-- Why this test exists. The dashboard used to take the phase from the first
-- digit of a name, so soren-ds's phase-10 issues (1001-...) were counted as
-- phase 1, and it read status from checkboxes the house format never required.
-- The reader now decides the digit split per project from evidence and reads
-- status from which folder a file sits in. Each case below builds a tiny fake
-- project in a scratch folder and checks one of those decisions.
--
-- Run: `luajit test_issue-names.lua [SCRIPTS_DIR]`. Exits 1 on any failure.

-- {{{ DIR + paths
local DIR = arg[1] or "/home/ritz/programming/ai-stuff/scripts"
local issue_names = dofile(DIR .. "/libs/issue-names.lua")
local SCRATCH = (os.getenv("TMPDIR") or "/tmp") .. "/test-issue-names-" .. os.time()
-- }}}

local failures = 0

-- {{{ local function check
local function check(label, got, want)
    if got ~= want then
        failures = failures + 1
        print("FAIL " .. label .. ": got " .. tostring(got) .. ", want " .. tostring(want))
    else
        print("ok   " .. label)
    end
end
-- }}}

-- {{{ local function make_project
-- Writes empty files at the given paths under <SCRATCH>/<name>/issues.
local function make_project(name, relative_paths)
    local root = SCRATCH .. "/" .. name
    for _, rel in ipairs(relative_paths) do
        local path = root .. "/issues/" .. rel
        os.execute("mkdir -p '" .. path:match("(.*)/") .. "'")
        local f = assert(io.open(path, "w"))
        f:write("# x\n")
        f:close()
    end
    return root
end
-- }}}

-- {{{ local function by_rel
local function by_rel(issues)
    local map = {}
    for _, issue in ipairs(issues) do
        map[issue.rel] = issue
    end
    return map
end
-- }}}

-- two-digit numbering with phase 10 confirmed by a progress file
do
    local root = make_project("two-digit", {
        "101-a.md", "1001-b.md", "completed/1002-c.md", "phase-1-progress.md",
        "phase-10-progress.md",
    })
    local issues, report = issue_names.scan(root)
    local map = by_rel(issues)
    check("1001 is phase 10", map["1001-b.md"].phase, "10")
    check("101 is phase 1", map["101-a.md"].phase, "1")
    check("completed/ means completed", map["completed/1002-c.md"].status, "completed")
    check("progress files are not issues", #issues, 3)
    check("width 2 confirmed", report.width_confirmed, true)
end

-- three-digit numbering proven by a name that states its phase
do
    local root = make_project("three-digit", {
        "1001-a.md", "1020-phase-1-demo.md", "phase-1-progress.md",
    })
    local issues, report = issue_names.scan(root)
    check("phase-N-demo name decides width 3", report.width, 3)
    check("1001 is phase 1 at width 3", by_rel(issues)["1001-a.md"].phase, "1")
end

-- single-digit numbering (usb-c-universal-encoder shape)
do
    local root = make_project("one-digit", {
        "11-a.md", "16-b.md", "71-c.md", "phase-1-progress.md", "phase-7-progress.md",
    })
    local issues, report = issue_names.scan(root)
    check("two-digit names use width 1", report.width, 1)
    check("71 is phase 7", by_rel(issues)["71-c.md"].phase, "7")
end

-- dashed and lettered shapes, retired and unknown folders
do
    local root = make_project("mixed", {
        "9-007-a.md", "10-004c-b.md", "A04-c.md", "superseded/201-d.md",
        "mystery/202-e.md", "10-progress.md", "demos/phase-1-demo.md",
    })
    local issues, report = issue_names.scan(root)
    local map = by_rel(issues)
    check("dashed 9-007 is phase 9", map["9-007-a.md"].phase, "9")
    check("dashed 10-004c is phase 10", map["10-004c-b.md"].phase, "10")
    check("dashed sub-issue index", map["10-004c-b.md"].index, "c")
    check("lettered A04 is phase A", map["A04-c.md"].phase, "A")
    check("superseded/ means retired", map["superseded/201-d.md"].status, "retired")
    check("unknown folder is reported", report.unknown_locations[1], "mystery/202-e.md")
    check("10-progress.md is not an issue", map["10-progress.md"], nil)
    check("demos/ is skipped", map["demos/phase-1-demo.md"], nil)
end

-- a phase-N/ folder outranks the name, and the disagreement is reported
do
    local root = make_project("folders", { "phase-1/001-a.md", "phase-2/015-b.md" })
    local issues, report = issue_names.scan(root)
    check("folder phase wins", by_rel(issues)["phase-1/001-a.md"].phase, "1")
    check("disagreements reported", #report.folder_disagreements, 2)
end

-- leading-zero phases are rejected, not read as phase 2
do
    check("023 at width 1 has no phase", (issue_names.phase_of_compact("023", 1)), nil)
    check("023 at width 2 is phase 0", (issue_names.phase_of_compact("023", 2)), "0")
end

-- a missing issues/ folder is an error, not an empty project
do
    local ok = pcall(issue_names.scan, SCRATCH .. "/does-not-exist")
    check("missing issues/ raises", ok, false)
end

os.execute("rm -rf '" .. SCRATCH .. "'")
print(failures == 0 and "all passed" or (failures .. " failed"))
os.exit(failures == 0 and 0 or 1)
