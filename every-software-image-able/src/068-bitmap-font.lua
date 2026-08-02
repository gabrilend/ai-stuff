-- 068-bitmap-font.lua
--
-- A font, as pictures. Each character is eight rows of eight, drawn with dots
-- and hashes, and turned into bytes at load time. Issue 202 needs one: text
-- output is a loop that copies these bits into a framebuffer, and there is
-- nothing else to it.
--
-- For a general: a computer with no operating system has no idea what a
-- letter looks like. This is where the shapes of the letters live -- small
-- enough to carry on the chip, and drawn in the source so a person can read
-- them without running anything.
--
-- WHY PICTURES RATHER THAN HEX. The same reason the exponential's constants
-- are computed rather than transcribed (043): a wrong hex byte in a font is
-- a letter that looks slightly odd forever and nobody suspects the right
-- thing. A wrong hash in a picture is visible while typing it. The bytes are
-- derived from the pictures at load, so there is no opportunity to
-- transcribe.
--
-- WHAT IS MISSING IS REFUSED, NOT GUESSED. A character with no glyph makes
-- the drawing refuse rather than print a blank -- a blank is a lie that says
-- the machine printed something it could not.

local M = {}

-- {{{ M.WIDTH, M.HEIGHT
M.WIDTH = 8
M.HEIGHT = 8
-- }}}

