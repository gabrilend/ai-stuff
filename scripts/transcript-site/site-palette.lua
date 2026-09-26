-- site-palette.lua
-- Copyright (C) 2026 gabrilend. SPDX-License-Identifier: AGPL-3.0-or-later
--
-- Turns a palette table into the transcript pages' colours.
--
-- Taken unchanged in its workings from double-diaper-dungeon's
-- src/049-site-palette.lua (at its commit 58f89bf). There it reads the game's
-- balance table; here it reads any file with the same shape - a table whose
-- `palette` field maps colour names to { value = { r, g, b } } with each
-- channel a number from zero to one. default-palette.lua beside this file is
-- the game's colours in that shape, so every project's pages look like that
-- game's unless it passes its own palette file.
--
-- The notes below are the original's, about the game.
--
-- WHY THIS EXISTS AT ALL. The palette is written down in exactly one place --
-- the balance table -- and three things read it: the battle log colours a
-- hero's name from it, the map colours her dot from it, and ./scripts/
-- check-colours measures it against a colourblind eye. A website that wrote
-- its own hex values would be a fourth copy that nobody checks and that drifts
-- the first time a colour is tuned.
--
-- So the site reads the same table. Change a colour once and the game, the
-- map, the checker and the website all move together.
--
-- WHY THE NUMBERS NEED CONVERTING. The game stores each colour as three
-- numbers from zero to one, because that is what the graphics library wants
-- when it draws. CSS wants the same colour as two hexadecimal digits per
-- channel, zero to 255. The conversion is a multiply and a round, and it lives
-- here rather than in a page so that every page gets the same answer.
--
-- WHAT THE SITE TAKES AND WHAT IT LEAVES. The five attribute colours, the
-- background and the plain-text grey are the site's whole palette. The map's
-- room greys, the door colours and the marker purple stay behind: they mean
-- something about a floor plan, and a page about conversations has no floor
-- plan on it. Taking them would invite somebody to use "locked door yellow"
-- for a heading, and then the two meanings of that colour drift apart.

local M = {}

-- The colours the website uses, and the CSS name each becomes. Names are the
-- game's own words, so a person reading the stylesheet and a person reading
-- the balance table are reading about the same thing.
--
-- A dispatch table rather than a chain of conditions, because the answer to
-- "which colours does the site want" is data and should look like data.
M.WANTED = {
  { from = "strength",     css = "--strength" },
  { from = "dexterity",    css = "--dexterity" },
  { from = "constitution", css = "--constitution" },
  { from = "intellect",    css = "--intellect" },
  { from = "spirit",       css = "--spirit" },
  { from = "background",   css = "--ground" },
  { from = "plain_text",   css = "--plain" },
}

-- {{{ local function channel()
-- One of red, green or blue, from the game's zero-to-one to CSS's two hex
-- digits.
--
-- Clamped before rounding. A value outside the range means somebody typed a
-- colour wrong in the balance table, and clamping turns that into a colour
-- that is merely wrong rather than into malformed CSS that takes a whole page
-- down -- but the checker is what catches the typo, not this.
local function channel(amount)
  if amount < 0 then amount = 0 end
  if amount > 1 then amount = 1 end
  return string.format("%02x", math.floor(amount * 255 + 0.5))
end
-- }}}

-- {{{ function M.to_hex()
-- One colour, from three numbers to a CSS hex string.
function M.to_hex(rgb)
  if type(rgb) ~= "table" or #rgb < 3 then
    error("a colour needs three numbers, red green and blue")
  end
  return "#" .. channel(rgb[1]) .. channel(rgb[2]) .. channel(rgb[3])
end
-- }}}

-- {{{ function M.from_balance_table()
-- Reads the palette out of a loaded balance table and returns name-to-hex.
--
-- A colour the site wants and the table does not have is an error rather than
-- a skipped entry. The page would otherwise render with a missing custom
-- property, which CSS treats as "use nothing" -- so text would go
-- black-on-black and look like a blank page rather than like a mistake.
function M.from_balance_table(balance)
  if type(balance) ~= "table" or type(balance.palette) ~= "table" then
    error("that is not a balance table: it has no palette in it")
  end

  local colours = {}
  for _, wanted in ipairs(M.WANTED) do
    local entry = balance.palette[wanted.from]
    if not entry then
      error("the balance table has no colour called " .. wanted.from)
    end
    colours[wanted.css] = M.to_hex(entry.value)
  end
  return colours
end
-- }}}

-- {{{ function M.custom_properties()
-- The colours as a CSS block, ready to sit at the top of a stylesheet.
--
-- Emitted as custom properties on :root rather than as literal values beside
-- each rule, so that a page says `color: var(--spirit)` and means it. A reader
-- of the stylesheet can then see which colour a thing is wearing without
-- looking anything up, and a person overriding the palette for their own eyes
-- has one block to change rather than forty rules.
function M.custom_properties(colours)
  local lines = { ":root {" }
  -- Walked in WANTED order rather than by pairs(), because a stylesheet that
  -- reorders itself between runs makes every rebuild look like a change.
  for _, wanted in ipairs(M.WANTED) do
    lines[#lines + 1] = string.format("  %s: %s;", wanted.css, colours[wanted.css])
  end
  lines[#lines + 1] = "}"
  return table.concat(lines, "\n")
end
-- }}}

-- {{{ function M.load()
-- The whole job: read the balance table off disk and hand back the CSS block.
--
-- The path is passed in rather than found, because a tool that guesses where
-- the project is works from one directory and nowhere else.
function M.load(balance_table_path)
  local chunk, complaint = loadfile(balance_table_path)
  if not chunk then
    error("cannot read the balance table at " .. balance_table_path .. ": " .. tostring(complaint))
  end
  local balance = chunk()
  local colours = M.from_balance_table(balance)
  return colours, M.custom_properties(colours)
end
-- }}}

return M
