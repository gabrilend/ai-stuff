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

-- 079-the-shared-frame.lua
--
-- The bodies of the viewer's frame, in memory another thread can read: a ring of
-- whole frames, and never half of one tick and half of the next (issue 709, R4).
--
-- ## What shared memory buys, and what it must not cost
--
-- The simulation and the drawing share one thread today. The display's frame and the
-- simulation's tick take turns, so a slow frame delays ticks and a fast-forwarded
-- match spends the frame's time on up to forty ticks before anything is drawn. Put
-- the simulation on a thread of its own and the two clocks are really separate: the
-- simulation keeps time whatever the drawing is doing, and the drawing draws whatever
-- the simulation has most recently finished. The person watching gets the frame rate
-- back at high speed; the thread pool of issue 209 gets memory it can share.
--
-- What it must not cost is the thing the snapshot pair exists for: **the screen never
-- shows half of one tick and half of the next.** So what is shared is not the live
-- world. It is the viewer's frame, written whole into one block of a ring, and a
-- reader takes a block only if it was whole before it started copying and is still
-- the same block when it finishes. "Everybody reads the same memory" means everybody
-- reads the same **finished** frames.
--
-- ## A sequence number on every block
--
-- Each block carries a sequence number. The writer makes it odd before it writes and
-- even again after. A reader notes it, copies, and notes it again: if it was odd, or
-- has changed, the copy may be torn and is thrown away. The writer never waits for a
-- reader, so the simulation's timing never depends on whether anybody is watching.
--
-- That is only sound if the two notes and the copy happen in the order written. On
-- x86 the processor keeps stores in order and loads in order, so all that is needed is
-- that the compiler does not move them, and the functions that touch a sequence
-- number are never compiled. Other processors would need fences, which LuaJIT does
-- not offer, so `create` refuses to run anywhere else rather than run unsoundly.
--
-- ## What is in a block
--
-- Only the bodies: the per-body arrays, the upgrade counts, the live and fading lists.
-- They are nearly all of a frame's size, and they change every tick. The rest -- the
-- chest, the slots, the wallets, the phase, the events -- is small, and how it crosses
-- threads is the next step, not this one.

local ffi = require("ffi")

local M = {}

-- {{{ M.settings
M.settings = {
  -- Blocks in the ring. **Chosen by Claude, open for Ritz.** A reader wants two
  -- adjacent ticks to blend between, and the writer must have somewhere to write that
  -- is neither of them nor the newest; four leaves one spare, so a reader that copies
  -- a little slowly still finds its pair whole. More is memory nobody reads.
  slots = 4,
}
-- }}}

-- {{{ M.per_body
-- Every per-body array of the viewer's frame, in the order they are laid out. A new
-- array on the frame is a new row here, or it does not cross.
M.per_body = {
  "alive", "x", "y", "facing", "team", "flavour", "archetype", "reach", "radius",
  "lane", "milestone", "health_fraction", "spawned_lane", "fade",
}
-- }}}

-- The ring's own header, ahead of the blocks.
local RING_HEADER = 4    -- capacity, kinds, slots, the last slot written
-- Each block's header, ahead of its arrays.
local BLOCK_HEADER = 6   -- sequence, tick, live_count, fading_count, zone_count, spare

