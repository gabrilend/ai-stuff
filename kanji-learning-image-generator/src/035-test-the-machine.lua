-- 035-test-the-machine.lua
--
-- Everything phase three claims, checked.
--
-- For a general: phase three turns a scene into a file somebody else's program
-- can run, then does it for every character at once.
--
-- The far end is not on this machine. A workflow this project calls correct has
-- never been opened by the program it is for, so these tests can only catch
-- this project disagreeing with itself -- which they do thoroughly, because the
-- two file formats are two descriptions of one graph and comparing them is a
-- real check. They cannot catch this project disagreeing with ComfyUI.
--
--   luajit src/035-test-the-machine.lua [--dir ROOT]

local project = dofile((debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$")) ..
                       "/009-where-things-are.lua")

local M = {}

-- {{{ test_the_graph(t)
local function test_the_graph(t)
  local graph = project.load("028-the-shape-of-a-graph")
  local json = project.load("018-write-the-numbers")

  local g = graph.new()
  local model = g:add("CheckpointLoaderSimple", { ckpt_name = "a.safetensors" })
  local scene = g:add("CLIPTextEncode", { text = "a tree" }, "the scene")
  local blank = g:add("EmptyLatentImage", { width = 768, height = 768 })
  local sampler = g:add("KSampler", { seed = 41011, steps = 24, cfg = 6.5,
                                      sampler_name = "dpmpp_2m" })
  g:link(model, "CLIP", scene, "clip")
  g:link(model, "MODEL", sampler, "model")
  g:link(scene, "CONDITIONING", sampler, "positive")
  g:link(blank, "LATENT", sampler, "latent_image")

  local api = g:api()
  local ui = g:ui()

  -- The check that catches socket numbers drifting away from socket names. Both
  -- formats are read back out of what was written and their wires compared --
  -- not compared against the graph they came from, which would prove only that
  -- the graph exists.
  local from_api = graph.connections_from_api(api, g)
  local from_ui = graph.connections_from_ui(ui)
  t.same(table.concat(from_api, ", "), table.concat(from_ui, ", "),
         "the two formats describe the same wiring")
  t.same(#from_api, 4, "and all four wires are in both")

  -- THE TRAP. The editor's control array holds a selector immediately after the
  -- sampler's seed which the posted format has no field for. Leave it out and
  -- every value after the seed is off by one: the step count lands in the
  -- guidance scale, the file opens without complaint, and the pictures come out
  -- wrong in a way that looks like bad settings.
  local editor_values = nil
  for _, node in ipairs(ui.nodes) do
    if node.type == "KSampler" then editor_values = node.widgets_values end
  end
  t.same(editor_values[1], 41011, "the editor's first control is the seed")
  t.same(editor_values[2], "fixed", "the second is the selector the endpoint has no field for")
  t.same(editor_values[3], 24, "so the step count is third")
  t.same(editor_values[4], 6.5, "and the guidance scale is fourth")

  local posted = api[tostring(sampler.id)].inputs
  t.same(posted.steps, 24, "and the posted form has the step count by name")
  t.same(posted.cfg, 6.5, "and the guidance scale by name")
  t.same(posted.control_after_generate, nil,
         "and no trace of the selector, which means nothing to it")

  -- A workflow that arrives set to randomise stops being the picture that was
  -- tested the moment somebody presses the button.
  t.same(editor_values[2], "fixed", "the seed is set to hold, not to randomise")

  t.ok(not pcall(function() g:add("NoSuchNodeType", {}) end),
       "a node type the catalogue does not describe is refused by name")
  t.ok(not pcall(function() g:add("KSampler", { nonsense = 1 }) end),
       "and so is a control it does not have")
  t.ok(not pcall(function() g:link(model, "VAE", sampler, "model") end),
       "and wiring two sockets of different types together")

  -- Positions are computed, not authored, so a workflow opens as a left-to-right
  -- pipeline rather than a pile.
  local by_id = {}
  for _, node in ipairs(ui.nodes) do by_id[node.id] = node end
  t.ok(by_id[sampler.id].pos[1] > by_id[model.id].pos[1],
       "a node is laid out to the right of what it depends on")
end
-- }}}

-- {{{ test_the_workflow(t)
local function test_the_workflow(t)
  local workflow = project.load("029-the-workflow-for-one-kanji")
  local graph = project.load("028-the-shape-of-a-graph")
  local store = project.load("019-the-kanji-record").store()
  local settings = project.settings()

  local record = store.records["\228\188\145"]
  local g = workflow.build(record, {
    positive = "a scene", negative = "no text",
    field_name = "kanji/field.png", arrows_name = "kanji/arrows.png",
  }, settings)

  local kinds = {}
  for _, node in ipairs(g.nodes) do kinds[node.kind] = (kinds[node.kind] or 0) + 1 end
  for _, needed in ipairs({ "CheckpointLoaderSimple", "ControlNetLoader",
                            "ControlNetApplyAdvanced", "KSampler", "VAEDecode",
                            "SaveImage" }) do
    t.ok(kinds[needed] ~= nil, "the graph has a " .. needed)
  end
  t.same(kinds.CLIPTextEncode, 2, "and two sentences, one of them the refusals")
  t.same(kinds.LoadImage, 2, "and loads two pictures")

  -- The grey picture biases both sentences, which is what makes it a constraint
  -- on the whole drawing rather than a note attached to the prompt.
  local applied = nil
  for _, node in ipairs(g.nodes) do
    if node.kind == "ControlNetApplyAdvanced" then applied = node end
  end
  t.ok(applied.incoming.positive ~= nil, "the field is applied to what it should be")
  t.ok(applied.incoming.negative ~= nil, "and to what it should not be")

  -- The mask arrives inside out. Paste the arrows straight through and they go
  -- exactly where the arrows are not.
  local flip = nil
  for _, node in ipairs(g.nodes) do
    if node.kind == "InvertMask" then flip = node end
  end
  t.ok(flip ~= nil, "there is something turning the mask the right way round")
  t.same(flip.incoming.mask.from.kind, "LoadImage",
         "and it sits between the arrows and the compositor")
  local over = nil
  for _, node in ipairs(g.nodes) do
    if node.kind == "ImageCompositeMasked" then over = node end
  end
  t.same(over.incoming.mask.from.kind, "InvertMask",
         "so the compositor never sees the mask as it arrived")

  -- Asked for the plain illusion, the nodes are absent rather than present and
  -- switched off. A disabled node is a node somebody re-enables by accident.
  local plain = {}
  for key, value in pairs(settings.workflow) do plain[key] = value end
  plain.composite_arrows = false
  local bare = workflow.build(record, {
    positive = "a scene", negative = "no text", field_name = "f.png",
  }, { workflow = plain })
  local bare_kinds = {}
  for _, node in ipairs(bare.nodes) do bare_kinds[node.kind] = true end
  t.same(bare_kinds.ImageCompositeMasked, nil,
         "without the arrows, the compositing nodes are not in the graph at all")
  t.same(bare_kinds.InvertMask, nil, "nor the thing that feeds it")

  -- Same character, same picture. Without it, comparing six thousand images
  -- against six thousand images is impossible and every change looks total.
  local once = workflow.seed_for(record)
  t.same(workflow.seed_for(record), once, "a character's noise comes from itself")
  local neighbour = store.records["\228\188\154"]
  if neighbour then
    t.ok(workflow.seed_for(neighbour) ~= once,
         "and neighbouring characters do not get neighbouring noise")
  end

  local from_api = graph.connections_from_api(g:api(), g)
  local from_ui = graph.connections_from_ui(g:ui())
  t.same(table.concat(from_api, ", "), table.concat(from_ui, ", "),
         "the real workflow describes the same wiring in both formats")
  t.note(#g.nodes .. " nodes, " .. #g.links .. " wires")
end
-- }}}

-- {{{ test_making_one(t)
local function test_making_one(t)
  local one = project.load("030-make-one-kanji")
  local store = project.load("019-the-kanji-record").store()
  local settings = project.settings()
  local out = project.scratch("test-set")
  os.execute('rm -rf "' .. out .. '"')

  local record = store.records["\228\188\145"]
  local done, why = one.make(record, store, settings, { out = out })
  t.ok(done ~= nil, "a character can be made", why)

  for _, name in ipairs({ "field.png", "field-thumb.png", "arrows.png",
                          "workflow.api.json", "workflow.ui.json", "card.json" }) do
    t.ok(project.exists(done.folder .. "/" .. name), "it leaves behind " .. name)
  end

  local card = project.read_file(done.folder .. "/card.json")
  t.ok(card:find('"character"', 1, true) ~= nil, "the card names its character")
  t.ok(card:find('"strokes_and_what_they_carry"', 1, true) ~= nil,
       "and says what every stroke is carrying")
  t.ok(card:find('"sound_half"', 1, true) ~= nil,
       "and which pieces were demoted for being there only for their sound")
  t.ok(card:find('"positive"', 1, true) ~= nil, "and holds the sentence")

  -- A killed run must not leave a half-written picture with a whole picture's
  -- name on it. The gallery would render it as broken and somebody would spend
  -- an hour on the generator.
  local leftovers = io.popen('ls "' .. done.folder .. '" | grep partial | wc -l')
  local count = tonumber(leftovers:read("*l"))
  leftovers:close()
  t.same(count, 0, "and nothing half-written is left lying about")

  os.execute('rm -rf "' .. out .. '"')
end
-- }}}

-- {{{ test_the_heat_governor(t)
local function test_the_heat_governor(t)
  local heat = project.load("031a-when-the-machine-runs-hot")
  local settings = project.settings()

  -- Fewer workers than cores, and by a proportion rather than a subtraction.
  -- Leaving two cores free is a large concession on a four-core machine and
  -- almost none on a thirty-two core one, and it is the *share* of the machine
  -- held at full load that decides how hot it gets.
  local function workers_for(processors, share, reserve, ceiling)
    local want = math.floor(processors * share)
    local spare = processors - reserve
    if want > spare then want = spare end
    if ceiling and want > ceiling then want = ceiling end
    if want < 1 then want = 1 end
    return want
  end

  local howmany, processors = heat.workers(settings)
  t.ok(processors >= 1, "the machine says how many processors it has", processors)
  t.ok(howmany >= 1, "and at least one worker is run")
  t.ok(howmany <= processors, "never more workers than processors")
  t.ok(howmany <= settings.batch.max_workers,
       "and never past the outright ceiling")
  if processors > 2 then
    t.ok(howmany < processors,
         "a run does not take the whole machine",
         howmany .. " of " .. processors)
  end
  t.same(howmany, workers_for(processors, settings.batch.share,
                              settings.batch.reserve, settings.batch.max_workers),
         "the count follows the share, the reserve and the ceiling")

  -- A single-core machine still gets a worker rather than none.
  t.same(workers_for(1, 0.45, 1, 6), 1, "a one-core machine still runs one worker")
  t.same(workers_for(2, 0.45, 1, 6), 1, "and so does a two-core one")

  -- Resting has to actually stop the process. A pause implemented by looping
  -- until the clock moves would be a way of avoiding heat by making it.
  local before = os.time()
  local spun = 0
  local started = os.clock()
  heat.rest(0.30)
  local cpu_spent = os.clock() - started
  t.ok(cpu_spent < 0.10,
       "resting gives the processor up rather than spinning on it",
       string.format("%.3f seconds of processor time for a 0.30 second rest",
                     cpu_spent))

  local where = heat.source()
  if where then
    local degrees = heat.temperature()
    t.ok(degrees ~= nil, "this machine reports its temperature")
    t.ok(degrees > 5 and degrees < 130,
         "and the reading is a plausible temperature",
         string.format("%.1f degrees from %s", degrees, where))

    local governor = heat.governor(settings)
    t.ok(governor ~= nil, "so a governor is made")
    for _ = 1, 3 do governor.consider() end
    local watched = governor.report()
    t.ok(watched.readings > 0, "which takes readings as work goes by")
    t.note(string.format("%.0f degrees now, resting above %d, %d of %d cores",
           degrees, settings.heat.warm, howmany, processors))
  else
    -- The failure worth preventing is a run that rests constantly because it is
    -- reading nothing and treating that as hot.
    t.same(heat.governor(settings), nil,
           "a machine that will not say how hot it is gets no governor at all")
    t.note("this machine does not report its temperature; runs will not pause")
  end
end
-- }}}

-- {{{ M.run(options)
function M.run(options)
  local ink = project.load("020-test-the-ink")
  local groups = {
    { "the graph", test_the_graph },
    { "the workflow", test_the_workflow },
    { "making one", test_making_one },
    { "the heat governor", test_the_heat_governor },
  }
  local all_passed = true
  for _, group in ipairs(groups) do
    local t = ink.harness()
    group[2](t)
    if not t.finish(group[1]) then all_passed = false end
  end
  return all_passed
end
-- }}}

-- {{{ main(argv)
local function main(argv)
  project.arguments(argv)
  project.hello("035-test-the-machine")
  io.write("phase three -- the machine\n")
  local passed = M.run({})
  project.goodbye("035-test-the-machine",
                  { passed and "all passed" or "SOMETHING FAILED" })
  os.exit(passed and 0 or 1)
end
-- }}}

if arg and arg[0] and arg[0]:find("035%-test%-the%-machine") then
  main(arg)
end

return M
