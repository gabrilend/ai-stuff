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

-- 073-bouncing.lua
--
-- A ball as a sphere, against the model's faces and against other spheres.
--
-- The row this replaces samples an interpolated height field: the floor under a
-- ball is the four surrounding cell heights blended together, and the slope is
-- the derivative of that blend. It is fast and it works, and it has one property
-- that is fatal on a mountain -- it smooths staircases into ramps **on purpose**,
-- because a staircase was a rare thing cut into a maze of walls and a ball
-- bouncing down every flight was chaotic. On a mountainside whose only way down
-- is stairs, that means the balls never bounce at all. They slide.
--
-- So there is no height field here and no slope term. There is a sphere, there
-- is gravity straight down, and there are the flat rectangles from
-- 071-the-model.lua. A ball on a sloping arrangement of stone accelerates because
-- the stone pushes it sideways, which is what a normal is for -- not because
-- anything computed a gradient. A tread is a horizontal face and a riser is a
-- vertical one, and a ball meeting either is the same three lines of code.

local M = {}

local Locomotion, Creatures, Model, BodyStore, Stone

-- Cached out of the model module at link time, because they are compared once
-- per face per ball per round and a table lookup there is not free.
local M_TOP, M_RIM

-- {{{ function M.link(deps)
-- The modules, handed in once at world creation.
--
-- Handed in rather than loaded here, and the reason is a bug rather than a
-- preference: the world already holds these, and requiring them again produces a
-- second copy of every table -- including the creature table, which would then be
-- tuned in one copy and read from the other. That is exactly what made a
-- parameter sweep report identical numbers for twelve different settings.
function M.link(deps)
  Locomotion = deps.Locomotion
  Creatures  = deps.Creatures
  Model      = deps.Model
  BodyStore  = deps.BodyStore
  Stone      = deps.Stone
  M_TOP      = Model.TOP
  M_RIM      = Model.RIM
end
-- }}}

-- How far a sphere may sit inside a face before the resolver stops trusting
-- which side it is on.
--
-- Not a slack allowance. A contact is resolved only when the sphere's centre is
-- on the outward side of the face's plane, and that single test is what makes a
-- one-sided surface out of a rectangle: a ball standing on the high shelf beside
-- a cliff is on the *solid* side of that cliff's riser, so the riser ignores it,
-- which is the correct answer and needs no special case for edges. The epsilon
-- exists because a ball resting exactly on a face sits precisely on the boundary
-- of that test, and floating point will put it on either side from tick to tick.
local SIDE_EPSILON = 1e-9

