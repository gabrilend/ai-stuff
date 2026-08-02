-- 035-reference-forward.lua
--
-- A forward pass, written plainly, on the host. This is the fixture the
-- assembly in issue 103 is checked against -- and the same fixture every port
-- in phase 4 is checked against afterwards, which is why it is worth more than
-- it looks.
--
-- For a general: this is the arithmetic a model performs to turn one token
-- into a score for every token that might come next. It is written here the
-- slow, obvious way, so that a fast obscure version can be proved to agree
-- with it.
--
-- IT IS NOT MEANT TO BE FAST. It is meant to be legible and right. Every
-- optimisation, and every architecture, is checked against what this produces.
-- A mistake here does not fail -- it becomes the definition of correct, and
-- three assembly implementations get patiently taught to reproduce it.
--
-- Everything is 32-bit float, in the order the packer wrote it, so the
-- comparison is byte-comparable rather than approximate wherever it can be.

local ffi = require("ffi")

-- The exponential is specified rather than borrowed (047). Sine and cosine do
-- not appear at all: the turns that carry position are read from a table
-- carried with the model (034). Between them, every function in this file is
-- one that agrees across implementations, which is what lets an assembly
-- version be required to match exactly rather than closely.
local exponential = dofile(
  (os.getenv("ESIA_DIR") or "/mnt/mtwo/programming/ai-stuff/every-software-image-able")
  .. "/src/047-reference-exp.lua")

local M = {}

-- {{{ single precision, on purpose and by specification
--
-- THE PRECISION IS PART OF THE ANSWER, NOT AN IMPLEMENTATION DETAIL.
--
-- This language's numbers are doubles, so accumulating a dot product the
-- obvious way sums in double and stores a float at the end. Assembly
-- accumulating in a single-precision register does not do that, and the two
-- results differ in the last bits -- summing 0.1 ten times gives
-- 1.0000000149011612 one way and 1.0000001192092896 the other.
--
-- That difference is small and it is fatal to the only comparison worth
-- having. A fixture that can only be matched approximately turns every future
-- disagreement into a judgement call about whether the difference is "small
-- enough", which is precisely the judgement this fixture exists to remove.
--
-- So the specification is: **every accumulation is single precision, in
-- ascending index order**, and this reference implements that literally by
-- rounding through a float after each step. It is slower. It is meant to be.
--
-- Rounding a double result to float once per operation gives the same answer
-- as doing the operation in float: a double carries fifty-three bits and
-- single-precision needs fifty for the rounding to be safe, so no operation
-- here is rounded twice.
--
-- WHAT THIS DOES NOT MAKE EXACT. Square root is exactly specified and matches
-- everywhere. Exponential, sine and cosine are not, and differ between
-- implementations. So the kernels built from arithmetic alone can be compared
-- bit for bit, and anything downstream of a transcendental function cannot --
-- see 044, which draws that line explicitly.
local round = ffi.new("float[1]")

local function f(value)
  round[0] = value
  return round[0]
end
-- }}}

-- {{{ local function read_header(blob, format)
local function read_header(blob, format)
  local at, header = 0, {}
  for _, field in ipairs(format.HEADER) do
    if field.kind == "string" then
      header[field.name] = blob:sub(at + 1, at + field.size)
    elseif field.kind == "u32" then
      local a, b, c, d = blob:byte(at + 1, at + 4)
      header[field.name] = a + b * 256 + c * 65536 + d * 16777216
    elseif field.kind == "u64" then
      local a, b, c, d = blob:byte(at + 1, at + 4)
      local e, f, g, h = blob:byte(at + 5, at + 8)
      header[field.name] = (a + b * 256 + c * 65536 + d * 16777216)
        + (e + f * 256 + g * 65536 + h * 16777216) * 4294967296
    end
    at = at + field.size
  end
  return header
end
-- }}}

-- {{{ M.load(blob, format)
-- Reads a packed model into something the arithmetic below can index. The
-- tensors are not copied: each is a pointer into the blob, which is what the
-- engine will do too when it reads the weights where they lie (issue 102).
function M.load(blob, format)
  local header = read_header(blob, format)
  if blob:sub(1, 4) ~= format.MAGIC then error("not a packed model") end

  local model = {
    shape = {
      layers = header.layers, hidden = header.hidden,
      heads = header.heads, head_width = header.head_width,
      kv_heads = header.kv_heads, feedforward = header.feedforward,
      vocabulary = header.vocabulary, context = header.context,
    },
    tensors = {},
  }

  local entry_size = format.tensor_entry_size()
  local bytes = ffi.cast("const char *", blob)

  for index = 0, header.tensor_count - 1 do
    local at = header.tensor_table + index * entry_size
    local name = blob:sub(at + 1, at + format.NAME_BYTES):gsub("%z.*", "")

    local cursor = at + format.NAME_BYTES + 4 + 4 + 32
    local a, b, c, d = blob:byte(cursor + 1, cursor + 4)
    local e, f, g, h = blob:byte(cursor + 5, cursor + 8)
    local offset = (a + b * 256 + c * 65536 + d * 16777216)
      + (e + f * 256 + g * 65536 + h * 16777216) * 4294967296

    -- only 32-bit floats here. The other precisions exist in the format and
    -- the reference deliberately does not implement them: a fixture that
    -- quantises is a fixture with an opinion, and what is wanted is the plain
    -- answer everything else is compared to.
    model.tensors[name] = ffi.cast("const float *", bytes + offset)
  end

  return model
end
-- }}}

