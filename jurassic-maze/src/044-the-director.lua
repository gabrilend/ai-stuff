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

-- 044-the-director.lua
--
-- Decides what is worth watching and when it stops being.
--
-- Separate from the camera, because "where is the camera" and "who is
-- interesting" are two questions that change at completely different rates. The
-- camera holds four numbers and is dumb; this holds an opinion.

local M = {}

M.FREE     = 1
M.FOLLOW   = 2
M.STAKEOUT = 3

M.MODE_NAMES = { "free", "following", "staking out" }

-- {{{ function M.new()
-- The director, and every setting the panel can move.
--
-- The settings are here rather than in the creature table because they are not
-- about the world. Nothing below the viewer reads one, and a test asserts that
-- driving every one of them through its whole range leaves the simulation's
-- checksum unchanged.
function M.new()
  return {
    mode        = M.FREE,
    subject     = 0,
    subject_generation = 0,
    dwell       = 0,          -- seconds spent staking out the current spot
    verdict     = nil,        -- which predicate fired, by name
    verdict_at  = 0,

    settings = {
      -- Asked for by name: "a toggle adjustable in-game with a keybind or
      -- something that lets the user swap to a new target randomly, and whether
      -- it should follow that target when it does so, or if it stays there and
      -- watches for N seconds, definable with a slider."
      follow_on_swap = true,
      dwell_seconds  = 8.0,
      auto_swap      = true,
      same_team_only = false,
      stay_with_the_loser = true,
      boredom_seconds = 12.0,
      ease            = 0.10,
    },
  }
end
-- }}}

-- The settings, as rows, so the panel is a loop rather than a control per
-- setting -- and so this list is the one place a setting is described.
M.CONTROLS = {
  { key = "auto_swap",      kind = "toggle", label = "swap on its own" },
  { key = "follow_on_swap", kind = "toggle", label = "follow, rather than stake out" },
  { key = "same_team_only", kind = "toggle", label = "stay with the same side" },
  { key = "stay_with_the_loser", kind = "toggle", label = "stay with the loser" },
  { key = "dwell_seconds",  kind = "slider", label = "stakeout, seconds", low = 1, high = 60 },
  { key = "boredom_seconds", kind = "slider", label = "boredom, seconds", low = 2, high = 60 },
  { key = "ease",           kind = "slider", label = "how fast it catches up", low = 0.02, high = 0.5 },
}

-- {{{ local function still_there(world, director)
local function still_there(world, director)
  local bodies = world.bodies
  return world.modules.BodyStore.is_valid(bodies, director.subject,
                                          director.subject_generation)
end
-- }}}

-- {{{ function M.verdict(world, director)
-- Is this still worth watching?
--
-- An ordered list of named predicates rather than a boolean, so the panel can
-- say *which* one fired. That is what makes "swap on its own" being off usable
-- rather than blind: the panel says this one is done, and the person decides.
function M.verdict(world, director)
  if director.subject == 0 then return "nobody" end
  if not still_there(world, director) then return "gone" end

  local bodies = world.bodies
  local id = director.subject

  -- Phase five will add "its duel ended" here, above the rest.

  if world.arrived[id] and world.arrived[id] > director.verdict_at then
    return "arrived"
  end

  if bodies.rest_timer[id] > director.settings.boredom_seconds then
    return "bored"
  end

  if director.mode == M.STAKEOUT
     and director.dwell > director.settings.dwell_seconds then
    return "seen enough"
  end

  return nil
end
-- }}}

-- {{{ function M.pick(world, director)
-- The next subject, from the camera stream and only from the camera stream.
--
-- **This is the rule that keeps a session reproducible while somebody is mashing
-- the swap key.** The stream is never read by the simulation and the simulation
-- is never read for randomness by this; the maze does not care that you are
-- watching, and the test that proves it presses the key a thousand times and
-- compares the simulation's checksum against a run where it was never pressed.
--
-- The choice is weighted toward bodies that are doing something, by drawing one
-- number against a running total rather than by sorting. Sorting the whole
-- population for a choice that only needs to be plausible is work proportional
-- to the population, every swap.
function M.pick(world, director)
  local rng    = world.streams.camera
  local bodies = world.bodies
  local Walking = world.modules.Walking

  local team = 0
  if director.settings.same_team_only and director.subject ~= 0
     and still_there(world, director) then
    team = bodies.team[director.subject]
  end

  local total, chosen = 0, 0
  for id = 1, bodies.capacity do
    if bodies.alive[id] == 1 and id ~= director.subject then
      if team == 0 or bodies.team[id] == team then
        -- A body on an errand or in company is worth more than one standing
        -- about; a body standing about is worth more than nothing.
        local weight = 1
        if bodies.intent[id] == Walking.INTENT_ERRAND then weight = 6 end
        if bodies.partner[id] ~= 0 then weight = 9 end
        if bodies.vz[id] ~= 0 then weight = 7 end          -- falling

        -- Reservoir sampling: one pass, no list built, and the probability of
        -- each body ending up chosen is its weight over the total. A candidate
        -- array would be an allocation of a few hundred entries per keypress
        -- for a result that is one integer.
        total = total + weight
        if rng:next_float() * total < weight then chosen = id end
      end
    end
  end

  if chosen == 0 then
    world.counters.swaps_with_nobody = (world.counters.swaps_with_nobody or 0) + 1
    return
  end

  director.subject = chosen
  director.subject_generation = bodies.generation[chosen]
  director.mode = director.settings.follow_on_swap and M.FOLLOW or M.STAKEOUT
  director.dwell = 0
  director.verdict = nil
  director.verdict_at = world.tick_count
  world.counters.swaps = (world.counters.swaps or 0) + 1
end
-- }}}