-- {{{ local function resolve_face(m, f, bodies, id, r, restitution)
-- One sphere against one rectangle. Returns the z of the contact normal, so the
-- caller can tell a floor from a wall without asking twice.
--
-- The closest point on an axis-aligned rectangle to a point is three independent
-- clamps, one per axis, and it is *exact* rather than an approximation -- which
-- is the whole reason the model stores rectangles rather than triangles. The
-- contact normal is then the direction from that point to the sphere's centre,
-- and not the face's own normal: at the top edge of a riser the nearest stone is
-- an edge rather than a plane, and pushing out along the plane's normal there
-- shoves the ball sideways along a surface it is resting on top of.
local function resolve_face(m, f, bodies, id, r, restitution)
  -- The body's stored z is where its **feet** are, not where its middle is.
  -- Everything else in the project uses it that way -- the renderer draws from
  -- it, the spawner puts a body down at the surface, `settle_stance` reads it to
  -- work out which stone the body is on -- so the sphere's centre is a radius
  -- above it and the conversion happens here rather than in the store.
  --
  -- Getting this wrong is not subtle in its consequences and is completely
  -- invisible in its symptom: a sphere centred on its feet is half buried, its
  -- centre sits exactly on the plane of the floor, the floor decides the centre
  -- is not on its outward side, and the ball falls through the mountain. Which
  -- looks like a ball that simply vanished.
  local px, py = bodies.x[id], bodies.y[id]
  local pz = bodies.z[id] + r

  -- Which side of the face's plane the centre is on. Negative is inside the
  -- stone, and a face never pushes from behind.
  local side = (px - m.x0[f]) * m.nx[f]
             + (py - m.y0[f]) * m.ny[f]
             + (pz - m.z0[f]) * m.nz[f]

  if m.kind[f] == M_RIM then
    -- The rim is the exception, and it has to be. It is not stone; it is the
    -- edge of the world, and there is no legitimate far side of it -- so it
    -- pushes whether the centre is in front of it or behind, which is what the
    -- one-sided test above would refuse to do.
    --
    -- This is not caution. In a heap, a sphere gets shoved by its neighbours, and
    -- a shove that lands it exactly on the rim's plane makes `side` zero, at
    -- which point a one-sided rim stops holding it and the next shove puts it
    -- outside the array. The locomotion row raises when that happens, which is
    -- the right way to find out and the wrong way to spend an afternoon.
    if side >= r then return nil end
    -- Only where the face actually is. The rim spans one cell of the boundary
    -- and the whole height of the world, so this is two range checks.
    if m.nx[f] ~= 0 then
      if py < m.y0[f] - r or py > m.y1[f] + r then return nil end
    else
      if px < m.x0[f] - r or px > m.x1[f] + r then return nil end
    end
    if pz < m.z0[f] - r or pz > m.z1[f] then return nil end

    local push = r - side
    bodies.x[id] = px + m.nx[f] * push
    bodies.y[id] = py + m.ny[f] * push
    bodies.z[id] = pz + m.nz[f] * push - r

    local into = bodies.vx[id] * m.nx[f] + bodies.vy[id] * m.ny[f]
               + bodies.vz[id] * m.nz[f]
    if into < 0 then
      local j = -(1 + restitution) * into
      bodies.vx[id] = bodies.vx[id] + m.nx[f] * j
      bodies.vy[id] = bodies.vy[id] + m.ny[f] * j
      bodies.vz[id] = bodies.vz[id] + m.nz[f] * j
    end
    return m.nz[f], push
  end

  -- A top face is the lid of a solid, and a sphere whose centre is under it and
  -- horizontally inside it is inside the mountain. Not "approaching from behind"
  -- -- there is nothing behind the top of a height field -- so this one pushes up
  -- regardless of which side the centre is on.
  --
  -- Without it a sphere that gets under a floor by any amount at all is gone
  -- forever: the one-sided test refuses to look at a face from below, so the ball
  -- keeps falling, and it falls past every other floor for the same reason. A
  -- heap is what produces it -- a neighbour resolving an overlap can shove a ball
  -- down by most of a radius in one step, far more than the speed cap ever allows
  -- it to travel -- and the symptom is a ball at minus a hundred and twenty-five,
  -- still being simulated, with the rim check happily reporting it is inside the
  -- map because it only ever looked at x and y.
  --
  -- Horizontally *inside* the rectangle, not merely within a radius of it. A
  -- sphere beside a tall block is under that block's top face and belongs against
  -- its riser, and lifting it would put it on the roof.
  if m.kind[f] == M_TOP
     and px >= m.x0[f] and px <= m.x1[f]
     and py >= m.y0[f] and py <= m.y1[f] then
    local want = m.z0[f] + r
    if pz >= want then return nil end
    bodies.z[id] = m.z0[f]
    if bodies.vz[id] < 0 then
      bodies.vz[id] = -bodies.vz[id] * restitution
    end
    return 1, want - pz
  end

  if side < SIDE_EPSILON then return nil end

  local qx = px; if qx < m.x0[f] then qx = m.x0[f] elseif qx > m.x1[f] then qx = m.x1[f] end
  local qy = py; if qy < m.y0[f] then qy = m.y0[f] elseif qy > m.y1[f] then qy = m.y1[f] end
  local qz = pz; if qz < m.z0[f] then qz = m.z0[f] elseif qz > m.z1[f] then qz = m.z1[f] end

  local dx, dy, dz = px - qx, py - qy, pz - qz
  local d2 = dx * dx + dy * dy + dz * dz
  if d2 >= r * r then return nil end

  local d = math.sqrt(d2)
  if d < 1e-12 then
    -- The centre is exactly on the rectangle. There is no direction from the
    -- closest point to the centre, so the face's own normal is the only thing
    -- left that knows which way out is.
    dx, dy, dz, d = m.nx[f], m.ny[f], m.nz[f], 1
  end

  local inv = 1 / d
  local nx, ny, nz = dx * inv, dy * inv, dz * inv

  -- Out to exactly one radius. Pushed out, not moved back along the path it
  -- came in on: resolving an overlap is about ending up somewhere legal, and the
  -- cheapest legal place is straight out.
  local push = r - d
  bodies.x[id] = px + nx * push
  bodies.y[id] = py + ny * push
  bodies.z[id] = pz + nz * push - r

  -- Reflect only the part of the velocity heading into the surface. The part
  -- along it is untouched, so a ball arriving at a shallow angle runs along the
  -- face instead of stopping dead against it.
  local into = bodies.vx[id] * nx + bodies.vy[id] * ny + bodies.vz[id] * nz
  if into < 0 then
    local j = -(1 + restitution) * into
    bodies.vx[id] = bodies.vx[id] + nx * j
    bodies.vy[id] = bodies.vy[id] + ny * j
    bodies.vz[id] = bodies.vz[id] + nz * j
  end

  return nz, push
end
-- }}}

