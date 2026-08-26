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

-- 047-the-renderer.lua
--
-- Draws the world. Reads snapshots, writes nothing.
--
-- ## The brief
--
-- **A glance should answer "which lane am I losing" with no number anywhere on
-- the screen.** That is the design brief and everything else here is subordinate
-- to it. The three lanes, the bodies in them, the stone along them, and the two
-- bases -- drawn so that the position of three frontlines is the loudest thing in
-- the frame.
--
-- ## The look
--
-- Nobody remembers why. An ancient automated war that nobody alive started: the
-- bases still spawn soldiers because the machinery that spawns soldiers still
-- works, the towers still shoot because that is what towers do, and nothing has
-- required a decision to keep happening for a very long time. The libraries hold
-- the records of why the war began and nobody has read them.
--
-- So: cold ground, faint worn paths, and two colours of light that clearly are
-- not on the same side. The bodies are the only things that look alive, and they
-- are not really.
--
-- ## Two scales, one drawing
--
-- Everything a player must react to is legible at the rest framing. Zoom adds
-- detail and never adds events. Concretely, the things that appear only as you
-- push in -- health bars on bodies, upgrade badges, the marks that say which lane
-- paid for a body -- are all things you look at when you have a moment, and never
-- things you must see to stay informed.

local M = {}

-- The palette. Team 1 is warm and team 2 is cold, which is the fastest
-- distinction the eye makes and the one the whole read depends on.
local COLOUR = {
  ground      = {0.055, 0.062, 0.078},
  lane_fill   = {0.105, 0.115, 0.140},
  lane_edge   = {0.160, 0.175, 0.205},
  connector   = {0.135, 0.125, 0.150},
  milestone   = {0.290, 0.310, 0.350},
  team        = {
    [1] = {0.960, 0.660, 0.240},
    [2] = {0.360, 0.780, 0.930},
    [3] = {0.760, 0.520, 0.900},
  },
  team_dim    = {
    [1] = {0.420, 0.290, 0.110},
    [2] = {0.150, 0.330, 0.400},
    [3] = {0.330, 0.230, 0.390},
  },
  rubble      = {0.200, 0.200, 0.215},
  health_full = {0.470, 0.830, 0.420},
  health_low  = {0.880, 0.330, 0.290},
  text        = {0.780, 0.800, 0.840},
}

-- How large each archetype is drawn, in paces. A captain is visibly the biggest
-- thing in a wave, which is the point of there being one in every lane.
local BODY_RADIUS = {
  [1] = 5.0,   -- melee
  [2] = 4.2,   -- ranged
  [3] = 8.0,   -- captain
  [4] = 5.2,   -- guard
}

-- Below this zoom fraction a body is a dot and nothing else. Above it, detail
-- starts arriving. Named rather than written inline three times, because the
-- three thresholds below have to stay in a sensible order and a reader should be
-- able to see that they do.
-- How far a body's shadow is offset, in paces, and it is the same for every body
-- because there is one light source and it is up and to the left.
local SHADOW_OFFSET = 2.6

local DETAIL_HEALTH = 0.30
local DETAIL_BADGES = 0.52
local DETAIL_NAMES  = 0.70

-- {{{ local function make_disc()
-- A soft white disc, generated once, tinted per draw.
--
-- Generated rather than loaded from a file because it is four lines of
-- arithmetic and a file would be an asset to keep in step with the code that
-- assumes its size. The alpha falls off over the last pixel, which is the whole
-- of the anti-aliasing and is enough at the sizes these are drawn at.
local function make_disc(diameter)
  local data = love.image.newImageData(diameter, diameter)
  local centre = (diameter - 1) * 0.5
  data:mapPixel(function(x, y)
    local dx, dy = x - centre, y - centre
    local distance = math.sqrt(dx * dx + dy * dy) / centre
    local alpha = 1 - distance
    if alpha < 0 then alpha = 0 end
    if alpha > 0.14 then alpha = 1 else alpha = alpha / 0.14 end
    return 1, 1, 1, alpha
  end)
  return love.graphics.newImage(data)
end
-- }}}

