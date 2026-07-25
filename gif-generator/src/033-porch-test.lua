-- 033-porch-test.lua — proof for the listening porch's testable
-- whole: grammar, prompt, collector, retry loop, cluster reader.
--
-- What this is, generally: the porch runs against a scripted fake
-- orchestrator — no cluster required — that first answers with a
-- misspelled hue the grammar could never actually emit, to prove
-- the wall's teaching is quoted back and the second answer lands.
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
