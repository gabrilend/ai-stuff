--[[
Tests for model animation (Issue 523): track sampling, the node
hierarchy about pivots, matrix groups, part alphas, sequence choice and
playback, units' animations by state, and every model in the test maps
posed through every sequence.
]]

-- {{{ Setup paths
local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local ffi = require("ffi")
local anim = require("assets.anim")
local gpu = require("assets.gpu")
local animate = require("demo.wc3map.animate")
local mdx = require("parsers.mdx")
local mpq = require("mpq")
-- }}}

-- {{{ Test infrastructure
local test_count, pass_count = 0, 0

local function test(name, condition, msg)
    test_count = test_count + 1
    if condition then
        pass_count = pass_count + 1
        print("  [PASS] " .. name)
    else
        print("  [FAIL] " .. name .. (msg and ": " .. msg or ""))
    end
end

local function test_section(name)
    print("\n=== " .. name .. " ===")
end

local function near(a, b, eps) return math.abs(a - b) <= (eps or 1e-4) end

-- floats of a pose string
local function floats(p)
    local f = ffi.cast("const float*", p)
    local out = {}
    for i = 0, #p / 4 - 1 do out[i + 1] = f[i] end
    return out
end

-- a 3 x 4 matrix (12 floats from 1-based index at) applied to a point
local function apply(f, at, x, y, z)
    return f[at] * x + f[at + 1] * y + f[at + 2] * z + f[at + 3],
           f[at + 4] * x + f[at + 5] * y + f[at + 6] * z + f[at + 7],
           f[at + 8] * x + f[at + 9] * y + f[at + 10] * z + f[at + 11]
end
-- }}}

-- {{{ A small model: a root, and an arm on it that turns a quarter about z
local s = math.sqrt(0.5)
local function model()
    return {
        sequences = {
            { name = "Stand", start = 0, finish = 1000, move_speed = 0, non_looping = false, rarity = 0 },
            { name = "Stand - 2", start = 2000, finish = 3000, move_speed = 0, non_looping = false, rarity = 0 },
            { name = "Stand Ready", start = 4000, finish = 5000, move_speed = 0, non_looping = false, rarity = 0 },
            { name = "Walk", start = 6000, finish = 7000, move_speed = 200, non_looping = false, rarity = 0 },
            { name = "Death", start = 8000, finish = 9000, move_speed = 0, non_looping = true, rarity = 0 },
            { name = "Attack - 1", start = 10000, finish = 10500, move_speed = 0, non_looping = false, rarity = 0 },
        },
        global_sequences = {},
        bones = {
            { name = "root", id = 0, parent = -1, flags = 0, tracks = {
                KGTR = { interpolation = 1, keys = {
                    { frame = 6000, value = { 0, 0, 0 } }, { frame = 7000, value = { 10, 0, 0 } } } } } },
            { name = "arm", id = 1, parent = 0, flags = 0, tracks = {
                KGRT = { interpolation = 1, keys = {
                    { frame = 0, value = { 0, 0, 0, 1 } }, { frame = 1000, value = { 0, 0, s, s } } } } } },
        },
        helpers = {},
        pivots = { { 0, 0, 0 }, { 0, 0, 100 } },
        geosets = { {
            vertices = { 0, 0, 0, 100, 0, 100, 50, 0, 50 },
            normals = { 0, 0, 1, 0, 0, 1, 0, 0, 1 },
            face_types = { 4 }, face_counts = { 3 }, faces = { 0, 1, 2 },
            vertex_groups = { 0, 1, 2 }, group_sizes = { 1, 1, 2 }, group_indices = { 0, 1, 0, 1 },
            material = 0, uvs = { { 0, 0, 1, 0, 0, 1 } },
        } },
        geoset_animations = { { alpha = 1, flags = 0, color = { 1, 1, 1 }, geoset = 0, tracks = {
            KGAO = { interpolation = 0, keys = { { frame = 0, value = 1 }, { frame = 8000, value = 1 }, { frame = 8500, value = 0 } } } } } },
        materials = { { layers = { { filter_mode = 0, shading = 0, texture = 0, alpha = 1, tracks = {} } } } },
        textures = { { replaceable = 0, path = "", flags = 0 } },
    }
end
local m = model()
local rig = anim.rig(m, { { geoset = 0, layer = m.materials[1].layers[1] } }, { 0 })
-- }}}

