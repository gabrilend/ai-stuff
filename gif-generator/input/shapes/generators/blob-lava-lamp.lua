-- blob-lava-lamp: soft blobs of warm wax rise and sink inside an invisible
-- column, melting into one another where they meet and pulling apart again.
-- A little light machine -- a gold orb on an arm, turned by a post -- circles
-- the column, and each blob is lit in stacked bands of brightness that sweep
-- round as the orb goes by. No outlines, no wireframe.
--
-- The owner's words: "some that have rounded shapes without wireframes but
-- with brightness levels on a 'per blob' fashion generated according to the
-- rotation of a point light machinery."
local instances = {
    -- the light machine: a post with an arm that turns once a loop, the
    -- lamp at its end (the light shines from the part tagged "lamp")
    { tag = "machine", motion = { kind = "fixed", at = { 0, -1.9, 0 } }, spin = { axis = { 0, 1, 0 }, turns = 1 },
      parts = {
          { tag = "post", mesh = "cone", hue = "ice", dim = 0.5, stretch = { 0.12, 0.35, 0.12 },
            mesh_params = { segments = 8 }, offset = { 0, 0.25, 0 } },
          { tag = "arm", mesh = "octahedron", hue = "ice", dim = 0.6, stretch = { 1.1, 0.04, 0.04 },
            pivot = { 1.1, 0, 0 }, offset = { 0, 0.5, 0 },
            orient = { axis = { 0, 0, 1 }, angle = 0.55 },
            parts = { { tag = "lamp", mesh = "icosahedron", hue = "gold", scale = 0.14, offset = { 2.2, 0, 0 },
                        pulse = { amount = 0.15, cycles = 4 } } } },
      } },
}
-- Seven blobs of wax on slow up-and-down paths of their own, so they meet,
-- merge and part at different times.
local wax = { "ember", "rose", "gold", "ember", "rose", "ember", "gold" }
for k = 1, #wax do
    local a = k * 2.4
    instances[#instances + 1] = {
        tag = "wax", hue = wax[k], scale = 0.28 + 0.06 * (k % 3),
        blob = { group = "lamp", bands = 4, soft = 0.45 },
        motion = { kind = "lissajous", center = { 0.35 * math.cos(a), 0, 0.35 * math.sin(a) },
                   size = { 0.12, 1.25, 0.12 }, freq = { 1, 1, 2 }, phase = k / #wax, shift = { 0.25, 0, 0 } },
    }
end
return {
    name = "blob-lava-lamp",
    size = 320, frames = 144, delay_cs = 4,
    jobs = 4,
    lights = { { tag = "lamp", hue = "cloud", strength = 1.1 } },
    camera = { fov = 46, motion = { kind = "orbit", radius = 4.8, height = 0.6, cycles = -1, target = { 0, -0.1, 0 } } },
    framing = { tag = "wax", at_least = 5 },
    stars = { count = 90, seed = 307, hues = { "gold", "rose", "ember" } },
    instances = instances,
}
