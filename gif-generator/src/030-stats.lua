-- 030-stats.lua — the one measurer: honest numbers about renders,
-- so documentation points at a tool instead of at stale statistics.
--
-- What this is, generally: two modes. Given a scene name, it
-- renders that scene and reports measured facts — stage timings,
-- populations, sizes — optionally comparing worker counts with real
-- wall-clock time. Given nothing, it summarizes every report in
-- output/ as one table. Any number a document wants to cite should
-- come from running this, dated, rather than from memory.
--
-- Wall clocks versus CPU clocks, worth knowing more than once:
-- os.clock sums CPU across every thread in the process, which makes
-- parallel work look SLOWER by CPU — speedup is a wall-clock fact,
-- and the wall here is read from the system clock at nanosecond
-- resolution (a read-only ask; nothing rendered depends on it).

local DEFAULT_DIR = "/mnt/mtwo/programming/ai-stuff/gif-generator"
if arg and arg[0] and arg[0]:find("030%-stats") then
    package.path = (arg[1] or DEFAULT_DIR) .. "/src/?.lua;"
                   .. package.path
end

local stats = {}

-- {{{ function stats.wall()
-- Seconds since the epoch, fractional. One read-only ask of the
-- system clock; used strictly for reporting elapsed reality.
function stats.wall()
    local p = io.popen("date +%s.%N")
    local t = tonumber(p:read("*l"))
    p:close()
    return t
end
-- }}}

-- {{{ function stats.measure()
-- Render a scene and return measured facts. workers = 0 means the
-- sequential runner; more means the many-hands pipeline, and the
-- caller can compare wall times between calls.
function stats.measure(dir, scene, workers)
    local score = require("022-score")
    local compile = require("024-compile")
    local compiled = compile.score(
        score.read(dir .. "/input/" .. scene .. ".lua"))
    local t0 = stats.wall()
    local bytes, facts
    if workers and workers > 0 then
        local parallel = require("028-parallel")
        bytes, facts = parallel.render_to_gif(compiled, dir, workers)
    else
        local main = require("026-render-main")
        bytes, facts = main.render_to_gif(compiled)
        facts.bytes = facts.bytes or #bytes
    end
    facts.wall_seconds = stats.wall() - t0
    facts.scene = scene
    return bytes, facts
end
-- }}}

-- {{{ function stats.say()
-- One measurement, spoken plainly.
function stats.say(facts)
    print(facts.scene .. ":")
    print("  frames:        " .. facts.frames)
    print("  bytes:         " .. facts.bytes)
    print("  peak alive:    " .. facts.peak)
    if facts.workers then
        print("  workers:       " .. facts.workers)
    end
    if facts.sim_seconds then
        print(string.format("  cpu (sim/draw/encode): %.2f / %.2f "
              .. "/ %.2f s", facts.sim_seconds, facts.draw_seconds,
              facts.encode_seconds))
    end
    print(string.format("  wall:          %.2f s", facts.wall_seconds))
    print(string.format("  frames/wall-s: %.1f",
                        facts.frames / facts.wall_seconds))
end
-- }}}

-- {{{ function stats.summarize()
-- Every report in output/, one table. The reports were written by
-- the runner at render time; this only reads.
function stats.summarize(dir)
    local names = {}
    local ls = io.popen("ls -1 '" .. dir .. "/output/'")
    for entry in ls:lines() do
        local name = entry:match("^(.+)%.report$")
        if name then names[#names + 1] = name end
    end
    ls:close()
    table.sort(names)
    if #names == 0 then
        print("stats: no reports in output/ — render something "
              .. "first (./run)")
        return 0
    end
    print(string.format("%-16s %8s %10s %8s %8s %8s",
          "scene", "frames", "bytes", "peak", "seats", "cpu-s"))
    for _, name in ipairs(names) do
        local facts = {}
        for line in io.lines(dir .. "/output/" .. name .. ".report") do
            local k, v = line:match("([%w_]+):%s*(.+)")
            if k then facts[k] = v end
        end
        local cpu = (tonumber(facts.sim_seconds) or 0)
                    + (tonumber(facts.draw_seconds) or 0)
                    + (tonumber(facts.encode_seconds) or 0)
        print(string.format("%-16s %8s %10s %8s %8s %8.2f",
              name, facts.frames or "?", facts.bytes or "?",
              facts.peak_particles or "?",
              facts.palette_seats_lit or "?", cpu))
    end
    return #names
end
-- }}}

if arg and arg[0] and arg[0]:find("030%-stats") then
    local dir = arg[1] or DEFAULT_DIR
    if arg[2] then
        local _, facts = stats.measure(dir, arg[2],
                                       tonumber(arg[3]) or 0)
        stats.say(facts)
    else
        stats.summarize(dir)
    end
end

return stats
