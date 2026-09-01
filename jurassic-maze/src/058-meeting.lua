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

-- 058-meeting.lua
--
-- The one pass where two bodies affect each other, and the table of what that
-- means.
--
-- Everything that happens between two bodies happens here. No other pass reads
-- one body's state and changes another's, and that is not tidiness: pairing is
-- the only thing in the simulation that is not independent per body, and
-- confining it to one pass is what lets every other pass be split across cores
-- without anybody thinking about it.
--
-- This pass is small precisely because it is the one that cannot be.

local M = {}

local Stone, BodyStore, Walking, Creatures

-- {{{ function M.link(stone, body_store, walking, creatures)
function M.link(stone, body_store, walking, creatures)
  Stone, BodyStore, Walking, Creatures = stone, body_store, walking, creatures
end
-- }}}

-- {{{ local function share_an_idle(world, bodies, a, b)
-- Two little guys, both standing about, both willing: give them the same idle,
-- the same clock, and point them at each other.
--
-- That is the entire mechanism, and it is enough to produce the thing that reads
-- as two people having a conversation. **Nobody is having a conversation.**
-- There is no dialogue, no relationship, and no memory of it afterwards. There
-- are two timers set to the same value and two facings pointed at each other,
-- and the temptation to add the relationship later would be a great deal of
-- machinery for something the timers already deliver.
local function share_an_idle(world, bodies, a, b)
  local kind = Creatures.KINDS[bodies.kind[a]]
  if bodies.intent[a] ~= Walking.INTENT_IDLE then return false end
  if bodies.intent[b] ~= Walking.INTENT_IDLE then return false end
  if bodies.partner[a] ~= 0 or bodies.partner[b] ~= 0 then return false end

  -- Both must have been standing about for a while. Without the wait, two
  -- bodies that happen to pause on the same tick lock together instantly and
  -- the maze fills with pairs, which reads as magnetism rather than as company.
  local waited = kind.notice_seconds or 1.5
  if bodies.rest_timer[a] < waited or bodies.rest_timer[b] < waited then
    return false
  end

  local row, seconds = Creatures.pick_idle(world.streams.meeting, kind.name)
  for _, id in ipairs({ a, b }) do
    bodies.intent[id]     = Walking.INTENT_IDLE
    bodies.idle_row[id]   = row
    bodies.timer[id]      = seconds
    bodies.idle_total[id] = seconds
  end

  bodies.partner[a] = b
  bodies.partner_generation[a] = bodies.generation[b]
  bodies.partner[b] = a
  bodies.partner_generation[b] = bodies.generation[a]

  -- Face each other. Which way that is comes from the sign of the difference,
  -- and a pair in the same cell -- which the overlap rule is about to separate
  -- anyway -- keeps whatever facing it had.
  local ax, ay = Stone.coords(world.store, bodies.cell[a])
  local bx, by = Stone.coords(world.store, bodies.cell[b])
  if bx ~= ax then
    bodies.facing[a] = (bx > ax) and 1 or 2
    bodies.facing[b] = (bx > ax) and 2 or 1
  elseif by ~= ay then
    bodies.facing[a] = (by > ay) and 3 or 4
    bodies.facing[b] = (by > ay) and 4 or 3
  end

  world.counters.shared_idles = (world.counters.shared_idles or 0) + 1
  return true
end
-- }}}