-- {{{ local function resolve_world(model, bodies, id, r, restitution)
-- Every face near the ball, one at a time, resolving as it goes.
--
-- One at a time and immediately, rather than gathering every overlap and
-- applying them together. Collecting first sounds more correct and is not: two
-- faces meeting in a corner each want the sphere pushed out along their own
-- normal, and applied together they push it twice as far as either asked for --
-- straight through whatever is on the other side.
--
-- Returns the most upward-facing contact normal seen, which is how the caller
-- knows whether the ball is standing on something.
local function resolve_world(model, bodies, id, r, restitution)
  local best_up = -1
  local touched = false

  -- The cells the sphere overlaps. A radius under half a cell means at most four
  -- cells, and asking for the nine around it costs nothing and cannot miss one.
  local cx = math.floor(bodies.x[id])
  local cy = math.floor(bodies.y[id])

  for dy = -1, 1 do
    for dx = -1, 1 do
      local x, y = cx + dx, cy + dy
      if x >= 0 and y >= 0 and x < model.width and y < model.depth then
        local list = model.at[x + y * model.width]
        if list then
          for k = 1, #list do
            local up, push = resolve_face(model, list[k], bodies, id, r, restitution)
            if up then
              -- "Touched" means moved, not merely in contact. A ball at rest is
              -- in contact with the floor on every round forever, so a contact
              -- test never converges and the loop always runs its full ceiling.
              -- Asking whether the sphere actually went anywhere lets a settled
              -- one leave after a single round, which is nearly all of them.
              if push > 1e-9 then touched = true end
              if up > best_up then best_up = up end
            end
          end
        end
      end
    end
  end

  return best_up, touched
end
-- }}}

-- How many times to go round the faces before giving up on converging.
--
-- Faces are resolved one at a time, so pushing a sphere out of one can nudge it
-- into another -- in a corner, out of the floor and into the wall, then out of
-- the wall and very slightly back into the floor. Each round shrinks the residual
-- by an order of magnitude and a handful of rounds takes it below anything that
-- can be measured.
--
-- A fixed ceiling rather than a loop until nothing moves, because "nothing moves"
-- is a floating-point comparison that can fail to be reached, and a physics pass
-- that occasionally spins forever is worse than one that occasionally leaves a
-- millionth of a layer of overlap.
local WORLD_ROUNDS = 4

