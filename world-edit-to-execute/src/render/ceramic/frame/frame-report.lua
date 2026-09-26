#!/usr/bin/env luajit
-- frame-report.lua - the fabricated frame's measurements, as a report and a page (issue 515h)
--
-- In plain terms: reads what run-frame.sh measured (every run's frame
-- times, the floor worked out from the plan, the threading code counted)
-- and writes a short markdown summary, then fills the viewer page
-- (src/viewers/ceramic-frame.html) with the rows, the plan's own numbers
-- (read from frame-plan.h, so the page and the code can't disagree), the
-- shared kit and this machine's processor. It measures nothing itself, and
-- fails if the runs don't all agree on the frame's checksum.
--
-- Usage: luajit frame-report.lua [OUT DIR]
--   default: tmp/shared-memory/ceramic (reads frame.tsv, frame-bounds.tsv,
--   frame-loc.tsv there; writes frame.md and ceramic-frame.html)

local DIR = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
local out_dir = arg[1] or (DIR .. "/tmp/shared-memory/ceramic")

-- {{{ local function read_file
local function read_file(path)
    local f = assert(io.open(path, "r"))
    local text = f:read("*a")
    f:close()
    return text
end
-- }}}

-- {{{ the runs
-- Columns: way, background, frames, workers, mean, p50, p95, p99, worst,
-- checksum, decodes finished. The last line carries the calibration.
local rows, rounds, checks = {}, nil, {}
for line in io.lines(out_dir .. "/frame.tsv") do
    local f = {}
    for x in (line .. "\t"):gmatch("([^\t]*)\t") do f[#f + 1] = x end
    if f[1] == "rounds" then
        rounds = tonumber(f[2])
    else
        assert(#f == 11, "a run line with " .. #f .. " columns: " .. line)
        rows[#rows + 1] = { way = f[1], bg = tonumber(f[2]), frames = tonumber(f[3]), workers = tonumber(f[4]),
            mean = tonumber(f[5]), p50 = tonumber(f[6]), p95 = tonumber(f[7]), p99 = tonumber(f[8]), worst = tonumber(f[9]),
            check = f[10], decoded = tonumber(f[11]) }
        checks[f[10]] = true
    end
end
local distinct = 0
for _ in pairs(checks) do distinct = distinct + 1 end
assert(distinct == 1, "the runs disagree on the frame's checksum (" .. distinct .. " different answers)")
assert(rounds, "frame.tsv has no calibration line")
-- }}}

-- {{{ the floor and the threading code
local b = {}
for x in (read_file(out_dir .. "/frame-bounds.tsv"):gsub("\n", "") .. "\t"):gmatch("([^\t]*)\t") do b[#b + 1] = tonumber(x) end
local bounds = { chain = b[1], work = b[2], best = b[3], pose = b[4] }
local loc = {}
for line in io.lines(out_dir .. "/frame-loc.tsv") do
    local name, n = line:match("^([^\t]+)\t(%d+)$")
    loc[name] = tonumber(n)
end
-- the map is written by a tool: count the tool's own code lines too
local gen = 0
for line in io.lines(DIR .. "/src/render/ceramic/frame/frame-gen.lua") do
    if line:match("%S") and not line:match("^%s*%-%-") then gen = gen + 1 end
end
loc["ceramic map generator"] = gen
-- }}}

-- {{{ the plan's numbers, from frame-plan.h
local plan = {}
for name, value in read_file(DIR .. "/src/render/ceramic/frame/frame-plan.h"):gmatch("#define ([A-Z_]+) (%d+)") do
    plan[name] = tonumber(value)
end
for _, need in ipairs({ "FRAME_PLAYERS", "FRAME_LANES", "FRAME_UNITS_PER_LANE", "FRAME_PATHS_MIN", "FRAME_PATHS_MAX",
                        "FRAME_DECODES", "SIM_US", "CULL_US", "DECODE_US" }) do
    assert(plan[need], "frame-plan.h has no " .. need)
end
-- }}}

-- {{{ the markdown summary
local lines = {}
local function w(s) lines[#lines + 1] = s or "" end
w("# A frame as a graph (issue 515h)")
w("")
w(string.format("Every run agreed on the checksum. %d rounds of work per microsecond on this machine.", rounds))
w(string.format("Floor from the plan: longest chain %.0f us, total work %.0f us, best possible %.0f us; a pose lane %.0f us.",
    bounds.chain, bounds.work, bounds.best, bounds.pose))
w("")
w("| Way | Background | Mean (range over repeats) | Worst 99th percentile | Decodes |")
w("|-----|------------|---------------------------|-----------------------|---------|")
local seen, order = {}, {}
for _, r in ipairs(rows) do
    local k = r.way .. "|" .. r.bg
    if not seen[k] then seen[k] = { lo = 1e18, hi = 0, p99 = 0, decoded = r.decoded, way = r.way, bg = r.bg }; order[#order + 1] = k end
    local s = seen[k]
    if r.mean < s.lo then s.lo = r.mean end
    if r.mean > s.hi then s.hi = r.mean end
    if r.p99 > s.p99 then s.p99 = r.p99 end
end
for _, k in ipairs(order) do
    local s = seen[k]
    w(string.format("| %s | %s | %.0f – %.0f us | %.0f us | %d |", s.way, s.bg == 1 and "yes" or "no", s.lo, s.hi, s.p99, s.decoded))
end
w("")
w("Threading code (lines): " .. string.format("hand-written %d; ceramic host %d, map %d (written by a %d-line tool).",
    loc["hand-written"], loc["ceramic host"], loc["ceramic map"], gen))
local mf = assert(io.open(out_dir .. "/frame.md", "w"))
mf:write(table.concat(lines, "\n"), "\n")
mf:close()
print(table.concat(lines, "\n"))
-- }}}

-- {{{ the page
local json = {}
for _, r in ipairs(rows) do
    json[#json + 1] = string.format('{"way":"%s","bg":%d,"frames":%d,"workers":%d,"mean":%.1f,"p50":%.1f,"p95":%.1f,"p99":%.1f,"worst":%.1f,"decoded":%d}',
        r.way, r.bg, r.frames, r.workers, r.mean, r.p50, r.p95, r.p99, r.worst, r.decoded)
end
local plan_json = {}
for k, v in pairs(plan) do plan_json[#plan_json + 1] = string.format('"%s":%d', k, v) end
local extra = string.format('{"bounds":{"chain":%.1f,"work":%.1f,"best":%.1f,"pose":%.1f},"loc":{"hand":%d,"host":%d,"map":%d,"gen":%d},"rounds":%d,"plan":{%s}}',
    bounds.chain, bounds.work, bounds.best, bounds.pose, loc["hand-written"], loc["ceramic host"], loc["ceramic map"], gen, rounds,
    table.concat(plan_json, ","))
local cpu = io.popen("lscpu"):read("*a")
local online = io.popen("nproc"):read("*l")
-- the power governor and the lowest clock it idles a core at (cpu0 stands
-- for all); both explain why threads that sleep between stages run slow
local governor = read_file("/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor"):gsub("%s+$", "")
local idle_mhz = math.floor(tonumber((read_file("/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_min_freq"):gsub("%s+$", ""))) / 1000 + 0.5)
local machine = string.format('{"model":"%s","cores":%d,"threads":%s,"frames":%d,"governor":"%s","idle_mhz":%d}',
    (cpu:match("Model name:%s*([^\n]+)") or "unknown processor"):gsub('"', "'"),
    (tonumber(cpu:match("Core%(s%) per socket:%s*(%d+)")) or 0) * (tonumber(cpu:match("Socket%(s%):%s*(%d+)")) or 1),
    online, rows[1].frames, governor, idle_mhz)
local page = read_file(DIR .. "/src/viewers/ceramic-frame.html")
local count
for marker, text in pairs({ ["/%*@@KIT%-CSS@@%*/"] = read_file(DIR .. "/src/viewers/ceramic-kit.css"),
                            ["/%*@@KIT%-JS@@%*/"] = read_file(DIR .. "/src/viewers/ceramic-kit.js"),
                            ["/%*@@DATA@@%*/%[%]"] = "[" .. table.concat(json, ",") .. "]",
                            ["/%*@@EXTRA@@%*/{}"] = extra,
                            ["/%*@@MACHINE@@%*/{}"] = machine }) do
    page, count = page:gsub(marker, function() return text end)
    assert(count == 1, "ceramic-frame.html: marker " .. marker .. " found " .. count .. " times")
end
local hf = assert(io.open(out_dir .. "/ceramic-frame.html", "w"))
hf:write(page)
hf:close()
-- }}}