-- {{{ local function separate(world, bodies, a, b)
-- Two bodies in the same cell, pushed apart along the line between them.
--
-- Happens when one spawns on top of another, or when a step lands two bodies on
-- the same surface in one tick. If neither can move they stay overlapped and it
-- is **counted**: an overlap that persists is a real problem, one that resolves
-- next tick is not, and counting is the only way to tell them apart.
local function separate(world, bodies, a, b)
  if bodies.cell[a] ~= bodies.cell[b] then return end
  if bodies.layer[a] ~= bodies.layer[b] then return end

  -- A rolling body is never pushed. It has a continuous position and its own
  -- collision, and this rule moves a body by *setting its cell* -- which for a
  -- ball is a teleport, in the middle of an arc, followed by the rolling code
  -- picking up the pieces.
  --
  -- Leaving it in made a scene with balls and walkers together four times slower
  -- than the sum of the two apart, which is the sort of number that looks like a
  -- scaling problem and is a rule firing where it should not.
  local rolling = world.creatures.ROLLING
  local a_rolls = Creatures.KINDS[bodies.kind[a]].locomotion == rolling
  local b_rolls = Creatures.KINDS[bodies.kind[b]].locomotion == rolling
  if a_rolls and b_rolls then return end
  if a_rolls then a, b = b, a end
  if Creatures.KINDS[bodies.kind[b]].locomotion == rolling then return end

  -- Move whichever of the two is *not* on its way somewhere.
  --
  -- Always displacing the higher id is simpler and quietly destroys errands: a
  -- body pushed a cell sideways is no longer at the start of the path it was
  -- following, so the path is abandoned. At any real density that happened to
  -- nineteen errands in twenty, and the feature looked as though it did not
  -- work rather than as though it was being interrupted.
  local Walking = world.modules.Walking
  if bodies.intent[b] == Walking.INTENT_ERRAND
     and bodies.intent[a] ~= Walking.INTENT_ERRAND then
    a, b = b, a
  end

  local Moving = world.modules.Moving
  local kind = Creatures.KINDS[bodies.kind[b]]

  for di = 1, 4 do
    local answer, nc, nl = Moving.step(Stone, world.store, bodies.cell[b],
                                       bodies.layer[b], di,
                                       kind.drop_limit, kind.body_height)
    -- The footprint check, which the step rule does not make.
    --
    -- Without it this is the one place in the project that can put a body
    -- somewhere it does not fit: a dinosaur shoved sideways ends up straddling a
    -- wall, off the wide floor entirely, and every rule that assumes a body
    -- stands where a body can stand is then quietly wrong about it. Eighteen of
    -- sixty, over forty seconds.
    if answer ~= Moving.BLOCKED
       and Walking.footprint_fits(world, bodies, b, kind, nc, nl) then
      bodies.cell[b]  = nc
      bodies.layer[b] = nl
      local x, y = Stone.coords(world.store, nc)
      bodies.x[b] = x + 0.5
      bodies.y[b] = y + 0.5
      bodies.z[b] = nl + 1
      bodies.progress[b] = 0
      bodies.intent[b]   = 0
      world.counters.overlaps_resolved = (world.counters.overlaps_resolved or 0) + 1
      return
    end
  end

  world.counters.overlaps_stuck = (world.counters.overlaps_stuck or 0) + 1
end
-- }}}

