-- 018-the-case.lua
--
-- One folder per piece of software the machine handles: its record (where
-- the source is, which harness does the thinking, what the person wants the
-- design to be), its ledger, its lock, and the folders every later phase
-- fills. Opening makes the folder; loading reads it back with every path
-- filled in, so no other module assembles a case path by hand.
--
-- The case record (case.lua), docs/002-the-terms.md:
--   name     string   the folder name
--   source   string   absolute path of the source folder, links resolved
--   opened   string   YYYY-MM-DD HH:MM:SS
--   harness  string   a row of the harness table: "claude-code" or "stand-in"
--   target   string   the person's words for what the design should be; ""
--                     means "the same kind of software as the source"
--   hold     string   "none" | "middle" | "foundation": the update grade at
--                     and above which a request waits for the person (008)

local text_tables = require("014-text-tables")
local ledger = require("016-ledger")
local fs = require("017-the-filesystem")

local case = {}

-- The folders inside every case, made when it opens.
local CASE_FOLDERS = { "input", "output", "survey", "blueprint", "blueprint/issues", "design", "turns" }

-- Files in input/ that are settings, not requests.
local NOT_REQUESTS = { target = true, README = true }

-- {{{ local function check_name
local function check_name(name)
    -- Lower-case words joined by dashes: the name becomes a folder and a
    -- scratch-space name, so nothing that needs quoting is allowed.
    if type(name) ~= "string" or not name:match("^[a-z0-9]+[a-z0-9%-]*$") then
        error("case: a case name is lower-case words and dashes, got '" .. tostring(name) .. "'")
    end
end
-- }}}

-- {{{ local function fill_paths
-- Adds every path of the case to the record table, from the cases folder.
local function fill_paths(record, cases_folder)
    local folder = cases_folder .. "/" .. record.name
    record.folder = folder
    record.ledger = folder .. "/ledger"
    record.lock = folder .. "/lock"
    record.record_file = folder .. "/case.lua"
    record.input = folder .. "/input"
    record.output = folder .. "/output"
    record.survey = folder .. "/survey"
    record.blueprint = folder .. "/blueprint"
    record.issues = folder .. "/blueprint/issues"
    record.design = folder .. "/design"
    record.turns = folder .. "/turns"
    return record
end
-- }}}

-- {{{ local function inside
-- Whether `path` is `folder` or somewhere under it.
local function inside(path, folder)
    return path == folder or path:sub(1, #folder + 1) == folder .. "/"
end
-- }}}

-- {{{ function case.open
-- Makes a new case. `project` is the paths table (013).
function case.open(project, name, source, harness)
    check_name(name)
    harness = harness or "claude-code"
    -- Each refusal below names exactly what is wrong.
    if type(source) ~= "string" or not fs.is_folder(source) then
        error("case.open: the source folder does not exist: " .. tostring(source))
    end
    local real_source = fs.real_path(source)
    local real_project = fs.real_path(project.dir)
    -- Describing the machine into its own cases folder would make the source
    -- grow as it is read. A copy elsewhere is the way to survey the machine.
    if inside(real_source, real_project) then
        error("case.open: the source is inside this project (" .. real_source .. "); copy it elsewhere first")
    end
    fs.make_folder(project.cases)
    local record = fill_paths({ name = name }, project.cases)
    if fs.exists(record.folder) then
        error("case.open: a case named '" .. name .. "' already exists; cases are never overwritten")
    end
    for _, sub in ipairs(CASE_FOLDERS) do
        fs.make_folder(record.folder .. "/" .. sub)
    end
    local stored = {
        name = name,
        source = real_source,
        opened = os.date("%Y-%m-%d %H:%M:%S"),
        harness = harness,
        target = "",
        hold = "foundation",
    }
    text_tables.write_record(record.record_file, stored)
    ledger.create(record.ledger, "opened on " .. real_source .. " with harness " .. harness)
    return case.load(project, name)
end
-- }}}

-- {{{ function case.load
function case.load(project, name)
    check_name(name)
    local folder = project.cases .. "/" .. name
    if not fs.is_folder(folder) then
        error("case: no case named '" .. name .. "' in " .. project.cases)
    end
    local record = text_tables.read_record(folder .. "/case.lua")
    -- A case folder without its ledger is broken, not new: only opening
    -- creates a ledger, and a history cannot be restarted silently.
    if not fs.exists(folder .. "/ledger") then
        error("case: '" .. name .. "' has no ledger; the case is broken")
    end
    fill_paths(record, project.cases)
    -- The target may also be given as a file, in the person's own words.
    local target_file = record.input .. "/target"
    if fs.exists(target_file) then
        record.target = (fs.read(target_file):gsub("%s+$", ""))
    end
    return record
end
-- }}}

-- {{{ function case.save
-- Rewrites the stored fields of the record (not the filled-in paths).
function case.save(record)
    text_tables.write_record(record.record_file, {
        name = record.name, source = record.source, opened = record.opened,
        harness = record.harness, target = record.target or "", hold = record.hold or "foundation",
    })
end
-- }}}

-- {{{ function case.take_lock
function case.take_lock(record)
    local existing = io.open(record.lock, "rb")
    if existing then
        local held_by = existing:read("*a")
        existing:close()
        -- Refused whether the holder is alive or not: a lock left by a dead
        -- process is evidence of a crash, and the person should see it.
        error("case: '" .. record.name .. "' is locked (" .. held_by:gsub("\n", " ")
            .. "); if that process is gone, remove " .. record.lock .. " by hand")
    end
    -- The process id of the luajit running us is the parent of a shell we
    -- start, so the shell's $PPID is our own id.
    local pid = fs.capture("echo $PPID")
    local file = assert(io.open(record.lock, "wb"))
    file:write("pid ", (pid:gsub("%s+$", "")), " since ", os.date("%Y-%m-%d %H:%M:%S"), "\n")
    file:close()
end
-- }}}

-- {{{ function case.drop_lock
function case.drop_lock(record)
    os.remove(record.lock)
end
-- }}}

-- {{{ function case.requests
-- Every request file in input/, and which of them are new: not yet named by a
-- request-received line. Returns (all, new), each an array of file names.
function case.requests(record, ledger_lines)
    local seen = {}
    for _, line in ipairs(ledger_lines) do
        if line.kind == "request-received" then
            seen[line.about] = true
        end
    end
    local all, new = {}, {}
    for _, name in ipairs(fs.list(record.input)) do
        -- Settings files, and the machine's own half-written files, are not
        -- requests.
        if not NOT_REQUESTS[name] and not name:match("%.writing$") and not name:match("^%.") then
            all[#all + 1] = name
            if not seen[name] then
                new[#new + 1] = name
            end
        end
    end
    return all, new
end
-- }}}

return case
