-- 061-thinking-loop.lua
--
-- The loop: text becomes tokens, tokens run through the arithmetic, a token
-- is drawn, it joins the input, repeat -- with an honest answer to what
-- happens when the machine has thought for longer than it can hold. Issue
-- 105 is the blueprint; everything this wires together already exists and is
-- tested alone.
--
-- For a general: this is the machine's heartbeat. The engine (056), the
-- sampler (057) and the tokenizer (059) are each proven against a readable
-- twin; this is the piece that makes them one machine that can be spoken to
-- and that speaks back, and that can be told to stop.
--
-- WHAT THE MACHINE THINKS WITH IS THE ATOM CONTEXT (052). The context is a
-- concatenation of atoms and nothing else. The loop reads it whole, lays it
-- into the cache, and puts what it says back in as an atom -- so nothing the
-- machine has said or been told sits outside the enumerable list.
--
-- THE CACHE IS REUSED, NOT RECOMPUTED. Each pass reuses the keys and values
-- of every position already thought, which is the difference between a
-- usable machine and an unusable one. The loop keeps the token list the
-- cache was built from; when the context is re-read, only what changed past
-- the common prefix is replayed.
--
-- WHAT STOPS IT. Four things, each named in the answer: a token that means
-- "finished"; a length limit; an interruption from outside, checked between
-- tokens because a machine that cannot be interrupted mid-thought cannot be
-- told to stop doing something; and the room running out -- the context is
-- finite, and stopping honestly beats thinking past the edge.
--
-- THE SEAM LEFT OPEN: writing atoms out and recalling them waits for
-- storage (304), as does loading the boot set from a file on the image
-- (502). Hosted callers hand `boot_atoms` in directly.

local ffi = require("ffi")

local M = {}

-- {{{ M.new(options)
--
-- options:
--   model        a loaded model (035.load)
--   kernels      the built library holding the conductor, sampler and tokenizer
--   conduct      the conductor module (056), declared
--   sampler      the sampler module (057), declared
--   tokenizer    the tokenizer module (059), declared
--   tables       { tokens = ..., merges = ... } -- the carried tokenizer tables
--   carried      the carried file of random numbers (a Lua array)
--   settings     temperature, top_k, top_p
--   finish_token a token number that means "finished", or nil for none
--   boot_atoms   what the context starts holding, or nil
function M.new(options)
  local model = options.model
  local shape = model.shape

  local context_module = dofile(
    (os.getenv("ESIA_DIR") or "/mnt/mtwo/programming/ai-stuff/every-software-image-able")
    .. "/src/052-atom-context.lua")

  local loop = {
    model = model,
    kernels = options.kernels,
    finish_token = options.finish_token,
    atoms = context_module,
    -- the budget is the model's context, because that is what "resident"
    -- physically means here: a token the cache has room to think over.
    context = context_module.new({ budget = shape.context }),

    -- what the cache currently holds, token by token, so a re-read of the
    -- context replays only what changed.
    known = {},
    logits = ffi.new("float[?]", shape.vocabulary),
    have_logits = false,
    forward_calls = 0,
  }

  local cache = { keys = ffi.new("float[?]", shape.layers * shape.context
                                   * shape.kv_heads * shape.head_width),
                  values = ffi.new("float[?]", shape.layers * shape.context
                                    * shape.kv_heads * shape.head_width),
                  width = shape.kv_heads * shape.head_width }
  loop.conductor = options.conduct.new_plan(options.kernels, model, cache, true)

  loop.stream = options.sampler.new_stream(options.carried)
  loop.chooser = options.sampler.new_plan(options.kernels, shape.vocabulary,
                                          options.settings or {}, loop.stream)

  loop.tokenizer = options.tokenizer.prepare(options.tables.tokens,
                                             options.tables.merges)
  loop.tokenizer_module = options.tokenizer
  loop.chance = ffi.new("float[1]")

  if options.boot_atoms then
    context_module.boot(loop.context, options.boot_atoms)
  end

  return loop
end
-- }}}