-- {{{ M.PICTURES -- the glyphs, drawn
--
-- The high bit of each row byte is the leftmost pixel, which is the order a
-- framebuffer wants them in.
M.PICTURES = {
  [" "] = "........,........,........,........,........,........,........,........",
  ["!"] = "...##...,...##...,...##...,...##...,...##...,........,...##...,........",
  ['"'] = "..##.##.,..##.##.,..##.##.,........,........,........,........,........",
  ["#"] = "..##.##.,..##.##.,.#######,..##.##.,.#######,..##.##.,..##.##.,........",
  ["'"] = "...##...,...##...,...##...,........,........,........,........,........",
  ["("] = "....##..,...##...,..##....,..##....,..##....,...##...,....##..,........",
  [")"] = "..##....,...##...,....##..,....##..,....##..,...##...,..##....,........",
  ["*"] = "........,..##.##.,...###..,.#######,...###..,..##.##.,........,........",
  ["+"] = "........,...##...,...##...,.#######,...##...,...##...,........,........",
  [","] = "........,........,........,........,........,...##...,...##...,..##....",
  ["-"] = "........,........,........,.#######,........,........,........,........",
  ["."] = "........,........,........,........,........,........,...##...,........",
  ["/"] = ".....##.,....##..,...##...,..##....,.##.....,##......,........,........",
  ["0"] = "..####..,.##..##.,.##..##.,.##..##.,.##..##.,.##..##.,..####..,........",
  ["1"] = "...##...,..###...,...##...,...##...,...##...,...##...,..####..,........",
  ["2"] = "..####..,.##..##.,.....##.,....##..,...##...,..##....,.#######,........",
  ["3"] = "..####..,.##..##.,.....##.,...###..,.....##.,.##..##.,..####..,........",
  ["4"] = "....###.,...####.,..##.##.,.##..##.,.#######,.....##.,.....##.,........",
  ["5"] = ".#######,.##.....,.######.,.....##.,.....##.,.##..##.,..####..,........",
  ["6"] = "...####.,..##....,.##.....,.######.,.##..##.,.##..##.,..####..,........",
  ["7"] = ".#######,.##..##.,....##..,...##...,..##....,..##....,..##....,........",
  ["8"] = "..####..,.##..##.,.##..##.,..####..,.##..##.,.##..##.,..####..,........",
  ["9"] = "..####..,.##..##.,.##..##.,..#####.,.....##.,....##..,..####..,........",
  [":"] = "........,...##...,...##...,........,........,...##...,...##...,........",
  [";"] = "........,...##...,...##...,........,........,...##...,...##...,..##....",
  ["<"] = "....##..,...##...,..##....,.##.....,..##....,...##...,....##..,........",
  ["="] = "........,........,.#######,........,.#######,........,........,........",
  [">"] = "..##....,...##...,....##..,.....##.,....##..,...##...,..##....,........",
  ["?"] = "..####..,.##..##.,.....##.,....##..,...##...,........,...##...,........",
  ["A"] = "...##...,..####..,.##..##.,.##..##.,.#######,.##..##.,.##..##.,........",
  ["B"] = ".######.,.##..##.,.##..##.,.######.,.##..##.,.##..##.,.######.,........",
  ["C"] = "..#####.,.##.....,.##.....,.##.....,.##.....,.##.....,..#####.,........",
  ["D"] = ".#####..,.##..##.,.##..##.,.##..##.,.##..##.,.##..##.,.#####..,........",
  ["E"] = ".#######,.##.....,.##.....,.#####..,.##.....,.##.....,.#######,........",
  ["F"] = ".#######,.##.....,.##.....,.#####..,.##.....,.##.....,.##.....,........",
  ["G"] = "..#####.,.##.....,.##.....,.##.####,.##..##.,.##..##.,..#####.,........",
  ["H"] = ".##..##.,.##..##.,.##..##.,.#######,.##..##.,.##..##.,.##..##.,........",
  ["I"] = "..####..,...##...,...##...,...##...,...##...,...##...,..####..,........",
  ["J"] = "....####,.....##.,.....##.,.....##.,.##..##.,.##..##.,..####..,........",
  ["K"] = ".##..##.,.##.##..,.####...,.###....,.####...,.##.##..,.##..##.,........",
  ["L"] = ".##.....,.##.....,.##.....,.##.....,.##.....,.##.....,.#######,........",
  ["M"] = ".##...##,.###.###,.#######,.##.#.##,.##...##,.##...##,.##...##,........",
  ["N"] = ".##..##.,.###.##.,.######.,.######.,.##.###.,.##..##.,.##..##.,........",
  ["O"] = "..####..,.##..##.,.##..##.,.##..##.,.##..##.,.##..##.,..####..,........",
  ["P"] = ".######.,.##..##.,.##..##.,.######.,.##.....,.##.....,.##.....,........",
  ["Q"] = "..####..,.##..##.,.##..##.,.##..##.,.##.###.,.##..##.,..#####.,........",
  ["R"] = ".######.,.##..##.,.##..##.,.######.,.####...,.##.##..,.##..##.,........",
  ["S"] = "..#####.,.##.....,.##.....,..####..,.....##.,.....##.,.#####..,........",
  ["T"] = ".#######,...##...,...##...,...##...,...##...,...##...,...##...,........",
  ["U"] = ".##..##.,.##..##.,.##..##.,.##..##.,.##..##.,.##..##.,..####..,........",
  ["V"] = ".##..##.,.##..##.,.##..##.,.##..##.,.##..##.,..####..,...##...,........",
  ["W"] = ".##...##,.##...##,.##...##,.##.#.##,.#######,.###.###,.##...##,........",
  ["X"] = ".##..##.,.##..##.,..####..,...##...,..####..,.##..##.,.##..##.,........",
  ["Y"] = ".##..##.,.##..##.,.##..##.,..####..,...##...,...##...,...##...,........",
  ["Z"] = ".#######,.....##.,....##..,...##...,..##....,.##.....,.#######,........",
  ["["] = "..####..,..##....,..##....,..##....,..##....,..##....,..####..,........",
  ["]"] = "..####..,....##..,....##..,....##..,....##..,....##..,..####..,........",
  ["_"] = "........,........,........,........,........,........,........,.#######",
  ["a"] = "........,........,..####..,.....##.,..#####.,.##..##.,..#####.,........",
  ["b"] = ".##.....,.##.....,.######.,.##..##.,.##..##.,.##..##.,.######.,........",
  ["c"] = "........,........,..#####.,.##.....,.##.....,.##.....,..#####.,........",
  ["d"] = ".....##.,.....##.,..#####.,.##..##.,.##..##.,.##..##.,..#####.,........",
  ["e"] = "........,........,..####..,.##..##.,.#######,.##.....,..#####.,........",
  ["f"] = "....###.,...##...,..#####.,...##...,...##...,...##...,...##...,........",
  ["g"] = "........,........,..#####.,.##..##.,..#####.,.....##.,..####..,........",
  ["h"] = ".##.....,.##.....,.######.,.##..##.,.##..##.,.##..##.,.##..##.,........",
  ["i"] = "...##...,........,..###...,...##...,...##...,...##...,..####..,........",
  ["j"] = ".....##.,........,....###.,.....##.,.....##.,.##..##.,..####..,........",
  ["k"] = ".##.....,.##.....,.##..##.,.##.##..,.####...,.##.##..,.##..##.,........",
  ["l"] = "..###...,...##...,...##...,...##...,...##...,...##...,..####..,........",
  ["m"] = "........,........,.##.#.##,.#######,.##.#.##,.##.#.##,.##.#.##,........",
  ["n"] = "........,........,.######.,.##..##.,.##..##.,.##..##.,.##..##.,........",
  ["o"] = "........,........,..####..,.##..##.,.##..##.,.##..##.,..####..,........",
  ["p"] = "........,........,.######.,.##..##.,.######.,.##.....,.##.....,........",
  ["q"] = "........,........,..#####.,.##..##.,..#####.,.....##.,.....##.,........",
  ["r"] = "........,........,.##.###.,.###....,.##.....,.##.....,.##.....,........",
  ["s"] = "........,........,..#####.,.##.....,..####..,.....##.,.#####..,........",
  ["t"] = "...##...,...##...,..#####.,...##...,...##...,...##...,....###.,........",
  ["u"] = "........,........,.##..##.,.##..##.,.##..##.,.##..##.,..#####.,........",
  ["v"] = "........,........,.##..##.,.##..##.,.##..##.,..####..,...##...,........",
  ["w"] = "........,........,.##.#.##,.##.#.##,.##.#.##,.#######,..##.##.,........",
  ["x"] = "........,........,.##..##.,..####..,...##...,..####..,.##..##.,........",
  ["y"] = "........,........,.##..##.,.##..##.,..#####.,.....##.,..####..,........",
  ["z"] = "........,........,.#######,....##..,...##...,..##....,.#######,........",
}
-- }}}

