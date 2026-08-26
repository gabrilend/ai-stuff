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

-- 046-the-camera.lua
--
-- A lens you push into.
--
-- ## The one thing this file is for
--
-- **The point of the world under the mouse cursor does not move while you zoom.**
--
-- Everything else here is subordinate to that. A camera that zooms about the
-- centre of the screen moves whatever you were looking at away from you, so the
-- loop becomes zoom, hunt, drag, zoom, hunt, drag. A player puts the cursor on
-- the frontline they want to read and turns the wheel; the frontline swells in
-- place, and they never aim, because they were already pointing at the thing.
--
-- Stated as a property rather than a procedure, because it is a property a test
-- asserts:
--
--     screen_of(world_under_cursor) == cursor    -- before the zoom
--     screen_of(world_under_cursor) == cursor    -- after the zoom
--
-- ## Zoom reveals detail. It never reveals events.
--
-- The rule the whole viewing layer is built on, and it constrains this file from
-- two directions at once.
--
-- Read forwards: anything a player must react to -- a tower falling, a surge
-- starting, a lock breaking -- has to be legible at the rest framing, with no
-- zoom and no camera move. Zooming in is a thing a player does when they have a
-- moment, not a thing the game requires to stay informed.
--
-- Read backwards, which is the half that lands here: **the camera never moves on
-- its own.** Not to follow a body, not to snap to a falling tower, not to frame a
-- monster. If the game were allowed to move the camera to show you something,
-- then the camera's position would be carrying information, and a player who was
-- mid-drag when it fired has been robbed of it. The one exception that is not an
-- exception is home, which the player pressed.
--
-- ## Why the smoothing is not decoration
--
-- A snapped zoom at a high notch rate reads as teleporting and a player loses
-- track of where they were, which reintroduces the hunt this file exists to
-- delete. The easing keeps the two views connected: you can see the frame you
-- left travelling toward the frame you asked for, so you arrive already knowing
-- where you are.
--
-- It also creates the file's one real trap, and the trap has a defence built into
-- the design below. The drawn scale lags the target scale. If the zoom-to-cursor
-- arithmetic were done against the drawn value, every notch during a fast scroll
-- would anchor to a slightly stale point and the world under the cursor would
-- creep. So the arithmetic is done against the **target**, and the anchor is then
-- *re-honoured every frame* against the drawn scale as well -- which is what keeps
-- the point under the cursor fixed during the animation and not merely at the end
-- of it.

local M = {}

-- How much of the viewport the map leaves empty at rest, as a fraction. A map
-- drawn edge to edge looks like it is falling out of the window.
local REST_MARGIN = 0.06

-- The closest the camera may push in, in screen pixels per pace.
--
-- This number is set by issue 702's close-zoom requirement and by nothing else:
-- a soldier's upgrades must be readable off the body, because that is how an
-- opponent learns your arrangement at all. Whatever scale makes a badge legible
-- is the ceiling; if the badges get smaller, this goes up.
local PIXELS_PER_PACE_MAX = 9.0

-- How far one wheel notch moves the scale, multiplicatively.
--
-- Multiplicative rather than additive, so a notch is the same *proportional*
-- change at every scale. An additive step crawls when you are zoomed in and jumps
-- when you are zoomed out, which is the same complaint from both ends.
local WHEEL_FACTOR = 1.18

-- How fast the drawn values chase the target ones. Higher is snappier. Used as
-- the rate of an exponential approach, so it is a time constant and not a speed.
local EASE_RATE = 14.0

-- How fast the keyboard pans, in **screen pixels** per second rather than in
-- world paces. Measured in pixels so that panning feels identical at every zoom
-- level -- in paces it would crawl across the screen when zoomed in and fly when
-- zoomed out.
local KEYBOARD_PAN_PIXELS = 900.0

