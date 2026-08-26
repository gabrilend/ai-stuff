-- 024a-the-paintbrush.lua
--
-- The closed set of things a person may say about a picture, and the wall that
-- refuses everything else.
--
-- For a general: when a picture comes out wrong there has to be something to do
-- about it other than changing the rules that produced it, because changing the
-- rules changes every other character too. This is that something. A person
-- writes a better argument for one character and it wins.
--
--     -- input/arguments/時.lua
--     return {
--       world = "sky",
--       subjects = {
--         { "日", "the sun, low and huge" },
--         { "寺", "a temple with a bronze bell" },
--       },
--       note = "sun over temple. the temple is only there for the sound.",
--     }
--
-- WHY THE VOCABULARY IS CLOSED. Given a long document describing everything a
-- scene can hold, anybody writing quickly will reach for a neighbouring word
-- that does not exist -- confidently, and in good style. A short allowlist has
-- nowhere for the analogy to go. The refusing is the feature.
--
-- The language is the parser: an argument is Lua returning a table, so a syntax
-- error arrives with a line number for free and there is no parser here to be
-- wrong. This checks vocabulary, not syntax.
--
-- Numbered to sit beside `024`, whose work it overrides.
--
--   luajit src/024a-the-paintbrush.lua --contract
--   luajit src/024a-the-paintbrush.lua --check 時

