-- phase-8-record.lua - records the canvas history the phase 8 demo replays.
--
-- In plain terms: the real blitter (016) takes the phase 1 series (018), all
-- its rounds, in a throwaway copy of the project, and the canvas files it
-- writes are copied out. assets/phase-8-history/ was made this way; run it
-- again to make it again (the written: lines will differ).
--
--   luajit issues/completed/demos/phase-8-record.lua DIR OUT
--     DIR   the project
--     OUT   the folder the canvas files go to (made if missing)

local DIR, OUT = arg[1], arg[2]
if not DIR or not OUT then
    io.stderr:write("usage: luajit phase-8-record.lua DIR OUT\n")
    os.exit(2)
end

local ffi = require("ffi")
pcall(ffi.cdef, "int setenv(const char *name, const char *value, int overwrite);")

-- {{{ helpers
local function q(text) return "'" .. string.gsub(text, "'", "'\\''") .. "'" end
local function shell(command)
    local pipe = io.popen(command .. " 2>&1")
    local text = pipe:read("*a")
    pipe:close()
    return (string.gsub(text, "\n$", ""))
end
local function write(path, text)
    local handle = assert(io.open(path, "wb"))
    handle:write(text)
    handle:close()
end
-- }}}

-- {{{ the throwaway copy: src, libs and scripts linked in, its own input and tiers
local BASE = shell("mktemp -d")
local ROOT = BASE .. "/guide-feature"
shell("mkdir -p " .. q(ROOT .. "/input") .. " " .. q(ROOT .. "/output") .. " "
    .. q(BASE .. "/exec") .. " " .. q(BASE .. "/shm"))
for _, name in ipairs({ "src", "libs", "scripts" }) do
    shell("ln -s " .. q(DIR .. "/" .. name) .. " " .. q(ROOT .. "/" .. name))
end
ffi.C.setenv("EXEC_TIER_ROOT", BASE .. "/exec", 1)
ffi.C.setenv("ARTIFACT_TIER_ROOT", BASE .. "/shm", 1)
-- }}}

-- {{{ every round of the series through the blitter
local series = dofile(ROOT .. "/src/018-phase-1-series.lua")
local blitter = dofile(ROOT .. "/src/016-blitter.lua")
write(ROOT .. "/input/blitter", series.SETTINGS)
write(ROOT .. "/input/to-voices", series.TO_VOICES_OFF)
local b = blitter.new({ root = ROOT, commit = "9f2c1e0", wait = function() end })
local latest = b.version or 0
local versions = { [latest] = b.current.rows }
local ARRIVALS = ROOT .. "/tmp/shared-memory/arrivals"
for number in ipairs(series.ROUNDS) do
    for _, sent in ipairs(series.arrivals(number, versions, latest)) do
        write(ARRIVALS .. "/" .. sent.name, sent.text)
        b:step()
        if b.version and b.version > latest then
            latest = b.version
            versions[latest] = b.current.rows
        end
    end
end
-- }}}

shell("mkdir -p " .. q(OUT) .. " && cp " .. q(ROOT .. "/tmp/shared-memory/canvas/history") .. "/* " .. q(OUT))
io.write("recorded versions 1 to ", latest, " in ", OUT, "\n")
shell("rm -rf " .. q(BASE))