-- {{{ function M.create()
-- Builds a camera framing the given world bounds inside the given viewport.
function M.create(bounds, viewport_x, viewport_y, viewport_width, viewport_height)
  local camera = {
    bounds = bounds,
    -- The camera's viewport is the part of the window the map gets, which is not
    -- the whole window: the panel takes a strip down the right-hand side.
    --
    -- Framing "the whole map" against the whole window instead would centre the
    -- map behind the panel, so a player at rest would be looking at a map pushed
    -- a hundred and seventy pixels off to one side, with one base partly hidden.
    -- The camera therefore owns a rectangle rather than a size, and every screen
    -- coordinate in this file is relative to that rectangle's origin.
    origin_x = viewport_x,
    origin_y = viewport_y,
    width  = viewport_width,
    height = viewport_height,

    -- What the player asked for.
    target_x = 0, target_y = 0, target_scale = 1,
    -- What is on screen this frame.
    drawn_x = 0, drawn_y = 0, drawn_scale = 1,

    -- The rest framing: the whole map, recomputed from the map's own bounds
    -- rather than written down, so that changing the field size reframes the view
    -- with no second edit anywhere.
    rest_x = 0, rest_y = 0, rest_scale = 1,

    -- The anchor a zoom is being held around. While this is live, the centre is
    -- *derived* from the scale every frame instead of being eased toward a
    -- target, which is what holds a point under the cursor for the whole
    -- animation rather than only at its end.
    anchor_live = false,
    anchor_world_x = 0, anchor_world_y = 0,
    anchor_screen_x = 0, anchor_screen_y = 0,

    -- A drag in progress. Holds the world point that was grabbed, so the drag
    -- keeps that exact point under the cursor -- the same invariant as the zoom,
    -- applied to translation.
    dragging = false,
    drag_world_x = 0, drag_world_y = 0,

    -- Where the camera was before it was pulled back to answer "where does this
    -- go?", so it can be put back afterwards.
    remembered_live = false,
    remembered_x = 0, remembered_y = 0, remembered_scale = 1,
  }

  M.reframe(camera, viewport_x, viewport_y, viewport_width, viewport_height)
  M.home(camera)
  return camera
end
-- }}}

-- {{{ function M.reframe()
-- Recomputes the rest framing for a new viewport size. Called at creation and
-- whenever the window is resized.
--
-- The rest scale is the zoom floor as well as the starting point: you cannot pull
-- back further than the whole map, because there is nothing out there, and a map
-- adrift in empty space is a player who thinks they have lost the game.
function M.reframe(camera, viewport_x, viewport_y, viewport_width, viewport_height)
  camera.origin_x = viewport_x
  camera.origin_y = viewport_y
  camera.width = viewport_width
  camera.height = viewport_height

  local bounds = camera.bounds
  local map_width  = bounds.max_x - bounds.min_x
  local map_height = bounds.max_y - bounds.min_y

  local fit_x = (viewport_width  * (1 - REST_MARGIN * 2)) / map_width
  local fit_y = (viewport_height * (1 - REST_MARGIN * 2)) / map_height
  -- The smaller of the two, so the whole map fits along both axes rather than
  -- along the one that happened to be more generous.
  camera.rest_scale = (fit_x < fit_y) and fit_x or fit_y

  camera.rest_x = bounds.min_x + map_width * 0.5
  camera.rest_y = bounds.min_y + map_height * 0.5
end
-- }}}

-- {{{ function M.world_to_screen()
-- The mapping. Written once, here, and never recomputed inline anywhere else --
-- every camera bug in every project is two copies of this arithmetic that
-- disagree.
function M.world_to_screen(camera, world_x, world_y)
  return (world_x - camera.drawn_x) * camera.drawn_scale + camera.origin_x + camera.width  * 0.5,
         (world_y - camera.drawn_y) * camera.drawn_scale + camera.origin_y + camera.height * 0.5
end
-- }}}

-- {{{ function M.screen_to_world()
-- The exact inverse of the above. The pair are defined next to each other so that
-- editing one without the other is visibly wrong.
function M.screen_to_world(camera, screen_x, screen_y)
  return (screen_x - camera.origin_x - camera.width  * 0.5) / camera.drawn_scale + camera.drawn_x,
         (screen_y - camera.origin_y - camera.height * 0.5) / camera.drawn_scale + camera.drawn_y
end
-- }}}

