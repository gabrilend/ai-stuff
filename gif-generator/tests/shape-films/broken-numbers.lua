-- broken-numbers: a scene where every word is spelled right and twelve
-- of them break a rule (half a turn, a darkening past 1, a curve with three
-- points, a shape with no colour, rolling on a circle, ...), for the wall's
-- test (050-shape-wall-test.lua). Every one must be reported in one pass;
-- nothing may be filmed.
return {
    name = "broken-numbers",
    size = 48, frames = 6, delay_cs = 5,
    camera = { fov = 50, motion = { kind = "orbit", radius = 4, cycles = 1, target = "ahead" } },
    streaks = { count = 10, seed = 1, cycles = 1 },
    instances = {
        { tag = "bloom", mesh = "icosahedron", dim = 2,
          spin = { axis = { 0, 1, 0 }, turns = 1.5 } },
        { tag = "ball", mesh = "cube", hue = "gold", roll = { radius = 0.5 }, morph = { cycles = 1 },
          motion = { kind = "orbit", radius = 1, cycles = 1 } },
        { tag = "dart", mesh = "octahedron", hue = "violet",
          motion = { kind = "bezier", cycles = 1, points = { { 0, 0, 0 }, { 1, 1, 0 }, { 2, 0, 0 } } } },
        { tag = "seed", mesh = "superball", hue = "jade",
          becomes = { at = 1.5, mesh = "star_prism" },
          motion = { kind = "conveyor", from = { -1, 0, 0 }, to = { 1, 0, 0 }, cycles = 2.5 } },
        { tag = "walker", mesh = "cone", hue = "ember", motion = { kind = "fixed", at = { 0, 0, 0 }, on_ground = true } },
    },
    strokes = { { from = { -1, 0, 0 }, to = { 1, 0, 0 }, drift = 0.5 } },
    lights = { { hue = "gold", strength = 1 } },
}
