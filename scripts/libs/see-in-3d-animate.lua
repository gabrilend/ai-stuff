-- see-in-3d-animate.lua - The pieces of a moving picture made from still
-- ones: the image-server workflow for one in-between frame, a palette chosen
-- for the frames, and frames turned into the indexes a GIF holds.
--
-- In plain terms: two pictures are the ends of a movement (a third can be its
-- middle). For each in-between frame the image server mixes the two pictures'
-- inner forms (their latents) by a growing amount and then lightly repaints the
-- mix under a description of the mechanism, with one seed for every frame, so
-- each frame is a picture in its own right and they do not flicker. A GIF can
-- hold only 256 colours, so the colours are chosen from the frames themselves
-- (median cut: the frames' colours split, again and again, at the middle of
-- whichever colour is most spread out, until there are 256 groups; each
-- group's average is one palette colour). The GIF itself is written by
-- gif-generator's own encoder; nothing here writes GIF bytes.
--
-- Scripts issue A12.

local ffi = require("ffi")
local bit = require("bit")
local M = {}

-- {{{ M.workflow_between(settings)
-- One in-between frame as a ComfyUI graph (API format). settings: from_image
-- and to_image (names on the server), blend (0..1, how much of the FROM
-- picture: LatentBlend gives samples1 * blend + samples2 * (1 - blend)),
-- prompt, negative, seed, steps, cfg, sampler, scheduler, denoise (how much
-- the mix is repainted), prefix, and checkpoint or model (as imagine).
function M.workflow_between(s)
    local loader = s.checkpoint
        and { class_type = "CheckpointLoaderSimple", inputs = { ckpt_name = s.checkpoint } }
        or { class_type = "DiffusersLoader", inputs = { model_path = s.model } }
    return {
        ["1"] = loader,
        ["2"] = { class_type = "CLIPTextEncode", inputs = { text = s.prompt, clip = { "1", 1 } } },
        ["3"] = { class_type = "CLIPTextEncode", inputs = { text = s.negative, clip = { "1", 1 } } },
        ["4"] = { class_type = "LoadImage", inputs = { image = s.from_image } },
        ["5"] = { class_type = "VAEEncode", inputs = { pixels = { "4", 0 }, vae = { "1", 2 } } },
        ["6"] = { class_type = "LoadImage", inputs = { image = s.to_image } },
        ["7"] = { class_type = "VAEEncode", inputs = { pixels = { "6", 0 }, vae = { "1", 2 } } },
        ["8"] = { class_type = "LatentBlend", inputs = { samples1 = { "5", 0 }, samples2 = { "7", 0 }, blend_factor = s.blend } },
        ["11"] = { class_type = "KSampler", inputs = {
            model = { "1", 0 }, positive = { "2", 0 }, negative = { "3", 0 }, latent_image = { "8", 0 },
            seed = s.seed, steps = s.steps, cfg = s.cfg, sampler_name = s.sampler, scheduler = s.scheduler,
            denoise = s.denoise } },
        ["12"] = { class_type = "VAEDecode", inputs = { samples = { "11", 0 }, vae = { "1", 2 } } },
        ["13"] = { class_type = "SaveImage", inputs = { images = { "12", 0 }, filename_prefix = s.prefix } },
    }
end
-- }}}

-- {{{ M.blends(segments, frames_per_segment)
-- The frames of the whole movement, in order: one entry per frame naming its
-- segment (1 for beginning-to-end, or 1 and 2 when there is a middle) and its
-- blend (1 = all FROM, 0 = all TO). Where two segments meet, the shared
-- picture is drawn once, not twice.
function M.blends(segments, frames_per_segment)
    if frames_per_segment < 2 then error("see-in-3d animate: a segment needs at least 2 frames", 0) end
    local list = {}
    for segment = 1, segments do
        for i = (segment == 1) and 0 or 1, frames_per_segment - 1 do
            list[#list + 1] = { segment = segment, blend = 1 - i / (frames_per_segment - 1) }
        end
    end
    return list
end
-- }}}

-- {{{ M.median_cut(frames, count)
-- A palette of up to `count` colours for frames (a list of strings of RGB
-- bytes). Every 3rd pixel of every frame is sampled; the box of colours with
-- the widest channel is split at that channel's median until there are
-- `count` boxes or no box can be split. Returns a list of { r, g, b }.
function M.median_cut(frames, count)
    local samples = {}
    for _, rgb in ipairs(frames) do
        for at = 1, #rgb - 2, 9 do
            local r, g, b = rgb:byte(at, at + 2)
            samples[#samples + 1] = { r, g, b }
        end
    end
    if #samples == 0 then error("see-in-3d animate: no pixels to choose colours from", 0) end
    local boxes = { samples }
    local function spread(box)
        local lo, hi = { 255, 255, 255 }, { 0, 0, 0 }
        for _, c in ipairs(box) do
            for k = 1, 3 do
                if c[k] < lo[k] then lo[k] = c[k] end
                if c[k] > hi[k] then hi[k] = c[k] end
            end
        end
        local widest, width = 1, -1
        for k = 1, 3 do if hi[k] - lo[k] > width then widest, width = k, hi[k] - lo[k] end end
        return widest, width
    end
    while #boxes < count do
        -- split the box whose widest channel is widest overall; a box of one
        -- colour cannot be split, and when none can, the palette is done
        local best, best_width, best_channel = nil, 0, 1
        for index, box in ipairs(boxes) do
            if #box > 1 then
                local channel, width = spread(box)
                if width > best_width then best, best_width, best_channel = index, width, channel end
            end
        end
        if not best then break end
        local box = table.remove(boxes, best)
        table.sort(box, function(a, b) return a[best_channel] < b[best_channel] end)
        local half = math.floor(#box / 2)
        local low, high = {}, {}
        for i = 1, #box do if i <= half then low[#low + 1] = box[i] else high[#high + 1] = box[i] end end
        boxes[#boxes + 1] = low
        boxes[#boxes + 1] = high
    end
    local palette = {}
    for _, box in ipairs(boxes) do
        local r, g, b = 0, 0, 0
        for _, c in ipairs(box) do r, g, b = r + c[1], g + c[2], b + c[3] end
        palette[#palette + 1] = { math.floor(r / #box + 0.5), math.floor(g / #box + 0.5), math.floor(b / #box + 0.5) }
    end
    return palette
end
-- }}}

-- {{{ M.palette_bytes(palette)
-- The 768-byte colour table the GIF encoder embeds; unused slots black.
function M.palette_bytes(palette)
    local bytes = ffi.new("uint8_t[768]")
    for index, colour in ipairs(palette) do
        bytes[(index - 1) * 3], bytes[(index - 1) * 3 + 1], bytes[(index - 1) * 3 + 2] = colour[1], colour[2], colour[3]
    end
    return bytes
end
-- }}}

-- {{{ M.indexer(palette)
-- A function turning a frame's RGB bytes into palette indexes (an ffi array
-- of width*height bytes). The nearest colour is found once per 15-bit colour
-- (5 bits a channel) and remembered, so each lookup after the first is one
-- table read.
function M.indexer(palette)
    local remembered = ffi.new("int16_t[32768]")
    ffi.fill(remembered, 32768 * 2, 0xFF)   -- -1: not yet looked up
    local function nearest(r, g, b)
        local best, best_distance = 0, math.huge
        for index, c in ipairs(palette) do
            local dr, dg, db = r - c[1], g - c[2], b - c[3]
            local distance = dr * dr + dg * dg + db * db
            if distance < best_distance then best, best_distance = index - 1, distance end
        end
        return best
    end
    return function(rgb, pixel_count)
        local out = ffi.new("uint8_t[?]", pixel_count)
        local source = ffi.cast("const uint8_t *", rgb)
        for i = 0, pixel_count - 1 do
            local r, g, b = source[i * 3], source[i * 3 + 1], source[i * 3 + 2]
            local key = bit.bor(bit.lshift(bit.rshift(r, 3), 10), bit.lshift(bit.rshift(g, 3), 5), bit.rshift(b, 3))
            local index = remembered[key]
            if index < 0 then
                index = nearest(bit.lshift(bit.rshift(r, 3), 3) + 4, bit.lshift(bit.rshift(g, 3), 3) + 4, bit.lshift(bit.rshift(b, 3), 3) + 4)
                remembered[key] = index
            end
            out[i] = index
        end
        return out
    end
end
-- }}}

return M