-- {{{ function M.target_screen_to_world()
-- The same inverse, taken against the **target** scale and centre rather than the
-- drawn ones.
--
-- This is the function the zoom uses, and using it is the difference between a
-- wheel that holds its point and one that creeps. During a fast scroll the drawn
-- values are always behind; anchoring each notch to where the camera *is* rather
-- than where it is *going* compounds the lag into visible drift.
function M.target_screen_to_world(camera, screen_x, screen_y)
  return (screen_x - camera.origin_x - camera.width  * 0.5) / camera.target_scale + camera.target_x,
         (screen_y - camera.origin_y - camera.height * 0.5) / camera.target_scale + camera.target_y
end
-- }}}

-- {{{ local function clamp_scale()
local function clamp_scale(camera, scale)
  if scale < camera.rest_scale then
    return camera.rest_scale
  end
  if scale > PIXELS_PER_PACE_MAX then
    return PIXELS_PER_PACE_MAX
  end
  return scale
end
-- }}}

-- {{{ local function clamp_centre()
-- Holds the centre inside the map's bounds.
--
-- Clamped at the **centre** rather than at the edges, deliberately. Clamping the
-- edges would forbid putting a corner of the map in the middle of the screen,
-- which is exactly what a player wants to do when they are reading a base.
-- Clamping the centre lets the view hang off the edge of the world while
-- guaranteeing the world is never entirely off screen.
local function clamp_centre(camera, x, y)
  local bounds = camera.bounds
  if x < bounds.min_x then x = bounds.min_x end
  if x > bounds.max_x then x = bounds.max_x end
  if y < bounds.min_y then y = bounds.min_y end
  if y > bounds.max_y then y = bounds.max_y end
  return x, y
end
-- }}}

-- {{{ function M.home()
-- Back to the whole map. One action, instant, always available.
--
-- Instant rather than eased, and that is not a shortcut. D7's ruling is that
-- returning to the whole map is a single unmissable action; if getting back were
-- ever a small navigation task -- or even a wait -- players stop zooming in at
-- all, and the detail this camera exists to show goes unread.
--
-- It also clears a drag in progress, so that a player who has got themselves lost
-- with a button held down is not still captured by it when they arrive.
function M.home(camera)
  camera.target_x, camera.target_y = camera.rest_x, camera.rest_y
  camera.target_scale = camera.rest_scale
  camera.drawn_x, camera.drawn_y = camera.rest_x, camera.rest_y
  camera.drawn_scale = camera.rest_scale
  camera.anchor_live = false
  camera.dragging = false
  -- Home is the player saying "put me back", so there is nothing left to return
  -- to afterwards. Keeping the memory here would mean dropping an upgrade snapped
  -- the view somewhere the player had just explicitly left.
  camera.remembered_live = false
end
-- }}}

-- {{{ function M.zoom_about()
-- Changes the scale by a factor while holding one screen point over the same
-- world point. The whole feature, in one function.
--
-- The wheel passes the cursor. The keyboard passes the centre of the screen,
-- because a player using the keyboard is not pointing at anything. One function,
-- two callers, two anchors.
function M.zoom_about(camera, factor, screen_x, screen_y)
  -- Where the anchor is in the world, read against the target so that a fast
  -- scroll does not compound the easing lag into drift.
  local world_x, world_y = M.target_screen_to_world(camera, screen_x, screen_y)

  local scale = clamp_scale(camera, camera.target_scale * factor)
  -- Nothing to do, and saying so rather than re-solving keeps a player scrolling
  -- against the floor from having their centre nudged around by arithmetic that
  -- cannot change the scale.
  if scale == camera.target_scale then
    return
  end
  camera.target_scale = scale

  -- Solve for the centre that puts that world point back under that screen point.
  camera.target_x = world_x - (screen_x - camera.origin_x - camera.width  * 0.5) / scale
  camera.target_y = world_y - (screen_y - camera.origin_y - camera.height * 0.5) / scale
  camera.target_x, camera.target_y = clamp_centre(camera, camera.target_x, camera.target_y)

  -- Remember it, so the easing can keep honouring it every frame instead of only
  -- at the end of the animation.
  camera.anchor_live = true
  camera.anchor_world_x, camera.anchor_world_y = world_x, world_y
  camera.anchor_screen_x, camera.anchor_screen_y = screen_x, screen_y
  -- A deliberate zoom is the player choosing where to look, which retires
  -- whatever the pull-back was going to return them to.
  camera.remembered_live = false
end
-- }}}

