-- 024-blob-format.lua
--
-- The layout of a packed model. Shared by the packer (025) and the reader
-- (026) so the two can never disagree about where anything is -- the same
-- reason the hazard map (020) is one file rather than two.
--
-- WHY SELF-DESCRIBING. At the moment the engine starts there is no
-- filesystem, no allocator, and no operating system. There is a block of
-- bytes at a known offset and nothing else. Everything the engine needs to
-- know about the shape of what it is holding has to be inside those bytes,
-- because there is nowhere else for it to be.
--
-- WHY OFFSETS ARE BLOB-RELATIVE. Measured from the start of the blob rather
-- than the start of the image, so the image builder (502) can move the blob
-- without rewriting it, and so the engine can find things whether the blob
-- was copied into memory or is being read where it lies (102's ratchet).
--
-- Issue 101 is the blueprint.

local M = {}

-- {{{ M.MAGIC and M.VERSION
-- "ESIA" -- every software image able. Four bytes so a reader can tell at a
-- glance whether it is holding a blob or holding rubbish.
M.MAGIC = "ESIA"

-- Bumped whenever a field moves. A reader that meets a version it does not
-- know must refuse rather than guess: guessing at a layout produces tensors
-- full of neighbouring tensors, which does not fail, it just thinks badly.
M.VERSION = 1
-- }}}

-- {{{ M.HEADER -- fixed-size fields at the very start of the blob
--
-- Every number is stored little-endian and unsigned. Sizes are in bytes.
-- The header is fixed-size on purpose: an engine with no allocator must be
-- able to read it into a known amount of space before it knows anything.
M.HEADER = {
  { name = "magic",         size = 4,  kind = "string" },
  { name = "version",       size = 4,  kind = "u32" },

  -- the model's shape. Read from here rather than compiled into the
  -- arithmetic, so a different model can be packed without rewriting 103.
  { name = "layers",        size = 4,  kind = "u32" },
  { name = "hidden",        size = 4,  kind = "u32" },
  { name = "heads",         size = 4,  kind = "u32" },
  { name = "head_width",    size = 4,  kind = "u32" },
  { name = "kv_heads",      size = 4,  kind = "u32" },
  { name = "feedforward",   size = 4,  kind = "u32" },
  { name = "vocabulary",    size = 4,  kind = "u32" },
  { name = "context",       size = 4,  kind = "u32" },

  -- where the three sections live, blob-relative.
  { name = "tensor_count",  size = 4,  kind = "u32" },
  { name = "tensor_table",  size = 8,  kind = "u64" },
  { name = "token_count",   size = 4,  kind = "u32" },
  { name = "token_table",   size = 8,  kind = "u64" },
  { name = "merge_count",   size = 4,  kind = "u32" },
  { name = "merge_table",   size = 8,  kind = "u64" },

  -- total size, so a reader can check it has the whole thing before trusting
  -- any offset inside it. A truncated blob is otherwise indistinguishable
  -- from a whole one until something reads past the end.
  { name = "blob_bytes",    size = 8,  kind = "u64" },
}
-- }}}

-- {{{ M.header_size()
function M.header_size()
  local total = 0
  for _, field in ipairs(M.HEADER) do total = total + field.size end
  return total
end
-- }}}

-- {{{ M.PRECISION -- how a tensor's numbers are stored
--
-- This is not only a size decision: it reaches into the hottest loop in the
-- machine (issue 103). The first two keep that loop simple. Block-quantised
-- formats are much smaller and put a dequantise step inside it, which is
-- assembly nobody wants to write three times -- so the format permits them
-- and the engine decides what it supports.
M.PRECISION = {
  f32 = { code = 1, bytes = 4, note = "plain 32-bit float; simplest inner loop" },
  f16 = { code = 2, bytes = 2, note = "16-bit float; half the size, same loop shape" },
  i8  = { code = 3, bytes = 1, note = "8-bit integer with a whole-tensor scale" },
  q40 = { code = 4, bytes = 0, note = "block-quantised: 32 weights share a scale; "
                                  .. "needs a dequantise step in the inner loop" },
}
-- }}}

-- {{{ M.precision_by_code(code)
function M.precision_by_code(code)
  for name, precision in pairs(M.PRECISION) do
    if precision.code == code then return name, precision end
  end
  return nil
end
-- }}}

-- {{{ M.TENSOR_ENTRY -- one row of the tensor table
--
-- Fixed-size rows so the table can be walked by index rather than scanned.
-- The name is a fixed 32 bytes, padded with zeros -- variable-length names
-- would mean parsing before you can seek, which an engine with no allocator
-- should not have to do.
M.TENSOR_ENTRY = {
  { name = "name",      size = 32, kind = "string" },
  { name = "precision", size = 4,  kind = "u32" },
  { name = "rank",      size = 4,  kind = "u32" },
  { name = "shape",     size = 32, kind = "u32x8" },  -- up to 8 dimensions
  { name = "offset",    size = 8,  kind = "u64" },    -- blob-relative
  { name = "bytes",     size = 8,  kind = "u64" },
  { name = "scale",     size = 4,  kind = "f32" },    -- for i8; 0 otherwise
}
-- }}}

-- {{{ M.tensor_entry_size()
function M.tensor_entry_size()
  local total = 0
  for _, field in ipairs(M.TENSOR_ENTRY) do total = total + field.size end
  return total
end
-- }}}

-- {{{ M.NAME_BYTES -- how long a tensor name may be
M.NAME_BYTES = 32
-- }}}

-- {{{ M.MAX_RANK
M.MAX_RANK = 8
-- }}}

-- {{{ The tokenizer sections
--
-- The model never sees text. It works in integers, and its embedding table
-- says what each integer MEANS without saying which string it IS. That
-- mapping is separate data, published beside the model, and it travels with
-- it (issue 105a).
--
-- token table: one entry per token -- a length byte then that many bytes.
--   Variable-length, walked in order, because it is read once at startup to
--   build whatever lookup the engine wants rather than seeked into.
--
-- merge table: one entry per rule -- two 32-bit token numbers, highest rank
--   first. Encoding repeatedly joins the highest-ranked adjacent pair until
--   no rule applies, so rank IS position in this table.
M.MERGE_ENTRY_BYTES = 8
-- }}}

return M
