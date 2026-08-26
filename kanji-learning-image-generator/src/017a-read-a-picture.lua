-- 017a-read-a-picture.lua
--
-- Reads a PNG somebody else wrote.
--
-- For a general: `017` writes pictures and this reads them, and until now
-- nothing here needed to read one -- every picture this project made, it made
-- from numbers it already had. That changes the moment a diffusion model hands
-- back a finished image and something has to look at it and say whether the
-- character is in there.
--
-- So this is a decompressor, which is the compressor in `017` run backwards and
-- then some: that one only ever emits the standard code table, and a picture
-- from anywhere else will use a table built for its own contents and written
-- into the file ahead of the data. Both are handled here.
--
-- Numbered to sit beside `017`, which it is the other half of.
--
-- It also gives the two of them something they did not have: a way to check
-- each other. A round trip through one misunderstanding twice proves nothing --
-- but this was written from the format description, to read what an outside
-- program produces, so agreement between them is worth something.

local bit = require("bit")
local band, bor, lshift, rshift = bit.band, bit.bor, bit.lshift, bit.rshift

local M = {}

-- {{{ bit_reader(text, position)
-- Bits out of a byte string, lowest first -- the order this format packs them.
local function bit_reader(text, position)
  local self = { text = text, at = position, held = 0, count = 0 }

  -- {{{ self.take(width)
  -- A plain number, lowest bit first.
  function self.take(width)
    while self.count < width do
      local byte = self.text:byte(self.at) or 0
      self.at = self.at + 1
      self.held = self.held + byte * (2 ^ self.count)
      self.count = self.count + 8
    end
    local value = self.held % (2 ^ width)
    self.held = math.floor(self.held / (2 ^ width))
    self.count = self.count - width
    return value
  end
  -- }}}

  -- {{{ self.align()
  -- Forget the rest of the current byte. Stored blocks begin on a boundary.
  function self.align()
    self.held, self.count = 0, 0
  end
  -- }}}

  return self
end
-- }}}

-- {{{ huffman(lengths)
-- A code table, from how many bits each symbol is given.
--
-- The format never writes the codes themselves -- only how long each one is --
-- because from the lengths alone there is exactly one assignment that works,
-- provided everyone builds it the same way: shortest codes first, and within a
-- length, in symbol order. This builds that assignment.
--
-- Decoding walks one bit at a time and asks whether the code so far is one of
-- the codes of that length. Slower than a lookup table and much easier to be
-- sure of, and this reads one picture at a time rather than millions.
local function huffman(lengths)
  local counts = {}
  local longest = 0
  for _, length in ipairs(lengths) do
    if length > 0 then
      counts[length] = (counts[length] or 0) + 1
      if length > longest then longest = length end
    end
  end

  local next_code = {}
  local code = 0
  for length = 1, longest do
    code = (code + (counts[length - 1] or 0)) * 2
    next_code[length] = code
  end

  local by_code = {}
  for symbol = 1, #lengths do
    local length = lengths[symbol]
    if length > 0 then
      by_code[length] = by_code[length] or {}
      by_code[length][next_code[length]] = symbol - 1
      next_code[length] = next_code[length] + 1
    end
  end

  return { by_code = by_code, longest = longest }
end
-- }}}

-- {{{ decode(reader, table)
-- One symbol.
--
-- Codes are stored highest bit first while everything else in the stream is
-- lowest bit first. Both are true at once, and mixing them up produces a stream
-- that decodes to something for a while and then falls apart.
local function decode(reader, tree)
  local code = 0
  for length = 1, tree.longest do
    code = code * 2 + reader.take(1)
    local row = tree.by_code[length]
    if row then
      local symbol = row[code]
      if symbol then return symbol end
    end
  end
  error("a code in this picture is not in its own code table")
end
-- }}}

-- {{{ LENGTH_BASE, LENGTH_EXTRA, DISTANCE_BASE, DISTANCE_EXTRA, ORDER
local LENGTH_BASE = { 3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31,
  35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258 }
local LENGTH_EXTRA = { 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3,
  3, 4, 4, 4, 4, 5, 5, 5, 5, 0 }
local DISTANCE_BASE = { 1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129,
  193, 257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289,
  16385, 24577 }
local DISTANCE_EXTRA = { 0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7,
  8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13 }
-- the order the code-length code lengths are written in, which is not one to
-- nineteen -- it is the order in which they are most often zero, so the tail
-- can be left out
local ORDER = { 16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15 }
-- }}}

-- {{{ FIXED -- the standard code table, built once
local FIXED_LITERAL, FIXED_DISTANCE
do
  local lengths = {}
  for symbol = 0, 143 do lengths[symbol + 1] = 8 end
  for symbol = 144, 255 do lengths[symbol + 1] = 9 end
  for symbol = 256, 279 do lengths[symbol + 1] = 7 end
  for symbol = 280, 287 do lengths[symbol + 1] = 8 end
  FIXED_LITERAL = huffman(lengths)
  local distances = {}
  for symbol = 1, 30 do distances[symbol] = 5 end
  FIXED_DISTANCE = huffman(distances)
end
-- }}}