-- {{{ local function settle_against_world(model, bodies, id, r, restitution)
local function settle_against_world(model, bodies, id, r, restitution)
  local best_up = -1
  for _ = 1, WORLD_ROUNDS do
    local up, touched = resolve_world(model, bodies, id, r, restitution)
    if up > best_up then best_up = up end
    if not touched then break end
  end
  return best_up
end
-- }}}

-- {{{ local function resolve_pair(bodies, a, b, ra, rb, restitution)
-- Two spheres that are inside each other.
--
-- Mass is radius cubed. Every ball is the same size today, so this changes
-- nothing and costs two multiplies -- and writing it as a volume now is what
-- stops a dinosaur being knocked across the mountain by a pebble the first time
-- something else uses this row.
local function resolve_pair(bodies, a, b, ra, rb, restitution)
  -- Centre to centre, and each centre is a radius above its own stored feet, so
  -- two spheres of different size are compared correctly rather than by the
  -- points they happen to be standing on.
  local dx = bodies.x[b] - bodies.x[a]
  local dy = bodies.y[b] - bodies.y[a]
  local dz = (bodies.z[b] + rb) - (bodies.z[a] + ra)
  local d2 = dx * dx + dy * dy + dz * dz
  local reach = ra + rb
  if d2 >= reach * reach then return false end

  local d, nx, ny, nz
  if d2 < 1e-12 then
    -- Exactly on top of each other, which the aquarium produces whenever it
    -- drops two balls on the same cell in the same tick. There is no line of
    -- centres to separate along, and returning without doing anything leaves the
    -- pair welded together for the rest of their lives -- two balls occupying one
    -- ball's space, travelling as one, and never noticed because they look like
    -- one ball.
    --
    -- So the direction is chosen rather than computed. Any fixed axis will do,
    -- since the only requirement is that the two go opposite ways, and choosing
    -- rather than randomising keeps the run reproducible.
    d, nx, ny, nz = 0, 1, 0, 0
  else
    d = math.sqrt(d2)
    local inv = 1 / d
    nx, ny, nz = dx * inv, dy * inv, dz * inv
  end

  local ma, mb = ra * ra * ra, rb * rb * rb
  local total = ma + mb

  -- Separate in proportion to the other's mass, so the heavier of the two moves
  -- less. Equal masses share it evenly, which is the case that runs today.
  local overlap = reach - d
  local share_a = overlap * (mb / total)
  local share_b = overlap * (ma / total)
  bodies.x[a] = bodies.x[a] - nx * share_a
  bodies.y[a] = bodies.y[a] - ny * share_a
  bodies.z[a] = bodies.z[a] - nz * share_a
  bodies.x[b] = bodies.x[b] + nx * share_b
  bodies.y[b] = bodies.y[b] + ny * share_b
  bodies.z[b] = bodies.z[b] + nz * share_b

  -- Closing speed along the line of centres. Two spheres that overlap while
  -- moving apart are already leaving; hitting them with an impulse would pull
  -- them back together, and a pair caught in that trades energy forever.
  local closing = (bodies.vx[b] - bodies.vx[a]) * nx
                + (bodies.vy[b] - bodies.vy[a]) * ny
                + (bodies.vz[b] - bodies.vz[a]) * nz
  if closing < 0 then
    local j = -(1 + restitution) * closing / (1 / ma + 1 / mb)
    bodies.vx[a] = bodies.vx[a] - nx * j / ma
    bodies.vy[a] = bodies.vy[a] - ny * j / ma
    bodies.vz[a] = bodies.vz[a] - nz * j / ma
    bodies.vx[b] = bodies.vx[b] + nx * j / mb
    bodies.vy[b] = bodies.vy[b] + ny * j / mb
    bodies.vz[b] = bodies.vz[b] + nz * j / mb
  end

  return true
end
-- }}}