-- {{{ function M.load()
-- Builds everything the renderer owns. Called once, from the viewer's load.
--
-- The camera *module* is handed in rather than reached for, so that the renderer
-- asks the camera its questions through the camera's own functions instead of
-- reading fields off the camera record and re-deriving answers the camera
-- already knows. That is the same rule as world_to_screen having exactly one
-- definition, applied one level up.
function M.load(world, camera_module)
  M.camera_module = camera_module
  M.disc = make_disc(64)
  M.disc:setFilter("linear", "linear")

  -- One sprite batch per team, because a batch can only be drawn in one colour
  -- at a time and team colour is the distinction the whole screen turns on.
  --
  -- This is the one place in the viewer where the drawing has to be fast, and it
  -- is fast for the same reason the simulation is: hundreds to thousands of
  -- near-identical things, handed over all at once rather than one at a time.
  M.batch = {}
  for team = 1, 3 do
    M.batch[team] = love.graphics.newSpriteBatch(M.disc, 4096, "stream")
  end

  -- A second batch for shadows, drawn under everything.
  --
  -- The shadow is the detail that says the dots are **objects standing on
  -- ground** rather than marks on a surface. At this scale a soldier is a
  -- coloured dot and is meant to be -- a thousand of them read as weather, not as
  -- a thousand characters -- and the shadow is what stops that reading from
  -- flattening into a diagram.
  M.shadow_batch = love.graphics.newSpriteBatch(M.disc, 4096, "stream")

  M.font_small = love.graphics.newFont(11)
  M.font_badge = love.graphics.newFont(10)
  M.world = world
end
-- }}}

-- {{{ local function set_colour()
local function set_colour(rgb, alpha)
  love.graphics.setColor(rgb[1], rgb[2], rgb[3], alpha or 1)
end
-- }}}

