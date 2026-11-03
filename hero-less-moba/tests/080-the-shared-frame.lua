-- hero-less-moba — a lane-pushing game with the heroes subtracted out
-- Copyright (C) 2026 gabrilend
--
-- This program is free software: you can redistribute it and/or modify it
-- under the terms of the GNU Affero General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or (at
-- your option) any later version.
--
-- This program is distributed in the hope that it will be useful, but
-- WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero
-- General Public License for more details.
--
-- You should have received a copy of the GNU Affero General Public License
-- along with this program. If not, see <https://www.gnu.org/licenses/>.
--
-- SPDX-License-Identifier: AGPL-3.0-or-later

-- 080-the-shared-frame.lua
--
-- covers: 709
--
-- The shared frame (709's third part, R4), read while a real match is written into it.
--
-- The claim worth testing is the one the snapshot pair exists for: **a reader never
-- takes half of one tick and half of the next.** One process is not enough to test
-- that -- nothing can change under a copy in progress -- so the last test forks. The
-- child plays a real match and writes every tick into memory both can see; the parent
-- reads as fast as it can while that happens, keeps a fingerprint of every frame it
-- accepted, and afterwards plays the same match itself. Every frame accepted must be
-- exactly a frame the match really had.
--
-- The LÖVE side -- a thread for the simulation, its ByteData, the rest of the frame --
-- is not here, because LÖVE is not here. The memory and the rule for reading it are.

local ROOT = debug.getinfo(1, "S").source:match("^@(.*)/tests/[^/]+$") or "."
local ffi = require("ffi")

local passed, failed = 0, 0

-- {{{ local function check()
local function check(name, condition, detail)
  if condition then
    passed = passed + 1
    print(string.format("  ok    %s", name))
  else
    failed = failed + 1
    print(string.format("  FAIL  %s%s", name, detail and ("  --  " .. detail) or ""))
  end
end
-- }}}

local tick_module = loadfile(ROOT .. "/src/042-the-tick.lua")()
local shared = loadfile(ROOT .. "/src/079-the-shared-frame.lua")()

-- {{{ local function fresh_world()
local function fresh_world()
  local modules = tick_module.load_cast(ROOT)
  local parameters = modules.match_parameters.load()
  local world = tick_module.assemble(modules, parameters)
  return world, modules, parameters
end
-- }}}

-- {{{ local function fingerprint()
-- Every number a block carries, folded into two. Two frames with the same fingerprint
-- are, for any purpose this test has, the same frame.
local function fingerprint(frame, capacity, kinds, without_tick)
  local a = without_tick and 0 or frame.tick
  local b = frame.live_count * 3 + frame.fading_count
  local function fold(array)
    for id = 1, capacity do
      local value = array[id] or 0  -- the lists are not filled past their longest
      a = (a * 1.000003 + value) % 1000003
      b = b + value * ((id % 97) + 1)
    end
  end
  for _, name in ipairs(shared.per_body) do fold(frame[name]) end
  for kind = 1, kinds do fold(frame.upgrade_count[kind]) end
  fold(frame.live)
  fold(frame.fading)
  return string.format("%.17g/%.17g", a, b)
end
-- }}}

-- {{{ local function test_a_frame_crosses_whole()
local function test_a_frame_crosses_whole()
  local world, modules, parameters = fresh_world()
  for _ = 1, 600 do tick_module.advance(world) end
  local frame = modules.snapshot.newest(world)
  local capacity, kinds = #world.soldier.alive, #parameters.upgrade.kind
  local ring = shared.create(capacity, kinds)
  local reader = shared.reader(ring)

  check("nothing is read from a ring nothing has been written into",
        shared.read(ring, reader) == false)

  shared.write(ring, frame)
  local moved = shared.read(ring, reader)
  check("a frame written is read back, every body array exactly",
        moved and fingerprint(reader.newest, capacity, kinds)
                    == fingerprint(frame, capacity, kinds)
          and reader.newest.tick == world.tick and reader.newest.live_count > 0,
        string.format("tick %d, %d live", reader.newest.tick, reader.newest.live_count))
  check("and reading again with nothing new says so", shared.read(ring, reader) == false)

  tick_module.advance(world)
  shared.write(ring, modules.snapshot.newest(world))
  shared.read(ring, reader)
  check("the next tick makes a pair: the previous is exactly the tick before",
        reader.previous.tick == world.tick - 1 and reader.newest.tick == world.tick
          and fingerprint(reader.newest, capacity, kinds)
                == fingerprint(modules.snapshot.newest(world), capacity, kinds)
          and fingerprint(reader.previous, capacity, kinds)
                == fingerprint(modules.snapshot.previous(world), capacity, kinds))

  -- Three ticks with nobody reading: the newest and the one before are both still in
  -- the ring, so the pair is still adjacent.
  for _ = 1, 3 do
    tick_module.advance(world)
    shared.write(ring, modules.snapshot.newest(world))
  end
  shared.read(ring, reader)
  check("a reader that fell behind still gets an adjacent pair from the ring",
        reader.newest.tick == world.tick and reader.previous.tick == world.tick - 1
          and fingerprint(reader.previous, capacity, kinds)
                == fingerprint(modules.snapshot.previous(world), capacity, kinds))

  -- A writer caught in the middle of the newest block: its sequence is odd. The reader
  -- must take the newest **whole** block instead.
  tick_module.advance(world)
  shared.write(ring, modules.snapshot.newest(world))
  tick_module.advance(world)
  shared.write(ring, modules.snapshot.newest(world))
  local newest_slot = ring.data[3]
  local base = 4 + (newest_slot - 1) * ring.size
  ring.data[base] = ring.data[base] + 1
  shared.read(ring, reader)
  check("a block being written is never read; the newest whole one is",
        reader.newest.tick == world.tick - 1,
        string.format("read tick %d with the world at %d", reader.newest.tick, world.tick))

  -- And when the one before the newest is the one being written, the previous frame is
  -- the newest again rather than anything torn.
  ring.data[base] = ring.data[base] + 1
  local before_slot = ((newest_slot - 2) % ring.slots) + 1
  local before_base = 4 + (before_slot - 1) * ring.size
  ring.data[before_base] = ring.data[before_base] + 1
  local reader2 = shared.reader(ring)
  shared.read(ring, reader2)
  check("with no whole pair, the previous frame is the newest again, never a torn one",
        reader2.newest.tick == world.tick and reader2.previous.tick == world.tick
          and fingerprint(reader2.previous, capacity, kinds)
                == fingerprint(reader2.newest, capacity, kinds))
  ring.data[before_base] = ring.data[before_base] + 1

  check("a ring is adopted from its pointer alone",
        (function()
          local again = shared.adopt(ring.data)
          return again.capacity == capacity and again.kinds == kinds
                   and again.slots == shared.settings.slots
        end)())
  check("and memory that was never made a ring is refused",
        not pcall(shared.adopt, ffi.new("double[8]")))
end
-- }}}

-- {{{ Two processes and the memory between them
ffi.cdef[[
  int fork(void);
  int waitpid(int pid, int *status, int options);
  void *mmap(void *addr, size_t length, int prot, int flags, int fd, long offset);
  int munmap(void *addr, size_t length);
  void _exit(int status);
]]
local PROT_READ, PROT_WRITE, MAP_SHARED, MAP_ANONYMOUS, WNOHANG = 1, 2, 1, 0x20, 1

local function shared_memory(bytes)
  local memory = ffi.C.mmap(nil, bytes, PROT_READ + PROT_WRITE,
                            MAP_SHARED + MAP_ANONYMOUS, -1, 0)
  if ffi.cast("intptr_t", memory) == -1 then
    error("could not map shared memory for the test")
  end
  return memory
end

local function fork()
  io.stdout:flush()
  local child = ffi.C.fork()
  if child < 0 then
    error("could not fork for the test")
  end
  return child
end
-- }}}

-- {{{ local function test_read_while_written()
-- The claim itself, under real concurrency: two processes, one ring.
local function test_read_while_written()
  local TICKS = 2400

  local world, modules, parameters = fresh_world()
  for _ = 1, 300 do tick_module.advance(world) end
  local capacity, kinds = #world.soldier.alive, #parameters.upgrade.kind
  local bytes = shared.bytes(capacity, kinds)
  local memory = shared_memory(bytes)
  local ring = shared.create(capacity, kinds, memory)
  local start = world.tick

  local child = fork()
  if child == 0 then
    -- The simulation's side: play, write every tick, never wait for anybody.
    for _ = 1, TICKS do
      tick_module.advance(world)
      shared.write(ring, modules.snapshot.newest(world))
    end
    ffi.C._exit(0)
  end

  -- The drawing's side: read as fast as possible until the match is written.
  local reader = shared.reader(ring)
  local seen, pairs_seen, unpaired, wrong_pair, last_tick = {}, 0, 0, 0, -1
  local status = ffi.new("int[1]")
  local reads = 0
  while true do
    local finished = ffi.C.waitpid(child, status, WNOHANG) == child
    if shared.read(ring, reader) then
      reads = reads + 1
      last_tick = reader.newest.tick
      seen[#seen + 1] = {reader.newest.tick, fingerprint(reader.newest, capacity, kinds)}
      if reader.previous.tick == reader.newest.tick - 1 then
        pairs_seen = pairs_seen + 1
        seen[#seen + 1] = {reader.previous.tick, fingerprint(reader.previous, capacity, kinds)}
      elseif reader.previous.tick == reader.newest.tick then
        unpaired = unpaired + 1
      else
        wrong_pair = wrong_pair + 1
      end
    end
    if finished then break end
  end
  ffi.C.munmap(memory, bytes)

  -- The same match, played here, to say what every tick really was.
  local truth = {}
  for _ = 1, TICKS do
    tick_module.advance(world)
    truth[world.tick] = fingerprint(modules.snapshot.newest(world), capacity, kinds)
  end
  local mismatched, first_bad = 0, nil
  for _, entry in ipairs(seen) do
    if truth[entry[1]] ~= entry[2] then
      mismatched = mismatched + 1
      first_bad = first_bad or entry[1]
    end
  end

  check("the other process finished the match it was writing", status[0] == 0)
  check("the reader saw the match as it was being written, many ticks of it",
        reads >= 50 and last_tick == start + TICKS,
        string.format("%d reads, last tick %d of %d", reads, last_tick, start + TICKS))
  check("every frame it accepted is exactly a frame the match really had -- none torn",
        mismatched == 0,
        string.format("%d of %d differ, first at tick %s", mismatched, #seen, tostring(first_bad)))
  check("a previous frame is always the tick before the newest, or the newest itself",
        wrong_pair == 0, string.format("%d pairs were neither", wrong_pair))
  print(string.format("        %d reads, %d adjacent pairs, %d steppy, %d torn copies thrown away",
                      reads, pairs_seen, unpaired, reader.torn))
end
-- }}}

-- {{{ local function test_a_writer_lapping_the_reader()
-- The rule for a torn copy, made to fire. A ring of two blocks, and a writer as fast as
-- it can go writing two different frames -- the newest and the previous of one moment
-- of a match -- each under a new tick number, and in an order that makes each block
-- hold the two in turn (writes 1 and 2 are the first, 3 and 4 the second, and so on).
-- A copy the writer laps mixes the two; it must be thrown away, and every copy kept
-- must be one of them whole, the right one for its tick.
local function test_a_writer_lapping_the_reader()
  local WRITES = 40000
  local world, modules, parameters = fresh_world()
  for _ = 1, 600 do tick_module.advance(world) end
  local capacity, kinds = #world.soldier.alive, #parameters.upgrade.kind
  local odd, even = modules.snapshot.newest(world), modules.snapshot.previous(world)
  local odd_print = fingerprint(odd, capacity, kinds, true)
  local even_print = fingerprint(even, capacity, kinds, true)

  local slots = shared.settings.slots
  shared.settings.slots = 2
  local bytes = shared.bytes(capacity, kinds)
  local memory = shared_memory(bytes)
  local ring = shared.create(capacity, kinds, memory)
  shared.settings.slots = slots

  local child = fork()
  if child == 0 then
    for write = 1, WRITES do
      local frame = (math.floor((write - 1) / 2) % 2 == 0) and odd or even
      frame.tick = write
      shared.write(ring, frame)
    end
    ffi.C._exit(0)
  end

  local reader = shared.reader(ring)
  local status = ffi.new("int[1]")
  local kept, wrong = 0, 0
  while true do
    local finished = ffi.C.waitpid(child, status, WNOHANG) == child
    if shared.read(ring, reader) then
      kept = kept + 1
      local want = (math.floor((reader.newest.tick - 1) / 2) % 2 == 0) and odd_print
                     or even_print
      if fingerprint(reader.newest, capacity, kinds, true) ~= want then
        wrong = wrong + 1
      end
    end
    if finished then break end
  end
  ffi.C.munmap(memory, bytes)

  check("a writer lapping the reader tears copies, and every torn one is thrown away",
        reader.torn > 0 and wrong == 0,
        string.format("%d torn, %d kept, %d of those wrong", reader.torn, kept, wrong))
  print(string.format("        %d copies kept, %d torn copies thrown away", kept, reader.torn))
end
-- }}}

local seed = os.getenv("HLM_SEED")
print("seed " .. tostring(seed or "drawn"))
test_a_frame_crosses_whole()
test_read_while_written()
test_a_writer_lapping_the_reader()

print("")
print(string.format("%d passed, %d failed", passed, failed))
print("")

if failed > 0 then
  os.exit(1)
end
