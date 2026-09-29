-- parts/wizard.lua - a wizard built from simple shapes, shared by the
-- wizard scenes. Not a scene itself (it lives in a folder the runner does not
-- list); a scene loads it and hangs the parts from a spine of its own.
--
-- The wizard faces +x in its own frame, y up. Each part's `offset` is where
-- it sits relative to what carries it; parts carried by the arm move when
-- the arm moves. The arm hinges at the shoulder (pivot) and rocks up to
-- cast; the wand rides the arm, and the star at the wand's tip rides the
-- wand -- three levels of carrying.
--
-- Returns a function(options) -> parts list. options:
--   robe, hat  -- hue names (defaults violet, ice)
--   cast_cycles -- whole number of casting gestures per loop (default 2)
--   cast_phase  -- where in its gesture the arm starts (default 0)
--
-- Where the wand's star sits, for scenes aiming spells from it: roughly
-- { 1.15, 1.95, 0.3 } in the wizard's own frame (scaled by the wizard's
-- size) when the arm is mid-gesture. Spells start there.

return function(options)
    options = options or {}
    local cast_cycles = options.cast_cycles or 2
    local cast_phase = options.cast_phase or 0
    return {
        -- the robe: a tall cone, the body inside it implied
        { tag = "wizard", mesh = "cone", hue = options.robe or "violet", style = "glow",
          mesh_params = { segments = 14, radius = 0.55, height = 1.5 }, offset = { 0, 0.75, 0 } },
        -- the head, pale, and a long beard hanging from the chin
        { tag = "wizard", mesh = "superball", hue = "cloud", dim = 0.85, scale = 0.25,
          mesh_params = { grid = 4 }, style = "solid", offset = { 0, 1.62, 0 } },
        { tag = "wizard", mesh = "cone", hue = "cloud", dim = 0.75, scale = 0.24, style = "solid",
          mesh_params = { segments = 8, radius = 0.6, height = 1.6 }, offset = { 0.12, 1.36, 0 },
          orient = { axis = { 1, 0, 0 }, angle = math.pi } },
        -- the hat: a tall pointed cone over a gold brim, tipped back a little
        { tag = "wizard", mesh = "cone", hue = options.hat or "ice", style = "glow",
          mesh_params = { segments = 12, radius = 0.42, height = 1.05 }, offset = { -0.04, 2.3, 0 },
          orient = { axis = { 0, 0, 1 }, angle = 0.12 } },
        { tag = "wizard", mesh = "torus", hue = "gold", scale = 0.52, style = "solid",
          mesh_params = { major = 0.75, minor = 0.1, rings = 24, sides = 6 }, offset = { -0.02, 1.82, 0 } },
        -- the casting arm: a sleeve hinged at the shoulder, rocking up and
        -- down; it carries the wand, which carries its star
        { tag = "wizard", mesh = "octahedron", hue = options.robe or "violet", style = "glow",
          stretch = { 0.42, 0.1, 0.1 }, pivot = { 0.42, 0, 0 }, offset = { 0.1, 1.3, 0.3 },
          rock = { axis = { 0, 0, 1 }, center = 0.45, amount = 0.3, cycles = cast_cycles, phase = cast_phase },
          parts = {
              { tag = "wizard", mesh = "octahedron", hue = "ember", dim = 0.8, style = "solid",
                stretch = { 0.38, 0.035, 0.035 }, pivot = { 0.38, 0, 0 }, offset = { 0.84, 0, 0 },
                orient = { axis = { 0, 0, 1 }, angle = 0.25 },
                parts = {
                    { tag = "wand-star", mesh = "star_prism", hue = "gold", scale = 0.16, style = "glow",
                      offset = { 0.8, 0, 0 }, spin = { axis = { 1, 0, 0 }, turns = 4 },
                      pulse = { amount = 0.25, cycles = cast_cycles * 2, phase = cast_phase } },
                },
              },
          },
        },
    }
end
