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

-- 045-the-viewer.lua
--
-- The engine's callbacks, the accumulator, the panel, and the input.
--
-- This file and the renderer are the only two that touch the engine. Everything
-- underneath receives a fixed timestep and returns state; this decides when to
-- ask for one and what to do with the answer.

local M = {}

local root
local Stone, Projection, Palette, Renderer, Camera, Params, Streams, Carve, Validator

local world      -- the stone, the report, and (once phase three lands) the bodies
local baked      -- the two static meshes
local camera
local screen_w, screen_h

local dragging   = false
local show_help  = true
local screenshot_after = nil
local start_zoom = nil
local start_at   = nil

-- {{{ local function load_modules(r)
local function load_modules(r)
  Stone      = dofile(r .. "/src/030-the-stone.lua")
  Params     = dofile(r .. "/src/028-maze-parameters.lua")
  Streams    = dofile(r .. "/src/029-random-streams.lua")
  Carve      = dofile(r .. "/src/031-carving.lua")
  Validator  = dofile(r .. "/src/032-the-validator.lua")
  Projection = dofile(r .. "/src/040-the-projection.lua")
  Palette    = dofile(r .. "/src/041-the-palette.lua")
  Renderer   = dofile(r .. "/src/042-the-renderer.lua")
  Camera     = dofile(r .. "/src/043-the-camera.lua")
end
-- }}}

-- {{{ local function parse_arguments(argv)
-- Only the flags a windowed run understands. The full command line lives in
-- ./run-maze, which decides whether the engine is started at all.
local function parse_arguments(argv)
  local overrides = {}
  local i = 1
  while argv and i <= #argv do
    local a = argv[i]
    if     a == "--seed"   then overrides.seed   = tonumber(argv[i+1]); i = i + 2
    elseif a == "--width"  then overrides.width  = tonumber(argv[i+1]); i = i + 2
    elseif a == "--depth"  then overrides.depth  = tonumber(argv[i+1]); i = i + 2
    elseif a == "--layers" then overrides.layers = tonumber(argv[i+1]); i = i + 2
    elseif a == "--terraces" then overrides.terrace_count = tonumber(argv[i+1]); i = i + 2
    elseif a == "--screenshot" then screenshot_after = argv[i+1]; i = i + 2
    elseif a == "--zoom"   then start_zoom = tonumber(argv[i+1]); i = i + 2
    elseif a == "--at"     then start_at = { tonumber(argv[i+1]), tonumber(argv[i+2]) }; i = i + 3
    elseif a == "--window" then
      love.window.setMode(tonumber(argv[i+1]), tonumber(argv[i+2]), { resizable = true })
      i = i + 3
    else i = i + 1 end
  end
  return overrides
end
-- }}}

-- {{{ function M.load(r, argv)
function M.load(r, argv)
  root = r
  load_modules(r)

  local overrides = parse_arguments(argv)
  local p = Params.check(Params.with(overrides))

  local streams = Streams.make_set(p.seed)
  local store, report = Carve.generate(root, p, streams)
  Validator.validate(root, store, p, report)

  world = { store = store, report = report, params = p, streams = streams }

  screen_w, screen_h = love.graphics.getDimensions()
  camera = Camera.new()
  Camera.fit(Projection, camera, store, screen_w, screen_h)

  -- A detail shot: a zoom level and a place to point it. Used by the phase demos
  -- and whenever a rendering change has to be compared against the same frame
  -- from before it, which is impossible if the camera is somewhere different.
  if start_zoom then camera.scale = start_zoom end
  if start_at then
    local h = store.height[Stone.index(store, start_at[1], start_at[2])] or 0
    Projection.centre_on(camera, start_at[1], start_at[2], h, screen_w, screen_h)
  end

  baked = Renderer.build(Stone, Projection, Palette, store, love.graphics)

  love.graphics.setBackgroundColor(Palette.SKY)
  print(Validator.describe(report))
  print(string.format("  faces              %d", baked.faces))
end
-- }}}

-- {{{ function M.update(dt)
function M.update(dt)
  -- Arrow keys pan. The same two numbers the drag writes, so neither is a mode.
  local speed = 700 * dt
  if love.keyboard.isDown("left")  then Camera.pan_by(camera,  speed, 0) end
  if love.keyboard.isDown("right") then Camera.pan_by(camera, -speed, 0) end
  if love.keyboard.isDown("up")    then Camera.pan_by(camera, 0,  speed) end
  if love.keyboard.isDown("down")  then Camera.pan_by(camera, 0, -speed) end

  Camera.clamp(Projection, camera, world.store, screen_w, screen_h)

  -- A screenshot run opens the window, draws one frame, saves it and leaves.
  -- Used by the phase demos and when a rendering change needs comparing against
  -- the same frame from before it.
  if screenshot_after and love.timer.getTime() > 0.6 then
    local path = screenshot_after
    screenshot_after = nil
    love.graphics.captureScreenshot(function(image_data)
      local f = io.open(path, "wb")
      f:write(image_data:encode("png"):getString())
      f:close()
      love.event.quit()
    end)
  end
end
-- }}}

