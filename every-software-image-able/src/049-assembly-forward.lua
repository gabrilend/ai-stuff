-- 049-assembly-forward.lua
--
-- A forward pass in which every piece of arithmetic is done by the assembly
-- kernels rather than by the readable reference. The order of operations is
-- still decided here, in a language a person can follow; only the arithmetic
-- has moved.
--
-- For a general: this is the real engine's arithmetic, driven by a readable
-- conductor. If it produces exactly what the readable version produced, then
-- every one of those small pieces is right and right in combination -- which is
-- a much stronger statement than each being right alone.
--
-- WHY THIS STEP EXISTS. Writing the whole engine in assembly at once means
-- discovering, at the end, that something in the middle is wrong. Moving the
-- arithmetic first and keeping the conducting in a readable language means a
-- disagreement can only be in the arithmetic, because that is the only thing
-- that changed. What remains afterwards -- the conducting -- has no floating
-- point in it at all, which is the easy half.
--
-- The kernels take pointers and nothing else, so the same instructions run
-- here and on a bare machine. Nothing about them is a testing arrangement.

local ffi = require("ffi")

local M = {}

-- {{{ M.declare()
-- What the kernels look like from outside. Declared once here rather than in
-- each caller, so a change to a signature is a change in one place.
function M.declare()
  ffi.cdef[[
    void matrix_vector_plain(float *out, const float *matrix, const float *input,
                             int rows, int columns);
    void matrix_vector_wide(float *out, const float *matrix, const float *input,
                            int rows, int columns);
    void rms_normalise(float *out, const float *input, const float *weight,
                       int size, float epsilon);
    float exp_one(float x);
    void softmax(float *values, int count);
    void swiglu(float *gate, const float *up, int count);
    void rotate(float *vec, const float *turns, int heads, int head_width);
    void attention_scores(float *scores, const float *query, const float *keys,
                          int count, int width, int stride, float scale);
    void attention_mix(float *out, const float *weights, const float *values,
                       int count, int width, int stride);
    void add_into(float *destination, const float *addend, int count);
  ]]
end
-- }}}

-- {{{ M.new_cache(shape)
function M.new_cache(shape)
  local width = shape.kv_heads * shape.head_width
  return {
    keys = ffi.new("float[?]", shape.layers * shape.context * width),
    values = ffi.new("float[?]", shape.layers * shape.context * width),
    width = width,
  }
end
-- }}}

-- {{{ M.forward(kernels, model, cache, token, position, wide)
-- One token in, one score per possible next token out.
--
-- `wide` chooses between the plain matrix-by-vector kernel and the one that
-- reads four numbers at a time. Both must give the same answer, so running the
-- whole pass each way and comparing is a stronger check of the wide version
-- than any single call to it.
function M.forward(kernels, model, cache, token, position, wide)
  local shape = model.shape
  local hidden = shape.hidden
  local heads, head_width = shape.heads, shape.head_width
  local kv_heads = shape.kv_heads
  local query_width = heads * head_width
  local kv_width = kv_heads * head_width
  local tensors = model.tensors
  local heads_per_kv = heads / kv_heads

  local multiply = wide and kernels.matrix_vector_wide or kernels.matrix_vector_plain

  local state = ffi.new("float[?]", hidden)
  local normalised = ffi.new("float[?]", hidden)
  local query = ffi.new("float[?]", query_width)
  local attended = ffi.new("float[?]", query_width)
  local projected = ffi.new("float[?]", hidden)
  local gate = ffi.new("float[?]", shape.feedforward)
  local up = ffi.new("float[?]", shape.feedforward)
  local scores = ffi.new("float[?]", position + 1)

  -- what this token means, before anything has been done with it
  ffi.copy(state, tensors.token_embedding + token * hidden, hidden * 4)

  -- the row of turns for this position, computed once rather than per head
  local turns = tensors.rotation + position * head_width

  local scale = 1 / math.sqrt(head_width)
  local rounder = ffi.new("float[1]")
  rounder[0] = scale
  scale = rounder[0]

  for layer = 0, shape.layers - 1 do
    local prefix = "layer" .. layer .. "."

    -- {{{ attention
    kernels.rms_normalise(normalised, state, tensors[prefix .. "attn_norm"], hidden, 1e-5)

    local slot = (layer * shape.context + position) * cache.width
    local key_here = cache.keys + slot
    local value_here = cache.values + slot

    multiply(query, tensors[prefix .. "wq"], normalised, query_width, hidden)
    multiply(key_here, tensors[prefix .. "wk"], normalised, kv_width, hidden)
    multiply(value_here, tensors[prefix .. "wv"], normalised, kv_width, hidden)

    kernels.rotate(query, turns, heads, head_width)
    kernels.rotate(key_here, turns, kv_heads, head_width)

    for head = 0, heads - 1 do
      local kv_head = math.floor(head / heads_per_kv)
      local query_base = head * head_width
      -- where this key head's numbers begin in the first cached position; the
      -- rest are one cache width further along each time.
      local first = (layer * shape.context) * cache.width + kv_head * head_width

      kernels.attention_scores(scores, query + query_base, cache.keys + first,
                               position + 1, head_width, cache.width, scale)
      kernels.softmax(scores, position + 1)
      kernels.attention_mix(attended + query_base, scores, cache.values + first,
                            position + 1, head_width, cache.width)
    end

    multiply(projected, tensors[prefix .. "wo"], attended, hidden, query_width)
    kernels.add_into(state, projected, hidden)
    -- }}}

    -- {{{ feedforward
    kernels.rms_normalise(normalised, state, tensors[prefix .. "ffn_norm"], hidden, 1e-5)
    multiply(gate, tensors[prefix .. "w_gate"], normalised, shape.feedforward, hidden)
    multiply(up, tensors[prefix .. "w_up"], normalised, shape.feedforward, hidden)
    kernels.swiglu(gate, up, shape.feedforward)
    multiply(projected, tensors[prefix .. "w_down"], gate, hidden, shape.feedforward)
    kernels.add_into(state, projected, hidden)
    -- }}}
  end

  kernels.rms_normalise(normalised, state, tensors.output_norm, hidden, 1e-5)

  local logits = ffi.new("float[?]", shape.vocabulary)
  multiply(logits, tensors.output, normalised, shape.vocabulary, hidden)
  return logits
end
-- }}}

return M
