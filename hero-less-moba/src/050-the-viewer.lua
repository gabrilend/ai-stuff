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

-- 050-the-viewer.lua
--
-- The window, the loop, and the two snapshots.
--
-- ## Two clocks, and only one of them matters
--
-- The world advances in fixed steps. The display advances whenever it feels like
-- it. This file is where those two facts are reconciled, and the reconciliation
-- is one accumulator and one clamp:
--
--   * real time piles up in an accumulator
--   * whole ticks are taken out of it and handed to the simulation
--   * what is left over, as a fraction of a tick, is the blend between the two
--     most recent snapshots
--
-- **Allowed to be behind. Never allowed to be ahead.** The blend is clamped at 1
-- rather than trusted to stay there. A viewer that extrapolates draws a frontline
-- that is not really there, and a player judging a lane by eye acts on it.
--
-- ## What this program may do
--
-- Reads snapshots. Writes commands. Holds no state the simulation needs, decides
-- nothing the simulation could decide, never writes into the world.
--
-- Those were easy to keep when the only viewer was fifty lines of text. This is
-- where they start costing something, and they are still not negotiable -- the
-- payoff is that every bug has a side, and in a game about a thousand small
-- bodies interacting, halving the search space with one question is worth a great
-- deal.

local M = {}

-- {{{ local function read_capture_plan()
-- The unattended-screenshot plan, read from the environment.
--
-- This exists so that the viewer can be checked without a person sitting at the
-- keyboard. A renderer is the one part of this project that cannot be tested by
-- asserting a number -- the question is always "does it look right" -- and the
-- next best thing is a picture taken the same way every time, which can be looked
-- at once and diffed against forever after.
--
--   HLM_CAPTURE       -- where to write the png
--   HLM_CAPTURE_AT    -- how many seconds of *match* to run first
--   HLM_CAPTURE_SPEED -- how many ticks per real tick to run while getting there,
--                        so a picture of minute four does not take four minutes
--   HLM_CAPTURE_ZOOM  -- optional: wheel notches, then screen x and y to zoom at,
--                        so the camera itself can be photographed doing its job
--   HLM_CAPTURE_HOLD  -- optional: an upgrade kind to be holding, so the
--                        pull-back and the lit destinations can be photographed
--
-- Absent, nothing here runs and the viewer behaves exactly as it does for a
-- player. Present, it takes its picture and quits.
local function read_capture_plan()
  local path = os.getenv("HLM_CAPTURE")
  if path == nil or path == "" then
    return nil
  end
  local plan = {
    path = path,
    at = tonumber(os.getenv("HLM_CAPTURE_AT")) or 20,
    speed = tonumber(os.getenv("HLM_CAPTURE_SPEED")) or 8,
    taken = false,
  }
  plan.hold = tonumber(os.getenv("HLM_CAPTURE_HOLD")) or 0
  local zoom = os.getenv("HLM_CAPTURE_ZOOM")
  if zoom ~= nil and zoom ~= "" then
    local notches, x, y = zoom:match("^(-?%d+):(%d+):(%d+)$")
    if notches == nil then
      error("HLM_CAPTURE_ZOOM should read notches:x:y, and read '" .. zoom .. "'")
    end
    plan.zoom = {notches = tonumber(notches), x = tonumber(x), y = tonumber(y)}
  end
  return plan
end
-- }}}

-- {{{ local function take_capture()
local function take_capture(plan)
  plan.taken = true
  love.graphics.captureScreenshot(function(image_data)
    local encoded = image_data:encode("png")
    local handle = io.open(plan.path, "wb")
    if handle == nil then
      error("cannot write a screenshot to " .. plan.path)
    end
    handle:write(encoded:getString())
    handle:close()
    love.event.quit()
  end)
end
-- }}}