-- {{{ local function vector(size)
local function vector(size)
  return ffi.new("float[?]", size)
end
-- }}}

-- {{{ local function rms_normalise(out, input, weight, size)
-- Scale a vector so its typical magnitude is one, then apply a learned scale
-- per position. Every layer does this twice, before attention and before the
-- feedforward, and it is why the numbers flowing through stay in a range the
-- rest of the arithmetic can work with.
local function rms_normalise(out, input, weight, size)
  local sum = f(0)
  for index = 0, size - 1 do
    sum = f(sum + f(input[index] * input[index]))
  end
  -- square root is exactly specified, so this much is reproducible anywhere
  local scale = f(1 / f(math.sqrt(f(f(sum / size) + 1e-5))))
  for index = 0, size - 1 do
    out[index] = f(f(input[index] * scale) * weight[index])
  end
end
-- }}}

-- {{{ local function matrix_vector(out, matrix, input, rows, columns)
-- The operation that is nearly all of the work and nearly all of the time.
-- Every projection in the model is one of these: for each output position,
-- multiply a row of the matrix through the input and add it all up.
--
-- The matrix is stored row by row, `columns` numbers to a row, which is why a
-- vectorised version can read straight down each row without gathering.
local function matrix_vector(out, matrix, input, rows, columns)
  for row = 0, rows - 1 do
    local sum = f(0)
    local base = row * columns
    for column = 0, columns - 1 do
      sum = f(sum + f(matrix[base + column] * input[column]))
    end
    out[row] = sum
  end
end
-- }}}

-- {{{ local function apply_rotation(vec, position, heads, head_width)
-- How a token learns where it is. Each pair of numbers in a head is treated as
-- a point on a circle and turned by an angle that depends on the position in
-- the sequence and on how far into the head the pair sits.
--
-- Nothing is added to the vector -- the information about position lives in
-- the angles, which is why two identical tokens in different places produce
-- different keys and queries.
local function apply_rotation(vec, turns, position, heads, head_width)
  -- The angles are read from the carried table rather than computed, which
  -- removes sine and cosine from this arithmetic entirely (034). They differ
  -- between implementations in the last bits, so anything downstream of them
  -- could only ever be compared approximately -- and there is nothing about
  -- them worth recomputing, since the turn at a given position never changes.
  local row = position * head_width
  for head = 0, heads - 1 do
    local base = head * head_width
    for pair = 0, head_width / 2 - 1 do
      local cosine = turns[row + pair * 2]
      local sine = turns[row + pair * 2 + 1]

      local first = base + pair * 2
      local second = first + 1
      local x, y = vec[first], vec[second]
      vec[first] = f(f(x * cosine) - f(y * sine))
      vec[second] = f(f(x * sine) + f(y * cosine))
    end
  end
end
-- }}}

-- {{{ local function softmax(values, count)
-- Turn a set of scores into a set of weights that add up to one. The largest
-- is subtracted first, which changes nothing about the answer and stops the
-- exponentials from running away.
local function softmax(values, count)
  local largest = values[0]
  for index = 1, count - 1 do
    if values[index] > largest then largest = values[index] end
  end
  local total = f(0)
  for index = 0, count - 1 do
    -- the specified exponential (047), not the language's, so that assembly
    -- can reproduce this exactly rather than approximately
    values[index] = exponential.exp(f(values[index] - largest))
    total = f(total + values[index])
  end
  for index = 0, count - 1 do values[index] = f(values[index] / total) end
end
-- }}}

-- {{{ M.kernels -- the arithmetic alone, exposed so assembly can be compared
--
-- These two are built from multiplication, addition and square root only, so
-- an assembly implementation can be required to match them bit for bit rather
-- than approximately. Everything else in this file passes through an
-- exponential, a sine or a cosine at some point, and those differ between
-- implementations -- which is why only these two are offered here.
M.kernels = {
  matrix_vector = matrix_vector,
  rms_normalise = rms_normalise,
}
-- }}}

