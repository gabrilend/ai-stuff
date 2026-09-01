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

-- 083-scenes-and-plans.lua
--
-- A scene and a plan survive a round trip, and shapes rasterise to the cells they
-- cover.
--
-- Both formats have their reader and their writer in one file, which is the
-- decision this test exists to defend. Split across two files a format drifts, and
-- it drifts *silently*, because each half stays perfectly consistent with itself
-- and only the pair disagrees. A round trip is the cheapest thing that notices.
--
-- The other half is the rasteriser, where the answers are known without having to
-- think: a square of four corners covers the cells inside it and no others, and a
-- shape with a hole traced into it does not cover the hole.

local M = {}

-- Written into the project's own RAM-backed scratch, which is where ephemeral
-- output belongs, and removed afterwards.
local function scratch(root, name)
  return root .. "/tmp/shared-memory/" .. name
end

-- {{{ local function same_scene(t, a, b, what)
local function same_scene(t, a, b, what)
  for _, field in ipairs({ "name", "image", "width", "depth", "half_width",
                           "half_height", "layer_pixels", "origin_x", "origin_y",
                           "spawn_x", "spawn_y", "spawn_z" }) do
    t.equal(b[field], a[field], what .. ": " .. field .. " came back")
  end

  local wrong = 0
  for i = 0, a.width * a.depth - 1 do
    if a.height[i] ~= b.height[i] then wrong = wrong + 1 end
  end
  t.equal(wrong, 0, what .. ": every cell of the height field came back")
end
-- }}}

