#!/usr/bin/env luajit
--[[
crowd-report.lua - the crowd benchmark's measurements, as a summary and a page (issue 515k)

What this is: reads what run-crowd.sh measured (every run's tick times,
the tick's parts from the serial measuring run, the threading code
counted) and writes a short markdown summary, then fills the viewer page
(src/viewers/ceramic-crowd.html) with the rows, the parts, the counts,
the GIFs' names and this machine's processor. It measures nothing itself,
and fails if the runs at any size disagree on the crowd's checksum.

Usage: luajit crowd-report.lua [OUT DIR]
  default: tmp/shared-memory/ceramic/crowd (reads crowd.tsv,
  crowd-parts.tsv, crowd-loc.tsv; writes crowd.md and ceramic-crowd.html)
]]

local DIR = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
local out_dir = arg[1] or (DIR .. "/tmp/shared-memory/ceramic/crowd")

-- {{{ local function read_file(path)
local function read_file(path)
    local f = assert(io.open(path, "r"))
    local text = f:read("*a")
    f:close()
    return text
end
-- }}}

-- {{{ local function fields(line)
local function fields(line)
    local f = {}
    for x in (line .. "\t"):gmatch("([^\t]*)\t") do f[#f + 1] = x end
    return f
end
-- }}}

-- {{{ the runs
-- Columns: way, threads, units, ticks, mean, median, p99, worst (ms),
-- checksum, round.
local rows, sums = {}, {}
local first = true
for line in io.lines(out_dir .. "/crowd.tsv") do
    if first then first = false else
        local f = fields(line)
        assert(#f == 10, "a run line with " .. #f .. " columns: " .. line)
        local r = { way = f[1], threads = tonumber(f[2]), units = tonumber(f[3]), ticks = tonumber(f[4]),
            mean = tonumber(f[5]), p50 = tonumber(f[6]), p99 = tonumber(f[7]), worst = tonumber(f[8]),
            check = f[9], round = tonumber(f[10]) }
        rows[#rows + 1] = r
        sums[r.units] = sums[r.units] or r.check
        assert(sums[r.units] == r.check, "at " .. r.units .. " units the runs disagree on where the units ended")
    end
end
-- }}}

-- {{{ the parts, and the threading code
-- Columns: units, ticks, snapshot, decide, settle, orders, floor, longest
-- unit (ms), hardware threads, crossings.
local parts = {}
first = true
for line in io.lines(out_dir .. "/crowd-parts.tsv") do
    if first then first = false else
        local f = fields(line)
        parts[#parts + 1] = string.format('{"units":%s,"ticks":%s,"snapshot":%s,"decide":%s,"settle":%s,"orders":%s,"floor":%s,"longest":%s,"hw":%s,"crossings":%s}',
            f[1], f[2], f[3], f[4], f[5], f[6], f[7], f[8], f[9], f[10])
    end
end
local loc = {}
first = true
for line in io.lines(out_dir .. "/crowd-loc.tsv") do
    if first then first = false else
        local name, n = line:match("^([^\t]+)\t(%d+)$")
        loc[#loc + 1] = string.format('{"name":"%s","lines":%s}', name, n)
    end
end
-- }}}

-- {{{ the markdown summary
local lines = {}
local function w(s) lines[#lines + 1] = s or "" end
w("# A crowd on every design (issue 515k)")
w("")
w("Every run at each size agreed on the checksum of every unit's position.")
w("")
w("| Units | Way | Mean (range over rounds) | Worst 99th percentile |")
w("|-------|-----|--------------------------|-----------------------|")
local seen, order = {}, {}
for _, r in ipairs(rows) do
    local k = r.units .. "|" .. r.way
    if not seen[k] then seen[k] = { lo = 1e18, hi = 0, p99 = 0, units = r.units, way = r.way }; order[#order + 1] = k end
    local s = seen[k]
    s.lo, s.hi, s.p99 = math.min(s.lo, r.mean), math.max(s.hi, r.mean), math.max(s.p99, r.p99)
end
for _, k in ipairs(order) do
    local s = seen[k]
    w(string.format("| %d | %s | %.3f – %.3f ms | %.2f ms |", s.units, s.way, s.lo, s.hi, s.p99))
end
local mf = assert(io.open(out_dir .. "/crowd.md", "w"))
mf:write(table.concat(lines, "\n"), "\n")
mf:close()
print(table.concat(lines, "\n"))
-- }}}

-- {{{ the page
local json = {}
for _, r in ipairs(rows) do
    json[#json + 1] = string.format('{"way":"%s","threads":%d,"units":%d,"ticks":%d,"mean":%.4f,"p50":%.4f,"p99":%.4f,"worst":%.4f,"round":%d}',
        r.way, r.threads, r.units, r.ticks, r.mean, r.p50, r.p99, r.worst, r.round)
end
local extra = string.format('{"parts":[%s],"loc":[%s]}', table.concat(parts, ","), table.concat(loc, ","))
local cpu = io.popen("lscpu"):read("*a")
local online = io.popen("nproc"):read("*l")
local governor = read_file("/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor"):gsub("%s+$", "")
local machine = string.format('{"model":"%s","cores":%d,"threads":%s,"governor":"%s"}',
    (cpu:match("Model name:%s*([^\n]+)") or "unknown processor"):gsub('"', "'"),
    (tonumber(cpu:match("Core%(s%) per socket:%s*(%d+)")) or 0) * (tonumber(cpu:match("Socket%(s%):%s*(%d+)")) or 1),
    online, governor)
local page = read_file(DIR .. "/src/viewers/ceramic-crowd.html")
local count
for marker, text in pairs({ ["/%*@@KIT%-CSS@@%*/"] = read_file(DIR .. "/src/viewers/ceramic-kit.css"),
                            ["/%*@@KIT%-JS@@%*/"] = read_file(DIR .. "/src/viewers/ceramic-kit.js"),
                            ["/%*@@DATA@@%*/%[%]"] = "[" .. table.concat(json, ",") .. "]",
                            ["/%*@@EXTRA@@%*/{}"] = extra,
                            ["/%*@@MACHINE@@%*/{}"] = machine }) do
    page, count = page:gsub(marker, function() return text end)
    assert(count == 1, "ceramic-crowd.html: marker " .. marker .. " found " .. count .. " times")
end
local hf = assert(io.open(out_dir .. "/ceramic-crowd.html", "w"))
hf:write(page)
hf:close()
-- }}}
