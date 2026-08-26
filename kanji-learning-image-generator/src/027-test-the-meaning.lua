-- 027-test-the-meaning.lua
--
-- Everything phase two claims, checked.
--
-- For a general: phase two decides what a picture is *of*. It measures each
-- stroke, works out what world the character belongs to, which of its pieces
-- are subjects and which are only sounds, and builds the grey image that
-- carries the illusion.
--
-- Almost none of that can be tested against the thing it is for. The
-- specification is that a person squints at a thumbnail and sees the character,
-- and no assertion here observes that. So these tests check that the machinery
-- did what it was told, and the demonstration in phase two exists to let
-- somebody check whether what it was told was right.
--
-- The assertion helpers come from `020`, which owns them.
--
--   luajit src/027-test-the-meaning.lua [--dir ROOT]

local project = dofile((debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$")) ..
                       "/009-where-things-are.lua")

local M = {}

-- {{{ test_measuring_a_stroke(t)
-- Characters whose answers are known by looking at them.
--
-- 一 is one horizontal. 十 is a horizontal and a vertical. 川 is three
-- verticals. 人 is a fall to the left and a fall to the right. If those four
-- come out wrong the direction boundaries are wrong, and they are assertions
-- that need no judgement from anybody.
local function test_measuring_a_stroke(t)
  local shape = project.load("021-the-shape-of-a-stroke")
  local store = project.load("019-the-kanji-record").store()

  local function directions(character)
    local measured = shape.measure_record(store.records[character])
    local out = {}
    for index, one in ipairs(measured) do out[index] = one.direction end
    return table.concat(out, " ")
  end

  t.same(directions("一"), "horizontal", "one is a single horizontal")
  t.same(directions("十"), "horizontal vertical", "ten is a cross")
  t.same(directions("川"), "vertical vertical vertical", "river is three verticals")
  t.same(directions("人"), "falling_left falling_right", "person falls both ways")

  -- The horizontal range is deliberately not centred on level, because a
  -- Japanese horizontal is written with a slight rise and a symmetric range
  -- throws the shallower ones into "rising". This is that rise, measured.
  local one = shape.measure_record(store.records["一"])[1]
  t.ok(one.angle > 340 and one.angle < 360,
       "and a horizontal really does rise slightly", string.format("%.1f degrees", one.angle))

  -- A hook is a sharp turn at the very end. The archive labels which strokes
  -- have one, and the measurement agrees -- see --calibrate on `021`.
  local hooked = shape.measure_record(store.records["丁"])
  local any_hooked = false
  for _, stroke in ipairs(hooked) do
    if stroke.hooked then any_hooked = true end
  end
  t.ok(any_hooked, "a character written with a hook measures as hooked")

  local straight = shape.measure_record(store.records["一"])[1]
  t.ok(not straight.hooked, "and one written without a hook does not")
  t.near(straight.bend, 1, 0.15, "a straight stroke barely bends")

  -- Size is measured apart from direction, because a dot and a long sweeping
  -- stroke point the same way and are not the same thing.
  local dots = shape.measure_record(store.records["犬"])
  local found_dot = false
  for _, stroke in ipairs(dots) do
    if stroke.size == "dot" then found_dot = true end
  end
  t.ok(found_dot, "a character with a dot in it has a stroke measured as a dot")

  local shares = shape.measure_record(store.records["川"])
  local total = 0
  for _, stroke in ipairs(shares) do total = total + stroke.weight end
  t.near(total, 1, 1e-6, "every stroke's share of the ink adds up to all of it")

  local heaviest = shape.structural(shares, 1)
  t.same(#heaviest, 1, "asking for the structural strokes gives that many")
  t.ok(heaviest[1].weight >= shares[1].weight,
       "and the heaviest really is the heaviest")
end
-- }}}

-- {{{ test_the_structure_field(t)
local function test_the_structure_field(t)
  local field = project.load("022-the-structure-field")
  local shape = project.load("021-the-shape-of-a-stroke")
  local canvas = project.load("016-the-grey-canvas")
  local store = project.load("019-the-kanji-record").store()
  local settings = project.settings()

  local record = store.records["川"]
  local measured = shape.measure_record(record)
  local surface, made = field.build(record, settings, { measured = measured })

  t.same(surface.width, settings.field.resolution, "the field is the size asked for")

  local low, high = canvas.extremes(surface)
  local wanted_low = 1 - settings.field.range_high
  local wanted_high = 1 - settings.field.range_low
  t.near(low, wanted_low, 0.01, "the darkest value sits on the band's floor")
  t.near(high, wanted_high, 0.01, "and the lightest on its ceiling")

  -- Every stroke has to have put ink somewhere. A stroke that vanished means
  -- the scaling is wrong for that character, and the illusion silently loses a
  -- line while the picture still looks fine.
  local along = field.inspect(surface, measured, settings)
  local missing = 0
  for index = 1, #measured do
    if not along[index] or along[index] > (wanted_low + wanted_high) / 2 then
      missing = missing + 1
    end
  end
  t.same(missing, 0, "every stroke left ink along its own line")

  -- Ink reaching the border means the character has been scaled wrongly and
  -- whatever fell off the edge is lost from the illusion.
  t.ok(field.edge_ink(surface) < 0.15, "and none of it reached the border",
       string.format("%.3f away from the background at the worst point",
                     field.edge_ink(surface)))

  -- The weakening along the writing order. 川 is three separate verticals that
  -- do not touch, so each stroke's darkness is its own -- on a character whose
  -- strokes cross, the blur mixes them and the ordering is not readable back
  -- out of the finished field.
  if settings.field.order_ramp > 0 then
    t.ok(along[1] < along[#along],
         "the first stroke is darker than the last, so the composition carries the order",
         string.format("%.4f then %.4f", along[1], along[#along]))
  else
    t.note("the writing-order ramp is turned off in settings; not checked")
  end

  -- The margin is applied to the archive's box, not to the character's own ink.
  -- Centring each character on its own extent would make a single horizontal
  -- line fill the frame as densely as a crowded character does, and a learner
  -- would lose the only signal they have for how much is in a character.
  local one = store.records["\228\184\128"]
  local one_field = field.build(one, settings)
  local ink_rows = 0
  for y = 0, one_field.height - 1 do
    local darkest = 1
    for x = 0, one_field.width - 1 do
      local value = one_field.pixels[y * one_field.width + x + 1]
      if value < darkest then darkest = value end
    end
    if darkest < 0.5 then ink_rows = ink_rows + 1 end
  end
  t.ok(ink_rows < one_field.height * 0.5,
       "a one-stroke character does not fill the frame",
       string.format("%d of %d rows hold ink", ink_rows, one_field.height))

  -- The blur has to shrink as a character gets crowded, or the dense ones weld
  -- shut at exactly the size the whole project is specified at.
  local sparse = field.blur_for(3, settings)
  local middling = field.blur_for(8, settings)
  local dense = field.blur_for(29, settings)
  t.ok(sparse > middling and middling > dense,
       "a crowded character is softened less than a sparse one",
       string.format("%.1f, %.1f, %.1f at 3, 8 and 29 strokes", sparse, middling, dense))
  t.ok(dense >= settings.field.blur_minimum,
       "and never below the floor where softening stops working")

  local small = field.thumbnail(surface, settings)
  t.same(small.width, settings.field.thumbnail,
         "the thumbnail is the size the illusion is specified at")

  t.note(string.format("river at %d strokes was blurred by %.1f",
         made.strokes, made.blur_radius))
end
-- }}}

-- {{{ test_the_component_lexicon(t)
local function test_the_component_lexicon(t)
  local lexicon = project.load("023-the-component-lexicon")
  local store = project.load("019-the-kanji-record").store()

  -- The rule that separates a gloss about the world from a gloss about the
  -- writing system. Without it the commonest pieces in the archive all resolve
  -- to their catalogue entries and every scene is about the naming of radicals.
  t.ok(lexicon.is_paintable("tree"), "a thing is paintable")
  t.ok(lexicon.is_paintable("mouth"), "so is another one")
  t.ok(not lexicon.is_paintable("radical number 9"), "a catalogue number is not")
  t.ok(not lexicon.is_paintable("kettle lid radical (no. 8)"), "nor a radical name")
  t.ok(not lexicon.is_paintable("katakana no radical (no. 4)"), "nor a kana name")
  t.ok(not lexicon.is_paintable("counter for small animals"), "nor a counter")

  local tree = lexicon.look_up({ element = "\230\156\168", depth = 2 }, store)
  t.ok(tree ~= nil, "a piece that is a character resolves")
  t.same(tree.depicts, "a tree", "to something that can be in a picture")

  -- The squeezed form of a character has its own dictionary entry, and that
  -- entry is its catalogue number. The archive says what it is a squeezed form
  -- *of*, and that is where the meaning is.
  local person_form = lexicon.look_up(
    { element = "\228\186\187", depth = 2, original = "\228\186\186" }, store)
  t.ok(person_form ~= nil, "a squeezed form resolves too")
  t.ok(person_form.depicts:find("figure") or person_form.depicts:find("person"),
       "to a person rather than to a radical number", person_form.depicts)

  local nothing = lexicon.look_up({ element = "\239\191\189", depth = 2 }, store)
  t.same(nothing, nil, "and something with no answer returns none, rather than a guess")

  -- Coverage is measured and printed, not asserted against a threshold. A
  -- number turned into a threshold is a number somebody adjusts; a number
  -- printed is a number somebody looks at.
  local found = lexicon.coverage(store)
  local resolved = found.total - (found.by_source.nothing or 0)
  t.ok(found.total > 10000, "coverage is measured across the whole archive")
  t.ok(resolved > 0, "and some of it resolves")
  t.note(string.format("%d of %d component appearances resolve (%.1f%%), from %d written rows",
         resolved, found.total, resolved / found.total * 100, lexicon.written_count()))
  if #found.queue > 0 then
    t.note(string.format("commonest piece with no picture: %s, %d times",
           found.queue[1].element, found.queue[1].count))
  end
end
-- }}}

-- {{{ test_the_scene_grammar(t)
-- The reasoning, not the wording.
--
-- Every assertion here is about which world, which subjects, which pieces were
-- demoted. None mentions a word of English prose, which is the point of the
-- scene being a table of facts -- `205` owns the sentences and can be rewritten
-- without any of these changing.
local function test_the_scene_grammar(t)
  local grammar = project.load("024-the-scene-grammar")
  local store = project.load("019-the-kanji-record").store()
  local settings = project.settings()

  local function world_of(character)
    local scene = grammar.scene(store.records[character], store, settings)
    return scene and scene.biome.name or nil
  end

  t.same(world_of("\230\156\168"), "forest", "a tree belongs in a forest")
  t.same(world_of("\229\183\157"), "water", "a river belongs in water")
  t.same(world_of("\229\177\177"), "mountain", "a mountain belongs on a mountain")
  t.same(world_of("\231\129\171"), "fire", "a fire belongs in fire")

  -- A character with no parts has exactly one component: itself. Skipping the
  -- outermost level left every atomic character with no evidence at all, and
  -- those are the first characters anybody learns.
  t.same(world_of("\228\184\128"), "sky", "one, which has no parts, still lands somewhere")
  t.same(world_of("\232\187\138"), "road", "and so does car")

  -- The etymology. Rest is a person beside a tree, and both have to survive
  -- into the cast, or the picture is not the character.
  local rest = grammar.scene(store.records["\228\188\145"], store, settings,
                             { reading = "semantic" })
  t.same(#rest.subjects, 2, "rest has two subjects")
  t.same(#rest.landscape, 0, "and neither of them is there for its sound")

  -- The half of a character chosen for its sound is demoted to ground, and so
  -- is everything inside it. The pieces inside the sound half of "language" are
  -- two mouths, and counted, they outvoted the speech radical and put the scene
  -- in a room with a person in it instead of at a desk with words on it.
  --
  -- Asked for by name, because the default reading is now the other one and a
  -- test that relied on the default would have been testing whichever reading
  -- somebody last set in the settings file.
  local language = grammar.scene(store.records["\232\170\158"], store, settings,
                                 { reading = "semantic" })
  t.same(world_of("\232\170\158"), "word", "language is about words")
  t.same(#language.subjects, 1, "and has exactly one subject")
  t.same(language.subjects[1].element, "\232\168\128", "which is the speech radical")
  t.ok(#language.landscape >= 2,
       "with the sound half and its insides all demoted to ground",
       #language.landscape .. " pieces became ground")
  local marked = 0
  for _, ground in ipairs(language.landscape) do
    if ground.marked then marked = marked + 1 end
  end
  t.same(marked, 1, "though the archive itself only marked one of them")

  -- The same failure in a different character, kept because it is the shape of
  -- mistake this project is most at risk of: the picture looks fine and is
  -- about the wrong thing.
  t.same(world_of("\230\153\130"), "sky", "time is a sun, not the earth beneath it")

  -- A character that matches nothing is refused rather than given a default
  -- world. A default would make some unknown share of the output generic
  -- landscapes unrelated to their characters, and every one would look fine.
  local nothing_scored = nil
  for _, record in ipairs(store.order) do
    if not grammar.scene(record, store, settings) then
      nothing_scored = record.character
      break
    end
  end
  if nothing_scored then
    local scene, why = grammar.scene(store.records[nothing_scored], store, settings)
    t.same(scene, nil, "a character with no evidence gets no scene")
    t.ok(why ~= nil and why:find(nothing_scored, 1, true) ~= nil,
         "and the refusal names the character and says what was tried")
  else
    t.note("every character in the set matched a world; the refusal path is untested")
  end

  -- The scene holds facts. Building sentences is `205`'s job, and keeping that
  -- boundary is what lets the wording be rewritten without touching any of the
  -- reasoning above.
  t.same(rest.prompt, nil, "a scene carries no assembled prose")

  local spread, homeless = grammar.spread(store, settings)
  t.ok(#spread >= 15, "the whole set is distributed across the worlds")
  t.ok(spread[1].count < #store.order * 0.6,
       "and no single world swallows most of it",
       string.format("the largest is %s at %.1f%%", spread[1].name,
                     spread[1].count / #store.order * 100))
  t.note(string.format("largest %s %d, smallest %s %d, %d matched nothing",
         spread[1].name, spread[1].count, spread[#spread].name,
         spread[#spread].count, #homeless))
end
-- }}}

-- {{{ test_the_words(t)
local function test_the_words(t)
  local words = project.load("025-the-words-the-machine-reads")
  local store = project.load("019-the-kanji-record").store()
  local settings = project.settings()

  local rest = words.prompts(store.records["\228\188\145"], store, settings)
  t.ok(rest ~= nil, "a prompt gets built")

  -- The whole claim of this project is that the character *is* the picture,
  -- and for "rest" that means a person and a tree, both. An earlier version
  -- shortened the sentence by dropping whichever clause sat second from the
  -- end, which for this character was the person -- leaving a prompt for a tree
  -- in a wood and silently deleting the reason the picture teaches anything.
  t.ok(rest.positive:find("figure", 1, true) ~= nil,
       "and rest keeps its person after the sentence is shortened", rest.positive)
  t.ok(rest.positive:find("tree", 1, true) ~= nil, "as well as its tree")

  -- The photographic terms are what keep the model out of illustration, and an
  -- illustration has flat regions of colour with no light and shade for the
  -- strokes to hide in.
  t.ok(rest.positive:find("photographic", 1, true) ~= nil,
       "and the terms that keep it a photograph are never dropped")

  -- The failure this project invites is a model satisfying "kanji" by painting
  -- one -- on a wall, a banner, a carved sign. Present, useless, and good
  -- enough to pass a careless glance. These terms are a constant and not a
  -- setting, because a setting is a thing somebody empties.
  for _, term in ipairs({ "kanji", "calligraphy", "text", "japanese characters",
                          "signage", "watermark" }) do
    t.ok(words.refusals():find(term, 1, true) ~= nil,
         "every prompt refuses " .. term)
  end

  -- A prompt past what the encoder reads does not fail -- it quietly ignores
  -- its own end, and the end is where the photographic terms are.
  local longest, longest_character = 0, nil
  local checked, missing_refusals = 0, 0
  for index = 1, math.min(400, #store.order) do
    local made = words.prompts(store.order[index], store, settings)
    if made then
      checked = checked + 1
      if made.length.tokens > longest then
        longest = made.length.tokens
        longest_character = store.order[index].character
      end
      -- checked without asserting per character, so that four hundred passes
      -- do not drown the handful of assertions that say something
      if made.negative ~= words.refusals() then
        missing_refusals = missing_refusals + 1
      end
    end
  end
  t.same(missing_refusals, 0,
         "every prompt in a sample of " .. checked .. " carries the refusals")
  t.ok(longest <= 80, "and none of them runs past what the encoder reads",
       string.format("the longest was %s at about %d tokens", longest_character, longest))
  t.note(string.format("longest prompt in %d characters: %s, about %d tokens",
         checked, longest_character or "-", longest))

  -- Two runs of the same character must produce the same sentence, or nothing
  -- downstream can be compared between runs.
  local once = words.prompts(store.records["\230\163\174"], store, settings)
  local twice = words.prompts(store.records["\230\163\174"], store, settings)
  t.same(twice.positive, once.positive, "the same character makes the same sentence")
end
-- }}}

-- {{{ test_the_arrows(t)
local function test_the_arrows(t)
  local arrows = project.load("026-arrows-that-teach-the-order")
  local shape = project.load("021-the-shape-of-a-stroke")
  local flatten = project.load("015-flatten-the-curves")
  local store = project.load("019-the-kanji-record").store()
  local settings = project.settings()

  local record = store.records["\228\188\145"]
  local measured = shape.measure_record(record)
  local surfaces, made = arrows.build(record, settings, { measured = measured })

  t.same(made.arrows, #record.strokes, "there is one arrow per stroke")
  t.same(#surfaces, 4, "and the sheet has three colours and a transparency")

  -- Everywhere there is no arrow has to be see-through, or the layer covers the
  -- picture it is annotating.
  local opaque = 0
  local total = surfaces[4].width * surfaces[4].height
  for index = 1, total do
    if surfaces[4].pixels[index] > 0.01 then opaque = opaque + 1 end
  end
  t.ok(opaque > 0, "something was drawn")
  t.ok(opaque < total * 0.2, "and most of the sheet is see-through",
       string.format("%.1f%% of it is not", opaque / total * 100))

  -- THE ONE THING HERE THAT IS NOT VISIBLE AT A GLANCE. An arrow must point the
  -- way the stroke *leaves*, which on a curving stroke is nothing like the
  -- direction from its start to its end. An arrow aimed at the far end of a
  -- bending stroke points straight through the middle of the bend and teaches
  -- the wrong exit -- and it looks perfectly reasonable.
  --
  -- Checked on a stroke found in the archive where the two genuinely disagree,
  -- rather than on one invented for the purpose.
  local found_curved = false
  for index = 1, math.min(300, #store.order) do
    local candidate = store.order[index]
    local shapes = shape.measure_record(candidate)
    for number, one in ipairs(shapes) do
      local flat = one.flat
      local tx, ty = flatten.direction(flat, 1)
      local cx = flat.xs[flat.count] - flat.xs[1]
      local cy = flat.ys[flat.count] - flat.ys[1]
      local size = math.sqrt(cx * cx + cy * cy)
      if size > 5 then
        cx, cy = cx / size, cy / size
        local between = math.deg(math.acos(
          math.max(-1, math.min(1, tx * cx + ty * cy))))
        if between > 45 and not found_curved then
          found_curved = true
          local _, placement = arrows.build(candidate, settings,
                                            { measured = shapes })
          local drawn = placement.placed[number]
          local agrees = drawn.direction_x * tx + drawn.direction_y * ty
          local against = drawn.direction_x * cx + drawn.direction_y * cy
          t.ok(agrees > 0.99,
               "an arrow points the way its stroke leaves",
               string.format("%s stroke %d, %.0f degrees between exit and chord",
                             candidate.character, number, between))
          t.ok(agrees > against,
               "and not at where the stroke ends up")
        end
      end
    end
    if found_curved then break end
  end
  t.ok(found_curved, "a stroke that bends enough to tell the two apart was found")

  -- A character with thirty strokes in one box has nowhere for thirty labels to
  -- go, and the layer says so rather than piling them up silently.
  local dense = store.records["\233\172\177"]
  if dense then
    local _, crowded = arrows.build(dense, settings)
    t.ok(crowded.arrows == #dense.strokes,
         "a crowded character still gets an arrow for every stroke")
    t.note(string.format("%s: %d arrows, %d had to be shortened for room",
           dense.character, crowded.arrows, crowded.crowded))
  end
end
-- }}}

-- {{{ test_the_two_readings(t)
-- The picture can be about the meaning, or it can be a hook the meaning hangs
-- on, and those want opposite things done with the half of a character that was
-- chosen for its sound. Both readings have to keep working.
local function test_the_two_readings(t)
  local grammar = project.load("024-the-scene-grammar")
  local lexicon = project.load("023-the-component-lexicon")
  local store = project.load("019-the-kanji-record").store()
  local settings = project.settings()

  local time = store.records["\230\153\130"]

  -- The mnemonic reading. Time is a sun over a temple, and it works precisely
  -- because a temple has nothing to do with time.
  local hook = grammar.scene(time, store, settings, { reading = "mnemonic" })
  t.same(#hook.subjects, 2, "under the mnemonic reading, time has two subjects")
  t.same(hook.subjects[1].element, "\230\151\165", "the sun leads")
  t.ok(not hook.subjects[1].for_the_sound, "and it carries the meaning")
  t.ok(hook.subjects[2].for_the_sound,
       "while the second is marked as being there only for the sound")
  t.same(#hook.landscape, 0, "and nothing was demoted to ground")

  -- The head of the list is the one the sentence weights and the last one it
  -- gives up. Sorting by size alone put the temple in front of the sun.
  t.ok(hook.subjects[1].box and hook.subjects[2].box, "both have a place")

  -- The semantic reading, which is what `docs/004` argued for and is still
  -- right for the question it was answering.
  local about = grammar.scene(time, store, settings, { reading = "semantic" })
  t.same(#about.subjects, 1, "under the semantic reading, time has one subject")
  t.same(about.subjects[1].element, "\230\151\165", "which is the sun")
  t.ok(#about.landscape >= 1, "and the sound half became ground")

  -- The world must not move between readings. A sound half never votes on which
  -- world a character belongs to, in either reading, because that was never
  -- about the picture.
  t.same(hook.biome.name, about.biome.name,
         "the world is the same either way, because the scoring is the same")

  t.ok(not pcall(grammar.scene, time, store, settings, { reading = "sideways" }),
       "a reading that is neither is refused by name")

  -- Every piece has a short name as well as a phrase, because a phrase goes in
  -- a sentence and a name is what a learner is told the piece is called.
  local tree = lexicon.look_up({ element = "\230\156\168", depth = 2 }, store)
  t.same(tree.name, "tree", "a piece has a name")
  t.same(tree.depicts, "a tree", "as well as a phrase")

  local say = lexicon.look_up({ element = "\232\168\128", depth = 2 }, store)
  t.same(say.name, "say", "and the name is shorter than the phrase")
  t.ok(#say.name < #say.depicts, "always")

  -- The names are mostly derived rather than written twice, because a hundred
  -- and seventy written by hand is a hundred and seventy chances for the name
  -- and the description to drift apart.
  t.same(lexicon.name_from("a temple with a bronze bell"), "temple",
         "a name is the head of its phrase")
  t.same(lexicon.name_from("a hand reaching down to grasp"), "hand",
         "with the elaboration cut off")
  t.same(lexicon.name_from("the sun"), "sun", "and the article too")

  -- A pronoun is a correct translation and cannot be in a photograph. The piece
  -- inside the sound half of "language" is glossed "I", which put the word "I"
  -- into a scene description as though it named something.
  t.ok(not lexicon.is_paintable("I"), "a pronoun is not a picture")
  t.ok(not lexicon.is_paintable("that"), "nor is a demonstrative")
  t.ok(lexicon.is_paintable("item"), "though a word containing one still is")

  local language = grammar.scene(store.records["\232\170\158"], store, settings,
                                 { reading = "mnemonic" })
  local named = {}
  for _, subject in ipairs(language.subjects) do
    named[#named + 1] = subject.depicts
  end
  for _, phrase in ipairs(named) do
    t.ok(phrase ~= "I", "no subject in a scene is a bare pronoun", phrase)
  end
  t.ok(#named > 0, "and language still has subjects under the mnemonic reading")
end
-- }}}

-- {{{ test_a_phrase(t)
-- A word is what a learner is actually trying to hold. 時 and 間 separately are
-- not the thing; 時間 is, and it means "time".
local function test_a_phrase(t)
  local phrases = project.load("019a-a-phrase-is-a-record-too")
  local field = project.load("022-the-structure-field")
  local grammar = project.load("024-the-scene-grammar")
  local store = project.load("019-the-kanji-record").store()
  local settings = project.settings()

  local TIME, INTERVAL = "\230\153\130", "\233\150\147"
  local record = phrases.build(TIME .. INTERVAL, { "time", "an hour" }, store)

  -- The property everything else rests on: a phrase's strokes are its
  -- characters' strokes, in order, with nothing lost between them.
  local time = store.records[TIME]
  local interval = store.records[INTERVAL]
  t.same(#record.strokes, #time.strokes + #interval.strokes,
         "a phrase has every stroke of every character in it")
  t.same(record.strokes[1].d, time.strokes[1].d, "starting with the first")
  t.same(record.strokes[#time.strokes + 1].d, interval.strokes[1].d,
         "and the second character following straight on")

  -- The numbering is continuous, because that is the order a hand writes the
  -- phrase in and the writing order is the viewing order.
  local cells = phrases.cells(record)
  t.same(#cells, 2, "the phrase knows it is two characters")
  t.same(cells[1].stroke_first, 1, "the first starts at stroke one")
  t.same(cells[2].stroke_first, #time.strokes + 1,
         "and the second picks up where it left off")
  t.same(cells[2].stroke_last, #record.strokes, "through to the end")

  -- Every stroke remembers which character it came from, which is how the field
  -- knows which box to draw it in.
  t.same(record.strokes[1].cell, 1, "a stroke knows its character")
  t.same(record.strokes[#record.strokes].cell, 2, "including the last one")

  -- A single character is one cell. Saying so in one place is what lets
  -- everything downstream treat a word and a character as the same thing.
  t.same(#phrases.cells(time), 1, "a single character is one cell")
  t.same(phrases.cells(time)[1].stroke_last, #time.strokes,
         "covering all of its strokes")
  t.ok(not phrases.is_phrase(time), "and is not a phrase")
  t.ok(phrases.is_phrase(record), "while a word is")

  -- The picture grows wider rather than each character shrinking. A phrase that
  -- squeezed its characters to fit would be a phrase whose characters stop
  -- being legible at the one size this project is specified at.
  local placement = field.placement(settings, record)
  t.same(placement.count, 2, "the picture has two boxes")
  t.same(placement.width, settings.field.resolution * 2, "and is twice as wide")
  t.same(placement.height, settings.field.resolution, "and no taller")
  t.same(placement.cells[1].scale, placement.cells[2].scale,
         "both characters are drawn at the same size as each other")
  t.same(field.placement(settings, time).cells[1].scale, placement.cells[1].scale,
         "and at the same size they would have had alone")

  -- The blur follows how crowded a character is, not how many strokes the whole
  -- phrase has -- a two-character word has twice the strokes and exactly the
  -- same crowding.
  local _, made = field.build(record, settings)
  local _, alone = field.build(time, settings)
  t.near(made.blur_radius, alone.blur_radius, 2.5,
         "a word is softened like a character, not like a monster",
         string.format("%.1f against %.1f", made.blur_radius, alone.blur_radius))

  -- The pieces of both characters are the cast, and they are named in reading
  -- order rather than in size order, or the sentence describes the phrase
  -- backwards.
  local scene = grammar.scene(record, store, settings)
  t.ok(#scene.subjects >= 3, "a two-character word has a cast from both",
       #scene.subjects .. " subjects")
  local last_cell = 0
  local in_order = true
  for _, subject in ipairs(scene.subjects) do
    if not subject.for_the_sound then
      if (subject.cell or 1) < last_cell then in_order = false end
      last_cell = subject.cell or 1
    end
  end
  t.ok(in_order, "and they are named in the order the phrase is read")

  -- A word's meaning is not in either archive, so it has to be given.
  t.ok(not pcall(phrases.build, TIME .. INTERVAL, {}, store),
       "a phrase with no meaning given is refused, and says where to put one")
  t.ok(not pcall(phrases.build, "\240\159\152\128", { "a face" }, store),
       "and so is one containing a character this project cannot draw")

  -- 時間 and 間時 are different words and must not get the same picture.
  local backwards = phrases.build(INTERVAL .. TIME, { "nonsense" }, store)
  t.ok(backwards.codepoint ~= record.codepoint,
       "the same characters in a different order are a different phrase")

  local parsed = phrases.from_argument(TIME .. INTERVAL .. "=time,an hour", store)
  t.same(parsed.meanings[2], "an hour", "a phrase can be given on a command line")
end
-- }}}

-- {{{ M.run(options)
function M.run(options)
  local ink = project.load("020-test-the-ink")
  local groups = {
    { "measuring a stroke", test_measuring_a_stroke },
    { "the structure field", test_the_structure_field },
    { "the component lexicon", test_the_component_lexicon },
    { "the scene grammar", test_the_scene_grammar },
    { "the words", test_the_words },
    { "the arrows", test_the_arrows },
    { "the two readings", test_the_two_readings },
    { "a phrase", test_a_phrase },
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
  project.hello("027-test-the-meaning")
  io.write("phase two -- the meaning\n")
  local passed = M.run({})
  project.goodbye("027-test-the-meaning",
                  { passed and "all passed" or "SOMETHING FAILED" })
  os.exit(passed and 0 or 1)
end
-- }}}

if arg and arg[0] and arg[0]:find("027%-test%-the%-meaning") then
  main(arg)
end

return M
