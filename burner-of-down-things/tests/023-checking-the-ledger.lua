-- 023-checking-the-ledger.lua
--
-- Checks the chained ledger (issue 104): lines chain, every kind of tampering
-- is caught at the exact line, and appending stays fast as the ledger grows.

local kit = dofile(arg[1] .. "/tests/020-checking-kit.lua")
local ledger = require("016-ledger")
local fs = kit.fs

local folder = kit.scratch("ledger")
local path = folder .. "/ledger"

-- Create and append: seq counts up, each prev is the last hash.
local first = ledger.create(path, "first")
kit.equal(first.seq, 1, "first line is 1")
kit.equal(first.prev, ledger.ZERO_HASH, "first prev is zeroes")
local second = ledger.append(path, "surveyed", "-", "two\twith a tab")
kit.equal(second.seq, 2, "second line is 2")
kit.equal(second.prev, first.hash, "second prev is first hash")
local third = ledger.append(path, "built", "101", "three")
kit.equal(third.prev, second.hash, "third prev is second hash")
kit.equal(ledger.head(path), third.hash, "head is the last hash")
kit.raises(function() ledger.create(path, "again") end, "already exists", "create refuses an existing ledger")
kit.raises(function() ledger.append(folder .. "/none", "built", "-", "") end, "no ledger", "append refuses a missing ledger")
kit.raises(function() ledger.append(path, "made-up-kind", "-", "") end, "unknown kind", "append refuses an unknown kind")

local read = ledger.read(path)
kit.equal(read[2].text, "two\twith a tab", "text unescaped on read")

for i = 4, 10 do
    ledger.append(path, "turn-ended", "t" .. i, "line " .. i)
end
local ok = ledger.verify(path)
kit.check(ok.ok, "a clean ledger verifies")
kit.equal(ok.count, 10, "ten lines")

-- {{{ local function lines_of
local function lines_of(p)
    local out = {}
    for line in io.lines(p) do
        out[#out + 1] = line
    end
    return out
end
-- }}}

-- {{{ local function write_lines
local function write_lines(p, lines)
    kit.write_file(p, table.concat(lines, "\n") .. "\n")
end
-- }}}

local clean = lines_of(path)

-- One character of line 5's text changed: line 5's own hash fails.
local tampered = { unpack(clean) }
tampered[5] = tampered[5]:gsub("line 5", "line 6")
local p1 = folder .. "/tampered-text"
write_lines(p1, tampered)
local r1 = ledger.verify(p1)
kit.check(not r1.ok and r1.line == 5 and r1.check == "hash", "changed text caught at line 5 (self hash)")

-- Line 5's hash recomputed to match: line 6's prev fails.
local sha_256 = require("015-sha-256")
local text_tables = require("014-text-tables")
local f = text_tables.split_line(tampered[5])
f[7] = sha_256.of_string(table.concat({ f[1], f[2], f[3], f[4], f[5], f[6] }, "\t"))
tampered[5] = table.concat(f, "\t")
local p2 = folder .. "/tampered-rehashed"
write_lines(p2, tampered)
local r2 = ledger.verify(p2)
kit.check(not r2.ok and r2.line == 6 and r2.check == "prev", "rehashed line caught at line 6 (prev)")

-- Line 5 deleted: line 5 now has seq 6.
local deleted = { unpack(clean) }
table.remove(deleted, 5)
local p3 = folder .. "/deleted"
write_lines(p3, deleted)
local r3 = ledger.verify(p3)
kit.check(not r3.ok and r3.line == 5 and r3.check == "seq", "deleted line caught at line 5 (seq)")
kit.check(ledger.describe_failure(r3):find("line 5", 1, true) ~= nil, "failure sentence names the line")

-- Appending stays constant-time: time for 500 appends at 1 000 lines and at
-- 20 000 lines should be within a small factor.
local big = folder .. "/big"
ledger.create(big, "big")
for i = 2, 1000 do
    ledger.append(big, "turn-ended", "-", "x")
end
local t0 = os.clock()
for i = 1, 500 do
    ledger.append(big, "turn-ended", "-", "x")
end
local early = os.clock() - t0
for i = 1, 18500 do
    ledger.append(big, "turn-ended", "-", "x")
end
t0 = os.clock()
for i = 1, 500 do
    ledger.append(big, "turn-ended", "-", "x")
end
local late = os.clock() - t0
kit.check(late < early * 3 + 0.05, string.format("append time does not grow (%.3fs early, %.3fs late)", early, late))
kit.check(ledger.verify(big).ok, "a 20 500 line ledger verifies")

kit.finish()