-- {{{ function M.load()
-- Builds everything and opens the window.
function M.load(root)
  M.root = root

  M.tick_module = loadfile(root .. "/src/042-the-tick.lua")()
  M.modules     = M.tick_module.load_cast(root)
  M.camera_module = loadfile(root .. "/src/046-the-camera.lua")()
  M.renderer    = loadfile(root .. "/src/047-the-renderer.lua")()
  M.panel       = loadfile(root .. "/src/048-the-panel.lua")()
  M.input       = loadfile(root .. "/src/049-input.lua")()

  local parameters = M.modules.match_parameters.load()
  M.world = M.tick_module.assemble(M.modules, parameters)

  M.tick_duration = 1 / parameters.unit.ticks_per_second
  M.accumulator = 0

  M.renderer.load(M.world, M.camera_module)
  M.panel.load(M.renderer)

  -- The camera gets the window minus the panel, so that "the whole map" at rest
  -- means the whole map in the space the map actually has.
  M.camera = M.camera_module.create(M.world.map.bounds,
                                    0, 0,
                                    M.panel.panel_left(),
                                    love.graphics.getHeight())
  M.state = M.input.create()
  M.capture = read_capture_plan()
  if M.capture ~= nil then
    M.state.speed = M.capture.speed
  end

  -- What the input layer is handed. Assembled once so that every callback sees
  -- the same set of neighbours and none of them has to reach for a global.
  M.context = {
    world         = M.world,
    camera        = M.camera,
    camera_module = M.camera_module,
    panel         = M.panel,
    queue         = function(command)
      M.modules.commands.queue(M.world, command)
    end,
    -- Which player the person at the keyboard is. A real match has one and it is
    -- fixed; the prototype lets you switch teams, so it derives one from that.
    player_number = function(state)
      return (state.watching == 1) and 1 or (M.world.parameters.team_size + 1)
    end,
  }
end
-- }}}

-- {{{ local function drain_events()
-- Turns this tick's events into things on screen.
--
-- Every event here is legible at the rest framing, which is the camera's rule
-- read from the other end: if a thing is worth raising an event about, a player
-- must not have to be zoomed in to learn about it.
local function drain_events(world, frame, watching)
  for _, event in ipairs(frame.event) do
    if event.name == "refused" then
      M.panel.note_refusal(event.reason)
    end
  end
end
-- }}}

-- {{{ function M.update()
function M.update(delta_time)
  -- A frame that took a very long time -- the window was dragged, the machine
  -- slept -- is truncated rather than simulated through. Catching up on four
  -- seconds of ticks in one frame produces a longer frame, which produces more
  -- catching up, and the window stops responding entirely.
  if delta_time > 0.25 then
    delta_time = 0.25
  end

  M.input.update(M.state, M.context, delta_time)
  M.camera_module.update(M.camera, delta_time)

  if M.state.paused then
    -- The accumulator is dropped rather than kept. Keeping it would make
    -- unpausing spend the pause's worth of real time on a burst of ticks.
    M.accumulator = 0
    return
  end

  -- The snapshot only ever fills in one team's sign-posts, so it has to be told
  -- which. On a real match this would be fixed at the lobby and never change.
  M.world.viewing_team = M.state.watching

  M.accumulator = M.accumulator + delta_time * M.state.speed

  -- A ceiling on ticks per frame, for the same reason the delta is clamped. At
  -- high speed this is what stops the simulation from outrunning the display
  -- rather than dropping frames.
  local budget = 40
  while M.accumulator >= M.tick_duration and budget > 0 do
    M.accumulator = M.accumulator - M.tick_duration
    if not M.tick_module.advance(M.world) then
      M.accumulator = 0
      break
    end
    drain_events(M.world, M.modules.snapshot.newest(M.world), M.state.watching)
    budget = budget - 1
  end

  -- The unattended capture, if one was asked for. Checked after the ticks so the
  -- picture is of a match that has actually got somewhere.
  if M.capture ~= nil and not M.capture.taken then
    local seconds = M.world.tick * M.tick_duration
    if seconds >= M.capture.at then
      if M.capture.zoom ~= nil then
        M.camera_module.wheel(M.camera, M.capture.zoom.notches,
                              M.capture.zoom.x, M.capture.zoom.y)
        -- Settle the ease, so the picture is of the framing that was asked for
        -- rather than of a frame somewhere on the way to it.
        for _ = 1, 60 do
          M.camera_module.update(M.camera, 1 / 60)
        end
      end
      -- Back to walking pace for the frame that gets photographed, so that the
      -- picture is drawn the way a player would see it rather than at the speed
      -- it was fast-forwarded at.
      M.state.speed = 1

      if M.capture.hold ~= 0 then
        M.state.held_kind = M.capture.hold
        M.camera_module.pull_back(M.camera)
        -- Settle the pull-back, so the picture is of the framing the gesture
        -- asks for rather than of a frame on the way to it.
        for _ = 1, 90 do
          M.camera_module.update(M.camera, 1 / 60)
        end
        M.state.mouse_x = love.graphics.getWidth() - 250
        M.state.mouse_y = 120
      end
      M.capture.pending = true
    end
  end
end
-- }}}

