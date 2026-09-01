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

-- 079-the-client.lua
--
-- A picture, a geometry, and spheres. It draws no stone at all.
--
-- Not one polygon of the world. The mountain in the picture was drawn once by
-- something else -- possibly by somebody's hand -- and this has no opinion about
-- what it looks like. What it has is a height field to collide against and five
-- numbers that say where a world position lands in the image, and that is the
-- entire interface.
--
-- The viewer beside it builds a maze, validates it, bakes two meshes, runs seven
-- locomotion rows, follows a director and has an opinion about dinosaurs. To
-- watch a ball roll down a hill it does all of that first. This does none of it.

local M = {}

local root
local SceneFile, Model, Sightlines, Stone, BodyStore, Locomotion, Bouncing,
      Renderer, Baker, Palette, Creatures, Streams

local scene            -- the five numbers and the height field
local picture          -- the background, as a texture
local model            -- the faces the spheres collide with
local world            -- what the bouncing row expects to be handed
local bodies
local sprites
local climb            -- layers of sight gained per diagonal cell, from the scene

local pan_x, pan_y, zoom = 0, 0, 1
local dragging, drag_x, drag_y
local paused = false
local population = 300
local seed = 1

-- Where a spawn's randomness comes from.
--
-- A named stream rather than the global generator, and the rule is not
-- fussiness: two runs of the same scene with the same seed have to put the same
-- balls in the same places, or a thing seen once cannot be looked at again. The
-- global generator is shared with everything else that ever calls it, so its
-- sequence depends on what else happened to run first.
local rng
local accumulator = 0
local screen_w, screen_h
local show_hidden = false
local hidden_now = 0

-- A screenshot run lets the simulation settle for a moment, saves a frame and
-- leaves. The same trick the viewer uses, and for the same reason: a rendering
-- change needs comparing against the same frame from before it, and "the same
-- frame" means the same number of ticks in rather than the same wall clock.
local shot_path, shot_delay = nil, 3.0

-- The simulation's step. Fixed, and it has to be: the speed cap that stops a
-- sphere passing through a face is expressed as a distance per tick, so a step
-- that grows when the frame is slow is a step in which balls leave the world.
local STEP = 1 / 60

-- {{{ local function build_store(scene)
-- A stone store from the scene's height field.
--
-- The bouncing row asks the shared locomotion helpers to settle a body's stance
-- and to check it is still inside the world, and both of those speak store. So
-- one is built here, out of the only thing the client has -- which is also the
-- reason the client needs no map, no plate list and no generator.
--
-- Planes to layers: a scene's height of 22 is ground you stand on at 22, and a
-- store's height is the index of the topmost solid layer, which is 21. See
-- 069-the-map.info.md, where the same conversion is spelled out.
local function build_store(scene)
  local highest = 0
  for i = 0, scene.width * scene.depth - 1 do
    if scene.height[i] > highest then highest = scene.height[i] end
  end

  local store = Stone.new(scene.width, scene.depth, math.min(32, highest + 2))
  store.height, store.walkable = {}, {}
  for i = 0, store.cells - 1 do
    local top_layer = scene.height[i] - 1
    Stone.fill_to(store, i, top_layer)
    store.height[i]   = top_layer
    store.walkable[i] = true
  end
  Stone.recompute_surfaces(store, 0, store.cells - 1)
  return store, highest
end
-- }}}

-- {{{ local function spawn_one()
-- One sphere, dropped near the top with a nudge.
--
-- The nudge is not decoration. Every surface in a height field is level or
-- vertical, so a sphere at rest on one has no sideways force on it at all and
-- stays exactly where it was put. See 073-bouncing.info.md.
local function spawn_one()
  local kind_index
  for i, k in ipairs(Creatures.KINDS) do
    if k.name == "bouncer" then kind_index = i end
  end
  local kind = Creatures.KINDS[kind_index]

  local id = BodyStore.spawn(bodies)
  bodies.alive[id] = 1
  bodies.kind[id] = kind_index
  bodies.radius[id] = kind.radius
  bodies.body_height[id] = kind.body_height
  bodies.health[id] = kind.health

  -- Within a few cells of the summit corner, which for a world that falls toward
  -- the viewer is where a ball has the furthest to travel.
  local x = rng:next_float() * 5 + 1
  local y = rng:next_float() * 5 + 1
  bodies.x[id] = x
  bodies.y[id] = y
  bodies.z[id] = scene.height[math.floor(x) + math.floor(y) * scene.width]
  bodies.vx[id] = (rng:next_float() - 0.5) * kind.spawn_nudge
  bodies.vy[id] = (rng:next_float() - 0.5) * kind.spawn_nudge

  BodyStore.set_locomotion(bodies, id, kind.locomotion)
  Locomotion.settle_stance(Stone, world.store, bodies, id)
  return id
end
-- }}}

