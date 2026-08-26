-- 014-the-path-language.lua
--
-- Reads the little language each stroke is written in.
--
-- For a general: a stroke in the archive is a line of text like
--
--     M19.5,39.86c2.45,0.57,5.23,0.8,8.04,0.57C40.75,39.38,63,36.5,79.78,36.15
--
-- which says: start at one point, then bend through two curves. The letters are
-- instructions and the numbers are the points they bend through. This turns
-- that text into the curves it describes.
--
-- It is not a general reader for the format it belongs to. That format has
-- arcs, straight lines, quadratic curves and a dozen other instructions, and
-- this archive uses none of them -- every one of its eighty thousand strokes is
-- a move followed by cubic curves. Accepting instructions that will never
-- arrive would mean the day one did arrive, it would be handled by code nobody
-- had ever run. So anything else is an error that names the character it came
-- from.

local M = {}

-- {{{ SEPARATORS -- the characters that merely divide numbers
local SEPARATORS = { [" "] = true, [","] = true, ["\t"] = true,
                     ["\n"] = true, ["\r"] = true }
-- }}}

-- {{{ read_number(text, position)
-- One number, and where it ended.
--
-- Hand-written rather than a pattern because of how this format packs numbers
-- together. There is no separator required between them, so a minus sign can be
-- both the end of one number and the start of the next: `-1.5-2.3` is two
-- numbers, not one. So is `.5.5`, since a number may have only one decimal
-- point.
--
-- The rule that makes both work: a sign is only accepted as the very first
-- character, and a decimal point only if no decimal point has been seen. Every
-- other appearance of either ends the number where it stands.
local function read_number(text, position)
  local length = #text
  while position <= length and SEPARATORS[text:sub(position, position)] do
    position = position + 1
  end
  if position > length then return nil, position end

  local start = position
  local character = text:sub(position, position)
  if character == "-" or character == "+" then position = position + 1 end

  local any_digits = false
  while position <= length and text:sub(position, position):match("%d") do
    position = position + 1
    any_digits = true
  end
  if text:sub(position, position) == "." then
    position = position + 1
    while position <= length and text:sub(position, position):match("%d") do
      position = position + 1
      any_digits = true
    end
  end
  if not any_digits then return nil, start end

  -- An exponent, which this archive does not use anywhere. Read anyway: it
  -- costs one comparison per number and its absence is a fact about today's
  -- release rather than about the format.
  local exponent = text:sub(position, position)
  if exponent == "e" or exponent == "E" then
    local before = position
    position = position + 1
    local sign = text:sub(position, position)
    if sign == "-" or sign == "+" then position = position + 1 end
    local exponent_digits = false
    while position <= length and text:sub(position, position):match("%d") do
      position = position + 1
      exponent_digits = true
    end
    -- an `e` with no digits after it was not an exponent at all
    if not exponent_digits then position = before end
  end

  return tonumber(text:sub(start, position - 1)), position
end
-- }}}