-- {{{ function M.wheel()
-- One or more wheel notches at the cursor. Positive is toward the player, which
-- every wheel in every application means "closer".
function M.wheel(camera, notches, cursor_x, cursor_y)
  if notches == 0 then
    return
  end
  M.zoom_about(camera, WHEEL_FACTOR ^ notches, cursor_x, cursor_y)
end
-- }}}

-- {{{ function M.zoom_centre()
-- Keyboard zoom, about the middle of the display.
function M.zoom_centre(camera, notches)
  M.zoom_about(camera, WHEEL_FACTOR ^ notches,
               camera.origin_x + camera.width * 0.5,
               camera.origin_y + camera.height * 0.5)
end
-- }}}

-- {{{ function M.pull_back()
-- Eases the camera all the way out to the whole map, remembering where it was.
--
-- This is the second vision's gesture, and it is a different thing from `home`
-- even though both end at the rest framing. Home is a player saying "I am lost,
-- put me back", and it is instant for that reason. This is the game saying "you
-- have picked something up, and choosing where it goes is a question about the
-- whole map" -- so the pulling back is **visible motion**, because the act of
-- zooming out *is* the act of asking where to put it.
--
-- It remembers, because the answer to that question is usually "back where I was
-- looking", and making a player re-find the fight they were watching every time
-- they place an upgrade would make placing upgrades something they avoid.
function M.pull_back(camera)
  if not camera.remembered_live then
    camera.remembered_x = camera.target_x
    camera.remembered_y = camera.target_y
    camera.remembered_scale = camera.target_scale
    camera.remembered_live = true
  end
  camera.anchor_live = false
  camera.target_x, camera.target_y = camera.rest_x, camera.rest_y
  camera.target_scale = camera.rest_scale
end
-- }}}

-- {{{ function M.return_to_remembered()
-- Eases back to wherever `pull_back` interrupted.
--
-- Does nothing if the player moved the camera themselves in the meantime -- see
-- `forget`. A camera that snapped back over a deliberate pan would be the game
-- overruling a person about where they are looking, which is the one thing the
-- camera is never allowed to do.
function M.return_to_remembered(camera)
  if not camera.remembered_live then
    return
  end
  camera.remembered_live = false
  camera.anchor_live = false
  camera.target_x = camera.remembered_x
  camera.target_y = camera.remembered_y
  camera.target_scale = camera.remembered_scale
  camera.target_x, camera.target_y = clamp_centre(camera, camera.target_x, camera.target_y)
end
-- }}}

-- {{{ function M.forget()
-- Drops the remembered framing, so a later return does nothing.
--
-- Called whenever the player moves the camera while holding something. The
-- moment they have chosen a different place to look, the place they were looking
-- before stops being where they want to end up.
function M.forget(camera)
  camera.remembered_live = false
end
-- }}}

-- {{{ function M.begin_drag()
-- Grabs the world point under the cursor. From here until the drag ends, that
-- point stays under the cursor -- the zoom's invariant, applied to translation.
function M.begin_drag(camera, screen_x, screen_y)
  camera.dragging = true
  camera.anchor_live = false
  camera.remembered_live = false
  camera.drag_world_x, camera.drag_world_y = M.screen_to_world(camera, screen_x, screen_y)
end
-- }}}

-- {{{ function M.drag_to()
-- The cursor moved while the drag is held. Solve for the centre that puts the
-- grabbed world point back under it.
function M.drag_to(camera, screen_x, screen_y)
  if not camera.dragging then
    return
  end
  local scale = camera.target_scale
  camera.target_x = camera.drag_world_x - (screen_x - camera.origin_x - camera.width  * 0.5) / scale
  camera.target_y = camera.drag_world_y - (screen_y - camera.origin_y - camera.height * 0.5) / scale
  camera.target_x, camera.target_y = clamp_centre(camera, camera.target_x, camera.target_y)

  -- A drag is direct manipulation and easing it feels like dragging something
  -- through treacle. The centre snaps; only the scale eases.
  camera.drawn_x, camera.drawn_y = camera.target_x, camera.target_y
end
-- }}}

-- {{{ function M.end_drag()
function M.end_drag(camera)
  camera.dragging = false
end
-- }}}

