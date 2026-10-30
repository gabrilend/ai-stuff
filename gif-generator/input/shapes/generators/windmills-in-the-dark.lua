-- windmills-in-the-dark: three windmills stand on dark rolling land, barely
-- lit. Wind blows across them as thin pale strokes, each bent into a sine
-- wave that travels along it; yellow stars ride the wind among the strokes,
-- weaving at two-thirds the strokes' frequency. The sails turn with the
-- wind. The camera drifts slowly sideways and back.
local GROUND = {
    size = 12, grid = 28, base = -1.3,
    hills = { { -2.5, -1.5, 0.6, 2.2 }, { 2.8, -2.2, 0.8, 2.4 }, { 0.3, 1.8, 0.35, 1.8 } },
    waves = { { 0.12, 0.7, 0.5, 0 }, { 0.07, -0.4, 1.1, 1.3 } },
}
-- {{{ local function windmill()
-- A spine standing on the ground, turned to face the wind, carrying a
-- tapering tower, a cap, a hub, and four sails that turn about the hub.
local function windmill(x, z, face, turns)
    local sails = {}
    for k = 0, 3 do
        sails[#sails + 1] = {
            tag = "windmill", mesh = "octahedron", hue = "cloud", dim = 0.7, style = "glow",
            stretch = { 0.62, 0.05, 0.12 }, pivot = { 0.62, 0, 0 }, offset = { 0, 1.72, 0.3 },
            orient = { axis = { 0, 0, 1 }, angle = k * math.pi / 2 },
            spin = { axis = { 0, 0, 1 }, turns = turns },
        }
    end
    local mill = {
        tag = "windmill", motion = { kind = "fixed", at = { x, 0, z }, on_ground = true },
        orient = { axis = { 0, 1, 0 }, angle = face },
        parts = {
            { tag = "windmill", mesh = "cone", hue = "ice", dim = 0.45, style = "glow",
              mesh_params = { segments = 8, radius = 0.32, height = 1.9 }, offset = { 0, 0.95, 0 } },
            { tag = "windmill", mesh = "octahedron", hue = "ember", dim = 0.6, scale = 0.2, offset = { 0, 1.75, 0 } },
            { tag = "windmill", mesh = "icosahedron", hue = "gold", scale = 0.1, offset = { 0, 1.72, 0.3 } },
        },
    }
    -- the sails hang from the windmill itself, at the hub: a part's size is
    -- measured against what carries it, so sails hung from the small hub
    -- would come out a tenth of their size
    for _, sail in ipairs(sails) do mill.parts[#mill.parts + 1] = sail end
    return mill
end
-- }}}
local instances = {
    { tag = "land", mesh = "terrain", hue = "violet", dim = 0.28, style = "solid", mesh_params = GROUND },
    windmill(-2.1, -1.0, 0.25, -2),
    windmill(0.6, -2.4, -0.15, -3),
    windmill(2.6, 0.2, 0.1, -2),
}
-- The wind: strokes crossing from left to right at several heights and
-- depths, each wave travelling along its stroke twice a loop.
local STROKE_WAVES = 3
local strokes = {}
local gusts = { { 0.9, -0.2 }, { 1.4, -1.8 }, { 0.3, 0.9 }, { 1.9, -0.6 }, { 0.6, -2.9 }, { 1.2, 1.6 } }
for g, gust in ipairs(gusts) do
    strokes[#strokes + 1] = {
        from = { -6, gust[1], gust[2] }, to = { 6, gust[1] + 0.3, gust[2] },
        amplitude = 0.16, waves = STROKE_WAVES, drift = 2, phase = g * 0.17, hue = "cloud", dim = 0.55,
    }
end
-- Stars riding the wind, weaving at two-thirds the strokes' frequency.
for s = 0, 7 do
    local gust = gusts[1 + s % #gusts]
    instances[#instances + 1] = {
        tag = "star", mesh = "star_prism", hue = "gold", scale = 0.13, style = "glow",
        motion = { kind = "wave", from = { -6, gust[1] + 0.05, gust[2] + 0.15 }, to = { 6, gust[1] + 0.35, gust[2] + 0.15 },
                   amplitude = 0.28, waves = STROKE_WAVES * 2 / 3, cycles = 1, phase = s / 8 },
        spin = { axis = { 0, 0, 1 }, turns = -3 },
    }
end
return {
    name = "windmills-in-the-dark",
    size = 320, frames = 150, delay_cs = 4,
    ground = GROUND,
    strokes = strokes,
    camera = { fov = 52,
               motion = { kind = "dolly", from = { -1.6, 1.6, 6.6 }, to = { 1.6, 1.2, 6.0 }, cycles = 1,
                          target = { 0.2, 0.3, -1.0 } } },
    framing = { tag = "windmill", at_least = 12 },
    stars = { count = 120, seed = 263, hues = { "gold", "ice" } },
    instances = instances,
}