-- {{{ function M.draw()
function M.draw()
  love.graphics.clear(M.renderer.COLOUR.ground)

  local newest   = M.modules.snapshot.newest(M.world)
  local previous = M.modules.snapshot.previous(M.world)

  -- The blend, clamped. See the note at the top of this file: never ahead.
  local blend = M.accumulator / (M.tick_duration * M.state.speed)
  if blend < 0 then blend = 0 end
  if blend > 1 then blend = 1 end
  -- At high speed a single displayed frame spans many ticks, and interpolating
  -- across them shows positions between two states that were never adjacent. So
  -- above a walking pace the blend is dropped and the newest state is drawn as
  -- it is -- honest and slightly steppy, rather than smooth and invented.
  if M.state.speed > 1 then
    blend = 1
  end

  local player_number = M.context.player_number(M.state)

  M.renderer.draw(M.world, M.camera, previous, newest, blend,
                  M.state.held_kind, M.state.watching, M.state.held_hero)
  M.panel.draw(M.world, M.camera, newest, M.state.watching,
               M.state.held_kind, M.state.mouse_x, M.state.mouse_y,
               M.state.speed, M.state.paused,
               player_number, M.state.held_hero)

  -- The one banner. A finished match is the only thing in the game that takes
  -- over the screen, because it is the only thing after which nothing else is
  -- worth looking at.
  -- The capture is taken at the end of a draw so that it photographs a finished
  -- frame rather than a half-built one.
  if M.capture ~= nil and M.capture.pending and not M.capture.taken then
    M.capture.pending = false
    take_capture(M.capture)
  end

  if newest.winner ~= 0 then
    local width = M.panel.panel_left()
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", 0, love.graphics.getHeight() * 0.5 - 60, width, 120)
    local text
    if newest.winner == 3 then
      text = "a draw -- both libraries fell on the same tick"
    else
      text = "team " .. newest.winner .. " burned the last copy"
    end
    love.graphics.setColor(1, 1, 1, 0.92)
    love.graphics.setFont(M.panel.font_big)
    love.graphics.printf(text, 0, love.graphics.getHeight() * 0.5 - 12, width, "center")
  end
end
-- }}}

-- {{{ function M.resize()
function M.resize(width, height)
  M.camera_module.reframe(M.camera, 0, 0, M.panel.panel_left(), height)
  -- The rest framing changed, so a camera sitting at the old floor is now below
  -- the new one. Nudging it back by zooming about the centre by a factor of one
  -- costs nothing and runs the clamp.
  M.camera_module.zoom_about(M.camera, 1.0, width * 0.5, height * 0.5)
end
-- }}}

-- The LOVE callbacks, forwarded. Kept as one block so that the whole surface this
-- program presents to the engine is visible in one place.
function M.keypressed(key)          M.input.keypressed(M.state, M.context, key) end
function M.wheelmoved(dx, dy)       M.input.wheel(M.state, M.context, dx, dy) end
function M.mousepressed(x, y, b)    M.input.mousepressed(M.state, M.context, x, y, b) end
function M.mousereleased(x, y, b)   M.input.mousereleased(M.state, M.context, x, y, b) end
function M.mousemoved(x, y)         M.input.mousemoved(M.state, M.context, x, y) end

return M
