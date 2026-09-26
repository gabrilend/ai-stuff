-- 025-checking-the-machine.lua
--
-- Checks the command dispatcher (issue 106) by running the real launcher as
-- a person would, against a scratch copy of the project so the real cases/
-- is never touched: open, ledger, a refused lock, a failing command still
-- leaving its goodbye, and unknown commands.

local kit = dofile(arg[1] .. "/tests/020-checking-kit.lua")
local fs = kit.fs
local ledger = require("016-ledger")

-- A copy of the project's code in scratch space: the launcher is pointed at
-- it with its folder argument, so cases land in the copy.
local folder = kit.scratch("machine")
local copy = folder .. "/project"
fs.make_folder(copy)
fs.run("cp -r " .. fs.quote(kit.DIR .. "/src") .. " " .. fs.quote(kit.DIR .. "/machine") .. " " .. fs.quote(copy))
fs.make_folder(copy .. "/input")
-- A real tmp/ folder (not a link) is left alone by the RAM tier helper, so
-- the copy never creates scratch space named after itself in /tmp.
fs.make_folder(copy .. "/tmp/shared-memory")
local source = folder .. "/source"
kit.write_file(source .. "/a.lua", "return 1\n")

-- {{{ local function machine
local function machine(args)
    -- Run through bash: the RAM artifact tier is mounted without permission
    -- to execute files directly.
    local out, ok = fs.capture("bash " .. fs.quote(copy .. "/machine") .. " " .. fs.quote(copy) .. " " .. args .. " 2>&1")
    return out, ok
end
-- }}}

local out, ok = machine("open alpha " .. fs.quote(source) .. " stand-in")
kit.check(ok, "open succeeds: " .. out)
local case_folder = copy .. "/cases/alpha"
local lines = ledger.read(case_folder .. "/ledger")
kit.equal(lines[1].kind, "case-opened", "first line case-opened")
kit.equal(lines[2].kind, "goodbye", "second line goodbye")
kit.check(fs.exists(case_folder .. "/output/goodbye"), "case goodbye written")
kit.check(fs.exists(copy .. "/output/goodbye"), "project goodbye written")

out, ok = machine("ledger alpha")
kit.check(ok, "ledger succeeds")
local count = tonumber(out:match("lines (%d+)"))
local head = out:match("head  (%x+)")
kit.equal(count, 2, "ledger printed 2 lines (its own goodbye comes after)")
kit.equal(ledger.read(case_folder .. "/ledger")[2].hash, head, "printed head is line 2's hash")

-- A new request is noticed before the command's work.
kit.write_file(case_folder .. "/input/wish", "a wish\n")
machine("ledger alpha")
lines = ledger.read(case_folder .. "/ledger")
kit.equal(lines[4].kind, "request-received", "request noticed first")
kit.equal(lines[4].about, "wish", "request named")

-- A held lock refuses the run and leaves the ledger untouched.
local before = #ledger.read(case_folder .. "/ledger")
kit.write_file(case_folder .. "/lock", "pid 1 since earlier\n")
out, ok = machine("ledger alpha")
kit.check(not ok, "a locked case refuses")
kit.check(out:find("is locked", 1, true) ~= nil, "refusal says locked")
kit.equal(#ledger.read(case_folder .. "/ledger"), before, "a refused run appends nothing")
kit.check(fs.read(case_folder .. "/output/goodbye"):find("is locked", 1, true) ~= nil, "goodbye says why")
os.remove(case_folder .. "/lock")

-- A broken ledger stops the run before its work, and is left as found.
local ledger_text = fs.read(case_folder .. "/ledger")
kit.write_file(case_folder .. "/ledger", (ledger_text:gsub("a wish", "b wish", 1):gsub("noticed in input/", "noticed in inpuT/", 1)))
local broken = fs.read(case_folder .. "/ledger")
out, ok = machine("ledger alpha")
kit.check(not ok, "a broken ledger stops the run")
kit.equal(fs.read(case_folder .. "/ledger"), broken, "the broken ledger is left as found")
kit.check(not fs.exists(case_folder .. "/lock"), "the lock is dropped after a failure")

-- Unknown command and missing case.
out, ok = machine("frobnicate")
kit.check(not ok and out:find("unknown command", 1, true), "unknown command refused with the table")
out, ok = machine("ledger nobody")
kit.check(not ok and out:find("no case named", 1, true), "missing case refused")

kit.finish()
