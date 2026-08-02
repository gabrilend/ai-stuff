#!/usr/bin/env luajit
-- 065-test-the-hands.lua
--
-- Checks the boundary between thinking and doing: that the door and the
-- catalogue really are one object, that every refusal is a sentence a
-- machine could act on, that a large answer does not cross into a context
-- that cannot hold it, and that a real thinking machine asking for something
-- gets it and carries on.
--
-- For a general: this is where the machine's hands are tested before any of
-- them touch anything. The hands here are pretend -- they add numbers and
-- echo text -- because what is being checked is the shape of asking, not
-- what any particular hand does.
--
-- usage:
--   luajit 065-test-the-hands.lua [--dir ROOT]

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

say("")
say("  asking for something, and being answered")
say("  " .. string.rep("-", 58))
say("")

local hands = dofile(DIR .. "/src/064-the-hands.lua")

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

-- {{{ a catalogue with pretend hands
local function fresh(options)
  local catalogue = hands.new(options)
  hands.offer_the_catalogue(catalogue)
  hands.offer(catalogue, {
    name = "add", takes = { "a", "b" }, gives = "a number",
    note = "adds two numbers",
    does = function(arguments)
      local a, b = tonumber(arguments[1]), tonumber(arguments[2])
      if not a or not b then return nil, "both must be numbers" end
      return tostring(a + b)
    end,
  })
  hands.offer(catalogue, {
    name = "shout", takes = { "word" }, gives = "text",
    does = function(arguments) return arguments[1]:upper() end,
  })
  hands.offer(catalogue, {
    name = "flood", takes = {}, gives = "a great deal of text",
    does = function() return string.rep("x", 100000) end,
  })
  hands.offer(catalogue, {
    name = "unplug", takes = {}, gives = "nothing good", dangerous = true,
    note = "the sort of thing that ends a board",
    does = function() return "the board is gone" end,
  })
  hands.offer(catalogue, {
    name = "trip", takes = {}, gives = "text",
    does = function() error("a hand that came apart") end,
  })
  return catalogue
end

local catalogue = fresh()
-- }}}

-- {{{ the door and the catalogue are one object
local listed = hands.catalogue_text(catalogue)
local every_hand_listed = true
for _, name in ipairs(catalogue.order) do
  if not listed:find(name, 1, true) then every_hand_listed = false end
end
check("every hand that exists is in the catalogue", every_hand_listed)

-- and the catalogue is reached the same way as anything else
local asked = hands.find(catalogue, "let me see: <call hands> please")
local answer = hands.answer(catalogue, asked)
check("the catalogue is reached by asking for it",
      answer.ok and answer.text == listed)

-- adding a hand widens the door from inside, and shows up immediately
hands.offer(catalogue, { name = "invented", takes = {},
                         does = function() return "made later" end })
check("a hand offered later appears without anything being rebuilt",
      hands.catalogue_text(catalogue):find("invented", 1, true) ~= nil)
-- }}}

-- {{{ the parser
local found = hands.find(catalogue, "thinking... <call add 2 3> ...more")
check("a call is found in a stretch of thinking",
      found ~= nil and found.name == "add"
      and found.arguments[1] == "2" and found.arguments[2] == "3")

check("text with no call in it finds none",
      hands.find(catalogue, "just thinking out loud") == nil)

local first = hands.find(catalogue, "<call shout one> then <call shout two>")
check("the first call is the one found",
      first ~= nil and first.arguments[1] == "one")
-- }}}

