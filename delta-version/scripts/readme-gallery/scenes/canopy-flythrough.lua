-- canopy-flythrough: like the jellyfish fly-through, but through a wood:
-- the camera swoops on a pinched loop among the crowns of trees whose trunks
-- reach all the way down to the ground, rising over some crowns and dipping
-- between others. The ground is the same green hill-country as
-- hill-to-the-stars. Yellow stars bob up and down among the trees, turning
-- about the upright axis.
--
-- The owner's words: "similar to jellyfish flythrough, but swooping through
-- the canopies of trees that have trunks that reach all the way down to the
-- ground. The earth should be comprised of the same stuff as
-- hill-to-the-stars. There should still be yellow stars but they should be
-- bouncing up and down, not left and right, and rotating about the Z axis."
-- A note on axes: in this tool "up" is y, not z, so the stars spin about y
-- -- the upright axis the owner means.
--
-- Checked by tests/framing-test.lua: the camera never comes within reach of
-- a crown, a trunk (measured level, to the trunk's upright line) or a star,
-- and at least two crowns are in view in every frame.
local GROUND = {
    size = 18, grid = 30, base = -1.2,
    hills = { { -3, 2, 0.5, 2.5 }, { 3.5, -2.5, 0.6, 2.8 }, { 0, 0, 0.3, 2.0 } },
    waves = { { 0.06, 1.3, 0.9, 0 }, { 0.05, -0.7, 1.1, 1.1 } },
}
-- the camera's loop, in the numbers the camera is given below
local RADIUS, PINCH, LOBES, HEIGHT = 4.6, 0.26, 2, 1.1
-- {{{ local function loop_point()
local function loop_point(angle)
    local r = RADIUS * (1 - PINCH * math.cos(LOBES * angle))
    return r * math.cos(angle), r * math.sin(angle)
end
-- }}}

local instances = {
    { tag = "ground", mesh = "terrain", hue = "jade", dim = 0.42, style = "solid", mesh_params = GROUND },
}
-- {{{ local function tree()
-- A spine standing on the ground carrying a trunk up to its crown, and a
-- crown of three leafy masses; the whole crown breathes a very little.
local function tree(x, z, trunk_height, crown_hue)
    instances[#instances + 1] = {
        tag = "tree", motion = { kind = "fixed", at = { x, 0, z }, on_ground = true },
        parts = {
            { tag = "trunk", mesh = "cone", hue = "ember", dim = 0.5, style = "solid",
              mesh_params = { segments = 8, radius = 0.16, height = trunk_height },
              offset = { 0, trunk_height / 2, 0 } },
            { tag = "canopy", mesh = "superball", hue = crown_hue, scale = 0.8, stretch = { 1, 0.72, 1 },
              mesh_params = { grid = 4 }, style = "glow", offset = { 0, trunk_height, 0 },
              pulse = { amount = 0.03, cycles = 2 } },
            { tag = "leaves", mesh = "icosahedron", hue = crown_hue, dim = 0.8, scale = 0.42,
              offset = { 0.45, trunk_height + 0.25, 0.2 } },
            { tag = "leaves", mesh = "icosahedron", hue = crown_hue, dim = 0.8, scale = 0.38,
              offset = { -0.35, trunk_height + 0.3, -0.3 } },
        },
    }
end
-- }}}

-- Trees stand beside the loop, alternately inside and outside it, far enough
-- off the path that neither crown nor trunk is ever flown through; their
-- heights vary so the crowns form a rolling roof to swoop over and under.
local crowns = { "jade", "teal", "rose", "jade", "gold", "teal", "jade" }
local SIDE = 1.6
for j = 0, 19 do
    local angle = (j + 0.5) / 20 * 2 * math.pi
    local x, z = loop_point(angle)
    local ax, az = loop_point(angle + 1e-4)
    local dx, dz = ax - x, az - z
    local len = math.sqrt(dx * dx + dz * dz)
    local side = (j % 2 == 0) and SIDE or -SIDE
    tree(x + dz / len * side, z - dx / len * side, 2.2 + 0.5 * ((j * 3) % 4) / 3, crowns[j % #crowns + 1])
end

-- Yellow stars bobbing up and down among the trees, turning about the
-- upright axis, set just off the path on alternate sides.
for k = 0, 11 do
    local angle = k / 12 * 2 * math.pi
    local x, z = loop_point(angle)
    local ax, az = loop_point(angle + 1e-4)
    local dx, dz = ax - x, az - z
    local len = math.sqrt(dx * dx + dz * dz)
    local side = (k % 2 == 0) and 0.9 or -0.9
    instances[#instances + 1] = {
        tag = "star", mesh = "star_prism", hue = "gold", scale = 0.14, style = "glow",
        motion = { kind = "fixed", at = { x + dz / len * side, HEIGHT + 0.2 * ((k % 3) - 1), z - dx / len * side },
                   sway = { { vector = { 0, 0.35, 0 }, cycles = 3, phase = k / 12 } } },
        spin = { axis = { 0, 1, 0 }, turns = (k % 2 == 0) and 2 or -2 },
    }
end
return {
    name = "canopy-flythrough",
    size = 320, frames = 200, delay_cs = 6,
    ground = GROUND,
    camera = { fov = 64,
               motion = { kind = "lobed", radius = RADIUS, pinch = PINCH, lobes = LOBES, cycles = 1, height = HEIGHT,
                          bob = { amount = 0.55, cycles = 3 }, target = "ahead", lead = 0.12 },
               roll = { amount = 0.05, cycles = 1 } },
    framing = { tag = "canopy", at_least = 2 },
    clearance = { { tag = "canopy", radius = 1.0 }, { tag = "leaves", radius = 0.6 },
                  { tag = "trunk", radius = 0.45, column = true }, { tag = "star", radius = 0.3 } },
    stars = { count = 110, seed = 293, hues = { "gold", "ice", "rose" } },
    instances = instances,
}