-- {{{ local function resolve_neighbours(store, bodies, id, r, restitution)
-- The ball against everybody near it.
--
-- Every pair comes up twice, once from each end, because the pass walks all the
-- balls and asks about each one's neighbourhood. Resolving it both times applies
-- the impulse twice and separates the pair twice as far as either sphere asked
-- for. Taking the pair only when the neighbour's id is the higher of the two is
-- one comparison and needs no memory of what has already been seen.
local function resolve_neighbours(bodies, width, id, r, restitution)
  local kinds = Creatures.KINDS
  local cx = math.floor(bodies.x[id])
  local cy = math.floor(bodies.y[id])
  local hit = false
  local row  = bodies.locomotion[id]
  local mine = bodies.roster_slot[id]

  -- The buckets belong to the body store and are indexed by the *world's* width,
  -- which is why that has to be handed in: the two stores are different objects
  -- with a field of the same name, and the stone store's width is the one that
  -- means cells across the map.
  BodyStore.for_each_near(bodies, width, cx, cy, function(other)
    -- Take the pair from the body that comes *earlier in the roster*, not from
    -- the one with the lower id.
    --
    -- Either rule visits every pair exactly once, and only one of them is
    -- correct. Resolving a pair moves both spheres, and the partner needs its
    -- final settle against the stone afterwards or it is left wherever the shove
    -- put it -- possibly inside a step. The roster is maintained by swap-remove,
    -- so it is in no particular order and the partner with the higher id is very
    -- often the one that was processed twenty slots ago. The slot is what says
    -- who has already had their turn.
    if bodies.alive[other] == 1
       and bodies.locomotion[other] == row
       and bodies.roster_slot[other] > mine then
      local ro = kinds[bodies.kind[other]].radius
      if resolve_pair(bodies, id, other, r, ro, restitution) then
        hit = true
        -- A ball that has been struck is not resting, whatever its timer said.
        -- Without this a heap at the foot of a flight evaporates on a schedule
        -- while visibly being jostled.
        bodies.rest_timer[other] = 0
      end
    end
  end)

  return hit
end
-- }}}

