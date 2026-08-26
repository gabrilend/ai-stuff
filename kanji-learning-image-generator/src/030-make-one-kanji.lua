-- 030-make-one-kanji.lua
--
-- Everything one character needs, in one folder.
--
-- For a general: this is the unit of work. Give it a character and it leaves
-- behind a folder holding the grey picture that hides the character, the
-- stroke-order arrows, the recipe in both the shapes the picture program reads,
-- and a plain description of every decision that went into them.
--
-- `031` runs this many times and does nothing else interesting. Everything that
-- decides what a picture is happens here.
--
--   luajit src/030-make-one-kanji.lua --chars 休 [--out DIR]

local project = dofile((debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$")) ..
                       "/009-where-things-are.lua")
local canvas = project.load("016-the-grey-canvas")
local png = project.load("017-write-a-picture")
local json = project.load("018-write-the-numbers")
local shape = project.load("021-the-shape-of-a-stroke")
local field_of = project.load("022-the-structure-field")
local words = project.load("025-the-words-the-machine-reads")
local arrows_of = project.load("026-arrows-that-teach-the-order")
local workflow = project.load("029-the-workflow-for-one-kanji")

local M = {}

-- {{{ M.folder_for(record, out_dir)
-- Where one character's work goes.
--
-- Named by number as well as by character, so the folders sort in a stable
-- order and so a filesystem that dislikes the character still has a name it can
-- keep.
function M.folder_for(record, out_dir)
  return string.format("%s/%05X-%s", out_dir, record.codepoint, record.character)
end
-- }}}

-- {{{ M.make(record, store, settings, options)
-- One character, all the way. Returns what was written, or nil and a reason.
function M.make(record, store, settings, options)
  options = options or {}
  local out_dir = options.out or project.scratch("sets/one")

  local measured = shape.measure_record(record)
  local built, why = words.prompts(record, store, settings,
                                   { measured = measured })
  if not built then return nil, why end
  local scene = built.scene

  local folder = M.folder_for(record, out_dir)
  project.ensure_directory(folder)

  -- The picture program names its inputs by filename, not by path -- it looks
  -- inside its own input folder. So the workflow carries a name, the report
  -- says where the files have to be put, and getting this backwards produces a
  -- workflow that is correct and cannot find its own pictures.
  local field_name = string.format("kanji/%05X-field.png", record.codepoint)
  local arrows_name = string.format("kanji/%05X-arrows.png", record.codepoint)

  local surface, field_made = field_of.build(record, settings,
                                { measured = measured, polarity = scene.polarity })
  local field_bytes = png.write_grey(folder .. "/field.png", surface, canvas)

  local small = field_of.thumbnail(surface, settings)
  png.write_grey(folder .. "/field-thumb.png", small, canvas)

  local sheets, arrows_made = arrows_of.build(record, settings,
                                              { measured = measured })
  local arrow_bytes = arrows_of.write(folder .. "/arrows.png", sheets)

  local graph = workflow.build(record, {
    positive = built.positive,
    negative = built.negative,
    field_name = field_name,
    arrows_name = arrows_name,
  }, settings)

  project.write_file(folder .. "/workflow.api.json", json.encode(graph:api()))
  project.write_file(folder .. "/workflow.ui.json", json.encode(graph:ui()))

  -- The card is what makes a generated set inspectable without opening a
  -- workflow, and it is what the gallery in `304` reads. Every decision, in
  -- plain view: which world and why, which pieces became subjects, which were
  -- demoted for being there only for their sound, what object each named stroke
  -- is carrying. When a picture comes out wrong, the wrongness is visible here
  -- before anybody generates anything.
  local card = json.object(
    "character", record.character,
    "codepoint", record.codepoint,
    "meanings", record.meanings,
    "readings_on", record.readings_on,
    "readings_kun", record.readings_kun,
    "grade", record.grade,
    "jlpt", record.jlpt,
    "frequency", record.frequency,
    "strokes", #record.strokes)

  card.world = json.object(
    "name", scene.biome.name,
    "register", scene.biome.register,
    "light", scene.biome.light,
    "polarity", scene.polarity,
    "score", scene.score,
    "runner_up", scene.runners_up[1] and scene.runners_up[1].name or nil,
    "runner_up_score", scene.runners_up[1] and scene.runners_up[1].score or nil,
    "sense", scene.register_note)

  local subjects = {}
  for _, subject in ipairs(scene.subjects) do
    subjects[#subjects + 1] = json.object(
      "element", subject.element, "depicts", subject.depicts,
      "where", subject.where, "from", subject.source)
  end
  card.subjects = subjects

  local ground = {}
  for _, one in ipairs(scene.landscape) do
    ground[#ground + 1] = json.object(
      "element", one.element, "becomes", one.terrain, "where", one.where,
      "marked_in_the_archive", one.marked)
  end
  card.sound_half = ground
  card.no_picture_for = scene.unglossed

  local strokes = {}
  for _, role in ipairs(scene.roles) do
    strokes[#strokes + 1] = json.object(
      "order", role.index, "shape", role.key, "direction", role.direction,
      "size", role.size, "where", role.place,
      "carries", role.object, "named_in_the_prompt", role.named or false)
  end
  card.strokes_and_what_they_carry = strokes

  card.prompt = json.object("positive", built.positive,
                            "negative", built.negative,
                            "words", built.length.words,
                            "about_tokens", built.length.tokens,
                            "clauses_dropped", built.length.dropped)

  card.field = json.object(
    "file", "field.png", "thumbnail", "field-thumb.png",
    "resolution", field_made.resolution, "blur_radius", field_made.blur_radius,
    "polarity", field_made.polarity, "bytes", field_bytes,
    "named_in_the_workflow", field_name)

  card.arrows = json.object(
    "file", "arrows.png", "count", arrows_made.arrows,
    "shortened_for_room", arrows_made.crowded, "bytes", arrow_bytes,
    "named_in_the_workflow", arrows_name)

  card.seed = workflow.seed_for(record)

  project.write_file(folder .. "/card.json", json.encode(card))

  return {
    folder = folder,
    character = record.character,
    world = scene.biome.name,
    bytes = field_bytes + arrow_bytes,
    unglossed = scene.unglossed,
    crowded = arrows_made.crowded,
  }
end
-- }}}

-- {{{ main(argv)
local function main(argv)
  local options = project.arguments(argv)
  local settings = project.hello("030-make-one-kanji")
  local store = project.load("019-the-kanji-record").store()
  local xml = project.load("011-scan-xml")

  local out_dir = options.out or project.scratch("sets/one")
  local said = {}
  for _, character in ipairs(xml.characters(options.chars or "休")) do
    local record = store.records[character]
    if not record then error(character .. " is not in the joined set") end
    local started = os.clock()
    local done, why = M.make(record, store, settings, { out = out_dir })
    if not done then
      io.write(character, ": ", why, "\n")
      said[#said + 1] = character .. " could not be made"
    else
      local line = string.format("%s  %s  %d bytes  %.2fs  ->  %s",
        character, done.world, done.bytes, os.clock() - started, done.folder)
      io.write(line, "\n")
      said[#said + 1] = line
    end
  end

  io.write("\nthis workflow assumes, and cannot check:\n")
  for _, note in ipairs(workflow.assumptions(settings)) do
    io.write("  - ", note, "\n")
  end
  project.goodbye("030-make-one-kanji", said)
end
-- }}}

if arg and arg[0] and arg[0]:find("030%-make%-one%-kanji") then
  main(arg)
end

return M
