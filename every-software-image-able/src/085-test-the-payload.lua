#!/usr/bin/env luajit
-- 085-test-the-payload.lua
--
-- Checks what the machine wakes up holding, and that everything else can be
-- reached when it becomes relevant. Issues 301 through 304 together, since
-- the instruction, the patterns and the descriptions are only useful as the
-- payload they form.
--
-- The uncomfortable checks are here on purpose: the machine can rewrite what
-- it wakes up believing, including the prohibitions, and nothing prevents
-- it. That follows from everything about the machine being mutable, and a
-- test is where it stops being an assumption somebody might quietly build
-- against.
--
-- usage:
--   luajit 085-test-the-payload.lua [--dir ROOT]

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

-- {{{ local function read_file(path)
local function read_file(path)
  local handle = io.open(path, "rb")
  if not handle then return nil end
  local text = handle:read("*a")
  handle:close()
  return text
end
-- }}}

-- {{{ main
local index = 1
while index <= #arg do
  if arg[index] == "--dir" then index = index + 1 ; DIR = arg[index] end
  index = index + 1
end

say("")
say("  what it wakes up holding, and what it can reach")
say("  " .. string.rep("-", 58))
say("")

local patterns = dofile(DIR .. "/src/083-the-patterns.lua")
local descriptions = dofile(DIR .. "/src/082-the-descriptions.lua")
local payload_module = dofile(DIR .. "/src/084-the-payload.lua")
local context_module = dofile(DIR .. "/src/052-atom-context.lua")
local keep = dofile(DIR .. "/src/076-keep-something.lua")
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

local instruction = read_file(DIR .. "/assets/081-the-instruction.md")
if not instruction then
  say("  the instruction is not where it should be")
  os.exit(1)
end

-- {{{ the instruction says what it must, and does not say what it must not
check("the instruction gives the order that cannot be rearranged",
      instruction:find("cannot be rearranged") ~= nil
      and instruction:find("Find memory") ~= nil
      and instruction:find("Find somewhere to keep things") ~= nil
      and instruction:find("Find the rest of the body") ~= nil
      and instruction:find("Open the channels") ~= nil)

check("and marks the two prohibitions as different from everything else",
      instruction:find("Everything else in this document is a suggestion")
      ~= nil and instruction:find("cannot be undone by\nwriting more software")
      ~= nil)

check("and says what the machine is for, then stops",
      instruction:find("Build every piece of software") ~= nil
      and instruction:find("Grow first") ~= nil
      and instruction:find("do whatever you want to be doing") ~= nil)

-- Step five of the ticket, and the sharpest thing in it: say the atoms can be
-- rewritten, do NOT say what that could cost. A machine that derives the
-- danger understands it; one that was warned has only been handed a rule.
check("it says the instruction itself can be rewritten",
      instruction:find("rewrite them") ~= nil)
check("and does NOT warn what rewriting it could cost",
      instruction:find("purpose") == nil
      or instruction:find("lose your purpose") == nil,
      "the instruction pre-empts a discovery it should leave to the machine")

-- the four rungs, the status square, the interpreter and the condensing must
-- not appear as requirements -- they are patterns and belong in 303.
local prescribes = instruction:find("four rungs") or instruction:find("interpreter")
  or instruction:find("condens")
check("and does not prescribe the shapes that are only suggestions",
      prescribes == nil,
      "a shape from the pattern bundle is written here as a requirement")

check("and is short enough to sit beside actual work",
      #instruction < 8000, #instruction .. " characters")
-- }}}

-- {{{ every pattern says where it stops working
local all_complete, incomplete = true, nil
for _, name in ipairs(patterns.names()) do
  local entry = patterns.PATTERNS[name]
  for _, part in ipairs({ "what", "worked", "costs", "stops" }) do
    if not entry[part] or #entry[part] < 20 then
      all_complete = false
      incomplete = incomplete or (name .. " has no " .. part)
    end
  end
end
check("every pattern says what it costs and where it stops",
      all_complete, incomplete)

check("and each says out loud that it is a suggestion",
      patterns.as_text("dispatch-tables"):find("has done nothing wrong") ~= nil)

check("the pattern about patterns is carried too",
      patterns.PATTERNS["ask-do-not-schedule"] ~= nil)

check("and the calling convention is marked as the one agreement",
      patterns.as_text("the-calling-convention"):find("agreement rather than a "
        .. "suggestion") ~= nil)

check("and it carries what the flags defect taught",
      patterns.PATTERNS["the-calling-convention"].learned:find("hang") ~= nil)
-- }}}

-- {{{ every description is complete, and names its source
local descriptions_sound, description_trouble = true, nil
for name, description in pairs(descriptions.CARRIED) do
  local ok, why = descriptions.check(description)
  if not ok then
    descriptions_sound = false
    description_trouble = description_trouble or (name .. ": " .. why)
  end
end
check("every carried description has every section",
      descriptions_sound, description_trouble)

check("and names whose document it was transcribed from",
      descriptions.CARRIED.storage.source:find("transcribed") ~= nil)

check("and storage is carried, since moving in depends on it",
      descriptions.CARRIED.storage ~= nil)

check("and the waits are in the starting sequence, with reasons",
      descriptions.as_text(descriptions.CARRIED.storage):find("WAIT") ~= nil
      and descriptions.as_text(descriptions.CARRIED.storage):find("because")
        ~= nil)
-- }}}

-- {{{ confirmation reads, and a partial match fails
local touched = { count = 0 }
local function reading(device, offset, width)
  touched.count = touched.count + 1
  return device.registers_say and device.registers_say[offset] or 0
end

local right_part = { vendor = 0x8086, class_code = 0x01, subclass = 0x06,
                     interface = 0x01, revision = 2 }
local confirmed = descriptions.confirm(descriptions.CARRIED.storage,
                                       right_part, reading)
check("a description about this part confirms", confirmed == true)

local wrong_part = { class_code = 0x02, subclass = 0x06, interface = 0x01,
                     revision = 2 }
local refused = select(2, descriptions.confirm(descriptions.CARRIED.storage,
                                               wrong_part, reading))
check("one about a different part does not",
      refused ~= nil and refused:find("class_code") ~= nil, refused)

-- a partial match is a failure, not a near miss
local nearly = { class_code = 0x01, subclass = 0x06, interface = 0x02,
                 revision = 2 }
local near_miss = select(2, descriptions.confirm(descriptions.CARRIED.storage,
                                                 nearly, reading))
check("and a nearly-right one is a failure, not a near miss",
      near_miss ~= nil, "a partial match was treated as confirmation")

local out_of_range = { class_code = 0x01, subclass = 0x06, interface = 0x01,
                       revision = 2 }
local narrow = {}
for key, value in pairs(descriptions.CARRIED.storage) do narrow[key] = value end
narrow.revisions = { from = 5, to = 9 }
local revision_wrong = select(2, descriptions.confirm(narrow, out_of_range, reading))
check("a revision outside what the description covers is refused",
      revision_wrong ~= nil and revision_wrong:find("revision") ~= nil,
      revision_wrong)
-- }}}

-- {{{ the payload: what is held at boot, and what is not
local atoms = payload_module.build({
  instruction = instruction, patterns = patterns, descriptions = descriptions,
})
check("the payload is built out of atoms rather than one block",
      #atoms > 15, #atoms .. " atoms")

local context = context_module.new({ budget = 4096 })
local disk = (function()
  local contents = {}
  return { name = "disk", blocks = 4096, block_bytes = 512, writable = true,
           removable = false,
           read = function(block, count)
             local out = {}
             for offset = 0, count - 1 do
               out[#out + 1] = contents[block + offset] or string.rep("\0", 512)
             end
             return table.concat(out)
           end,
           write = function(block, text)
             for offset = 0, #text / 512 - 1 do
               contents[block + offset] = text:sub(offset * 512 + 1, (offset + 1) * 512)
             end
             return true
           end }
end)()
local store = keep.new({ devices = { disk } })

local payload = payload_module.new({
  context = context, context_module = context_module, atoms = atoms,
  store = store, keep = keep, on = "disk",
})

local resident, total = 0, 0
for _, entry in ipairs(payload_module.index(payload)) do
  total = total + 1
  if entry.resident then resident = resident + 1 end
end
check("only a few of them are held at boot",
      resident > 0 and resident < total / 2,
      resident .. " of " .. total .. " held")

check("and what is held includes the order and the prohibitions",
      payload_module.boot_set(payload):find("cannot be rearranged") ~= nil
      and payload_module.boot_set(payload):find("prohibitions") ~= nil)

check("and does not include the patterns or the devices",
      payload_module.boot_set(payload):find("pattern:") == nil
      and payload_module.boot_set(payload):find("device:") == nil)

check("what is held is exactly what the context holds",
      #context.order == resident, #context.order .. " against " .. resident)

-- Being held now and being in the boot set are different things, and they
-- move independently: fetching something does not change what the next start
-- wakes with, and changing the boot set does not disturb the thought in
-- progress. Reading one from the other made the boot set unchangeable.
local wakes = 0
for _, entry in ipairs(payload_module.index(payload)) do
  if entry.wakes_with then wakes = wakes + 1 end
end
check("what it holds and what it will wake with are separate",
      wakes == resident, wakes .. " in the boot set, " .. resident .. " held")

check("and every atom says where it came from",
      context.atoms[1].origin == "carried on the chip")
-- }}}

-- {{{ fetching, and what it costs
local before = context_module.room_left(context)
local fetched = payload_module.fetch(payload, "pattern: dispatch-tables")
check("something not held can be fetched", fetched ~= nil)
check("and holding it costs room the machine can see",
      context_module.room_left(context) < before,
      before .. " before, " .. context_module.room_left(context) .. " after")

local twice = select(2, payload_module.fetch(payload, "pattern: dispatch-tables"))
check("fetching what is already held says so",
      twice ~= nil and twice:find("already") ~= nil, twice)

local absent = select(2, payload_module.fetch(payload, "pattern: nonsense"))
check("and fetching what does not exist says how to find out what does",
      absent ~= nil and absent:find("list") ~= nil, absent)
-- }}}

-- {{{ the disk half: written out, and fetched back
local went_to = payload_module.write_out(payload, "pattern: dispatch-tables")
check("an atom can be written out to storage", went_to ~= nil, tostring(went_to))

local held_now = false
for _, entry in ipairs(payload_module.index(payload)) do
  if entry.topic == "pattern: dispatch-tables" then held_now = entry.resident end
end
check("and stops taking room once it is out", held_now == false)

payload_module.fetch(payload, "pattern: dispatch-tables")
local came_back = nil
for _, number in ipairs(context.order) do
  if context.atoms[number].topic == "pattern: dispatch-tables" then
    came_back = context.atoms[number].content
  end
end
check("and comes back exactly when it is fetched again",
      came_back ~= nil and came_back == patterns.as_text("dispatch-tables"),
      came_back and (#came_back .. " characters back"))
-- }}}

-- {{{ the uncomfortable one
-- The boot set is a mutable file, so the machine can change what it wakes up
-- believing -- including the prohibitions. Nothing prevents it, deliberately,
-- and this is where that stops being an assumption somebody could quietly
-- build against.
local was = payload_module.boot_set(payload)
local ok = payload_module.set_boot_set(payload,
  "the instruction: What you are for")
check("the machine can rewrite what it wakes up holding", ok == true)

local now = payload_module.boot_set(payload)
check("and can drop the prohibitions from it",
      was:find("prohibitions") ~= nil and now:find("prohibitions") == nil,
      "the prohibitions could not be dropped, which is a different design")

local nonsense = select(2, payload_module.set_boot_set(payload, "something else"))
check("but cannot wake up holding something that does not exist",
      nonsense ~= nil and nonsense:find("nothing here is called") ~= nil,
      nonsense)

payload_module.set_boot_set(payload, was)
check("and the old set can be put back", payload_module.boot_set(payload) == was)
-- }}}

-- {{{ as hands
local catalogue = hands.new({ budget = 20000 })
hands.offer_the_catalogue(catalogue)
payload_module.offer(catalogue, hands, payload)
patterns.offer(catalogue, hands)
descriptions.offer(catalogue, hands, reading)

local carried = hands.answer(catalogue, hands.find(catalogue, "<call carried>"))
check("the machine can ask what it is carrying",
      carried.ok and carried.text:find("not held") ~= nil
      and carried.text:find("held") ~= nil)

local room = hands.answer(catalogue, hands.find(catalogue, "<call room>"))
check("and how much room is left", room.ok and room.text:find("of 4096") ~= nil,
      room.text)

local one = hands.answer(catalogue, {
  name = "pattern", arguments = { "the-four-rungs" } })
check("and can read a pattern it has not been shown",
      one.ok and one.text:find("where it stops working") ~= nil)

local device = hands.answer(catalogue, {
  name = "describe", arguments = { "serial" } })
check("and a description of a device kind",
      device.ok and device.text:find("16550") ~= nil)

local waking = hands.answer(catalogue, hands.find(catalogue,
  "<call what_i_wake_with>"))
check("and can read the file that says what it wakes with",
      waking.ok and waking.text:find("the instruction") ~= nil)
-- }}}

say("")
say("  " .. string.rep("-", 58))
say("  " .. passed .. " of " .. (passed + failed) .. " as expected")
say("")
say("  what this cannot check:")
say("    - whether the instruction WORKS. Nothing here says a machine given")
say("      this text does the right thing with it; only 602 says that, and")
say("      it says it by leaving a machine alone and watching. A failure")
say("      there is fixed in this text rather than at the keyboard.")
say("")

run_one("mkdir -p " .. DIR .. "/output")
local goodbye = io.open(DIR .. "/output/goodbye", "w")
if goodbye then
  goodbye:write("the payload: " .. passed .. " of " .. (passed + failed)
                .. " as expected\ngoodbye\n")
  goodbye:close()
end

os.exit(failed == 0 and 0 or 1)
-- }}}
