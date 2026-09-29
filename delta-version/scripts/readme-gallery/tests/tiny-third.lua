-- tiny-third: the third test scene, carrying every word added in the fourth
-- round -- terrain and a ground, a keyframed route resting on it, rolling,
-- becoming another shape with a trail, parts carried by a spine (with a part
-- of a part), a wave route, a bezier flight, wind strokes, standing on the
-- ground, a flying camera with a lead, and a framing promise -- at a size
-- that films at once.
local GROUND = { size = 6, grid = 6, base = -1, hills = { { 0, 0, 0.6, 1.2 } } }
return {
    name = "tiny-third",
    size = 48, frames = 6, delay_cs = 5,
    ground = GROUND,
    camera = { fov = 60, motion = { kind = "fly", size = { 3, 0.2, 3 }, freq = { 1, 2, 1 }, shift = { 0.25, 0, 0 },
                                    center = { 0, 1.5, 0 }, target = "ahead", lead = 0.1 } },
    framing = { tag = "anything", at_least = 0 },
    strokes = { { from = { -2, 0.5, 0 }, to = { 2, 0.5, 0 }, amplitude = 0.2, waves = 2, drift = 1 } },
    instances = {
        { tag = "ground", mesh = "terrain", hue = "jade", dim = 0.4, style = "solid", mesh_params = GROUND },
        { tag = "ball", mesh = "superball", hue = "rose", scale = 0.3, mesh_params = { grid = 2 },
          roll = { radius = 0.3 },
          motion = { kind = "keyframes", cycles = 1, lift = 0.3,
                     points = { { 0, 2, 0 }, { 0.5, 0, 0 }, { 0.8, 0, 0, 3 } },
                     sizes = { { 0, 0 }, { 0.1, 1 }, { 0.8, 1 }, { 0.9, 0 } } },
          becomes = { at = 0.55, mesh = "star_prism", hue = "gold", roll = false,
                      trail = { count = 2, mesh = "octahedron", hues = { "ember" } } } },
        { tag = "spine", motion = { kind = "fixed", at = { -1, 0, 1 }, on_ground = true },
          parts = { { mesh = "cone", hue = "violet", offset = { 0, 0.5, 0 },
                      parts = { { mesh = "star_prism", hue = "gold", scale = 0.3, offset = { 0, 1, 0 },
                                  spin = { axis = { 0, 1, 0 }, turns = 1 } } } } } },
        { tag = "rider", mesh = "star_prism", hue = "gold", scale = 0.2,
          motion = { kind = "wave", from = { -2, 0.6, 0 }, to = { 2, 0.6, 0 }, amplitude = 0.2, waves = 4 / 3, cycles = 1 } },
        { tag = "dart", mesh = "octahedron", hue = "violet", scale = 0.2, face_motion = true,
          motion = { kind = "bezier", cycles = 1, points = { { -1, 1, 1 }, { 0, 2, 1 }, { 1, 2, -1 }, { 1, 0.5, -1 } } } },
    },
}
