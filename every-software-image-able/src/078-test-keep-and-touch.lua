#!/usr/bin/env luajit
-- 078-test-keep-and-touch.lua
--
-- Checks storage and hardware exploration together, because they only work
-- together: the discipline that makes exploring survivable depends on
-- writing a note first, and the note needs somewhere to land. Issues 206 and
-- 205.
--
-- For a general: the machine is given pretend storage and a pretend body,
-- and then made to explore recklessly. What is being tested is that it
-- cannot -- that the writes which destroy real hardware are refused, that
-- every exploratory write leaves a note behind first, and that a machine
-- with nowhere to write a note is not allowed to explore at all.
--
-- usage:
--   luajit 078-test-keep-and-touch.lua [--dir ROOT]

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

say("")
say("  keeping something, and touching what can be broken")
say("  " .. string.rep("-", 58))
say("")

local keep = dofile(DIR .. "/src/076-keep-something.lua")
local touch = dofile(DIR .. "/src/077-touch-the-hardware.lua")
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

-- {{{ pretend storage: one writable disk, one read-only card
local function make_disk(name, blocks, block_bytes, writable, removable, note)
  local contents = {}
  return {
    name = name, blocks = blocks, block_bytes = block_bytes,
    writable = writable, removable = removable, note = note,
    read = function(block, count)
      local out = {}
      for offset = 0, count - 1 do
        out[#out + 1] = contents[block + offset] or string.rep("\0", block_bytes)
      end
      return table.concat(out)
    end,
    write = function(block, text)
      for offset = 0, #text / block_bytes - 1 do
        contents[block + offset] = text:sub(offset * block_bytes + 1,
                                            (offset + 1) * block_bytes)
      end
      return true
    end,
    contents = contents,
  }
end

local disk = make_disk("disk", 4096, 512, true, false, "the one to move into")
local card = make_disk("card", 512, 512, false, true, "what the seed arrived on")
local store = keep.new({ devices = { disk, card } })
-- }}}

-- {{{ storage: enumeration, reading, writing, refusing
local attached = keep.enumerate(store)
check("the machine can see what is attached to keep things on",
      #attached == 2 and attached[1].bytes == 4096 * 512)

check("and can tell what may be written from what may not",
      attached[1].writable == true and attached[2].writable == false)

keep.write(store, "disk", 100, string.rep("a", 512))
check("something written comes back",
      keep.read(store, "disk", 100, 1) == string.rep("a", 512))

local onto_card = select(2, keep.write(store, "card", 10, string.rep("x", 512)))
check("a read-only medium refuses rather than pretending",
      onto_card ~= nil and onto_card:find("is not a fault") ~= nil, onto_card)

local past_end = select(2, keep.write(store, "disk", 4090, string.rep("x", 512 * 10)))
check("a write past the end is refused, naming the size",
      past_end ~= nil and past_end:find("4096 blocks") ~= nil, past_end)

local partial = select(2, keep.write(store, "disk", 5, "not a whole block"))
check("a write that is not whole blocks is refused",
      partial ~= nil and partial:find("512 bytes at a time") ~= nil, partial)
-- }}}

-- {{{ claiming an extent, and finding it again
local claim = keep.claim(store, "disk", 200, 1024)
check("the machine can claim an extent", claim ~= nil and claim.at == 200)

-- a new machine, on the same disks, from nothing
local next_boot = keep.new({ devices = { disk, card } })
local found = keep.look_for_claim(next_boot, { 0, 200 })
check("and finds it again after everything is forgotten",
      found ~= nil and found.device == "disk" and found.at == 200
      and found.blocks == 1024,
      found and (found.device .. " at " .. found.at))

local over_the_mark = select(2, keep.write(store, "disk", 200, string.rep("z", 512)))
check("and will not write over the mark that finds it",
      over_the_mark ~= nil and over_the_mark:find("loses everything") ~= nil,
      over_the_mark)

-- a disk cloned from another machine carries a mark that is not ours
local stranger = make_disk("stranger", 512, 512, true, true, "somebody else's")
stranger.write(0, keep.MARK .. "\ndisk\n200\n1024\n"
  .. string.rep("\0", 512 - #(keep.MARK .. "\ndisk\n200\n1024\n")))
local cloned = keep.new({ devices = { stranger } })
local adopted, refusal = keep.look_for_claim(cloned, { 0 })
check("a mark belonging to another machine is not adopted",
      adopted == nil and refusal:find("writing over each other") ~= nil, refusal)

local unclaimed = select(2, keep.look_for_claim(keep.new({
  devices = { make_disk("blank", 64, 512, true, false) } }), { 0 }))
check("and a blank machine says nothing has been claimed",
      unclaimed ~= nil and unclaimed:find("claimed yet") ~= nil, unclaimed)
-- }}}

-- {{{ a pretend body, with real dangers in it
local registers = {}
local devices = {
  { name = "netcard", slot = 3, vendor = 0x8086, part = 0x100e, class = "network",
    registers = { { base = 0xf0000000, length = 0x20000 } }, interrupt = 11,
    -- the addresses that end the part, exactly as a real one would have
    destroying = { [0x40] = "voltage", [0x44] = "clock", [0x80] = "non-volatile" } },
  { name = "display", slot = 2, vendor = 0x1234, part = 0x1111, class = "display",
    registers = { { base = 0xe0000000, length = 0x1000000 } }, interrupt = -1,
    destroying = { [0x10] = "thermal" } },
}

local hardware = touch.new({
  enumerate = function() return devices end,
  read = function(device, offset) return registers[device.name .. offset] or 0 end,
  write = function(device, offset, width, value)
    registers[device.name .. offset] = value
  end,
  store = store, keep = keep, note_on = "disk", note_at = 1000,
})
-- }}}

-- {{{ finding the body, and reading it
local body = touch.look(hardware)
check("the machine finds what it is attached to", #body == 2)

local read_back = touch.peek(hardware, "netcard", 0x10, 4)
check("and can read a register", read_back == 0)

local nothing_there = select(2, touch.peek(hardware, "toaster", 0, 4))
check("a device that is not there is refused, saying where to look",
      nothing_there ~= nil and nothing_there:find("body") ~= nil, nothing_there)
-- }}}

-- {{{ the destroying registers
local voltage = select(2, touch.poke(hardware, "netcard", 0x40, 4, 0xffff,
                                     { expecting = "more speed" }))
check("a voltage register is refused, and says what it does",
      voltage ~= nil and voltage:find("damages it in seconds") ~= nil, voltage)

local thermal = select(2, touch.poke(hardware, "display", 0x10, 4, 0,
                                     { expecting = "quieter fan" }))
check("so is thermal protection, and it says why that is worse",
      thermal ~= nil and thermal:find("stops existing") ~= nil, thermal)

local nonvolatile = select(2, touch.poke(hardware, "netcard", 0x80, 4, 1,
                                         { expecting = "a new name" }))
check("and the one that makes a part never answer again",
      nonvolatile ~= nil and nonvolatile:find("will not be found") ~= nil,
      nonvolatile)

-- confirming is a read-only act, and separate from writing
touch.confirm(hardware, "voltage", "the datasheet, read and matched against "
  .. "what the part reports about itself")
local now_allowed = touch.poke(hardware, "netcard", 0x40, 4, 0x1234,
                               { expecting = "the regulator changes" })
check("a confirmed description opens that kind, and only that kind",
      now_allowed == 0x1234
      and select(2, touch.poke(hardware, "netcard", 0x44, 4, 1,
                               { expecting = "faster" })) ~= nil)

local bad_kind = select(2, touch.confirm(hardware, "colour", "anything"))
check("confirming something that is not a danger is refused",
      bad_kind ~= nil and bad_kind:find("destroying kinds") ~= nil, bad_kind)
-- }}}

-- {{{ predict, then write, then check
local no_prediction = select(2, touch.poke(hardware, "netcard", 0x20, 4, 7, {}))
check("a write with no prediction is refused",
      no_prediction ~= nil and no_prediction:find("nobody can interpret") ~= nil,
      no_prediction)

local before_notes = hardware.notes_written
local written, _, how = touch.poke(hardware, "netcard", 0x20, 4, 7,
                                   { expecting = "the counter clears" })
check("an ordinary exploratory write goes through", written == 7)
check("and left a note behind before it happened",
      hardware.notes_written == before_notes + 1 and how.note_at ~= nil)

local note = keep.read(store, "disk", how.note_at, 1)
check("and the note says the device, the register, the value and the hope",
      note:find("netcard") and note:find("0x20") and note:find("0x7")
      and note:find("the counter clears"), note:sub(1, 60))
-- }}}

-- {{{ nowhere to write a note is nowhere to explore
-- The whole reason these two tickets land together.
local no_storage = touch.new({
  enumerate = function() return devices end,
  read = function() return 0 end,
  write = function() end,
})
touch.look(no_storage)
local allowed, unexplorable = touch.poke(no_storage, "netcard", 0x20, 4, 1,
                                         { expecting = "something" })
check("a machine with nowhere to write a note may not explore",
      allowed == nil and unexplorable ~= nil
      and unexplorable:find("nowhere to write a note") ~= nil,
      unexplorable)
-- }}}

-- {{{ as hands
local catalogue = hands.new()
hands.offer_the_catalogue(catalogue)
keep.offer(catalogue, hands, store)
touch.offer(catalogue, hands, hardware)

local listed = hands.answer(catalogue, hands.find(catalogue, "<call storage>"))
check("the machine can ask what it may keep things on",
      listed.ok and listed.text:find("READ ONLY") ~= nil
      and listed.text:find("claimed 1024") ~= nil, listed.text)

local kept = hands.answer(catalogue, {
  name = "keep", arguments = { "disk", "300", "something worth remembering" } })
local recalled = hands.answer(catalogue, {
  name = "recall", arguments = { "disk", "300" } })
check("and can keep something and recall it",
      kept.ok and recalled.ok and recalled.text == "something worth remembering",
      recalled.text)

local dangers = hands.answer(catalogue, hands.find(catalogue, "<call dangers>"))
check("and can ask what it must not touch, and why",
      dangers.ok and dangers.text:find("cannot") ~= nil
      and dangers.text:find("thermal") ~= nil)

local writing = hands.answer(catalogue, hands.find(catalogue,
  "<call write_register netcard 0x20 4 9 something>"))
check("the writing hand is refused until it is opened",
      not writing.ok and writing.text:find("refused by default") ~= nil,
      writing.text)
-- }}}

say("")
say("  " .. string.rep("-", 58))
say("  " .. passed .. " of " .. (passed + failed) .. " as expected")
say("")
say("  what this does not cover:")
say("    - a read that never returns. Some buses hang on an address nothing")
say("      answers on, and this is the most likely way an early machine")
say("      dies. Nothing here prevents it.")
say("    - finding the reset first. The discipline says to establish whether")
say("      a device can be returned to a known state before any exploratory")
say("      write, and nothing here requires it yet -- a pretend device has")
say("      no reset to find.")
say("    - moving in. Writing the engine, the weights and the text to")
say("      claimed storage and handing control to that copy belongs to 601,")
say("      where there is a real machine to hand it to.")
say("")

run_one("mkdir -p " .. DIR .. "/output")
local goodbye = io.open(DIR .. "/output/goodbye", "w")
if goodbye then
  goodbye:write("keeping and touching: " .. passed .. " of " .. (passed + failed)
                .. " as expected\ngoodbye\n")
  goodbye:close()
end

os.exit(failed == 0 and 0 or 1)
-- }}}
