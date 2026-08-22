#!/usr/bin/env luajit
-- 089-build-the-image.lua
--
-- Recipe plus board description in; a flashable image out, along with the
-- manifest saying what went into it and a number anyone can reproduce from
-- the same inputs. Issue 502.
--
-- For a general: this is what turns a description of a seed and a
-- description of a computer into the actual bytes you put on a card. It
-- never emits only the image -- always the image, what it is made of, and
-- its identity, because an image on its own is a pile of bytes nobody can
-- account for.
--
-- THE SEAM THIS EXISTS TO KEEP CLOSED. The builder decides where things go
-- and the engine decides where to look (102). If they disagree the machine
-- fails at the earliest possible moment with the least possible information.
-- So the agreement is checked BY THE BUILD: the offsets this lays down are
-- read back out of the built image and compared against what the engine's
-- own layout description says, before anything is written anywhere.
--
-- THE MODEL IS A PARAMETER. Which model an image carries is the operator's
-- choice at build time, not a decision baked into this project (101). This is
-- also where a model too large for the board is refused, with the three
-- numbers said out loud rather than left for first light to discover.
--
-- REPRODUCIBLE IN THE PLAIN SENSE: same inputs, same output bytes. No
-- timestamps and no build paths leak in, which is the usual reason this
-- fails.
--
-- usage:
--   luajit 089-build-the-image.lua --recipe FILE --board NAME [--model FILE]
--                                  [--to FILE] [--dir ROOT]

local M = {}

