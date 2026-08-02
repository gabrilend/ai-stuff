#!/usr/bin/env luajit
-- 053-test-context.lua
--
-- Checks the atom context, and mostly checks the properties that make it worth
-- having rather than the operations that are obviously right.
--
-- usage:
--   luajit 053-test-context.lua [--dir ROOT]

-- {{{ DIR -- the project root, hard-coded, overridable by --dir
local DIR = "/mnt/mtwo/programming/ai-stuff/every-software-image-able"
-- }}}

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

-- {{{ main
local index = 1
while index <= #arg do
  if arg[index] == "--dir" then index = index + 1 ; DIR = arg[index] end
  index = index + 1
end

local context_module = dofile(DIR .. "/src/052-atom-context.lua")

say("")
say("  what the machine is thinking with")
say("  " .. string.rep("-", 58))
say("")

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

-- {{{ a machine waking up
local context = context_module.new({ budget = 100 })
context_module.boot(context, {
  { topic = "what to do first", content = "find memory", tokens = 10,
    origin = "carried on the chip" },
  { topic = "what will kill you", content = "not the voltage register", tokens = 10,
    origin = "carried on the chip" },
  { topic = "how to ask for anything else", content = "say what you want", tokens = 10,
    origin = "carried on the chip" },
})

check("a machine wakes holding what it was given",
      #context_module.enumerate(context) == 3)
check("and knows how much room it has left",
      context_module.room_left(context) == 70,
      "room left came to " .. context_module.room_left(context))
-- }}}

-- {{{ the rule
-- The context is the concatenation of the resident atoms and nothing else. If
-- anything else were in there -- a preamble, a frame, a separator nobody named
-- -- then the machine could not account for what it is thinking with.
local whole = context_module.concatenate(context)
local rebuilt = {}
for _, entry in ipairs(context_module.enumerate(context)) do
  rebuilt[#rebuilt + 1] = context.atoms[entry.number].content
end
check("the context is exactly its atoms, joined",
      whole == table.concat(rebuilt, "\n"),
      "something is in the context that is not an atom")
-- }}}

-- {{{ choosing
local working = context_module.add(context, {
  topic = "the allocator I am writing", content = "a first draft", tokens = 40,
})
check("adding something reduces the room left",
      context_module.room_left(context) == 30)

context_module.drop(context, working)
check("dropping it gives the room back",
      context_module.room_left(context) == 70)

check("a dropped atom is still findable",
      #context_module.find(context, "allocator") == 1,
      "an atom that cannot be found again was not dropped, it was lost")

context_module.carry_forward(context, working)
check("and can be picked up again", context_module.room_left(context) == 30)
-- }}}

-- {{{ merging
local first = context_module.add(context, { topic = "a note", content = "one", tokens = 5 })
local second = context_module.add(context, { topic = "another", content = "two", tokens = 5 })
local merged = context_module.merge(context, first, second, "both notes")

check("merging two atoms leaves one resident",
      context.atoms[merged].resident
        and not context.atoms[first].resident
        and not context.atoms[second].resident)

check("the merged atom records what it came from",
      #context.atoms[merged].derived_from == 2,
      "without that, merging is amnesia")

-- The numbers of the originals must keep meaning what they meant. Reusing
-- them would leave anything that referred to them pointing at a different
-- subject, which is worse than pointing at nothing.
local after = context_module.add(context, { topic = "later", content = "x", tokens = 1 })
check("a merged-away atom's number is never reused",
      after ~= first and after ~= second and context.atoms[first].topic == "a note")
-- }}}

-- {{{ editing
context_module.replace(context, merged, { content = "one and two, tidied", tokens = 4 })
check("an edited atom keeps its number",
      context.atoms[merged].content == "one and two, tidied",
      "whatever referred to it meant the subject, not the wording")
-- }}}

-- {{{ running out
local tight = context_module.new({ budget = 50 })
context_module.boot(tight, {
  { topic = "what to do first", content = "find memory", tokens = 20,
    origin = "carried on the chip" },
})
context_module.add(tight, { topic = "scratch", content = "a", tokens = 20 })
context_module.add(tight, { topic = "more scratch", content = "b", tokens = 10 })

local freed = context_module.make_room(tight, 25)
check("making room lets go of something", #freed > 0)
check("and never lets go of what was carried on the chip",
      tight.atoms[1].resident,
      "the instruction and the explanation of this mechanism are in there")
check("and says how many it had to let go", tight.dropped == #freed)

-- Everything undroppable and still not enough room is a refusal, not a
-- silent success. A machine that believes it made room and did not will
-- overrun without noticing.
local stuck = context_module.new({ budget = 10 })
context_module.boot(stuck, {
  { topic = "instruction", content = "x", tokens = 10, origin = "carried on the chip" },
})
local nothing_freed = context_module.make_room(stuck, 5)
check("when nothing may be let go, nothing is", #nothing_freed == 0)
check("and the room left says so plainly", context_module.room_left(stuck) == 0)
-- }}}

-- {{{ the uncomfortable one
-- The initialising set is a list of atoms and it is mutable, so a machine can
-- change what it wakes up believing -- including the prohibitions. This is
-- true by design and is tested so that nobody later assumes it is not.
local brakes = context_module.new({ budget = 100 })
context_module.boot(brakes, {
  { topic = "what will kill you", content = "not the voltage register", tokens = 10,
    origin = "carried on the chip" },
})
context_module.replace(brakes, 1, { content = "go right ahead" })
check("a machine can edit its own prohibitions",
      brakes.atoms[1].content == "go right ahead",
      "this is deliberate -- nothing here prevents it, and docs/013 says why")
-- }}}

say("")
say("  " .. string.rep("-", 58))
say("  " .. passed .. " of " .. (passed + failed) .. " as expected")
say("")
say("  the seam left open:")
say("    writing an atom out to storage and recalling it. Storage does not")
say("    exist in this phase, so an atom that is dropped is gone. Issue 304")
say("    closes it.")
say("")

run_one("mkdir -p " .. DIR .. "/output")
local goodbye = io.open(DIR .. "/output/goodbye", "w")
if goodbye then
  goodbye:write("context: " .. passed .. " of " .. (passed + failed)
                .. " as expected\ngoodbye\n")
  goodbye:close()
end

os.exit(failed == 0 and 0 or 1)
-- }}}
