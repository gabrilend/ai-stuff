-- 025-the-words-the-machine-reads.lua
--
-- Turns a scene into the two sentences a diffusion model is given: what the
-- picture is, and what it must not be.
--
-- For a general: everything upstream decided facts -- this world, these
-- subjects, this object along that line. A diffusion model does not read facts;
-- it reads a sentence. This is the only file in the project that writes
-- English, and keeping it the only one is why `024` is forbidden from building
-- sentences even though it is where all the information is. Rewording the whole
-- project's output should mean editing this file and nothing else, and testing
-- the reasoning should never mean reading prose.
--
--   luajit src/025-the-words-the-machine-reads.lua --chars 休語時川

local project = dofile((debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$")) ..
                       "/009-where-things-are.lua")
local grammar = project.load("024-the-scene-grammar")

local M = {}

-- {{{ REFUSALS -- the negative prompt, and it is not a tuning parameter
--
-- THIS IS WHERE THE PROJECT IS DEFENDED. The idea invites one specific failure:
-- a model satisfying "kanji" by *painting a kanji*. A brushed character on a
-- wall, a banner, a carved sign, a shop curtain. Technically present, completely
-- useless as a learning image, and the picture will look good enough to pass a
-- careless glance -- so nobody reviewing a set of six thousand would catch it.
--
-- The character has to be assembled out of scenery or the whole thing has not
-- worked. So these terms are a constant rather than a setting, and this comment
-- is the reason: a setting is a thing somebody empties.
--
-- The second group is ordinary quality refusal. The first group is the project.
local REFUSALS = table.concat({
  "text", "letters", "lettering", "words", "writing", "calligraphy",
  "brush strokes", "ink wash", "chinese characters", "japanese characters",
  "kanji", "hanzi", "signage", "watermark", "signature", "logo",
  "border", "frame", "caption", "subtitle",
  "illustration", "cartoon", "flat colour", "poster", "diagram",
  "blurry", "low contrast", "washed out", "deformed",
}, ", ")
-- }}}

-- {{{ TAIL -- what keeps the model out of illustration
--
-- An illustration has large flat regions of one colour, and a flat region
-- cannot hide a shape -- there is no light and shade in it for the strokes to
-- live in. Photographic terms are not a style preference here; they are what
-- makes the illusion possible at all.
local TAIL = "photographic, natural light, shallow depth of field, fine texture"
-- }}}

-- {{{ WORD_BUDGET -- how long the sentence may be
--
-- The text encoder these models use reads about seventy-five tokens and then
-- stops. It does not fail -- it quietly ignores the end of what it was given,
-- which means the photographic tail falls off and nobody is told.
--
-- Counted in words times a factor rather than with the real tokeniser, which is
-- not here. The estimate is documented as an estimate so that nobody later
-- reports a bug against it; being a few tokens out costs nothing, because the
-- budget is set below the limit on purpose.
local WORD_BUDGET = 54
local TOKENS_PER_WORD = 1.35
-- }}}

-- {{{ M.token_estimate(text)
function M.token_estimate(text)
  local words = 0
  for _ in text:gmatch("%S+") do words = words + 1 end
  return math.floor(words * TOKENS_PER_WORD + 0.5), words
end
-- }}}

-- {{{ M.refusals()
function M.refusals() return REFUSALS end
-- }}}

-- {{{ M.positive(scene, settings)
-- The scene, as the sentence describing it.
--
-- Every clause carries a rank, and the sentence is shortened by dropping the
-- lowest-ranked clause until it fits. The ranks are a claim about what a
-- learning image cannot do without.
--
-- WHY RANKS AND NOT POSITIONS. The first attempt kept the head and the tail and
-- trimmed the middle, on the reasoning that a text encoder weighs the beginning
-- most and the photographic terms at the end are what stop the model drawing a
-- cartoon. Both true. But when the middle ran out, the next thing to go was
-- whatever sat second from the end of the head -- and for the character meaning
-- *rest*, that was the person. The prompt came back as a tree in a wood, having
-- silently deleted the entire reason this project claims to teach anything.
--
-- A colour palette is expendable. An etymology is not. Saying so explicitly is
-- the only way the sentence shortens in the right direction.
--
--   100  the first subject, weighted
--    92  the second subject
--    88  the world, in its particular version
--    80  the photographic tail
--    72  the third subject
--    60  the light
--    50  the objects along the strokes, heaviest first
--    40  the ground the sound-half became
--    30  the palette
--    20  the note that this is an abstract word
function M.positive(scene, settings)
  -- Two orders, and they are not the same order. `rank` decides what gets
  -- dropped when the sentence is too long; `place` decides where a clause sits
  -- in the sentence that is finally written. Using one for both put the
  -- photographic terms -- which must never be dropped, so they rank high --
  -- into the middle of the sentence, between the setting and the light.
  local clauses = {}
  local function say(rank, place, text)
    if text and text ~= "" then
      clauses[#clauses + 1] = { rank = rank, place = place, text = text }
    end
  end

  -- Not every piece gets named. A crowded character can have six, and naming
  -- all six spends the whole sentence before the world is mentioned. `024`
  -- sorted them largest first, so what survives is what dominates the picture.
  local most = settings.scene.named_subjects or 3
  local subject_ranks = { 100, 92, 72 }
  for index, subject in ipairs(scene.subjects) do
    if index > most then break end
    -- Only the first subject is weighted. Weighting everything weights nothing,
    -- and a sentence full of parentheses is a sentence somebody has stopped
    -- reading.
    local phrase = (index == 1)
      and ("(" .. subject.depicts .. ":1.2) " .. subject.where)
      or (subject.depicts .. " " .. subject.where)
    say(subject_ranks[index] or 65, 10 + index, phrase)
  end

  -- A character with no nameable pieces still has a world and still has
  -- strokes. The sentence then starts with the setting, which is a legitimate
  -- picture: a landscape with no figure in it.
  say(88, 20, scene.biome.register)

  for index, role in ipairs(scene.named) do
    say(50 - index, 30 + index, role.phrase or role.object)
  end
  for index, ground in ipairs(scene.landscape) do
    say(40 - index, 50 + index, ground.terrain)
  end

  say(60, 60, scene.biome.light)
  say(30, 65, scene.biome.palette)

  -- A character read only with borrowed pronunciations is usually an abstract,
  -- bookish word rather than a thing somebody points at. Saying so nudges the
  -- model towards something staged and quiet instead of a snapshot.
  if scene.register_note == "abstract" then
    say(20, 70, "still, composed, deliberate")
  end

  say(80, 80, TAIL)

  -- Emitted in the order that reads as a sentence and puts the most heavily
  -- weighed words first: subjects, world, composition, ground, light, palette,
  -- then the terms that keep it photographic.
  local order = {}
  for index, clause in ipairs(clauses) do order[index] = clause end
  table.sort(order, function(a, b)
    if a.place ~= b.place then return a.place < b.place end
    return a.rank > b.rank
  end)

  local dropped = 0
  local function assemble()
    local kept = {}
    for _, clause in ipairs(order) do
      if not clause.gone then kept[#kept + 1] = clause.text end
    end
    return table.concat(kept, ", ")
  end

  local function weakest()
    local found = nil
    for _, clause in ipairs(order) do
      if not clause.gone and (not found or clause.rank < found.rank) then
        found = clause
      end
    end
    return found
  end

  local text = assemble()
  while select(2, M.token_estimate(text)) > WORD_BUDGET do
    local going = weakest()
    -- Everything left is something the sentence cannot do without. A prompt
    -- slightly over budget loses a few words off its end; a prompt with no
    -- subject in it is not a prompt for this picture at all.
    if not going or going.rank >= 80 then break end
    going.gone = true
    dropped = dropped + 1
    text = assemble()
  end

  local tokens, words = M.token_estimate(text)
  return text, { words = words, tokens = tokens, dropped = dropped }
end
-- }}}

-- {{{ M.prompts(record, store, settings)
-- One record, all the way to the two sentences. Or nil and a reason.
function M.prompts(record, store, settings, options)
  local scene, why = grammar.scene(record, store, settings, options)
  if not scene then return nil, why end
  local positive, measured = M.positive(scene, settings)
  return {
    positive = positive,
    negative = REFUSALS,
    scene = scene,
    length = measured,
  }
end
-- }}}

-- {{{ main(argv)
local function main(argv)
  local options = project.arguments(argv)
  local settings = project.hello("025-the-words-the-machine-reads")
  local store = project.load("019-the-kanji-record").store()
  local xml = project.load("011-scan-xml")

  for _, character in ipairs(xml.characters(options.chars or "休語時川森")) do
    local record = store.records[character]
    if not record then error(character .. " is not in the joined set") end
    local made, why = M.prompts(record, store, settings)
    io.write("\n", character, "  ", table.concat(record.meanings, ", "), "\n")
    if not made then
      io.write("  no scene: ", why, "\n")
    else
      io.write("  ", made.positive, "\n")
      io.write(string.format("  [%d words, about %d tokens, %d clauses dropped]\n",
               made.length.words, made.length.tokens, made.length.dropped))
    end
  end
  io.write("\nrefused in every prompt:\n  ", REFUSALS, "\n")
  project.goodbye("025-the-words-the-machine-reads", { "prompts built" })
end
-- }}}

if arg and arg[0] and arg[0]:find("025%-the%-words%-the%-machine%-reads") then
  main(arg)
end

return M
