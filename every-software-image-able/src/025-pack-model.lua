#!/usr/bin/env luajit
-- 025-pack-model.lua
--
-- Turns a model into the blob an engine can find its way around with nothing
-- underneath it. Runs on a development machine, never on the seed.
--
-- For a general: models are published in whatever shape their makers chose.
-- This puts one into the single shape our machine knows how to read, and
-- writes down inside it everything needed to find each piece again.
--
-- WHICH MODEL IS NOT DECIDED HERE. It is a parameter of whoever builds an
-- image (issue 502). This tool only has to carry whichever one arrives, which
-- is why nothing below names a model or assumes a size.
--
-- usage:
--   luajit 025-pack-model.lua --from DESCRIPTION --to BLOB [--dir ROOT]
--
--   DESCRIPTION is a Lua file returning { shape = {...}, tensors = {...},
--   tokens = {...}, merges = {...} } -- see 025-pack-model.info.md.

-- {{{ DIR -- the project root, hard-coded, overridable by --dir
local DIR = "/mnt/mtwo/programming/ai-stuff/every-software-image-able"
-- }}}

local ffi = require("ffi")

-- {{{ local function say(text)
local function say(text)
  io.write(text, "\n")
end
-- }}}

-- {{{ local function die(text)
local function die(text)
  io.stderr:write("025-pack-model: ", text, "\n")
  os.exit(1)
end
-- }}}