-- {{{ function M.free(director)
function M.free(director)
  director.mode = M.FREE
  director.subject = 0
  director.subject_generation = 0
  director.verdict = nil
end
-- }}}

-- {{{ function M.update(world, director, camera, Projection, Camera, Walking, dt, screen_w, screen_h)
-- One frame of directing. Moves the camera; touches nothing in the world.
function M.update(world, director, camera, Projection, Camera, Walking, dt,
                  screen_w, screen_h)
  if director.mode == M.FREE then
    director.verdict = nil
    return
  end

  director.dwell = director.dwell + dt
  director.verdict = M.verdict(world, director)

  if director.verdict and director.settings.auto_swap then
    M.pick(world, director)
    if director.subject == 0 then M.free(director); return end
  end

  -- A stakeout goes to where the subject is and then *stops*, holding that spot
  -- and watching whatever wanders through. Following is not always the better
  -- shot: a camera welded to a body in a corridor shows a wall going past, and a
  -- camera parked at a junction shows the maze working.
  if director.mode == M.STAKEOUT and director.dwell > 1.2 then
    return
  end

  if not still_there(world, director) then return end

  local bodies = world.bodies
  local id = director.subject
  local x, y, z

  local kind = world.creatures.KINDS[bodies.kind[id]]
  if kind.locomotion == world.creatures.WALKING then
    x, y, z = Walking.drawn_position(world.store, bodies, id)
  else
    x, y, z = bodies.x[id], bodies.y[id], bodies.z[id]
  end

  -- The camera module is handed in rather than reached for through the world.
  -- The world is the simulation's, and the simulation does not know a camera
  -- exists -- which is the arrangement that lets the whole thing run headless.
  Camera.ease_toward(Projection, camera, x, y, z, screen_w, screen_h,
                     director.settings.ease)
end
-- }}}

-- {{{ function M.draw_marker(Projection, Palette, flat, world, director, Walking, love_graphics)
-- A thin ring on the stone beneath the subject.
--
-- Without one, a camera locked to one of forty identical little guys looks
-- exactly like a camera that is not locked to anything.
function M.draw_marker(Projection, Palette, flat, world, director, Walking,
                       love_graphics)
  if director.subject == 0 or not still_there(world, director) then return end

  local bodies = world.bodies
  local id = director.subject
  local x, y = bodies.x[id], bodies.y[id]
  local kind = world.creatures.KINDS[bodies.kind[id]]
  if kind.locomotion == world.creatures.WALKING then
    x, y = Walking.drawn_position(world.store, bodies, id)
  end

  local floor_z = bodies.layer[id] + 1
  local sx, sy = Projection.to_screen(flat, x, y, floor_z)
  local hw, hh = Projection.HALF_WIDTH, Projection.HALF_HEIGHT

  love_graphics.setColor(0.95, 0.85, 0.35, 0.9)
  love_graphics.setLineWidth(1.6)
  love_graphics.ellipse("line", sx, sy, hw * 0.72, hh * 0.72)
  love_graphics.setLineWidth(1)
end
-- }}}

-- {{{ function M.describe(world, director)
-- What the panel says about the subject, as lines.
function M.describe(world, director)
  local lines = { "watching: " .. M.MODE_NAMES[director.mode] }

  if director.subject == 0 then
    lines[#lines + 1] = "  nobody"
    return lines
  end
  if not still_there(world, director) then
    lines[#lines + 1] = "  a body that is no longer there"
    return lines
  end

  local bodies = world.bodies
  local id = director.subject
  local kind = world.creatures.KINDS[bodies.kind[id]]
  local Walking = world.modules.Walking

  local doing = "standing about"
  if bodies.intent[id] == Walking.INTENT_ERRAND then doing = "going somewhere"
  elseif bodies.partner[id] ~= 0 then doing = "in company"
  elseif bodies.vz[id] ~= 0 then doing = "falling"
  elseif bodies.intent[id] == Walking.INTENT_WANDER then doing = "wandering" end

  lines[#lines + 1] = string.format("  body %d, a %s, on layer %d -- %s",
                                    id, kind.name, bodies.layer[id], doing)
  lines[#lines + 1] = string.format("  %s",
    director.verdict and ("done: " .. director.verdict ..
      (director.settings.auto_swap and "" or "   (press tab)"))
    or string.format("still worth watching   %.0fs", director.dwell))
  return lines
end
-- }}}

return M
