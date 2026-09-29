-- decode-worker.lua - One background decoder for the gif viewer.
--
-- In general terms: the window hands out "please decode this gif, at this
-- size" requests; several of these workers take them, unpack the frames, and
-- send them back one at a time as LÖVE pictures (ImageData). The window
-- stays smooth because the heavy unpacking never happens on its thread.
--
-- Two request channels: "urgent" (what is on screen now) is always served
-- before "background" (everything else, decoded ahead of time). A request
-- is a table { id, path, kind, max_size, frame_step, generation }; every
-- reply carries id, kind and generation back, so the window can drop replies
-- for something it has since forgotten.
--
-- Started by main.lua with love.thread.newThread; receives the viewer's own
-- folder as its argument so it can load the decoder by absolute path.

local viewer_dir = ...
require("love.image")
local ffi = require("ffi")
local gif = dofile(viewer_dir .. "/gif-decode.lua")

local urgent = love.thread.getChannel("gif-viewer-urgent")
local background = love.thread.getChannel("gif-viewer-background")
local results = love.thread.getChannel("gif-viewer-results")
local control = love.thread.getChannel("gif-viewer-control")

-- {{{ local function serve()
-- Decodes one request, sending each frame as soon as it exists. A failure is
-- sent back as a message rather than killing the worker, so one bad file
-- cannot silence the rest.
local function serve(request)
    local ok, failure = pcall(function()
        local info = gif.decode_file(request.path, {
            max_size = request.max_size,
            frame_step = request.frame_step,
            on_frame = function(index, pixels, width, height, delay_cs)
                local picture = love.image.newImageData(width, height, "rgba8")
                ffi.copy(picture:getFFIPointer(), pixels, width * height * 4)
                results:push({ id = request.id, kind = request.kind,
                               generation = request.generation,
                               index = index, image = picture, delay_cs = delay_cs })
            end,
        })
        results:push({ id = request.id, kind = request.kind, generation = request.generation,
                       done = true, count = info.frame_count })
    end)
    if not ok then
        results:push({ id = request.id, kind = request.kind, generation = request.generation,
                       failed = tostring(failure) })
    end
end
-- }}}

while true do
    if control:peek() == "stop" then break end
    local request = urgent:pop() or background:demand(0.05)
    if request then serve(request) end
end