-- {{{ function M.draw()
function M.draw()
  -- The meshes were baked at scale one with no pan, so the camera is applied as
  -- a transform rather than by rebuilding geometry. Panning and zooming a
  -- hundred thousand polygons then costs two numbers.
  love.graphics.push()
  love.graphics.translate(camera.pan_x, camera.pan_y)
  love.graphics.scale(camera.scale, camera.scale)

  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(baked.outline)
  love.graphics.draw(baked.fill)

  love.graphics.pop()

  M.draw_overlay()
end
-- }}}

-- {{{ function M.draw_overlay()
-- Drawn in screen space after the world and with its own scale, so zooming the
-- maze does not zoom the writing.
function M.draw_overlay()
  local r = world.report
  love.graphics.setColor(0, 0, 0, 0.55)
  love.graphics.rectangle("fill", 0, 0, 330, show_help and 190 or 74)
  love.graphics.setColor(1, 1, 1, 1)

  local lines = {
    string.format("seed %d   %d x %d x %d", r.seed, r.width, r.depth, r.layers),
    string.format("%d floor cells   %d staircases   diameter %d",
                  r.floor_cells, r.staircases_cut, r.diameter),
    string.format("%d faces   %.0f fps   zoom %.2f",
                  baked.faces, love.timer.getFPS(), camera.scale),
  }
  if show_help then
    lines[#lines + 1] = ""
    lines[#lines + 1] = "drag or arrows   pan"
    lines[#lines + 1] = "wheel            zoom at the pointer"
    lines[#lines + 1] = "f                fit the whole maze"
    lines[#lines + 1] = "n                a new maze, next seed"
    lines[#lines + 1] = "h                hide this"
    lines[#lines + 1] = "escape           leave"
  end

  for i, line in ipairs(lines) do
    love.graphics.print(line, 10, 6 + (i - 1) * 16)
  end
end
-- }}}

-- {{{ function M.resize(w, h)
function M.resize(w, h)
  screen_w, screen_h = w, h
end
-- }}}

-- {{{ function M.keypressed(key)
-- A dispatch table rather than a chain of comparisons: adding a key is a row,
-- and the help text above can be generated from the same table the moment there
-- are enough of them to make that worth doing.
local KEYS = {}
function M.keypressed(key)
  local action = KEYS[key]
  if action then action() end
end

KEYS["escape"] = function() love.event.quit() end
KEYS["h"]      = function() show_help = not show_help end
KEYS["f"]      = function()
  Camera.fit(Projection, camera, world.store, screen_w, screen_h)
end
KEYS["n"]      = function()
  local p = Params.check(Params.with{ seed = world.params.seed + 1,
                                      width = world.params.width,
                                      depth = world.params.depth,
                                      layers = world.params.layers,
                                      terrace_count = world.params.terrace_count })
  local streams = Streams.make_set(p.seed)
  local store, report = Carve.generate(root, p, streams)
  Validator.validate(root, store, p, report)
  world = { store = store, report = report, params = p, streams = streams }
  baked = Renderer.build(Stone, Projection, Palette, store, love.graphics)
  Camera.fit(Projection, camera, store, screen_w, screen_h)
  print(Validator.describe(report))
end
-- }}}

-- {{{ function M.wheelmoved(dx, dy)
function M.wheelmoved(dx, dy)
  if dy == 0 then return end
  local mx, my = love.mouse.getPosition()
  Camera.zoom_at(Projection, camera, dy > 0 and 1.15 or 1 / 1.15, mx, my)
end
-- }}}

-- {{{ function M.mousepressed(x, y, button)
function M.mousepressed(x, y, button)
  if button == 1 then
    dragging = true
  elseif button == 2 then
    -- Pointing at the maze and being told what is there. Goes through the ray
    -- march rather than the cheap inversion, because the cheap one reports the
    -- cell *behind* whatever tall thing is being pointed at.
    local cell, layer = Projection.pick(Stone, camera, world.store, x, y)
    if cell then
      local cx, cy = Stone.coords(world.store, cell)
      print(string.format("cell (%d, %d) index %d, solid at layer %d, height %d, %s",
        cx, cy, cell, layer, world.store.height[cell],
        world.store.walkable[cell] and "floor" or "wall"))
    end
  end
end
-- }}}

-- {{{ function M.mousereleased(x, y, button)
function M.mousereleased(x, y, button)
  if button == 1 then dragging = false end
end
-- }}}

-- {{{ function M.mousemoved(x, y, dx, dy)
function M.mousemoved(x, y, dx, dy)
  if dragging then Camera.pan_by(camera, dx, dy) end
end
-- }}}

return M
