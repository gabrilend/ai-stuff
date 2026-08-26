-- 017-write-a-picture.lua
--
-- Writes a surface out as a PNG, which means writing a compressor.
--
-- For a general: there is no way to write this format without compressing the
-- data, because the format's contents are defined to be a compressed stream.
-- The format does permit blocks marked "not actually compressed", and a picture
-- built from those is valid and opens everywhere -- and is about six times
-- larger than it should be. This project writes two pictures per character for
-- potentially six thousand characters, so six times larger is the difference
-- between a set somebody can keep and a set somebody deletes.
--
-- So the real thing, in three parts:
--
--   * finding repeats -- most of a blurred picture is a slow gradient, and a
--     gradient repeats once you look at it the right way
--   * the standard code table, which spends fewer bits on the byte values that
--     turn up most
--   * the row transformations, which are what turn a gradient into a repeat in
--     the first place, and are the single largest win available here
--
-- Nothing here reads a PNG. The test in `020` carries a small reader, because
-- the only way to know a compressor is right is to decompress what it wrote.

local bit = require("bit")
local band, bor, lshift, rshift, bxor = bit.band, bit.bor, bit.lshift,
                                        bit.rshift, bit.bxor

local M = {}

-- {{{ CRC_TABLE -- the per-byte remainders, built once
--
-- The chunk checksum. Every chunk in the file carries one over its own type and
-- contents, and it is not the same algorithm as the one inside the compressed
-- stream -- which is the classic way to lose an afternoon here, because a file
-- with either one wrong opens in some viewers and is rejected by others.
local CRC_TABLE = {}
for index = 0, 255 do
  local remainder = index
  for _ = 1, 8 do
    if band(remainder, 1) == 1 then
      remainder = bxor(0xEDB88320, rshift(remainder, 1))
    else
      remainder = rshift(remainder, 1)
    end
  end
  CRC_TABLE[index] = remainder
end
-- }}}

-- {{{ M.crc32(text, seed)
-- The checksum a PNG chunk carries.
function M.crc32(text, seed)
  local remainder = seed or 0xFFFFFFFF
  for index = 1, #text do
    remainder = bxor(CRC_TABLE[band(bxor(remainder, text:byte(index)), 0xFF)],
                     rshift(remainder, 8))
  end
  return remainder
end
-- }}}

-- {{{ M.adler32(bytes, from, to)
-- The checksum the compressed stream carries, over the bytes before compression.
--
-- Two running sums, one of the bytes and one of that sum, both kept modulo the
-- largest prime below sixty-five thousand five hundred and thirty-six. The
-- second sum is what makes it notice bytes swapped around, which a plain total
-- would not.
function M.adler32(bytes, from, to)
  local low, high = 1, 0
  for index = from, to do
    low = (low + bytes[index]) % 65521
    high = (high + low) % 65521
  end
  return high * 65536 + low
end
-- }}}

-- {{{ LENGTH_BASE, LENGTH_EXTRA, DISTANCE_BASE, DISTANCE_EXTRA
--
-- A repeat is written as "go back this far, copy this many". Neither number is
-- written directly: each is a small code plus some extra bits, so that short
-- distances -- which are far commoner -- cost fewer bits than long ones. These
-- four tables are the format's, verbatim.
local LENGTH_BASE = {
  3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59,
  67, 83, 99, 115, 131, 163, 195, 227, 258,
}
local LENGTH_EXTRA = {
  0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3,
  4, 4, 4, 4, 5, 5, 5, 5, 0,
}
local DISTANCE_BASE = {
  1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513,
  769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577,
}
local DISTANCE_EXTRA = {
  0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8,
  9, 9, 10, 10, 11, 11, 12, 12, 13, 13,
}
-- }}}