-- {{{ M.inflate(text, from)
-- A compressed stream, back to the bytes that went into it.
function M.inflate(text, from)
  local reader = bit_reader(text, from or 3)   -- past the two header bytes
  local out = {}
  local size = 0

  -- {{{ push(byte)
  local function push(byte)
    size = size + 1
    out[size] = byte
  end
  -- }}}

  while true do
    local final = reader.take(1)
    local kind = reader.take(2)

    if kind == 0 then
      -- not compressed at all: a length, its complement, then the bytes
      reader.align()
      local low = text:byte(reader.at) or 0
      local high = text:byte(reader.at + 1) or 0
      local length = low + high * 256
      reader.at = reader.at + 4
      for index = 0, length - 1 do
        push(text:byte(reader.at + index) or 0)
      end
      reader.at = reader.at + length

    else
      local literal, distance
      if kind == 1 then
        literal, distance = FIXED_LITERAL, FIXED_DISTANCE
      elseif kind == 2 then
        -- A table built for this picture's own contents, written into the file
        -- ahead of the data -- and itself compressed, with a third table
        -- describing how long the codes in the second one are.
        local literals = reader.take(5) + 257
        local distances = reader.take(5) + 1
        local code_lengths = reader.take(4) + 4

        local order_lengths = {}
        for index = 1, 19 do order_lengths[index] = 0 end
        for index = 1, code_lengths do
          order_lengths[ORDER[index] + 1] = reader.take(3)
        end
        local code_tree = huffman(order_lengths)

        local lengths = {}
        local index = 1
        while index <= literals + distances do
          local symbol = decode(reader, code_tree)
          if symbol < 16 then
            lengths[index] = symbol
            index = index + 1
          elseif symbol == 16 then
            -- repeat the previous length, three to six times
            local repeats = reader.take(2) + 3
            local previous = lengths[index - 1]
            if not previous then
              error("this picture repeats a code length before there is one")
            end
            for _ = 1, repeats do lengths[index] = previous index = index + 1 end
          elseif symbol == 17 then
            local repeats = reader.take(3) + 3
            for _ = 1, repeats do lengths[index] = 0 index = index + 1 end
          else
            local repeats = reader.take(7) + 11
            for _ = 1, repeats do lengths[index] = 0 index = index + 1 end
          end
        end

        local literal_lengths, distance_lengths = {}, {}
        for at = 1, literals do literal_lengths[at] = lengths[at] or 0 end
        for at = 1, distances do
          distance_lengths[at] = lengths[literals + at] or 0
        end
        literal = huffman(literal_lengths)
        distance = huffman(distance_lengths)
      else
        error("this picture uses a kind of block the format does not define")
      end

      while true do
        local symbol = decode(reader, literal)
        if symbol == 256 then break end
        if symbol < 256 then
          push(symbol)
        else
          local which = symbol - 256
          local length = LENGTH_BASE[which] +
            (LENGTH_EXTRA[which] > 0 and reader.take(LENGTH_EXTRA[which]) or 0)
          local code = decode(reader, distance) + 1
          local back = DISTANCE_BASE[code] +
            (DISTANCE_EXTRA[code] > 0 and reader.take(DISTANCE_EXTRA[code]) or 0)
          -- A repeat may reach into itself -- copying two bytes forty times is
          -- how a long run is written -- so this copies one byte at a time
          -- rather than taking a slice.
          local start = size - back
          if start < 0 then
            error("this picture points back further than it has written")
          end
          for step = 0, length - 1 do
            push(out[start + step + 1])
          end
        end
      end
    end

    if final == 1 then break end
  end

  return out, size
end
-- }}}

