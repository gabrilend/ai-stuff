-- 034-model-shapes.lua
--
-- Which tensors a model of a given shape contains, and how large each one is.
-- One description, used by everything that needs to agree about a model: the
-- thing that generates a packable description, the reference implementation
-- that reads one, and eventually the assembly that walks the same bytes.
--
-- For a general: a model is a few dozen tables of numbers with fixed names.
-- This says which tables exist and how big each is, given the handful of
-- numbers that describe the model overall.
--
-- WHY ONE FILE. The alternative is each program working out the tensor names
-- for itself, which is two programs agreeing until one of them is edited.
-- Issue 101 already learned this about field offsets; the same rule applies a
-- level up.
--
-- The arrangement below is the ordinary one -- attention with separate query,
-- key and value projections, fewer key and value heads than query heads, and a
-- gated feedforward. It is not the only arrangement a model can have, and a
-- model built differently would need this file extended rather than edited.

local M = {}

-- {{{ M.tensors(shape)
-- Returns an ordered array of { name, shape } for a model of this shape.
--
-- Order matters: it is the order they are packed in, and packing the same
-- description twice must produce the same bytes.
function M.tensors(shape)
  local hidden = shape.hidden
  local heads = shape.heads
  local head_width = shape.head_width
  local kv_heads = shape.kv_heads or heads
  local feedforward = shape.feedforward
  local vocabulary = shape.vocabulary

  -- the width of everything the query heads produce together, and the same
  -- for the fewer key and value heads.
  local query_width = heads * head_width
  local kv_width = kv_heads * head_width

  local out = {}
  local function add(name, dimensions)
    out[#out + 1] = { name = name, shape = dimensions }
  end

  -- one row per token in the vocabulary: what that token means, as a vector.
  add("token_embedding", { vocabulary, hidden })

  for layer = 0, shape.layers - 1 do
    local prefix = "layer" .. layer .. "."

    -- a scale per position in the vector, applied before attention
    add(prefix .. "attn_norm", { hidden })

    -- what to look for, what can be found, and what is carried
    add(prefix .. "wq", { hidden, query_width })
    add(prefix .. "wk", { hidden, kv_width })
    add(prefix .. "wv", { hidden, kv_width })

    -- and how what was found rejoins the vector
    add(prefix .. "wo", { query_width, hidden })

    -- a scale again, before the feedforward
    add(prefix .. "ffn_norm", { hidden })

    -- the gated pair: one decides how much passes, the other what passes
    add(prefix .. "w_gate", { hidden, feedforward })
    add(prefix .. "w_up", { hidden, feedforward })
    add(prefix .. "w_down", { feedforward, hidden })
  end

  add("output_norm", { hidden })
  add("output", { hidden, vocabulary })

  return out
end
-- }}}

-- {{{ M.weight_count(shape)
-- How many numbers a model of this shape holds altogether. Useful before
-- deciding whether a model fits somewhere (issue 502).
function M.weight_count(shape)
  local total = 0
  for _, tensor in ipairs(M.tensors(shape)) do
    local count = 1
    for _, extent in ipairs(tensor.shape) do count = count * extent end
    total = total + count
  end
  return total
end
-- }}}

-- {{{ M.cache_bytes(shape, bytes_per_number)
-- How large a full cache of past keys and values grows. This is the number
-- that decides how long a thought can get (issue 103c), and it is computed
-- rather than written down anywhere so it cannot go stale.
function M.cache_bytes(shape, bytes_per_number)
  local kv_heads = shape.kv_heads or shape.heads
  return 2 * shape.layers * kv_heads * shape.head_width * shape.context
         * (bytes_per_number or 4)
end
-- }}}

-- {{{ M.SMALL -- a model small enough to test with and shaped like a real one
--
-- Every dimension is deliberately different from every other, so an
-- implementation that confuses two of them fails rather than coincidentally
-- working. A model with hidden width equal to its feedforward width would
-- hide a whole class of mistake.
M.SMALL = {
  layers = 2,
  hidden = 32,
  heads = 4,
  head_width = 8,
  kv_heads = 2,
  feedforward = 64,
  vocabulary = 48,
  context = 16,
}
-- }}}

return M
