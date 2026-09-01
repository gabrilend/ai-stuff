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

-- 064-the-habitat.lua
--
-- Sight, hiding, wide bodies, and games that end.

local M = {}

-- {{{ function M.run(root, t)
function M.run(root, t)
  local Params = dofile(root .. "/src/028-maze-parameters.lua")
  local Stone  = dofile(root .. "/src/030-the-stone.lua")
  local Tick   = dofile(root .. "/src/039-the-tick.lua")

  local world = Tick.new_world(root, Params.with{ seed = 7, capacity = 300 },
                               "habitat", { dino = 60 })
  local Sight   = world.modules.Sight
  local Walking = world.modules.Walking
  local store   = world.store

  -- {{{ sight is neither blind nor omniscient
  --
  -- Both failure modes are silent and both look plausible from a screenshot. The
  -- one that actually happened was blindness: the eye height was measured from
  -- the layer a body stands *on* rather than from its feet, so every line began
  -- inside the block the creature was standing on and nothing could see
  -- anything -- one pair in four hundred and forty-one, and that pair adjacent.
  local rng = world.streams.spawn
  local by_range = {}
  for _, range in ipairs({ 4, 10, 26 }) do
    local seen, tried = 0, 0
    for _ = 1, 6000 do
      local a = world.floor[rng:next_below(#world.floor)]
      local b = world.floor[rng:next_below(#world.floor)]
      local ok, dist = Sight.can_see(store, a, store.height[a],
                                     b, store.height[b], range)
      if dist <= range then
        tried = tried + 1
        if ok then seen = seen + 1 end
      end
    end
    by_range[range] = (tried > 0) and (seen / tried) or 0
  end

  t.truthy(by_range[4] > 0.15,
           "close by, creatures can usually see each other -- got " ..
           string.format("%.0f%%", by_range[4] * 100))
  t.truthy(by_range[26] < 0.35,
           "across the maze, they usually cannot -- got " ..
           string.format("%.0f%%", by_range[26] * 100))
  t.truthy(by_range[4] > by_range[26],
           "and sight falls off with distance rather than being a constant")

  -- A body can always see itself, and a wall really does block.
  local anywhere = world.floor[1]
  t.truthy(Sight.can_see(store, anywhere, store.height[anywhere],
                         anywhere, store.height[anywhere], 30),
           "a body can see its own cell")
  -- }}}

  -- {{{ a wide body fits where it is told it fits, and nowhere else
  t.truthy(#world.wide_floor > 0,
           "somewhere in the maze admits a body wider than one cell")
  t.truthy(#world.wide_floor < world.report.floor_cells * 0.5,
           "and it is a small part of the floor -- " .. #world.wide_floor ..
           " of " .. world.report.floor_cells .. ". A dinosaur cannot go " ..
           "everywhere a little guy can, and that is the point of it.")

  local kind = world.creatures.KINDS[world.creatures.by_name("dino")]
  local wrong = 0
  for _, cell in ipairs(world.wide_floor) do
    if not Walking.footprint_fits(world, world.bodies, 0, kind, cell,
                                  store.height[cell]) then
      wrong = wrong + 1
    end
  end
  t.equal(wrong, 0, "every cell on the wide floor really does admit the footprint")
  -- }}}

  -- {{{ dinosaurs actually move, and stay in their own enclosure
  local start_piece = {}
  for id = 1, world.bodies.capacity do
    if world.bodies.alive[id] == 1 then
      start_piece[id] = world.wide_label[world.bodies.cell[id]]
    end
  end

  for _ = 1, 2400 do Tick.tick(world) end

  local moved, escaped, off_wide = 0, 0, 0
  local live = 0
  for id = 1, world.bodies.capacity do
    if world.bodies.alive[id] == 1 then
      live = live + 1
      if world.bodies.distance[id] > 1 then moved = moved + 1 end
      local piece = world.wide_label[world.bodies.cell[id]]
      if piece == nil then off_wide = off_wide + 1
      elseif start_piece[id] and piece ~= start_piece[id] then
        escaped = escaped + 1
      end
    end
  end

  t.truthy(moved > live * 0.7,
           "most dinosaurs get somewhere -- " .. moved .. " of " .. live ..
           ". They were spawned into corridors once and fifty-seven of ninety " ..
           "never moved at all.")
  t.equal(off_wide, 0,
          "no dinosaur is standing where a dinosaur cannot stand")
  t.equal(escaped, 0,
          "and none of them left the enclosure they started in, because the " ..
          "corridors between the plazas are one cell wide")
  -- }}}

  -- {{{ games start, and every one of them ends
  local c = world.counters
  local started = (c.games_chase or 0) + (c.games_hide_and_seek or 0)
                  + (c.games_follow_the_leader or 0)
  t.truthy(started > 4, "games do start -- " .. started .. " of them")

  local running = 0
  for g = 1, world.games.capacity do
    if world.games.alive[g] == 1 then running = running + 1 end
  end
  t.equal(running + (c.games_ended or 0), started,
          "every game that began is either running or has ended -- none leaked")

  t.truthy((c.tags or 0) > 0, "a chase does get tagged, and the roles swap")

  -- Nobody is in a game that is not there, and nobody is in one they are not
  -- listed in. Either would leave a body steered by a record nothing owns.
  local orphaned = 0
  for id = 1, world.bodies.capacity do
    if world.bodies.alive[id] == 1 and world.bodies.game[id] ~= 0 then
      local g = world.bodies.game[id]
      if world.games.alive[g] == 0 then
        orphaned = orphaned + 1
      else
        local listed = false
        for n = 1, world.games.count[g] do
          if world.games.player[(g - 1) * 6 + n] == id then listed = true end
        end
        if not listed then orphaned = orphaned + 1 end
      end
    end
  end
  t.equal(orphaned, 0, "no body is steered by a game that does not list it")
  -- }}}

  -- {{{ a failed search never fires in a loop
  --
  -- Every one of these was a real thrash: a body asks for a route it cannot
  -- have, gets nothing, so has nothing decided, so asks again next tick. The
  -- per-caller breakdown is what made them findable, and it is what would find
  -- the next one.
  local ticks = 2400
  t.truthy((c.searches_abandoned or 0) < live * ticks * 0.02,
           "failed searches are rare rather than a loop -- " ..
           (c.searches_abandoned or 0) .. " over " .. ticks .. " ticks with " ..
           live .. " bodies")
  -- }}}
end
-- }}}

return M
