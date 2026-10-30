-- 050-shape-wall-test.lua - checks the 3D wall keeps its promises.
--
-- What this is, generally: the wall (049-shape-wall.lua) promises that
-- every scene in the gallery speaks only legal words and keeps every rule,
-- that a scene with a dozen misspellings hears about all twelve in one pass,
-- each with the nearest legal word, that a scene with a dozen broken rules
-- (half a turn, a curve with three points, a shape with no colour) hears
-- about all twelve too, and that the word lists and the code agree.
-- This asks it directly, no pixels.
--
-- Usage: luajit src/050-shape-wall-test.lua DIR   (DIR = the gif-generator project)
-- Prints one line per check; exits 1 if any failed.

local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/gif-generator"
local meshes = dofile(DIR .. "/src/034-meshes.lua")
local choreography = dofile(DIR .. "/src/035-choreography.lua")
local scene_file = dofile(DIR .. "/src/045-scene-file.lua")
local wall = dofile(DIR .. "/src/049-shape-wall.lua")

-- The hue words the films hand in; only the names matter here.
local HUES = {}
for _, hue in ipairs({ "rose", "ember", "gold", "jade", "teal", "ice", "violet", "cloud" }) do
    HUES[hue] = { 1, 1, 1 }
end

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

-- {{{ local function scene_files()
-- Every scene in the gallery, then every test scene but the broken ones.
local function scene_files()
    local list = {}
    for _, folder in ipairs({ "/input/shapes", "/tests/shape-films" }) do
        local pipe = io.popen(string.format("ls %q", DIR .. folder))
        for line in pipe:lines() do
            if line:match("%.lua$") and line ~= "misspelled.lua" and line ~= "broken-numbers.lua"
               and line ~= "approved-films.lua" then
                list[#list + 1] = DIR .. folder .. "/" .. line
            end
        end
        pipe:close()
    end
    return list
end
-- }}}

local made, vocab = pcall(wall.vocabulary, HUES, meshes, choreography)
check("the word lists and the code that runs them name the same motions and shapes", made)
if not made then
    print("        " .. tostring(vocab))
    print(string.format("\n%d passed, %d failed", passed, failed))
    os.exit(1)
end

-- Every scene speaks only legal words.
local files, clean, first_problem = scene_files(), 0, nil
for _, path in ipairs(files) do
    local problems = wall.check(scene_file.read(path), vocab)
    if #problems == 0 then
        clean = clean + 1
    elseif not first_problem then
        first_problem = path:match("([^/]+)$") .. ": " .. problems[1]
    end
end
check(string.format("all %d scenes pass the wall (%d did)", #files, clean), clean == #files)
if first_problem then print("        " .. first_problem) end

-- The misspelled scene: every mistake, at once, each with its nearest word.
local EXPECTED = {
    "scene.camera.motion: no word 'radus' in an orbit camera motion -- nearest legal: radius",
    "scene: no word 'frams' in a scene -- nearest legal: frames",
    "scene.instances[1] (bloom).hue: no hue 'rsoe' -- nearest legal: rose",
    "scene.instances[1] (bloom).mesh: no shape 'icosahedorn' -- nearest legal: icosahedron",
    "scene.instances[1] (bloom).reacts[1].effect: no effect 'shater' -- nearest legal: shatter",
    "scene.instances[1] (bloom).spin: no word 'trns' in a spin -- nearest legal: turns",
    "scene.instances[1] (bloom).style: no style 'glwo' -- nearest legal: glow",
    "scene.instances[2] (hammer).motion: no word 'cycels' in a swing motion -- nearest legal: cycles",
    "scene.instances[3] (ring).mesh_params: no word 'majr' in a torus -- nearest legal: major",
    "scene.instances[3] (ring).motion.kind: no motion 'orbt' -- nearest legal: orbit",
    "scene.beams[1].from: nothing is tagged 'bloon' -- nearest tag: bloom",
    "scene.instances[1] (bloom).reacts[1].to: nothing is tagged 'hammr' -- nearest tag: hammer",
}
local misspelled = scene_file.read(DIR .. "/tests/shape-films/misspelled.lua")
local got = wall.check(misspelled, vocab)
check(string.format("the misspelled scene gets all %d mistakes in one pass (got %d)", #EXPECTED, #got),
      #got == #EXPECTED)
local said = {}
for _, line in ipairs(got) do said[line] = true end
for _, line in ipairs(EXPECTED) do
    check("the wall says: " .. line, said[line] == true)
end

-- choreography.load is behind the wall: the same scene is refused there,
-- with every mistake in the one refusal.
local loaded, refusal = pcall(choreography.load, scene_file.read(DIR .. "/tests/shape-films/misspelled.lua"),
                              HUES, meshes)
check("loading the misspelled scene is refused", not loaded)
check("the refusal counts all twelve, all at once",
      not loaded and tostring(refusal):match("12 problems, all at once") ~= nil)

-- The broken-numbers scene: every word spelled right, twelve rules broken,
-- all reported at once.
local BROKEN = {
    "scene.camera.motion.target: only a flying or lobed camera can look \"ahead\"",
    "scene.instances[1] (bloom).dim: must be a number from 0 to 1",
    "scene.instances[1] (bloom).spin.turns: must be a whole number, or the loop has a seam",
    "scene.instances[1] (bloom): needs a hue",
    "scene.instances[2] (ball).roll: needs a route motion (arc, bezier, conveyor, keyframes, spline, wave), not orbit",
    "scene.instances[2] (ball).morph: only a superball can morph",
    "scene.instances[3] (dart).motion.points: needs exactly 4",
    "scene.instances[4] (seed).becomes.at: must be a number between 0 and 1",
    "scene.instances[4] (seed).motion.cycles: must be a whole number, or the loop has a seam",
    "scene.instances[5] (walker).motion.on_ground: stands on the ground, but the scene has no `ground`",
    "scene.lights[1]: needs a tag to ride or a fixed `at`",
    "scene.strokes[1].drift: must be a whole number, or the loop has a seam",
}
local broken = wall.check(scene_file.read(DIR .. "/tests/shape-films/broken-numbers.lua"), vocab)
check(string.format("the broken-numbers scene gets all %d broken rules in one pass (got %d)", #BROKEN, #broken),
      #broken == #BROKEN)
local broken_said = {}
for _, line in ipairs(broken) do broken_said[line] = true end
for _, line in ipairs(BROKEN) do
    check("the wall says: " .. line, broken_said[line] == true)
end

-- A few words that are legal in one place and not another.
-- {{{ local function only()
-- The problems with a small scene, given the size and length every scene
-- needs.
local function only(scene)
    scene.size, scene.frames = scene.size or 16, scene.frames or 4
    return wall.check(scene, vocab)
end
-- }}}
check("a part may not travel (parts ride their parent)",
      #only({ instances = { { parts = { { mesh = "cube", hue = "gold", motion = { kind = "fixed" } } } } } }) == 1)
check("a cube takes no proportions", #only({ instances = { { mesh = "cube", hue = "gold", mesh_params = { grid = 4 } } } }) == 1)
check("a becomes may stop rolling with false", #only({ instances = { { mesh = "cube", hue = "gold",
      becomes = { at = 0.5, roll = false },
      motion = { kind = "conveyor", from = { 0, 0, 0 }, to = { 1, 0, 0 }, cycles = 1 } } } }) == 0)
check("a camera may look \"ahead\", but at nothing else",
      #only({ instances = { { mesh = "cube", hue = "gold" } },
                camera = { motion = { kind = "fly", freq = { 1, 1, 1 }, target = "ahead" } } }) == 0
      and #only({ instances = { { mesh = "cube", hue = "gold" } },
                camera = { motion = { kind = "fly", freq = { 1, 1, 1 }, target = "behind" } } }) == 1)
check("a route may start at a carried part, by its tag", #only({ instances = {
      { tag = "wand", mesh = "cone", hue = "gold" },
      { mesh = "cube", hue = "gold", motion = { kind = "conveyor", from = { part = "wand", plus = { 0, 1, 0 } },
        to = { 1, 1, 1 }, cycles = 1 } } } }) == 0)
check("a needed word is asked for", #only({ instances = { { mesh = "cube", hue = "gold",
      spin = { axis = { 0, 1, 0 } } } } }) == 1)
check("a misspelled needed word is not asked for twice", #only({ instances = { { mesh = "cube", hue = "gold",
      spin = { axis = { 0, 1, 0 }, trns = 1 } } } }) == 1)
check("a morph carried into a star is refused", #only({ instances = { { mesh = "superball", hue = "gold",
      morph = { cycles = 1 }, becomes = { at = 0.5, mesh = "star_prism" },
      motion = { kind = "conveyor", from = { 0, 0, 0 }, to = { 1, 0, 0 }, cycles = 1 } } } }) == 1)
check("a route's anchor is checked like any table", #only({ instances = {
      { tag = "wand", mesh = "cone", hue = "gold" },
      { mesh = "cube", hue = "gold", motion = { kind = "conveyor", from = { prat = "wand" },
        to = { 1, 1, 1 }, cycles = 1 } } } }) == 1)

print("")
print(string.format("%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
