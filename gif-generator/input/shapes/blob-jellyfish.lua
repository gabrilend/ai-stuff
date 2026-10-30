-- blob-jellyfish: a jellyfish made of soft blobs -- a bell of five melted
-- together, squeezing and relaxing, and four tentacles of small blobs that
-- ripple beneath it -- drifting in the dark. A lamp on a slow arm circles it,
-- and every blob's bands of light turn to follow. No outlines anywhere.
local instances = {
    { tag = "machine", motion = { kind = "fixed", at = { 0, 0.3, 0 } }, spin = { axis = { 0, 1, 0 }, turns = 1 },
      parts = {
          { tag = "arm", mesh = "octahedron", hue = "ice", dim = 0.4, stretch = { 1.2, 0.025, 0.025 },
            pivot = { 1.2, 0, 0 },
            parts = { { tag = "lamp", mesh = "icosahedron", hue = "gold", scale = 0.12, offset = { 2.4, 0.4, 0 } } } },
      } },
}
local drift = { vector = { 0, 0.18, 0 }, cycles = 2 }
-- the bell: a crown blob and four around it, breathing wide and narrow
instances[#instances + 1] = {
    tag = "bell", hue = "violet", scale = 0.55, blob = { group = "jelly", bands = 4, soft = 0.4 },
    motion = { kind = "fixed", at = { 0, 0.55, 0 }, sway = { drift } },
    pulse = { amount = 0.08, cycles = 3 },
}
for k = 0, 3 do
    local a = k * math.pi / 2 + 0.4
    instances[#instances + 1] = {
        tag = "bell", hue = (k % 2 == 0) and "rose" or "violet", scale = 0.36,
        blob = { group = "jelly", bands = 4, soft = 0.4 },
        motion = { kind = "fixed", at = { 0.55 * math.cos(a), 0.3, 0.55 * math.sin(a) },
                   sway = { drift, { vector = { 0.14 * math.cos(a), 0, 0.14 * math.sin(a) }, cycles = 3 } } },
    }
end
-- the tentacles: chains of small blobs, each hanging lower and rippling
-- outward more, a moment behind the one above
for arm = 0, 3 do
    local a = arm * math.pi / 2 + 0.4
    for k = 1, 6 do
        instances[#instances + 1] = {
            tag = "tentacle", hue = (k % 2 == 0) and "ice" or "teal", scale = 0.15 - k * 0.012,
            -- each tentacle melts along itself but not into the bell or
            -- its neighbours (one great melted mass read as a lump, and was
            -- slow to draw: every ray had to search all of it)
            blob = { group = "tentacle-" .. arm, bands = 3, soft = 0.12 },
            motion = { kind = "fixed", at = { 0.45 * math.cos(a), 0.1 - k * 0.26, 0.45 * math.sin(a) },
                       sway = { drift, { vector = { 0.06 * k * math.cos(a), 0, 0.06 * k * math.sin(a) },
                                         cycles = 3, phase = -k * 0.07 } } },
        }
    end
end
return {
    name = "blob-jellyfish",
    size = 320, frames = 144, delay_cs = 4,
    jobs = 6,
    lights = { { tag = "lamp", hue = "cloud", strength = 1.15 } },
    camera = { fov = 46, motion = { kind = "orbit", radius = 5.2, height = 0.8, cycles = -1, target = { 0, -0.2, 0 } } },
    framing = { tag = "bell", at_least = 4 },
    stars = { count = 110, seed = 313, hues = { "ice", "violet", "gold" } },
    instances = instances,
}
