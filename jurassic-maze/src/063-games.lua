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

-- 063-games.lua
--
-- Roles, a rule for swapping between them, and an ending. Nothing knows it is
-- playing.
--
-- A game is not intelligence and it is not planning. It is a state machine
-- shared by two or more bodies, and the fact that it reads as play is a property
-- of the watcher rather than of the creatures.

local M = {}

local Stone, Moving, Sight, Walking, BodyStore, Creatures

-- {{{ function M.link(stone, moving, sight, walking, body_store, creatures)
function M.link(stone, moving, sight, walking, body_store, creatures)
  Stone, Moving, Sight, Walking, BodyStore, Creatures =
    stone, moving, sight, walking, body_store, creatures
end
-- }}}

M.CHASE  = 1
M.HIDE   = 2
M.FOLLOW = 3

M.NAMES = { "chase", "hide and seek", "follow the leader" }

-- The most bodies one game may hold. A chase is two; hide and seek and follow
-- the leader are as many as happen to be standing together when one starts.
M.MAX_PLAYERS = 6

-- {{{ function M.new_store(capacity)
-- The third store of this shape -- flat arrays, a free list, participants held
-- by id and generation, a clock.
--
-- Generalising it with the duel store was considered and not done. A duel is
-- always two bodies and has an outcome; a game is up to six and has roles that
-- swap. Merging them means a store whose entries are two different things with a
-- discriminator, which is the shape that gets one of the two wrong later. Three
-- instances is enough to see the pattern and not enough to be sure of where the
-- seam is.
function M.new_store(capacity)
  local store = { capacity = capacity, live = 0, free_top = 0, free = {} }
  for _, field in ipairs({ "alive", "kind", "clock", "state", "count" }) do
    local array = {}
    for i = 1, capacity do array[i] = 0 end
    store[field] = array
  end
  -- Participants and their generations, as one flat array of MAX_PLAYERS per
  -- game rather than a list per game.
  store.player     = {}
  store.generation = {}
  for i = 1, capacity * M.MAX_PLAYERS do
    store.player[i], store.generation[i] = 0, 0
  end
  for i = capacity, 1, -1 do
    store.free_top = store.free_top + 1
    store.free[store.free_top] = i
  end
  return store
end
-- }}}

-- {{{ local function slot(g, n)
local function slot(g, n) return (g - 1) * M.MAX_PLAYERS + n end
-- }}}

