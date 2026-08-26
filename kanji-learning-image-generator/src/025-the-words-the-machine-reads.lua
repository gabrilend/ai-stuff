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
-- The paintbrush rather than the grammar directly, so that an argument
-- somebody wrote is never written and then quietly ignored -- which would be
-- worse than having no arguments at all, because the picture would not change
-- and nothing would say why.
local grammar = project.load("024a-the-paintbrush")

local M = {}

-- {{{ REFUSALS -- what every prompt says it must not be
--
-- THIS IS WHERE THE PROJECT IS DEFENDED. The idea invites one specific failure:
-- a model satisfying "kanji" by *painting a kanji*. A brushed character on a
-- wall, a banner, a carved sign. Technically present, completely useless as a
-- learning image, and good enough to pass a careless glance -- so nobody
-- reviewing a set of six thousand would catch it.
--
-- A list rather than one string, so a style can lift an entry by name and leave
-- the rest standing (`412`). Four are marked as never liftable, and that mark
-- is the project: a style asking for those is asking for a picture *of* a
-- character rather than a picture that *is* one.
local REFUSALS = {
  { "text", forever = true },
  { "lettering", forever = true },
  { "calligraphy", forever = true },
  { "kanji", forever = true },

  { "letters" }, { "words" }, { "writing" }, { "brush strokes" },
  { "ink wash" }, { "chinese characters" }, { "japanese characters" },
  { "hanzi" }, { "signage" }, { "watermark" }, { "signature" }, { "logo" },
  { "border" }, { "frame" }, { "caption" }, { "subtitle" },

  { "illustration" }, { "cartoon" }, { "flat colour" }, { "poster" },
  { "diagram" },

  { "blurry" }, { "low contrast" }, { "washed out" }, { "deformed" },
}
-- }}}

-- {{{ STYLES -- what a picture may be asked to look like
--
-- Photographic is the default and is a style like any other, so nothing is
-- special-cased.
--
-- A style may lift refusals, one at a time and never wholesale, and each
-- lifting carries the reason it does not apply. The refusal against
-- illustration was argued precisely: an illustration has large flat regions of
-- one colour, and a flat region has no light and shade for a hidden shape to
-- live in. Good against what it was aimed at, and written as though it were an
-- argument against everything that is not a photograph.
local STYLES = {

  photographic = {
    tail = "photographic, natural light, shallow depth of field, fine texture",
    -- Where in the sentence the style sits. Last, for this one, because it is a
    -- qualifier on a scene rather than the point of it.
    place = 80,
    lifts = {},
    why = "the default: flat regions cannot hide a shape, so pictures are " ..
          "pushed towards photographs, which have light and shade everywhere",
  },

  wimmelbild = {
    tail = "(a Wimmelbild:1.3), a teeming seek-and-find picture crowded with " ..
           "hundreds of small distinct figures and objects in every corner, " ..
           "each with its own outline, richly detailed, painted",
    -- Near the front, because for this style the style *is* the point. Written
    -- last, as the photographic tail is, it was a qualifier the model had
    -- almost no room left to act on.
    place = 15,
    -- Lifted because a Wimmelbild is the *opposite* of flat: hundreds of small
    -- distinct things, each with edges and a shadow, which is more for a hidden
    -- shape to live in than a photograph offers rather than less. Diagram is
    -- not lifted, because a diagram really is flat and schematic.
    lifts = { "illustration", "cartoon", "flat colour", "poster" },
    why = "a teeming picture has no large flat regions -- it is small detail " ..
          "everywhere -- so the argument that sends this project towards " ..
          "photographs does not apply to it",
  },
}
-- }}}

-- {{{ M.styles()
function M.styles()
  local names = {}
  for name in pairs(STYLES) do names[#names + 1] = name end
  table.sort(names)
  return names
end
-- }}}

-- {{{ M.style(name)
-- One style, or an error naming the ones there are.
function M.style(name)
  name = name or "photographic"
  local found = STYLES[name]
  if not found then
    error("there is no style called '" .. tostring(name) .. "'.\n  there is: " ..
          table.concat(M.styles(), ", "))
  end
  return found, name
end
-- }}}

-- {{{ M.refusals(style_name)
-- The negative prompt, with whatever this style may lift removed.
function M.refusals(style_name)
  local style = M.style(style_name)
  local lifted = {}
  for _, term in ipairs(style.lifts or {}) do lifted[term] = true end

  local out = {}
  for _, entry in ipairs(REFUSALS) do
    local term = entry[1]
    if lifted[term] and entry.forever then
      -- Refused by name rather than ignored. A style wanting one of these is
      -- asking for a picture of a character instead of a picture that is one,
      -- and allowing it quietly is how the whole project stops working while
      -- every individual image still looks fine.
      error("the style '" .. tostring(style_name) .. "' asks to lift '" ..
            term .. "', and no style may.\n  Those four are what stop a model " ..
            "satisfying 'kanji' by painting one.")
    end
    if not lifted[term] then out[#out + 1] = term end
  end
  return table.concat(out, ", ")
end
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
function M.positive(scene, settings, style_name)
  -- Two orders, and they are not the same order. `rank` decides what gets
  -- dropped when the sentence is too long; `place` decides where a clause sits
  -- in the sentence that is finally written. Using one for both put the
  -- photographic terms -- which must never be dropped, so they rank high --
  -- into the middle of the sentence, between the setting and the light.
  local style = M.style(style_name or (settings.scene and settings.scene.style))
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
    -- A piece that is only in the picture because the character is written with
    -- it -- not because it means anything -- is worth a little less of the
    -- sentence than one that carries the meaning, even though both belong in
    -- the picture. It still outranks the palette and the light.
    local rank = subject_ranks[index] or 65
    if subject.for_the_sound then rank = rank - 25 end
    say(rank, 10 + index, phrase)
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

  say(80, style.place or 80, style.tail)

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
  options = options or {}
  local scene, why = grammar.scene(record, store, settings, options)
  if not scene then return nil, why end
  local chosen = options.style or (settings.scene and settings.scene.style)
                 or "photographic"
  local positive, measured = M.positive(scene, settings, chosen)
  return {
    positive = positive,
    negative = M.refusals(chosen),
    style = chosen,
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
    local made, why = M.prompts(record, store, settings,
                                { style = type(options.style) == "string"
                                          and options.style or nil })
    io.write("\n", character, "  ", table.concat(record.meanings, ", "), "\n")
    if not made then
      io.write("  no scene: ", why, "\n")
    else
      io.write("  ", made.positive, "\n")
      io.write(string.format("  [%d words, about %d tokens, %d clauses dropped]\n",
               made.length.words, made.length.tokens, made.length.dropped))
    end
  end
  local which = type(options.style) == "string" and options.style
                or (settings.scene and settings.scene.style) or "photographic"
  io.write("\nstyle: ", which, " -- ", (M.style(which).why), "\n")
  io.write("refused in every prompt:\n  ", M.refusals(which), "\n")
  project.goodbye("025-the-words-the-machine-reads", { "prompts built" })
end
-- }}}

if arg and arg[0] and arg[0]:find("025%-the%-words%-the%-machine%-reads") then
  main(arg)
end

return M
