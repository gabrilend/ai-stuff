-- 031-making-a-gif.lua - a folder of recorded frames into one GIF.
--
-- In plain terms: the viewer (010) records a moving picture as numbered raw
-- frames; this turns them into a GIF without ever seeing the viewer. It
-- chooses one table of 256 colours from all the frames together, then
-- shares the frames out among one worker per processor (each turns its own
-- run of frames into colour numbers and compresses them, 030), and joins
-- the workers' pieces in frame order -- never in the order they finish, so
-- the same frames always make the same file.
--
--   luajit src/031-making-a-gif.lua <project-dir> FRAMES-FOLDER OUT.gif
--   (a worker is the same program: ... worker FRAMES-FOLDER PALETTE FIRST LAST OUT)

local project_dir = arg[1]
if project_dir == nil then error("usage: luajit 031-making-a-gif.lua <project-dir> FRAMES-FOLDER OUT.gif", 0) end
local code_dir = (arg[0]:match("^(.*)/[^/]+$") or ".")
package.path = code_dir .. "/?.lua;" .. code_dir .. "/../libs/?.lua;" .. package.path

local ffi = require("ffi")
local gif = require("030-gif-writer")
local data = require("024-writing-lua-data")

-- {{{ local function read_frame()
-- One raw frame (width x height x 4 bytes) as an ffi byte array.
local function read_frame(folder, index, width, height)
    local path = string.format("%s/%04d.rgba", folder, index)
    local file, problem = io.open(path, "rb")
    if file == nil then error("missing frame " .. path .. ": " .. tostring(problem), 0) end
    local bytes = file:read("*a")
    file:close()
    if #bytes ~= width * height * 4 then error(path .. " is " .. #bytes .. " bytes, not " .. width * height * 4, 0) end
    local frame = ffi.new("uint8_t[?]", #bytes)
    ffi.copy(frame, bytes, #bytes)
    return frame
end
-- }}}

-- {{{ worker
if arg[2] == "worker" then
    local folder, palette_path, first, last, out = arg[3], arg[4], tonumber(arg[5]), tonumber(arg[6]), arg[7]
    local info = dofile(folder .. "/info.lua")
    local palette = data.read_file(palette_path)
    local map = gif.mapper(palette)
    local delay = math.floor(100 / info.fps + 0.5)
    local file = io.open(out, "wb")
    for index = first, last do
        local indices = map(read_frame(folder, index, info.width, info.height), info.width, info.height)
        file:write(gif.frame_block(info.width, info.height, gif.lzw(indices, info.width * info.height), delay))
    end
    file:close()
    os.exit(0)
end
-- }}}

-- {{{ the whole file
local folder, out_path = arg[2], arg[3]
if folder == nil or out_path == nil then error("usage: luajit 031-making-a-gif.lua <project-dir> FRAMES-FOLDER OUT.gif", 0) end
local info = dofile(folder .. "/info.lua")
local started = os.time()

-- the colour table, from a sample of every frame
local frames = {}
for index = 0, info.frames - 1 do frames[#frames + 1] = read_frame(folder, index, info.width, info.height) end
local palette = gif.palette(frames, info.width, info.height, 256, 13)
frames = nil
local work = project_dir .. "/tmp/shared-memory/gif-work-" .. info.name
os.execute("rm -rf '" .. work .. "' && mkdir -p '" .. work .. "'")
data.write_file(work .. "/palette.lua", "-- the colour table for " .. info.name .. " (031)", palette)

-- one worker per processor, each a run of frames; all started, then waited
-- for together
local pipe = io.popen("nproc")
local workers = math.max(1, math.min(tonumber(pipe:read("*l")) or 1, info.frames))
pipe:close()
local commands = {}
for w = 0, workers - 1 do
    local first = math.floor(w * info.frames / workers)
    local last = math.floor((w + 1) * info.frames / workers) - 1
    if last >= first then
        commands[#commands + 1] = string.format("luajit '%s/031-making-a-gif.lua' '%s' worker '%s' '%s/palette.lua' %d %d '%s/%03d.part' &",
            code_dir, project_dir, folder, work, first, last, work, w)
    end
end
if not os.execute(table.concat(commands, " ") .. " wait") then error("a worker failed", 0) end

-- the pieces, joined in frame order
local file, problem = io.open(out_path, "wb")
if file == nil then error("cannot write " .. out_path .. ": " .. tostring(problem), 0) end
file:write(gif.header(info.width, info.height, palette))
for w = 0, workers - 1 do
    local part = io.open(string.format("%s/%03d.part", work, w), "rb")
    if part then file:write(part:read("*a")); part:close() end
end
file:write(gif.trailer())
file:close()
local size = io.open(out_path, "rb"):seek("end")
print(string.format("%s: %d frames, %dx%d, %d colours, %d workers, %.1f MB, %d s", out_path, info.frames,
    info.width, info.height, #palette, workers, size / 1e6, os.time() - started))
-- }}}