-- {{{ writing primitives -- little-endian, fixed width, no surprises
--
-- Written by hand rather than with string.pack, which LuaJIT does not have.
-- Little-endian because all three target architectures read it natively.
local function u32(value)
  value = math.floor(value)
  return string.char(value % 256,
                     math.floor(value / 256) % 256,
                     math.floor(value / 65536) % 256,
                     math.floor(value / 16777216) % 256)
end

local function u64(value)
  -- split into two 32-bit halves rather than trusting a double past 2^53.
  local low = value % 4294967296
  local high = math.floor(value / 4294967296)
  return u32(low) .. u32(high)
end

local function f32(value)
  -- reinterpret the bits of a float as four bytes.
  local box = ffi.new("float[1]", value)
  return ffi.string(ffi.cast("char *", box), 4)
end

local function fixed_string(text, width)
  if #text > width then
    die("name '" .. text .. "' is longer than the " .. width .. " bytes a tensor name may use")
  end
  return text .. string.rep("\0", width - #text)
end
-- }}}

-- {{{ local function tensor_bytes(tensor, format)
local function tensor_bytes(tensor, format)
  -- How many bytes a tensor's numbers occupy, ASKED RATHER THAN WORKED OUT.
  --
  -- This used to hold its own copy: a special case for the block-quantised
  -- form spelling out that thirty-two weights share a two-byte scale, plus
  -- its own divisibility check repeating the block size, plus a multiply by
  -- a `bytes` field for everything else. Three files described that one fact
  -- in three shapes and the field this read gave zero for the very form the
  -- special case existed to handle -- so the special case was load-bearing
  -- and nothing said so.
  --
  -- The format decides what a stored number is, so the format decides what it
  -- costs. Both the size and the refusal of a partial block come from there.
  if not format.PRECISION[tensor.precision] then
    die("tensor '" .. tensor.name .. "' asks for unknown precision '"
        .. tostring(tensor.precision) .. "'")
  end

  local count = 1
  for _, extent in ipairs(tensor.shape) do count = count * extent end

  local ok, bytes = pcall(format.bytes_for, tensor.precision, count)
  if not ok then
    die("tensor '" .. tensor.name .. "': " .. tostring(bytes))
  end
  return bytes
end
-- }}}

-- {{{ local function build_blob(description, format)
local function build_blob(description, format)
  local shape = description.shape
  local tensors = description.tensors
  local tokens = description.tokens or {}
  local merges = description.merges or {}

  local header_size = format.header_size()
  local entry_size = format.tensor_entry_size()

  -- Lay out in a fixed order so the same description always produces the same
  -- bytes: header, tensor table, token table, merge table, then the weights.
  -- Reproducibility is a build-time property that matters here even though it
  -- stops meaning anything the moment a machine grows (issue 502).
  local cursor = header_size
  local tensor_table_at = cursor
  cursor = cursor + entry_size * #tensors

  local token_table_at = cursor
  for _, token in ipairs(tokens) do
    if #token > 255 then die("token '" .. token:sub(1, 20) .. "...' is longer than 255 bytes") end
    cursor = cursor + 1 + #token
  end

  local merge_table_at = cursor
  cursor = cursor + format.MERGE_ENTRY_BYTES * #merges

  -- weight data, each tensor aligned to 32 bytes so a vectorised inner loop
  -- can load from the start of one without a preliminary unaligned step.
  local placements = {}
  for index, tensor in ipairs(tensors) do
    local padding = (32 - (cursor % 32)) % 32
    cursor = cursor + padding
    placements[index] = { offset = cursor, bytes = tensor_bytes(tensor, format) }
    cursor = cursor + placements[index].bytes
  end
  local total = cursor

  -- {{{ the header
  local parts = {}
  parts[#parts + 1] = format.MAGIC
  parts[#parts + 1] = u32(format.VERSION)
  parts[#parts + 1] = u32(shape.layers)
  parts[#parts + 1] = u32(shape.hidden)
  parts[#parts + 1] = u32(shape.heads)
  parts[#parts + 1] = u32(shape.head_width)
  parts[#parts + 1] = u32(shape.kv_heads or shape.heads)
  parts[#parts + 1] = u32(shape.feedforward)
  parts[#parts + 1] = u32(shape.vocabulary)
  parts[#parts + 1] = u32(shape.context)
  parts[#parts + 1] = u32(#tensors)
  parts[#parts + 1] = u64(tensor_table_at)
  parts[#parts + 1] = u32(#tokens)
  parts[#parts + 1] = u64(token_table_at)
  parts[#parts + 1] = u32(#merges)
  parts[#parts + 1] = u64(merge_table_at)
  parts[#parts + 1] = u64(total)
  -- }}}

  -- {{{ the tensor table
  for index, tensor in ipairs(tensors) do
    if #tensor.shape > format.MAX_RANK then
      die("tensor '" .. tensor.name .. "' has rank " .. #tensor.shape
          .. ", above the " .. format.MAX_RANK .. " this format holds")
    end
    parts[#parts + 1] = fixed_string(tensor.name, format.NAME_BYTES)
    parts[#parts + 1] = u32(format.PRECISION[tensor.precision].code)
    parts[#parts + 1] = u32(#tensor.shape)
    for slot = 1, format.MAX_RANK do
      parts[#parts + 1] = u32(tensor.shape[slot] or 0)
    end
    parts[#parts + 1] = u64(placements[index].offset)
    parts[#parts + 1] = u64(placements[index].bytes)
    parts[#parts + 1] = f32(tensor.scale or 0)
  end
  -- }}}

  -- {{{ the token table -- a length byte, then that many bytes
  for _, token in ipairs(tokens) do
    parts[#parts + 1] = string.char(#token)
    parts[#parts + 1] = token
  end
  -- }}}

  -- {{{ the merge table -- two token numbers per rule, rank is position
  for _, merge in ipairs(merges) do
    parts[#parts + 1] = u32(merge[1])
    parts[#parts + 1] = u32(merge[2])
  end
  -- }}}

  -- {{{ the weights, padded to their alignment
  local written = #table.concat(parts)
  for index, tensor in ipairs(tensors) do
    local placement = placements[index]
    if written < placement.offset then
      parts[#parts + 1] = string.rep("\0", placement.offset - written)
      written = placement.offset
    end
    local data = tensor.data(placement.bytes)
    if #data ~= placement.bytes then
      die("tensor '" .. tensor.name .. "' produced " .. #data
          .. " bytes where its shape and precision say " .. placement.bytes)
    end
    parts[#parts + 1] = data
    written = written + #data
  end
  -- }}}

  local blob = table.concat(parts)
  if #blob ~= total then
    die("packed " .. #blob .. " bytes where the layout says " .. total
        .. " -- the header would be lying about its own size")
  end
  return blob, placements, total
end
-- }}}

-- {{{ main
local from_path, to_path = nil, nil
local index = 1
while index <= #arg do
  local word = arg[index]
  if word == "--dir" then
    index = index + 1 ; DIR = arg[index] or die("missing value after --dir")
  elseif word == "--from" then
    index = index + 1 ; from_path = arg[index] or die("missing value after --from")
  elseif word == "--to" then
    index = index + 1 ; to_path = arg[index] or die("missing value after --to")
  else
    die("unknown option: " .. word)
  end
  index = index + 1
end

if not from_path then die("no --from description given; there is nothing to pack") end
if not to_path then die("no --to path given; there is nowhere to put it") end

local format = dofile(DIR .. "/src/024-blob-format.lua")

local chunk = loadfile(from_path) or die("cannot load description: " .. from_path)
local description = chunk()
if type(description) ~= "table" then die(from_path .. " did not return a table") end
if not description.shape then die(from_path .. " has no shape") end
if not description.tensors then die(from_path .. " has no tensors") end

local blob, placements, total = build_blob(description, format)

local handle = io.open(to_path, "wb") or die("cannot write " .. to_path)
handle:write(blob)
handle:close()

say("packed " .. to_path)
say("  " .. #description.tensors .. " tensors, "
    .. #(description.tokens or {}) .. " tokens, "
    .. #(description.merges or {}) .. " merge rules")
say("  " .. total .. " bytes")
say("  header says the blob is " .. total .. " bytes, and it is")
-- }}}