-- {{{ M.new_cache(shape)
-- Room for every key and value the model will produce, for as long a thought
-- as it is allowed to have. This is the largest thing after the weights.
function M.new_cache(shape)
  local kv_heads = shape.kv_heads
  local width = kv_heads * shape.head_width
  return {
    keys = ffi.new("float[?]", shape.layers * shape.context * width),
    values = ffi.new("float[?]", shape.layers * shape.context * width),
    width = width,
    filled = 0,
  }
end
-- }}}

-- {{{ M.forward(model, cache, token, position)
-- One token in, one score per possible next token out.
function M.forward(model, cache, token, position)
  local shape = model.shape
  local hidden = shape.hidden
  local heads, head_width = shape.heads, shape.head_width
  local kv_heads = shape.kv_heads
  local query_width = heads * head_width
  local kv_width = kv_heads * head_width
  local tensors = model.tensors

  -- how many query heads share each key-and-value head. Fewer keys than
  -- queries is the ordinary arrangement now; it makes the cache smaller
  -- without costing much.
  local heads_per_kv = heads / kv_heads

  local state = vector(hidden)
  local normalised = vector(hidden)
  local query = vector(query_width)
  local attended = vector(query_width)
  local projected = vector(hidden)
  local gate = vector(shape.feedforward)
  local up = vector(shape.feedforward)

  -- what this token means, before anything has been done with it
  local embedding = tensors.token_embedding
  for index = 0, hidden - 1 do
    state[index] = embedding[token * hidden + index]
  end

  for layer = 0, shape.layers - 1 do
    local prefix = "layer" .. layer .. "."

    -- {{{ attention
    rms_normalise(normalised, state, tensors[prefix .. "attn_norm"], hidden)

    -- where this token's key and value go in the cache
    local slot = (layer * shape.context + position) * cache.width
    local key_here = cache.keys + slot
    local value_here = cache.values + slot

    matrix_vector(query, tensors[prefix .. "wq"], normalised, query_width, hidden)
    matrix_vector(key_here, tensors[prefix .. "wk"], normalised, kv_width, hidden)
    matrix_vector(value_here, tensors[prefix .. "wv"], normalised, kv_width, hidden)

    apply_rotation(query, tensors.rotation, position, heads, head_width)
    apply_rotation(key_here, tensors.rotation, position, kv_heads, head_width)

    local scale = 1 / math.sqrt(head_width)
    local scores = vector(position + 1)

    for head = 0, heads - 1 do
      local kv_head = math.floor(head / heads_per_kv)
      local query_base = head * head_width

      -- how well this token's question matches every earlier token's answer
      for past = 0, position do
        local past_slot = (layer * shape.context + past) * cache.width
                        + kv_head * head_width
        local sum = f(0)
        for index = 0, head_width - 1 do
          sum = f(sum + f(query[query_base + index] * cache.keys[past_slot + index]))
        end
        scores[past] = f(sum * scale)
      end

      softmax(scores, position + 1)

      -- and what to carry forward, weighted by how well each matched
      for index = 0, head_width - 1 do attended[query_base + index] = 0 end
      for past = 0, position do
        local past_slot = (layer * shape.context + past) * cache.width
                        + kv_head * head_width
        local weight = scores[past]
        for index = 0, head_width - 1 do
          attended[query_base + index] = attended[query_base + index]
            + weight * cache.values[past_slot + index]
        end
      end
    end

    matrix_vector(projected, tensors[prefix .. "wo"], attended, hidden, query_width)
    for index = 0, hidden - 1 do state[index] = state[index] + projected[index] end
    -- }}}

    -- {{{ feedforward
    rms_normalise(normalised, state, tensors[prefix .. "ffn_norm"], hidden)

    matrix_vector(gate, tensors[prefix .. "w_gate"], normalised, shape.feedforward, hidden)
    matrix_vector(up, tensors[prefix .. "w_up"], normalised, shape.feedforward, hidden)

    -- the gate decides how much of each position passes, on a curve that is
    -- smooth everywhere rather than a hard cutoff.
    for index = 0, shape.feedforward - 1 do
      local value = gate[index]
      local opened = f(value / f(1 + exponential.exp(f(-value))))
      gate[index] = f(opened * up[index])
    end

    matrix_vector(projected, tensors[prefix .. "w_down"], gate, hidden, shape.feedforward)
    for index = 0, hidden - 1 do state[index] = state[index] + projected[index] end
    -- }}}
  end

  rms_normalise(normalised, state, tensors.output_norm, hidden)

  local logits = vector(shape.vocabulary)
  matrix_vector(logits, tensors.output, normalised, shape.vocabulary, hidden)

  cache.filled = position + 1
  return logits
end
-- }}}

return M
