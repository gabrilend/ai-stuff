-- dress-mannequin-orbit: the outfit from twirling-dress, now standing almost
-- still -- the skirt turns once, slowly, and barely breathes; the hat hardly
-- tips -- while the camera walks round it the other way, rising a little,
-- the horizon rocking gently. Two ribbons of gems idle round the hem.
local instances = {
    { tag = "skirt", mesh = "cone", hue = "rose", scale = 1.0, style = "glow",
      mesh_params = { segments = 16, radius = 1.0, height = 1.5 },
      motion = { kind = "fixed", at = { 0, -0.55, 0 } },
      spin = { axis = { 0, 1, 0 }, turns = 1 },
      pulse = { amount = 0.07, cycles = 2, axes = { 1, -0.35, 1 } } },
    { tag = "bodice", mesh = "octahedron", hue = "violet", scale = 0.42, stretch = { 0.8, 1.2, 0.6 },
      motion = { kind = "fixed", at = { 0, 0.55, 0 } }, spin = { axis = { 0, 1, 0 }, turns = 1 } },
    -- Two arms, one at each shoulder, turning with the bodice and hanging
    -- a little out from the skirt, swaying gently. Carried by a spine at the
    -- bodice's middle so they turn with it. (The first cut had none, and
    -- the owner read one of the gem ribbons as a lone arm: "has one arm...
    -- It should have two arms.")
    { tag = "arms", motion = { kind = "fixed", at = { 0, 0.55, 0 } }, spin = { axis = { 0, 1, 0 }, turns = 1 },
      parts = {
          { tag = "arm", mesh = "octahedron", hue = "violet", style = "glow",
            stretch = { 0.42, 0.07, 0.07 }, pivot = { 0.42, 0, 0 }, offset = { 0, 0.2, 0.26 },
            orient = { axis = { 0, 1, 0 }, angle = -math.pi / 2 },
            rock = { axis = { 0, 0, 1 }, center = -1.05, amount = 0.08, cycles = 2 },
            parts = { { tag = "arm", mesh = "superball", hue = "cloud", dim = 0.85, scale = 0.07,
                        mesh_params = { grid = 2 }, style = "solid", offset = { 0.86, 0, 0 } } } },
          { tag = "arm", mesh = "octahedron", hue = "violet", style = "glow",
            stretch = { 0.42, 0.07, 0.07 }, pivot = { 0.42, 0, 0 }, offset = { 0, 0.2, -0.26 },
            orient = { axis = { 0, 1, 0 }, angle = math.pi / 2 },
            rock = { axis = { 0, 0, 1 }, center = -1.05, amount = 0.08, cycles = 2, phase = 0.5 },
            parts = { { tag = "arm", mesh = "superball", hue = "cloud", dim = 0.85, scale = 0.07,
                        mesh_params = { grid = 2 }, style = "solid", offset = { 0.86, 0, 0 } } } },
      } },
    { tag = "hat", mesh = "cone", hue = "violet", scale = 0.42, style = "glow",
      mesh_params = { segments = 12, radius = 0.55, height = 1.0 },
      motion = { kind = "fixed", at = { 0, 1.55, 0 }, sway = { { vector = { 0, 0.05, 0 }, cycles = 2 } } },
      rock = { axis = { 0, 0, 1 }, amount = 0.06, cycles = 2, phase = 0.25 } },
    { tag = "brim", mesh = "torus", hue = "gold", scale = 0.6, style = "solid",
      mesh_params = { major = 0.75, minor = 0.12, rings = 28, sides = 8 },
      motion = { kind = "fixed", at = { 0, 1.35, 0 }, sway = { { vector = { 0, 0.05, 0 }, cycles = 2 } } },
      rock = { axis = { 0, 0, 1 }, amount = 0.06, cycles = 2, phase = 0.25 } },
}
-- The gems. They used to circle the hem in two ribbons; the owner meant
-- those when asking for arms: "I meant the part that's orbiting now, it
-- should calm down like the other side and those should be the arms. I like
-- what you've built now though." Reading that: the gems stop orbiting and
-- become the arms' beading -- five along each sleeve, carried by the arm, so
-- they move only as calmly as the arm itself sways, with a slow shimmer.
local gem_hues = { "gold", "teal", "jade", "ice" }
local arms_spine
for _, inst in ipairs(instances) do if inst.tag == "arms" then arms_spine = inst end end
for _, arm in ipairs(arms_spine.parts) do
    for k = 1, 5 do
        arm.parts[#arm.parts + 1] = {
            tag = "arm", mesh = (k % 2 == 0) and "octahedron" or "icosahedron",
            hue = gem_hues[1 + k % #gem_hues], scale = 0.075, offset = { k * 0.15, 0.03, 0 },
            spin = { axis = { 1, 0, 0 }, turns = 1, phase = k * 0.2 },
            pulse = { amount = 0.15, cycles = 2, phase = k * 0.1 },
        }
    end
end
return {
    name = "dress-mannequin-orbit",
    size = 320, frames = 144, delay_cs = 4,
    camera = { fov = 46,
               motion = { kind = "orbit", radius = 5.2, height = 0.9, cycles = -1, target = { 0, 0.1, 0 },
                          bob = { amount = 0.6, cycles = 1 } },
               roll = { amount = 0.07, cycles = 2 } },
    stars = { count = 110, seed = 239, hues = { "gold", "rose", "violet" } },
    instances = instances,
}
