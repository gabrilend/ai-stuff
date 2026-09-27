-- phase-7-demo.lua
--
-- The phase 7 demonstration, run by phase-7-demo: the machine used the way a
-- person uses it — through its launcher, one command at a time — on a
-- scratch copy of the project, so the real cases/ folder is never touched.

local DIR = arg[1]
local paths_module = dofile(DIR .. "/src/013-paths.lua")
paths_module.set_search_path(DIR)
local project = paths_module.for_project(DIR)

local fs = require("017-the-filesystem")
local ledger = require("016-ledger")
local center = require("058-the-center")
local design_folder = require("048-the-design-folder")

-- {{{ local function wall
local function wall()
    return tonumber((fs.capture("date +%s.%N")))
end
-- }}}

local scratch = project.scratch .. "/demo-phase-7"
if fs.is_folder(scratch) then
    fs.remove_tree(scratch)
end
-- A copy of the machine to run: its code, its launcher, its fixtures. A real
-- tmp/ folder inside it keeps the RAM helper from making scratch space named
-- after the copy.
local copy = scratch .. "/machine-copy"
fs.make_folder(copy .. "/tmp/shared-memory")
fs.make_folder(copy .. "/input")
fs.make_folder(copy .. "/tests")
fs.run("cp -r " .. fs.quote(DIR .. "/src") .. " " .. fs.quote(DIR .. "/machine") .. " " .. fs.quote(copy))
fs.run("cp -r " .. fs.quote(DIR .. "/tests/fixtures") .. " " .. fs.quote(copy .. "/tests/fixtures"))
fs.run("cp -r " .. fs.quote(project.fixtures .. "/tiny-notes") .. " " .. fs.quote(scratch .. "/tiny-notes"))

-- {{{ local function machine
-- One command through the real launcher (run with bash: the RAM tier does
-- not let files execute directly). Prints the command and its output.
local function machine(args, quiet)
    local line = "bash " .. fs.quote(copy .. "/machine") .. " " .. fs.quote(copy) .. " " .. args .. " 2>&1"
    local out = fs.capture(line)
    if not quiet then
        print("  $ machine " .. args)
        for l in out:gmatch("[^\n]+") do
            print("    " .. l)
        end
    end
    return out
end
-- }}}

local case_folder = copy .. "/cases/notes"

-- {{{ local function draw_center
-- The center as bars, straight from the case's ledger.
local function draw_center(label)
    local c = center.compute(ledger.read(case_folder .. "/ledger"))
    local top = center.heaviest(c, 6)
    local most = top[1] and top[1].weight or 1
    print("  THE CENTER " .. label .. "  (" .. c.lines .. " ledger lines)")
    for _, t in ipairs(top) do
        print(string.format("    %-22s %6.2f  %s", t.about, t.weight, string.rep("█", math.max(1, math.floor(t.weight / most * 30 + 0.5)))))
    end
end
-- }}}

-- {{{ local function drop
local function drop(name)
    fs.write(case_folder .. "/input/" .. name, fs.read(project.fixtures .. "/tiny-notes-requests/" .. name .. "/request"))
end
-- }}}

print("PHASE 7 — THE CENTER, AND THE WHOLE LOOP")
print("")
print("ONE COMMAND: source code in, working design out")
machine("open notes " .. fs.quote(scratch .. "/tiny-notes") .. " stand-in")
fs.write(case_folder .. "/stand-in.lua", "return dofile(" .. string.format("%q", copy .. "/tests/fixtures/tiny-notes.stand-in.lua")
    .. ")({ root = " .. string.format("%q", copy .. "/tests/fixtures") .. ", with_requests = true, broken_build = { [\"202\"] = 1 } })\n")