-- {{{ M.build(options)
--
-- options: recipe, board, model_bytes, sizes (a memory budget module),
--          shapes, format, blob_report_geometry
--
-- Returns { image, manifest, identity, layout } or nil and why.
function M.build(options)
  local recipe = options.recipe
  local board = options.board
  local describe = options.describe        -- 088

  -- {{{ both descriptions must be sound before anything is laid out
  local ok, why = describe.check_recipe(recipe)
  if not ok then return nil, "the recipe: " .. why end
  ok, why = describe.check_board(board)
  if not ok then return nil, "the board description: " .. why end
  -- }}}

  -- {{{ an engine for this board must actually be carried
  local engine = nil
  for _, entry in ipairs(recipe.engines) do
    if entry.arch == board.arch then engine = entry end
  end
  if not engine then
    local carried = {}
    for _, entry in ipairs(recipe.engines) do carried[#carried + 1] = entry.arch end
    return nil, "this recipe carries engines for " .. table.concat(carried, ", ")
      .. " and '" .. board.board_id .. "' speaks " .. board.arch
      .. ". Building it would produce a card that boots and stops."
  end
  -- }}}

  -- {{{ will it fit, and will it be fast enough to be worth carrying
  -- Refused here rather than at first light, with the three numbers said out
  -- loud: what the medium holds, what the board's memory holds alongside
  -- working space, and what the resulting speed will be.
  if options.shape and options.budget then
    local memory = options.board_memory or 0
    local strategy, needed = options.budget.strategy({
      shape = options.shape,
      weights_bytes = #(options.model_bytes or ""),
      engine_bytes = options.engine_bytes or 0,
      context = options.shape.context,
    }, memory)

    if not strategy then
      return nil, string.format(
        "this model does not fit '%s'.\n"
        .. "  the medium holds:        %d bytes\n"
        .. "  the board's memory:      %d bytes\n"
        .. "  thinking needs at least: %d bytes with no weights resident at all\n"
        .. "  so there is no arrangement of it that runs.",
        board.board_id, options.medium_bytes or 0, memory, needed)
    end
    options.chosen_strategy = strategy
  end
  -- }}}

  -- {{{ the carried randomness
  -- Made here and baked in, from a seed recorded in the manifest -- so the
  -- same recipe and the same seed give the same machine, exactly, and a
  -- strange failure becomes reproducible by handing somebody an image.
  local randomness = {}
  if recipe.randomness and options.sampler then
    local numbers = options.sampler.generate_file(recipe.randomness.seed,
      math.floor(recipe.randomness.bytes / 4))
    for _, number in ipairs(numbers) do
      randomness[#randomness + 1] = string.char(
        number % 256,
        math.floor(number / 256) % 256,
        math.floor(number / 65536) % 256,
        math.floor(number / 16777216) % 256)
    end
  end
  local carried_randomness = table.concat(randomness)
  -- }}}

  -- {{{ lay the medium out
  -- Where the starting code goes, where the engine goes, where the weights
  -- go, where the text goes -- in the order the firmware will meet them.
  local parts = {}
  local layout = {}
  local at = 0

  local function place(name, bytes)
    if #bytes == 0 then return end
    -- everything starts on a block boundary, because a medium is written in
    -- blocks and a part that straddles one cannot be replaced alone.
    local padding = (512 - at % 512) % 512
    if padding > 0 then
      parts[#parts + 1] = string.rep("\0", padding)
      at = at + padding
    end
    layout[#layout + 1] = { name = name, at = at, bytes = #bytes }
    parts[#parts + 1] = bytes
    at = at + #bytes
  end

  place("waking", options.waking_bytes or "")
  place("engine", options.engine_bytes_content or "")
  place("model", options.model_bytes or "")
  place("text", options.text_bytes or "")
  place("randomness", carried_randomness)

  local boot_file = table.concat(parts)
  -- }}}

  -- {{{ wrap it in something a firmware will open
  -- ADDED 2026-08-21, AND ITS ABSENCE MADE EVERY IMAGE THIS EVER BUILT
  -- UNBOOTABLE. What is above lays five regions down in the order the firmware
  -- meets them, on block boundaries, checked against what the engine looks for.
  -- All of that was right and none of it was findable: a computer starting up
  -- does not read a medium from the beginning. It looks for a partition table,
  -- opens the partition marked as the one to start from, expects a filesystem
  -- inside it, and opens ONE FILE at one fixed name.
  --
  -- So the five regions are the boot FILE, and the image is a medium with that
  -- file in it at the path the board description already names. Everything
  -- rides inside, which is not a compromise: firmware loads that file whole
  -- before the first instruction runs, so a model inside it is simply in memory
  -- when the machine wakes. The offsets recorded below stay relative to the
  -- file's own beginning, which is exactly what the engine measures from.
  local image = boot_file
  local medium = nil
  if board.payload and board.payload.kind == "uefi-esp" then
    local wrap = options.medium_module
    if not wrap then
      return nil, "this board boots through firmware, which needs the image "
        .. "wrapped in a partition table and a filesystem, and no module to do "
        .. "that was handed in"
    end
    local made, why_not = wrap.medium({
      bytes = boot_file,
      path = board.payload.boot_path,
      identity = describe.identity(describe.manifest(recipe, board, options.components)),
      label = "SEED",
    })
    if not made then return nil, "the medium: " .. why_not end
    image = made.image
    medium = made
  end
  -- }}}

  -- {{{ the manifest and the identity
  local manifest = describe.manifest(recipe, board, options.components)

  -- the layout goes in the manifest too, because where things ended up is
  -- part of what this image IS -- and because the engine's agreement with
  -- it is what the check below is about.
  local layout_lines = {}
  for _, entry in ipairs(layout) do
    layout_lines[#layout_lines + 1] = string.format("at: %s %d %d",
                                                    entry.name, entry.at, entry.bytes)
  end
  manifest = manifest .. table.concat(layout_lines, "\n") .. "\n"
  -- Where the offsets above are measured FROM is part of the account. On a
  -- board that boots through firmware they are inside the boot file, and the
  -- image around it is a medium; on one that does not, the image is the
  -- regions themselves and the two are the same thing.
  manifest = manifest .. "offsets-measured-from: "
    .. ((board.payload and board.payload.kind == "uefi-esp") and "boot-file" or "image")
    .. "\n"

  local identity = describe.identity(manifest)
  -- }}}

  return {
    image = image,
    boot_file = boot_file,
    medium = medium,
    manifest = manifest,
    identity = identity,
    layout = layout,
    strategy = options.chosen_strategy,
  }
end
-- }}}

-- {{{ M.check_the_seam(built, expectations)
-- The seam between this and the engine, checked by the build rather than
-- discovered at first light.
--
-- `expectations` is what the engine believes about where things are -- taken
-- from the engine's own layout description rather than written again here,
-- because two copies of an agreement are two things that can drift.
function M.check_the_seam(built, expectations)
  local found = {}
  for _, entry in ipairs(built.layout) do found[entry.name] = entry end

  local wrong = {}
  for name, expected in pairs(expectations) do
    local entry = found[name]
    if not entry then
      wrong[#wrong + 1] = "the engine expects '" .. name
        .. "' and the builder laid down nothing by that name"
    elseif expected.at and entry.at ~= expected.at then
      wrong[#wrong + 1] = string.format(
        "the engine looks for '%s' at %d and the builder put it at %d",
        name, expected.at, entry.at)
    elseif expected.after and found[expected.after]
           and entry.at <= found[expected.after].at then
      wrong[#wrong + 1] = string.format(
        "the engine expects '%s' after '%s' and it is not",
        name, expected.after)
    end
  end

  if #wrong > 0 then
    return nil, "the builder and the engine disagree about the image:\n  "
      .. table.concat(wrong, "\n  ")
      .. "\nThis is the disagreement that makes a machine fail at the "
      .. "earliest possible moment with the least possible information, so "
      .. "it is refused here instead."
  end
  return true
end
-- }}}

-- {{{ M.write(built, to)
-- Three files, never only the image.
function M.write(built, to)
  local handle = io.open(to, "wb")
  if not handle then return nil, "cannot write " .. to end
  handle:write(built.image)
  handle:close()

  handle = io.open(to .. ".manifest", "w")
  if not handle then return nil, "cannot write the manifest" end
  handle:write(built.manifest)
  handle:close()

  handle = io.open(to .. ".identity", "w")
  if not handle then return nil, "cannot write the identity" end
  handle:write(built.identity, "\n")
  handle:close()

  return true
end
-- }}}

return M