-- {{{ function M.pan_by_keys()
-- Keyboard panning, in screen pixels per second converted to world paces at the
-- current scale.
function M.pan_by_keys(camera, right, down, delta_time)
  if right == 0 and down == 0 then
    return
  end
  -- Diagonal movement is normalised, so pressing two keys does not pan faster
  -- than pressing one.
  local length = math.sqrt(right * right + down * down)
  right, down = right / length, down / length

  local paces = KEYBOARD_PAN_PIXELS * delta_time / camera.target_scale
  camera.target_x = camera.target_x + right * paces
  camera.target_y = camera.target_y + down  * paces
  camera.target_x, camera.target_y = clamp_centre(camera, camera.target_x, camera.target_y)
  camera.anchor_live = false
  -- The player has chosen where to look, so there is no longer anywhere to go
  -- back to. See `forget`.
  camera.remembered_live = false
end
-- }}}

-- {{{ function M.update()
-- Eases the drawn values toward the target ones. Called once per frame with the
-- real elapsed time.
--
-- The approach is exponential and framed as `remaining * exp(-rate * dt)`, which
-- is what makes it frame-rate independent: the fraction of the gap closed in a
-- given number of seconds is the same whether that time arrived as one long frame
-- or ten short ones. The naive `value += gap * 0.2` closes a different amount at
-- 60Hz and 144Hz, and the camera feels like a different camera on each display.
--
-- The scale is eased **in log space**, so that going from 1x to 2x takes as long
-- as going from 4x to 8x. Zoom is perceived proportionally, and easing it
-- linearly makes the far end of the range crawl.
function M.update(camera, delta_time)
  local keep = math.exp(-EASE_RATE * delta_time)

  camera.drawn_scale = math.exp(
    math.log(camera.target_scale) +
    (math.log(camera.drawn_scale) - math.log(camera.target_scale)) * keep)

  if camera.anchor_live then
    -- Hold the anchor against the *drawn* scale, so the point under the cursor
    -- stays under it for the whole animation rather than arriving there at the
    -- end. This is the line that turns a correct zoom into one that feels right.
    camera.drawn_x = camera.anchor_world_x -
      (camera.anchor_screen_x - camera.origin_x - camera.width  * 0.5) / camera.drawn_scale
    camera.drawn_y = camera.anchor_world_y -
      (camera.anchor_screen_y - camera.origin_y - camera.height * 0.5) / camera.drawn_scale
    camera.drawn_x, camera.drawn_y = clamp_centre(camera, camera.drawn_x, camera.drawn_y)

    -- Once the scale has arrived there is nothing left to hold, and keeping the
    -- anchor live would fight the next pan.
    if math.abs(camera.drawn_scale - camera.target_scale) < 0.0005 then
      camera.drawn_scale = camera.target_scale
      camera.anchor_live = false
    end
  else
    camera.drawn_x = camera.target_x + (camera.drawn_x - camera.target_x) * keep
    camera.drawn_y = camera.target_y + (camera.drawn_y - camera.target_y) * keep
  end
end
-- }}}

-- {{{ function M.visible_rectangle()
-- The world rectangle currently on screen, which the renderer uses to skip
-- everything outside it. At close zoom that is most of the map.
function M.visible_rectangle(camera)
  local half_w = camera.width  * 0.5 / camera.drawn_scale
  local half_h = camera.height * 0.5 / camera.drawn_scale
  return camera.drawn_x - half_w, camera.drawn_y - half_h,
         camera.drawn_x + half_w, camera.drawn_y + half_h
end
-- }}}

-- {{{ function M.zoom_fraction()
-- How far between the rest framing and the ceiling the camera currently is, 0 to
-- 1. Read by the renderer to decide how much detail to draw, and by the panel to
-- draw the zoom indicator.
function M.zoom_fraction(camera)
  local low  = math.log(camera.rest_scale)
  local high = math.log(PIXELS_PER_PACE_MAX)
  if high <= low then
    return 0
  end
  local here = (math.log(camera.drawn_scale) - low) / (high - low)
  if here < 0 then return 0 end
  if here > 1 then return 1 end
  return here
end
-- }}}

M.PIXELS_PER_PACE_MAX = PIXELS_PER_PACE_MAX

return M
