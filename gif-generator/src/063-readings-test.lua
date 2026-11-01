-- 063-readings-test.lua — proof for three readings (issue 602), with no
-- model and no cluster.
--
-- What this is, generally: fake transports stand in for the doors. One
-- reads the sentence well, one misspells a word every time, and one is
-- a door that doesn't answer. The readings land in a folder in RAM, the
-- passed one is filmed small and read back by the studio's own reader,
-- the pick page shows all three (the two that didn't pass dimmed, with
-- their words), and picking moves the score into a stand-in input/
-- whole, never over another, remembering who heard it.
-- Run: luajit src/063-readings-test.lua DIR

local DIR = "/mnt/mtwo/programming/ai-stuff/gif-generator"
if arg and arg[1] then DIR = arg[1] end
package.path = DIR .. "/src/?.lua;" .. package.path

local readings = dofile(DIR .. "/src/061-readings.lua")
local decode = require("040-gif-decode")

local passed, failed = 0, 0

-- {{{ local function check()
local function check(name, condition)
    if condition then
        passed = passed + 1
    else
        failed = failed + 1
        print("FAIL: " .. name)
    end
end
-- }}}

-- {{{ local function slurp()
local function slurp(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local text = f:read("*a")
    f:close()
    return text
end
-- }}}

-- who reads, with which seed
local a, b, c = { name = "a" }, { name = "b" }, { name = "c" }
local one = readings.plan({ a })
check("one door reads three times with three seeds",
      one[1].door == a and one[3].door == a
      and one[1].seed == 1 and one[2].seed == 2 and one[3].seed == 3)
local three = readings.plan({ a, b, c })
check("three doors read once each",
      three[1].door == a and three[2].door == b and three[3].door == c
      and three[3].seed == 1)
local two = readings.plan({ a, b })
check("two doors share three readings, the first going round again",
      two[3].door == a and two[3].seed == 2)

-- a sentence as a folder name
check("a sentence becomes a folder name",
      readings.slug("Curve the ball, around the circle!") == "curve-the-ball-around-the-circle")
check("a sentence with no words is still a name", readings.slug("!!") == "reading")
local long = readings.slug(string.rep("spark ", 30))
check("a long sentence is cut, never on a dash", #long <= 48 and not long:find("%-$"))

-- {{{ local function reading()
-- A reading as a model says it; `cycles` is the word one fake misspells.
local function reading(cycles)
    return '{"tool":"canvas","size":192,"fps":25,"length":1.0,"seed":5,"background":"sky"}\n'
        .. '{"tool":"camera","distance":7,"fov":44,"tilt":0.3}\n'
        .. '{"tool":"world","stars":{"count":20,"seed":3,"hues":["ice"]}}\n'
        .. '{"tool":"shape","tag":"ball","mesh":"icosahedron","hue":"violet",'
        .. '"scale":0.5,"style":"glow","motion":{"kind":"orbit","radius":2,"'
        .. cycles .. '":1},"prose":"curve the ball around the circle"}\n'
        .. '{"tool":"stroke","at":0.0,"lasts":1.0,"color":"jade","fade":"in-out",'
        .. '"shape":{"kind":"point","at":{"tip":"ball"}}}'
end
-- }}}

local prose = "curve the ball around the circle"
local good = readings.one(DIR, prose, function() return reading("cycles") end)
local stubborn = readings.one(DIR, prose, function() return reading("cycels") end)
local silent = readings.one(DIR, prose, function()
    error("porch: door 'c' (http://10.0.0.9:8080/completion) gave no completion: "
          .. "curl: (7) Failed to connect", 0)
end)
check("a good reading passes, with what was heard",
      good.ok and good.heard[4]:find("^ball: a violet icosahedron") ~= nil)
check("a stubborn reading fails with the wall's words and its draft",
      not stubborn.ok and stubborn.errors:find("no word 'cycels'", 1, true) ~= nil
      and stubborn.draft ~= nil)
check("a door that doesn't answer is a reading that says so, not an error",
      not silent.ok and silent.errors:find("door 'c'", 1, true) ~= nil)

-- three readings land, side by side
local root = os.tmpname()
os.remove(root)
local folder = root .. "/readings/" .. readings.slug(prose)
os.execute("mkdir -p '" .. folder .. "' '" .. root .. "/input'")
local f = assert(io.open(folder .. "/prose.txt", "w"))
f:write(prose .. "\n")
f:close()
readings.land(folder, 1, good, "a", 1)
readings.land(folder, 2, stubborn, "b", 1)
readings.land(folder, 3, silent, "c", 1)

local film = slurp(folder .. "/reading-1.gif")
local facts = film and decode.facts(film)
check("the passed reading is filmed small: 192 pixels shown at 96, a whole loop",
      facts ~= nil and facts.width == 96 and facts.height == 96 and facts.frame_count == 25)
check("the passed reading's score lands beside its film",
      (slurp(folder .. "/reading-1.lua") or ""):find("tip(\"ball\")", 1, true) ~= nil)
check("a failed reading keeps its draft and films nothing",
      slurp(folder .. "/reading-2.draft.lua") ~= nil and slurp(folder .. "/reading-2.gif") == nil)
local said = readings.read_said(folder, 2)
check("what each reading said is read back",
      said.door == "b" and said.seed == 1 and said.passed == false
      and said.wall[2]:find("nearest legal: cycles", 1, true) ~= nil)

local page = slurp(readings.page(folder, prose, 3, readings.slug(prose)))
local _, dimmed = page:gsub('class="reading failed"', "")
check("the pick page shows the sentence and all three, two dimmed",
      page:find(prose, 1, true) ~= nil and dimmed == 2
      and page:find('src="reading-1.gif"', 1, true) ~= nil)
check("the pick page says what was heard and how to pick",
      page:find("<li>ball: a violet icosahedron", 1, true) ~= nil
      and page:find("./porch --pick curve-the-ball-around-the-circle 1", 1, true) ~= nil)
check("the pick page shows the wall's words and the silent door, escaped",
      page:find("no word 'cycels'", 1, true) ~= nil
      and page:find("door 'c'", 1, true) ~= nil
      and page:find("tip(\"ball\")", 1, true) ~= nil)
check("the pick page needs no script", page:find("<script", 1, true) == nil)

-- picking: whole, never over another, remembered
local picked = readings.pick(root, folder, 1, "the-ball")
check("picking moves the score into input/",
      slurp(picked) == slurp(folder .. "/reading-1.lua"))
check("picking leaves no partial behind",
      io.popen("ls -A '" .. root .. "/input'"):read("*a") == "porch-history.txt\nthe-ball.lua\n")
check("picking never writes over a score",
      not pcall(readings.pick, root, folder, 1, "the-ball"))
check("a reading with no score can't be picked",
      not pcall(readings.pick, root, folder, 2, "other"))
local history = slurp(root .. "/input/porch-history.txt") or ""
check("the history remembers which door heard it",
      history:find("a heard it best (seed 1), of curve-the-ball-around-the-circle: "
                   .. prose, 1, true) ~= nil)

os.execute("rm -rf '" .. root .. "'")

print(string.format("readings: %d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
