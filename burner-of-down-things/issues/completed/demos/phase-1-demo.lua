-- phase-1-demo.lua
--
-- The phase 1 demonstration, run by phase-1-demo. Numbers first: how fast the
-- ledger grows and verifies, how fast SHA-256 runs; then the chain drawn
-- around a tampered line, twice — once with the text changed, once with the
-- forger also fixing that line's checksum.

local DIR = arg[1]
local paths_module = dofile(DIR .. "/src/013-paths.lua")
paths_module.set_search_path(DIR)
local project = paths_module.for_project(DIR)

local text_tables = require("014-text-tables")
local sha_256 = require("015-sha-256")
local ledger = require("016-ledger")
local fs = require("017-the-filesystem")
local case = require("018-the-case")

local LINES = 30000
local TAMPER_AT = 15000

-- {{{ local function clock
local function clock()
    return os.clock()
end
-- }}}

-- {{{ local function bar
local function bar(value, max, width)
    local filled = math.floor(value / max * width + 0.5)
    return string.rep("█", filled) .. string.rep("·", width - filled)
end
-- }}}

-- A scratch project so the demo's case never lands in the real cases/.
local scratch = project.scratch .. "/demo-phase-1"
if fs.is_folder(scratch) then
    fs.remove_tree(scratch)
end
fs.make_folder(scratch .. "/source")
fs.write(scratch .. "/source/hello.lua", "print('hello')\n")
local demo_project = {}
for k, v in pairs(project) do
    demo_project[k] = v
end
demo_project.cases = scratch .. "/cases"

print("PHASE 1 — THE CASE AND THE LEDGER")
print("")

local record = case.open(demo_project, "demo", scratch .. "/source", "stand-in")
print("case opened:   " .. record.folder)

-- The events a real case produces, cycled, so the ledger looks like one.
local KINDS = { "request-received", "turn-started", "turn-ended", "described", "built", "graded" }
local t0 = clock()
for i = 2, LINES do
    local kind = KINDS[(i % #KINDS) + 1]
    ledger.append(record.ledger, kind, tostring(100 + i % 40), "event number " .. i)
end
local append_seconds = clock() - t0

t0 = clock()
local verified = ledger.verify(record.ledger)
local verify_seconds = clock() - t0

local blob = string.rep("the machine remembers. ", 45000)
t0 = clock()
sha_256.of_string(blob)
local sha_seconds = clock() - t0
local sha_mb = #blob / 1e6 / sha_seconds

local size = #fs.read(record.ledger)

print("")
print(string.format("  ledger lines           %8d", verified.count))
print(string.format("  ledger size            %8.1f MB", size / 1e6))
local append_rate = LINES / append_seconds
local verify_rate = verified.count / verify_seconds
local top = math.max(append_rate, verify_rate)
print(string.format("  appended   %8.0f lines/s  %s", append_rate, bar(append_rate, top, 30)))
print(string.format("  verified   %8.0f lines/s  %s", verify_rate, bar(verify_rate, top, 30)))
print(string.format("  SHA-256    %8.1f MB/s     (pure LuaJIT, no outside program)", sha_mb))
print("")
print("  head hash  " .. verified.head)
print("")

-- {{{ local function draw_chain
-- Draws lines around `center`: each line's prev and hash prefixes, with a
-- mark where the chain breaks.
local function draw_chain(path, center, broken_line)
    local lines = {}
    local n = 0
    for line in io.lines(path) do
        n = n + 1
        if n >= center - 2 and n <= center + 2 then
            lines[#lines + 1] = { n = n, fields = text_tables.split_line(line) }
        end
        if n > center + 2 then
            break
        end
    end
    for _, l in ipairs(lines) do
        local f = l.fields
        local mark = "  "
        if l.n == broken_line then
            mark = "✗ "
        end
        print(string.format("   %s%6d  prev %s…  hash %s…  %s", mark, l.n, f[6]:sub(1, 10), f[7]:sub(1, 10), text_tables.unescape(f[5])))
    end
end
-- }}}

-- {{{ local function rewrite_line
local function rewrite_line(path, number, change)
    local out = {}
    local n = 0
    for line in io.lines(path) do
        n = n + 1
        if n == number then
            line = change(line)
        end
        out[#out + 1] = line
    end
    fs.write(path, table.concat(out, "\n") .. "\n")
end
-- }}}

print(string.format("TAMPERING 1: one character of line %d's text changed", TAMPER_AT))
rewrite_line(record.ledger, TAMPER_AT, function(line)
    return (line:gsub("event number", "Event number", 1))
end)
local r1 = ledger.verify(record.ledger)
draw_chain(record.ledger, TAMPER_AT, r1.line)
print("   verifier: " .. ledger.describe_failure(r1))
print("")

print(string.format("TAMPERING 2: the forger also recomputes line %d's own hash", TAMPER_AT))
rewrite_line(record.ledger, TAMPER_AT, function(line)
    local f = text_tables.split_line(line)
    f[7] = sha_256.of_string(table.concat({ f[1], f[2], f[3], f[4], f[5], f[6] }, "\t"))
    return table.concat(f, "\t")
end)
local r2 = ledger.verify(record.ledger)
draw_chain(record.ledger, TAMPER_AT, r2.line)
print("   verifier: " .. ledger.describe_failure(r2))
print("")
print(string.format("To hide one changed character, a forger must rehash all %d lines after it,",
    verified.count - TAMPER_AT))
print("and the head hash — the fingerprint anyone holding a copy can compare — changes anyway.")

fs.remove_tree(scratch)
