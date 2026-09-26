-- 024-checking-the-case.lua
--
-- Checks the case folder (issue 105): opening makes every folder and one
-- ledger line, a name is never reused, the lock refuses a second holder, and
-- only new files in input/ count as new requests.

local kit = dofile(arg[1] .. "/tests/020-checking-kit.lua")
local case = require("018-the-case")
local ledger = require("016-ledger")
local fs = kit.fs

local project, folder = kit.project_copy("case")
local source = folder .. "/source"
kit.write_file(source .. "/main.lua", "print(1)\n")

local record = case.open(project, "first-case", source, "stand-in")
for _, sub in ipairs({ "input", "output", "survey", "blueprint", "blueprint/issues", "design", "turns" }) do
    kit.check(fs.is_folder(record.folder .. "/" .. sub), "made " .. sub)
end
kit.equal(ledger.verify(record.ledger).count, 1, "one ledger line after open")
kit.equal(record.harness, "stand-in", "harness recorded")
kit.equal(record.hold, "foundation", "hold defaults to foundation")
kit.equal(record.source, fs.real_path(source), "source stored with links resolved")

kit.raises(function() case.open(project, "first-case", source) end, "already exists", "a name is never reused")
kit.raises(function() case.open(project, "Bad Name", source) end, "lower-case", "a bad name is refused")
kit.raises(function() case.open(project, "no-source", folder .. "/missing") end, "does not exist", "a missing source is refused")
kit.raises(function() case.open(project, "itself", kit.DIR .. "/src") end, "inside this project",
    "the machine's own folder is refused")

-- The lock.
case.take_lock(record)
kit.raises(function() case.take_lock(record) end, "is locked (pid", "a second lock names the first holder")
case.drop_lock(record)
case.take_lock(record)
case.drop_lock(record)
kit.check(not fs.exists(record.lock), "the lock is gone after drop")

-- Requests: only unnoticed files are new; target and README are settings.
kit.write_file(record.input .. "/make-it-blue", "make it blue\n")
kit.write_file(record.input .. "/add-sound", "add sound\n")
kit.write_file(record.input .. "/target", "a Lua program\n")
ledger.append(record.ledger, "request-received", "make-it-blue", "noticed")
local all, new = case.requests(record, ledger.read(record.ledger))
kit.equal(#all, 2, "two requests in all")
kit.equal(#new, 1, "one new request")
kit.equal(new[1], "add-sound", "the new one is add-sound")

-- The target file is read into the record on load.
local loaded = case.load(project, "first-case")
kit.equal(loaded.target, "a Lua program", "target read from input/target")
kit.raises(function() case.load(project, "never-opened") end, "no case named", "loading a missing case is refused")

-- A case without its ledger is broken.
os.remove(record.ledger)
kit.raises(function() case.load(project, "first-case") end, "no ledger", "a case with no ledger is refused")

kit.finish()
