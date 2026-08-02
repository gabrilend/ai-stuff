#!/usr/bin/env luajit
-- 026-read-blob.lua
--
-- Reads a packed model and says what is in it. A separate program from the
-- packer on purpose: generation and viewing stay apart, so a blob is checked
-- by something that did not make it and cannot share its assumptions.
--
-- For a general: hand it a packed model and it tells you what the model is
-- shaped like, what pieces are inside, and whether anything about it is
-- inconsistent with itself.
--
-- This is also the reference for the engine's own reading code (issue 102).
-- Whatever the assembly does when it walks a blob, it should agree with this.
--
-- usage:
--   luajit 026-read-blob.lua BLOB [--tensors] [--tokens] [--dir ROOT]

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
  io.stderr:write("026-read-blob: ", text, "\n")
  os.exit(1)
end
-- }}}

-- {{{ reading primitives -- the mirror of the packer's writing ones
local function read_u32(blob, at)
  local a, b, c, d = blob:byte(at + 1, at + 4)
  if not d then die("blob ends inside a number at offset " .. at) end
  return a + b * 256 + c * 65536 + d * 16777216
end

local function read_u64(blob, at)
  return read_u32(blob, at) + read_u32(blob, at + 4) * 4294967296
end

local function read_f32(blob, at)
  local box = ffi.new("float[1]")
  ffi.copy(box, blob:sub(at + 1, at + 4), 4)
  return box[0]
end

local function read_name(blob, at, width)
  local raw = blob:sub(at + 1, at + width)
  return (raw:gsub("%z.*", ""))
end
-- }}}

