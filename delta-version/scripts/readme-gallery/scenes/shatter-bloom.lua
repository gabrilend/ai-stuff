-- shatter-bloom: a rose icosahedron sits still while a small gold cube swings
-- through it. As the cube arrives the icosahedron bursts into rainbow shards,
-- which fly outward, hang, and fall back together as the cube swings away --
-- twice per loop, from either side.
return {
    name = "shatter-bloom",
    size = 320, frames = 96, delay_cs = 4,
    camera = { distance = 7.5, fov = 44, tilt = 0.3 },
    stars = { count = 90, seed = 23, hues = { "gold", "rose", "ice" } },
    instances = {
        { tag = "bloom", mesh = "icosahedron", hue = "rose", scale = 1.35, style = "glow",
          motion = { kind = "fixed" }, spin = { axis = { 0.3, 1, 0.2 }, turns = 1 },
          shard_distance = 1.3,
          reacts = { { to = "hammer", within = 2.6, effect = "shatter", amount = 1.1 } } },

        { tag = "hammer", mesh = "cube", hue = "gold", scale = 0.38, style = "glow",
          motion = { kind = "swing", from = { -3.6, 0.35, 0.6 }, to = { 3.6, -0.35, 0.6 }, cycles = 1 },
          spin = { axis = { 1, 1, 0.2 }, turns = 4 },
          reacts = { { to = "bloom", within = 2.2, effect = "glow", amount = 0.8 } } },
    },
}