-- {{{ Sampling
test_section("Sampling")
do
    local t = { interpolation = 1, keys = { { frame = 0, value = 0 }, { frame = 100, value = 10 } } }
    test("linear halfway", near(anim.sample1(t, -1, rig, 0, 100, 50, 0), 5))
    test("before the first key: the first", anim.sample1(t, -1, rig, 0, 100, -5, 0) == 0)
    test("no keys in the interval: the default", anim.sample1(t, -1, rig, 200, 300, 250, 0) == -1)
    local h = { interpolation = 2, keys = {
        { frame = 0, value = 0, inTan = 0, outTan = 0 }, { frame = 100, value = 10, inTan = 0, outTan = 0 } } }
    test("Hermite with flat tangents: halfway is half", near(anim.sample1(h, 0, rig, 0, 100, 50, 0), 5))
    test("Hermite eases in", anim.sample1(h, 0, rig, 0, 100, 25, 0) < 2.5)
    local r = { interpolation = 1, keys = { { frame = 0, value = { 0, 0, 0, 1 } }, { frame = 100, value = { 0, 0, 1, 0 } } } }
    local x, y, z, w = anim.sample_rotation(r, rig, 0, 100, 50, 0)
    test("slerp halfway round a half turn is a quarter turn", near(z, s) and near(w, s) and near(x, 0) and near(y, 0))
    local g = { interpolation = 1, global = 0, keys = { { frame = 0, value = 0 }, { frame = 100, value = 10 } } }
    local grig = { globals = { 100 } }
    test("a global sequence runs on the clock", near(anim.sample1(g, 0, grig, 0, 1000, 999, 250), 5))
    local dup = { interpolation = 1, keys = { { frame = 0, value = 1 }, { frame = 0, value = 2 }, { frame = 10, value = 3 } } }
    local v = anim.sample1(dup, 0, rig, 0, 10, 0, 0)
    test("repeated key frames don't divide by zero", v == v)
end
-- }}}

-- {{{ Posing
test_section("Posing")
do
    test("nodes: parents before children", rig.nodes[1].name == "root" and rig.nodes[2].parent == 1)
    test("pose size: 1 part alpha + 3 groups x 12", rig.floats == 1 + 36)
    local f = floats(anim.pose_at(rig, 1, 0, 0))
    local x, y, z = apply(f, 2 + 12, 100, 0, 100)
    test("at the start the arm is where it was", near(x, 100) and near(y, 0) and near(z, 100))
    f = floats(anim.pose_at(rig, 1, 1000, 0))
    x, y, z = apply(f, 2 + 12, 100, 0, 100)
    test("a quarter turn about its pivot moves the arm's end", near(x, 0, 1e-3) and near(y, 100, 1e-3) and near(z, 100, 1e-3),
        string.format("%.3f %.3f %.3f", x, y, z))
    x, y, z = apply(f, 2, 100, 0, 100)
    test("the root's group doesn't move", near(x, 100) and near(y, 0))
    x, y, z = apply(f, 2 + 24, 100, 0, 100)
    test("a group of both is their average", near(x, 50, 1e-3) and near(y, 50, 1e-3))
    f = floats(anim.pose_at(rig, 4, 7000, 0))
    x, y, z = apply(f, 2 + 12, 100, 0, 100)
    test("a child follows its parent's translation", near(x, 110, 1e-3) and near(y, 0, 1e-3))
    test("a part shows while its geoset animation says so", near(floats(anim.pose_at(rig, 5, 8000, 0))[1], 1))
    test("and hides when it says so", near(floats(anim.pose_at(rig, 5, 8600, 0))[1], 0))
end
-- }}}

-- {{{ Playback
test_section("Playback")
do
    test("names: variants share a base", anim.base_name("Stand - 2") == "stand" and anim.base_name("Stand Ready") == "stand ready")
    local seen = {}
    for i = 1, 40 do
        local st = anim.state(0)
        anim.play(rig, st, "stand")
        seen[m.sequences[st.seq].name] = true
    end
    test("stand plays Stand and Stand - 2", seen["Stand"] and seen["Stand - 2"])
    test("but not Stand Ready", not seen["Stand Ready"])
    local st = anim.state(0)
    anim.play(rig, st, "stand ready")
    test("stand ready plays that", m.sequences[st.seq].name == "Stand Ready")
    st = anim.state(0)
    test("a name the model hasn't: false", anim.play(rig, st, "spell") == false)
    test("unless it falls back", anim.play(rig, st, "spell", { fallback = "stand" }) and st.name == "stand")
    st = anim.state(0)
    anim.play(rig, st, "walk")
    anim.step(rig, st, 1.25)
    test("a looping sequence starts over", near(st.t, 250) and not st.done)
    anim.play(rig, st, "death")
    anim.step(rig, st, 5)
    test("death holds its last frame", st.done and near(st.t, 1000))
    local a, b = anim.pose(rig, st), anim.pose(rig, st)
    test("poses are cached", a == b and rig.cached >= 1)
    st = anim.state(0)
    anim.play(rig, st, "walk", { rate = 2 })
    anim.step(rig, st, 0.25)
    test("rate speeds it up", near(st.t, 500))
end
-- }}}