-- {{{ M.parse(d, context)
-- One stroke's path text, as the curves it describes.
--
-- Returns { x, y, curves }, where x and y are where the brush starts and each
-- curve is { x1, y1, x2, y2, x, y } -- two control points and an endpoint, all
-- absolute. The point a curve starts from is wherever the previous one ended,
-- which is how the format itself works and saves storing it twice.
--
-- `context` is a phrase naming what is being parsed, used only in errors.
function M.parse(d, context)
  context = context or "a stroke"
  if type(d) ~= "string" or d == "" then
    error(context .. " has no path text")
  end

  local position = 1
  local length = #d
  local command = nil
  local x, y = 0, 0
  local start_x, start_y = nil, nil
  local curves = {}

  -- Where the previous curve's second control point was, mirrored through the
  -- current point. This is what a smooth curve uses for its first control
  -- point, and it is the one piece of state in this file that has to be
  -- maintained across instructions.
  local reflected_x, reflected_y = nil, nil

  -- {{{ want(count)
  -- The next several numbers, or an error saying what was missing.
  local function want(count)
    local values = {}
    for index = 1, count do
      local value
      value, position = read_number(d, position)
      if not value then
        error(context .. ": the '" .. tostring(command) .. "' instruction wants " ..
              count .. " numbers and only " .. (index - 1) .. " were there")
      end
      values[index] = value
    end
    return unpack(values)
  end
  -- }}}

  -- {{{ add_curve(x1, y1, x2, y2, ex, ey)
  -- One cubic curve, recorded, and the state it leaves behind.
  local function add_curve(x1, y1, x2, y2, ex, ey)
    curves[#curves + 1] = { x1, y1, x2, y2, ex, ey }
    -- the reflection of the second control point through the endpoint, ready
    -- for a smooth curve that might follow
    reflected_x, reflected_y = 2 * ex - x2, 2 * ey - y2
    x, y = ex, ey
  end
  -- }}}

  while position <= length do
    while position <= length and SEPARATORS[d:sub(position, position)] do
      position = position + 1
    end
    if position > length then break end

    local character = d:sub(position, position)
    if character:match("%a") then
      command = character
      position = position + 1
    elseif command == nil then
      error(context .. ": the path begins with a number rather than an instruction")
    elseif command == "M" or command == "m" then
      -- In this format, extra coordinate pairs after a move are straight lines.
      -- The archive has none, and inventing a handler for a case that never
      -- occurs means the day it does occur it is handled by code nobody has run.
      error(context .. ": a move instruction is followed by more than one point," ..
            "\n  which in this format means a straight line. No stroke in this" ..
            "\n  archive has ever had one, so this is new and should be looked at.")
    end

    if command == "M" or command == "m" then
      local nx, ny = want(2)
      -- A relative move as the very first instruction is defined to be
      -- absolute. It makes no numerical difference here, since the brush starts
      -- at the origin and adding to zero is the same as replacing it -- but the
      -- rule is the format's and the reason it does not matter is worth knowing
      -- rather than rediscovering.
      if command == "m" and start_x ~= nil then
        x, y = x + nx, y + ny
      else
        x, y = nx, ny
      end
      if start_x == nil then start_x, start_y = x, y end
      reflected_x, reflected_y = nil, nil

    elseif command == "C" or command == "c" then
      local x1, y1, x2, y2, ex, ey = want(6)
      if command == "c" then
        x1, y1 = x + x1, y + y1
        x2, y2 = x + x2, y + y2
        ex, ey = x + ex, y + ey
      end
      add_curve(x1, y1, x2, y2, ex, ey)

    elseif command == "S" or command == "s" then
      local x2, y2, ex, ey = want(4)
      if command == "s" then
        x2, y2 = x + x2, y + y2
        ex, ey = x + ex, y + ey
      end
      -- The smooth instruction leaves its first control point unwritten: it is
      -- the previous curve's second control point, mirrored through the current
      -- point, which is what makes the join smooth. Where there is no previous
      -- curve there is nothing to mirror, and the format says to use the current
      -- point itself -- which produces a curve that leaves in the direction of
      -- its own second control point.
      --
      -- Getting this wrong puts a kink at every smooth joint, and the character
      -- still looks like a character, which is why it is worth being explicit
      -- about.
      local x1 = reflected_x or x
      local y1 = reflected_y or y
      add_curve(x1, y1, x2, y2, ex, ey)

    else
      error(context .. ": the instruction '" .. tostring(command) ..
            "' is not one this archive has ever used." ..
            "\n  Only move and cubic curves appear in it, so either the release" ..
            "\n  changed or this is not the archive it claims to be.")
    end
  end

  if start_x == nil then
    error(context .. ": the path never says where to start")
  end
  if #curves == 0 then
    error(context .. ": the path moves somewhere and then draws nothing")
  end

  return { x = start_x, y = start_y, curves = curves }
end
-- }}}

return M
