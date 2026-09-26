#!/usr/bin/env luajit
-- analysis-report.lua - turns the analysis's measurements into a readable report
--
-- In plain terms: reads the table run-analysis.sh wrote (one timed run per
-- line) and writes a markdown report, sweep by sweep, with the numbers a
-- person wants rather than the raw ones: what one task costs, how much of
-- a frame goes to handing work in, how the time falls as cores are added,
-- how steady the frames are. It also writes the same numbers as JSON, and
-- fills the two viewer pages -- ceramic-analysis.html (the stock engine)
-- and ceramic-lockfree.html (the kept copy's task queue) -- with them, the
-- shared kit (ceramic-kit.css / .js) and this machine's processor, so each
-- page draws offline as one self-contained file. It
-- measures nothing itself.
--
-- Usage: luajit analysis-report.lua [TSV] [OUT DIR]
--   defaults: tmp/shared-memory/ceramic/analysis.tsv, same folder
--   writes analysis.md, analysis.json, ceramic-analysis.html, ceramic-lockfree.html

local DIR = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
local tsv = arg[1] or (DIR .. "/tmp/shared-memory/ceramic/analysis.tsv")
local out_dir = arg[2] or (DIR .. "/tmp/shared-memory/ceramic")
local FRAME = 16667   -- microseconds in a 60 fps frame

-- {{{ read the measurements
-- Columns: sweep, way, units, units per task, workers, frames, mean, p50,
-- p95, p99, worst, delivering, landing wait, checksum.
local rows = {}
for line in io.lines(tsv) do
    local f = {}
    for field in (line .. "\t"):gmatch("([^\t]*)\t") do f[#f + 1] = field end
    assert(#f == 14, "a line with " .. #f .. " columns, not 14: " .. line)
    rows[#rows + 1] = {
        sweep = f[1], way = f[2], units = tonumber(f[3]), per = tonumber(f[4]), workers = tonumber(f[5]),
        frames = tonumber(f[6]), mean = tonumber(f[7]), p50 = tonumber(f[8]), p95 = tonumber(f[9]),
        p99 = tonumber(f[10]), worst = tonumber(f[11]), deliver = tonumber(f[12]), land = tonumber(f[13]),
        check = f[14],
    }
end
-- }}}

-- {{{ local function in_sweep
local function in_sweep(name)
    local list = {}
    for _, r in ipairs(rows) do if r.sweep == name then list[#list + 1] = r end end
    return list
end
-- }}}

-- {{{ local function find
local function find(sweep, way, units, workers)
    for _, r in ipairs(rows) do
        if r.sweep == sweep and r.way == way and (not units or r.units == units) and (not workers or r.workers == workers) then return r end
    end
    error("no measurement: " .. sweep .. " " .. way .. " " .. tostring(units) .. " " .. tostring(workers))
end
-- }}}

local lines = {}
local function w(s) lines[#lines + 1] = s or "" end
local function f1(x) return string.format("%.1f", x) end
local function pct(x) return string.format("%.1f%%", 100 * x / FRAME) end
-- (the scale sweep's rows now include the shared counter; find() picks by way)

-- the checksums: every way that computes poses must agree with the plain loop
local truth = {}
for _, r in ipairs(rows) do if r.way == "plain-loop" then truth[r.units] = r.check end end
local disagree = {}
for _, r in ipairs(rows) do
    if r.check ~= "00000000" and truth[r.units] and r.check ~= truth[r.units] then
        disagree[#disagree + 1] = string.format("%s %s at %d units", r.sweep, r.way, r.units)
    end
end

w("# The ceramic engine under a renderer's load (issue 515a)")
w("")
w("Every row is one run of " .. rows[1].frames .. " frames. Times are microseconds; a 60 fps frame is " .. FRAME .. ".")
w("The work is posing a 30-bone skeleton per unit (the same function every way).")
w(#disagree == 0 and "Every way that computes poses produced the same poses as the plain loop (checksums agree)."
    or ("**Checksums disagree:** " .. table.concat(disagree, "; ")))

-- {{{ anatomy
w("")
w("## Anatomy of a task (2048 units, one task each unless noted)")
w("")
w("| Way | Frame (mean) | Per task | Host delivering | Share of a frame |")
w("|-----|--------------|----------|-----------------|------------------|")
for _, r in ipairs(in_sweep("anatomy")) do
    local tasks = r.per > 0 and r.units / r.per or 1
    w(string.format("| %s | %s | %s | %s | %s |", r.way .. (r.per > 1 and (" (" .. r.per .. " per task)") or ""),
        f1(r.mean), r.per > 0 and f1(r.mean / tasks) or "", r.per > 0 and f1(r.deliver) or "", pct(r.mean)))
end
local plain = find("anatomy", "plain-loop")
w("")
w(string.format("The work itself: %s µs per unit on one thread (the plain loop over 2048 units).", string.format("%.2f", plain.mean / 2048)))
-- }}}

-- {{{ size
w("")
w("## What an answer's size costs (256 tasks per frame, no pose work)")
w("")
w("| Answer | Frame (mean) | Per task | Host delivering |")
w("|--------|--------------|----------|-----------------|")
for _, r in ipairs(in_sweep("size")) do
    local bytes = r.way:match("make_blob_(%d+)") or "4 (empty task)"
    w(string.format("| %s bytes | %s | %s | %s |", bytes, f1(r.mean), f1(r.mean / 256), f1(r.deliver)))
end
-- }}}

-- {{{ chunk
w("")
w("## How many units one task should cover (2048 units, " .. in_sweep("chunk")[1].workers .. " workers)")
w("")
w("| Way | Units per task | Tasks per frame | Frame (mean) | 99th percentile | Handing in to the task queue |")
w("|-----|----------------|-----------------|--------------|-----------------|------------------------------|")
for _, sweep in ipairs({ "chunk", "chunk@fork", "batch", "spin" }) do
    for _, r in ipairs(in_sweep(sweep)) do
        -- three kinds of row: a ceramic way (tasks handed in), the shared
        -- counter (units taken at a time, no queue), a plain or fixed loop
        local label = (sweep == "chunk" and "" or (sweep .. ": ")) .. r.way
        if r.way:match("^pose_") then
            w(string.format("| %s | %d | %d | %s | %s | %s |", label, r.per, r.units / r.per, f1(r.mean), f1(r.p99), f1(r.deliver)))
        elseif r.way == "counter-loop" then
            w(string.format("| %s (%d threads) | %d at a time | | %s | %s | |", label, r.workers, r.per, f1(r.mean), f1(r.p99)))
        else
            w(string.format("| %s (%d threads) | | | %s | %s | |", label, r.workers, f1(r.mean), f1(r.p99)))
        end
    end
end
-- }}}

-- {{{ scale
w("")
w("## Adding workers (2048 units); speed-up over one thread's plain loop")
w("")
w("| Workers | Ceramic, 32 per task | Speed-up | Ceramic, 1 per task | Speed-up | Hand-written loop | Speed-up |")
w("|---------|----------------------|----------|---------------------|----------|-------------------|----------|")
local base = find("scale", "plain-loop").mean
for _, n in ipairs({ 1, 2, 3, 4, 6, 8, 11 }) do
    local c = find("scale", "pose_chunk_32", 2048, n)
    local u = find("scale", "pose_fold", 2048, n)
    local p = find("scale", "parallel-loop", 2048, n == 11 and 12 or n)
    w(string.format("| %d | %s | %.2f× | %s | %.2f× | %s (%d threads) | %.2f× |", n, f1(c.mean), base / c.mean,
        f1(u.mean), base / u.mean, f1(p.mean), p.workers, base / p.mean))
end
-- }}}

-- {{{ army
w("")
w("## Army size")
w("")
w("| Units | Plain loop | Hand-written loop | Ceramic, 32 per task | Ceramic, 1 per task |")
w("|-------|------------|-------------------|----------------------|---------------------|")
for _, u in ipairs({ 128, 512, 2048, 8192 }) do
    w(string.format("| %d | %s | %s | %s | %s |", u, f1(find("army", "plain-loop", u).mean), f1(find("army", "parallel-loop", u).mean),
        f1(find("army", "pose_chunk_32", u).mean), f1(find("army", "pose_fold", u).mean)))
end
-- }}}

-- {{{ herd
w("")
w("## The herd experiment: waking one worker per task instead of all (2048 units, one unit per task)")
w("")
w("| Variant | Workers | Wakes all: frame | delivering | Wakes one: frame | delivering |")
w("|---------|---------|------------------|------------|------------------|------------|")
for _, r in ipairs(in_sweep("herd")) do
    local one
    for _, o in ipairs(in_sweep("herd-wake-one")) do
        if o.way == r.way and o.workers == r.workers and o.units == r.units then one = o end
    end
    assert(one, "no wake-one run to pair with " .. r.way .. " at " .. r.workers .. " workers")
    w(string.format("| %s | %d | %s | %s | %s | %s |", r.way, r.workers, f1(r.mean), f1(r.deliver), f1(one.mean), f1(one.deliver)))
end
-- }}}

-- {{{ landing
w("")
w("## Landing: the kept copy's count trusted with no workaround wait")
w("")
for _, r in ipairs(in_sweep("landing")) do
    local ok = truth[r.units] and r.check == truth[r.units]
    w(string.format("- %s, %d units: checksum %s (%s)", r.way, r.units, r.check, ok and "agrees with the one-thread loop" or "**disagrees**"))
end
-- }}}

-- {{{ steadiness
w("")
w("## Steadiness (every run: median, 95th, 99th percentile and worst frame)")
w("")
w("| Sweep | Way | Units | Workers | Median | 95th | 99th | Worst | Worst ÷ median |")
w("|-------|-----|-------|---------|--------|------|------|-------|----------------|")
for _, r in ipairs(rows) do
    w(string.format("| %s | %s | %d | %d | %s | %s | %s | %s | %.1f |", r.sweep, r.way, r.units, r.workers,
        f1(r.p50), f1(r.p95), f1(r.p99), f1(r.worst), r.worst / r.p50))
end
-- }}}

local f = assert(io.open(out_dir .. "/analysis.md", "w"))
f:write(table.concat(lines, "\n"), "\n")
f:close()

-- the same rows as JSON, for a page that draws them
local json = {}
for _, r in ipairs(rows) do
    json[#json + 1] = string.format('{"sweep":"%s","way":"%s","units":%d,"per":%d,"workers":%d,"mean":%.1f,"p50":%.1f,"p95":%.1f,"p99":%.1f,"worst":%.1f,"deliver":%.1f,"land":%.1f}',
        r.sweep, r.way, r.units, r.per, r.workers, r.mean, r.p50, r.p95, r.p99, r.worst, r.deliver, r.land)
end
local j = assert(io.open(out_dir .. "/analysis.json", "w"))
j:write("[\n", table.concat(json, ",\n"), "\n]\n")
j:close()

-- {{{ the viewer page, filled
-- The processor, as lscpu names it, for the page's method note.
local cpu = io.popen("lscpu")
local info = cpu:read("*a")
cpu:close()
local model = info:match("Model name:%s*([^\n]+)") or "unknown processor"
local cores = tonumber(info:match("Core%(s%) per socket:%s*(%d+)")) or 0
local sockets = tonumber(info:match("Socket%(s%):%s*(%d+)")) or 1
local per_core = tonumber(info:match("Thread%(s%) per core:%s*(%d+)")) or 1
local online = io.popen("nproc"):read("*l")
local machine = string.format('{"model":"%s","cores":%d,"threads":%s,"per_core":%d,"frames":%d}',
    model:gsub('"', "'"), cores * sockets, online, per_core, rows[1].frames)
local data = "[" .. table.concat(json, ",") .. "]"
-- {{{ local function read_file
local function read_file(path)
    local f = assert(io.open(path, "r"))
    local text = f:read("*a")
    f:close()
    return text
end
-- }}}
-- {{{ local function fill
-- A viewer template filled: the shared kit spliced in, then the rows and
-- the machine. Every marker must be found once, or the page is broken.
local function fill(name)
    local page = read_file(DIR .. "/src/viewers/" .. name)
    local count
    for marker, text in pairs({ ["/%*@@KIT%-CSS@@%*/"] = read_file(DIR .. "/src/viewers/ceramic-kit.css"),
                                ["/%*@@KIT%-JS@@%*/"] = read_file(DIR .. "/src/viewers/ceramic-kit.js"),
                                ["/%*@@DATA@@%*/%[%]"] = data,
                                ["/%*@@MACHINE@@%*/{}"] = machine }) do
        page, count = page:gsub(marker, function() return text end)
        assert(count == 1, name .. ": marker " .. marker .. " found " .. count .. " times")
    end
    local hf = assert(io.open(out_dir .. "/" .. name, "w"))
    hf:write(page)
    hf:close()
end
-- }}}
-- the first report (the stock engine) and the second (the lock-free copy)
fill("ceramic-analysis.html")
fill("ceramic-lockfree.html")
-- }}}
print(table.concat(lines, "\n"))
if #disagree > 0 then os.exit(1) end