-- {{{ local function draw_lane_ground()
-- The three lanes, drawn at their real widths.
--
-- The centre lane is visibly wider than the side lanes and that is topography,
-- not decoration: it is where numbers matter most, because more bodies get into
-- contact at once. A player should be able to see that before anybody explains
-- it, which is why the width is drawn rather than merely stored.
local function draw_lane_ground(world, camera)
  for _, lane in ipairs(world.map.lane) do
    local points = {}
    for _, node_id in ipairs(lane.path) do
      local node = world.map.node[node_id]
      points[#points + 1] = node.x
      points[#points + 1] = node.y
    end

    love.graphics.setLineStyle("smooth")
    love.graphics.setLineJoin("bevel")

    set_colour(COLOUR.lane_fill)
    love.graphics.setLineWidth(lane.width)
    love.graphics.line(points)

    set_colour(COLOUR.lane_edge)
    love.graphics.setLineWidth(1.5 / camera.drawn_scale)
    love.graphics.line(points)
  end
end
-- }}}

-- {{{ local function draw_connectors()
-- The ground the jungle used to occupy, with everything that made it jungle
-- taken out. Drawn thinner and duller than a lane, because that is what it is:
-- the only route from the top of the map to the bottom, and a place nothing
-- spawns, nothing camps, and no tower covers.
local function draw_connectors(world, camera)
  set_colour(COLOUR.connector)
  love.graphics.setLineWidth(9 / camera.drawn_scale + 3)
  for _, node in ipairs(world.map.node) do
    if node.lane == 0 and node.kind == 1 then
      for _, neighbour_id in ipairs(node.neighbour) do
        local other = world.map.node[neighbour_id]
        -- Drawn once per pair rather than twice, so that the alpha does not
        -- double and make the connectors the brightest thing on a dim map.
        --
        -- "Once" is the subtle part. Only drawing toward the higher id looks
        -- right and is wrong: a connector's two end edges join it to a *junction*,
        -- and junctions are built before connectors and therefore hold lower ids
        -- -- so both ends of every connector went undrawn and the two of them
        -- floated in the middle of the map, joined to nothing. The rule is
        -- instead "draw it unless the other end is a connector that will draw it
        -- itself", which covers the ends exactly once each.
        local other_is_connector = other.lane == 0 and other.kind == 1
        if (not other_is_connector) or neighbour_id > node.id then
          love.graphics.line(node.x, node.y, other.x, other.y)
        end
      end
    end
  end
end
-- }}}

-- {{{ local function draw_milestones()
-- The marks a lane is measured in.
--
-- Drawn because they are the game's unit of progress: a player who can see them
-- can read a lane the way the simulation does. Push depth is a comparison of
-- these small integers and never a distance, and the two answers differ in
-- exactly the case where getting it right matters most.
local function draw_milestones(world, camera)
  set_colour(COLOUR.milestone, 0.55)
  love.graphics.setLineWidth(1.2 / camera.drawn_scale)
  for _, lane in ipairs(world.map.lane) do
    for m = 1, 7 do
      local node = world.map.node[lane.milestone_node[m]]
      local half = lane.width * 0.5
      -- The tick is drawn across the lane, so its direction has to follow the
      -- lane's direction at that point rather than being axis-aligned.
      local before = world.map.node[lane.path[math.max(1, lane.milestone_index[m] - 1)]]
      local after  = world.map.node[lane.path[math.min(#lane.path, lane.milestone_index[m] + 1)]]
      local dx, dy = after.x - before.x, after.y - before.y
      local length = math.sqrt(dx * dx + dy * dy)
      if length > 0 then
        local nx, ny = -dy / length, dx / length
        love.graphics.line(node.x - nx * half, node.y - ny * half,
                           node.x + nx * half, node.y + ny * half)
      end
    end
  end
end
-- }}}

-- {{{ local function draw_push_bars()
-- Where each team has reached in each lane, drawn along the lane as a band rather
-- than written as a number.
--
-- This is the primary read made explicit. The two bands grow toward each other
-- from opposite ends and the gap between them is the contested ground; a lane
-- where one band has swallowed the other is a lane in trouble, seen rather than
-- computed.
local function draw_push_bars(world, camera, frame)
  for _, lane in ipairs(world.map.lane) do
    local half = lane.width * 0.5
    for team = 1, 2 do
      local depth = frame.team_view[team].push_depth[lane.id]
      if depth > 0 then
        local from_index, to_index
        if team == 1 then
          from_index, to_index = 1, lane.milestone_index[depth]
        else
          from_index, to_index = lane.milestone_index[8 - depth], #lane.path
        end

        local points = {}
        for index = from_index, to_index do
          local node = world.map.node[lane.path[index]]
          points[#points + 1] = node.x
          points[#points + 1] = node.y
        end
        if #points >= 4 then
          set_colour(COLOUR.team_dim[team], 0.85)
          love.graphics.setLineWidth(half * 0.42)
          love.graphics.line(points)
        end
      end
    end
  end
end
-- }}}

-- {{{ local function draw_structures()
-- Stone, its health, its command radius, and what is slotted into it.
--
-- The command radius is drawn for **both** teams, deliberately and uniquely. It
-- is the one piece of information in this game both sides can see, because the
-- attacker and the defender have to reason about the same circle at the same
-- moment: the attacker needs to know how far in they must get to shut the
-- reinforcements off, the defender how far out they must push to turn them back
-- on. Everything else here is hidden until it walks into you.
local function draw_structures(world, camera, frame, detail)
  local kinds = world.parameters.upgrade.kind

  for _, view in ipairs(frame.structure) do
    if view.alive == 1 and view.kind ~= 3 then
      set_colour(COLOUR.team[view.team], 0.075)
      love.graphics.setLineWidth(1.5 / camera.drawn_scale)
      love.graphics.circle("line", view.x, view.y, view.command_radius, 48)
    end
  end

  for _, view in ipairs(frame.structure) do
    local size = (view.kind == 3) and 30 or 19

    if view.alive == 0 then
      -- Rubble stays. "There used to be a tower here" is information, and erasing
      -- it would make a lost lane read as a lane that never had stone in it.
      set_colour(COLOUR.rubble)
      love.graphics.setLineWidth(2.5 / camera.drawn_scale)
      love.graphics.rectangle("line", view.x - size * 0.5, view.y - size * 0.5, size, size)
    else
      set_colour(COLOUR.team_dim[view.team])
      love.graphics.rectangle("fill", view.x - size * 0.5, view.y - size * 0.5, size, size)
      set_colour(COLOUR.team[view.team])
      love.graphics.setLineWidth(2.2 / camera.drawn_scale)
      love.graphics.rectangle("line", view.x - size * 0.5, view.y - size * 0.5, size, size)

      -- Health as a bar under the stone. Falling stone is the second-biggest
      -- event in a lane, so this is legible at every zoom rather than being
      -- detail that arrives when you lean in.
      local bar_width = size * 1.5
      local left = view.x - bar_width * 0.5
      local top = view.y + size * 0.72
      love.graphics.setColor(0, 0, 0, 0.55)
      love.graphics.rectangle("fill", left, top, bar_width, 4)
      local fraction = view.health_fraction
      love.graphics.setColor(
        COLOUR.health_low[1] + (COLOUR.health_full[1] - COLOUR.health_low[1]) * fraction,
        COLOUR.health_low[2] + (COLOUR.health_full[2] - COLOUR.health_low[2]) * fraction,
        COLOUR.health_low[3] + (COLOUR.health_full[3] - COLOUR.health_low[3]) * fraction)
      love.graphics.rectangle("fill", left, top, bar_width * fraction, 4)

      -- What is slotted into it. Without these, the whole trade of putting an
      -- upgrade into stone instead of into bodies is invisible, and an invisible
      -- trade is one nobody makes on purpose.
      if detail >= DETAIL_BADGES then
        local badge_x = view.x - size * 0.5
        local badge_y = view.y - size * 0.5 - 13
        for kind = 1, #kinds do
          local held = view.upgrade_count[kind]
          if held > 0 then
            set_colour(kinds[kind].colour)
            love.graphics.rectangle("fill", badge_x, badge_y, 9, 9)
            badge_x = badge_x + 11
          end
        end
      end
    end
  end
end
-- }}}

-- {{{ local function interpolated_position()
-- Where a body is drawn, between the two most recent frames.
--
-- **Allowed to be behind, never allowed to be ahead.** The blend is clamped to
-- [0, 1] rather than being trusted to arrive there: a viewer that extrapolates
-- shows things that did not happen, and in a game where a player judges a lane by
-- looking at where the frontline is, that is a lie that changes decisions.
--
-- A body absent from the previous frame was just born, and is drawn where it is
-- rather than sliding in from wherever the slot's last occupant died.
local function interpolated_position(previous, newest, id, blend)
  if previous.alive[id] ~= 1 then
    return newest.x[id], newest.y[id]
  end
  return previous.x[id] + (newest.x[id] - previous.x[id]) * blend,
         previous.y[id] + (newest.y[id] - previous.y[id]) * blend
end
-- }}}

-- {{{ local function draw_bodies()
-- Every living body, batched by team.
local function draw_bodies(world, camera, previous, newest, blend, detail)
  for team = 1, 3 do
    M.batch[team]:clear()
  end
  M.shadow_batch:clear()

  local disc_size = M.disc:getWidth()
  local left, top, right, bottom = M.camera_module.visible_rectangle(camera)

  for index = 1, newest.live_count do
    local id = newest.live[index]
    local x, y = interpolated_position(previous, newest, id, blend)

    -- Skipped if it is not on screen. At the rest framing this rejects nothing
    -- and costs four comparisons per body; at close zoom it rejects almost
    -- everything, which is exactly when the frame has the least room to spare.
    if x >= left and x <= right and y >= top and y <= bottom then
      local radius = BODY_RADIUS[newest.archetype[id]] or 5
      local scale = (radius * 2) / disc_size
      M.batch[newest.team[id]]:add(x - radius, y - radius, 0, scale, scale)
      -- Offset down and to the right, and flattened, so the light is consistently
      -- from the upper left across the whole field. One light source, never
      -- stated anywhere else, because nothing else in the game casts anything.
      M.shadow_batch:add(x - radius + SHADOW_OFFSET, y - radius + SHADOW_OFFSET,
                         0, scale, scale * 0.62)
    end
  end

  love.graphics.setColor(0, 0, 0, 0.42)
  love.graphics.draw(M.shadow_batch)

  for team = 1, 3 do
    set_colour(COLOUR.team[team])
    love.graphics.draw(M.batch[team])
  end
end
-- }}}

-- {{{ local function draw_body_detail()
-- Health bars, upgrade badges, and the mark that says which lane paid for a body.
-- Everything here appears only as the camera pushes in.
--
-- **A soldier's upgrades must be readable off the body.** That is not a nicety --
-- it is the only way an opponent learns your arrangement at all. You know roughly
-- *what* they hold, because the deck is shared; you learn *where they put it* by
-- looking at what walks at you. Leaning in has to answer that question, or the
-- fog stops being made of walking and starts being made of the interface not
-- telling you.
local function draw_body_detail(world, camera, previous, newest, blend, detail)
  local kinds = world.parameters.upgrade.kind
  local left, top, right, bottom = M.camera_module.visible_rectangle(camera)

  for index = 1, newest.live_count do
    local id = newest.live[index]
    local x, y = interpolated_position(previous, newest, id, blend)

    if x >= left and x <= right and y >= top and y <= bottom then
      local radius = BODY_RADIUS[newest.archetype[id]] or 5

      if detail >= DETAIL_HEALTH then
        local fraction = newest.health_fraction[id]
        if fraction < 0.999 then
          -- Offsets are in paces, so the bar scales with the body and sits the
          -- same distance above it at every zoom. Kept close: a bar floating a
          -- body's width above its owner stops reading as that body's health.
          local width = radius * 2.3
          love.graphics.setColor(0, 0, 0, 0.5)
          love.graphics.rectangle("fill", x - width * 0.5, y - radius - 3, width, 2.0)
          love.graphics.setColor(
            COLOUR.health_low[1] + (COLOUR.health_full[1] - COLOUR.health_low[1]) * fraction,
            COLOUR.health_low[2] + (COLOUR.health_full[2] - COLOUR.health_low[2]) * fraction,
            COLOUR.health_low[3] + (COLOUR.health_full[3] - COLOUR.health_low[3]) * fraction)
          love.graphics.rectangle("fill", x - width * 0.5, y - radius - 3, width * fraction, 2.0)
        end
      end

      if detail >= DETAIL_BADGES then
        -- One pip per kind carried, sized by how many copies. This is the enemy's
        -- arrangement, read off their frontline.
        local pip_x = x - radius
        local pip_y = y + radius + 2
        for kind = 1, #kinds do
          local held = newest.upgrade_count[kind][id]
          if held > 0 then
            set_colour(kinds[kind].colour)
            love.graphics.rectangle("fill", pip_x, pip_y, 2.6 + held * 0.6, 2.6)
            pip_x = pip_x + 4.2 + held * 0.6
          end
        end
      end

      -- Which lane paid for this body. Equal to the lane it is standing in today;
      -- during a challenge it stops being equal, when all three lanes' soldiers
      -- fight in the centre carrying their own lane's upgrades. Without this mark
      -- that ruling is invisible and unexplainable.
      if detail >= DETAIL_NAMES and newest.flavour[id] == 1 then
        set_colour(COLOUR.text, 0.5)
        love.graphics.setFont(M.font_badge)
        love.graphics.push()
        love.graphics.translate(x + radius + 2, y - radius - 2)
        love.graphics.scale(1 / camera.drawn_scale)
        love.graphics.print(tostring(newest.spawned_lane[id]), 0, 0)
        love.graphics.pop()
      end
    end
  end
end
-- }}}

-- {{{ local function draw_libraries()
-- The two buildings the match is about, drawn last and brightest.
--
-- Destroying the enemy's library is how you win and also how the answer is lost
-- for good. A team that wins has not learned anything; it has burned the last
-- copy of the only question worth asking. Nothing on screen says that -- but the
-- libraries get to be the brightest things on the map, and a player who wonders
-- why is asking the right question.
local function draw_libraries(world, camera, frame)
  for _, view in ipairs(frame.structure) do
    if view.kind == 3 then
      local pulse = 0.72 + 0.28 * math.sin(love.timer.getTime() * 1.4)
      if view.alive == 0 then
        set_colour(COLOUR.rubble)
        love.graphics.setLineWidth(3 / camera.drawn_scale)
        love.graphics.circle("line", view.x, view.y, 34, 6)
      else
        set_colour(COLOUR.team[view.team], 0.16 * pulse)
        love.graphics.circle("fill", view.x, view.y, 46, 32)
        set_colour(COLOUR.team[view.team])
        love.graphics.setLineWidth(3 / camera.drawn_scale)
        love.graphics.circle("line", view.x, view.y, 30, 6)
        love.graphics.circle("fill", view.x, view.y, 12, 6)
      end
    end
  end
end
-- }}}

-- {{{ local function draw_destinations()
-- Where the rune in your hand could go, lit up.
--
-- This is the other half of the pull-back gesture. Selecting a rune zooms the
-- camera out to the whole map and **the valid destinations light up at that
-- scale**, so a placement is chosen by looking at the whole board rather than by
-- reading a slot name off a list. The enemy's armies are on screen while you
-- decide, which is the entire point and the opposite of a panel.
--
-- Only the player's own stone lights up. Dropping on an enemy tower is a miss
-- rather than a refusal, so lighting it would be an invitation to a mistake.
local function draw_destinations(world, camera, frame, team_id)
  -- A slow pulse, so the highlight reads as an offer rather than as an alarm.
  -- Events in this game are allowed to be loud; a menu is not.
  local pulse = 0.55 + 0.45 * math.sin(love.timer.getTime() * 3.4)

  for _, lane in ipairs(world.map.lane) do
    local points = {}
    for _, node_id in ipairs(lane.path) do
      local node = world.map.node[node_id]
      points[#points + 1] = node.x
      points[#points + 1] = node.y
    end
    set_colour(COLOUR.team[team_id], 0.10 + 0.12 * pulse)
    love.graphics.setLineWidth(lane.width * 0.92)
    love.graphics.line(points)
    set_colour(COLOUR.team[team_id], 0.35 + 0.35 * pulse)
    love.graphics.setLineWidth(2.5 / camera.drawn_scale)
    love.graphics.line(points)
  end

  for _, view in ipairs(frame.structure) do
    if view.alive == 1 and view.team == team_id then
      -- A base tower is not a destination: upgrades cannot be slotted into one
      -- directly, they go into the library, which reaches all three at once. So
      -- the base towers stay dark and the library glows, which teaches the rule
      -- without anybody having to be refused first.
      if view.kind ~= 2 then
        local radius = (view.kind == 3) and 44 or 26
        set_colour(COLOUR.team[team_id], 0.20 + 0.30 * pulse)
        love.graphics.circle("fill", view.x, view.y, radius, 24)
        set_colour(COLOUR.team[team_id], 0.55 + 0.45 * pulse)
        love.graphics.setLineWidth(2.5 / camera.drawn_scale)
        love.graphics.circle("line", view.x, view.y, radius, 24)
      end
    end
  end
end
-- }}}

-- {{{ function M.draw()
-- One frame of the world, under the camera's transform.
function M.draw(world, camera, previous, newest, blend, held_kind, watching)
  -- How far in the camera is, 0 at the whole map and 1 at the ceiling. Every
  -- decision about how much detail to draw reads this one number, so that the
  -- thresholds are comparable and a reader can see they are in order.
  local detail = M.camera_module.zoom_fraction(camera)

  love.graphics.push()
  love.graphics.translate(camera.origin_x + camera.width * 0.5,
                          camera.origin_y + camera.height * 0.5)
  love.graphics.scale(camera.drawn_scale)
  love.graphics.translate(-camera.drawn_x, -camera.drawn_y)

  draw_connectors(world, camera)
  draw_lane_ground(world, camera)
  draw_push_bars(world, camera, newest)
  draw_milestones(world, camera)
  -- Drawn before the stone and the bodies, so the highlight sits under them
  -- rather than over them. You are choosing a place, and the place is the ground.
  if held_kind ~= nil and held_kind ~= 0 then
    draw_destinations(world, camera, newest, watching)
  end
  draw_structures(world, camera, newest, detail)
  draw_libraries(world, camera, newest)
  draw_bodies(world, camera, previous, newest, blend, detail)
  if detail >= DETAIL_HEALTH then
    draw_body_detail(world, camera, previous, newest, blend, detail)
  end

  love.graphics.pop()
end
-- }}}

M.COLOUR = COLOUR
M.DETAIL_BADGES = DETAIL_BADGES

return M