-- {{{ function M.new_table(creatures)
-- What a pairing means, indexed by the two creature kinds.
--
-- A table rather than a chain of conditions, for two reasons. The chain grows as
-- the square of the number of creatures. And a table can be **printed** -- being
-- able to read the complete list of what any two things do when they meet is the
-- fastest way to notice that nobody wrote down what happens when a golem meets a
-- ball.
function M.new_table(creatures)
  local guy    = creatures.by_name("guy")
  local ball   = creatures.by_name("ball")
  local fencer = creatures.by_name("fencer")
  local dino   = creatures.by_name("dino")

  local meet = {}
  local function pair(a, b, what, fn)
    meet[a] = meet[a] or {}
    meet[a][b] = { what = what, fn = fn }
    if a ~= b then
      meet[b] = meet[b] or {}
      -- The mirror shares the function and swaps the arguments, so a rule is
      -- written once and cannot be written twice differently.
      --
      -- A pairing with **no** function gets no wrapper. Wrapping a nil produces
      -- an entry that looks callable and is not, and the pass calls it -- which
      -- only happens for the pairings where nothing was supposed to happen, so
      -- it waits until a scene containing both kinds is first run.
      meet[b][a] = { what = what, fn = fn and function(world, bodies, x, y)
        return fn(world, bodies, y, x)
      end or nil }
    end
  end


  -- The delve. Every pairing among its creatures goes through one function,
  -- because what any two of them do to each other is a lookup in the solution
  -- table rather than a rule per pair -- and a rule per pair is nine rules that
  -- have to agree with a table of three.
  --
  -- **Written first, so that the specific pairs below overwrite it.** Written
  -- last it silently replaced them -- including dinosaur meets dinosaur, which
  -- is where the games start, so games simply stopped happening with no error
  -- and nothing in any counter.
  local delvers = { creatures.by_name("human"), creatures.by_name("golem"),
                    creatures.by_name("vine"), creatures.by_name("automaton"),
                    dino }
  local function delve_rule(world, bodies, x, y)
    return world.modules.Delve.meets(world, bodies, x, y)
  end
  for _, a in ipairs(delvers) do
    for _, b in ipairs(delvers) do
      meet[a] = meet[a] or {}
      meet[a][b] = { what = "the delve's rules", fn = delve_rule }
    end
  end

  pair(guy, guy, "stand about together", share_an_idle)
  pair(ball, ball, "nothing", nil)
  pair(ball, guy, "nothing", nil)
  pair(ball, fencer, "nothing", nil)
  pair(guy, fencer, "they pass", nil)
  pair(fencer, fencer, "a duel, if their sides differ", function(world, bodies, a, b)
    return world.modules.Duels.meets(world, bodies, a, b)
  end)
  pair(dino, dino, "sometimes a game", function(world, bodies, a, b)
    return world.modules.Games.maybe_start(world, bodies, a, b)
  end)
  pair(dino, guy, "the guy gets out of the way", nil)
  pair(dino, ball, "nothing", nil)
  pair(dino, fencer, "nothing", nil)

  return meet
end
-- }}}

-- {{{ function M.pass(world, dt)
-- The sweep. For each body, its own bucket and the eight around it, considering
-- only bodies whose id is greater than its own.
--
-- That one comparison is what stops every pair being considered twice, instead
-- of a set of already-seen pairs -- and it keeps the pass a single sweep with a
-- bounded amount of work per body no matter how many bodies there are.
--
-- The bucket ranges are walked directly rather than through a callback. The
-- callback version reads better and allocates a closure per body per tick, which
-- at seven hundred bodies is a quarter of a million closures a minute for a loop
-- of four lines -- and the collector then arrives in the middle of a frame, for
-- reasons nothing on screen explains.
function M.pass(world, dt)
  local bodies = world.bodies
  local store  = world.store
  local meet   = world.meet
  local width  = store.width
  local cells  = store.cells

  local count, offset, ids = bodies.bucket_count, bodies.bucket_offset,
                             bodies.bucket_ids
  local alive, cell, kind = bodies.alive, bodies.cell, bodies.kind

  local meetings = 0

  for id = 1, bodies.capacity do
    if alive[id] == 1 then
      local here = cell[id]
      local x = here % width
      local y = (here - x) / width
      local mine = meet[kind[id]]

      for dy = -1, 1 do
        local row = (y + dy) * width
        for dx = -1, 1 do
          local c = row + x + dx
          if c >= 0 and c < cells then
            local first = offset[c] + 1
            local last  = first + count[c] - 1
            for k = first, last do
              local other = ids[k]
              if other > id and alive[other] == 1 then
                meetings = meetings + 1
                separate(world, bodies, id, other)
                local rule = mine and mine[kind[other]]
                if rule and rule.fn then
                  rule.fn(world, bodies, id, other)
                end
              end
            end
          end
        end
      end
    end
  end

  world.counters.meetings = (world.counters.meetings or 0) + meetings
end
-- }}}

-- {{{ function M.describe(world)
-- The whole meet table, printed. Nothing reads this; it is here so that a person
-- can.
function M.describe(world)
  local lines = {}
  local kinds = world.creatures.KINDS
  for a = 1, #kinds do
    for b = 1, #kinds do
      local rule = world.meet[a] and world.meet[a][b]
      lines[#lines + 1] = string.format("  %-10s meets %-10s  %s",
        kinds[a].name, kinds[b].name, rule and rule.what or "nothing written down")
    end
  end
  return table.concat(lines, "\n")
end
-- }}}

return M
