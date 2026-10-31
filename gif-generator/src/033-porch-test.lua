-- 033-porch-test.lua — proof for the listening porch's testable
-- whole: grammar, prompt, collector, retry loop, cluster reader.
--
-- What this is, generally: the porch runs against a scripted fake
-- orchestrator — no cluster required — that first answers with a
-- misspelled hue the grammar could never actually emit, to prove
-- the wall's teaching is quoted back and the second answer lands.
-- Since 704 it also proves the porch in both spaces: the grammar is
-- whole (058-gbnf.lua reads it), a mixed reading is sayable and a
-- misspelled 3D word is not, the 3D wall's teaching flows back, the
-- read-back lines (059-say-back.lua) say what was heard, and the
-- written score films.
-- Run: luajit src/033-porch-test.lua

local DIR = "/mnt/mtwo/programming/ai-stuff/gif-generator"
if arg and arg[1] then DIR = arg[1] end
package.path = DIR .. "/src/?.lua;" .. package.path

local porch = require("032-porch")

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

-- the grammar is a pure function of the vocabulary, carrying every
-- legal word and the structural tenths rule
local g1 = porch.grammar()
local g2 = porch.grammar()
check("the grammar is the same words twice", g1 == g2)
check("the grammar speaks every hue",
      g1:find("ember", 1, true) ~= nil
      and g1:find("violet", 1, true) ~= nil
      and g1:find("teal", 1, true) ~= nil)
check("the grammar speaks the fades and easings",
      g1:find("in-out", 1, true) ~= nil
      and g1:find("stroke", 1, true) ~= nil)
check("times are structurally tenths in the grammar",
      g1:find('tenths ::= [0-9]+ ("." [0-9])?', 1, true) ~= nil)

-- the prompt is assembled from the truth people read
local prompt = porch.prompt(DIR)
check("the prompt carries the format contract",
      prompt:find("The Score Format", 1, true) ~= nil)
check("the prompt carries the vision translation",
      prompt:find("left-hand", 1, true) ~= nil)

-- the collector orders arrivals by time, arrival breaking ties
local raw = porch.collect{
    { tool = "canvas", size = 64, fps = 25, length = 3.0, seed = 5 },
    { tool = "stroke", at = 2.0, lasts = 1.0, color = "ember",
      fade = "hold", prose = "the late one",
      shape = { kind = "point", at = {10, 10} } },
    { tool = "stroke", at = 0.0, lasts = 1.0, color = "ember",
      fade = "hold", name = "first-spoken",
      shape = { kind = "point", at = {20, 20} } },
    { tool = "stroke", at = 0.0, lasts = 1.0, color = "ember",
      fade = "hold", name = "second-spoken",
      shape = { kind = "point", at = {30, 30} } },
}
check("the collector sorts by declared time",
      raw.strokes[3].comment == "the late one")
check("equal times keep their arrival order",
      raw.strokes[1].name == "first-spoken"
      and raw.strokes[2].name == "second-spoken")

