-- choreography-test.lua - checks the stage manager keeps its promises.
--
-- What this is, generally: the gallery promises every film loops without a
-- seam, and that each word of the scene vocabulary does what its comment
-- says. This asks the stage manager directly -- no pixels -- where every
-- shape of every scene is at the first moment and at the moment one full
-- loop later, and checks they agree; then it poses a few purpose-built
-- shapes to check each word of the vocabulary one at a time -- the arc, the
-- lag, the sway, the rock, the burst, the camera, the ground, rolling,
-- becoming, trails, parts, waves, curves and wind -- and checks that
-- broken scenes are refused.
--
-- Usage: luajit choreography-test.lua DIR     (DIR = the tool's folder)
-- Prints one line per check; exits 1 if any failed.

local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/delta-version/scripts/readme-gallery"
local meshes = dofile(DIR .. "/meshes.lua")
local choreography = dofile(DIR .. "/choreography.lua")
local fluid = dofile(DIR .. "/fluid.lua")

local HUES = {
    rose = { 1, 0.2, 0.45 }, ember = { 1, 0.42, 0.1 }, gold = { 1, 0.8, 0.15 },
    jade = { 0.15, 1, 0.35 }, teal = { 0.1, 0.9, 0.8 }, ice = { 0.4, 0.7, 1 },
    violet = { 0.55, 0.25, 1 }, cloud = { 1, 1, 1 },
}

local passed, failed = 0, 0
-- {{{ local function check()
local function check(label, ok)
    if ok then
        passed = passed + 1
        print("  ok   - " .. label)
    else
        failed = failed + 1
        print("  FAIL - " .. label)
    end
end
-- }}}

-- {{{ local function close()
local function close(a, b) return math.abs(a - b) < 1e-7 end
-- }}}

-- {{{ local function same_pose()
-- Two placed shapes agree in everything a viewer could see.
local function same_pose(a, b)
    for i = 1, 3 do
        if not close(a.position[i], b.position[i]) then return false end
        if not close(a.stretch[i], b.stretch[i]) then return false end
        if not close(a.rgb[i], b.rgb[i]) then return false end
        for j = 1, 3 do
            if not close(a.rotation[i][j], b.rotation[i][j]) then return false end
        end
    end
    return close(a.scale, b.scale) and close(a.shatter, b.shatter) and close(a.glow, b.glow)
        and ((a.morph_p == nil and b.morph_p == nil) or close(a.morph_p, b.morph_p))
end
-- }}}

-- {{{ local function scene_files()
local function scene_files()
    local list = {}
    local pipe = io.popen(string.format("ls %q", DIR .. "/scenes"))
    for line in pipe:lines() do
        if line:match("%.lua$") then list[#list + 1] = DIR .. "/scenes/" .. line end
    end
    pipe:close()
    list[#list + 1] = DIR .. "/tests/tiny.lua"
    list[#list + 1] = DIR .. "/tests/tiny-new.lua"
    list[#list + 1] = DIR .. "/tests/tiny-third.lua"
    list[#list + 1] = DIR .. "/tests/tiny-fluid.lua"
    table.sort(list)
    return list
end
-- }}}

print("every scene loops without a seam")
for _, path in ipairs(scene_files()) do
    local scene = choreography.load(dofile(path), HUES, meshes, fluid)
    local first, again = choreography.pose(scene, 0), choreography.pose(scene, 1)
    local all_same = #first == #again
    for i = 1, #first do all_same = all_same and same_pose(first[i], again[i]) end
    -- the camera too: eye, target and roll one loop in match the start
    -- (a still camera has no view at all, which trivially matches)
    local view0, view1 = choreography.camera(scene, 0), choreography.camera(scene, 1)
    if view0 then
        for axis = 1, 3 do
            all_same = all_same and close(view0.eye[axis], view1.eye[axis])
                                and close(view0.target[axis], view1.target[axis])
        end
        -- a roll of whole turns ends a whole number of turns round
        local roll_gap = (view1.roll - view0.roll) / (2 * math.pi)
        all_same = all_same and close(roll_gap, math.floor(roll_gap + 0.5))
    end
    check(scene.name .. ": the moment after the last frame is the first frame"
          .. (view0 and " (camera included)" or ""), all_same)
end

-- {{{ local function one()
-- A one-shape scene for probing a single word of the vocabulary.
local function one(instance)
    return choreography.load({ name = "probe", size = 16, frames = 4, instances = { instance } }, HUES, meshes)
end
-- }}}

print("each new word does what it says")
do
    local s = one({ mesh = "cube", hue = "gold",
                    motion = { kind = "arc", radius = 2, cycles = 1, center = { 0, 0, 0 } } })
    local start, crown = choreography.pose(s, 0)[1], choreography.pose(s, 0.5)[1]
    check("arc: starts at the left foot", close(start.position[1], -2) and close(start.position[2], 0))
    check("arc: starts at size zero, so the return jump is unseen", close(start.scale, 0))
    check("arc: stands at the crown, full size, halfway", close(crown.position[2], 2) and close(crown.scale, 1))
end
do
    local path = { kind = "lissajous", size = { 1, 2, 3 }, freq = { 1, 2, 3 } }
    local leader = one({ mesh = "cube", hue = "gold", motion = path })
    local follower = one({ mesh = "cube", hue = "gold",
        motion = { kind = "lissajous", size = { 1, 2, 3 }, freq = { 1, 2, 3 }, lag = 0.1, offset = { 0, -1, 0 } } })
    local ahead, behind = choreography.pose(leader, 0.3)[1], choreography.pose(follower, 0.4)[1]
    check("lag and offset: a follower stands where the leader was, shifted",
        close(ahead.position[1], behind.position[1]) and close(ahead.position[2] - 1, behind.position[2]))
end
do
    local s = one({ mesh = "cube", hue = "gold",
        motion = { kind = "fixed", sway = { { vector = { 0, 0, 0.5 }, cycles = 1 } } } })
    check("sway: a quarter loop in, pushed its full reach", close(choreography.pose(s, 0.25)[1].position[3], 0.5))
end
do
    local s = one({ mesh = "cube", hue = "gold", rock = { axis = { 0, 0, 1 }, center = 0.5, amount = 0.25, cycles = 1 } })
    local r = choreography.pose(s, 0.25)[1].rotation
    check("rock: tipped to center plus amount at the crest", close(math.atan2(r[2][1], r[1][1]), 0.75))
end
do
    local s = one({ mesh = "superball", hue = "rose", burst = { amount = 0.8, cycles = 1, power = 1 }, shards = "own" })
    check("burst: whole in the trough", close(choreography.pose(s, 0.75)[1].shatter, 0))
    check("burst: fully open on the crest", close(choreography.pose(s, 0.25)[1].shatter, 0.8))
    local shards = choreography.pose(s, 0.25)[1].shard_rgbs
    check("shards own: every shard keeps the shape's colour", #shards == 1 and shards[1] == HUES.rose)
end
do
    local s = one({ mesh = "cone", hue = "rose", pulse = { amount = 0.5, cycles = 1, axes = { 1, 0, 1 } } })
    local p = choreography.pose(s, 0.25)[1]
    check("pulse with axes: stretches only those axes", close(p.stretch[1], 1.5) and close(p.stretch[2], 1)
        and close(p.scale, 1))
end
do
    local horn = meshes.build("horn", {})
    local ok = true
    for _, face in ipairs(horn.faces) do
        local a, b, c = horn.verts[face[1]], horn.verts[face[2]], horn.verts[face[3]]
        local nx = (b[2] - a[2]) * (c[3] - a[3]) - (b[3] - a[3]) * (c[2] - a[2])
        local ny = (b[3] - a[3]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[3] - a[3])
        local nz = (b[1] - a[1]) * (c[2] - a[2]) - (b[2] - a[2]) * (c[1] - a[1])
        local mx, my, mz = (a[1] + b[1] + c[1]) / 3, (a[2] + b[2] + c[2]) / 3, (a[3] + b[3] + c[3]) / 3
        -- base cap faces backward; everything else faces away from the axis or forward
        if mx < -1.09 then ok = ok and nx < 0 else ok = ok and (ny * my + nz * mz + math.max(0, nx)) > -1e-9 end
    end
    check("horn: every face points out of the horn", ok)
end

print("the camera and the conveyor do what they say")
do
    local s = one({ mesh = "cube", hue = "gold",
                    motion = { kind = "conveyor", from = { 0, 0, -10 }, to = { 0, 0, 0 }, cycles = 1 } })
    check("conveyor: starts far away at size zero", close(choreography.pose(s, 0)[1].scale, 0)
          and close(choreography.pose(s, 0)[1].position[3], -10))
    check("conveyor: full size and halfway along at the middle",
          close(choreography.pose(s, 0.5)[1].scale, 1) and close(choreography.pose(s, 0.5)[1].position[3], -5))
end
-- {{{ local function with_camera()
local function with_camera(camera)
    return choreography.load({ name = "camera-probe", size = 16, frames = 4, camera = camera,
        instances = { { mesh = "cube", hue = "gold" } } }, HUES, meshes)
end
-- }}}
do
    local s = with_camera({ motion = { kind = "orbit", radius = 4, height = 1, cycles = 1 } })
    local v = choreography.camera(s, 0.25)
    check("camera orbit: a quarter turn round, radius and height kept, looking at the middle",
        close(v.eye[1], 0) and close(v.eye[2], 1) and close(v.eye[3], 4) and close(v.target[1], 0))
end
do
    local s = with_camera({ motion = { kind = "crane", radius = 3, low = 0, high = 2, cycles = 1, follow = 0.5 } })
    local v = choreography.camera(s, 0.5)
    check("camera crane: at the top halfway, the target raised half as far", close(v.eye[2], 2) and close(v.target[2], 1))
end
do
    local s = with_camera({ motion = { kind = "fly", size = { 2, 0, 0 }, freq = { 1, 1, 1 }, target = "ahead" } })
    local v = choreography.camera(s, 0)
    check("camera fly ahead: looks the way it is going", v.target[1] > v.eye[1])
end
do
    local s = with_camera({ motion = { kind = "orbit", radius = 4, cycles = 1 }, roll = { turns = 1 } })
    check("camera roll turns: half a turn of the horizon halfway", close(choreography.camera(s, 0.5).roll, math.pi))
end
do
    local still = choreography.load({ name = "still", size = 16, frames = 4, camera = { distance = 7, tilt = 0.3 },
        instances = { { mesh = "cube", hue = "gold" } } }, HUES, meshes)
    check("still camera: no view, so the original still-camera drawing is used", choreography.camera(still, 0.3) == nil)
end
-- {{{ local function refused()
local function refused(camera)
    return not pcall(with_camera, camera)
end
-- }}}
check("camera refusal: half an orbit", refused({ motion = { kind = "orbit", radius = 4, cycles = 0.5 } }))
check("camera refusal: an unknown camera motion", refused({ motion = { kind = "teleport" } }))
check("camera refusal: looking ahead without flying", refused({ motion = { kind = "orbit", radius = 4, cycles = 1, target = "ahead" } }))
check("camera refusal: half a turn of roll",
      refused({ motion = { kind = "orbit", radius = 4, cycles = 1 }, roll = { turns = 0.5 } }))

print("the fourth-round words do what they say")
-- {{{ local function grounded()
-- A probe scene with a gently sloping ground (height = x / 10).
local GROUND = { waves = { { 0.1, 1, 0, 0 } }, base = 0 }
local function grounded(instances, extra)
    local scene = { name = "ground-probe", size = 16, frames = 4, ground = GROUND, instances = instances }
    for k, v in pairs(extra or {}) do scene[k] = v end
    return choreography.load(scene, HUES, meshes)
end
-- }}}
do
    local s = grounded({ { mesh = "cube", hue = "gold",
        motion = { kind = "keyframes", cycles = 1, lift = 0.5, points = { { 0, 0, 0 }, { 0.5, 2, 0 }, { 0.75, 2, 0, 5 } },
                   sizes = { { 0, 1 }, { 0.8, 1 }, { 0.9, 0 } } } } })
    local p0, p25, p75 = choreography.pose(s, 0)[1], choreography.pose(s, 0.25)[1], choreography.pose(s, 0.75)[1]
    check("keyframes: starts at the first point, resting on the ground plus lift", close(p0.position[2], 0.5))
    check("keyframes: halfway between two ground points follows the ground",
        close(p25.position[2], 0.1 * math.sin(p25.position[1]) + 0.5))
    check("keyframes: a point with a height hangs at that height", close(p75.position[2], 5))
    check("keyframes: sizes shrink the shape to nothing", close(choreography.pose(s, 0.9)[1].scale, 0))
end
do
    -- a ball rolled a straight metre along flat ground turns by 1/radius
    local flat = choreography.load({ name = "roll-probe", size = 16, frames = 4, ground = { base = 0 },
        instances = { { mesh = "superball", hue = "gold", roll = { radius = 0.5 },
            motion = { kind = "keyframes", cycles = 1, lift = 0.5, points = { { 0, 0, 0 }, { 0.5, 1, 0 } } } } } },
        HUES, meshes)
    local r = choreography.pose(flat, 0.5)[1].rotation
    -- rolling toward +x turns about -z: the top of the ball moves forward
    check("roll: a metre rolled at radius 0.5 turns the ball 2 radians", close(math.atan2(-r[1][2], r[1][1]), 2))
end
do
    local s = one({ mesh = "cube", hue = "gold",
        motion = { kind = "conveyor", from = { 0, 0, 0 }, to = { 10, 0, 0 }, cycles = 1 },
        becomes = { at = 0.5, over = 0.1, mesh = "star_prism", hue = "rose" } })
    local early, late = choreography.pose(s, 0.3), choreography.pose(s, 0.7)
    check("becomes: unfolds into two shapes, the old and the new", #s.instances == 2)
    check("becomes: before the moment, the old shape shows and the new does not",
        early[1].scale > 0.9 and close(early[2].scale, 0))
    check("becomes: after it, the new shape shows and the old does not",
        close(late[1].scale, 0) and late[2].scale > 0.9)
    check("becomes: the new shape rides the same route", close(late[1].position[1], late[2].position[1]))
end
do
    local s = one({ mesh = "cube", hue = "gold", motion = { kind = "conveyor", from = { 0, 0, 0 }, to = { 10, 0, 0 }, cycles = 1 },
                    trail = { count = 3, spacing = 0.05, shrink = 0.5, hues = { "rose" }, full_speed = 1 } })
    local now = choreography.pose(s, 0.5)
    check("trail: unfolds into the leader and three followers", #s.instances == 4)
    check("trail: each follower stands where the leader was a spacing earlier",
        close(now[2].position[1], choreography.pose(s, 0.45)[1].position[1]))
    check("trail: each follower half the size of the one before", close(now[3].scale, 0.25 * now[1].scale))
    local still = one({ mesh = "cube", hue = "gold", motion = { kind = "fixed" }, trail = { count = 2 } })
    check("trail: a resting shape leaves no sparks", close(choreography.pose(still, 0.5)[2].scale, 0))
end
do
    local s = one({ mesh = "cube", hue = "gold", scale = 2, motion = { kind = "fixed", at = { 1, 0, 0 } },
                    orient = { axis = { 0, 1, 0 }, angle = math.pi / 2 },
                    parts = { { mesh = "octahedron", hue = "rose", offset = { 1, 0, 0 },
                                parts = { { mesh = "cube", hue = "ice", scale = 0.5, offset = { 0, 1, 0 } } } } } })
    local placed = choreography.pose(s, 0)
    -- turned a quarter about y, the part's +x offset of 1 (sized 2) lands at -z
    check("parts: a part rides its parent, turned and sized with it",
        #placed == 3 and close(placed[2].position[1], 1) and close(placed[2].position[3], -2))
    check("parts: a part's part rides the part, and sizes compound",
        close(placed[3].position[2], 2) and close(placed[3].scale, 1))
    local spine = one({ motion = { kind = "fixed" }, parts = { { mesh = "cube", hue = "gold" } } })
    check("parts: a shape carrying only parts is hidden itself", choreography.pose(spine, 0)[1].hidden == true)
end
do
    local s = one({ mesh = "cube", hue = "gold", motion = { kind = "wave", from = { 0, 0, 0 }, to = { 4, 0, 0 },
                    amplitude = 0.5, waves = 1, cycles = 1 } })
    local p = choreography.pose(s, 0.25)[1].position
    check("wave: a quarter along, one crest up and a quarter of the way", close(p[1], 1) and close(p[2], 0.5))
end
do
    local s = one({ mesh = "cube", hue = "gold", motion = { kind = "bezier", cycles = 1,
                    points = { { 0, 0, 0 }, { 0, 3, 0 }, { 3, 3, 0 }, { 3, 0, 0 } } } })
    local mid = choreography.pose(s, 0.5)[1]
    check("bezier: starts at size zero at its first point", close(choreography.pose(s, 0)[1].scale, 0))
    check("bezier: halfway, at the curve's midpoint", close(mid.position[1], 1.5) and close(mid.position[2], 2.25))
end
do
    local s = choreography.load({ name = "stroke-probe", size = 16, frames = 4,
        instances = { { mesh = "cube", hue = "gold" } },
        strokes = { { from = { -2, 1, 0 }, to = { 2, 1, 0 }, amplitude = 0.3, waves = 2, drift = 1, segments = 8 } } },
        HUES, meshes)
    local line = choreography.strokes(s, 0.3)[1].points
    check("strokes: a wind stroke tapers to its ends", close(line[1][2], 1) and close(line[9][2], 1) and close(line[9][1], 2))
    local a, b = choreography.strokes(s, 0)[1].points, choreography.strokes(s, 1)[1].points
    check("strokes: the travelling wave is back where it started one loop in", close(a[4][2], b[4][2]))
end
do
    local s = grounded({ { mesh = "cube", hue = "gold", motion = { kind = "fixed", at = { 1.5, 0.2, 0 }, on_ground = true } } })
    check("on_ground: height is measured up from the ground there",
        close(choreography.pose(s, 0)[1].position[2], 0.2 + 0.1 * math.sin(1.5)))
end
do
    local s = with_camera({ motion = { kind = "fly", size = { 2, 0, 2 }, freq = { 1, 1, 1 }, shift = { 0.25, 0, 0 },
                                       target = "ahead", lead = 0.25 } })
    local v = choreography.camera(s, 0)
    check("camera fly lead: looks at where it will be a quarter loop later",
        close(v.target[1], 0) and close(v.target[3], 2))
end
-- {{{ local function refused_scene()
local function refused_scene(scene)
    scene.name, scene.size, scene.frames = scene.name or "refusal", 16, 4
    return not pcall(choreography.load, scene, HUES, meshes, fluid)
end
-- }}}
check("refusal: keyframe moments out of order", refused_scene({ ground = GROUND, instances = { { mesh = "cube", hue = "gold",
    motion = { kind = "keyframes", cycles = 1, points = { { 0.5, 0, 0 }, { 0.2, 1, 0 } } } } } }))
check("refusal: resting on the ground in a scene with no ground", refused_scene({ instances = { { mesh = "cube", hue = "gold",
    motion = { kind = "keyframes", cycles = 1, points = { { 0, 0, 0 }, { 0.5, 1, 0 } } } } } }))
check("refusal: rolling on a motion that is not a route", refused_scene({ instances = { { mesh = "cube", hue = "gold",
    roll = { radius = 1 }, motion = { kind = "orbit", radius = 1, cycles = 1 } } } }))
check("refusal: a part that travels on its own", refused_scene({ instances = { { motion = { kind = "fixed" },
    parts = { { mesh = "cube", hue = "gold", motion = { kind = "fixed" } } } } } }))
check("refusal: a wind stroke drifting half a wave", refused_scene({ instances = { { mesh = "cube", hue = "gold" } },
    strokes = { { from = { 0, 0, 0 }, to = { 1, 0, 0 }, amplitude = 1, waves = 1, drift = 0.5 } } }))
check("refusal: a trail of no copies", refused_scene({ instances = { { mesh = "cube", hue = "gold",
    motion = { kind = "fixed" }, trail = { count = 0 } } } }))
check("refusal: a bezier with three points", refused_scene({ instances = { { mesh = "cube", hue = "gold",
    motion = { kind = "bezier", cycles = 1, points = { { 0, 0, 0 }, { 1, 1, 1 }, { 2, 2, 2 } } } } } }))

print("the fifth-round words, and the owner's requests, hold")
-- {{{ local function scene_named()
local function scene_named(name) return choreography.load(dofile(DIR .. "/scenes/" .. name .. ".lua"), HUES, meshes) end
-- }}}
-- {{{ local function near()
local function near(a, b, tolerance)
    return math.abs(a[1] - b[1]) < tolerance and math.abs(a[2] - b[2]) < tolerance and math.abs(a[3] - b[3]) < tolerance
end
-- }}}
do
    local s = one({ mesh = "cube", hue = "gold", motion = { kind = "spline", cycles = 1,
                    points = { { 0, 0, 0 }, { 2, 0, 0 }, { 2, 0, 2 }, { 0, 0, 2 } } } })
    check("spline: passes through each of its points in turn",
        near(choreography.pose(s, 0.25)[1].position, { 2, 0, 0 }, 1e-9)
        and near(choreography.pose(s, 0.5)[1].position, { 2, 0, 2 }, 1e-9))
end
do
    local s = with_camera({ motion = { kind = "lobed", radius = 4, pinch = 0.25, lobes = 2, cycles = 1 } })
    local pinched, swollen = choreography.camera(s, 0).eye, choreography.camera(s, 0.25).eye
    check("camera lobed: pinched in at the start, swollen out a quarter round",
        close(pinched[1], 3) and close(swollen[3], 5))
end
do
    local track = { points = { { 0, 0, 5 }, { 5, 0, 0 }, { 0, 0, -5 }, { -5, 0, 0 } },
                    twist = { from = 0.2, to = 0.6, turns = 1 } }
    local s = choreography.load({ name = "ride-probe", size = 16, frames = 4, track = track, instances = {},
        camera = { motion = { kind = "ride", cycles = 1, height = 0.5 } } }, HUES, meshes)
    local c0, _, _, up0 = choreography.track_frame(track, 0)
    local v0 = choreography.camera(s, 0)
    check("camera ride: sits above the rails, the track's height up",
        near(v0.eye, { c0[1] + up0[1] * 0.5, c0[2] + up0[2] * 0.5, c0[3] + up0[3] * 0.5 }, 1e-9))
    check("track corkscrew: half turned halfway through it, and the rider rolls with it",
        close(choreography.camera(s, 0.4).roll, math.pi))
    local _, _, side_after = choreography.track_frame(track, 0.7)
    local _, _, side_plain = choreography.track_frame({ points = track.points }, 0.7)
    check("track corkscrew: level again after it", near(side_after, side_plain, 1e-9))
end
do
    local s = scene_named("wizard-rings")
    local ok = true
    for _, inst in ipairs(s.instances) do
        if inst.tag == "ring" then
            local m = inst.motion
            local t0 = ((1 - m.phase) % 1) / m.cycles
            local first = choreography.pose(s, t0)
            -- this ring at its launch moment stands exactly at the wand's star
            local ring_here
            for i, candidate in ipairs(s.instances) do
                if candidate == inst then ring_here = first[i].position end
            end
            ok = ok and near(ring_here, choreography.part_position(s, "wand-star", t0), 1e-9)
        end
    end
    check("wizard-rings: every ring leaves from the wand's star where it was at that moment", ok)
end
do
    local s = scene_named("wizard-missiles")
    local ok, count = true, 0
    for i, inst in ipairs(s.instances) do
        if inst.tag == "dart" then
            count = count + 1
            local m = inst.motion
            for launch = 0, m.cycles - 1 do
                local t0 = ((launch + 1 - m.phase) % m.cycles) / m.cycles
                ok = ok and near(choreography.pose(s, t0)[i].position, choreography.part_position(s, "wand-star", t0), 1e-9)
            end
        end
    end
    check("wizard-missiles: every dart, every launch, leaves from the wand's star (" .. count .. " darts)", ok and count > 0)
end
do
    local s = scene_named("wizard-beam")
    local ok = true
    for frame = 0, 29 do
        local t = frame / 30
        local placed = choreography.pose(s, t)
        local tip, crystal
        for _, item in ipairs(placed) do
            if item.tag == "wand-star" then tip = item.position end
            if item.tag == "crystal" then crystal = item.position end
        end
        for _, strand in ipairs(choreography.beams(s, t, placed)) do
            ok = ok and near(strand.points[1], tip, 1e-12) and near(strand.points[#strand.points], crystal, 1e-12)
        end
    end
    check("wizard-beam: every strand is pinned to the wand's star and the crystal, every frame", ok)
end
do
    local s = scene_named("twin-reef")
    local tally = {}
    for _, inst in ipairs(s.instances) do
        if inst.flock then
            tally[inst.flock] = tally[inst.flock] or { pass = 0, burst = 0 }
            tally[inst.flock][inst.role] = tally[inst.flock][inst.role] + 1
        end
    end
    check("twin-reef: each shoal has as many passers as bursters",
        tally.A.pass == tally.A.burst and tally.B.pass == tally.B.burst and tally.A.pass == tally.B.pass)
    -- whenever any burster is shattered, every passer is well clear of the middle
    local clear = math.huge
    for k = 0, 359 do
        local placed = choreography.pose(s, k / 360)
        local bursting = false
        for i, inst in ipairs(s.instances) do
            if inst.role == "burst" and placed[i].shatter > 0.05 then bursting = true end
        end
        if bursting then
            for i, inst in ipairs(s.instances) do
                if inst.role == "pass" then
                    local p = placed[i].position
                    clear = math.min(clear, math.sqrt(p[1] ^ 2 + p[2] ^ 2 + p[3] ^ 2))
                end
            end
        end
    end
    check(string.format("twin-reef: bursts wait until the passers are through (nearest passer %.2f from the middle)", clear),
        clear > 1.0)
end
do
    local s = one({ mesh = "cube", hue = "gold", motion = { kind = "conveyor", from = { 0, 0, 0 }, to = { 1, 0, 0 }, cycles = 1 },
                    shatter_keys = { { 0, 0 }, { 0.5, 1 } } })
    check("shatter_keys: open at the keyed moment, whole at the other",
        close(choreography.pose(s, 0.5)[1].shatter, 1) and close(choreography.pose(s, 0)[1].shatter, 0))
end
do
    local cube = meshes.build("cube")
    check("radius_toward: a cube reaches 1/sqrt(3) of its corner distance straight out through a face",
        close(meshes.radius_toward(cube, { 1, 0, 0 }), 1 / math.sqrt(3)))
    local s = one({ mesh = "superball", hue = "gold", mesh_params = { grid = 2 },
                    morph_through = { cycles = 1, hold = 0.5, shapes = { "cube", "octahedron" }, hues = { "gold", "ice" } } })
    local holding, flowing = choreography.pose(s, 0.1)[1], choreography.pose(s, 0.375)[1]
    local solids = s.instances[1].morph_through._meshes
    check("morph_through: holds the first solid whole, then flows toward the next",
        holding.through.f == 0 and holding.through.a == solids[1] and holding.through.b == solids[2]
        and flowing.through.f > 0 and flowing.through.f < 1)
end
do
    -- a camera circling: at t = 0 it sits at +x moving toward +z, looking at
    -- the middle -- so the way it looks and the way it moves differ, and the
    -- streaks must follow the moving
    local s = choreography.load({ name = "streak-probe", size = 16, frames = 4, instances = { { mesh = "cube", hue = "gold" } },
        camera = { motion = { kind = "orbit", radius = 4, cycles = 1 } },
        streaks = { count = 5, seed = 3, cycles = 2, far = 10, near = 1, length = 1, inner = 0.5, outer = 2 } }, HUES, meshes)
    local a, b = choreography.streaks(s, 0), choreography.streaks(s, 1)
    local ok = #a == 5
    for i = 1, #a do
        local d = { a[i].points[1][1] - a[i].points[2][1], a[i].points[1][2] - a[i].points[2][2],
                    a[i].points[1][3] - a[i].points[2][3] }
        -- each dash lies along the heading (+z here), not the look (-x);
        -- the heading is measured over a sliver of time, so allow a sliver
        ok = ok and math.abs(d[1]) < 1e-3 and math.abs(d[2]) < 1e-3 and math.abs(d[3] - 1) < 1e-3
            and near(a[i].points[2], b[i].points[2], 1e-7)
    end
    check("streaks: laid along the way the camera is moving, back where they started one loop in", ok)
end
do
    local track = { points = { { 0, 0, 5 }, { 5, 0, 0 }, { 0, 0, -5 }, { -5, 0, 0 } },
                    twist = { from = 0.2, to = 0.6, turns = 1, radius = 1.5 } }
    local plain = { points = track.points }
    local swung = choreography.track_frame(track, 0.4)
    local base, _, _, up = choreography.track_frame(plain, 0.4)
    check("track corkscrew radius: halfway round, the track has swung over the top, twice the radius up",
        near(swung, { base[1] + up[1] * 3, base[2] + up[2] * 3, base[3] + up[3] * 3 }, 1e-9))
    check("track corkscrew radius: back on its line after the corkscrew",
        near(choreography.track_frame(track, 0.8), choreography.track_frame(plain, 0.8), 1e-9))
end
do
    local s = scene_named("candy-coaster")
    local ties, stars = 0, 0
    for _, inst in ipairs(s.instances) do
        if inst.tag == "tie" then ties = ties + 1 end
        if inst.tag == "star" then stars = stars + 1 end
    end
    check("track ties and trackside stars are laid out along it", ties == 80 and stars == 44)
end
check("refusal: morphing through a solid with dents", refused_scene({ instances = { { mesh = "superball", hue = "gold",
    morph_through = { cycles = 1, shapes = { "cube", "torus" } } } } }))
check("refusal: starting from a part nothing carries", refused_scene({ instances = { { mesh = "cube", hue = "gold",
    motion = { kind = "conveyor", from = { part = "nowhere" }, to = { 1, 0, 0 }, cycles = 1 } } } }))
check("refusal: a beam writhing half a time", refused_scene({ instances = { { tag = "a", mesh = "cube", hue = "gold" },
    { tag = "b", mesh = "cube", hue = "gold" } }, beams = { { from = "a", to = "b", amplitude = 1, waves = 1, writhe = 0.5 } } }))
check("refusal: riding a track the scene does not have", refused_scene({ instances = { { mesh = "cube", hue = "gold" } },
    camera = { motion = { kind = "ride", cycles = 1 } } }))
check("refusal: a track of three points", refused_scene({ instances = {},
    track = { points = { { 0, 0, 0 }, { 1, 0, 0 }, { 0, 0, 1 } } } }))
check("refusal: a corkscrew of half a turn", refused_scene({ instances = {},
    track = { points = { { 0, 0, 5 }, { 5, 0, 0 }, { 0, 0, -5 }, { -5, 0, 0 } }, twist = { from = 0.1, to = 0.3, turns = 0.5 } } }))
check("refusal: streaks with a camera standing still", refused_scene({ instances = { { mesh = "cube", hue = "gold" } },
    streaks = { count = 1, cycles = 1, far = 5, near = 1, length = 1, inner = 1, outer = 2 } }))
check("refusal: streaks rushing half a time", refused_scene({ instances = { { mesh = "cube", hue = "gold" } },
    camera = { motion = { kind = "orbit", radius = 4, cycles = 1 } },
    streaks = { count = 1, cycles = 1.5, far = 5, near = 1, length = 1, inner = 1, outer = 2 } }))

print("the seventh-round words -- blobs, lights, bands, liquid -- hold")
local raster = dofile(DIR .. "/raster.lua")
do
    local s = one({ tag = "wax", hue = "rose", scale = 0.4, blob = { group = "g", bands = 3, soft = 0.2 } })
    local item = choreography.pose(s, 0)[1]
    check("blob: posed as a soft body -- drawn, its size its radius, its group and bands kept",
        item.hidden == false and item.blob.group == "g" and item.blob.bands == 3 and close(item.scale, 0.4))
end
do
    local s = one({ tag = "machine", motion = { kind = "fixed" }, spin = { axis = { 0, 1, 0 }, turns = 1 },
                    parts = { { tag = "lamp", mesh = "cube", hue = "gold", offset = { 2, 0, 0 } } } })
    s.lights = { { tag = "lamp", hue = "cloud", strength = 2 } }
    local at0 = choreography.lights(s, 0, choreography.pose(s, 0))[1]
    local at4 = choreography.lights(s, 0.25, choreography.pose(s, 0.25))[1]
    check("point light: rides the lamp on its turning arm (a quarter turn moves it a quarter round)",
        near(at0.position, { 2, 0, 0 }, 1e-9) and near(at4.position, { 0, 0, -2 }, 1e-9) and close(at0.rgb[1], 2))
end
check("bands: a light's slant is cut into whole steps (4 bands: 0.1 -> 0, 0.6 -> 2/3, 0.99 -> 1, facing away -> 0)",
    raster.band_level(0.1, 4) == 0 and close(raster.band_level(0.6, 4), 2 / 3)
    and raster.band_level(0.99, 4) == 1 and raster.band_level(-0.5, 4) == 0)
do
    -- one blob of radius 1 at the middle, seen from 5 away: the middle pixel
    -- lands on its surface 4 away; a corner pixel sees nothing
    local canvas = raster.new(16, { distance = 5, fov = 40, tilt = 0 }, meshes)
    raster.clear(canvas)
    local blob = { position = { 0, 0, 0 }, scale = 1, rgb = { 1, 1, 1 }, blob = { group = "g", bands = 4, soft = 0.3 } }
    raster.draw_blobs(canvas, { blob }, { { position = { 0, 0, 10 }, rgb = { 1, 1, 1 } } })
    local mid = 16 * 32 + 16
    check("blob surface: the ray through the middle lands on the sphere 4 away, lit; a corner sees nothing",
        math.abs(canvas.depth[mid] - 0.25) < 0.002 and canvas.rgb[mid * 3] > 0.9 and canvas.depth[0] == 0)
    -- two blobs a little apart: with softness they melt into a bridge the
    -- middle ray lands on; with none, the middle ray passes between them
    local function between(soft)
        raster.clear(canvas)
        local a = { position = { -0.55, 0, 0 }, scale = 0.45, rgb = { 1, 1, 1 }, blob = { group = "g", bands = 4, soft = soft } }
        local b = { position = { 0.55, 0, 0 }, scale = 0.45, rgb = { 1, 1, 1 }, blob = { group = "g", bands = 4, soft = soft } }
        raster.draw_blobs(canvas, { a, b }, {})
        return canvas.depth[mid] > 0
    end
    check("blob surface: soft blobs melt into a bridge between them; hard ones leave a gap", between(0.5) and not between(0))
end
do
    local spec = { count = 30, seed = 9, radius = 0.15, box = { 0.7, 0.5, 0.4 }, stiffness = 800, drag = 3,
                   tilt = { axis = { 0, 0, 1 }, amount = 0.4, cycles = 1 }, substeps = 6, warmup = 1, blend = 3 }
    local a, b = fluid.simulate(spec, 24), fluid.simulate(spec, 24)
    local same = true
    for f = 0, 23 do
        for i = 1, spec.count do
            for k = 1, 3 do same = same and a.frames[f][i][k] == b.frames[f][i][k] end
        end
    end
    check("liquid: the same recipe and seed give the very same drops, frame by frame", same)
    local inside = true
    for f = 0, 23 do
        for _, p in ipairs(a.frames[f]) do
            inside = inside and math.abs(p[1]) <= 0.7 - 0.15 + 1e-9 and math.abs(p[2]) <= 0.5 - 0.15 + 1e-9
                and math.abs(p[3]) <= 0.4 - 0.15 + 1e-9
        end
    end
    check("liquid: every drop stays inside the invisible box", inside)
    -- {{{ local function gap()
    local function gap(p, q)
        local sum = 0
        for i = 1, #p do sum = sum + math.sqrt((p[i][1] - q[i][1]) ^ 2 + (p[i][2] - q[i][2]) ^ 2 + (p[i][3] - q[i][3]) ^ 2) end
        return sum / #p
    end
    -- }}}
    local steps = 0
    for f = 1, 23 do steps = steps + gap(a.frames[f - 1], a.frames[f]) end
    check("liquid: the join from the last frame to the first is no bigger a step than twice an ordinary one",
        gap(a.frames[23], a.frames[0]) <= 2 * steps / 23)
end
check("refusal: a blob with a mesh", refused_scene({ instances = { { mesh = "cube", hue = "gold", blob = {} } } }))
check("refusal: a blob of one band", refused_scene({ instances = { { hue = "gold", blob = { bands = 1 } } } }))
check("refusal: a light riding something that is not there", refused_scene({ instances = { { mesh = "cube", hue = "gold" } },
    lights = { { tag = "nowhere" } } }))
check("refusal: a liquid whose box tilts half a time", refused_scene({ instances = {},
    fluid = { count = 5, radius = 0.1, box = { 1, 1, 1 }, tilt = { axis = { 0, 0, 1 }, amount = 0.3, cycles = 0.5 } } }))
check("refusal: a liquid with no simulator handed in", not pcall(choreography.load, { name = "no-sim", size = 16,
    frames = 4, instances = {}, fluid = { count = 5, radius = 0.1, box = { 1, 1, 1 },
    tilt = { axis = { 0, 0, 1 }, amount = 0.3, cycles = 1 } } }, HUES, meshes))

print("")
print(string.format("%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
