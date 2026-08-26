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

  -- Asked for by name. Burning the arrows into the saved picture is no longer
  -- the default -- the pool holds what the model drew, unmodified -- but the
  -- graph still has to be able to do it, and a test that relied on the default
  -- would be testing whichever way the settings file happened to be set.
  local compositing = { workflow = {} }
  for key, value in pairs(settings.workflow) do compositing.workflow[key] = value end
  compositing.workflow.composite_arrows = true

  local g = workflow.build(record, {
    positive = "a scene", negative = "no text",
    field_name = "kanji/field.png", arrows_name = "kanji/arrows.png",
  }, compositing)

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

  -- Asked for the plain illusion -- which is now the ordinary case -- the nodes
  -- are absent rather than present and switched off. A disabled node is a node
  -- somebody re-enables by accident.
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

-- {{{ test_the_two_sites(t)
local function test_the_two_sites(t)
  local gallery = project.load("032-a-gallery-you-can-page")
  local site = project.load("033-the-documentation-site")
  local one = project.load("030-make-one-kanji")
  local store = project.load("019-the-kanji-record").store()
  local settings = project.settings()

  -- A small real set rather than a fixture, because the gallery reads what a
  -- run wrote and a fixture would be a second opinion about that format.
  local out = project.scratch("test-gallery")
  os.execute('rm -rf "' .. out .. '"')
  for _, character in ipairs({ "\230\156\168", "\229\183\157", "\228\188\145" }) do
    one.make(store.records[character], store, settings, { out = out })
  end

  local made = gallery.build(out, { per_page = 2 })
  t.same(made.characters, 3, "the gallery finds every character in the set")
  t.same(made.pages, 2, "and pages them as asked")
  t.same(#made.broken, 0, "with no folder missing its card")
  t.ok(project.exists(out .. "/index.html"), "there is an index")
  t.ok(project.exists(out .. "/page-001.html"), "and a page")

  local index = project.read_file(out .. "/index.html")
  t.ok(index:find("field%-thumb%.png") ~= nil,
       "the index shows the thumbnail, which is the size the illusion works at")
  t.ok(index:find("<style>", 1, true) ~= nil,
       "and carries its own style, so it works from a filesystem with no server")
  t.ok(index:find("http://") == nil and index:find("https://") == nil,
       "and fetches nothing from anywhere")

  local page = project.read_file(out .. "/page-001.html")
  t.ok(page:find("workflow%.ui%.json") ~= nil, "a page links to its workflows")
  t.ok(page:find("refused", 1, true) ~= nil, "and shows what every prompt refuses")

  -- A folder with no card must show as a visible gap, not vanish. A gallery
  -- quietly short of the set it claims to show is worse than one with a hole in
  -- it, because the hole is at least visible.
  os.execute('mkdir -p "' .. out .. '/0FFFF-x"')
  local gapped = gallery.build(out, { per_page = 10 })
  t.same(#gapped.broken, 1, "a folder with no card is counted")
  local said = project.read_file(out .. "/index.html")
  t.ok(said:find("have no card", 1, true) ~= nil, "and named on the page")
  os.execute('rm -rf "' .. out .. '"')

  -- The documentation site. Its own check is that every link it emits resolves;
  -- a site full of dead links is worse than the markdown it came from, because
  -- markdown never promised the link worked.
  local built = site.build({ no_figures = true })
  t.ok(built.pages > 20, "the site covers the documents, tickets and source pages",
       built.pages .. " pages")
  t.ok(built.links > 50, "with a good many cross-references", built.links)
  t.same(#built.broken, 0, "and every one of them resolves",
         built.broken[1])
  t.note(built.pages .. " pages, " .. built.links .. " links, none broken")
end
-- }}}

-- {{{ test_the_paintbrush(t)
-- The mechanism for arguing with a picture that came out wrong. Its whole value
-- is in what it refuses, so most of this walks into the wall on purpose.
local function test_the_paintbrush(t)
  local paintbrush = project.load("024a-the-paintbrush")
  local store = project.load("019-the-kanji-record").store()
  local settings = project.settings()
  local record = store.records["\230\153\130"]

  -- Every complaint at once. Stopping at the first turns fixing an argument
  -- into one guess per run.
  local complaints = paintbrush.check({
    wold = "sky",
    world = "skies",
    reading = "mnemonik",
    subjects = { { "\229\177\177", "a mountain" } },
    strokes = { [99] = "nowhere" },
    palette = 12,
  }, record, store)
  t.ok(#complaints >= 6, "the wall reports every problem in one pass",
       #complaints .. " of them")

  local all = table.concat(complaints, "\n")

  -- Each refusal names its field and, where a suggestion means anything, makes
  -- one. The vocabulary is small and closed, so the nearest legal word is
  -- computable and is almost certainly what was meant.
  t.ok(all:find("no word 'wold'", 1, true) ~= nil, "an unknown word is named")
  t.ok(all:find("Did you mean 'world'", 1, true) ~= nil, "with the word meant")
  t.ok(all:find("Did you mean 'sky'", 1, true) ~= nil,
       "a misspelt world is corrected")
  t.ok(all:find("Did you mean 'mnemonic'", 1, true) ~= nil,
       "and so is a misspelt reading")

  -- A piece the character does not have is the mistake somebody will actually
  -- make, so the wall names what it *is* made of. It offers no guess: every
  -- distinct single character is exactly one edit from every other, so the
  -- "nearest" one is whichever came first in the list -- which once produced
  -- "did you mean 時?" about the character being argued.
  t.ok(all:find("has no piece", 1, true) ~= nil, "a piece it does not have is refused")
  t.ok(all:find("it is made of", 1, true) ~= nil, "and the real pieces are listed")
  t.ok(all:find("Did you mean '\230\153\130'", 1, true) == nil,
       "without guessing between single characters, which carries no information")

  t.ok(all:find("strokes 1 to 10", 1, true) ~= nil,
       "a stroke number it does not have is refused, with the range")
  t.ok(all:find("palette", 1, true) ~= nil, "and a field of the wrong type")

  -- An argument may say as little as it likes. Overriding the world and nothing
  -- else is the commonest case.
  t.same(#paintbrush.check({ world = "shrine" }, record, store), 0,
         "an argument that says one thing is legal")
  t.same(#paintbrush.check({}, record, store), 0,
         "and so is one that says nothing at all")
  t.same(#paintbrush.check({ note = "just a note" }, record, store), 0,
         "a note is legal and does nothing")

  -- What an argument actually does. Only what it says changes.
  local grammar = project.load("024-the-scene-grammar")
  local before = grammar.scene(record, store, settings)
  local after = paintbrush.apply(
    grammar.scene(record, store, settings),
    { world = "shrine", subjects = { { "\230\151\165", "a huge white sun" } } })
  t.same(after.biome.name, "shrine", "an argued world wins")
  t.same(after.subjects[1].depicts, "a huge white sun", "and an argued subject")
  t.same(after.reading, before.reading,
         "while everything unsaid stays as the grammar worked it out")
  t.ok(after.argued, "and the scene records that it was argued with")

  -- A person says what a piece looks like, not where it is. Where it is comes
  -- from the strokes and nobody should have to restate it.
  t.ok(after.subjects[1].where ~= "somewhere",
       "an argued subject keeps the place its strokes give it",
       after.subjects[1].where)

  -- The contract is generated from the vocabulary, not written beside it. Two
  -- homes for one contract is a contract that disagrees with itself silently:
  -- the document says one thing, the wall enforces another, and whoever is
  -- writing an argument believes the document.
  local contract = paintbrush.contract()
  for _, word in ipairs({ "world", "reading", "polarity", "subjects",
                          "strokes", "register", "light", "palette", "note" }) do
    t.ok(contract:find("`" .. word .. "`", 1, true) ~= nil,
         "the contract publishes " .. word)
  end
  for _, biome in ipairs(grammar.biomes()) do
    if not contract:find(biome.name, 1, true) then
      t.ok(false, "the contract lists every world", biome.name .. " is missing")
      break
    end
  end
  t.ok(true, "and every world it will accept")

  -- An argument that exists and is wrong must stop the run. Written and then
  -- silently ignored would be worse than never written: the picture does not
  -- change and nothing says why.
  local wrong = paintbrush.path_for("\239\189\158test")
  project.write_file(wrong, "return { world = 'nowhere' }")
  local pretend = { character = "\239\189\158test", components = {},
                    strokes = { { d = "M0,0c1,1,2,2,3,3" } } }
  local ok, complaint = pcall(paintbrush.load_for, pretend, store)
  os.remove(wrong)
  t.ok(not ok, "an argument that is there and is wrong stops the run")
  t.ok(tostring(complaint):find("is not a world", 1, true) ~= nil,
       "saying what was wrong with it")
  t.ok(tostring(complaint):find("--contract", 1, true) ~= nil,
       "and where the list of legal words is")
end
-- }}}

-- {{{ test_the_pool_and_the_graders(t)
local function test_the_pool_and_the_graders(t)
  local pool = project.load("045-the-pool-that-remembers")
  local grader = project.load("046-two-ways-of-saying-it-is-good")
  local reader = project.load("017a-read-a-picture")
  local canvas = project.load("016-the-grey-canvas")
  local png = project.load("017-write-a-picture")
  local field_of = project.load("022-the-structure-field")
  local paintbrush = project.load("024a-the-paintbrush")
  local store = project.load("019-the-kanji-record").store()

  -- Its own pool, so this never touches a real one. Nothing is ever deleted
  -- from a pool, and a test that wrote into the working one would be a test
  -- that permanently added nine renderings to it every time it ran.
  local settings = {}
  for key, value in pairs(project.settings()) do settings[key] = value end
  settings.pool = { dir = project.scratch("test-pool"), cuts = { 0.86, 0.72, 0.55, 0.34 },
                    human_floor = 0.05 }
  os.execute('rm -rf "' .. settings.pool.dir .. '"')

  local TREE, RIVER = "\230\156\168", "\229\183\157"
  local made = {}
  for _, character in ipairs({ TREE, RIVER }) do
    local record = store.records[character]
    local scene = paintbrush.scene(record, store, settings)
    local surface = field_of.build(record, settings, { polarity = scene.polarity })
    local scratch = project.scratch("test-standin-" .. record.codepoint .. ".png")
    png.write_grey(scratch, surface, canvas)
    local picture, companion = pool.add(settings, {
      record = record, scene = scene, seed = 1234,
      character = character, means = table.concat(record.meanings, ", "),
      kind = "character", category = scene.biome.name,
      codepoint = record.codepoint, canvas = "a made-up brief",
      ratings = {},
    }, project.read_file(scratch))
    made[character] = { picture = picture, companion = companion, field = scratch }
  end

  -- Two files with the same stem in the same folder. That is the whole store.
  t.ok(project.exists(made[TREE].picture), "a rendering lands in the pool")
  t.ok(project.exists(made[TREE].companion), "with its companion beside it")

  local entry = pool.read_companion(made[TREE].companion)
  t.same(entry.character, TREE, "the companion names its character")
  t.same(entry.seed, 1234, "and its seed, so it can be made again")
  t.same(entry.canvas, "a made-up brief",
         "and the brief it answered, so a bad score can be told from a bad ask")

  -- THE MACHINE GRADER. A field against itself is perfect agreement; against a
  -- different character's, far less. Neither needs a generated picture, and
  -- they check the arithmetic -- which is the half that can be wrong quietly.
  local tree_field = reader.read(made[TREE].field)
  local river_field = reader.read(made[RIVER].field)
  local itself = grader.squint(tree_field, tree_field, settings)
  local other = grader.squint(tree_field, river_field, settings)
  t.near(itself, 1, 0.001, "a field agrees perfectly with itself")
  t.ok(other < itself - 0.2, "and much less with a different character's",
       string.format("%.2f against %.2f", other, itself))
  t.same(grader.tier_for(itself, settings), 5, "so it scores at the top")

  -- A picture that is uniformly brighter has not failed at anything: what
  -- matters is whether light and dark move together, not whether they match.
  local brighter = canvas.clone(tree_field)
  for index = 1, brighter.width * brighter.height do
    brighter.pixels[index] = brighter.pixels[index] * 0.5 + 0.4
  end
  t.near(grader.squint(brighter, tree_field, settings), 1, 0.02,
         "a picture that is merely paler still agrees")

  -- An inverted picture is a failure and not a near miss.
  local inverted = canvas.clone(tree_field)
  canvas.invert(inverted)
  t.same(grader.squint(inverted, tree_field, settings), 0,
         "and one that is inside out agrees not at all")

  -- Ratings are appended, never overwritten. A machine's guess has to stay
  -- visible under a person's correction, or the agreement between them cannot
  -- be measured -- and that measurement is the only check there is on whether
  -- the machine's taste is anything like a person's.
  pool.rate(made[TREE].companion, 5, "machine:squint 1.000")
  pool.rate(made[TREE].companion, 2, "person")
  local rated = pool.read_companion(made[TREE].companion)
  t.same(#rated.ratings, 2, "both ratings are kept")

  -- This is the bug that made every correction invisible: a pattern anchored on
  -- the newline before each entry eats it, so the second entry never matches --
  -- and the rating that counts is the last one.
  t.same(rated.ratings[1].tier, 5, "the machine's guess is still there")
  t.same(rated.ratings[2].tier, 2, "and so is the correction after it")
  t.same(pool.tier_of(rated), 2, "the last one wins")
  t.same(pool.tier_by_a_person(rated), 2, "and it is known to be a person's")

  pool.rate(made[RIVER].companion, 4, "machine:squint 0.800")
  local unjudged = pool.read_companion(made[RIVER].companion)
  t.same(pool.tier_by_a_person(unjudged), nil,
         "while one only a machine rated has no person's tier")

  -- "tier 4 or better" and "tier 4 or better as judged by a person" are
  -- different requests, and the second is smaller and more trustworthy.
  t.same(#pool.walk(settings, { floor = 4 }), 1, "a floor filters")
  t.same(#pool.walk(settings, { floor = 4, by_a_person = true }), 0,
         "and asking for a person's judgement filters harder")
  t.same(#pool.walk(settings, { floor = 1 }), 2, "a low floor keeps everything")
  t.same(#pool.walk(settings, { category = "forest" }), 1, "so does a category")

  local counts = pool.counts(settings)
  t.same(counts.total, 2, "the counting utility sees everything")
  t.same(counts.compared, 1, "and finds where both have rated the same one")
  t.same(counts.agreed, 0, "and whether they agreed")

  -- Copy the pair anywhere and nothing is lost. A record in a central store
  -- drifts from what it describes the first time somebody archives one without
  -- the other.
  local elsewhere = project.scratch("moved")
  project.ensure_directory(elsewhere)
  os.execute('cp "' .. made[TREE].companion .. '" "' .. elsewhere .. '/"')
  local moved = pool.read_companion(elsewhere ..
    "/" .. made[TREE].companion:gsub(".*/", ""))
  t.same(pool.tier_of(moved), 2, "a companion carried elsewhere keeps its tier")
  t.same(moved.seed, 1234, "and its seed")

  -- A pool that has lost its pictures but kept its judgements is the ordinary
  -- state of a fresh clone, and it must be a supported state rather than a
  -- broken one -- the opinions are in the record and the pictures are not,
  -- because a picture can be made again from its seed and an opinion cannot
  -- be made again from anything.
  t.ok(pool.read_companion(made[TREE].companion).picture_is_here,
       "a companion knows its picture is beside it")
  os.remove(made[TREE].picture)
  local orphaned = pool.read_companion(made[TREE].companion)
  t.ok(not orphaned.picture_is_here, "and knows when it is not")
  t.same(pool.tier_of(orphaned), 2, "while still carrying every rating")
  t.same(orphaned.seed, 1234, "and the seed that makes the picture again")
  local after = pool.counts(settings)
  t.same(#after.awaiting_their_picture, 1,
         "and the count says how many are waiting for their picture")

  t.ok(not pcall(pool.rate, made[TREE].companion, 7, "person"),
       "a tier outside one to five is refused, with the scale")
  t.ok(not pcall(pool.rate, made[TREE].companion, 2.5, "person"),
       "and so is one between two steps")

  os.execute('rm -rf "' .. settings.pool.dir .. '" "' .. elsewhere .. '"')
end
-- }}}

-- {{{ test_reading_a_picture(t)
-- The decoder, which is what makes grading possible at all -- everything else
-- here writes pictures from numbers it already had.
local function test_reading_a_picture(t)
  local reader = project.load("017a-read-a-picture")
  local canvas = project.load("016-the-grey-canvas")
  local png = project.load("017-write-a-picture")

  local surface = canvas.new(64, 48, 0)
  for y = 0, 47 do
    for x = 0, 63 do
      surface.pixels[y * 64 + x + 1] = ((x * 3 + y * 5) % 71) / 71
    end
  end
  local path = project.scratch("read-back.png")
  png.write_grey(path, surface, canvas)

  local back, why = reader.read(path)
  t.ok(back ~= nil, "a picture this project wrote can be read again", why)
  t.same(back.width, 64, "at the width it was written")
  t.same(back.height, 48, "and the height")
  local worst = 0
  for index = 1, 64 * 48 do
    local gap = math.abs(back.pixels[index] - surface.pixels[index])
    if gap > worst then worst = gap end
  end
  t.ok(worst < 1 / 255 + 1e-6,
       "and every value comes back within one step of eight bits",
       string.format("worst was %.5f", worst))
  os.remove(path)

  -- The point of this file is reading somebody *else's* picture, which uses a
  -- code table built for its own contents rather than the standard one `017`
  -- always emits. An outside tool is used to make one, and where the machine
  -- has none the test says the check was skipped rather than counting a missing
  -- check as a pass.
  local foreign = project.scratch("foreign.png")
  local made = os.execute('magick -size 40x30 gradient:navy-orange -depth 8 ' ..
                          'PNG24:"' .. foreign .. '" 2>/dev/null')
  if (made == true or made == 0) and project.exists(foreign) then
    local outside = reader.read(foreign)
    t.ok(outside ~= nil, "a picture written by another program reads")
    t.same(outside.width, 40, "at the size that program made it")

    -- And its brightness agrees with what that program says it is. Two
    -- independent readers is proof; one is an opinion.
    local total = 0
    for index = 1, outside.width * outside.height do
      total = total + outside.pixels[index]
    end
    local ours = total / (outside.width * outside.height)
    local probe = io.popen('magick "' .. foreign ..
                           '" -colorspace gray -format "%[fx:mean]" info: 2>/dev/null')
    local theirs = tonumber(probe and probe:read("*l") or "")
    if probe then probe:close() end
    if theirs then
      t.near(ours, theirs, 0.01,
             "and its brightness agrees with what that program says")
      t.note(string.format("this reader %.5f, the outside one %.5f", ours, theirs))
    else
      t.note("the outside tool would not report a brightness; not compared")
    end
    os.remove(foreign)
  else
    t.note("no outside image tool on this machine, so only the round trip ran")
  end
end
-- }}}

-- {{{ ungif(text)
-- Enough of a reader to check the writer, written from the format description.
--
-- It lives here rather than in `048` because nothing in this project reads an
-- animation -- and because a round trip through code written from the same
-- misunderstanding proves nothing. This decodes the way an outside program
-- would: find the frames, undo the compression, hand back the pixels.
local function ungif(text)
  if text:sub(1, 6) ~= "GIF89a" then return nil, "does not begin like a GIF" end
  local width = text:byte(7) + text:byte(8) * 256
  local height = text:byte(9) + text:byte(10) * 256
  local flags = text:byte(11)
  local at = 14
  local table_size = 2 ^ ((flags % 8) + 1)
  local palette = text:sub(at, at + table_size * 3 - 1)
  at = at + table_size * 3

  local frames = {}
  while at <= #text do
    local marker = text:byte(at)
    if marker == 0x3B then break end

    if marker == 0x21 then
      -- an extension: a label, then sub-blocks
      at = at + 2
      while text:byte(at) and text:byte(at) ~= 0 do
        at = at + text:byte(at) + 1
      end
      at = at + 1

    elseif marker == 0x2C then
      -- The frame header is ten bytes: the marker, where the frame sits, how
      -- big it is, and one byte of flags -- so the flags are the tenth byte and
      -- not the eleventh, and reading the eleventh gets the code size instead.
      local local_flags = text:byte(at + 9)
      at = at + 10
      if local_flags and local_flags >= 128 then
        at = at + 2 ^ ((local_flags % 8) + 1) * 3
      end
      local minimum = text:byte(at)
      at = at + 1

      local packed = {}
      while text:byte(at) and text:byte(at) ~= 0 do
        local length = text:byte(at)
        packed[#packed + 1] = text:sub(at + 1, at + length)
        at = at + length + 1
      end
      at = at + 1
      local data = table.concat(packed)

      -- the decompression, which is the whole point of this reader
      local CLEAR, STOP = 2 ^ minimum, 2 ^ minimum + 1
      local held, bits, position = 0, 0, 1
      local function take(this_wide)
        while bits < this_wide do
          held = held + (data:byte(position) or 0) * (2 ^ bits)
          position = position + 1
          bits = bits + 8
        end
        local value = held % (2 ^ this_wide)
        held = math.floor(held / (2 ^ this_wide))
        bits = bits - this_wide
        return value
      end

      local dictionary, next_code, code_width, previous
      local function reset()
        dictionary = {}
        for index = 0, CLEAR - 1 do dictionary[index] = string.char(index) end
        next_code = STOP + 1
        code_width = minimum + 1
        previous = nil
      end
      reset()

      local pixels = {}
      while true do
        local code = take(code_width)
        if code == CLEAR then
          reset()
        elseif code == STOP then
          break
        else
          local run = dictionary[code]
          if not run then
            if not previous then
              return nil, "a frame begins with a code that is not in the table"
            end
            run = previous .. previous:sub(1, 1)
          end
          pixels[#pixels + 1] = run
          if previous and next_code < 4096 then
            dictionary[next_code] = previous .. run:sub(1, 1)
            next_code = next_code + 1
            if next_code >= 2 ^ code_width and code_width < 12 then
              code_width = code_width + 1
            end
          end
          previous = run
        end
      end
      frames[#frames + 1] = table.concat(pixels)

    else
      return nil, "an unexpected byte where a block should start"
    end
  end
  return { width = width, height = height, palette = palette, frames = frames }
end
-- }}}

-- {{{ test_the_animation(t)
local function test_the_animation(t)
  local animation = project.load("048-what-a-higher-tier-buys")
  local canvas = project.load("016-the-grey-canvas")
  local settings = project.settings()

  -- A small picture with structure in it, so the compressor has both repeats
  -- and things it has never seen. A flat one would compress to almost nothing
  -- and would exercise none of the dictionary building.
  local width, height = 48, 32
  local frames = {}
  for step = 1, 3 do
    local indices = {}
    for y = 0, height - 1 do
      for x = 0, width - 1 do
        indices[y * width + x + 1] = (x * step + y * 7) % 176
      end
    end
    frames[#frames + 1] = indices
  end

  local bytes = animation.encode(frames, width, height,
                                 animation.palette(settings), 45)
  t.same(bytes:sub(1, 6), "GIF89a", "the file starts the way one does")
  t.same(bytes:sub(-1), "\59", "and ends the way one does")

  -- THE ASSERTION THE WHOLE FILE EXISTS FOR. A compressor that grows its code
  -- width one entry late writes a file that decodes correctly for a while and
  -- then falls apart -- which looks like a corrupt download rather than a bug,
  -- and only a decoder finds it.
  local back, why = ungif(bytes)
  t.ok(back ~= nil, "what was written can be read again", why)
  t.same(back.width, width, "at the width it was written")
  t.same(back.height, height, "and the height")
  t.same(#back.frames, #frames, "with every frame present")

  local wrong = 0
  for number, frame in ipairs(back.frames) do
    if #frame ~= width * height then
      wrong = wrong + 1
    else
      for position = 1, width * height do
        if frame:byte(position) ~= frames[number][position] then
          wrong = wrong + 1
          break
        end
      end
    end
  end
  t.same(wrong, 0, "and every pixel of every frame is the one that went in")

  t.ok(#bytes < width * height * #frames,
       "and it is smaller than the pixels were",
       string.format("%d bytes for %d pixels", #bytes, width * height * #frames))

  -- An outside opinion, where the machine has one. Two independent readers is
  -- proof; one is an opinion.
  local scratch = project.scratch("test-animation.gif")
  project.write_file(scratch, bytes)
  local probe = io.popen('identify "' .. scratch .. '" 2>/dev/null | wc -l')
  local counted = tonumber(probe and probe:read("*l") or "")
  if probe then probe:close() end
  if counted and counted > 0 then
    t.same(counted, #frames, "an outside decoder finds the same number of frames")
    t.note("an outside decoder read it and agreed about the frames")
  else
    t.note("no outside decoder on this machine; only the round trip ran")
  end
  os.remove(scratch)

  -- The palette is built to be exactly what these frames are made of, so no
  -- pixel needs a nearest-colour search and none is placed with any error.
  t.same(#animation.palette(settings), 256 * 3, "the palette is a full one")
  t.same(animation.index_of(0, 0, 0, 0, false), 0, "black is the first entry")
  t.same(animation.index_of(1, 1, 1, 0, false), 215, "and white is the last colour")
  t.ok(animation.index_of(0.5, 0.5, 0.5, 1, false) >= 216,
       "while anything with an arrow over it is past the colours")
  -- The cube is arithmetic rather than a search, so a pure colour lands where
  -- multiplying out says it should and not merely somewhere near.
  t.same(animation.index_of(1, 0, 0, 0, false), 5 * 36, "pure red is where it should be")
  t.same(animation.index_of(0, 1, 0, 0, false), 5 * 6, "and pure green")
  t.same(animation.index_of(0, 0, 1, 0, false), 5, "and pure blue")
end
-- }}}

-- {{{ test_the_dial(t)
local function test_the_dial(t)
  local dial = project.load("047-the-quality-dial")
  local pool = project.load("045-the-pool-that-remembers")

  local settings = {}
  for key, value in pairs(project.settings()) do settings[key] = value end
  settings.pool = { dir = project.scratch("dial-pool"),
                    cuts = { 0.86, 0.72, 0.55, 0.34 }, human_floor = 0.05 }
  os.execute('rm -rf "' .. settings.pool.dir .. '"')
  project.ensure_directory(settings.pool.dir .. "/forest")

  -- A pool made by hand, so the arithmetic is checkable against numbers chosen
  -- rather than numbers that happened.
  local tiers = { 5, 5, 4, 4, 4, 3, 3, 2, 1, 1 }
  for index, tier in ipairs(tiers) do
    local stem = string.format("%s/forest/%08d-x-%06d", settings.pool.dir,
                               index, index)
    project.write_file(stem .. ".png", "not really a picture")
    project.write_file(stem .. ".info.md", pool.render_companion({
      character = "x", means = "a test", kind = "character",
      category = "forest", codepoint = index, seed = index,
      canvas = "a brief", ratings = {
        { tier = tier, who = index <= 3 and "person" or "machine:squint 0.5",
          when = "2026-01-01 00:00:00" },
      },
    }))
  end

  local report = dial.consider(settings, "forest")
  t.same(report.total, 10, "the dial sees the whole category")
  t.same(report.ladder[1], 10, "everything is tier 1 or better")
  t.same(report.ladder[3], 7, "seven are tier 3 or better")
  t.same(report.ladder[4], 5, "five are tier 4 or better")
  t.same(report.ladder[5], 2, "and two are at the top")

  -- The variety cost, said before it is paid. A filter that quietly returns
  -- five things where there were seven is the failure this file exists to
  -- prevent, so the telling is what gets tested rather than the filtering.
  local said = table.concat(dial.describe(report, 3, 4), "\n")
  t.ok(said:find("leaves 5 to draw from instead of 7", 1, true) ~= nil,
       "raising a floor says what it costs, in both numbers", said:sub(1, 200))
  t.ok(said:find("Declining costs nothing", 1, true) ~= nil,
       "and the offer to rate more says that saying no is free")

  -- Provenance is a second dial and a stricter one.
  local strict = dial.consider(settings, "forest", true)
  t.same(strict.ladder[4], 3,
         "asking only for what a person rated gives a smaller set")
  t.ok(strict.ladder[4] < report.ladder[4],
       "which is the whole point of asking")

  local kept, again = dial.choose(settings, { category = "forest", floor = 4 })
  t.same(#kept, 5, "and what survives is what was promised")
  t.ok(again ~= nil, "with the report handed back alongside it, always")

  os.execute('rm -rf "' .. settings.pool.dir .. '"')
end
-- }}}

-- {{{ test_the_card_is_also_the_screen(t)
-- `307` asked whether the processor was getting hot and answered it properly.
-- Nobody asked the same question about the graphics card, on the grounds that
-- generating is the card's work and so the processor's governor did not apply
-- -- which is true, and answers the wrong question. On a machine with one card,
-- that card is drawing somebody's desktop.
local function test_the_card_is_also_the_screen(t)
  local runner = project.load("044-run-the-pictures")
  local settings = project.settings()

  -- A card with a desktop on it is never at zero before anything of ours has
  -- run. That is the tell.
  t.ok(runner.is_the_display_card({ total = 11, used = 0.3, free = 10.6 }),
       "a card with something already on it is drawing a screen")
  t.ok(not runner.is_the_display_card({ total = 24, used = 0.0, free = 24 }),
       "and one with nothing on it is not")
  t.ok(not runner.is_the_display_card(nil),
       "a card that will not say is not assumed to be one")

  -- THE ASSERTION THIS TICKET EXISTS FOR. That a picture gets made when there
  -- is room is the ordinary path. That a run stops rather than taking the last
  -- of the memory the desktop is living in is the thing, and it is the one a
  -- later tidy-up would quietly drop.
  local tight = { kitchen = {} }
  for key, value in pairs(settings.kitchen) do tight.kitchen[key] = value end
  tight.kitchen.least_free_vram = 99999
  local room, seen = runner.room_to_work(tight)
  if seen then
    t.ok(not room, "a run refuses to start when the card has no room to spare",
         string.format("%.1f GB free against a floor of %d", seen.free,
                       tight.kitchen.least_free_vram))
  else
    t.note("this machine has no card that will report its memory; not checked")
  end

  local roomy = { kitchen = {} }
  for key, value in pairs(settings.kitchen) do roomy.kitchen[key] = value end
  roomy.kitchen.least_free_vram = 0
  t.ok(runner.room_to_work(roomy), "and does start when there is")

  -- A machine with no card at all must not be stopped by a check about cards.
  t.ok(runner.room_to_work({ kitchen = {} }),
       "a machine that reports nothing is not refused on that account")

  local card = runner.card()
  if card then
    t.ok(card.total > 0, "the card reports a size")
    t.near(card.used + card.free, card.total, card.total * 0.06,
           "and its used and free add up to about its total")
    t.note(string.format("%.1f GB, %.1f free, %s", card.total, card.free,
           runner.is_the_display_card(card) and "also drawing the screen"
           or "not drawing a screen"))
  end

  t.ok(settings.kitchen.reserve_vram and settings.kitchen.reserve_vram > 0,
       "and something is held back for the desktop by default")
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
    { "the card is also the screen", test_the_card_is_also_the_screen },
    { "the paintbrush", test_the_paintbrush },
    { "reading a picture", test_reading_a_picture },
    { "the pool and the graders", test_the_pool_and_the_graders },
    { "the dial", test_the_dial },
    { "the animation", test_the_animation },
    { "the two sites", test_the_two_sites },
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
