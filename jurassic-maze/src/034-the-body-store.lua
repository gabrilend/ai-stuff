-- jurassic-maze — a simulation living inside an isometric maze of stacked stone
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

-- 034-the-body-store.lua
--
-- Flat arrays, a free list, generation counters, and the spatial buckets.
--
-- A body is an integer. It is not a table, it is not an object, and there is
-- nowhere in the program you can hold one in your hand. Body twelve is the
-- twelfth entry of every array below.

local M = {}

-- Every per-body field. Listed once, here, and the store is built from this
-- list -- so adding a field is adding a row, and no constructor anywhere can
-- forget to zero one.
--
-- The zero value matters as much as the name. Nothing in this store is ever nil:
-- empty is the integer zero, body zero does not exist and never will, and
-- `partner == 0` therefore reads as "nobody" without ambiguity. A nil check is a
-- question about whether some earlier code did its job, and that question
-- belongs in a validator at load time rather than in the inner loop.
M.FIELDS = {
  "alive", "generation", "kind", "locomotion",
  "x", "y", "z",                       -- position, in cells and layers
  "vx", "vy", "vz",                    -- velocity, in cells per second
  "cell", "layer",                     -- the stance: which stone it is on
  "facing", "radius", "body_height",
  "health", "team",
  "intent", "intent_cell", "intent_layer",
  "from_cell", "from_layer", "progress",
  "partner", "partner_generation",
  "timer", "idle_row", "idle_total",
  "rest_timer", "distance",
  "roster_slot",                       -- where it sits in its locomotion's roster
}

-- {{{ function M.new(capacity, cells)
-- The store, allocated once and never grown.
--
-- Running out is an error with a message. A store that quietly reallocates is a
-- store that quietly stops fitting in cache, and the frame rate falls off a
-- cliff for reasons that look like nothing.
function M.new(capacity, cells)
  local store = {
    capacity = capacity,
    cells    = cells,
    live     = 0,
    free_top = 0,
    free     = {},
    rosters  = {},        -- one contiguous array of ids per locomotion row
  }

  for _, field in ipairs(M.FIELDS) do
    local a = {}
    for i = 1, capacity do a[i] = 0 end
    store[field] = a
  end

  -- The free list, built backwards so that the first spawn takes id 1 and a
  -- fresh run reads in the order things were made.
  for i = capacity, 1, -1 do
    store.free_top = store.free_top + 1
    store.free[store.free_top] = i
  end

  -- The spatial index: a count and an offset per cell, plus one array holding
  -- every live id sorted by cell. Two preallocated arrays and no tables, so the
  -- rebuild allocates nothing.
  store.bucket_count  = {}
  store.bucket_offset = {}
  store.bucket_ids    = {}
  for i = 0, cells do
    store.bucket_count[i]  = 0
    store.bucket_offset[i] = 0
  end
  for i = 1, capacity do store.bucket_ids[i] = 0 end
  store.largest_bucket = 0

  return store
end
-- }}}

-- {{{ function M.spawn(store)
-- Takes an id off the free list, bumps its generation, and zeroes every field.
--
-- Zeroing everything is not tidiness. A slot that kept its old partner or its
-- old velocity hands them to whoever moves in next, and the resulting body is
-- fighting somebody who has never heard of it, at a speed it never accelerated
-- to.
function M.spawn(store)
  if store.free_top == 0 then
    error("the body store is full at " .. store.capacity ..
          " bodies -- raise the capacity rather than letting it grow")
  end

  local id = store.free[store.free_top]
  store.free_top = store.free_top - 1

  local generation = store.generation[id] + 1
  for _, field in ipairs(M.FIELDS) do
    store[field][id] = 0
  end
  store.generation[id] = generation
  store.alive[id] = 1
  store.live = store.live + 1

  return id, generation
end
-- }}}

-- {{{ function M.kill(store, id)
function M.kill(store, id)
  if store.alive[id] == 0 then return end
  M.leave_roster(store, id)
  store.alive[id] = 0
  store.live = store.live - 1
  store.free_top = store.free_top + 1
  store.free[store.free_top] = id
end
-- }}}

-- {{{ function M.is_valid(store, id, generation)
-- The only sanctioned way to follow a stored id.
--
-- One comparison. It is what stops a fencer duelling the stranger who moved into
-- its dead opponent's slot -- which does happen, is entirely silent, and looks
-- from the outside like a body attacking somebody at random.
function M.is_valid(store, id, generation)
  return id ~= 0 and store.alive[id] == 1 and store.generation[id] == generation
end
-- }}}

-- Rosters. Each locomotion row owns a contiguous array of the ids currently
-- using it, so the move pass hands a range to a thread pool rather than walking
-- every body asking what kind it is.
--
-- The array is contiguous even though the ids in it are scattered, and it is
-- maintained in constant time by swap-remove. Bodies change locomotion rarely --
-- a human mounting a dinosaur, a fencer knocked down -- so the cost is paid on
-- the rare event rather than on the common one.