-- {{{ M.rows_of_picture(picture, called)
-- Any picture as eight bytes, high bit leftmost. `called` names it in a
-- refusal, since a picture on its own has nothing to be called.
function M.rows_of_picture(picture, called)
  local character = called or "a picture"

  -- Every row is checked rather than read loosely. A picture is typed by
  -- hand, and a row one character short shifts a letter sideways while
  -- still looking like a letter -- which is this file's own failure mode
  -- arriving in the place it was built to prevent. A stray apostrophe in
  -- the C was caught exactly this way while the font was being written.
  local out = {}
  for row in picture:gmatch("[^,]+") do
    if #row ~= M.WIDTH then
      error("068-bitmap-font: row " .. (#out + 1) .. " of '" .. character
        .. "' is " .. #row .. " wide rather than " .. M.WIDTH .. ": " .. row)
    end
    local byte = 0
    for column = 1, M.WIDTH do
      local mark = row:sub(column, column)
      if mark ~= "." and mark ~= "#" then
        error("068-bitmap-font: row " .. (#out + 1) .. " of '" .. character
          .. "' has '" .. mark .. "' in it, which is neither a dot nor a hash")
      end
      byte = byte * 2
      if mark == "#" then byte = byte + 1 end
    end
    out[#out + 1] = byte
  end
  if #out ~= M.HEIGHT then
    error("068-bitmap-font: '" .. character .. "' is drawn in " .. #out
      .. " rows rather than " .. M.HEIGHT)
  end
  return out
end
-- }}}

-- {{{ M.rows(character)
-- One glyph as eight bytes. Nil for a character with no picture -- the
-- caller decides whether that is a refusal or a box, and both callers here
-- do decide, rather than a blank being substituted quietly.
function M.rows(character)
  local picture = M.PICTURES[character]
  if not picture then return nil end
  return M.rows_of_picture(picture, character)
end
-- }}}

-- {{{ M.table_bytes(order)
-- The whole font as a flat run of bytes, in the order given -- what a
-- payload carries, and what the drawing code indexes into.
--
-- `order` is a list of the characters, and their positions in it are what
-- the drawing code looks up. Anything not in the font is refused here rather
-- than at drawing time, so a payload cannot be built carrying a hole.
function M.table_bytes(order)
  local out = {}
  for _, character in ipairs(order) do
    local rows = M.rows(character)
    if not rows then
      error("068-bitmap-font: nothing is drawn for '" .. character .. "'")
    end
    for _, byte in ipairs(rows) do out[#out + 1] = byte end
  end
  return out
end
-- }}}

-- {{{ M.MISSING -- what stands in for a character with no picture
--
-- A hollow box, and deliberately not a blank. A blank says the machine
-- printed a space; a box says it met something it has no shape for, which is
-- a different fact and the one worth seeing.
M.MISSING = "########,#......#,#......#,#......#,#......#,#......#,########,........"
-- }}}

-- {{{ M.FIRST, M.LAST -- the range a carried table covers
M.FIRST = 32
M.LAST = 126
-- }}}

-- {{{ M.contiguous_table()
-- Every code from FIRST to LAST, in order, with the box where no picture
-- exists -- so a payload finds a glyph by subtracting rather than searching.
--
-- CONTIGUOUS IS THE WHOLE POINT. A table holding only the characters that
-- happen to be drawn is dense, small, and wrong to index by subtraction: the
-- gaps shift every later letter. That produced a screen of real letterforms
-- spelling something else entirely, which is this file's own failure mode --
-- no error, just a plausible wrong answer -- arriving from the one direction
-- the pictures could not prevent.
function M.contiguous_table()
  local out, missing = {}, 0
  for code = M.FIRST, M.LAST do
    local character = string.char(code)
    local rows
    if M.PICTURES[character] then
      rows = M.rows(character)
    else
      rows = M.rows_of_picture(M.MISSING, character)
      missing = missing + 1
    end
    for _, byte in ipairs(rows) do out[#out + 1] = byte end
  end
  return out, missing
end
-- }}}

-- {{{ M.printable()
-- Every character the font actually has a picture for, in byte order. For
-- listing and checking; NOT for indexing -- see contiguous_table above.
function M.printable()
  local order = {}
  for byte = M.FIRST, M.LAST do
    local character = string.char(byte)
    if M.PICTURES[character] then order[#order + 1] = character end
  end
  return order
end
-- }}}

-- {{{ M.show(character)
-- A glyph printed back as a picture, from its bytes rather than its source.
-- The check that the derivation is right, and the reason the pictures can be
-- trusted: what this prints is what a framebuffer will show.
function M.show(character)
  local rows = M.rows(character)
  if not rows then return nil end
  local lines = {}
  for _, byte in ipairs(rows) do
    local line = {}
    for column = M.WIDTH - 1, 0, -1 do
      local bit = math.floor(byte / 2 ^ column) % 2
      line[#line + 1] = bit == 1 and "#" or "."
    end
    lines[#lines + 1] = table.concat(line)
  end
  return table.concat(lines, "\n")
end
-- }}}

return M