-- {{{ local function block_size()
-- Doubles in one block: its header, the per-body arrays, one array per upgrade kind,
-- and the live and fading lists.
local function block_size(capacity, kinds)
  return BLOCK_HEADER + (#M.per_body + kinds + 2) * capacity
end
-- }}}

-- {{{ function M.bytes()
-- How much memory a ring needs, so that it can be allocated somewhere both threads
-- can see -- a LÖVE ByteData, or in a test a shared mapping -- and handed to `create`.
function M.bytes(capacity, kinds)
  return (RING_HEADER + M.settings.slots * block_size(capacity, kinds)) * 8
end
-- }}}

-- {{{ function M.create()
-- A ring for `capacity` bodies and `kinds` upgrade kinds, in `memory` if given --
-- `M.bytes` long, zeroed -- or in memory of its own. Writes the ring's header, so the
-- reader on the other side can `adopt` it knowing nothing but the pointer.
function M.create(capacity, kinds, memory)
  if ffi.arch ~= "x64" and ffi.arch ~= "x86" then
    error("the shared frame relies on x86's ordering of loads and stores; on " ..
          ffi.arch .. " it would need fences that LuaJIT does not have")
  end
  local keep = nil
  if memory == nil then
    keep = ffi.new("double[?]", M.bytes(capacity, kinds) / 8)
    memory = keep
  end
  local data = ffi.cast("volatile double *", memory)
  data[0], data[1], data[2], data[3] = capacity, kinds, M.settings.slots, 0
  for slot = 1, M.settings.slots do
    data[RING_HEADER + (slot - 1) * block_size(capacity, kinds)] = 0
  end
  return M.adopt(data, keep)
end
-- }}}

-- {{{ function M.adopt()
-- A ring somebody else created, from its pointer alone.
function M.adopt(memory, keep)
  local data = ffi.cast("volatile double *", memory)
  local capacity, kinds, slots = data[0], data[1], data[2]
  if capacity < 1 or slots < 2 then
    error("that memory does not hold a ring: no header was written into it")
  end
  return {data = data, keep = keep, capacity = capacity, kinds = kinds, slots = slots,
          size = block_size(capacity, kinds)}
end
-- }}}

-- {{{ local function base_of()
local function base_of(ring, slot)
  return RING_HEADER + (slot - 1) * ring.size
end
-- }}}

-- {{{ local function sequence_of(), local function set_sequence()
-- The only two places a sequence number is touched, and never compiled, so that the
-- loads and stores around a copy happen in the order they are written.
local function sequence_of(data, base)
  return data[base]
end
local function set_sequence(data, base, value)
  data[base] = value
end
jit.off(sequence_of)
jit.off(set_sequence)
-- }}}

-- {{{ local function copy_in()
local function copy_in(ring, base, frame)
  local data, capacity = ring.data, ring.capacity
  data[base + 1] = frame.tick
  data[base + 2] = frame.live_count
  data[base + 3] = frame.fading_count
  data[base + 4] = frame.zone_count
  local at = base + BLOCK_HEADER - 1
  for _, name in ipairs(M.per_body) do
    local array = frame[name]
    for id = 1, capacity do data[at + id] = array[id] end
    at = at + capacity
  end
  for kind = 1, ring.kinds do
    local array = frame.upgrade_count[kind]
    for id = 1, capacity do data[at + id] = array[id] end
    at = at + capacity
  end
  for index = 1, capacity do data[at + index] = frame.live[index] or 0 end
  at = at + capacity
  for index = 1, capacity do data[at + index] = frame.fading[index] or 0 end
end
-- }}}

-- {{{ local function copy_out()
local function copy_out(ring, base, frame)
  local data, capacity = ring.data, ring.capacity
  frame.tick         = data[base + 1]
  frame.live_count   = data[base + 2]
  frame.fading_count = data[base + 3]
  frame.zone_count   = data[base + 4]
  local at = base + BLOCK_HEADER - 1
  for _, name in ipairs(M.per_body) do
    local array = frame[name]
    for id = 1, capacity do array[id] = data[at + id] end
    at = at + capacity
  end
  for kind = 1, ring.kinds do
    local array = frame.upgrade_count[kind]
    for id = 1, capacity do array[id] = data[at + id] end
    at = at + capacity
  end
  for index = 1, capacity do frame.live[index] = data[at + index] end
  at = at + capacity
  for index = 1, capacity do frame.fading[index] = data[at + index] end
end
-- }}}

-- {{{ function M.write()
-- Writes the bodies of a stamped viewer frame into the next block, whole. Never waits.
function M.write(ring, frame)
  local data = ring.data
  local slot = (data[3] % ring.slots) + 1
  local base = base_of(ring, slot)
  local sequence = sequence_of(data, base)
  set_sequence(data, base, sequence + 1)    -- odd: being written
  copy_in(ring, base, frame)
  set_sequence(data, base, sequence + 2)    -- even: whole
  data[3] = slot
end
jit.off(M.write)
-- }}}

-- {{{ local function try_copy()
-- Copies one block into `frame` if it is whole, and says whether it was.
local function try_copy(ring, slot, frame)
  local data = ring.data
  local base = base_of(ring, slot)
  local before = sequence_of(data, base)
  if before == 0 or before % 2 == 1 then
    return false
  end
  copy_out(ring, base, frame)
  return sequence_of(data, base) == before
end
jit.off(try_copy)
-- }}}

-- {{{ function M.reader()
-- The reading side's own two frames, shaped like the viewer's so that whatever
-- draws a frame can draw these.
function M.reader(ring)
  local function frame()
    local made = {tick = -1, live_count = 0, fading_count = 0, zone_count = 0,
                  live = {}, fading = {}, upgrade_count = {}}
    for _, name in ipairs(M.per_body) do
      made[name] = {}
      for id = 1, ring.capacity do made[name][id] = 0 end
    end
    for kind = 1, ring.kinds do
      made.upgrade_count[kind] = {}
      for id = 1, ring.capacity do made.upgrade_count[kind][id] = 0 end
    end
    for index = 1, ring.capacity do made.live[index], made.fading[index] = 0, 0 end
    return made
  end
  return {newest = frame(), previous = frame(), spare = frame(), torn = 0}
end
-- }}}

-- {{{ local function copy_frame()
-- One reader frame into another, in Lua. Used when no adjacent pair is in the ring,
-- so the previous frame becomes the newest without touching shared memory again.
local function copy_frame(ring, from, to)
  to.tick, to.live_count = from.tick, from.live_count
  to.fading_count, to.zone_count = from.fading_count, from.zone_count
  for _, name in ipairs(M.per_body) do
    local source, target = from[name], to[name]
    for id = 1, ring.capacity do target[id] = source[id] end
  end
  for kind = 1, ring.kinds do
    local source, target = from.upgrade_count[kind], to.upgrade_count[kind]
    for id = 1, ring.capacity do target[id] = source[id] end
  end
  for index = 1, ring.capacity do
    to.live[index], to.fading[index] = from.live[index], from.fading[index]
  end
end
-- }}}

-- {{{ function M.read()
-- Brings the reader up to the newest whole tick, with the whole tick before it as the
-- previous frame. Returns whether the newest moved.
--
-- When the tick before the newest is neither already held nor still whole in the ring
-- -- the simulation ran more than a tick ahead of the drawing -- the previous frame is
-- the newest again, and the blend between them is no blend at all: the honest picture,
-- a little steppy, never an invented one. A torn copy is thrown away and counted.
function M.read(ring, reader)
  local data = ring.data
  local best_slot, best_tick = 0, reader.newest.tick
  for slot = 1, ring.slots do
    local base = base_of(ring, slot)
    local sequence = sequence_of(data, base)
    local tick = data[base + 1]
    if sequence ~= 0 and sequence % 2 == 0 and tick > best_tick then
      best_slot, best_tick = slot, tick
    end
  end
  if best_slot == 0 then
    return false
  end

  local fresh = reader.spare
  if not try_copy(ring, best_slot, fresh) then
    reader.torn = reader.torn + 1
    return false
  end
  local want = fresh.tick - 1

  if reader.newest.tick == want then
    -- The pair is the old newest and this one.
    reader.spare, reader.previous, reader.newest = reader.previous, reader.newest, fresh
    return true
  end

  local paired = false
  for slot = 1, ring.slots do
    if not paired and slot ~= best_slot and data[base_of(ring, slot) + 1] == want then
      paired = try_copy(ring, slot, reader.previous) and reader.previous.tick == want
      if not paired then
        reader.torn = reader.torn + 1
      end
    end
  end
  if not paired then
    copy_frame(ring, fresh, reader.previous)
  end
  reader.spare, reader.newest = reader.newest, fresh
  return true
end
-- }}}

return M