local t0 = wall()
machine("run notes")
print(string.format("  (%.2f s)", wall() - t0))
machine("run notes")
print("")
print("THE DESIGN, IN USE")
local notes_file = scratch .. "/notes.txt"
for _, args in ipairs({ "add buy oat milk '#home'", "add oil the '#bike' chain", "list" }) do
    local out = fs.capture("cd " .. fs.quote(case_folder .. "/design") .. " && NOTES_FILE=" .. fs.quote(notes_file) .. " luajit notes.lua " .. args)
    print("  $ notes " .. args)
    for l in out:gmatch("[^\n]+") do print("    " .. l) end
end
print("")
draw_center("after the first build")
print("")

print("REQUESTS ARRIVE — the center moves toward what is asked about")
drop("count-in-list")
machine("run notes")
draw_center("after 'count-in-list' (touches 301)")
print("")

-- Two at once. The machine notices them in the order their names sort;
-- the center then puts the most recently noticed first (its weight has had
-- the least time to fade) unless an older one touches heavier issues.
drop("hash-marked-tags")
drop("file-header")
print("  two requests arrive together: hash-marked-tags and file-header")
machine("run notes")
local noticed, handled = {}, {}
for _, l in ipairs(ledger.read(case_folder .. "/ledger")) do
    if l.kind == "request-received" and l.about ~= "count-in-list" then noticed[#noticed + 1] = l.about end
    if l.kind == "graded" and l.about ~= "count-in-list" then handled[#handled + 1] = l.about .. " (" .. l.text:match("^(%a+)") .. ")" end
end
print("  noticed in this order: " .. table.concat(noticed, ", "))
print("  the center handled them in this order: " .. table.concat(handled, ", "))
draw_center("after both were graded")
print("")
print("  file-header is foundation-grade: `run` leaves it to the person, who says --go")
machine("update notes --go")
draw_center("after the foundation change")
print("")

print("THE DESIGN NOW")
for _, args in ipairs({ "add call the dentist", "list" }) do
    local out = fs.capture("cd " .. fs.quote(case_folder .. "/design") .. " && NOTES_FILE=" .. fs.quote(notes_file) .. " luajit notes.lua " .. args)
    print("  $ notes " .. args)
    for l in out:gmatch("[^\n]+") do print("    " .. l) end
end
print("  first line of the notes file: " .. fs.read(notes_file):match("^[^\n]*"))
print("")

-- The whole story as numbers, from the ledger.
local counts = {}
for _, l in ipairs(ledger.read(case_folder .. "/ledger")) do
    counts[l.kind] = (counts[l.kind] or 0) + 1
end
print("THE LEDGER'S TOTALS")
for _, kind in ipairs({ "turn-started", "described", "built", "build-failed", "graded", "held", "request-done", "delivered", "goodbye" }) do
    print(string.format("  %-16s %4d  %s", kind, counts[kind] or 0, string.rep("▪", counts[kind] or 0)))
end
local verified = ledger.verify(case_folder .. "/ledger")
print(string.format("  chain %s, %d lines, head %s", verified.ok and "intact" or "BROKEN", verified.count, verified.head))
print("")

print("THE CASE AS ONE PAGE")
machine("view notes", true)
local page = project.scratch .. "/phase-7-case-view.html"
fs.write(page, fs.read(case_folder .. "/view.html"))
print("  " .. page .. "  (kept after the demo; the page checks its own ledger chain)")
if os.getenv("DISPLAY") and os.getenv("DISPLAY") ~= "" and not os.getenv("NO_BROWSER") then
    fs.run("firefox " .. fs.quote(page) .. " > /dev/null 2>&1 &")
    print("  opened in Firefox")
else
    print("  (no display, or NO_BROWSER set: not opened)")
end

-- The design's scratch space lives outside the demo folder.
local record_like = { name = "notes", folder = case_folder }
local key = design_folder.scratch_key(record_like)
fs.remove_tree("/tmp/burner-of-down-things/cases/" .. key)
fs.remove_tree("/dev/shm/burner-of-down-things/cases/" .. key)
fs.remove_tree(scratch)
