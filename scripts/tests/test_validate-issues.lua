#!/usr/bin/env luajit
-- test_validate-issues.lua
-- Drives validate-issues against a small fake project and checks that each kind
-- of finding is reported, that a clean project passes, and that --next picks
-- the right number.
--
-- Why this test exists. The validator is what the issue-lifecycle skill runs
-- before and after touching an issue; if it silently stopped seeing a class of
-- problem, every project would drift without anyone noticing. Each finding
-- kind has one fixture here.
--
-- Run: `luajit test_validate-issues.lua [SCRIPTS_DIR]`. Exits 1 on any failure.

-- {{{ DIR + paths
local DIR = arg[1] or "/home/ritz/programming/ai-stuff/scripts"
local VALIDATOR = DIR .. "/validate-issues"
local SCRATCH = (os.getenv("TMPDIR") or "/tmp") .. "/test-validate-issues-" .. os.time()
-- }}}

local failures = 0

-- {{{ local function check
local function check(label, ok)
    failures = failures + (ok and 0 or 1)
    print((ok and "ok   " or "FAIL ") .. label)
end
-- }}}

-- {{{ local function write
local function write(root, rel, text)
    local path = root .. "/issues/" .. rel
    os.execute("mkdir -p '" .. path:match("(.*)/") .. "'")
    local f = assert(io.open(path, "w"))
    f:write(text)
    f:close()
end
-- }}}

-- {{{ local function run
-- Returns the validator's stdout and exit status.
local function run(args)
    local handle = io.popen(VALIDATOR .. " " .. args .. "; echo \"exit=$?\"")
    local out = handle:read("*a")
    handle:close()
    return out, tonumber(out:match("exit=(%d+)%s*$"))
end
-- }}}

local full = "## Current Behavior\nx\n## Intended Behavior\ny\n## Suggested Implementation Steps\nz\n"

-- a clean project passes
local clean = SCRATCH .. "/clean"
write(clean, "phase-1-progress.md", "")
write(clean, "101-first.md", "**Blocks:** 102\n" .. full)
write(clean, "102-second.md", "**Blocked by:** 101\n" .. full)
local out, status = run(clean)
check("clean project exits 0", status == 0)
check("next free id is 103", out:find("1→103", 1, true) ~= nil)
out = run(clean .. " --next 1")
check("--next 1 prints 103", out:match("^103") ~= nil)
out = run(clean .. " --next 2")
check("--next on an empty phase starts at 201", out:match("^201") ~= nil)

-- every finding kind appears once
local messy = SCRATCH .. "/messy"
write(messy, "phase-1-progress.md", "")
write(messy, "101-first.md", "## Blocks\n\n102, 109.\n\n" .. full)       -- 109 dangling
write(messy, "102-second.md", "## Current Behavior\nx\n")                  -- no blocker named; sections missing
write(messy, "completed/102-again.md", full)                               -- duplicate id
write(messy, "104a-orphan.md", "**Blocked by:** 105\n" .. full)           -- no 104; also makes the
                                                                           -- project write both directions
write(messy, "105-Bad_Name.md", full)                                      -- bad description
write(messy, "106-no-extension", full)                                     -- no .md
out, status = run(messy)
check("messy project exits 1", status == 1)
check("dangling link found", out:find("names 109, which has no file", 1, true) ~= nil)
check("one-sided link found", out:find("does not name 101 as a blocker", 1, true) ~= nil)
check("missing section found", out:find("102-second.md: missing section: Intended Behavior", 1, true) ~= nil)
check("duplicate id found", out:find("id 102: claimed by 2 files", 1, true) ~= nil)
check("orphan sub-issue found", out:find("sub-issue has no parent issue 104", 1, true) ~= nil)
check("bad description found", out:find("not lower-case words", 1, true) ~= nil)
check("missing extension found", out:find("no .md extension", 1, true) ~= nil)
check("completed issue sections not checked", out:find("completed/102-again.md: missing", 1, true) == nil)

-- --file narrows to one file
out = run(messy .. " --file " .. messy .. "/issues/105-Bad_Name.md")
check("--file reports only that file", out:find("105-Bad_Name", 1, true) ~= nil
    and out:find("102-second", 1, true) == nil)

-- a missing issues/ folder is a usage error
_, status = run(SCRATCH .. "/nothing-here")
check("missing issues/ exits 2", status == 2)

os.execute("rm -rf '" .. SCRATCH .. "'")
print(failures == 0 and "all passed" or (failures .. " failed"))
os.exit(failures == 0 and 0 or 1)
