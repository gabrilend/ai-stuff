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

-- 038-walking.lua
--
-- The row that steps from surface to surface. Little guys.
--
-- A walking body has no velocity. It occupies a surface, chooses an adjacent
-- one, and takes a fixed time to get there. Everything smooth about it is the
-- renderer's doing, and the simulation never reads that.

local M = {}

local Stone, Locomotion, Moving, Creatures

-- {{{ function M.link(stone, locomotion, moving, creatures)
function M.link(stone, locomotion, moving, creatures)
  Stone, Locomotion, Moving, Creatures = stone, locomotion, moving, creatures
end
-- }}}

M.INTENT_WANDER = 1
M.INTENT_IDLE   = 2
M.INTENT_ERRAND = 3

-- {{{ local function opposite(direction)
local function opposite(direction)
  if direction == 1 then return 2 end
  if direction == 2 then return 1 end
  if direction == 3 then return 4 end
  return 3
end
-- }}}

-- {{{ local function choose_step(world, bodies, id, kind)
-- Which adjacent surface to walk to next.
--
-- Weighted against turning around. An unweighted random walk on a graph spends
-- most of its time going back and forth across the same two cells, which reads
-- as broken rather than as aimless -- a body that is wandering should get
-- somewhere eventually, even if it did not mean to.
--
-- The weight is never zero. A body in a dead end must be able to turn around,
-- and a rule that forbids it produces a body that stands in a corner for the
-- rest of the run, vibrating.
local function choose_step(world, bodies, id, kind)
  local store = world.store
  local rng   = world.streams.wander_guy
  local cell, layer = bodies.cell[id], bodies.layer[id]
  local came_from = opposite(bodies.facing[id] == 0 and 1 or bodies.facing[id])

  local total = 0
  local weights, targets = {}, {}

  -- A destination somebody is standing in, or has already claimed this tick, is
  -- avoided rather than contested.
  --
  -- The buckets say who is standing where, and they are one tick stale. The
  -- claims say who is on their way there, and they are exact -- the move pass
  -- walks the roster in order, so a body deciding later sees what the bodies
  -- before it took. That is the "lower id gets the surface" rule, arrived at by
  -- the order the pass already runs in rather than by comparing ids.
  --
  -- A claim lasts the **journey**, not the tick. A step takes twenty-five ticks
  -- at the walker's speed, so a claim that expires after one leaves twenty-four
  -- during which anybody may take the destination -- which is where most of the
  -- shoving was coming from.
  --
  -- Without both, walkers at any real density spend their time stepping onto
  -- each other and being pushed apart, which reads on screen as a crowd shoving.
  local occupied = bodies.bucket_count
  local taken    = world.taken
  local now      = world.tick_count

  for di = 1, 4 do
    local answer, ncell, nlayer =
      Moving.step(Stone, store, cell, layer, di, kind.drop_limit, kind.body_height)
    if answer ~= Moving.BLOCKED then
      local w = (di == came_from) and kind.reverse_weight or 1.0
      if (occupied[ncell] or 0) > 0 then w = w * kind.crowd_weight end
      if (taken[ncell] or 0) > now then w = w * kind.crowd_weight end
      total = total + w
      weights[#weights + 1] = total
      targets[#targets + 1] = { di, ncell, nlayer }
    end
  end

  if #targets == 0 then return nil end

  local roll = rng:next_float() * total
  for k = 1, #targets do
    if roll <= weights[k] then return targets[k] end
  end
  return targets[#targets]
end
-- }}}

-- {{{ local function begin_errand(world, bodies, id, kind)
-- Sends a body somewhere in particular.
--
-- A wandering body never arrives, so there is no moment at which anything it was
-- doing finished -- which is fine for the body and useless for the camera, whose
-- whole job is to notice when a thing it is watching is over. An errand gives it
-- a destination and therefore an ending.
--
-- The path is computed **once** and kept. A body that pathfinds every tick costs
-- a hundred times what it should to do the same thing.
local function begin_errand(world, bodies, id, kind)
  local store  = world.store
  local Moving = world.modules.Moving
  local rng    = world.streams.wander_guy

  -- Somewhere near here, not somewhere in the maze. A block or two away is a
  -- walk of twenty or thirty steps: long enough to be a journey, short enough to
  -- plan in a fraction of a millisecond and to watch to its end.
  local x = bodies.cell[id] % store.width
  local y = (bodies.cell[id] - x) / store.width
  local bx = math.floor(x / world.block_size) + rng:next_between(-2, 2)
  local by = math.floor(y / world.block_size) + rng:next_between(-2, 2)
  if bx < 0 then bx = 0 elseif bx >= world.blocks_x then bx = world.blocks_x - 1 end
  if by < 0 then by = 0 elseif by >= world.blocks_y then by = world.blocks_y - 1 end

  local block = world.floor_blocks[bx + by * world.blocks_x]
  if not block or #block == 0 then return false end

  local target = block[rng:next_below(#block)]
  local target_layer = store.height[target]
  world.errand_cell[id]  = target
  world.errand_layer[id] = target_layer

  local path = world.paths[id]
  if not path then path = {}; world.paths[id] = path end

  local steps = Moving.find_path(Stone, store, bodies.cell[id], bodies.layer[id],
                                 target, target_layer,
                                 kind.drop_limit, kind.body_height,
                                 kind.search_budget, path)

  if not steps or steps == 0 then
    -- Announced and counted, which is the whole rule about fallbacks here. A
    -- search that quietly failed leaves a body standing still looking stuck for
    -- no reason anybody can name.
    world.counters.searches_abandoned = (world.counters.searches_abandoned or 0) + 1
    return false
  end

  world.path_length[id] = steps
  world.path_at[id]     = 1
  world.replanned[id]   = false
  bodies.intent[id]     = M.INTENT_ERRAND
  world.counters.errands = (world.counters.errands or 0) + 1
  return true
end
-- }}}

-- {{{ local function advance_errand(world, bodies, id, kind, dt)
-- One step along a stored path.
--
-- Returns true while the errand continues. When the next surface is no longer
-- adjacent -- which is what a fall does -- the path is abandoned rather than
-- repaired, because a path from where the body used to be is not a path.
local function advance_errand(world, bodies, id, kind, dt)
  local path = world.paths[id]
  local at   = world.path_at[id]
  if not path or at > world.path_length[id] then return false end

  if bodies.progress[id] > 0 then
    bodies.progress[id] = bodies.progress[id] + dt / kind.step_seconds
    if bodies.progress[id] >= 1 then
      bodies.cell[id]  = bodies.intent_cell[id]
      bodies.layer[id] = bodies.intent_layer[id]
      bodies.progress[id] = 0
      bodies.distance[id] = bodies.distance[id] + 1
      bodies.rest_timer[id] = 0
      local x, y = Stone.coords(world.store, bodies.cell[id])
      bodies.x[id] = x + 0.5
      bodies.y[id] = y + 0.5
      bodies.z[id] = Locomotion.surface_top(bodies.layer[id])
      world.path_at[id] = at + 1
    end
    return true
  end

  local Moving = world.modules.Moving
  local next_cell, next_layer = Moving.unpack(world.store, path[at])

  -- Is it actually adjacent? A body that fell is somewhere its path does not
  -- start from.
  local ok = false
  for di = 1, 4 do
    local answer, nc, nl = Moving.step(Stone, world.store, bodies.cell[id],
                                       bodies.layer[id], di,
                                       kind.drop_limit, kind.body_height)
    if answer ~= Moving.BLOCKED and nc == next_cell and nl == next_layer then
      bodies.facing[id] = di
      ok = true
      break
    end
  end

  if not ok then
    -- Knocked off the path -- pushed aside by somebody, or landed after a fall.
    -- Replan once from where the body actually is, toward where it was actually
    -- going. Abandoning outright throws the errand away for a displacement of
    -- one cell, and the errand is the only thing in a walker's life that ever
    -- finishes.
    if world.replanned[id] then
      world.path_length[id] = 0
      world.counters.errands_abandoned = (world.counters.errands_abandoned or 0) + 1
      return false
    end
    world.replanned[id] = true

    local steps = Moving.find_path(Stone, world.store,
                                   bodies.cell[id], bodies.layer[id],
                                   world.errand_cell[id], world.errand_layer[id],
                                   kind.drop_limit, kind.body_height,
                                   kind.search_budget, path)
    world.counters.errands_replanned = (world.counters.errands_replanned or 0) + 1
    if not steps or steps == 0 then
      world.path_length[id] = 0
      world.counters.errands_abandoned = (world.counters.errands_abandoned or 0) + 1
      return false
    end
    world.path_length[id] = steps
    world.path_at[id] = 1
    return true
  end

  bodies.from_cell[id]    = bodies.cell[id]
  bodies.from_layer[id]   = bodies.layer[id]
  bodies.intent_cell[id]  = next_cell
  bodies.intent_layer[id] = next_layer
  bodies.progress[id]     = 1e-6
  world.taken[next_cell]  = world.tick_count + world.claim_ticks
  return true
end
-- }}}

-- {{{ function M.begin_step(world, bodies, id, kind)
-- Sets up the journey from the current surface to the next one.
function M.begin_step(world, bodies, id, kind)
  local pick = choose_step(world, bodies, id, kind)
  if not pick then
    -- Nowhere to go at all. Legal -- a body can be standing on a surface with
    -- four walls around it, which the validator counts as a dead end -- so it
    -- idles rather than erroring, and the report is where that shows up.
    bodies.intent[id] = M.INTENT_IDLE
    bodies.timer[id]  = 1.0
    return false
  end

  bodies.from_cell[id]    = bodies.cell[id]
  bodies.from_layer[id]   = bodies.layer[id]
  bodies.facing[id]       = pick[1]
  bodies.intent_cell[id]  = pick[2]
  bodies.intent_layer[id] = pick[3]
  bodies.progress[id]     = 0
  bodies.intent[id]       = M.INTENT_WANDER
  world.taken[pick[2]]    = world.tick_count + world.claim_ticks
  return true
end
-- }}}

-- {{{ function M.advance(world, bodies, roster, first, last, dt)
-- Moves a slice of the walking roster.
--
-- The body is **either at one surface or at another**. It is never between them
-- as far as anything that matters is concerned, which is what makes both spatial
-- questions simple: which cell it is in is exactly one cell, always, and who is
-- near it is one bucket lookup. A continuous position would put a walker in two
-- cells for half of every step and every question about it would need a
-- tie-breaking rule.
function M.advance(world, bodies, roster, first, last, dt)
  local store = world.store
  local kinds = Creatures.KINDS

  for slot = first, last do
    local id = roster[slot]
    if bodies.alive[id] == 1 then
      local kind = kinds[bodies.kind[id]]

      -- A body in a duel is owned by the duel. Its locomotion does not advance,
      -- which is what "both fencers stand still and face each other" means when
      -- written down as code rather than as a sentence.
      if bodies.duel[id] ~= 0 then goto continue end

      -- Falling first, and it is the shared fall, not one of this row's own. A
      -- walker that has walked off a ledge and a ball that has rolled off one
      -- are doing the same thing, and writing it twice is how they start
      -- disagreeing about what a fall is.
      local ground = Locomotion.floor_under(Stone, store, bodies, id)
      if ground >= 0 and bodies.z[id] > ground + 0.02 then
        Locomotion.apply_falling(Stone, store, bodies, id, kind, dt)
        -- The step it was taking is abandoned rather than resumed: the surface
        -- it was heading for is no longer adjacent to where it has landed.
        bodies.progress[id] = 0
        bodies.intent[id]   = 0
        Locomotion.settle_stance(Stone, store, bodies, id)
      elseif bodies.intent[id] == M.INTENT_IDLE then
        bodies.timer[id] = bodies.timer[id] - dt
        bodies.rest_timer[id] = bodies.rest_timer[id] + dt

        -- The one idle that turns. A quarter turn every so often, rather than
        -- continuously, because a body rotating smoothly reads as a turret.
        local row = Creatures.IDLES[bodies.idle_row[id]]
        if row and row.turn then
          local elapsed = (bodies.idle_total[id] or 1) - bodies.timer[id]
          bodies.facing[id] = 1 + (math.floor(elapsed * 1.2) % 4)
        end

        if bodies.timer[id] <= 0 then
          bodies.intent[id]   = 0
          bodies.idle_row[id] = 0
          -- A shared idle ends for both, always. A body left in one whose
          -- partner has walked off is doing a synchronised animation at an empty
          -- cell, which is funny once and then is a bug.
          M.release_partner(world, bodies, id)
        end
      elseif bodies.intent[id] == M.INTENT_ERRAND then
        if not advance_errand(world, bodies, id, kind, dt) then
          -- Arrived, or the path stopped making sense. Either way this is the
          -- moment something the body was doing finished, which is the only
          -- thing the director can notice.
          bodies.intent[id]  = 0
          bodies.progress[id] = 0
          world.arrived[id]  = world.tick_count
          world.counters.arrivals = (world.counters.arrivals or 0) + 1
        end

      elseif bodies.intent[id] == M.INTENT_WANDER then
        bodies.progress[id] = bodies.progress[id] + dt / kind.step_seconds
        if bodies.progress[id] >= 1 then
          bodies.cell[id]  = bodies.intent_cell[id]
          bodies.layer[id] = bodies.intent_layer[id]
          bodies.progress[id] = 0
          bodies.intent[id]   = 0
          bodies.distance[id] = bodies.distance[id] + 1
          bodies.rest_timer[id] = 0

          local x, y = Stone.coords(store, bodies.cell[id])
          bodies.x[id] = x + 0.5
          bodies.y[id] = y + 0.5
          bodies.z[id] = Locomotion.surface_top(bodies.layer[id])
        end
      else
        -- Nothing decided. Idle sometimes, walk otherwise -- standing still for
        -- a moment is most of what makes a crowd read as alive rather than as a
        -- flock of things all going somewhere.
        if kind.errand_chance and world.streams.wander_guy:chance(kind.errand_chance)
           and begin_errand(world, bodies, id, kind) then
          -- off it goes
        elseif world.streams.idle:chance(kind.idle_chance) then
          local row, seconds = Creatures.pick_idle(world.streams.idle, kind.name)
          bodies.intent[id]   = M.INTENT_IDLE
          bodies.idle_row[id] = row
          bodies.timer[id]    = seconds
          bodies.idle_total[id] = seconds
        else
          M.begin_step(world, bodies, id, kind)
        end
      end

      Locomotion.check_in_world(Stone, store, bodies, id, "walking")
      ::continue::
    end
  end
end
-- }}}

-- {{{ function M.release_partner(world, bodies, id)
-- Ends a shared idle for both bodies, or for this one alone if the other is
-- already gone.
--
-- The generation check is what catches the gone case. A partner id on its own
-- would still name a live body -- whichever one moved into the recycled slot --
-- and this one would go on being paired with a stranger who has never heard of
-- it.
function M.release_partner(world, bodies, id)
  local other = bodies.partner[id]
  bodies.partner[id] = 0
  bodies.partner_generation[id] = 0
  if other == 0 then return end

  if bodies.alive[other] == 1 and bodies.partner[other] == id then
    bodies.partner[other] = 0
    bodies.partner_generation[other] = 0
    bodies.intent[other]  = 0
    bodies.idle_row[other] = 0
    bodies.timer[other]   = 0
  end
end
-- }}}

-- {{{ function M.idle_offset(Creatures, bodies, id)
-- What an idle does to a body's drawn height, in layers.
--
-- All of it, and it is the entire animation system. A row's bob and rate make a
-- sine; its squat is a constant. Two numbers and a sine, per body, in the
-- renderer, read from a table -- which is why a body standing still costs one
-- timer decrement a tick and a crowd of them costs nothing worth measuring.
function M.idle_offset(Creatures, bodies, id)
  local index = bodies.idle_row[id]
  if index == 0 then return 0 end
  local row = Creatures.IDLES[index]
  if not row then return 0 end

  local total   = bodies.idle_total[id]
  if total <= 0 then return row.squat or 0 end
  local elapsed = total - bodies.timer[id]

  -- Eased in and out over the whole idle, so a squat does not snap on and off.
  local ramp = math.sin(math.min(1, math.max(0, elapsed / total)) * math.pi)
  local bob  = math.sin(elapsed * row.rate * 2 * math.pi) * (row.bob or 0)
  return bob + (row.squat or 0) * ramp
end
-- }}}

-- {{{ function M.drawn_position(bodies, id)
-- Where the renderer puts a walking body, and the only place the interpolation
-- happens.
--
-- The simulation never calls this. That separation is the whole reason a
-- smoothed graph walk was chosen for these bodies over continuous motion: the
-- simulation gets a graph, which is cheap and exact, and the eye gets
-- smoothness, which is a lie the renderer tells.
--
-- The arc on a vertical step is a cosmetic hack and it is written down because
-- somebody tidying up will delete it. Interpolating a one-layer climb in a
-- straight line makes the body slide up a diagonal, which reads as ascending an
-- invisible ramp rather than as climbing; a small hump peaking at the middle of
-- the step fixes it. A flat step gets no arc, because the difference is zero.
-- It takes no Stone argument. It used to, and the parameter shadowed the
-- module's own -- so every caller passing nil for it got a nil index, in the
-- draw path, only for walking bodies, which meant it did not show up until the
-- first screenshot of a scene that had any. That screenshot was written off as
-- the window manager throttling a background window.
function M.drawn_position(store, bodies, id)
  if not Stone then
    error("038-walking has not been linked. Every world loads its own copy of " ..
          "every module, so the copy the viewer loaded is not the copy the " ..
          "tick linked -- take it from world.modules.Walking rather than " ..
          "loading another.")
  end
  local p = bodies.progress[id]
  if p <= 0 or (bodies.intent[id] ~= M.INTENT_WANDER
                and bodies.intent[id] ~= M.INTENT_ERRAND) then
    local x, y = Stone.coords(store, bodies.cell[id])
    return x + 0.5, y + 0.5, bodies.z[id]
  end

  local fx, fy = Stone.coords(store, bodies.from_cell[id])
  local tx, ty = Stone.coords(store, bodies.intent_cell[id])
  local fz = bodies.from_layer[id] + 1
  local tz = bodies.intent_layer[id] + 1

  local x = (fx + 0.5) + ((tx + 0.5) - (fx + 0.5)) * p
  local y = (fy + 0.5) + ((ty + 0.5) - (fy + 0.5)) * p
  local z = fz + (tz - fz) * p

  local rise = math.abs(tz - fz)
  if rise > 0 then
    z = z + math.sin(p * math.pi) * 0.35 * rise
  end

  return x, y, z
end
-- }}}

return M