-- {{{ Units
test_section("Units' animations")
do
    local u = { alive = true, speed = 400 }
    animate.unit(rig, u, 0)
    test("standing: stand", u.anim.name == "stand")
    u.route = { {} }
    animate.unit(rig, u, 0)
    test("moving: walk", u.anim.name == "walk")
    test("at its speed over the walk's (400 / 200)", near(u.anim.rate, 2))
    u.swing, u.weapon = 0, { attack_point = 0.3, backswing = 0.2 }
    animate.unit(rig, u, 0.1)
    test("swinging: attack, fitted to the swing (0.5 s / 0.5 s)", u.anim.name == "attack" and near(u.anim.rate, 1))
    local t1 = u.anim.t
    u.swing = 0.2
    animate.unit(rig, u, 0.1)
    test("the swing goes on", u.anim.t > t1)
    u.swing = 0
    animate.unit(rig, u, 0)
    test("a new swing starts it over", near(u.anim.t, 0))
    u.alive, u.swing = false, nil
    animate.unit(rig, u, 3)
    test("dead: death, held", u.anim.name == "death" and u.anim.done)
end
-- }}}

-- {{{ Onto the renderer
test_section("Onto the renderer")
do
    local calls = { meshes = {}, models = {} }
    local fake = {
        tex_create = function() return 1 end,
        mesh_create = function(v, i, skin) calls.meshes[#calls.meshes + 1] = { skin = skin }; return #calls.meshes end,
        model_create = function(parts, skins) calls.models[#calls.models + 1] = { parts = parts, skins = skins }; return #calls.models end,
    }
    local cache = gpu.new(fake, { texture = function() return nil end })
    local id = cache:build(model(), "small.mdx")
    local made = calls.models[1]
    test("each vertex's group goes with its mesh", calls.meshes[1].skin and #calls.meshes[1].skin == 3 * 2)
    test("the model's skins: one, of 3 groups", made.skins[1] == 3 and #made.skins == 1)
    test("its part names its skin", made.parts[1].skin == 1)
    local r = cache:rig(id)
    test("a rig for it", r and r.floats == 37)
end
-- }}}

-- {{{ Every model in the test maps
test_section("The test maps' models")
do
    local fake = { tex_create = function() return 1 end, mesh_create = function() return 1 end,
                   model_create = function() return 1 end }
    local seen, models, poses, bad, skins, idn = {}, 0, 0, 0, 0, 0
    local maps = {}
    local p = io.popen('ls "' .. DIR .. '"/assets/*.w3x "' .. DIR .. '"/assets/*.w3m 2>/dev/null')
    for f in p:lines() do maps[#maps + 1] = f end
    p:close()
    for _, f in ipairs(maps) do
        local ar = mpq.open(f)
        for _, name in ipairs(ar:list()) do
            local ok, d = pcall(ar.extract, ar, name)
            if ok and d and d:sub(1, 4) == "MDLX" and not seen[d] then
                seen[d] = true
                idn = idn + 1
                local m2 = mdx.parse(d)
                local cache = gpu.new(fake, { texture = function() return nil end })
                -- (a fresh cache per model: the fake gives every model id 1)
                local id = cache:build(m2, name)
                local r = id and cache:rig(id)
                if r then
                    models = models + 1
                    skins = skins + #r.skins
                    for si, sq in ipairs(r.sequences) do
                        for k = 0, 2 do
                            local pose = anim.pose_at(r, si, sq.start + (sq.finish - sq.start) * k / 2, 777)
                            poses = poses + 1
                            local fl = ffi.cast("const float*", pose)
                            for q = 0, #pose / 4 - 1 do
                                local v = fl[q]
                                if v ~= v or math.abs(v) > 1e7 then bad = bad + 1; break end
                            end
                        end
                    end
                end
            end
        end
        ar:close()
    end
    print(string.format("  %d models, %d skinned geosets, %d poses", models, skins, poses))
    test("the maps' models are rigged (250 or more)", models >= 250, tostring(models))
    test("every pose of every sequence is finite", bad == 0, bad .. " bad")
end
-- }}}

-- {{{ Summary
print("\n" .. string.rep("=", 50))
print(string.format("Tests: %d passed, %d failed", pass_count, test_count - pass_count))
if pass_count == test_count then
    print("ALL TESTS PASSED")
else
    print("SOME TESTS FAILED")
    os.exit(1)
end
-- }}}
