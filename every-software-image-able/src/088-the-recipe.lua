-- 088-the-recipe.lua
--
-- Two descriptions that do not name each other: a recipe saying what the
-- seed IS, and a board description saying what it RUNS ON. Issue 501.
--
-- For a general: one file says what goes on the chip, another says what
-- machine the chip is for, and neither mentions the other. Supporting a new
-- computer is then a new file and no code at all -- which is the whole
-- portability claim, and the only way to test it is to add one.
--
-- THE RECIPE NEVER NAMES A BOARD, AND THE BOARD NEVER NAMES A PART OF THE
-- SEED. This is checked rather than intended: a recipe that mentions a board
-- has quietly become a recipe for that board, and the next person to want a
-- different machine has to edit it rather than write beside it.
--
-- NOTHING SECRET AND NOTHING MACHINE-SPECIFIC. An image is copied onto every
-- card in a batch, so anything particular to one machine is particular to
-- all of them. The seed is generic by construction; everything individual
-- about a machine happens after it wakes.
--
-- The board descriptions already in src/015 through src/017 and src/030
-- through src/032 are this file's board half at an earlier stage: they were
-- written for the emulator harness before there was a builder to read them.
-- An emulated machine is a board, so they are the same kind of thing, and
-- this checks them the same way.

local M = {}

-- {{{ M.RECIPE_FIELDS -- what a recipe must say
M.RECIPE_FIELDS = {
  { name = "recipe_id",    why = "what this seed is called" },
  { name = "engines",      why = "which architectures it carries an engine for, "
                              .. "and at which vector level each" },
  { name = "model",        why = "which packed model, by name and by the hash "
                              .. "of its bytes. The model is the operator's "
                              .. "choice at build time, not this project's" },
  { name = "instruction",  why = "the text the machine wakes up holding" },
  { name = "patterns",     why = "the bundled build patterns, pinned" },
  { name = "descriptions", why = "the carried device descriptions, pinned" },
  { name = "randomness",   why = "how many bytes of carried randomness, and "
                              .. "the seed that produced them -- same recipe "
                              .. "and same seed gives the same machine" },
}
-- }}}

-- {{{ M.BOARD_FIELDS -- what a board description must say
M.BOARD_FIELDS = {
  { name = "board_id",     why = "what this machine is called" },
  { name = "arch",         why = "which instruction set it speaks" },
  { name = "console",      why = "which device carries bytes off the machine, "
                              .. "and where" },
  { name = "storage",      why = "which controllers to expect" },
  { name = "payload",      why = "HOW THE FIRMWARE FINDS SOMETHING TO START, "
                              .. "and WHERE IT LOOKS. Load-bearing rather than "
                              .. "incidental: nothing shared can detect a "
                              .. "processor and choose an engine, so the way "
                              .. "each architecture runs its own code is that "
                              .. "its firmware finds only its own payload in "
                              .. "the place its convention names" },
  { name = "verified_against", why = "where this description was transcribed "
                              .. "from. A transcription whose source is not "
                              .. "named cannot be re-checked when a board "
                              .. "revision lands" },
}
-- }}}