-- {{{ local function read_header(blob, format)
local function read_header(blob, format)
  if #blob < format.header_size() then
    die("blob is " .. #blob .. " bytes, shorter than its own header")
  end

  local magic = blob:sub(1, 4)
  if magic ~= format.MAGIC then
    die("this is not a packed model: expected magic '" .. format.MAGIC
        .. "', found '" .. magic:gsub("%c", "?") .. "'")
  end

  local header, at = {}, 0
  for _, field in ipairs(format.HEADER) do
    if field.kind == "string" then
      header[field.name] = blob:sub(at + 1, at + field.size)
    elseif field.kind == "u32" then
      header[field.name] = read_u32(blob, at)
    elseif field.kind == "u64" then
      header[field.name] = read_u64(blob, at)
    end
    at = at + field.size
  end

  -- A reader that meets a version it does not know must refuse rather than
  -- guess. Guessing at a layout produces tensors full of neighbouring
  -- tensors, which does not fail -- it just thinks badly, forever, and
  -- nobody suspects the right thing.
  if header.version ~= format.VERSION then
    die("blob is format version " .. header.version .. "; this reader knows version "
        .. format.VERSION .. " and will not guess at the difference")
  end

  if header.blob_bytes ~= #blob then
    die("header says the blob is " .. header.blob_bytes .. " bytes but it is "
        .. #blob .. " -- truncated, or written by something that miscounted")
  end

  return header
end
-- }}}

-- {{{ local function read_tensors(blob, header, format)
local function read_tensors(blob, header, format)
  local tensors = {}
  local entry_size = format.tensor_entry_size()

  for index = 0, header.tensor_count - 1 do
    local at = header.tensor_table + index * entry_size
    if at + entry_size > #blob then
      die("tensor table entry " .. index .. " runs past the end of the blob")
    end

    local cursor = at
    local name = read_name(blob, cursor, format.NAME_BYTES) ; cursor = cursor + format.NAME_BYTES
    local precision_code = read_u32(blob, cursor) ; cursor = cursor + 4
    local rank = read_u32(blob, cursor) ; cursor = cursor + 4

    local shape = {}
    for slot = 1, format.MAX_RANK do
      local extent = read_u32(blob, cursor) ; cursor = cursor + 4
      if slot <= rank then shape[slot] = extent end
    end

    local offset = read_u64(blob, cursor) ; cursor = cursor + 8
    local bytes = read_u64(blob, cursor) ; cursor = cursor + 8
    local scale = read_f32(blob, cursor)

    local precision_name = format.precision_by_code(precision_code)
      or die("tensor '" .. name .. "' claims precision code " .. precision_code
             .. ", which this format does not define")

    if offset + bytes > #blob then
      die("tensor '" .. name .. "' says its data runs to " .. (offset + bytes)
          .. ", past the end of a " .. #blob .. " byte blob")
    end

    tensors[#tensors + 1] = {
      name = name, precision = precision_name, rank = rank, shape = shape,
      offset = offset, bytes = bytes, scale = scale,
    }
  end
  return tensors
end
-- }}}

-- {{{ local function read_tokens(blob, header)
local function read_tokens(blob, header)
  local tokens = {}
  local at = header.token_table
  for index = 1, header.token_count do
    if at >= #blob then die("token table ends early, at token " .. index) end
    local length = blob:byte(at + 1)
    tokens[index] = blob:sub(at + 2, at + 1 + length)
    at = at + 1 + length
  end
  return tokens, at
end
-- }}}

-- {{{ local function check_overlaps(tensors)
-- Two tensors sharing bytes is the failure that does not announce itself:
-- both read successfully, one of them is wrong, and the model merely seems
-- a little stupid. Cheap to check here, expensive to find later.
local function check_overlaps(tensors)
  local sorted = {}
  for _, tensor in ipairs(tensors) do sorted[#sorted + 1] = tensor end
  table.sort(sorted, function(a, b) return a.offset < b.offset end)

  local complaints = {}
  for index = 2, #sorted do
    local previous, current = sorted[index - 1], sorted[index]
    if previous.offset + previous.bytes > current.offset then
      complaints[#complaints + 1] = previous.name .. " and " .. current.name
        .. " share bytes at " .. current.offset
    end
  end
  return complaints
end
-- }}}

-- {{{ main
local blob_path, show_tensors, show_tokens = nil, false, false
local index = 1
while index <= #arg do
  local word = arg[index]
  if word == "--dir" then
    index = index + 1 ; DIR = arg[index] or die("missing value after --dir")
  elseif word == "--tensors" then
    show_tensors = true
  elseif word == "--tokens" then
    show_tokens = true
  elseif word:sub(1, 2) == "--" then
    die("unknown option: " .. word)
  elseif not blob_path then
    blob_path = word
  else
    die("more than one blob named")
  end
  index = index + 1
end

if not blob_path then die("no blob named; there is nothing to read") end

local format = dofile(DIR .. "/src/024-blob-format.lua")

local handle = io.open(blob_path, "rb") or die("cannot open " .. blob_path)
local blob = handle:read("*a")
handle:close()

local header = read_header(blob, format)
local tensors = read_tensors(blob, header, format)
local tokens = read_tokens(blob, header)

say("")
say("  " .. blob_path)
say("  " .. string.rep("-", 58))
say(string.format("  format version %d, %d bytes", header.version, header.blob_bytes))
say("")
say("  shape")
say(string.format("    %d layers of %d, %d heads of width %d (%d for keys and values)",
                  header.layers, header.hidden, header.heads,
                  header.head_width, header.kv_heads))
say(string.format("    feedforward %d, vocabulary %d, context %d",
                  header.feedforward, header.vocabulary, header.context))
say("")

-- the number that decides how long a thought can get, computed rather than
-- stated, so it cannot go stale (issue 103c).
local cache_bytes = 2 * header.layers * header.kv_heads * header.head_width * header.context * 4
say("  a full key-and-value cache at 32-bit precision would be "
    .. string.format("%.1f", cache_bytes / 1048576) .. " MB")
say("")

local weight_bytes = 0
for _, tensor in ipairs(tensors) do weight_bytes = weight_bytes + tensor.bytes end
say("  contents")
say(string.format("    %d tensors, %d bytes of weights (%.1f%% of the blob)",
                  #tensors, weight_bytes, 100 * weight_bytes / #blob))
say(string.format("    %d tokens, %d merge rules", header.token_count, header.merge_count))

local complaints = check_overlaps(tensors)
if #complaints > 0 then
  say("")
  say("  TENSORS SHARE BYTES:")
  for _, complaint in ipairs(complaints) do say("    " .. complaint) end
else
  say("    no two tensors share a byte")
end

if show_tensors then
  say("")
  say("  tensors")
  for _, tensor in ipairs(tensors) do
    local shape = table.concat(tensor.shape, " x ")
    say(string.format("    %-24s %-4s %-16s %10d bytes at %d",
                      tensor.name, tensor.precision, shape, tensor.bytes, tensor.offset))
  end
end

if show_tokens then
  say("")
  say("  first tokens")
  for slot = 1, math.min(#tokens, 24) do
    say(string.format("    %4d  %q", slot - 1, tokens[slot]))
  end
  if #tokens > 24 then say("    ... and " .. (#tokens - 24) .. " more") end
end

say("")
-- }}}