-- {{{ function M.join_roster(store, id, row)
function M.join_roster(store, id, row)
  local roster = store.rosters[row]
  if not roster then
    roster = { n = 0 }
    store.rosters[row] = roster
  end
  roster.n = roster.n + 1
  roster[roster.n] = id
  store.locomotion[id]  = row
  store.roster_slot[id] = roster.n
end
-- }}}

-- {{{ function M.leave_roster(store, id)
-- Swap-remove: the last entry moves into the hole and is told where it went.
function M.leave_roster(store, id)
  local row = store.locomotion[id]
  local roster = store.rosters[row]
  if not roster then return end

  local slot = store.roster_slot[id]
  if slot == 0 or roster[slot] ~= id then return end

  local last = roster[roster.n]
  roster[slot] = last
  store.roster_slot[last] = slot
  roster[roster.n] = 0
  roster.n = roster.n - 1
  store.roster_slot[id] = 0
end
-- }}}

-- {{{ function M.set_locomotion(store, id, row)
function M.set_locomotion(store, id, row)
  if store.locomotion[id] == row and store.roster_slot[id] ~= 0 then return end
  M.leave_roster(store, id)
  M.join_roster(store, id, row)
end
-- }}}

-- {{{ function M.reindex(store, footprint_of)
-- Rebuilds the spatial buckets: a counting sort over cell index.
--
-- Two linear sweeps and a prefix sum, into arrays that were allocated once. No
-- lists, no tables, nothing allocated per tick.
--
-- Rebuilt rather than maintained incrementally, for two reasons. An
-- incrementally-maintained index is one that can be subtly wrong for a while and
-- nobody can say since when. And the renderer reads these same buckets to draw
-- bodies in the right order, so they have to be exactly right at the moment the
-- frame is drawn rather than eventually.
--
-- `footprint_of` is optional and returns the cells a wide body covers. A
-- three-cell dinosaur in one bucket is invisible to anything standing beside its
-- tail.
function M.reindex(store, footprint_of)
  local count = store.bucket_count
  local cells = store.cells
  for i = 0, cells do count[i] = 0 end

  local alive, cell = store.alive, store.cell
  local capacity = store.capacity

  -- A carried body is in no bucket at all. It is not in a cell of its own, it is
  -- in its mount's, and skipping it is also what stops the meet pass pairing a
  -- rider with whatever its mount happens to walk past.
  local carried = store.CARRIED_ROW

  for id = 1, capacity do
    if alive[id] == 1 and store.locomotion[id] ~= carried then
      if footprint_of then
        for _, c in ipairs(footprint_of(store, id)) do
          count[c] = count[c] + 1
        end
      else
        count[cell[id]] = count[cell[id]] + 1
      end
    end
  end

  local offset = store.bucket_offset
  local running = 0
  local largest = 0
  for i = 0, cells do
    offset[i] = running
    running = running + count[i]
    if count[i] > largest then largest = count[i] end
  end
  store.largest_bucket = largest

  -- The offsets are consumed as cursors during placement and then restored, so
  -- that no third array is needed to hold the write positions.
  local ids = store.bucket_ids
  for id = 1, capacity do
    if alive[id] == 1 and store.locomotion[id] ~= carried then
      if footprint_of then
        for _, c in ipairs(footprint_of(store, id)) do
          offset[c] = offset[c] + 1
          ids[offset[c]] = id
        end
      else
        local c = cell[id]
        offset[c] = offset[c] + 1
        ids[offset[c]] = id
      end
    end
  end

  running = 0
  for i = 0, cells do
    offset[i] = running
    running = running + count[i]
  end
end
-- }}}

-- {{{ function M.for_each_in(store, cell, fn)
-- Every body whose bucket is this cell. The range is into the shared id array,
-- so nothing is copied and nothing is allocated.
function M.for_each_in(store, cell, fn)
  local first = store.bucket_offset[cell] + 1
  local last  = first + store.bucket_count[cell] - 1
  for k = first, last do
    fn(store.bucket_ids[k])
  end
end
-- }}}

-- {{{ function M.for_each_near(store, width, x, y, fn)
-- The nine-cell neighbourhood. Bounded work per body no matter how many bodies
-- there are, which is the property that makes the population a knob rather than
-- a cliff -- and which depends on the bodies being spread out. A hundred of them
-- in one cell puts them all in one bucket and every question about them is
-- quadratic again, on the tick where things are already going badly. That is
-- what `largest_bucket` is in the report for.
function M.for_each_near(store, width, x, y, fn)
  for dy = -1, 1 do
    for dx = -1, 1 do
      local c = (x + dx) + (y + dy) * width
      if c >= 0 and c < store.cells then
        M.for_each_in(store, c, fn)
      end
    end
  end
end
-- }}}

return M