-- the whole porch against a scripted fake orchestrator: the first
-- reply misspells a hue (which the real grammar could never emit —
-- the point is proving the wall's teaching flows back), the second
-- corrects it
local saw_teaching = false
local attempts = 0
-- {{{ local function fake_orchestrator()
local function fake_orchestrator(request)
    attempts = attempts + 1
    if request.errors then
        saw_teaching = request.errors:find("nearest legal: ember",
                                           1, true) ~= nil
    end
    local hue = (attempts == 1) and "ebmer" or "ember"
    return '{"tool":"canvas","size":64,"fps":25,"length":2.0,'
        .. '"seed":9}\n'
        .. '{"tool":"stroke","at":0.0,"lasts":1.5,"color":"' .. hue
        .. '","fade":"in-out","ease":"stroke",'
        .. '"shape":{"kind":"arc","center":[32,32],"radius":20,'
        .. '"from":12,"to":7,"turn":"clockwise"},'
        .. '"prose":"a slow sweep, like a brush"}'
end
-- }}}
local text, compiled = porch.translate(DIR, "sweep it slow", fake_orchestrator)
check("the second reading passes the wall", text ~= nil)
check("it took exactly two attempts", attempts == 2)
check("the wall's teaching was quoted back to the model",
      saw_teaching)
check("the score carries the person's sentence as a comment",
      text:find("-- a slow sweep, like a brush", 1, true) ~= nil)
check("the compiled reading is ready to render",
      compiled ~= nil and #compiled.timeline.tracks == 1)

-- exhausted patience surfaces the errors WITH the draft
-- {{{ local function hopeless_orchestrator()
local function hopeless_orchestrator()
    return '{"tool":"canvas","size":64,"fps":25,"length":2.0,'
        .. '"seed":9}\n'
        .. '{"tool":"stroke","at":0.0,"lasts":1.5,"color":"ebmer",'
        .. '"fade":"hold","shape":{"kind":"point","at":[5,5]},'
        .. '"prose":"stubborn"}'
    end
-- }}}
local none, errors, draft = porch.translate(DIR, "x", hopeless_orchestrator)
check("hopelessness returns no score", none == nil)
check("the errors surface to the person",
      errors ~= nil and errors:find("ebmer", 1, true) ~= nil)
check("the best draft surfaces beside them",
      draft ~= nil and draft:find("stubborn", 1, true) ~= nil)

-- {{{ issue 704: the porch hears both spaces
local gbnf = dofile(DIR .. "/src/058-gbnf.lua")
local sayback = dofile(DIR .. "/src/059-say-back.lua")
local score = require("022-score")
local compile = require("024-compile")
local two_spaces = require("053-two-spaces")
local shape_words = dofile(DIR .. "/src/048-shape-words.lua")

-- the grammar is whole: every rule it names, it defines
local grammar = gbnf.read(g1)
check("the grammar defines every rule it names",
      #gbnf.undefined(grammar) == 0)
local every_kind = true
for kind in pairs(shape_words.MOTIONS) do
    if not g1:find('"\\"kind\\"" ws ":" ws "\\"' .. kind .. '\\""', 1, true) then
        every_kind = false
        print("  the grammar never says the motion kind " .. kind)
    end
end
check("the grammar says every kind of shape motion", every_kind)

-- {{{ local function both_spaces()
-- One reading that speaks both spaces, as a model would say it: a sky,
-- an eye, a ball curving round, a ring on a pane of glass, and a spark
-- following the ball. `cycles` is the word the first reply may misspell.
local function both_spaces(cycles)
    return '{"tool":"canvas","size":64,"fps":25,"length":1.0,"seed":5,'
        .. '"background":"sky"}\n'
        .. '{"tool":"camera","distance":7,"fov":44,"tilt":0.3}\n'
        .. '{"tool":"world","stars":{"count":20,"seed":3,"hues":["ice"]}}\n'
        .. '{"tool":"shape","tag":"ball","mesh":"icosahedron","hue":"violet",'
        .. '"scale":0.5,"style":"glow","motion":{"kind":"orbit","radius":2,"'
        .. cycles .. '":1},"prose":"curve the ball around the circle"}\n'
        .. '{"tool":"pane","name":"sign","at":[0,0,-0.6],"facing":[0,0,1],'
        .. '"size":[3,3],"pixels":48}\n'
        .. '{"tool":"pane","name":"far","place":"back"}\n'
        .. '{"tool":"stroke","pane":"sign","at":0.0,"lasts":1.0,"color":"gold",'
        .. '"fade":"in-out","shape":{"kind":"arc","center":[24,24],"radius":16,'
        .. '"from":12,"to":11,"turn":"clockwise"},'
        .. '"prose":"a gold ring on the glass"}\n'
        .. '{"tool":"stroke","at":0.0,"lasts":1.0,"color":"jade",'
        .. '"fade":"in-out","shape":{"kind":"point","at":{"tip":"ball"}}}'
end
-- }}}

-- what a model may say, and what it may not
check("a reading in both spaces is one the grammar allows",
      gbnf.matches(grammar, both_spaces("cycles")))
check("a misspelled 3D word is one the grammar refuses",
      not gbnf.matches(grammar, both_spaces("cycels")))
check("a misspelled shape hue is one the grammar refuses",
      not gbnf.matches(grammar, (both_spaces("cycles"):gsub('"violet"', '"violt"'))))
check("a choice of words belongs to its key",
      not gbnf.matches(grammar, (both_spaces("cycles"):gsub('"style":"glow"', '"glow"'))))

-- the prompt carries the world-space contract and a mixed score
check("the prompt carries the world-space words",
      prompt:find("Shape scene format", 1, true) ~= nil)
check("the prompt carries a score that speaks both spaces",
      prompt:find('tip("wanderer")', 1, true) ~= nil)

-- the whole porch, both spaces, against a fake model that misspells a
-- 3D word first: the 3D wall's teaching comes back, the second lands
local taught, tries = nil, 0
local both_text, both_compiled, heard = porch.translate(DIR, "curve the ball around the circle",
    function(request)
        tries = tries + 1
        taught = request.errors or taught
        return both_spaces(tries == 1 and "cycels" or "cycles")
    end)
check("the 3D misspelling is mended on the second reading",
      both_text ~= nil and tries == 2)
check("the 3D wall's words were quoted back",
      taught ~= nil and taught:find("shape #1 (ball).motion: no word 'cycels'", 1, true) ~= nil
      and taught:find("nearest legal: cycles", 1, true) ~= nil)
check("the score carries each call's sentence above it",
      both_text:find("-- curve the ball around the circle\nshape{", 1, true) ~= nil
      and both_text:find("-- a gold ring on the glass\nstroke{", 1, true) ~= nil)
check("what the porch heard is said back, plainly",
      heard ~= nil
      and heard[4] == "ball: a violet icosahedron, glowing, circles at radius 2, once a loop"
      and heard[#heard] == "0 to 1 s: a jade point following ball")
check("the same lines head the score",
      both_text:sub(1, #"-- what the porch heard:\n") == "-- what the porch heard:\n"
      and both_text:find("\n--   " .. heard[4] .. "\n", 1, true) ~= nil)

-- the written score reads back, passes the wall again, and films
local path = os.tmpname()
local f = assert(io.open(path, "w"))
f:write(both_text)
f:close()
local reread = compile.score(score.read(path))
os.remove(path)
local frames = two_spaces.render(reread)
check("the written score reads back and films a whole loop",
      #frames == 25 and #reread.studio.panes == 3)

-- a second camera is refused with a sentence, not dropped
local twice, twice_errors = porch.translate(DIR, "x", function()
    return both_spaces("cycles") .. '\n{"tool":"camera","distance":9}'
end)
check("a second camera call is refused, saying why",
      twice == nil and twice_errors:find("called the camera tool twice", 1, true) ~= nil)

-- the read-back of a known score is the expected lines
local mixed = sayback.lines(score.read(DIR .. "/tests/two-spaces/mixed.lua"))
local expected = {
    "the canvas: 256 pixels square, 4 s at 25 frames a second, under the stars",
    "the eye stands 7.5 back, tipped down 0.25, seeing 44 degrees",
    "the world: 60 stars in ice and violet",
    "wanderer: a violet icosahedron, glowing, circles at radius 2.4, once a loop, spinning twice a loop",
    "pane sign: glass 3 by 3 standing at (0, 0.2, -0.6), facing (0, 0, 1)",
    "pane backdrop: glass behind every shape",
    "circle, 0 to 4 s: a gold arc of radius 70 round (96, 96), clockwise from 12 o'clock to 11 o'clock, on pane sign",
    "spark, 0 to 4 s: a jade point following wanderer",
    "sweep, 0.5 to 3.5 s: an ice line from (20, 230) to (236, 200), on pane backdrop",
}
local same = #mixed == #expected
for i = 1, #expected do
    if mixed[i] ~= expected[i] then
        same = false
        print("  line " .. i .. ": " .. tostring(mixed[i]))
    end
end
check("the read-back of mixed.lua is the expected lines", same)
-- a word no saying knows is still named
local odd = sayback.lines{ shapes = { { tag = "x", hue = "gold", mesh = "cube",
    motion = { kind = "orbit", radius = 1, cycles = 1, bob = { amount = 0.2, cycles = 2 } },
    trail = { count = 3 } } } }
check("a word no saying knows is still named",
      odd[1]:find("(also: bob)", 1, true) ~= nil
      and odd[1]:find("(also: trail)", 1, true) ~= nil)
-- }}}

-- {{{ the live door (601's last mile): llama.cpp's /completion
local body = porch.llama_body({ prompt = "THE LANGUAGE", grammar = "root ::= x",
                                prose = "curve the ball", errors = "no word 'cycels'" }, 7)
check("the request body carries the prompt, the sentence and the wall's words",
      body.prompt:find("THE LANGUAGE", 1, true) == 1
      and body.prompt:find("THE PERSON SAYS:\n\ncurve the ball", 1, true) ~= nil
      and body.prompt:find("no word 'cycels'", 1, true) ~= nil
      and body.grammar == "root ::= x" and body.seed == 7)
local asked = {}
-- {{{ local function fake_curl()
-- Stands in for the shell: answers /completion as llama.cpp's server
-- does, the first time with a misspelled word, and /health with ok.
local function fake_curl(command)
    asked[#asked + 1] = command
    if command:find("/health", 1, true) then return '{"status":"ok"}', true end
    local file = command:match("@'([^']+)'")
    local f = io.open(file, "r")
    local sent = f:read("*a")
    f:close()
    asked.grammar = asked.grammar or sent:find('"grammar"', 1, true) ~= nil
    local reply = both_spaces(#asked == 1 and "cycels" or "cycles")
    local escaped = reply:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub("\n", "\\n")
    return '{"content":"' .. escaped .. '","stop":true}', true
end
-- }}}
local door = { name = "mind", host = "10.0.0.7", port = 8080 }
local live_text, _, live_heard = porch.translate(DIR, "curve the ball around the circle",
                                                 porch.door_transport(door, fake_curl))
check("a door's server is asked at /completion, grammar and all",
      asked[1]:find("http://10.0.0.7:8080/completion", 1, true) ~= nil and asked.grammar)
check("through a door, the misspelling is mended on the second asking",
      live_text ~= nil and #asked == 2 and live_heard[4]:find("^ball: a violet") ~= nil)
check("a door's health is asked at /health",
      porch.door_health(door, fake_curl) == true
      and asked[#asked]:find("/health", 1, true) ~= nil)
local silent = porch.door_transport(door, function() return "curl: (7) Failed to connect", false end)
local ok_silent, why_silent = pcall(silent, { prompt = "", grammar = "", prose = "x" })
check("a door that doesn't answer is a sentence naming it",
      not ok_silent and why_silent:find("door 'mind'", 1, true) ~= nil
      and why_silent:find("Failed to connect", 1, true) ~= nil)
local babble, babble_errors = porch.translate(DIR, "x", function() return "I think you want a ball" end)
check("a reply with no tool-calls fails the reading, not the porch",
      babble == nil and babble_errors:find("no tool-calls", 1, true) ~= nil)
check("a host that could break the command line is refused",
      not pcall(porch.door_transport, { name = "odd", host = "x';rm", port = 1 }))
-- }}}

-- the cluster roster: doors parse purely; comments and blanks pass
local doors = porch.cluster_doors(
    "# the little cluster\nalpha 10.0.0.1 8080\n\n"
    .. "beta 10.0.0.2 8080\nnonsense line without a port\n")
check("the roster parses its doors",
      #doors == 2 and doors[1].name == "alpha"
      and doors[2].host == "10.0.0.2" and doors[2].port == 8080)
-- a missing cluster file refuses politely, naming the example
local doors_ok, err = pcall(porch.cluster, DIR)
check("a missing cluster file refuses politely",
      not doors_ok and err:find("cluster.example", 1, true) ~= nil)

print(string.format("porch: %d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
