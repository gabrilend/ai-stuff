#!/usr/bin/env luajit
-- 062-test-thinking-loop.lua
--
-- Closes the loop and checks what stops it. Text becomes tokens, tokens run
-- through the assembly engine, a token is drawn and joins the input -- and
-- each of the four stoppers is exercised by name, because a machine that
-- cannot be stopped cannot be told to stop doing something.
--
-- For a general: every part of the engine was proven alone against a
-- readable twin. This proves they are one machine: it can be spoken to, it
-- speaks back, it does not redo thinking it has already done, and it stops
-- when told, when finished, and when it runs out of room -- saying which.
--
-- The model is the tiny fixture model, whose words are numbers rather than
-- English. The loop neither knows nor cares; what is tested here is the
-- machinery of thought, not its quality.
--
-- usage:
--   luajit 062-test-thinking-loop.lua [--dir ROOT]

-- {{{ DIR -- the project root, hard-coded, overridable by --dir
local DIR = "/mnt/mtwo/programming/ai-stuff/every-software-image-able"
-- }}}

local ffi = require("ffi")

-- {{{ local function say(text)
local function say(text)
  io.write(text, "\n")
  io.flush()
end
-- }}}

-- {{{ local function run_one(command)
local function run_one(command)
  local ok, _, code = os.execute(command)
  return (ok == true or ok == 0), code
end
-- }}}

-- {{{ local function host_architecture()
local function host_architecture()
  local pipe = io.popen("uname -m")
  local name = pipe and pipe:read("*l") or "unknown"
  if pipe then pipe:close() end
  return name
end
-- }}}