-- {{{ unfilter(rows, width, height, channels)
-- The row transformations undone.
--
-- Every row is prefixed by a byte saying how its bytes were transformed, and
-- the transformations are differences against neighbours. `017` explains why
-- they exist; this is the same five, run backwards.
local function unfilter(bytes, width, height, channels)
  local stride = width * channels
  local out = {}
  local previous = {}
  for index = 1, stride do previous[index] = 0 end

  local at = 1
  for _ = 1, height do
    local filter = bytes[at]
    at = at + 1
    local row = {}
    for index = 1, stride do
      local value = bytes[at + index - 1] or 0
      local left = index > channels and row[index - channels] or 0
      local up = previous[index]
      local upleft = index > channels and previous[index - channels] or 0
      if filter == 1 then value = (value + left) % 256
      elseif filter == 2 then value = (value + up) % 256
      elseif filter == 3 then value = (value + math.floor((left + up) / 2)) % 256
      elseif filter == 4 then
        local estimate = left + up - upleft
        local from_left = math.abs(estimate - left)
        local from_up = math.abs(estimate - up)
        local from_upleft = math.abs(estimate - upleft)
        local guess
        if from_left <= from_up and from_left <= from_upleft then guess = left
        elseif from_up <= from_upleft then guess = up
        else guess = upleft end
        value = (value + guess) % 256
      elseif filter ~= 0 then
        error("this picture uses row transformation " .. tostring(filter) ..
              ", and the format defines five")
      end
      row[index] = value
    end
    out[#out + 1] = row
    previous = row
    at = at + stride
  end
  return out
end
-- }}}

-- {{{ M.read(path, keep_colour)
-- One PNG, as brightness values between zero and one.
--
-- Colour is flattened to brightness on the way out, weighted the way an eye
-- weighs it, because the thing that reads a picture to *grade* it is asking
-- about light and dark -- whether the strokes are where they should be -- and
-- does not care what colour they are.
--
-- `keep_colour` also fills in `red`, `green` and `blue`, for the one caller
-- that is not grading: the animation, which is showing somebody a photograph
-- and would be turning it grey for no reason.
function M.read(path, keep_colour)
  local text = project_read(path)
  if not text then return nil, "there is no picture at " .. path end
  if text:sub(1, 8) ~= "\137PNG\13\10\26\10" then
    return nil, path .. " does not begin like a PNG"
  end

  local position = 9
  local header, compressed, palette = nil, {}, nil
  while position <= #text do
    local length = 0
    for offset = 0, 3 do length = length * 256 + text:byte(position + offset) end
    local kind = text:sub(position + 4, position + 7)
    local body = text:sub(position + 8, position + 7 + length)
    if kind == "IHDR" then
      local function number(at)
        return text:byte(position + 7 + at) * 16777216
             + text:byte(position + 8 + at) * 65536
             + text:byte(position + 9 + at) * 256
             + text:byte(position + 10 + at)
      end
      header = {
        width = number(1), height = number(5),
        depth = body:byte(9), colour = body:byte(10),
        interlace = body:byte(13),
      }
    elseif kind == "IDAT" then
      compressed[#compressed + 1] = body
    elseif kind == "PLTE" then
      palette = body
    elseif kind == "IEND" then
      break
    end
    position = position + 12 + length
  end

  if not header then return nil, path .. " has no header chunk" end
  -- Eight bits per value is what the picture program writes and what `017`
  -- writes. Sixteen turns up from image tools and costs five lines to read --
  -- two bytes per value, most significant first, and only the first matters
  -- once everything is on its way to a fraction anyway.
  if header.depth ~= 8 and header.depth ~= 16 then
    return nil, path .. " stores " .. header.depth ..
           " bits per value, and this reads eight or sixteen"
  end
  local wide = (header.depth == 16)
  if header.interlace ~= 0 then
    return nil, path .. " is interlaced, which this does not read"
  end

  local channels = ({ [0] = 1, [2] = 3, [3] = 1, [4] = 2, [6] = 4 })[header.colour]
  if not channels then
    return nil, path .. " uses colour type " .. header.colour
  end

  local bytes = M.inflate(table.concat(compressed))
  local stored = wide and channels * 2 or channels
  local rows = unfilter(bytes, header.width, header.height, stored)

  local canvas = { width = header.width, height = header.height, pixels = {} }
  if keep_colour then
    canvas.red, canvas.green, canvas.blue = {}, {}, {}
  end
  for y = 1, header.height do
    local row = rows[y]
    local base = (y - 1) * header.width
    for x = 1, header.width do
      local at = (x - 1) * stored + 1
      local step = wide and 2 or 1
      local value
      if header.colour == 0 or header.colour == 4 then
        value = row[at] / 255
      elseif header.colour == 3 then
        local index = row[at] * 3
        value = (0.2126 * palette:byte(index + 1)
               + 0.7152 * palette:byte(index + 2)
               + 0.0722 * palette:byte(index + 3)) / 255
      else
        value = (0.2126 * row[at] + 0.7152 * row[at + step]
               + 0.0722 * row[at + step * 2]) / 255
      end
      canvas.pixels[base + x] = value
      if keep_colour then
        if header.colour == 0 or header.colour == 4 then
          canvas.red[base + x] = value
          canvas.green[base + x] = value
          canvas.blue[base + x] = value
        elseif header.colour == 3 then
          local into = row[at] * 3
          canvas.red[base + x] = palette:byte(into + 1) / 255
          canvas.green[base + x] = palette:byte(into + 2) / 255
          canvas.blue[base + x] = palette:byte(into + 3) / 255
        else
          canvas.red[base + x] = row[at] / 255
          canvas.green[base + x] = row[at + step] / 255
          canvas.blue[base + x] = row[at + step * 2] / 255
        end
      end
    end
  end
  return canvas
end
-- }}}

-- {{{ project_read(path)
-- Reading a file without dragging the whole project in.
--
-- This file is loaded by things that already have the project module and by the
-- test, which does not want a second copy of it. Opening a file is two lines.
function project_read(path)
  local handle = io.open(path, "rb")
  if not handle then return nil end
  local text = handle:read("*a")
  handle:close()
  return text
end
-- }}}

return M