-- {{{ function M.load(root_path, argv)
function M.load(root_path, argv)
  root = root_path

  local path
  local i = 1
  while i <= #argv do
    local a = argv[i]
    if     a == "--play"       then path = argv[i + 1]; i = i + 2
    elseif a == "--population" then population = tonumber(argv[i + 1]); i = i + 2
    elseif a == "--zoom"       then zoom = tonumber(argv[i + 1]); i = i + 2
    elseif a == "--seed"       then seed = tonumber(argv[i + 1]); i = i + 2
    elseif a == "--screenshot" then shot_path = argv[i + 1]; i = i + 2
    elseif a == "--after"      then shot_delay = tonumber(argv[i + 1]); i = i + 2
    else i = i + 1 end
  end
  if not path then
    error("the client needs a scene: --play <file>.scene", 0)
  end

  SceneFile  = dofile(root .. "/src/077-the-scene-file.lua")
  Stone      = dofile(root .. "/src/030-the-stone.lua")
  Model      = dofile(root .. "/src/071-the-model.lua")
  Sightlines = dofile(root .. "/src/067-sightlines.lua")
  BodyStore  = dofile(root .. "/src/034-the-body-store.lua")
  Locomotion = dofile(root .. "/src/036-locomotion.lua")
  Bouncing   = dofile(root .. "/src/073-bouncing.lua")
  Renderer   = dofile(root .. "/src/042-the-renderer.lua")
  Baker      = dofile(root .. "/src/075-the-sprite-baker.lua")
  Palette    = dofile(root .. "/src/041-the-palette.lua")
  Creatures  = dofile(root .. "/assets/035-creature-table.lua")
  Streams    = dofile(root .. "/src/029-random-streams.lua")

  rng = Streams.make_set(seed).spawn

  scene = SceneFile.read(path)

  -- The picture, loaded from beside the datafile rather than from anywhere this
  -- program decides. A scene names its own image, so a scene directory can be
  -- moved or copied whole.
  --
  -- Read with plain Lua io and handed to the engine as bytes, rather than by
  -- name. The engine's own loader resolves a name inside its sandbox, which is
  -- rooted at the game directory -- so it cannot open a scene sitting anywhere
  -- else, and a scene that has to live inside the program is not a scene somebody
  -- else can hand you. The rest of this project reads its catalogues the same way
  -- and for the same reason.
  local dir = path:match("^(.*)/[^/]*$") or "."
  local image_path = dir .. "/" .. scene.image
  local f = io.open(image_path, "rb")
  if not f then
    error(string.format("scene '%s' names a picture at %s and there is none",
                        scene.name, image_path), 0)
  end
  local bytes = f:read("*a")
  f:close()

  local file_data = love.filesystem.newFileData(bytes, scene.image)
  picture = love.graphics.newImage(love.image.newImageData(file_data))
  picture:setFilter("linear", "linear")

  local store, highest = build_store(scene)

  model = Model.build({ width = scene.width, depth = scene.depth,
                        height = scene.height }, 0, highest + 6)

  bodies = BodyStore.new(population + 16, store.cells, 1)
  world = { store = store, model = model, bodies = bodies }

  Bouncing.link({ Locomotion = Locomotion, Creatures = Creatures, Model = Model,
                  BodyStore = BodyStore, Stone = Stone })

  sprites = Renderer.bake_sprites(Baker, love.image, love.graphics)

  -- The line of sight, taken from the **scene's** projection rather than from
  -- this project's. A client that assumed its own constants would be right only
  -- for pictures this project drew, and the whole point of the format is that it
  -- need not have.
  climb = Sightlines.climb({ HALF_HEIGHT = scene.half_height,
                             LAYER_PIXELS = scene.layer_pixels })

  for _ = 1, population do spawn_one() end

  screen_w, screen_h = love.graphics.getDimensions()
  pan_x = screen_w * 0.5 - scene.origin_x * zoom
  pan_y = screen_h * 0.5 - scene.origin_y * zoom

  love.window.setTitle("jurassic-maze client — " .. scene.name)
end
-- }}}

-- {{{ function M.update(dt)
function M.update(dt)
  if paused then return end

  -- Fixed steps out of a variable frame, with the leftover carried. The
  -- alternative is a physics step that grows when the machine is busy, and the
  -- speed cap that stops a sphere passing through a wall is a distance per step.
  accumulator = accumulator + dt
  if accumulator > 0.25 then accumulator = 0.25 end

  if shot_path and love.timer.getTime() > shot_delay then
    local path = shot_path
    shot_path = nil
    love.graphics.captureScreenshot(function(image_data)
      local out = io.open(path, "wb")
      out:write(image_data:encode("png"):getString())
      out:close()
      love.event.quit()
    end)
  end

  while accumulator >= STEP do
    accumulator = accumulator - STEP

    BodyStore.reindex(bodies)

    local roster = bodies.rosters[Creatures.BOUNCING]
    if roster and roster.n > 0 then
      Bouncing.advance(world, bodies, roster, 1, roster.n, STEP)
    end

    -- The aquarium. A sphere that has been still long enough is taken away and
    -- another is dropped in at the top, which is what makes this a circulation
    -- rather than a run with an end.
    local kinds = Creatures.KINDS
    for id = 1, bodies.capacity do
      if bodies.alive[id] == 1 then
        local kind = kinds[bodies.kind[id]]
        if bodies.rest_timer[id] > kind.rest_seconds then
          BodyStore.kill(bodies, id)
          spawn_one()
        end
      end
    end
  end
end
-- }}}

