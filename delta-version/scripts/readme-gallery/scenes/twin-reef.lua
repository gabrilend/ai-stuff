-- twin-reef: two shoals of fish, each circling its own home, dive toward
-- each other once a loop. Half of each shoal passes straight through the
-- other -- the two passing halves phasing through one another in the middle
-- -- and swings round through the far shoal's waters before curving home.
-- The other half of each shoal holds back, reaches the meeting point just
-- after the passers are through, bursts into rainbow shards, gathers itself
-- again, and swims home to rejoin the circle.
--
-- The owner's words: "two separate reef flocks that sometimes dive toward
-- each other and explode? then recombine. Each flock should get an equal
-- number that pass through, and an equal number that explode and recombine
-- once the pass-through-er has fully gone through. They should phase through
-- each other then go off along on their orbiting journeys."
--
-- Every fish's journey is one closed smooth curve (`spline`) worked out here,
-- twelve points round, each stretch a twelfth of the loop:
--   points 0-6   circling its home  (u 0 to 1/2)
--   point 7      turning to dive    (u 7/12)
--   passers:  8 through the middle (2/3), 9 deep in the far shoal (3/4),
--             10-11 curving round and home (5/6, 11/12)
--   bursters: 8 creeping closer (2/3), 9 at the middle (3/4), bursting as
--             the passers have cleared it, 10 gathering (5/6), 11 home
-- The bursts are timed along the route (`shatter_keys`). Each fish carries
-- `flock` and `role` so the test can count equal halves.
local instances = {}
local HOMES = { A = { -2.3, 0, 0 }, B = { 2.3, 0, 0 } }
local COLOURS = { A = { "teal", "ice", "jade" }, B = { "rose", "ember", "gold" } }
local PER_FLOCK = 8

-- {{{ local function journey()
local function journey(flock, index, role)
    local home = HOMES[flock]
    local toward = flock == "A" and 1 or -1          -- which way the middle lies
    local angle0 = index / PER_FLOCK * 2 * math.pi
    local radius = 0.9 + 0.12 * (index % 3)
    local lift = 0.25 * ((index % 4) - 1.5)
    local points = {}
    for k = 0, 6 do
        local a = angle0 + toward * k * math.pi / 3.2
        points[#points + 1] = { home[1] + radius * math.cos(a), lift + 0.15 * math.sin(2 * a),
                                home[3] + radius * math.sin(a) }
    end
    local side = (index % 2 == 0) and 0.5 or -0.5
    -- {{{ local function at()
    local function at(dx, dy, dz) return { toward * dx, lift * 0.5 + dy, dz } end
    -- }}}
    if role == "pass" then
        points[#points + 1] = at(-1.2, 0, side * 0.6)
        points[#points + 1] = at(0.4, 0, side * 0.2)
        points[#points + 1] = at(2.0, 0.3, side * 1.6)
        points[#points + 1] = at(0.6, 1.3, side * 2.0)
        points[#points + 1] = at(-1.6, 0.8, side * 1.4)
    else
        points[#points + 1] = at(-1.5, 0, side * 0.7)
        points[#points + 1] = at(-0.7, 0, side * 0.3)
        points[#points + 1] = at(0.0, 0, side * 0.08)
        points[#points + 1] = at(-0.6, -0.5, side * 0.6)
        points[#points + 1] = at(-1.7, -0.3, side * 1.1)
    end
    local hues = COLOURS[flock]
    instances[#instances + 1] = {
        tag = "fish", flock = flock, role = role,
        mesh = "octahedron", hue = hues[index % #hues + 1], scale = 0.25, stretch = { 1.9, 0.75, 0.6 },
        style = "glow", face_motion = true, shard_distance = 2.2,
        motion = { kind = "spline", cycles = 1, points = points },
        shatter_keys = role == "burst" and { { 0, 0 }, { 0.71, 0 }, { 0.76, 1 }, { 0.82, 1 }, { 0.9, 0 } } or nil,
    }
end
-- }}}

for _, flock in ipairs({ "A", "B" }) do
    for index = 0, PER_FLOCK - 1 do
        journey(flock, index, (index % 2 == 0) and "pass" or "burst")
    end
    -- a slow-turning coral at each home, for the shoal to circle
    instances[#instances + 1] = {
        tag = "home", mesh = flock == "A" and "icosahedron" or "star_prism",
        hue = flock == "A" and "violet" or "gold", scale = 0.3, style = "glow",
        motion = { kind = "fixed", at = HOMES[flock] }, spin = { axis = { 0, 1, 0 }, turns = 1 },
    }
end
return {
    name = "twin-reef",
    size = 320, frames = 180, delay_cs = 5,
    camera = { fov = 58,
               motion = { kind = "orbit", radius = 5.4, height = 1.9, cycles = 1, target = { 0, 0, 0 },
                          bob = { amount = 0.4, cycles = 2 } } },
    framing = { tag = "fish", at_least = 10 },
    stars = { count = 110, seed = 281, hues = { "ice", "rose", "gold" } },
    instances = instances,
}
