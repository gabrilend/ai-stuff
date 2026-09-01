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

-- 048-the-report.lua
--
-- The numbers a run produces, and how they are printed.
--
-- Built as a table of named numbers rather than as printed prose, because the
-- headless runner, the terminal viewer, the overnight sweep and the phase demo
-- all consume it, and four things reading four different formats is four things
-- that disagree about what a run did.

local M = {}

-- {{{ function M.gather(world)
-- Everything worth knowing about a run, as one table.
function M.gather(world)
  local b = world.bodies
  local creatures = world.creatures
  local r = {}

  for k, v in pairs(world.report) do r[k] = v end
  for k, v in pairs(world.counters) do r[k] = v end

  r.scene       = world.scene
  r.ticks       = world.tick_count
  r.seconds     = world.tick_count / 60
  r.live        = b.live
  r.capacity    = b.capacity

  -- Per locomotion kind rather than in total. A kind whose distance collapses
  -- has stopped working, and in a window full of other kinds that still work it
  -- is invisible -- which is the whole argument for measuring anything at all.
  r.by_kind = {}
  local never_moved = 0
  local lowest, highest = 99, -1

  for id = 1, b.capacity do
    if b.alive[id] == 1 then
      local kind = creatures.KINDS[b.kind[id]]
      local row = r.by_kind[kind.name]
      if not row then
        row = { live = 0, distance = 0, still = 0, lowest = 99, highest = -1 }
        r.by_kind[kind.name] = row
      end
      row.live = row.live + 1
      row.distance = row.distance + b.distance[id]
      if b.distance[id] < 0.5 then
        row.still = row.still + 1
        never_moved = never_moved + 1
      end
      local l = b.layer[id]
      if l < row.lowest  then row.lowest  = l end
      if l > row.highest then row.highest = l end
      if l < lowest  then lowest  = l end
      if l > highest then highest = l end
    end
  end

  r.never_moved   = never_moved
  r.lowest_layer  = lowest
  r.highest_layer = highest
  return r
end
-- }}}

-- {{{ function M.describe(r, pass_time)
-- The report as lines of text.
function M.describe(r, pass_time)
  local lines = {}
  local function add(fmt, ...) lines[#lines + 1] = string.format(fmt, ...) end

  add("seed %d   %d x %d x %d   scene '%s'   %d ticks (%.1f s)",
      r.seed, r.width, r.depth, r.layers, r.scene, r.ticks, r.seconds)
  add("")
  add("  the maze")
  add("    floor cells          %d", r.floor_cells or 0)
  add("    staircases           %d  (%d for connectivity, %d beyond it)",
      (r.staircases_cut or 0) + (r.extra_staircases or 0),
      r.staircases_cut or 0, r.extra_staircases or 0)
  add("    orphan cells filled  %d", r.orphans_filled or 0)
  add("    diameter             %d steps", r.diameter or 0)
  add("    fill fraction        %.3f", r.fill_fraction or 0)
  add("")
  add("  the bodies")
  add("    live                 %d of %d capacity", r.live, r.capacity)
  add("    spawned              %d", r.spawned or 0)
  add("    retired at rest      %d", r.removed_at_rest or 0)
  add("    spawns skipped       %d   (a maze whose spawn points are all blocked)",
      r.spawn_skipped or 0)
  add("    never moved          %d   (one is stuck; forty is a broken rule)",
      r.never_moved or 0)
  add("    layers visited       %d to %d", r.lowest_layer or 0, r.highest_layer or 0)
  add("    largest bucket       %d   (climbing means the meet pass is going quadratic)",
      r.largest_bucket or 0)

  local names = {}
  for name in pairs(r.by_kind or {}) do names[#names + 1] = name end
  table.sort(names)
  if #names > 0 then
    add("")
    add("  by kind")
    for _, name in ipairs(names) do
      local row = r.by_kind[name]
      add("    %-8s live %4d   mean distance %7.2f cells   still %3d   layers %2d to %2d",
          name, row.live, row.distance / math.max(1, row.live), row.still,
          row.lowest, row.highest)
    end
  end

  if pass_time then
    local total = 0
    for _, secs in pairs(pass_time) do total = total + secs end
    if total > 0 then
      add("")
      add("  where the time went")
      local order = {}
      for name in pairs(pass_time) do order[#order + 1] = name end
      table.sort(order, function(a, b) return pass_time[a] > pass_time[b] end)
      for _, name in ipairs(order) do
        add("    %-8s %7.3f s   %4.1f%%   %6.1f us per tick",
            name, pass_time[name], 100 * pass_time[name] / total,
            1e6 * pass_time[name] / math.max(1, r.ticks))
      end
    end
  end

  return table.concat(lines, "\n")
end
-- }}}

-- {{{ function M.as_table_row(r)
-- One line per run, for the overnight sweep's table. Tab separated, so it goes
-- into anything that reads columns without an escaping question ever arising.
function M.as_table_row(r)
  return table.concat({
    r.seed, r.scene, r.ticks,
    r.floor_cells or 0,
    (r.staircases_cut or 0) + (r.extra_staircases or 0),
    r.diameter or 0,
    r.live, r.spawned or 0, r.removed_at_rest or 0,
    r.never_moved or 0, r.largest_bucket or 0,
    string.format("%.2f", (r.lowest_layer or 0)),
    string.format("%.2f", (r.highest_layer or 0)),
  }, "\t")
end
-- }}}

-- {{{ function M.table_header()
function M.table_header()
  return table.concat({
    "seed", "scene", "ticks", "floor", "stairs", "diameter",
    "live", "spawned", "retired", "still", "bucket", "low", "high",
  }, "\t")
end
-- }}}

-- {{{ function M.say_goodbye(root, r)
-- The last thing a run does is write goodbye to output/.
function M.say_goodbye(root, r)
  local f = io.open(root .. "/output/goodbye", "w")
  if not f then return end
  f:write("goodbye\n\n")
  f:write(M.describe(r))
  f:write("\n")
  f:close()
end
-- }}}

return M