-- {{{ M.check_recipe(recipe)
function M.check_recipe(recipe)
  local missing = {}
  for _, field in ipairs(M.RECIPE_FIELDS) do
    if recipe[field.name] == nil then missing[#missing + 1] = field.name end
  end
  if #missing > 0 then
    return nil, "this recipe does not say: " .. table.concat(missing, ", ")
  end

  -- {{{ and it must not name a board
  -- Checked by looking, because the failure is quiet: a recipe that mentions
  -- one board still builds, and the next person wanting a different machine
  -- edits it instead of writing beside it.
  local said = {}
  local function walk(value, path)
    if type(value) == "string" then
      said[#said + 1] = { where = path, text = value }
    elseif type(value) == "table" then
      for key, inner in pairs(value) do
        walk(inner, path .. "." .. tostring(key))
      end
    end
  end
  walk(recipe, "recipe")

  for _, entry in ipairs(said) do
    local lowered = entry.text:lower()
    for _, word in ipairs({ "board", "qemu", "raspberry", "emulat" }) do
      if lowered:find(word, 1, true) then
        return nil, "the recipe mentions a machine at " .. entry.where
          .. " ('" .. entry.text .. "'). A recipe that names a board has "
          .. "become a recipe FOR that board, and supporting another means "
          .. "editing this rather than writing beside it."
      end
    end
  end
  -- }}}

  return true
end
-- }}}

-- {{{ M.check_board(board)
function M.check_board(board)
  local missing = {}
  for _, field in ipairs(M.BOARD_FIELDS) do
    if board[field.name] == nil then missing[#missing + 1] = field.name end
  end
  if #missing > 0 then
    return nil, "this board description does not say: "
      .. table.concat(missing, ", ")
  end

  -- {{{ where the firmware looks
  -- Some boot schemes carry the answer in the scheme itself: a BIOS always
  -- reads sector zero, and saying so again in the description would be a
  -- second copy of a fact that cannot vary. The schemes that DO vary must
  -- say, and that is the load-bearing part -- it is the field by which each
  -- architecture ends up running its own code.
  local ANSWERS_ITSELF = {
    ["boot-sector"] = "sector zero, which is where every BIOS looks",
  }
  if not ANSWERS_ITSELF[board.payload.kind]
     and not board.payload.boot_path and not board.payload.load_addr then
    return nil, "'" .. board.board_id .. "' boots by '"
      .. tostring(board.payload.kind) .. "' and does not say where its "
      .. "firmware looks for something to start. That is the field by which "
      .. "each architecture ends up running its own code, and a builder "
      .. "cannot lay the medium out without it."
  end
  -- }}}

  -- {{{ and it must not name a part of the seed
  local said = {}
  local function walk(value, path)
    if type(value) == "string" then
      said[#said + 1] = { where = path, text = value }
    elseif type(value) == "table" then
      for key, inner in pairs(value) do walk(inner, path .. "." .. tostring(key)) end
    end
  end
  walk(board, "board")

  for _, entry in ipairs(said) do
    local lowered = entry.text:lower()
    for _, word in ipairs({ "weights", "the model", "instruction text", "engine for" }) do
      if lowered:find(word, 1, true) then
        return nil, "the board description mentions a part of the seed at "
          .. entry.where .. " ('" .. entry.text .. "'). A board that names "
          .. "what runs on it stops being usable for a different seed."
      end
    end
  end
  -- }}}

  return true
end
-- }}}

-- {{{ M.manifest(recipe, board, components)
-- The honest account of what an image is. The image itself is a pile of
-- bytes; this is what those bytes were meant to be.
--
-- Ordered rather than gathered, because the identity below is computed from
-- it and two builds that listed the same things in a different order would
-- otherwise be different images.
function M.manifest(recipe, board, components)
  local where = board.payload.boot_path
  if not where and board.payload.load_addr then
    where = string.format("0x%x", board.payload.load_addr)
  end
  if not where then where = board.payload.kind end

  local lines = {
    "recipe: " .. recipe.recipe_id,
    "board: " .. board.board_id,
    "architecture: " .. board.arch,
    "firmware looks in: " .. where,
    "model: " .. recipe.model.name .. " " .. recipe.model.hash,
    "instruction: " .. recipe.instruction,
    "patterns: " .. recipe.patterns,
    "descriptions: " .. recipe.descriptions,
    "randomness: " .. recipe.randomness.bytes .. " bytes from seed "
      .. recipe.randomness.seed,
  }

  local engines = {}
  for _, engine in ipairs(recipe.engines) do
    engines[#engines + 1] = engine.arch .. "/" .. engine.level
  end
  table.sort(engines)
  lines[#lines + 1] = "engines: " .. table.concat(engines, " ")

  local named = {}
  for name, version in pairs(components or {}) do
    named[#named + 1] = name .. "=" .. version
  end
  table.sort(named)
  for _, entry in ipairs(named) do
    lines[#lines + 1] = "component: " .. entry
  end

  -- No timestamp and no build path. Those are the usual reason a build stops
  -- being reproducible, and they say nothing about what the image IS.
  return table.concat(lines, "\n") .. "\n"
end
-- }}}

-- {{{ M.identity(manifest)
-- The image's identity: a number computed from the manifest, so somebody
-- with the same recipe, the same board description and the same components
-- arrives at the same one.
--
-- This is the only kind of reproducibility the project has, and it stops
-- mattering the moment the machine starts growing -- which is the answer to
-- the fifth open question in docs/008 rather than a limitation.
function M.identity(manifest)
  -- A plain rolling hash. Not a cryptographic one: nothing here is
  -- defending against somebody constructing a collision on purpose, and
  -- claiming otherwise by using a stronger name would be the more dishonest
  -- choice. What is wanted is that different inputs give different numbers.
  local high, low = 0x811c, 0x9dc5
  for index = 1, #manifest do
    local byte = manifest:byte(index)
    low = low + byte
    high = (high + low) % 65536
    low = (low * 3 + byte * 7) % 65536
  end
  return string.format("%04x%04x", high, low)
end
-- }}}

return M
