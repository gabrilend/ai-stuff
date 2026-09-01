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
local Stone, Projection, Palette, Renderer, Camera, Params, Tick, Validator, Walking

local world      -- the maze, the streams, the bodies, the report
local baked      -- the two static meshes and their band ranges
local camera
local screen_w, screen_h
local body_bands

local dragging   = false
local show_help  = true
local paused     = false
local screenshot_after = nil
local screenshot_delay = 0.6
local start_zoom = nil
local start_at   = nil
local scene      = "balls"
local overrides  = {}
local pass_time  = {}

-- {{{ local function load_modules(r)
local function load_modules(r)
  Params     = dofile(r .. "/src/028-maze-parameters.lua")
  Stone      = dofile(r .. "/src/030-the-stone.lua")
  Validator  = dofile(r .. "/src/032-the-validator.lua")
  Walking    = dofile(r .. "/src/038-walking.lua")
  Tick       = dofile(r .. "/src/039-the-tick.lua")
  Projection = dofile(r .. "/src/040-the-projection.lua")
  Palette    = dofile(r .. "/src/041-the-palette.lua")
  Renderer   = dofile(r .. "/src/042-the-renderer.lua")
  Camera     = dofile(r .. "/src/043-the-camera.lua")
end
-- }}}

-- {{{ local function parse_arguments(argv)
-- Only the flags a windowed run understands. The whole command line lives in
-- ./run-maze, which decides whether the engine is started at all.
local function parse_arguments(argv)
  local i = 1
  while argv and i <= #argv do
    local a = argv[i]
    if     a == "--seed"     then overrides.seed   = tonumber(argv[i+1]); i = i + 2
    elseif a == "--width"    then overrides.width  = tonumber(argv[i+1]); i = i + 2
    elseif a == "--depth"    then overrides.depth  = tonumber(argv[i+1]); i = i + 2
    elseif a == "--layers"   then overrides.layers = tonumber(argv[i+1]); i = i + 2
    elseif a == "--terraces" then overrides.terrace_count = tonumber(argv[i+1]); i = i + 2
    elseif a == "--scene"    then scene = argv[i+1]; i = i + 2
    elseif a == "--zoom"     then start_zoom = tonumber(argv[i+1]); i = i + 2
    elseif a == "--at"       then start_at = { tonumber(argv[i+1]), tonumber(argv[i+2]) }; i = i + 3
    elseif a == "--screenshot" then screenshot_after = argv[i+1]; i = i + 2
    elseif a == "--after"    then screenshot_delay = tonumber(argv[i+1]); i = i + 2
    else i = i + 1 end
  end
end
-- }}}

-- {{{ local function build(seed)
local function build(seed)
  local o = {}
  for k, v in pairs(overrides) do o[k] = v end
  if seed then o.seed = seed end

  world = Tick.new_world(root, Params.with(o), scene)
  baked = Renderer.build(Stone, Projection, Palette, world.store, love.graphics)
  body_bands = { max_band = baked.max_band }

  print(Validator.describe(world.report))
  print(string.format("  faces              %d", baked.faces))
  print(string.format("  bodies             %d in scene '%s'", world.bodies.live, scene))
end
-- }}}