local project = dofile((debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$")) ..
                       "/009-where-things-are.lua")
local grammar = project.load("024-the-scene-grammar")
local xml = project.load("011-scan-xml")

local M = {}

-- {{{ VERSION -- what vocabulary an argument was written against
--
-- Recorded on every picture made from an argument. Without it a rating means
-- nothing later: a vocabulary that has since changed produces scenes that
-- cannot be compared with new ones, and nothing would say so.
M.VERSION = "1"
-- }}}

-- {{{ WORDS -- every word an argument may speak
--
-- The whole contract, and it is short on purpose. Each row says what the word
-- means, what shape its value takes, and what happens when it is left out --
-- and a default written here is *vocabulary*, published, while a default that
-- existed only in code would be a fallback, and this project treats a fallback
-- as a warning and a warning as an error.
local WORDS = {
  { name = "world", kind = "world",
    says = "which of the seventeen worlds the picture is set in",
    absent = "the scene grammar works it out by weighing evidence" },

  { name = "reading", kind = "reading",
    says = "mnemonic -- every piece is a named thing, including the half " ..
           "chosen for its sound; or semantic -- that half becomes background",
    absent = "whatever input/settings.lua says" },

  { name = "polarity", kind = "polarity",
    says = "dark_ink for strokes darker than the scene, light_ink for lighter",
    absent = "the world decides" },

  { name = "subjects", kind = "subjects",
    says = "the pieces of this character that appear in the picture, in the " ..
           "order they should be named, each with what it looks like",
    absent = "the pieces are looked up in the lexicon" },

  { name = "strokes", kind = "strokes",
    says = "what a particular stroke is, by its number in writing order",
    absent = "the world's own vocabulary supplies one from the stroke's shape" },

  { name = "register", kind = "text",
    says = "which particular version of the world -- not 'a forest' but the " ..
           "one this is",
    absent = "the world's own" },

  { name = "light", kind = "text",
    says = "the light in the scene",
    absent = "the world's own" },

  { name = "palette", kind = "text",
    says = "the colours",
    absent = "the world's own" },

  { name = "note", kind = "text",
    says = "for whoever reads this file later. Never used for anything.",
    absent = "nothing" },
}

local BY_NAME = {}
for _, word in ipairs(WORDS) do BY_NAME[word.name] = word end
-- }}}

-- {{{ distance(a, b)
-- How many single-character edits turn one word into the other.
--
-- Used to say *did you mean* rather than only *no*. The vocabulary is small and
-- closed, so comparing against all of it costs nothing and one of them is
-- almost certainly what was meant.
local function distance(a, b)
  local first = xml.characters(a)
  local second = xml.characters(b)
  local previous = {}
  for index = 0, #second do previous[index] = index end
  for i = 1, #first do
    local current = { [0] = i }
    for j = 1, #second do
      local cost = (first[i] == second[j]) and 0 or 1
      local best = previous[j] + 1
      if current[j - 1] + 1 < best then best = current[j - 1] + 1 end
      if previous[j - 1] + cost < best then best = previous[j - 1] + cost end
      current[j] = best
    end
    previous = current
  end
  return previous[#second]
end
-- }}}

-- {{{ nearest(word, legal)
-- The legal word this one was probably meant to be, or nil.
local function nearest(word, legal)
  local length = #xml.characters(tostring(word))

  -- A one-character word has no shape to compare. Every other single character
  -- is exactly one edit away from it, so the "nearest" one is whichever
  -- happened to be first in the list -- which is how asking about a piece a
  -- character does not have produced "did you mean 時?", where 時 was the
  -- character being argued about. Say nothing instead; the caller lists what
  -- the character really is made of, which is the useful answer anyway.
  if length <= 1 then return nil end

  local best, best_distance = nil, math.huge
  for _, candidate in ipairs(legal) do
    if #xml.characters(tostring(candidate)) > 1 then
      local gap = distance(tostring(word), tostring(candidate))
      if gap < best_distance then best, best_distance = candidate, gap end
    end
  end

  -- Past about three fifths of the length, a suggestion stops being a
  -- suggestion and starts being noise. Three edits out of five is "skies" for
  -- "sky", which is obviously what was meant; a stricter bound refused it.
  if best_distance > math.max(3, length * 0.6) then return nil end
  return best
end
-- }}}

-- {{{ M.contract()
-- The vocabulary, as a document.
--
-- Generated from the table above rather than written beside it, because a
-- contract with two homes is a contract that will disagree with itself. The
-- documentation site renders this; there is no file to go stale.
function M.contract()
  local out = {}
  local function say(line) out[#out + 1] = line or "" end

  say("# The paintbrush")
  say()
  say("Everything an argument in `input/arguments/` may say, and nothing else.")
  say("Version " .. M.VERSION .. ".")
  say()
  say("An argument is a Lua file returning a table, named for the character it")
  say("argues about. It may say as little as it likes -- overriding the world")
  say("and nothing else is the commonest case, because the automatic scene was")
  say("fine except that it put the character in the wrong place.")
  say()
  say("| word | what it says | if it is left out |")
  say("|---|---|---|")
  for _, word in ipairs(WORDS) do
    say("| `" .. word.name .. "` | " .. word.says .. " | " .. word.absent .. " |")
  end
  say()
  say("## The values that are not free text")
  say()
  local worlds = {}
  for _, biome in ipairs(grammar.biomes()) do worlds[#worlds + 1] = biome.name end
  say("**`world`** is one of: " .. table.concat(worlds, ", ") .. ".")
  say()
  say("**`reading`** is `mnemonic` or `semantic`.")
  say()
  say("**`polarity`** is `dark_ink` or `light_ink`.")
  say()
  say("**`subjects`** is a list of pairs -- the piece, and what it looks like.")
  say("The piece must be one this character actually contains; the wall checks")
  say("that against the archive and will tell you which pieces it has.")
  say()
  say("**`strokes`** is a table from a stroke's number in writing order to what")
  say("that stroke is. The number must be one this character actually has.")
  say()
  say("## What the wall does")
  say()
  say("Refuses anything not in that table, by name, with the nearest legal word")
  say("beside it. Reports every error in one pass, because stopping at the")
  say("first turns fixing an argument into one guess per run. Never fills in a")
  say("malformed field -- an absent optional field takes the default published")
  say("above, and that is vocabulary; a default living only in code would be a")
  say("fallback, and here a fallback is a warning and a warning is an error.")
  return table.concat(out, "\n")
end
-- }}}

-- {{{ M.check(argument, record, store)
-- Every complaint the wall has, at once.
--
-- Returns a list. Empty means the argument is legal. Nothing is thrown, because
-- the caller wants all of them together and an error would deliver one.
function M.check(argument, record, store)
  local complaints = {}
  local function refuse(text) complaints[#complaints + 1] = text end

  if type(argument) ~= "table" then
    refuse("the file must return a table; it returned a " .. type(argument))
    return complaints
  end

  local legal_words = {}
  for _, word in ipairs(WORDS) do legal_words[#legal_words + 1] = word.name end

  for key in pairs(argument) do
    if not BY_NAME[key] then
      local guess = nearest(key, legal_words)
      refuse("there is no word '" .. tostring(key) .. "'" ..
             (guess and (". Did you mean '" .. guess .. "'?") or
              (". The words are: " .. table.concat(legal_words, ", "))))
    end
  end

  -- {{{ the world
  if argument.world ~= nil then
    local worlds = {}
    for _, biome in ipairs(grammar.biomes()) do worlds[#worlds + 1] = biome.name end
    local found = false
    for _, name in ipairs(worlds) do
      if name == argument.world then found = true break end
    end
    if not found then
      local guess = nearest(argument.world, worlds)
      refuse("world: '" .. tostring(argument.world) .. "' is not a world" ..
             (guess and (". Did you mean '" .. guess .. "'?") or
              (". They are: " .. table.concat(worlds, ", "))))
    end
  end
  -- }}}

  -- {{{ the two-valued words
  for _, pair in ipairs({ { "reading", { "mnemonic", "semantic" } },
                          { "polarity", { "dark_ink", "light_ink" } } }) do
    local key, allowed = pair[1], pair[2]
    if argument[key] ~= nil then
      local found = false
      for _, value in ipairs(allowed) do
        if value == argument[key] then found = true break end
      end
      if not found then
        local guess = nearest(argument[key], allowed)
        refuse(key .. ": '" .. tostring(argument[key]) .. "' is not one of " ..
               table.concat(allowed, " or ") ..
               (guess and (". Did you mean '" .. guess .. "'?") or "."))
      end
    end
  end
  -- }}}

  -- {{{ the subjects
  if argument.subjects ~= nil then
    if type(argument.subjects) ~= "table" then
      refuse("subjects: must be a list of { piece, what it looks like } pairs")
    else
      local has = {}
      local pieces = {}
      for _, component in ipairs(record.components) do
        if component.element and not has[component.element] then
          has[component.element] = true
          pieces[#pieces + 1] = component.element
        end
      end
      for index, subject in ipairs(argument.subjects) do
        if type(subject) ~= "table" or type(subject[1]) ~= "string"
           or type(subject[2]) ~= "string" then
          refuse("subjects[" .. index .. "]: must be { piece, " ..
                 "what it looks like }, both strings")
        elseif not has[subject[1]] then
          -- The mistake somebody will actually make. The archive knows which
          -- pieces this character has, so the wall can name them.
          local guess = nearest(subject[1], pieces)
          refuse("subjects[" .. index .. "]: " .. record.character ..
                 " has no piece '" .. subject[1] .. "'" ..
                 (guess and (". Did you mean '" .. guess .. "'?") or "") ..
                 "\n    it is made of: " .. table.concat(pieces, " "))
        end
      end
    end
  end
  -- }}}

  -- {{{ the strokes
  if argument.strokes ~= nil then
    if type(argument.strokes) ~= "table" then
      refuse("strokes: must be a table from a stroke's number to what it is")
    else
      for number, phrase in pairs(argument.strokes) do
        if type(number) ~= "number" or number < 1
           or number > #record.strokes or number % 1 ~= 0 then
          refuse("strokes[" .. tostring(number) .. "]: " .. record.character ..
                 " has strokes 1 to " .. #record.strokes)
        elseif type(phrase) ~= "string" then
          refuse("strokes[" .. tostring(number) .. "]: must be a string")
        end
      end
    end
  end
  -- }}}

  -- {{{ the free text
  for _, key in ipairs({ "register", "light", "palette", "note" }) do
    if argument[key] ~= nil and type(argument[key]) ~= "string" then
      refuse(key .. ": must be a string, not a " .. type(argument[key]))
    end
  end
  -- }}}

  return complaints
end
-- }}}

-- {{{ M.path_for(character)
function M.path_for(character)
  return project.path("input", "arguments", character .. ".lua")
end
-- }}}

-- {{{ M.load_for(record, store)
-- The argument somebody has written for this character, checked.
--
-- Returns the argument and its path, or nil when there is none. Errors, with
-- every complaint at once, when there is one and it is wrong -- because an
-- argument that was written and then silently ignored is worse than no argument
-- at all: the picture does not change and nothing says why.
function M.load_for(record, store)
  local file = M.path_for(record.character)
  if not project.exists(file) then return nil, nil end

  local chunk, why = loadfile(file)
  if not chunk then
    error("the argument for " .. record.character .. " will not load:\n  " ..
          tostring(why))
  end
  local argument = chunk()

  local complaints = M.check(argument, record, store)
  if #complaints > 0 then
    local lines = { "the argument for " .. record.character .. " (" .. file ..
                    ") has " .. #complaints ..
                    (#complaints == 1 and " problem:" or " problems:") }
    for _, complaint in ipairs(complaints) do
      lines[#lines + 1] = "  - " .. complaint
    end
    lines[#lines + 1] = "the words an argument may speak: " ..
                        "luajit src/024a-the-paintbrush.lua --contract"
    error(table.concat(lines, "\n"))
  end
  return argument, file
end
-- }}}

-- {{{ M.apply(scene, argument)
-- A scene, with a person's argument laid over it.
--
-- Only what the argument actually says is changed. Everything else stays as the
-- grammar worked it out, which is what makes overriding one thing a small act
-- rather than an obligation to describe the whole picture.
function M.apply(scene, argument, path)
  if not argument then return scene end

  scene.argued = true
  scene.argument_path = path
  scene.paintbrush_version = M.VERSION
  if argument.note then scene.argument_note = argument.note end

  if argument.world then
    for _, biome in ipairs(grammar.biomes()) do
      if biome.name == argument.world then
        scene.biome = biome
        scene.polarity = biome.polarity
        break
      end
    end
  end
  if argument.polarity then scene.polarity = argument.polarity end

  -- Replacing the world's own words rather than the world itself. Somebody who
  -- wants this forest at night says so here; somebody who wants a different
  -- world says `world`.
  if argument.register or argument.light or argument.palette then
    local changed = {}
    for key, value in pairs(scene.biome) do changed[key] = value end
    changed.register = argument.register or changed.register
    changed.light = argument.light or changed.light
    changed.palette = argument.palette or changed.palette
    scene.biome = changed
  end

  if argument.subjects then
    local replaced = {}
    for _, given in ipairs(argument.subjects) do
      -- Where the grammar already found this piece, its place in the frame is
      -- kept -- a person is saying what a piece looks like, not where it is,
      -- and where it is comes from the strokes.
      local place, sound = "somewhere", nil
      for _, found in ipairs(scene.all_subjects or scene.subjects) do
        if found.element == given[1] then
          place, sound = found.where, found.for_the_sound
        end
      end
      replaced[#replaced + 1] = {
        element = given[1], depicts = given[2], name = given[2],
        where = place, for_the_sound = sound, source = "argued",
      }
    end
    scene.subjects = replaced
  end

  if argument.strokes then
    for number, phrase in pairs(argument.strokes) do
      local role = scene.roles[number]
      if role then
        role.object = phrase
        role.phrase = phrase
        role.argued = true
        -- A stroke somebody troubled to describe is a stroke they want in the
        -- sentence, whether or not it was one of the heaviest.
        if not role.named then
          role.named = true
          scene.named[#scene.named + 1] = role
        end
      end
    end
  end

  return scene
end
-- }}}

-- {{{ M.scene(record, store, settings, options)
-- The scene for a character, argued with if somebody has argued with it.
--
-- Everything that wants a scene should come through here rather than through
-- `024` directly, or an argument would be written and quietly ignored.
function M.scene(record, store, settings, options)
  local scene, why = grammar.scene(record, store, settings, options)
  if not scene then return nil, why end
  local argument, path = M.load_for(record, store)
  return M.apply(scene, argument, path), nil
end
-- }}}

-- {{{ main(argv)
local function main(argv)
  local options = project.arguments(argv)
  local settings = project.hello("024a-the-paintbrush")

  if options.contract then
    io.write(M.contract(), "\n")
    project.goodbye("024a-the-paintbrush", { "the contract" })
    return
  end

  local store = project.load("019-the-kanji-record").store()
  local which = options.check
  if type(which) ~= "string" then
    io.write("luajit src/024a-the-paintbrush.lua --contract\n")
    io.write("luajit src/024a-the-paintbrush.lua --check 時\n")
    os.exit(1)
  end

  for _, character in ipairs(xml.characters(which)) do
    local record = store.records[character]
    if not record then error(character .. " is not in the joined set") end
    local file = M.path_for(character)
    if not project.exists(file) then
      io.write(character, ": no argument written. one would go in ", file, "\n")
    else
      local ok, why = pcall(M.load_for, record, store)
      if not ok then
        io.write(tostring(why), "\n")
      else
        io.write(character, ": the argument in ", file, " is legal\n")
      end
    end
  end
  project.goodbye("024a-the-paintbrush", { "checked" })
end
-- }}}

if arg and arg[0] and arg[0]:find("024a%-the%-paintbrush") then
  main(arg)
end

return M
