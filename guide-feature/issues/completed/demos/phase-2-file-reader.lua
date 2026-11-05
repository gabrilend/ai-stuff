-- phase-2-file-reader.lua - the phase 2 demo's first reader: the canvas
-- files in RAM.
--
-- It watches tmp/shared-memory/canvas/current (203) by reading its first
-- line every 20 milliseconds (no inotify binding in this project yet), and
-- keeps every version it sees, read through the viewer-side reader (202) so
-- a version a viewer could not read is caught here. A version that went by
-- between two looks is read from canvas/history. Each version is saved, byte
-- for byte, as OUT/NNNNNN, and a line goes to OUT/received:
--   <version> <current|history> <seconds since 1970, to the microsecond>
-- It stops when OUT/stop appears, writing OUT/done.
--
-- usage (phase-2-demo starts it):
--   luajit phase-2-file-reader.lua --root PROJECT --out FOLDER

-- {{{ arguments
local ROOT, OUT
for index = 1, #arg do
    if arg[index] == "--root" then ROOT = arg[index + 1] end
    if arg[index] == "--out" then OUT = arg[index + 1] end
end
if not (ROOT and OUT) then
    io.stderr:write("usage: luajit phase-2-file-reader.lua --root PROJECT --out FOLDER\n")
    os.exit(2)
end
-- }}}

local socket = require("socket")
local viewer = dofile(ROOT .. "/src/022-viewer.lua")
local FOLDER = ROOT .. "/tmp/shared-memory/canvas"

-- {{{ small helpers
local function slurp(path)
    local handle = io.open(path, "rb")
    if not handle then return nil end
    local text = handle:read("*a")
    handle:close()
    return text
end
local function first_line(path)
    local handle = io.open(path, "rb")
    if not handle then return nil end
    local line = handle:read("*l")
    handle:close()
    return line
end
local function exists(path)
    local handle = io.open(path, "r")
    if handle then handle:close() end
    return handle ~= nil
end
local received = assert(io.open(OUT .. "/received", "a"))
received:setvbuf("line")
local function keep(text, how)
    local view, problem = viewer.read(text, "a canvas file")
    if not view then
        received:write("unreadable " .. how .. " " .. tostring(problem) .. "\n")
        return nil
    end
    local name = string.format("%s/%06d", OUT, view.version)
    local handle = assert(io.open(name .. ".part", "wb"))
    handle:write(text)
    handle:close()
    assert(os.rename(name .. ".part", name))
    received:write(string.format("%d %s %.6f\n", view.version, how, socket.gettime()))
    return view.version
end
-- }}}

-- {{{ watching
local last = nil
while not exists(OUT .. "/stop") do
    local version = tonumber(string.match(first_line(FOLDER .. "/current") or "",
        "^canvas: (%d+)$"))
    if version and (not last or version > last) then
        local text = slurp(FOLDER .. "/current")
        local got = text and keep(text, "current")
        if got then
            -- versions that went by between two looks, from the history
            if last then
                for missed = last + 1, got - 1 do
                    local old = slurp(string.format("%s/history/%06d", FOLDER, missed))
                    if old then keep(old, "history") end
                end
            end
            last = got
        end
    end
    socket.sleep(0.02)
end
received:close()
local done = assert(io.open(OUT .. "/done", "w"))
done:write("stopped at version " .. tostring(last) .. "\n")
done:close()
-- }}}