-- {{{ function M.run(root, t)
function M.run(root, t)
  local SceneFile = dofile(root .. "/src/077-the-scene-file.lua")
  local Plan      = dofile(root .. "/src/081-the-plan.lua")

  os.execute("mkdir -p " .. root .. "/tmp/shared-memory")

  -- A scene, out and back.
  do
    local height = {}
    for i = 0, 5 * 4 - 1 do height[i] = (i % 7) end
    local scene = {
      name = "a test scene", image = "somewhere.png",
      width = 5, depth = 4,
      half_width = 16, half_height = 8, layer_pixels = 10,
      origin_x = 123.5, origin_y = -40,
      spawn_x = 2, spawn_y = 1, spawn_z = 6,
      height = height,
    }

    local path = scratch(root, "round-trip.scene")
    SceneFile.write(path, scene)
    local back = SceneFile.read(path)
    same_scene(t, scene, back, "a scene")
    os.remove(path)
  end

  -- The projection, which is the whole of the interface between a world and a
  -- picture. Two points a cell apart have to land a cell apart on the picture,
  -- and a layer of height has to move a point up by exactly one layer's pixels.
  do
    local scene = { origin_x = 100, origin_y = 200,
                    half_width = 16, half_height = 8, layer_pixels = 10 }

    local ax, ay = SceneFile.to_pixels(scene, 0, 0, 0)
    t.equal(ax, 100, "the world's origin lands on the picture's origin, across")
    t.equal(ay, 200, "and down")

    local bx, by = SceneFile.to_pixels(scene, 1, 0, 0)
    t.equal(bx - ax, 16, "a step in x moves half a cell to the right")
    t.equal(by - ay, 8, "and half a cell down")

    local cx, cy = SceneFile.to_pixels(scene, 0, 1, 0)
    t.equal(cx - ax, -16, "a step in y moves half a cell to the left")
    t.equal(cy - ay, 8, "and half a cell down")

    local dx, dy = SceneFile.to_pixels(scene, 0, 0, 1)
    t.equal(dx, ax, "a layer of height does not move a point sideways")
    t.equal(ay - dy, 10, "and lifts it by exactly one layer of pixels")
  end

  -- A pixel back to a cell, at a chosen elevation. The inverse has to be exact,
  -- because it is what turns a click into a vertex.
  do
    local plan = Plan.new({ name = "p", image = "i.png",
                            half_width = 16, half_height = 8, layer_pixels = 10,
                            origin_x = 40, origin_y = 90 })
    for _, at in ipairs({ { 3, 5, 0 }, { 0, 0, 7 }, { 12, 2, 21 }, { 1, 9, 4 } }) do
      local px, py = Plan.to_pixels(plan, at[1], at[2], at[3])
      local x, y = Plan.to_cell(plan, px, py, at[3])
      t.truthy(math.abs(x - at[1]) < 1e-9 and math.abs(y - at[2]) < 1e-9,
               string.format("(%g, %g) at elevation %d survives the round trip " ..
                             "through the picture", at[1], at[2], at[3]))
    end
  end

  -- A plan, out and back, and then rasterised.
  do
    local plan = Plan.new({ name = "a test plan", image = "somewhere.png",
                            half_width = 16, half_height = 8, layer_pixels = 10,
                            origin_x = 7, origin_y = 11 })
    -- A four by four square at elevation 5, with a two by two block on it at 9,
    -- and a separate square further out.
    plan.structures = {
      { z = 5, tag = "top",   points = { {0,0}, {4,0}, {4,4}, {0,4} } },
      { z = 9, tag = "top",   points = { {1,1}, {3,1}, {3,3}, {1,3} } },
      { z = 2, tag = "stair", points = { {6,0}, {8,0}, {8,2}, {6,2} } },
    }

    local path = scratch(root, "round-trip.plan")
    Plan.write(path, plan)
    local back = Plan.read(path)

    t.equal(back.name, plan.name, "a plan's name came back")
    t.equal(back.half_width, plan.half_width, "and its projection")
    t.equal(back.origin_x, plan.origin_x, "and its origin")
    t.equal(#back.structures, 3, "and all three structures")
    t.equal(back.structures[3].tag, "stair", "and the tag on the third of them")
    t.equal(#back.structures[1].points, 4, "and the corners of the first")
    os.remove(path)

    -- The extent is what was traced and not one cell more. The shapes run from
    -- x = 0 to x = 8 and y = 0 to y = 4, so that is the world.
    local field = Plan.rasterise(back)
    t.equal(field.min_x, 0, "the world starts where the trace does, in x")
    t.equal(field.min_y, 0, "and in y")
    t.equal(field.width, 8, "and is as wide as the trace")
    t.equal(field.depth, 4, "and as deep")

    -- Where the block overlaps the plaza, the higher wins.
    t.equal(field.height[1 + 1 * 8], 9, "the block on the plaza is the block")
    t.equal(field.height[0 + 0 * 8], 5, "and the plaza beside it is the plaza")
    t.equal(field.height[6 + 0 * 8], 2, "and the separate square is itself")

    -- The gap between the two squares was never traced, so it is a hole, and it
    -- is counted rather than filled with a guess.
    t.equal(field.height[5 + 0 * 8], back.base, "the gap is left at the base")
    -- Twelve, not eight. The column between the two squares is eight cells, and
    -- the small square is only two rows deep against the plaza's four, so the two
    -- rows under it are holes as well. Worth spelling out because the first
    -- expectation written here was eight, and a rasteriser that agreed with it
    -- would have been the one that was wrong.
    t.equal(field.uncovered, 12, "and the twelve cells around them are holes")

    -- Order does not matter. The same shapes written the other way round give the
    -- same world, which is the property that lets somebody add a structure
    -- without working out where in the list it belongs.
    local shuffled = Plan.read and { }
    local other = Plan.new({ name = back.name, image = back.image,
                             half_width = back.half_width,
                             half_height = back.half_height,
                             layer_pixels = back.layer_pixels,
                             origin_x = back.origin_x, origin_y = back.origin_y })
    other.structures = { back.structures[2], back.structures[3], back.structures[1] }
    local again = Plan.rasterise(other)
    local differ = 0
    for i = 0, field.width * field.depth - 1 do
      if field.height[i] ~= again.height[i] then differ = differ + 1 end
    end
    t.equal(differ, 0, "the order the structures were written in changes nothing")
  end

  -- A shape with a hole traced into it. Even-odd handles this without anybody
  -- having to say that holes exist, and a traced painting is full of them: a
  -- plaza with a block standing in the middle is exactly this.
  do
    local plan = Plan.new({ name = "holed", image = "i.png",
                            half_width = 16, half_height = 8, layer_pixels = 10,
                            origin_x = 0, origin_y = 0 })
    -- A five by five ring: out around the outside, in along a seam, round the
    -- hole, and back out the same seam.
    plan.structures = { { z = 3, tag = "top", points = {
      {0,0}, {5,0}, {5,5}, {0,5}, {0,2}, {2,2}, {2,3}, {0,3},
    } } }
    local field = Plan.rasterise(plan)
    t.equal(field.width, 5, "the ring is five across")
    t.equal(field.height[0 + 0 * 5], 3, "its wall is covered")
    t.equal(field.uncovered, 2, "and the two cells of the hole are not")
  end

  -- What the readers refuse. Every one of these is a file somebody edited by
  -- hand, and a format that loads a broken one with a plausible substitute is a
  -- simulation running on a world nobody described.
  do
    local path = scratch(root, "broken.scene")

    local function refuses(text, what)
      local f = io.open(path, "w")
      f:write(text)
      f:close()
      t.raises(function() SceneFile.read(path) end, what)
    end

    refuses("scene a\nimage b.png\nsize 2 2\nprojection 16 8 10\norigin 0 0\n",
            "a scene with no height field is refused")
    refuses("scene a\nimage b.png\nsize 2 2\nprojection 16 8 10\norigin 0 0\n" ..
            "spawn 0 0 0\nheight\n1 2\n",
            "a scene with too few rows is refused")
    refuses("scene a\nimage b.png\nsize 2 2\nprojection 16 8 10\norigin 0 0\n" ..
            "spawn 0 0 0\nheight\n1 2 3\n1 2\n",
            "a scene with a row of the wrong length is refused")
    refuses("scene a\nimage b.png\nsize 2 2\nprojection 16 0 10\norigin 0 0\n" ..
            "spawn 0 0 0\nheight\n1 2\n3 4\n",
            "a scene whose projection has a zero in it is refused")
    refuses("scene a\nimage b.png\nsize 2 2\nprojection 16 8 10\norigin 0 0\n" ..
            "spawn 0 0 0\nwobble 3\nheight\n1 2\n3 4\n",
            "a scene saying something nobody has heard of is refused")
    os.remove(path)

    local plan_path = scratch(root, "broken.plan")
    local f = io.open(plan_path, "w")
    f:write("plan p\nimage i.png\nprojection 16 8 10\norigin 0 0\n" ..
            "structure 4 top\n  0 0\n  1 0\n")
    f:close()
    t.raises(function() Plan.read(plan_path) end,
             "a structure of two points, which encloses nothing, is refused")
    os.remove(plan_path)
  end
end
-- }}}

return M