-- {{{ function M.draw()
-- The picture, then whatever is standing on it.
function M.draw()
  love.graphics.clear(0.72, 0.80, 0.88)

  love.graphics.push()
  love.graphics.translate(pan_x, pan_y)
  love.graphics.scale(zoom, zoom)

  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(picture, 0, 0)

  local kinds = Creatures.KINDS
  local k = sprites.radius
  hidden_now = 0

  for id = 1, bodies.capacity do
    if bodies.alive[id] == 1 then
      local x, y, z = bodies.x[id], bodies.y[id], bodies.z[id]
      local kind = kinds[bodies.kind[id]]
      local r = kind.radius

      -- Occlusion without a depth buffer.
      --
      -- A body behind a rock has to not be drawn, and there is nothing to sort it
      -- behind -- the world is a photograph. The geometry answers it exactly:
      -- march from the body toward the camera and ask whether any column stands
      -- over the ray. One ray a body a frame, and it is the same march the
      -- sightline survey uses, so it is exact rather than an approximation of a
      -- depth test.
      local blocked = Sightlines.blocked(
        { width = scene.width, depth = scene.depth,
          layers = 1e9, height = scene.height }, climb, x, y, z + r)

      if blocked then
        hidden_now = hidden_now + 1
        if not show_hidden then goto continue end
        love.graphics.setColor(1, 0, 0, 0.5)
      end

      do
        -- The shadow sits on the stone the body's stance says it is on, not at
        -- the body's own height. That is the difference between a falling ball
        -- trailing its shadow downward and one whose shadow waits on the floor
        -- for it.
        local under = scene.height[bodies.cell[id]] or 0
        local sx, sy = SceneFile.to_pixels(scene, x, y, under)
        love.graphics.setColor(0, 0, 0, 0.30)
        love.graphics.draw(sprites.shadow, sx, sy, 0,
                           r * scene.half_width * 1.05 / k,
                           r * scene.half_height * 1.05 / k, k, k)

        local bx, by = SceneFile.to_pixels(scene, x, y, z + r)
        local cr, cg, cb = Palette.creature(kind.name, bodies.team[id])
        love.graphics.setColor(cr, cg, cb, 1)
        local scale = r * scene.half_width / k
        love.graphics.draw(sprites.ball, bx, by, 0, scale, scale, k, k)
      end

      ::continue::
    end
  end

  love.graphics.pop()

  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.print(string.format(
    "%s   %d by %d cells   %d bodies   %d hidden by the geometry   %.0f fps",
    scene.name, scene.width, scene.depth, bodies.live, hidden_now,
    love.timer.getFPS()), 8, 8)
  love.graphics.print(
    "drag to pan   wheel to zoom   space pauses   h shows what is hidden   escape leaves",
    8, 26)
end
-- }}}

-- {{{ function M.keypressed(key)
function M.keypressed(key)
  if key == "escape" then love.event.quit()
  elseif key == "space" then paused = not paused
  elseif key == "h" then show_hidden = not show_hidden
  end
end
-- }}}

-- {{{ function M.wheelmoved(dx, dy)
function M.wheelmoved(dx, dy)
  if dy == 0 then return end
  -- Zoom at the pointer rather than at the middle of the window, so that the
  -- thing being looked at stays under the mouse.
  local mx, my = love.mouse.getPosition()
  local before_x = (mx - pan_x) / zoom
  local before_y = (my - pan_y) / zoom
  zoom = zoom * ((dy > 0) and 1.15 or (1 / 1.15))
  if zoom < 0.1 then zoom = 0.1 elseif zoom > 8 then zoom = 8 end
  pan_x = mx - before_x * zoom
  pan_y = my - before_y * zoom
end
-- }}}

-- {{{ function M.mousepressed(x, y, button)
function M.mousepressed(x, y, button)
  dragging = true; drag_x, drag_y = x, y
end
-- }}}

-- {{{ function M.mousereleased() dragging = false end
function M.mousereleased() dragging = false end
-- }}}

-- {{{ function M.mousemoved(x, y)
function M.mousemoved(x, y)
  if dragging then
    pan_x = pan_x + (x - drag_x)
    pan_y = pan_y + (y - drag_y)
    drag_x, drag_y = x, y
  end
end
-- }}}

-- {{{ function M.resize(w, h)
function M.resize(w, h) screen_w, screen_h = w, h end
-- }}}

return M