-- {{{ every refusal is a sentence, and no hand moved
local function refusal_for(text)
  return hands.answer(catalogue, hands.find(catalogue, text))
end

local nameless = refusal_for("<call >")
check("a call with no name is refused, not guessed at",
      nameless ~= nil and not nameless.ok
      and nameless.text:find("did not parse") ~= nil, nameless and nameless.text)

local unknown = refusal_for("<call fly>")
check("an unknown hand is refused, and says where to look",
      not unknown.ok and unknown.text:find("hands") ~= nil, unknown.text)

local miscounted = refusal_for("<call add 2>")
check("a call with the wrong count is refused, naming the count",
      not miscounted.ok and miscounted.text:find("takes 2") ~= nil, miscounted.text)

local bad_arguments = refusal_for("<call add two three>")
check("a hand that cannot do it says why",
      not bad_arguments.ok and bad_arguments.text:find("must be numbers") ~= nil,
      bad_arguments.text)

local came_apart = refusal_for("<call trip>")
check("a hand that comes apart does not take the thought with it",
      not came_apart.ok and came_apart.text:find("came apart") ~= nil,
      came_apart.text)

check("and all of those were counted as refusals", catalogue.refusals == 5,
      "counted " .. catalogue.refusals)
check("and none of them moved a hand", catalogue.hands.add.used == 1,
      "add moved " .. catalogue.hands.add.used .. " times")
-- }}}

-- {{{ dangerous hands are refused until opened, and opening is separate
local dangerous = refusal_for("<call unplug>")
check("a dangerous hand is refused by default",
      not dangerous.ok and dangerous.text:find("refused by default") ~= nil,
      dangerous.text)
check("and the catalogue says so where the machine can read it",
      hands.catalogue_text(catalogue):find("dangerous, refused") ~= nil)

local no_confirmation = select(2, hands.open(catalogue, "unplug", nil))
check("opening it needs a confirmed description",
      no_confirmation ~= nil and no_confirmation:find("confirmed") ~= nil,
      no_confirmation)

hands.open(catalogue, "unplug", "the description, read and confirmed")
local opened = refusal_for("<call unplug>")
check("once opened, it moves", opened.ok and opened.text == "the board is gone")

local nothing_to_open = select(2, hands.open(catalogue, "add", "anything"))
check("opening a hand that was never refused says so",
      nothing_to_open ~= nil and nothing_to_open:find("nothing to open") ~= nil,
      nothing_to_open)
-- }}}

-- {{{ an answer too large to hold
local unread = fresh()
local flooded = hands.answer(unread, hands.find(unread, "<call flood>"))
check("a huge answer is refused rather than truncated",
      not flooded.ok and flooded.text:find("100000") ~= nil, flooded.text)

-- with a reader, it crosses as something small, and says it was read
local with_reader = fresh({
  reader = function(whole, call)
    return "read " .. #whole .. " characters of what '" .. call.name
      .. "' said; the useful part is: xxx"
  end,
})
local read = hands.answer(with_reader, hands.find(with_reader, "<call flood>"))
check("with a reader, only the useful part crosses",
      read.ok and read.read and #read.text < 200 and read.whole_length == 100000,
      read.text)
-- }}}