-- {{{ main
local index = 1
while index <= #arg do
  if arg[index] == "--dir" then index = index + 1 ; DIR = arg[index] end
  index = index + 1
end

local arch = host_architecture()

say("")
say("  the loop, closed, and its four stoppers")
say("  " .. string.rep("-", 58))
say("")

-- {{{ build one library holding the whole engine
local emit_kernels = dofile(DIR .. "/src/043-emit-kernels.lua")
if not emit_kernels[arch] then
  say("  no engine for " .. arch .. ". Nothing was tested, which is not the")
  say("  same as nothing being wrong.")
  os.exit(1)
end

run_one("mkdir -p " .. DIR .. "/tmp/shared-memory/kernels")
run_one("mkdir -p " .. DIR .. "/tmp/kernels")

local specification = dofile(DIR .. "/src/047-reference-exp.lua")
local conduct = dofile(DIR .. "/src/056-emit-conductor.lua")
local sampler = dofile(DIR .. "/src/057-emit-sampler.lua")
local tokenizer = dofile(DIR .. "/src/059-emit-tokenizer.lua")

local sources = {
  { path = "kernels-" .. arch .. ".s", text = emit_kernels.source(arch, specification) },
  { path = "conductor-" .. arch .. ".s", text = conduct[arch]() },
  { path = "sampler-" .. arch .. ".s", text = sampler[arch]() },
  { path = "tokenizer-" .. arch .. ".s", text = tokenizer[arch]() },
}
local paths = {}
for _, source in ipairs(sources) do
  local path = DIR .. "/tmp/shared-memory/kernels/" .. source.path
  local handle = io.open(path, "w")
  handle:write(source.text)
  if not source.text:find("GNU%-stack") then
    handle:write('  .section .note.GNU-stack,"",@progbits\n')
  end
  handle:close()
  paths[#paths + 1] = path
end

local library = DIR .. "/tmp/kernels/engine-" .. arch .. ".so"
if not run_one("clang -shared -o " .. library .. " " .. table.concat(paths, " ")) then
  say("  the engine would not assemble")
  os.exit(1)
end

dofile(DIR .. "/src/049-assembly-forward.lua").declare()
conduct.declare()
sampler.declare()
tokenizer.declare()
local kernels = ffi.load(library)
-- }}}

-- {{{ the model, and a vocabulary the loop can carry text in with
local format = dofile(DIR .. "/src/024-blob-format.lua")
local reference = dofile(DIR .. "/src/035-reference-forward.lua")

local blob_path = DIR .. "/tmp/shared-memory/fixture/fixture-model.blob"
local blob_file = io.open(blob_path, "rb")
if not blob_file then
  say("  building the fixture model first")
  run_one("luajit " .. DIR .. "/src/036-make-fixture.lua --dir " .. DIR .. " > /dev/null")
  blob_file = io.open(blob_path, "rb")
end
local blob = blob_file:read("*a")
blob_file:close()
local model = reference.load(blob, format)

-- The fixture's own vocabulary is placeholder names, not text. The loop is
-- being tested as machinery, so it gets a byte vocabulary whose first
-- thirty-two tokens are the only bytes the prompts below use -- every token
-- number the tokenizer can produce from them is a token the weights know.
local tokenizer_reference = dofile(DIR .. "/src/038-reference-tokenizer.lua")
local vocabulary_size = model.shape.vocabulary
local tokens = {}
for byte = 0, vocabulary_size - 1 do tokens[#tokens + 1] = string.char(byte) end
local tables = { tokens = tokens, merges = {} }

-- prompts written in the bytes the model knows: 0 to 31.
local function prompt_of(numbers)
  local parts = {}
  for _, byte in ipairs(numbers) do parts[#parts + 1] = string.char(byte) end
  return table.concat(parts)
end

local loop_module = dofile(DIR .. "/src/061-thinking-loop.lua")
local sampler_reference = dofile(DIR .. "/src/040-reference-sampler.lua")
local carried = sampler_reference.generate_file(20260802, 64)

local function fresh_loop(extra)
  local options = {
    model = model,
    kernels = kernels,
    conduct = conduct,
    sampler = sampler,
    tokenizer = tokenizer,
    tables = tables,
    carried = carried,
    settings = { temperature = 1.0 },
  }
  for key, value in pairs(extra or {}) do options[key] = value end
  return loop_module.new(options)
end
-- }}}

local passed, failed = 0, 0
local function check(what, ok, detail)
  if ok then
    passed = passed + 1
    say(string.format("  %-50s ok", what))
  else
    failed = failed + 1
    say(string.format("  %-50s WRONG", what))
    if detail then say("      " .. detail) end
  end
end

-- The fixture model holds sixteen positions, so the arithmetic below is
-- tight on purpose: five for the prompt, six spoken, and room left over for
-- a second thought.
local prompt = prompt_of({ 1, 3, 5, 7, 2 })

-- {{{ the loop closes: text in, text out, and it lands in the context
local loop = fresh_loop()
local thought, trouble = loop_module.think(loop, prompt, { max_tokens = 6 })
check("text goes in and text comes back", thought ~= nil and #thought.tokens == 6,
      trouble or (thought and ("got " .. #thought.tokens .. " tokens")))
check("and it stopped for the stated reason", thought and thought.reason == "length",
      thought and thought.reason)

local atoms = loop.atoms.enumerate(loop.context)
local request_seen, spoken_seen = false, false
for _, atom in ipairs(atoms) do
  if atom.topic == "request" then request_seen = true end
  if atom.topic == "spoken" then spoken_seen = true end
end
check("what was said and heard are both atoms", request_seen and spoken_seen)

local rebuilt = loop.atoms.concatenate(loop.context)
check("the context is exactly the conversation",
      rebuilt == prompt .. thought.text)
-- }}}

-- {{{ determinism: the same machine twice says the same thing
local again = fresh_loop()
local repeated = loop_module.think(again, prompt, { max_tokens = 6 })
local same = repeated ~= nil and #repeated.tokens == #thought.tokens
if same then
  for position = 1, #thought.tokens do
    if thought.tokens[position] ~= repeated.tokens[position] then same = false end
  end
end
check("the same machine twice says the same thing", same)
-- }}}

-- {{{ the cache is reused rather than recomputed
local before = again.forward_calls
local continued, continued_trouble =
  loop_module.think(again, prompt_of({ 4, 6 }), { max_tokens = 2 })
local new_work = again.forward_calls - before
-- the second thought adds two request tokens and two spoken ones; the reuse
-- claim is that the work is those plus at most one boundary re-merge, not
-- the whole conversation again.
check("a second thought does not rethink the first",
      continued ~= nil and new_work <= 2 + 2 + 1,
      continued_trouble or ("replayed " .. new_work .. " positions"))

-- and the reused cache gives the same answer a fresh machine would compute:
-- the invariant that caught real defects in 037 and 050, applied to the loop.
local replayed = fresh_loop()
local whole_conversation = replayed.atoms.concatenate(again.context)
local everything = loop_module.encode(replayed, whole_conversation)
local scratch_logits = ffi.new("float[?]", model.shape.vocabulary)
for position = 0, #everything - 1 do
  kernels.forward_conduct(replayed.conductor.plan, everything[position + 1],
                          position, scratch_logits)
end
local agree = true
for slot = 0, model.shape.vocabulary - 1 do
  if scratch_logits[slot] ~= again.logits[slot] then agree = false end
end
check("the reused cache answers as a fresh one would", agree)
-- }}}

-- {{{ the other three stoppers
local finish = thought.tokens[1]
local finishing = fresh_loop({ finish_token = finish })
local finished = loop_module.think(finishing, prompt, { max_tokens = 6 })
check("a finish token stops it and is swallowed",
      finished ~= nil and finished.reason == "finished" and #finished.tokens == 0,
      finished and (finished.reason .. " after " .. #finished.tokens))

local interrupting = fresh_loop()
local interrupted = loop_module.think(interrupting, prompt, {
  max_tokens = 50,
  interrupt = function(spoken) return spoken >= 3 end,
})
check("an interruption stops it between tokens",
      interrupted ~= nil and interrupted.reason == "interrupted"
      and #interrupted.tokens == 3,
      interrupted and (interrupted.reason .. " after " .. #interrupted.tokens))

local crowded = fresh_loop()
local crowded_thought = loop_module.think(crowded, prompt, { max_tokens = 50 })
check("a thought that outgrows the room says so",
      crowded_thought ~= nil and crowded_thought.reason == "the room ran out"
      and crowded_thought.position == model.shape.context,
      crowded_thought and (crowded_thought.reason .. " at " .. crowded_thought.position))

local full = loop_module.think(crowded, prompt_of({ 9 }), { max_tokens = 2 })
check("and a full context refuses more, naming the numbers",
      full == nil,
      "a full machine accepted another request")
-- }}}

-- {{{ the refusals an engine can meet
local unsayable = fresh_loop()
local no_token = select(2, loop_module.think(unsayable, "the letter A is byte 65", {}))
check("a byte outside the vocabulary is refused",
      no_token ~= nil and no_token:find("no token") ~= nil, no_token)

-- a tokenizer that can say more than the model knows: the mismatch is
-- caught at the seam rather than read past the embedding's edge.
local wide_tokens = {}
for byte = 0, 255 do wide_tokens[#wide_tokens + 1] = string.char(byte) end
local mismatched = fresh_loop({ tables = { tokens = wide_tokens, merges = {} } })
local disagreement = select(2, loop_module.think(mismatched, "byte 200: \200", {}))
check("a table the weights disagree with is refused",
      disagreement ~= nil and disagreement:find("disagree") ~= nil, disagreement)
-- }}}

say("")
say("  " .. string.rep("-", 58))
say("  " .. passed .. " of " .. (passed + failed) .. " as expected")
say("")
say("  the seams left open:")
say("    - writing an atom out and recalling it waits for storage (304),")
say("      and loading the boot set from the image waits for the builder")
say("      (502). Hosted callers hand the boot atoms in directly.")
say("    - what to let go of when the room runs out is the machine's own")
say("      decision, made through the context operations (052), not a")
say("      policy of this loop.")
say("")

run_one("mkdir -p " .. DIR .. "/output")
local goodbye = io.open(DIR .. "/output/goodbye", "w")
if goodbye then
  goodbye:write("thinking loop: " .. passed .. " of " .. (passed + failed)
                .. " as expected\ngoodbye\n")
  goodbye:close()
end

os.exit(failed == 0 and 0 or 1)
-- }}}