-- {{{ bit_writer()
-- Somewhere to put bits, in the order this format wants them.
--
-- TWO ORDERS AT ONCE, which is the thing to hold on to. Ordinary values go into
-- the stream lowest bit first. Code-table entries go in highest bit first. Both
-- are true simultaneously, and mixing them up produces a stream that decodes to
-- something for a while and then falls apart, which is much harder to find than
-- one that fails immediately.
local function bit_writer()
  local self = { bytes = {}, held = 0, count = 0 }

  -- {{{ self.put(value, width)
  -- A plain number, lowest bit first.
  function self.put(value, width)
    self.held = bor(self.held, lshift(band(value, lshift(1, width) - 1), self.count))
    self.count = self.count + width
    while self.count >= 8 do
      self.bytes[#self.bytes + 1] = string.char(band(self.held, 0xFF))
      self.held = rshift(self.held, 8)
      self.count = self.count - 8
    end
  end
  -- }}}

  -- {{{ self.code(value, width)
  -- A code-table entry, highest bit first.
  function self.code(value, width)
    for shift = width - 1, 0, -1 do
      self.put(band(rshift(value, shift), 1), 1)
    end
  end
  -- }}}

  -- {{{ self.finish()
  function self.finish()
    if self.count > 0 then
      self.bytes[#self.bytes + 1] = string.char(band(self.held, 0xFF))
      self.held, self.count = 0, 0
    end
    return table.concat(self.bytes)
  end
  -- }}}

  return self
end
-- }}}

-- {{{ write_literal(out, value)
-- One uncompressed byte, in the standard code table.
--
-- The table is fixed by the format rather than computed from the data. That
-- costs a few percent against a table built for this particular picture, and it
-- removes the entire problem of building a tree, writing it into the stream,
-- and being wrong about either. The few percent is not worth that.
--
-- Byte values under 144 get eight bits; the rest get nine.
local function write_literal(out, value)
  if value < 144 then
    out.code(0x30 + value, 8)
  else
    out.code(0x190 + value - 144, 9)
  end
end
-- }}}

-- {{{ write_match(out, length, distance)
-- A repeat: how many bytes, and how far back they were.
local function write_match(out, length, distance)
  local code = 29
  for index = 1, 29 do
    -- the bounds check comes first: at the last entry there is no next base to
    -- compare against, and Lua evaluates both sides of an `or` left to right
    if index == 29 or length < LENGTH_BASE[index + 1] then code = index break end
  end
  local symbol = 256 + code
  -- symbols 256 to 279 are seven bits; 280 and up are eight
  if symbol < 280 then
    out.code(symbol - 256, 7)
  else
    out.code(0xC0 + symbol - 280, 8)
  end
  if LENGTH_EXTRA[code] > 0 then
    out.put(length - LENGTH_BASE[code], LENGTH_EXTRA[code])
  end

  local distance_code = 30
  for index = 1, 30 do
    if index == 30 or distance < DISTANCE_BASE[index + 1] then
      distance_code = index break
    end
  end
  out.code(distance_code - 1, 5)
  if DISTANCE_EXTRA[distance_code] > 0 then
    out.put(distance - DISTANCE_BASE[distance_code], DISTANCE_EXTRA[distance_code])
  end
end
-- }}}

-- {{{ M.deflate(bytes, count, chain_limit)
-- The bytes, compressed, wrapped as the stream a PNG carries.
--
-- Repeats are found with a hash of every three consecutive bytes. Each hash
-- remembers the most recent place it was seen and each place remembers the one
-- before it, so following that chain walks backwards through everywhere the
-- next three bytes have appeared -- and the longest run from any of them is the
-- repeat to write.
--
-- The chain is walked only so far. Blurred pictures have enormous numbers of
-- places matching any three bytes, and the hundredth candidate almost never
-- beats the first few; an unbounded walk turns a fast compressor into a slow
-- one for a fraction of a percent.
function M.deflate(bytes, count, chain_limit)
  chain_limit = chain_limit or 32
  local out = bit_writer()

  -- the two-byte header saying what kind of stream this is
  out.put(0x78, 8)
  out.put(0x01, 8)

  -- one block, the last one, using the standard code table
  out.put(1, 1)
  out.put(1, 2)

  local WINDOW = 32768
  local MIN_MATCH = 3
  local MAX_MATCH = 258
  local HASH_SIZE = 16384

  local head, prev = {}, {}
  local position = 1

  while position <= count do
    local best_length, best_distance = 0, 0

    if position + MIN_MATCH - 1 <= count then
      local key = band((bytes[position] * 6151 + bytes[position + 1] * 769
                        + bytes[position + 2] * 31), HASH_SIZE - 1)
      local candidate = head[key]
      local walked = 0
      while candidate and walked < chain_limit do
        local distance = position - candidate
        if distance > WINDOW then break end
        -- Only bother if this candidate could beat what we have: check the byte
        -- that would be one past the end of the current best first. Most
        -- candidates fail here, and failing in one comparison rather than three
        -- is most of the speed of this loop.
        if best_length == 0 or bytes[candidate + best_length] == bytes[position + best_length] then
          local length = 0
          local limit = count - position + 1
          if limit > MAX_MATCH then limit = MAX_MATCH end
          while length < limit and bytes[candidate + length] == bytes[position + length] do
            length = length + 1
          end
          if length >= MIN_MATCH and length > best_length then
            best_length, best_distance = length, distance
            if length >= MAX_MATCH then break end
          end
        end
        candidate = prev[candidate]
        walked = walked + 1
      end
      prev[position] = head[key]
      head[key] = position
    end

    if best_length >= MIN_MATCH then
      write_match(out, best_length, best_distance)
      -- Every position inside the repeat still has to go into the tables, or
      -- the next repeat cannot find anything that overlapped this one. Skipping
      -- them is a real and quiet compression loss.
      for step = 1, best_length - 1 do
        local at = position + step
        if at + MIN_MATCH - 1 <= count then
          local key = band((bytes[at] * 6151 + bytes[at + 1] * 769
                            + bytes[at + 2] * 31), HASH_SIZE - 1)
          prev[at] = head[key]
          head[key] = at
        end
      end
      position = position + best_length
    else
      write_literal(out, bytes[position])
      position = position + 1
    end
  end

  -- the symbol that says the block is over
  out.code(0, 7)

  local body = out.finish()
  local check = M.adler32(bytes, 1, count)
  return body .. string.char(band(rshift(check, 24), 0xFF),
                             band(rshift(check, 16), 0xFF),
                             band(rshift(check, 8), 0xFF),
                             band(check, 0xFF))
end
-- }}}

-- {{{ filter_rows(raw, width, height, channels)
-- Each row rewritten as differences, whichever difference makes it smallest.
--
-- THE LARGEST WIN IN THIS FILE, and the least obvious. A compressor finds
-- repeated bytes, and a smooth gradient has no repeated bytes at all -- every
-- value differs from the last. Subtract each byte from its neighbour and the
-- same gradient becomes a long run of the same small number, which compresses
-- to almost nothing. On a blurred grey picture this is roughly a halving before
-- the compressor has done anything.
--
-- Five ways to do it, one chosen per row: leave it alone, difference against
-- the left, against the row above, against their average, or against a
-- predictor that picks whichever of three neighbours it is nearest. The choice
-- is the standard heuristic -- try each, add up how far the results are from
-- zero, keep the smallest -- because bytes near zero are what compresses.
local function filter_rows(raw, width, height, channels)
  local stride = width * channels
  local out = {}
  local previous = {}
  for index = 1, stride do previous[index] = 0 end

  local current = {}
  local candidates = { {}, {}, {}, {}, {} }

  for y = 0, height - 1 do
    local base = y * stride
    for index = 1, stride do current[index] = raw:byte(base + index) end

    local scores = { 0, 0, 0, 0, 0 }
    for index = 1, stride do
      local here = current[index]
      local left = index > channels and current[index - channels] or 0
      local up = previous[index]
      local upleft = index > channels and previous[index - channels] or 0

      candidates[1][index] = here
      candidates[2][index] = (here - left) % 256
      candidates[3][index] = (here - up) % 256
      candidates[4][index] = (here - math.floor((left + up) / 2)) % 256

      -- the fifth predictor: of the three neighbours, whichever is closest to
      -- their combined estimate
      local estimate = left + up - upleft
      local from_left = math.abs(estimate - left)
      local from_up = math.abs(estimate - up)
      local from_upleft = math.abs(estimate - upleft)
      local guess
      if from_left <= from_up and from_left <= from_upleft then guess = left
      elseif from_up <= from_upleft then guess = up
      else guess = upleft end
      candidates[5][index] = (here - guess) % 256

      for which = 1, 5 do
        local value = candidates[which][index]
        -- how far from zero, treating the byte as signed, which is what the
        -- compressor actually cares about
        scores[which] = scores[which] + (value < 128 and value or (256 - value))
      end
    end

    local best, best_score = 1, scores[1]
    for which = 2, 5 do
      if scores[which] < best_score then best, best_score = which, scores[which] end
    end

    out[#out + 1] = string.char(best - 1)
    local chosen = candidates[best]
    local row = {}
    for index = 1, stride do row[index] = string.char(chosen[index]) end
    out[#out + 1] = table.concat(row)

    for index = 1, stride do previous[index] = current[index] end
  end

  return table.concat(out)
end
-- }}}

-- {{{ chunk(kind, body)
-- One PNG chunk: how long, what it is, what it says, and its checksum.
local function chunk(kind, body)
  local length = #body
  local header = string.char(band(rshift(length, 24), 0xFF),
                             band(rshift(length, 16), 0xFF),
                             band(rshift(length, 8), 0xFF),
                             band(length, 0xFF))
  local check = bxor(M.crc32(kind .. body), 0xFFFFFFFF)
  return header .. kind .. body ..
         string.char(band(rshift(check, 24), 0xFF),
                     band(rshift(check, 16), 0xFF),
                     band(rshift(check, 8), 0xFF),
                     band(check, 0xFF))
end
-- }}}

-- {{{ M.encode(raw, width, height, channels)
-- Pixel bytes in, a whole PNG file out.
--
-- `channels` is one for grey and four for grey-with-transparency... four for
-- colour-with-transparency. One and four are the only two this project makes.
function M.encode(raw, width, height, channels)
  local colour_type
  if channels == 1 then colour_type = 0
  elseif channels == 4 then colour_type = 6
  else error("this writer makes grey or colour-with-transparency, not " ..
             tostring(channels) .. " channels") end

  local header = string.char(band(rshift(width, 24), 0xFF),
                             band(rshift(width, 16), 0xFF),
                             band(rshift(width, 8), 0xFF), band(width, 0xFF),
                             band(rshift(height, 24), 0xFF),
                             band(rshift(height, 16), 0xFF),
                             band(rshift(height, 8), 0xFF), band(height, 0xFF),
                             8, colour_type, 0, 0, 0)

  local filtered = filter_rows(raw, width, height, channels)
  local bytes = {}
  for index = 1, #filtered do bytes[index] = filtered:byte(index) end

  return "\137PNG\13\10\26\10" ..
         chunk("IHDR", header) ..
         chunk("IDAT", M.deflate(bytes, #filtered)) ..
         chunk("IEND", "")
end
-- }}}

-- {{{ M.write_grey(path, surface, canvas_module)
-- A surface, written to disk as grey.
function M.write_grey(path, surface, canvas_module)
  local raw = canvas_module.bytes(surface)
  local png = M.encode(raw, surface.width, surface.height, 1)
  local handle = assert(io.open(path .. ".partial", "wb"))
  handle:write(png)
  handle:close()
  os.rename(path .. ".partial", path)
  return #png, #raw
end
-- }}}

-- {{{ M.write_rgba(path, red, green, blue, alpha, canvas_module)
-- Four surfaces, written to disk as one colour picture with transparency.
--
-- Four separate surfaces rather than one with four numbers per pixel, so that
-- everything in `016` works on them unchanged -- the arrow layer draws into the
-- transparency exactly the way it draws into the colours, and there is no
-- second kind of canvas to maintain.
function M.write_rgba(path, red, green, blue, alpha, canvas_module)
  local width, height = red.width, red.height
  local out = {}
  local count = width * height
  local function clamp(value)
    if value < 0 then return 0 elseif value > 1 then return 1 end
    return value
  end
  for index = 1, count do
    out[index] = string.char(
      math.floor(clamp(red.pixels[index]) * 255 + 0.5),
      math.floor(clamp(green.pixels[index]) * 255 + 0.5),
      math.floor(clamp(blue.pixels[index]) * 255 + 0.5),
      math.floor(clamp(alpha.pixels[index]) * 255 + 0.5))
  end
  local raw = table.concat(out)
  local png = M.encode(raw, width, height, 4)
  local handle = assert(io.open(path .. ".partial", "wb"))
  handle:write(png)
  handle:close()
  os.rename(path .. ".partial", path)
  return #png, #raw
end
-- }}}

return M
