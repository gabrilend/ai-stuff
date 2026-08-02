#!/usr/bin/env luajit
-- 028-show-picture.lua
--
-- Renders a screenshot as text, so what a machine drew can be checked without
-- leaving the terminal and without a viewer.
--
-- For a general: the emulated computers can be photographed while they run.
-- This turns one of those photographs into something you can read in a
-- terminal, so a machine's drawing can be confirmed on the same screen you
-- started it from.
--
-- Reads the plain binary PPM an emulator screendump produces: a short text
-- header giving width, height and the largest value a colour can take, then
-- three bytes per pixel.
--
-- usage:
--   luajit 028-show-picture.lua PICTURE [--region X,Y,W,H] [--width N]
--                               [--colour]

-- {{{ local function say(text)
local function say(text)
  io.write(text, "\n")
end
-- }}}

-- {{{ local function die(text)
local function die(text)
  io.stderr:write("028-show-picture: ", text, "\n")
  os.exit(1)
end
-- }}}

-- {{{ local function read_ppm(path)
local function read_ppm(path)
  local handle = io.open(path, "rb") or die("cannot open " .. path)
  local data = handle:read("*a")
  handle:close()

  if data:sub(1, 2) ~= "P6" then
    die("not a binary PPM (expected 'P6', found '" .. data:sub(1, 2):gsub("%c", "?") .. "')")
  end

  -- the header is whitespace-separated numbers, possibly with comment lines.
  -- Walking it by hand rather than with a pattern, because a comment can sit
  -- between any two fields and a single pattern would miss that.
  local at, fields = 3, {}
  while #fields < 3 do
    local char = data:sub(at, at)
    if char == "#" then
      at = data:find("\n", at, true) + 1
    elseif char:match("%s") then
      at = at + 1
    else
      local stop = at
      while data:sub(stop, stop):match("%d") do stop = stop + 1 end
      fields[#fields + 1] = tonumber(data:sub(at, stop - 1))
      at = stop
    end
  end
  at = at + 1  -- the single whitespace byte after the last field

  local width, height, largest = fields[1], fields[2], fields[3]
  if largest > 255 then die("this reader handles one byte per colour; that picture uses two") end

  return { width = width, height = height, pixels = data, start = at }
end
-- }}}

-- {{{ local function pixel_at(picture, x, y)
local function pixel_at(picture, x, y)
  if x < 0 or y < 0 or x >= picture.width or y >= picture.height then return 0, 0, 0 end
  local at = picture.start + (y * picture.width + x) * 3
  local r, g, b = picture.pixels:byte(at, at + 2)
  return r or 0, g or 0, b or 0
end
-- }}}

-- {{{ SHADES -- brightness, darkest first
-- Ten steps is enough to read letterforms and few enough to stay legible in a
-- terminal; more shades make text harder to read rather than easier.
local SHADES = { " ", ".", ":", "-", "=", "+", "*", "#", "%", "@" }
-- }}}

-- {{{ COLOUR_NAME -- which colour dominates a cell, for the summary
local function colour_name(r, g, b)
  local most = math.max(r, g, b)
  if most < 24 then return "dark" end
  if r == most and g == most and b == most then return "grey" end
  if g == most and g > r and g > b then return "green" end
  if r == most and r > g and r > b then return "red" end
  if b == most and b > r and b > g then return "blue" end
  if r == most and g == most then return "yellow" end
  return "mixed"
end
-- }}}

-- {{{ main
local path, region, out_width, want_colour = nil, nil, 96, false
local index = 1
while index <= #arg do
  local word = arg[index]
  if word == "--region" then
    index = index + 1
    local x, y, w, h = (arg[index] or ""):match("^(%d+),(%d+),(%d+),(%d+)$")
    if not x then die("--region wants X,Y,W,H") end
    region = { x = tonumber(x), y = tonumber(y), w = tonumber(w), h = tonumber(h) }
  elseif word == "--width" then
    index = index + 1
    out_width = tonumber(arg[index]) or die("--width wants a number")
  elseif word == "--colour" or word == "--color" then
    want_colour = true
  elseif word:sub(1, 2) == "--" then
    die("unknown option: " .. word)
  elseif not path then
    path = word
  else
    die("more than one picture named")
  end
  index = index + 1
end

if not path then die("no picture named; there is nothing to show") end

local picture = read_ppm(path)
region = region or { x = 0, y = 0, w = picture.width, h = picture.height }

say("")
say("  " .. path)
say("  " .. picture.width .. " x " .. picture.height
    .. ", showing " .. region.w .. " x " .. region.h .. " from ("
    .. region.x .. "," .. region.y .. ")")
say("")

-- Terminal cells are about twice as tall as they are wide, so vertical
-- sampling is coarser by the same factor. Without that a picture comes out
-- stretched and letters stop being recognisable.
local step_x = math.max(1, math.floor(region.w / out_width))
local step_y = step_x * 2

local lit_cells, colours = 0, {}

for y = region.y, region.y + region.h - 1, step_y do
  local row = {}
  for x = region.x, region.x + region.w - 1, step_x do
    -- average the block this cell stands for, rather than sampling one pixel:
    -- a single pixel misses thin strokes entirely, which is most of a letter.
    local r_sum, g_sum, b_sum, count = 0, 0, 0, 0
    for sample_y = y, math.min(y + step_y - 1, region.y + region.h - 1) do
      for sample_x = x, math.min(x + step_x - 1, region.x + region.w - 1) do
        local r, g, b = pixel_at(picture, sample_x, sample_y)
        r_sum, g_sum, b_sum, count = r_sum + r, g_sum + g, b_sum + b, count + 1
      end
    end
    local r, g, b = r_sum / count, g_sum / count, b_sum / count
    local brightness = (r * 0.299 + g * 0.587 + b * 0.114) / 255
    local shade = SHADES[math.min(#SHADES, math.floor(brightness * #SHADES) + 1)]
    row[#row + 1] = shade
    if brightness > 0.08 then
      lit_cells = lit_cells + 1
      local name = colour_name(r, g, b)
      colours[name] = (colours[name] or 0) + 1
    end
  end
  say("  " .. table.concat(row))
end

say("")
say("  " .. lit_cells .. " cells have something in them")
if want_colour or lit_cells > 0 then
  local named = {}
  for name, count in pairs(colours) do named[#named + 1] = name .. " " .. count end
  table.sort(named)
  if #named > 0 then say("  colours: " .. table.concat(named, ", ")) end
end
say("")
-- }}}