-- {{{ function M.begin(world, kind, players)
function M.begin(world, kind, players)
  local games  = world.games
  local bodies = world.bodies
  if games.free_top == 0 or #players < 2 then return nil end

  local g = games.free[games.free_top]
  games.free_top = games.free_top - 1
  games.live = games.live + 1

  games.alive[g] = 1
  games.kind[g]  = kind
  games.clock[g] = 0
  games.state[g] = 0
  games.count[g] = math.min(#players, M.MAX_PLAYERS)

  for n = 1, games.count[g] do
    local id = players[n]
    games.player[slot(g, n)]     = id
    games.generation[slot(g, n)] = bodies.generation[id]
    bodies.game[id]  = g
    bodies.role[id]  = (n == 1) and 1 or 2   -- the first is it, or the seeker,
    bodies.grace[id] = 0                     -- or the leader
    bodies.intent[id] = 0
  end

  world.counters["games_" .. M.NAMES[kind]:gsub("%s", "_")] =
    (world.counters["games_" .. M.NAMES[kind]:gsub("%s", "_")] or 0) + 1
  return g
end
-- }}}

-- {{{ function M.finish(world, g)
function M.finish(world, g)
  local games  = world.games
  local bodies = world.bodies
  if games.alive[g] == 0 then return end

  for n = 1, games.count[g] do
    local id = games.player[slot(g, n)]
    if id ~= 0 and bodies.alive[id] == 1 and bodies.game[id] == g then
      bodies.game[id]   = 0
      bodies.role[id]   = 0
      bodies.intent[id] = 0
    end
    games.player[slot(g, n)] = 0
  end

  games.alive[g] = 0
  games.live = games.live - 1
  games.free_top = games.free_top + 1
  games.free[games.free_top] = g
  world.counters.games_ended = (world.counters.games_ended or 0) + 1
end
-- }}}

-- {{{ local function other_player(world, g, id)
-- In a chase, the one that is not this one.
local function other_player(world, g, id)
  local games = world.games
  for n = 1, games.count[g] do
    local p = games.player[slot(g, n)]
    if p ~= id and p ~= 0 then return p end
  end
  return 0
end
-- }}}

-- {{{ function M.decide(world, bodies, id, kind)
-- What a body in a game does when it has nothing else to do.
--
-- Called from the walking row instead of that body's own wandering. The game
-- steers it; it is released back to itself when the game ends.
function M.decide(world, bodies, id, kind)
  local g = bodies.game[id]
  local games = world.games
  if games.alive[g] == 0 then bodies.game[id] = 0; return end

  local which = games.kind[g]

  if which == M.CHASE then
    local other = other_player(world, g, id)
    if other == 0 or bodies.alive[other] == 0 then return end

    if bodies.role[id] == 1 then
      -- It. Head straight for the other one, wherever it is now.
      --
      -- If there is no route -- which for a wide body chasing something into a
      -- corridor is most of the time -- stand still for a moment rather than
      -- asking again next tick. The answer will not have changed in a sixtieth
      -- of a second, and asking costs a search.
      if not Walking.send_to(world, bodies, id, kind,
                             bodies.cell[other], bodies.layer[other], "chase") then
        bodies.intent[id]     = Walking.INTENT_IDLE
        bodies.idle_row[id]   = 2
        bodies.timer[id]      = 0.5
        bodies.idle_total[id] = 0.5
      end
    else
      -- Not it. Somewhere the other cannot see, if there is such a place; away
      -- from it otherwise.
      --
      -- The difference between those two is the difference between hiding and
      -- fleeing, and it is one line: a successful hider *stops*. Fleeing looks
      -- like panic; stopping behind a wall looks like intent.
      -- Cover is looked for on the sight cadence, not every tick.
      --
      -- Without the cadence a body that cannot find cover asks again next tick,
      -- and next tick, at three hundred surfaces and a sight march apiece --
      -- seventy thousand failed searches a minute, and the move pass costing
      -- nine tenths of the whole simulation. The body is in the open; the answer
      -- is not going to be different in a sixtieth of a second.
      if Sight.due(world, bodies, id, kind) then
        local cell, layer = Sight.find_cover(world, id, other, 260)
        if cell then
          Walking.send_to(world, bodies, id, kind, cell, layer, "cover")
        else
          -- Nowhere hidden within the budget: run, and let the running take it
          -- somewhere the answer is different.
          --
          -- This is the difference between hiding and fleeing, and it is worth
          -- keeping both: fleeing looks like panic, and stopping behind a wall
          -- looks like intent. A creature does the second when it can.
          M.flee(world, bodies, id, kind, other)
        end
      end
    end

  elseif which == M.HIDE then
    if bodies.role[id] == 1 then
      -- The seeker. Counts first, then goes looking.
      if games.clock[g] < kind.count_seconds then
        bodies.intent[id]   = Walking.INTENT_IDLE
        bodies.idle_row[id] = 2                -- looking around
        bodies.timer[id]    = 0.6
        bodies.idle_total[id] = 0.6
      end
    else
      -- A hider. Cover, once, and then stay there.
      if bodies.role[id] == 2 then
        local seeker = games.player[slot(g, 1)]
        if seeker ~= 0 and bodies.alive[seeker] == 1
           and Sight.due(world, bodies, id, kind) then
          local cell, layer = Sight.find_cover(world, id, seeker, 260)
          if cell then
            Walking.send_to(world, bodies, id, kind, cell, layer, "hide")
            bodies.role[id] = 3                -- hidden; stops asking
          else
            M.flee(world, bodies, id, kind, seeker)
          end
        end
      end
    end

  elseif which == M.FOLLOW then
    if bodies.role[id] == 1 then return end    -- the leader wanders on its own
    local leader = games.player[slot(g, 1)]
    if leader == 0 or bodies.alive[leader] == 0 then return end

    -- Where the leader was a moment ago, from a small ring of its recent
    -- stances. Pathfinding to a *moving* target means recomputing every time it
    -- moves, which is every step, which is the pathfinder running constantly for
    -- a result that is thrown away.
    -- Asked on the sight cadence rather than every tick. A follower that has
    -- arrived at the trail cell would otherwise re-plan on every one of them.
    if not Sight.due(world, bodies, id, kind) then return end

    local trail = world.trail[leader]
    if trail and trail.n > 0 then
      local at = ((trail.at + 1) % trail.n) + 1
      local cell = trail[at]
      if cell then
        Walking.send_to(world, bodies, id, kind, cell, world.store.height[cell],
                        "follow")
      end
    end
  end
end
-- }}}

-- {{{ function M.flee(world, bodies, id, kind, from_id)
-- Away from something, when there is nowhere to hide from it.
--
-- Picks a floor block on the far side and heads for it. Counted, because a
-- creature that is always fleeing and never hiding is a maze with no cover in
-- it, which is a fact about the generator rather than about the creature.
function M.flee(world, bodies, id, kind, from_id)
  local store = world.store
  local width = store.width

  local ax = bodies.cell[id] % width
  local ay = math.floor(bodies.cell[id] / width)
  local bx = bodies.cell[from_id] % width
  local by = math.floor(bodies.cell[from_id] / width)

  local dx, dy = ax - bx, ay - by
  local len = math.sqrt(dx * dx + dy * dy)
  if len < 0.001 then dx, dy, len = 1, 0, 1 end

  -- A wide body flees within its own enclosure, and to the cell in it that is
  -- furthest from the threat. Drawing from the floor at large hands it somewhere
  -- it cannot stand, and the search that fails leaves it with nothing decided --
  -- which is the same failure as the errand, arrived at from a different
  -- direction, and it cost fifty-five thousand searches a minute before it was
  -- found here too.
  local target
  if kind.radius >= 1 then
    local piece = world.wide_pieces[world.wide_label[bodies.cell[id]] or 0]
    if not piece or #piece < 2 then return false end
    -- The furthest of a sample rather than of all of them: an enclosure can hold
    -- a few hundred cells and this runs on the sight cadence for every fleeing
    -- body.
    local best = -1
    for _ = 1, 12 do
      local c = piece[world.streams.wander_dino:next_below(#piece)]
      local cx = c % width
      local cy = math.floor(c / width)
      local away = (cx - bx) * (cx - bx) + (cy - by) * (cy - by)
      if away > best then best, target = away, c end
    end
  else
    local blocks = math.max(2, math.floor(kind.give_up_distance / world.block_size))
    local tx = math.floor(ax / world.block_size + (dx / len) * blocks)
    local ty = math.floor(ay / world.block_size + (dy / len) * blocks)
    if tx < 0 then tx = 0 elseif tx >= world.blocks_x then tx = world.blocks_x - 1 end
    if ty < 0 then ty = 0 elseif ty >= world.blocks_y then ty = world.blocks_y - 1 end

    local block = world.floor_blocks[tx + ty * world.blocks_x]
    if not block or #block == 0 then return false end
    target = block[world.streams.wander_dino:next_below(#block)]
  end

  if not target then return false end
  world.counters.fled = (world.counters.fled or 0) + 1
  return Walking.send_to(world, bodies, id, kind, target, store.height[target],
                         "flee")
end
-- }}}

-- {{{ function M.pass(world, dt)
-- Every live game, one tick: the clock, the role swaps, and the endings.
function M.pass(world, dt)
  local games  = world.games
  local bodies = world.bodies

  -- The leader's trail, for follow the leader. A small ring per body, written
  -- only for bodies that are leading something.
  for g = 1, games.capacity do
    if games.alive[g] == 1 and games.kind[g] == M.FOLLOW then
      local leader = games.player[slot(g, 1)]
      if leader ~= 0 and bodies.alive[leader] == 1 then
        local trail = world.trail[leader]
        if not trail then trail = { n = 0, at = 0 }; world.trail[leader] = trail end
        if trail[trail.at + 1] ~= bodies.cell[leader] then
          trail.at = (trail.at % 8) + 1
          trail[trail.at] = bodies.cell[leader]
          if trail.n < 8 then trail.n = trail.n + 1 end
        end
      end
    end
  end

  for g = 1, games.capacity do
    if games.alive[g] == 1 then
      games.clock[g] = games.clock[g] + dt
      local kind_row = Creatures.KINDS[bodies.kind[games.player[slot(g, 1)]] ~= 0
                                       and bodies.kind[games.player[slot(g, 1)]] or 1]

      -- Anybody gone dissolves the game. The generation is what makes this a
      -- real check rather than a plausible one.
      local intact = true
      for n = 1, games.count[g] do
        local id = games.player[slot(g, n)]
        if not BodyStore.is_valid(bodies, id, games.generation[slot(g, n)]) then
          intact = false
        end
      end

      if not intact or games.clock[g] > kind_row.game_seconds then
        M.finish(world, g)
      elseif games.kind[g] == M.CHASE then
        local a = games.player[slot(g, 1)]
        local b = games.player[slot(g, 2)]

        for _, id in ipairs({ a, b }) do
          if bodies.grace[id] > 0 then bodies.grace[id] = bodies.grace[id] - dt end
        end

        -- Tagged: adjacent, and neither in the grace that follows a swap. The
        -- grace is what stops the roles swapping back and forth every tick while
        -- the two of them are standing next to each other.
        local dx = math.abs((bodies.cell[a] % world.store.width)
                            - (bodies.cell[b] % world.store.width))
        local dy = math.abs(math.floor(bodies.cell[a] / world.store.width)
                            - math.floor(bodies.cell[b] / world.store.width))
        if dx <= 1 and dy <= 1 and bodies.grace[a] <= 0 and bodies.grace[b] <= 0 then
          bodies.role[a], bodies.role[b] = bodies.role[b], bodies.role[a]
          bodies.grace[a] = kind_row.grace_seconds
          bodies.grace[b] = kind_row.grace_seconds
          bodies.intent[a], bodies.intent[b] = 0, 0
          world.counters.tags = (world.counters.tags or 0) + 1
        end

        -- Too far apart to be a chase any more.
        if math.sqrt(dx * dx + dy * dy) > kind_row.give_up_distance then
          M.finish(world, g)
        end

      elseif games.kind[g] == M.HIDE then
        local seeker = games.player[slot(g, 1)]
        if games.clock[g] >= kind_row.count_seconds then
          local left = 0
          for n = 2, games.count[g] do
            local id = games.player[slot(g, n)]
            if id ~= 0 and bodies.alive[id] == 1 and bodies.role[id] ~= 4 then
              left = left + 1
              if Sight.due(world, bodies, id, kind_row)
                 and Sight.sees_body(world, seeker, id) then
                bodies.role[id] = 4            -- found; joins the seeking
                world.counters.found = (world.counters.found or 0) + 1
                left = left - 1
              end
            end
          end
          if left == 0 then M.finish(world, g) end
        end
      end
    end
  end
end
-- }}}

-- {{{ function M.maybe_start(world, bodies, a, b)
-- Two creatures of a playing kind have met. Sometimes that is a game.
--
-- Called from the meet table. Whether it happens at all is a draw, because a
-- crowd where every meeting starts a game is a crowd where nothing else ever
-- happens.
function M.maybe_start(world, bodies, a, b)
  if bodies.game[a] ~= 0 or bodies.game[b] ~= 0 then return false end
  if bodies.duel[a] ~= 0 or bodies.duel[b] ~= 0 then return false end

  local kind = Creatures.KINDS[bodies.kind[a]]
  if not kind.game_chance then return false end

  local rng = world.streams.meeting
  if not rng:chance(kind.game_chance) then return false end

  -- Which game. A table of weights rather than a chain, so adding one is a row.
  local roll = rng:next_below(3)
  local players = { a, b }

  if roll == 3 then
    -- Follow the leader and hide and seek want more than two if more than two
    -- are standing about. Whoever else is in the same cell's neighbourhood.
    BodyStore.for_each_near(bodies, world.store.width,
                            bodies.cell[a] % world.store.width,
                            math.floor(bodies.cell[a] / world.store.width),
                            function(other)
      if #players < M.MAX_PLAYERS and other ~= a and other ~= b
         and bodies.alive[other] == 1 and bodies.game[other] == 0
         and bodies.kind[other] == bodies.kind[a] then
        players[#players + 1] = other
      end
    end)
  end

  return M.begin(world, roll, players) ~= nil
end
-- }}}

-- {{{ function M.describe(world, g)
function M.describe(world, g)
  local games = world.games
  if games.alive[g] == 0 then return "no game" end
  return string.format("%s, %d players, %.0fs",
                       M.NAMES[games.kind[g]], games.count[g], games.clock[g])
end
-- }}}

return M