-- {{{ function M.advance(world, bodies, roster, first, last, dt)
-- Moves a slice of the bouncing roster.
function M.advance(world, bodies, roster, first, last, dt)
  local store = world.store
  local model = world.model
  local kinds = Creatures.KINDS

  for slot = first, last do
    local id = roster[slot]
    if bodies.alive[id] == 1 then
      local kind = kinds[bodies.kind[id]]
      local r = kind.radius

      -- Gravity, straight down and with no slope term in sight. Everything that
      -- makes a ball run downhill comes out of the faces pushing on it.
      bodies.vz[id] = bodies.vz[id] - kind.gravity * dt

      -- The speed cap, and it is load-bearing rather than tidy. One tick at the
      -- cap has to move the ball less than its own radius: a body that travels
      -- further than its own width between ticks can pass clean through a face
      -- without ever being within a radius of it, and no amount of correct
      -- collision code catches that. It is also why the timestep is fixed rather
      -- than whatever the frame happened to take.
      local vx, vy, vz = bodies.vx[id], bodies.vy[id], bodies.vz[id]
      local speed = math.sqrt(vx * vx + vy * vy + vz * vz)
      local cap = kind.max_speed
      if speed > cap then
        local scale = cap / speed
        bodies.vx[id] = vx * scale
        bodies.vy[id] = vy * scale
        bodies.vz[id] = vz * scale
        speed = cap
      end

      local was_x, was_y = bodies.x[id], bodies.y[id]

      bodies.x[id] = bodies.x[id] + bodies.vx[id] * dt
      bodies.y[id] = bodies.y[id] + bodies.vy[id] * dt
      bodies.z[id] = bodies.z[id] + bodies.vz[id] * dt

      -- The world first, then the neighbours. A ball pushed out of a neighbour
      -- and then out of a wall ends up somewhere legal; the other order can leave
      -- it shoved back into the wall it was just rescued from.
      local up = settle_against_world(model, bodies, id, r, kind.restitution)
      resolve_neighbours(bodies, store.width, id, r, kind.restitution)

      -- The world again, and this is not belt and braces.
      --
      -- The two resolutions disagree, and one of them has to win. A sphere
      -- shoved by a neighbour can end up back inside the stone it was just
      -- pushed out of, and a sphere inside the stone is a catastrophe -- the
      -- ground beneath it is the top of the block it is inside, so it is standing
      -- on nothing, so it falls forever and what shows on screen is a ball that
      -- vanished. A sphere overlapping another sphere by a fraction of a radius,
      -- meanwhile, is a pile of balls looking slightly tight.
      --
      -- So the stone goes last, and the stone wins. The remaining overlap between
      -- bodies in a heap is the price, it is bounded by how hard the stone is
      -- squeezing them, and it is what the test measures rather than forbids.
      local up2 = settle_against_world(model, bodies, id, r, kind.restitution)
      if up2 > up then up = up2 end

      -- Grounded is a fact about the contact, not about the height. `up` is the
      -- most upward-facing normal anything pushed with this tick, so a ball on a
      -- tread is grounded and a ball pressed against a riser is not.
      local grounded = up > 0.5

      if grounded then
        -- Rolling resistance, applied only in contact. Some is needed or the
        -- mountain fills with balls oscillating in the bottom of every dip
        -- forever; much more and they stop before they have found a way down.
        local decay = 1 - kind.roll_friction * dt
        if decay < 0 then decay = 0 end
        bodies.vx[id] = bodies.vx[id] * decay
        bodies.vy[id] = bodies.vy[id] * decay

        -- Below the floor a bounce is not a bounce. Without this a settling ball
        -- performs several hundred infinitesimal bounces a second, each one a
        -- contact, none of them visible, all of them costing.
        if bodies.vz[id] > 0 and bodies.vz[id] < kind.bounce_floor then
          bodies.vz[id] = 0
        end
      end

      -- How long it has been going nowhere. The aquarium reads this and drops a
      -- new ball in at the top when it expires.
      local dx = bodies.x[id] - was_x
      local dy = bodies.y[id] - was_y
      bodies.distance[id] = bodies.distance[id] + math.sqrt(dx * dx + dy * dy)

      -- Rest is measured on the horizontal velocity rather than on the whole of
      -- it. A ball settling on a tread still has a vertical component for a few
      -- ticks while the bounces die away, and counting that would keep resetting
      -- the timer of a ball that has plainly stopped going anywhere.
      local flat = math.sqrt(bodies.vx[id] ^ 2 + bodies.vy[id] ^ 2)
      if grounded and flat < kind.rest_speed then
        bodies.rest_timer[id] = bodies.rest_timer[id] + dt
      else
        bodies.rest_timer[id] = 0
      end

      Locomotion.settle_stance(Stone, store, bodies, id)
      Locomotion.check_in_world(Stone, store, bodies, id, "bouncing")

      -- And that it is still above the ground, which the rim check does not ask.
      --
      -- `check_in_world` looks at x and y, because until now nothing could get
      -- out through the floor -- a body walked on surfaces or fell onto them. A
      -- sphere can, if a face ever fails to catch it, and the failure is silent:
      -- the ball keeps being simulated, keeps being drawn somewhere off the
      -- bottom of the screen, and shows up only as a population that is quietly
      -- one short. One comparison a body a tick against that.
      if bodies.z[id] < -1 then
        error(string.format(
          "body %d fell out of the bottom of the world at (%.2f, %.2f, %.2f) " ..
          "while moving as 'bouncing' -- a face let it through",
          id, bodies.x[id], bodies.y[id], bodies.z[id]))
      end
    end
  end
end
-- }}}

-- The pair resolver, exposed by name so that a test can put two spheres in known
-- positions and check what comes out. Everything else in this file needs a world
-- around it; this is the one piece that is pure arithmetic on two bodies, and it
-- is where conservation of momentum either holds or does not.
M.resolve_pair_for_test = resolve_pair

return M