-- {{{ the grammar is swappable, and nothing above assumed one
local curly = {
  name = "curly",
  find = function(text)
    local from, to, body = text:find("{([^{}]*)}")
    if not from then return nil end
    local words = {}
    for word in body:gmatch("%S+") do words[#words + 1] = word end
    if #words == 0 then return { malformed = "empty", from = from, to = to } end
    local name = table.remove(words, 1)
    return { name = name, arguments = words, from = from, to = to }
  end,
  render = function(result) return "[" .. result.name .. ": " .. result.text .. "]" end,
}
local other = fresh({ grammar = curly })
local in_curly = hands.answer_text(other, hands.find(other, "so {add 20 22} then"))
check("another model's grammar works with the same hands",
      in_curly == "[add: 42]", in_curly)
check("and the old grammar's calls mean nothing to it",
      hands.find(other, "<call add 1 2>") == nil)
-- }}}

-- {{{ a real thinking machine asks for something and is answered
-- Everything above is the boundary alone. This is the boundary in place: a
-- machine whose thought is interrupted at the closing mark, whose hand
-- moves, and whose answer joins the context as its own atom before another
-- token is drawn.
local emit_kernels = dofile(DIR .. "/src/043-emit-kernels.lua")
local arch = host_architecture()
if emit_kernels[arch] then
  run_one("mkdir -p " .. DIR .. "/tmp/shared-memory/kernels")
  run_one("mkdir -p " .. DIR .. "/tmp/kernels")

  local specification = dofile(DIR .. "/src/047-reference-exp.lua")
  local conduct = dofile(DIR .. "/src/056-emit-conductor.lua")
  local sampler = dofile(DIR .. "/src/057-emit-sampler.lua")
  local tokenizer = dofile(DIR .. "/src/059-emit-tokenizer.lua")

  local pieces = {
    { "kernels-" .. arch .. ".s", emit_kernels.source(arch, specification) },
    { "conductor-" .. arch .. ".s", conduct[arch]() },
    { "sampler-" .. arch .. ".s", sampler[arch]() },
    { "tokenizer-" .. arch .. ".s", tokenizer[arch]() },
  }
  local paths = {}
  for _, piece in ipairs(pieces) do
    local path = DIR .. "/tmp/shared-memory/kernels/" .. piece[1]
    local handle = io.open(path, "w")
    handle:write(piece[2])
    if not piece[2]:find("GNU%-stack") then
      handle:write('  .section .note.GNU-stack,"",@progbits\n')
    end
    handle:close()
    paths[#paths + 1] = path
  end

  local library = DIR .. "/tmp/kernels/engine-" .. arch .. ".so"
  if run_one("clang -shared -o " .. library .. " " .. table.concat(paths, " ")) then
    dofile(DIR .. "/src/049-assembly-forward.lua").declare()
    conduct.declare()
    sampler.declare()
    tokenizer.declare()
    local kernels = ffi.load(library)

    local format = dofile(DIR .. "/src/024-blob-format.lua")
    local reference = dofile(DIR .. "/src/035-reference-forward.lua")
    local blob_path = DIR .. "/tmp/shared-memory/fixture/fixture-model.blob"
    local blob_file = io.open(blob_path, "rb")
    if not blob_file then
      run_one("luajit " .. DIR .. "/src/036-make-fixture.lua --dir " .. DIR .. " > /dev/null")
      blob_file = io.open(blob_path, "rb")
    end
    local blob = blob_file:read("*a")
    blob_file:close()
    local model = reference.load(blob, format)

    -- A vocabulary the model's own numbers cover, with the call's characters
    -- among them: the fixture holds 48 tokens, so bytes 0..47 plus the few
    -- letters the grammar needs, mapped into that range.
    local tokens = {}
    for byte = 0, model.shape.vocabulary - 1 do
      tokens[#tokens + 1] = string.char(byte)
    end

    -- A call has to come out of the MACHINE's mouth, not the request -- a
    -- call in a request is somebody else asking, and answering it would let
    -- anything that talks to the machine move its hands directly.
    --
    -- A model whose weights are arbitrary numbers will not write a grammar
    -- on purpose, so the grammar is fitted to it instead: the machine speaks
    -- once with no hands at all, and whatever byte it said first becomes the
    -- asking. Deterministic, so the same byte comes out again.
    local loop_module = dofile(DIR .. "/src/061-thinking-loop.lua")
    local sampler_reference = dofile(DIR .. "/src/040-reference-sampler.lua")

    local function build_loop(catalogue)
      return loop_module.new({
        model = model, kernels = kernels, conduct = conduct, sampler = sampler,
        tokenizer = tokenizer, tables = { tokens = tokens, merges = {} },
        carried = sampler_reference.generate_file(20260802, 64),
        settings = { temperature = 1.0 },
        hands = catalogue,
      })
    end

    local listener = build_loop(nil)
    local overheard = loop_module.think(listener, "\1\2\3", { max_tokens = 1 })
    local asking_byte = overheard and overheard.text:sub(1, 1)

    local function byte_grammar()
      return {
        name = "one byte",
        find = function(text)
          local at = text:find(asking_byte, 1, true)
          if not at then return nil end
          return { name = "beep", arguments = {}, from = at, to = at }
        end,
        -- the answer is written in bytes this vocabulary can say, and in
        -- none that would be mistaken for another asking.
        render = function(result) return "\4" .. result.text .. "\5" end,
      }
    end

    local moved = { count = 0 }
    local live = hands.new({ grammar = byte_grammar() })
    hands.offer(live, {
      name = "beep", takes = {}, gives = "a short sound",
      does = function()
        moved.count = moved.count + 1
        return "\6\7"
      end,
    })

    local loop = build_loop(live)
    local exchange, trouble = loop_module.converse(loop, "\1\2\3",
                                                   { max_tokens = 3, max_calls = 2 })
    check("a machine that asks for something gets it",
          exchange ~= nil and moved.count >= 1,
          trouble or (asking_byte and ("it never said byte "
            .. string.byte(asking_byte)) or "it said nothing at all"))

    if exchange then
      local carried_back = false
      for _, atom in ipairs(loop.atoms.enumerate(loop.context)) do
        if atom.topic == "answer to beep" then carried_back = true end
      end
      check("and the answer is an atom in its own right", carried_back)
      check("and the exchange says how many hands moved",
            exchange.calls == moved.count,
            tostring(exchange.calls) .. " against " .. moved.count)
    end

    -- {{{ a call in a request is not the machine asking
    -- Somebody else's words must never move the machine's hands: that is
    -- the difference between a machine with hands and a machine anyone can
    -- reach through.
    local overheard_count = { count = moved.count }
    local quiet = hands.new({ grammar = byte_grammar() })
    local outsider_moved = false
    hands.offer(quiet, { name = "beep", takes = {},
                         does = function() outsider_moved = true return "\6" end })
    local guarded = build_loop(quiet)
    -- the request is nothing BUT an asking, and the machine is given no room
    -- to speak, so anything that moves was moved from outside.
    loop_module.converse(guarded, asking_byte, { max_tokens = 0, max_calls = 2 })
    check("a call in a request moves nothing", not outsider_moved)
    -- }}}

    -- A machine that asks forever is stopped, and told. Making it truly
    -- endless takes a grammar that reads ANY speech as an asking -- the
    -- machine's own words vary turn to turn, and a bound that only holds
    -- for a cooperative machine is not a bound.
    local endless = hands.new({
      grammar = {
        name = "everything is a call",
        find = function(text)
          if #text == 0 then return nil end
          return { name = "beep", arguments = {}, from = 1, to = 1 }
        end,
        render = function(result) return "\4" .. result.text .. "\5" end,
      },
    })
    hands.offer(endless, { name = "beep", takes = {},
                           does = function() return "\6" end })
    local spinner = build_loop(endless)
    local spun = loop_module.converse(spinner, "\1\2\3",
                                      { max_tokens = 3, max_calls = 3 })
    check("a machine asking forever is stopped, and told",
          spun ~= nil and spun.reason == "too many hands in one exchange"
          and spun.calls == 3,
          spun and (spun.reason .. ", " .. spun.calls .. " calls"))
  end
else
  say("  (no engine for " .. arch .. "; the live exchange was not run)")
end
-- }}}

say("")
say("  " .. string.rep("-", 58))
say("  " .. passed .. " of " .. (passed + failed) .. " as expected")
say("")
say("  what this does not settle:")
say("    - the call format for any particular model. That is chosen against")
say("      whichever model is in front of you, which is why the grammar is")
say("      swappable and why it is tested per model rather than once.")
say("    - a call that never returns. The hands that can hang are the ones")
say("      that touch hardware (205), and giving up on one is their ticket.")
say("")

run_one("mkdir -p " .. DIR .. "/output")
local goodbye = io.open(DIR .. "/output/goodbye", "w")
if goodbye then
  goodbye:write("the hands: " .. passed .. " of " .. (passed + failed)
                .. " as expected\ngoodbye\n")
  goodbye:close()
end

os.exit(failed == 0 and 0 or 1)
-- }}}