-- {{{ M.encode(loop, text)
-- Text into token numbers, through the assembly half, with the two refusals
-- an engine can meet: a byte the vocabulary cannot say, and a token number
-- the weights do not know. The second means the tokenizer table and the
-- model disagree about how many words exist -- a broken image, said plainly,
-- rather than an embedding read past its edge.
function M.encode(loop, text)
  local capacity = math.max(#text, 1)
  local bytes = ffi.new("uint8_t[?]", capacity)
  ffi.copy(bytes, text, #text)
  local numbers = ffi.new("int32_t[?]", capacity)
  local answer = tonumber(loop.kernels.tokenizer_encode(
    loop.tokenizer.plan, bytes, #text, numbers))
  if answer < 0 then
    return nil, "no token for the byte at position " .. (-answer)
  end

  local out = {}
  for index = 0, answer - 1 do
    local token = numbers[index]
    if token >= loop.model.shape.vocabulary then
      return nil, "the tokenizer says " .. token .. " but the weights only know "
        .. loop.model.shape.vocabulary .. " tokens -- the table and the model disagree"
    end
    out[index + 1] = token
  end
  return out
end
-- }}}

-- {{{ M.decode(loop, numbers)
function M.decode(loop, numbers)
  local count = #numbers
  local packed = ffi.new("int32_t[?]", math.max(count, 1))
  for index = 1, count do packed[index - 1] = numbers[index] end
  -- room for the longest possible answer: every token's text, end to end,
  -- cannot exceed the whole packed text of the vocabulary per token.
  local room = ffi.new("uint8_t[?]", math.max(count, 1) * math.max(loop.tokenizer.longest, 1))
  local wrote = tonumber(loop.kernels.tokenizer_decode(
    loop.tokenizer.plan, packed, count, room))
  if wrote < 0 then
    return nil, "no token numbered at position " .. (-wrote)
  end
  return ffi.string(room, wrote)
end
-- }}}

-- {{{ local function replay(loop, wanted)
-- Lays a token list into the cache, reusing the longest common prefix of
-- what is already there. Returns how far the cache now reaches, or refuses
-- when the list is longer than the machine can hold.
local function replay(loop, wanted)
  local shape = loop.model.shape
  if #wanted > shape.context then
    return nil, "the context is " .. #wanted .. " tokens and the machine holds "
      .. shape.context
  end

  local common = 0
  while common < #wanted and loop.known[common + 1] == wanted[common + 1] do
    common = common + 1
  end
  -- a divergence means every later position was thought over different
  -- ground; those cache rows are simply overwritten as the replay walks.
  for position = common, #wanted - 1 do
    loop.kernels.forward_conduct(loop.conductor.plan, wanted[position + 1],
                                 position, loop.logits)
    loop.forward_calls = loop.forward_calls + 1
    loop.have_logits = true
  end
  loop.known = wanted
  return #wanted
end
-- }}}

-- {{{ M.think(loop, request, limits)
--
-- One turn: the request joins the context as an atom, the whole context is
-- laid into the cache, and the machine speaks until something stops it.
--
-- limits: max_tokens (default: whatever room is left), interrupt (a function
-- asked between tokens; answering true stops the thought).
--
-- Returns { text, tokens, reason, position }, where reason is one of
-- "finished", "length", "interrupted", "the room ran out" -- or nil and an
-- error when the machine cannot think at all.
function M.think(loop, request, limits)
  limits = limits or {}
  local atoms = loop.atoms

  if request and #request > 0 then
    local counted, why = M.encode(loop, request)
    if not counted then return nil, why end
    atoms.add(loop.context, { topic = "request", content = request,
                              tokens = #counted, origin = "handed in from outside" })
  end

  local whole = atoms.concatenate(loop.context)
  local tokens, trouble = M.encode(loop, whole)
  if not tokens then return nil, trouble end
  if #tokens == 0 then
    return nil, "there is nothing in the context to think over"
  end

  local position, refusal = replay(loop, tokens)
  if not position then return nil, refusal end

  local shape = loop.model.shape
  local spoken = {}
  local reason = nil
  local max_tokens = limits.max_tokens or (shape.context - position)

  while true do
    if max_tokens <= #spoken then reason = "length" break end

    local token = tonumber(loop.kernels.sampler_choose(
      loop.chooser.plan, loop.logits, shape.vocabulary, loop.chance))

    if token == loop.finish_token then
      reason = "finished"
      break
    end

    spoken[#spoken + 1] = token

    if limits.interrupt and limits.interrupt(#spoken) then
      reason = "interrupted"
      break
    end
    if position >= shape.context then
      -- the honest answer: the machine has thought for as long as it can
      -- hold. What to let go of is the context mechanism's question (052),
      -- and it is the machine's to answer, not this loop's.
      reason = "the room ran out"
      break
    end

    loop.kernels.forward_conduct(loop.conductor.plan, token, position, loop.logits)
    loop.forward_calls = loop.forward_calls + 1
    position = position + 1
    loop.known[#loop.known + 1] = token
  end

  local text = ""
  if #spoken > 0 then
    local decoded, trouble_back = M.decode(loop, spoken)
    if not decoded then return nil, trouble_back end
    text = decoded
    atoms.add(loop.context, { topic = "spoken", content = text,
                              tokens = #spoken, origin = "written by the machine" })
  end

  return { text = text, tokens = spoken, reason = reason, position = position }
end
-- }}}

return M