-- {{{ function M.load(r, argv)
function M.load(r, argv)
  root = r
  load_modules(r)
  parse_arguments(argv)

  screen_w, screen_h = love.graphics.getDimensions()
  camera = Camera.new()
  build(nil)
  Camera.fit(Projection, camera, world.store, screen_w, screen_h)

  -- A detail shot: a zoom level and a place to point it. Used by the phase demos
  -- and whenever a rendering change has to be compared against the same frame
  -- from before it, which is impossible if the camera is somewhere different.
  if start_zoom then camera.scale = start_zoom end
  if start_at then
    local h = world.store.height[Stone.index(world.store, start_at[1], start_at[2])] or 0
    Projection.centre_on(camera, start_at[1], start_at[2], h, screen_w, screen_h)
  end

  love.graphics.setBackgroundColor(Palette.SKY)
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

  -- The engine's real elapsed time stops here. Everything below the tick gets a
  -- fixed sixtieth of a second or nothing at all.
  if not paused then
    Tick.advance(world, dt, pass_time)
  end

  -- A screenshot run opens the window, lets the simulation settle for a moment,
  -- saves a frame and leaves. Used by the phase demos and when a rendering
  -- change needs comparing against the same frame from before it.
  if screenshot_after and love.timer.getTime() > screenshot_delay then
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
-- The stone a band at a time, with the bodies of each band in between.
--
-- The meshes were baked at scale one with no pan, so the camera is applied as a
-- transform rather than by rebuilding geometry -- panning and zooming a hundred
-- thousand polygons costs two numbers.
function M.draw()
  Renderer.bucket_bodies(world.store, world.bodies, body_bands)

  love.graphics.push()
  love.graphics.translate(camera.pan_x, camera.pan_y)
  love.graphics.scale(camera.scale, camera.scale)

  local flat = { pan_x = 0, pan_y = 0, scale = 1 }
  local outline, fill = baked.outline, baked.fill
  local bands = baked.bands

  for band = 0, baked.max_band do
    local range = bands[band]
    if range and range.count > 0 then
      love.graphics.setColor(1, 1, 1, 1)
      outline:setDrawRange(range.first, range.count)
      love.graphics.draw(outline)
      fill:setDrawRange(range.first, range.count)
      love.graphics.draw(fill)
    end

    local here = body_bands[band]
    if here and here.n > 0 then
      for k = 1, here.n do
        Renderer.draw_body(Projection, Palette, flat, world.store, world.bodies,
                           world.creatures, here[k], Walking, love.graphics)
      end
    end
  end

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
  love.graphics.rectangle("fill", 0, 0, 350, show_help and 216 or 90)
  love.graphics.setColor(1, 1, 1, 1)

  local lines = {
    string.format("seed %d   %d x %d x %d   scene '%s'",
                  r.seed, r.width, r.depth, r.layers, scene),
    string.format("%d floor cells   %d staircases   diameter %d",
                  r.floor_cells, (r.staircases_cut or 0) + (r.extra_staircases or 0),
                  r.diameter),
    string.format("%d faces   %.0f fps   zoom %.2f", baked.faces,
                  love.timer.getFPS(), camera.scale),
    string.format("tick %d   %d bodies   %d spawned   %d retired%s",
                  world.tick_count, world.bodies.live, world.counters.spawned,
                  world.counters.removed_at_rest, paused and "   [PAUSED]" or ""),
  }
  if show_help then
    lines[#lines + 1] = ""
    lines[#lines + 1] = "drag or arrows   pan"
    lines[#lines + 1] = "wheel            zoom at the pointer"
    lines[#lines + 1] = "f                fit the whole maze"
    lines[#lines + 1] = "space            hold the simulation still"
    lines[#lines + 1] = "."                .. "                one tick, while held still"
    lines[#lines + 1] = "n                a new maze, next seed"
    lines[#lines + 1] = "1 2 3            balls / little guys / both"
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

-- A dispatch table rather than a chain of comparisons: adding a key is a row.
local KEYS = {}

-- {{{ function M.keypressed(key)
function M.keypressed(key)
  local action = KEYS[key]
  if action then action() end
end
-- }}}

KEYS["escape"] = function() love.event.quit() end
KEYS["h"]      = function() show_help = not show_help end
KEYS["space"]  = function() paused = not paused end
KEYS["."]      = function() if paused then Tick.tick(world, pass_time) end end
KEYS["f"]      = function()
  Camera.fit(Projection, camera, world.store, screen_w, screen_h)
end
KEYS["n"]      = function()
  build(world.params.seed + 1)
  Camera.fit(Projection, camera, world.store, screen_w, screen_h)
end
KEYS["1"] = function() scene = "balls"; build(world.params.seed) end
KEYS["2"] = function() scene = "guys";  build(world.params.seed) end
KEYS["3"] = function() scene = "both";  build(world.params.seed) end

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
