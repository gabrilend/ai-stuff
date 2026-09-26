-- 048-the-design-folder.lua
--
-- Laying out a case's design/ folder as a house project the first time the
-- case builds (docs/007, "the design folder"). The layout is the owner's own
-- skeleton tool's, run with --skeleton-only; the machine does not invent a
-- layout of its own, and refuses when the tool is missing.
--
-- The RAM scratch space: the skeleton tool names a project's scratch space
-- after its folder, and every case's design folder is called "design", so
-- every case would share one. The machine therefore makes both doors first —
-- design/tmp -> /tmp/burner-of-down-things/cases/<key>, and inside it
-- shared-memory -> /dev/shm/burner-of-down-things/cases/<key> — and the tool
-- honours doors that already exist. <key> is the case name and the first 8
-- characters of the SHA-256 of the case folder's path, so two cases with the
-- same name in different places (a test's scratch case and a real one) never
-- share scratch space.

local ledger = require("016-ledger")
local fs = require("017-the-filesystem")
local sha_256 = require("015-sha-256")

local design_folder = {}

-- {{{ function design_folder.scratch_key
function design_folder.scratch_key(record)
    return record.name .. "-" .. sha_256.of_string(record.folder):sub(1, 8)
end
-- }}}

-- {{{ local function make_doors
local function make_doors(record)
    local key = design_folder.scratch_key(record)
    local exec_tier = "/tmp/burner-of-down-things/cases/" .. key
    local artifact_tier = "/dev/shm/burner-of-down-things/cases/" .. key
    fs.make_folder(exec_tier .. "/tmp")
    fs.make_folder(artifact_tier)
    if not fs.exists(exec_tier .. "/shared-memory") then
        if not fs.run("ln -s " .. fs.quote(artifact_tier) .. " " .. fs.quote(exec_tier .. "/shared-memory")) then
            error("design folder: could not link " .. exec_tier .. "/shared-memory")
        end
    end
    local door = record.design .. "/tmp"
    if not fs.run("test -L " .. fs.quote(door)) then
        if not fs.run("ln -s " .. fs.quote(exec_tier) .. " " .. fs.quote(door)) then
            error("design folder: could not link " .. door)
        end
    end
end
-- }}}

-- {{{ function design_folder.lay_out
-- Returns true when it laid the folder out now, false when it already was.
function design_folder.lay_out(project, record)
    if fs.is_folder(record.design .. "/src") then
        return false
    end
    if not fs.exists(project.init_project) then
        error("design folder: the house skeleton tool is missing at " .. project.init_project)
    end
    fs.make_folder(record.design)
    make_doors(record)
    local out, ok = fs.capture("bash " .. fs.quote(project.init_project) .. " --skeleton-only "
        .. fs.quote(record.design) .. " 2>&1")
    if not ok then
        error("design folder: the skeleton tool failed:\n" .. out)
    end
    fs.write(record.design .. "/README", table.concat({
        "This folder is a design built by the machine in burner-of-down-things",
        "from the blueprint of case '" .. record.name .. "', never from its source.",
        "",
        "The blueprint:  " .. record.blueprint,
        "The ledger's head when this folder was laid out:  " .. (ledger.head(record.ledger) or "-"),
        "",
    }, "\n"))
    fs.write(record.output .. "/first-build", table.concat({
        "The first build of this case has started.",
        "",
        "Each issue of the blueprint names acceptance commands, written by a model.",
        "The machine runs exactly those commands, one at a time, from the design",
        "folder, under a time limit:",
        "",
        "  " .. record.design,
        "",
        "They run with your permissions. They are not walled off from the rest of",
        "the machine (docs/010, question 3, asks whether they should be).",
        "",
    }, "\n"))
    return true
end
-- }}}

return design_folder
