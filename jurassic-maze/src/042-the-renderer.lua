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

-- 042-the-renderer.lua
--
-- One linear sweep that turns disagreements between columns into polygons.
--
-- The renderer never draws a block. A block is a set bit and a face is a
-- disagreement between two neighbouring columns, and neither is ever allocated.
-- The other two sides of every block and its underside face away from the
-- viewer and are never considered -- two thirds of the geometry gone for free,
-- which is the whole benefit of a fixed camera angle.

local M = {}

M.FACE_TOP   = 1
M.FACE_LEFT  = 2
M.FACE_RIGHT = 3

-- Which of a face's four sides needs a line drawn along it. Reused across every
-- emit rather than made fresh, because the sweep touches every column in the
-- maze and a table per face is a hundred thousand tables per build.
M.EDGE_SCRATCH = { false, false, false, false }

-- {{{ function M.sweep(Stone, store, minx, miny, maxx, maxy, emit)
-- Every visible face in a rectangle of columns, back to front.
--
-- Back to front is `for y ascending, for x ascending`, and the column index is
-- x + y * width, so this sweep is a linear walk of the array from its first
-- element to its last, in the direction the prefetcher is already going. That is
-- not a coincidence noticed afterwards and enjoyed -- it is why the index is
-- that way round rather than the other. See docs/006-the-isometric-projection.md.
--
-- Pure. It knows nothing about the engine, which is what lets a mesh builder, an
-- immediate-mode drawer and a face counter all be the same sweep.
function M.sweep(Stone, store, minx, miny, maxx, maxy, emit)
  for y = miny, maxy do
    for x = minx, maxx do
      M.sweep_cell(Stone, store, x, y, x + y, emit)
    end
  end
end
-- }}}

-- {{{ function M.sweep_cell(Stone, store, x, y, band, emit)
-- Every visible face of one column. Both sweep orders call this, so there is one
-- place that decides what a column contributes and two that decide when.
function M.sweep_cell(Stone, store, x, y, band, emit)
  local bit = require("bit")
  local column, surfaces = store.column, store.surfaces
  local width, depth, layers = store.width, store.depth, store.layers
  local edges = M.EDGE_SCRATCH

  local i = x + y * width
  local col = column[i]
  if col == 0 then return end

  -- {{{ local function column_at(cx, cy)
  local function column_at(cx, cy)
    if cx < 0 or cy < 0 or cx >= width or cy >= depth then return 0 end
    return column[cx + cy * width]
  end
  -- }}}

  -- {{{ local function surfaces_at(cx, cy)
  local function surfaces_at(cx, cy)
    if cx < 0 or cy < 0 or cx >= width or cy >= depth then return 0 end
    return surfaces[cx + cy * width]
  end
  -- }}}

  -- The neighbour toward +x is drawn down and to the right on screen; the
  -- neighbour toward +y is drawn down and to the left. Those are the two faces
  -- the viewer can see. Off the edge of the array counts as air, so the outside
  -- of the maze gets its faces drawn.
  local right_col = column_at(x + 1, y)
  local left_col  = column_at(x,     y + 1)

  -- The exposed part of a side is the run this column has that its neighbour
  -- does not. Two identical columns side by side give zero here and draw nothing
  -- at all, which is why a large solid terrace costs its outline rather than its
  -- area.
  local exposed_right = bit.band(col, bit.bnot(right_col))
  local exposed_left  = bit.band(col, bit.bnot(left_col))

  if exposed_right ~= 0 then
    -- The two neighbours whose right faces sit in this same plane. Where their
    -- exposure matches ours over a run, the wall is continuous through it and
    -- there is no edge to draw.
    local near = bit.band(column_at(x, y - 1), bit.bnot(column_at(x + 1, y - 1)))
    local far  = bit.band(column_at(x, y + 1), bit.bnot(column_at(x + 1, y + 1)))
    local l = 0
    while l < layers do
      if bit.band(exposed_right, bit.lshift(1, l)) ~= 0 then
        local bottom = l
        while l < layers and bit.band(exposed_right, bit.lshift(1, l)) ~= 0 do
          l = l + 1
        end
        local mask = bit.lshift(1, l) - bit.lshift(1, bottom)
        edges[1] = true                            -- the top of the wall
        edges[2] = bit.band(far,  mask) ~= mask    -- toward y+1
        edges[3] = true                            -- where it meets ground
        edges[4] = bit.band(near, mask) ~= mask    -- toward y-1
        emit(M.FACE_RIGHT, i, x, y, bottom, l, edges, band)
      else
        l = l + 1
      end
    end
  end

  if exposed_left ~= 0 then
    local near = bit.band(column_at(x - 1, y), bit.bnot(column_at(x - 1, y + 1)))
    local far  = bit.band(column_at(x + 1, y), bit.bnot(column_at(x + 1, y + 1)))
    local l = 0
    while l < layers do
      if bit.band(exposed_left, bit.lshift(1, l)) ~= 0 then
        local bottom = l
        while l < layers and bit.band(exposed_left, bit.lshift(1, l)) ~= 0 do
          l = l + 1
        end
        local mask = bit.lshift(1, l) - bit.lshift(1, bottom)
        edges[1] = true
        edges[2] = bit.band(far,  mask) ~= mask    -- toward x+1
        edges[3] = true
        edges[4] = bit.band(near, mask) ~= mask    -- toward x-1
        emit(M.FACE_LEFT, i, x, y, bottom, l, edges, band)
      else
        l = l + 1
      end
    end
  end

  local s = surfaces[i]
  if s ~= 0 then
    for l = 0, layers - 1 do
      local b = bit.lshift(1, l)
      if bit.band(s, b) ~= 0 then
        -- A top face's four sides border the four cells around it. Where a
        -- neighbour's floor is at exactly this layer the two tops are one
        -- continuous surface, and drawing a line between them is what turns a
        -- long wall into a row of separate cubes.
        edges[1] = bit.band(surfaces_at(x,     y - 1), b) == 0
        edges[2] = bit.band(surfaces_at(x + 1, y    ), b) == 0
        edges[3] = bit.band(surfaces_at(x,     y + 1), b) == 0
        edges[4] = bit.band(surfaces_at(x - 1, y    ), b) == 0
        emit(M.FACE_TOP, i, x, y, l + 1, l + 1, edges, band)
      end
    end
  end
end
-- }}}

-- {{{ function M.sweep_by_diagonal(Stone, store, emit)
-- The same faces as M.sweep, grouped into the bands the painter's algorithm
-- actually cares about.
--
-- Everything nearer the viewer has a larger `x + y`, so cells sharing a value of
-- `x + y` lie on one band across the screen and none of them can occlude any
-- other -- their diamonds sit side by side and exactly touch. Two orders are
-- therefore both correct: row by row, which is the array's own memory order, and
-- band by band, which is this.
--
-- Memory order is used by the pure sweep. This one exists because **bodies have
-- to be drawn between the bands**. The stone is one static mesh, and a mesh drawn
-- in one call is drawn all at once -- so a ball would sit on top of every wall in
-- the maze, including the ones in front of it. Grouping the faces by band lets
-- the mesh be drawn a band at a time with the bodies of that band in between.
--
-- `emit` is called as for M.sweep, plus the band index, and bands arrive in
-- ascending order.
function M.sweep_by_diagonal(Stone, store, emit)
  local width, depth = store.width, store.depth
  for band = 0, width + depth - 2 do
    local x0 = band - (depth - 1)
    if x0 < 0 then x0 = 0 end
    local x1 = band
    if x1 > width - 1 then x1 = width - 1 end
    for x = x0, x1 do
      M.sweep_cell(Stone, store, x, band - x, band, emit)
    end
  end
end
-- }}}

-- {{{ function M.corners(Projection, flat, face, x, y, low, high, out)
-- The four screen points of one face, at scale one and no pan.
--
-- A block at layer L spans heights L to L+1, so the top of the pile is at the
-- height of its highest layer plus one. Getting that off by one puts every top
-- face one layer down inside its own block, which looks like nothing at all
-- because the block below it is exactly the same colour.
function M.corners(Projection, flat, face, x, y, low, high, out)
  local function at(cx, cy, h)
    return Projection.to_screen(flat, cx, cy, h)
  end

  if face == M.FACE_TOP then
    -- A diamond: top, right, bottom, left.
    out[1], out[2]   = at(x,     y,     high)
    out[3], out[4]   = at(x + 1, y,     high)
    out[5], out[6]   = at(x + 1, y + 1, high)
    out[7], out[8]   = at(x,     y + 1, high)
  elseif face == M.FACE_RIGHT then
    -- The plane at x+1, seen from the lower right.
    out[1], out[2]   = at(x + 1, y,     high)
    out[3], out[4]   = at(x + 1, y + 1, high)
    out[5], out[6]   = at(x + 1, y + 1, low)
    out[7], out[8]   = at(x + 1, y,     low)
  else
    -- The plane at y+1, seen from the lower left.
    out[1], out[2]   = at(x,     y + 1, high)
    out[3], out[4]   = at(x + 1, y + 1, high)
    out[5], out[6]   = at(x + 1, y + 1, low)
    out[7], out[8]   = at(x,     y + 1, low)
  end
  return out
end
-- }}}

-- {{{ local function inset(pts, amount, edges)
-- Pulls in only the sides of a quad that are real edges of the geometry.
--
-- This is the entire outlining scheme. The faces tile without gaps, so a mesh of
-- full-size faces in the outline colour is completely hidden by a mesh of inset
-- faces drawn on top -- except along whichever sides were pulled in, where the
-- gap exposes a line of it. Two draw calls for the whole maze's linework, and no
-- second sweep over anything.
--
-- Insetting all four sides was the first version and it is what a naive reading
-- of "outline every face" gives you. It draws a line between every pair of
-- neighbouring cells, including two cells of one long wall whose tops are the
-- same continuous slab of stone -- and the maze stops reading as corridors
-- between walls and starts reading as a field of separate cubes. The reference
-- picture has linework everywhere and none of it is that line.
--
-- The offsets are summed at the corners rather than intersected properly. Every
-- angle here is ninety degrees or the isometric's sixty, and the inset is under
-- a pixel, so the error is smaller than the thing being drawn.
local function inset(pts, amount, edges)
  local cx = (pts[1] + pts[3] + pts[5] + pts[7]) * 0.25
  local cy = (pts[2] + pts[4] + pts[6] + pts[8]) * 0.25

  local nx, ny = {}, {}
  for e = 1, 4 do
    if edges[e] then
      local a = (e - 1) * 2 + 1
      local b = (e % 4) * 2 + 1
      local ex, ey = pts[b] - pts[a], pts[b + 1] - pts[a + 1]
      local px, py = -ey, ex
      local len = math.sqrt(px * px + py * py)
      if len > 0 then px, py = px / len, py / len end
      -- Point it at the middle of the quad rather than assuming a winding.
      local mx, my = (pts[a] + pts[b]) * 0.5, (pts[a + 1] + pts[b + 1]) * 0.5
      if px * (cx - mx) + py * (cy - my) < 0 then px, py = -px, -py end
      nx[e], ny[e] = px * amount, py * amount
    else
      nx[e], ny[e] = 0, 0
    end
  end

  -- Corner k is shared by edge k-1 and edge k.
  local moved = {}
  for k = 1, 4 do
    local prev = ((k - 2) % 4) + 1
    moved[(k - 1) * 2 + 1] = pts[(k - 1) * 2 + 1] + nx[prev] + nx[k]
    moved[(k - 1) * 2 + 2] = pts[(k - 1) * 2 + 2] + ny[prev] + ny[k]
  end
  for k = 1, 8 do pts[k] = moved[k] end
  return pts
end
-- }}}

-- {{{ function M.build(Stone, Projection, Palette, store, love_graphics)
-- Bakes the whole maze into two meshes: the outline underneath, the faces on
-- top, inset by a hair so the outline shows through along every seam.
--
-- The stone does not change, so this runs once. Rebuilding it per frame would
-- be a hundred thousand polygons of work to produce a picture identical to the
-- last one -- and a renderer that allocates per frame is a renderer that
-- stutters every time the collector notices, correlated with nothing.
--
-- When a golem starts breaking walls in phase seven, this is rebuilt on the
-- store's version counter rather than every frame.
function M.build(Stone, Projection, Palette, store, love_graphics)
  local flat = { pan_x = 0, pan_y = 0, scale = 1 }
  local pts  = {}

  local fill_v, outline_v = {}, {}
  local fill_i, outline_i = {}, {}
  local nverts = 0
  local faces  = 0

  -- Mossiness is a property of floor, never of a wall top. In the reference
  -- picture the greenery is in the walked places; putting it on the wall tops as
  -- well flattens everything into one texture and the moss stops marking
  -- anything.
  local walkable = store.walkable

  local function emit(face, cell, x, y, low, high, edges)
    M.corners(Projection, flat, face, x, y, low, high, pts)

    local r, g, b
    if face == M.FACE_TOP then
      local moss = (walkable and walkable[cell]) and 0.55 or 0.0
      r, g, b = Palette.mossy_top(cell, high - 1, store.layers, moss)
    else
      local f = (face == M.FACE_LEFT) and Palette.LEFT or Palette.RIGHT
      r, g, b = Palette.stone(cell, high - 1, store.layers, f)
    end

    local base = nverts
    for k = 1, 7, 2 do
      outline_v[#outline_v + 1] = {
        pts[k], pts[k + 1], 0, 0,
        Palette.OUTLINE[1], Palette.OUTLINE[2], Palette.OUTLINE[3], 1 }
    end

    inset(pts, 0.85, edges)
    for k = 1, 7, 2 do
      fill_v[#fill_v + 1] = { pts[k], pts[k + 1], 0, 0, r, g, b, 1 }
    end

    -- Two triangles per quad, sharing the diagonal.
    local n = #fill_i
    fill_i[n + 1] = base + 1; fill_i[n + 2] = base + 2; fill_i[n + 3] = base + 3
    fill_i[n + 4] = base + 1; fill_i[n + 5] = base + 3; fill_i[n + 6] = base + 4
    outline_i[n + 1] = base + 1; outline_i[n + 2] = base + 2; outline_i[n + 3] = base + 3
    outline_i[n + 4] = base + 1; outline_i[n + 5] = base + 3; outline_i[n + 6] = base + 4

    nverts = nverts + 4
    faces = faces + 1
  end

  -- Built band by band, and the index range of each band recorded, so the mesh
  -- can be drawn a band at a time with bodies in between. A mesh drawn in one
  -- call is drawn all at once, and a ball drawn after it would sit on top of
  -- every wall in the maze including the ones in front of it.
  local bands = {}
  local last_band = -1
  M.sweep_by_diagonal(Stone, store, function(face, cell, x, y, low, high, edges, band)
    if band ~= last_band then
      -- Bands with no faces at all are simply absent, and the draw loop skips
      -- them. A band is empty only outside the maze's footprint, but that is two
      -- hundred and fifty-eight of them on a square maze seen corner-on.
      bands[band] = { first = #fill_i + 1, count = 0 }
      last_band = band
    end
    local before = #fill_i
    emit(face, cell, x, y, low, high, edges)
    bands[band].count = bands[band].count + (#fill_i - before)
  end)

  local outline_mesh = love_graphics.newMesh(outline_v, "triangles", "static")
  outline_mesh:setVertexMap(outline_i)
  local fill_mesh = love_graphics.newMesh(fill_v, "triangles", "static")
  fill_mesh:setVertexMap(fill_i)

  return {
    outline  = outline_mesh,
    fill     = fill_mesh,
    bands    = bands,
    max_band = store.width + store.depth - 2,
    faces    = faces,
    vertices = nverts,
    version  = store.version,
  }
end
-- }}}

-- {{{ function M.bake_sprites(Baker, love_image, love_graphics)
-- Turns the baker's bytes into textures, once.
--
-- The whole of the drawing lives here and the whole of the *deciding* lives in
-- 075-the-sprite-baker.lua, which has never heard of a texture. That split is why
-- there is a test for what a ball looks like: the shape and the shading are a
-- string of bytes a headless run can produce and a test can read, and this
-- function is the four lines that hand them to the engine.
--
-- Nearest-neighbour is deliberately not used. The sprite is baked large and drawn
-- small, so the filtering is doing real work -- a ball is six pixels across at
-- scale one, and a forty-eight pixel sprite reduced to six by point sampling
-- throws away fifteen of every sixteen pixels of the antialiased edge that was
-- the reason for baking it.
function M.bake_sprites(Baker, love_image, love_graphics)
  local r = Baker.BAKE_RADIUS

  local function make(w, h, bytes)
    local data = love_image.newImageData(w, h, "rgba8", bytes)
    local image = love_graphics.newImage(data)
    image:setFilter("linear", "linear")
    return image
  end

  local bw, bh, bball = Baker.ball(r)
  local sw, sh, bshadow = Baker.shadow(r)

  return { ball = make(bw, bh, bball), shadow = make(sw, sh, bshadow), radius = r }
end
-- }}}

-- {{{ function M.bucket_bodies(store, bodies, into)
-- Groups the live bodies by which band they will be drawn in.
--
-- Reuses the arrays it is given rather than making new ones, because this runs
-- every frame and a renderer that allocates per frame stutters every time the
-- collector notices, correlated with nothing anybody can see.
function M.bucket_bodies(store, bodies, into)
  for band = 0, into.max_band do
    local list = into[band]
    if list then list.n = 0 end
  end

  for id = 1, bodies.capacity do
    if bodies.alive[id] == 1 then
      local cell = bodies.cell[id]
      local x = cell % store.width
      local y = (cell - x) / store.width
      local band = x + y
      local list = into[band]
      if not list then list = { n = 0 }; into[band] = list end
      list.n = list.n + 1
      list[list.n] = id
    end
  end
end
-- }}}

-- {{{ function M.draw_body(Projection, Palette, flat, store, bodies, creatures, id, walking, love_graphics)
-- One body, at scale one and no pan, so the camera transform already applied to
-- the stone covers it too.
--
-- A shadow first, on the floor beneath. Without one a ball reads as floating at
-- an indeterminate height -- there is no perspective in an isometric projection
-- to say how far away the ground is, so the only cue that a thing is *on* a
-- surface is a mark on that surface.
function M.draw_body(Projection, Palette, flat, store, bodies, creatures, id,
                     walking, love_graphics, rider_position, sprites)
  local kind = creatures.KINDS[bodies.kind[id]]
  local r = bodies.radius[id]

  local x, y, z
  if kind.locomotion == creatures.WALKING
     or kind.locomotion == creatures.STRIDING
     or kind.locomotion == creatures.LUMBERING
     or kind.locomotion == creatures.CREEPING then
    x, y, z = walking.drawn_position(store, bodies, id)
  else
    x, y, z = bodies.x[id], bodies.y[id], bodies.z[id]
  end

  -- A carried body's position is its mount's, derived. Nothing is stored for it,
  -- which is what stops the two drifting apart.
  if bodies.locomotion[id] == creatures.CARRIED and rider_position then
    x, y, z = rider_position(id)
  end

  local hw = Projection.HALF_WIDTH
  local hh = Projection.HALF_HEIGHT

  -- The shadow sits on the stone the body's stance says it is on, not at the
  -- body's own height -- which is the difference between a falling ball trailing
  -- its shadow downward and one whose shadow waits on the floor for it.
  local floor_z = bodies.layer[id] + 1
  local sx, sy = Projection.to_screen(flat, x, y, floor_z)
  love_graphics.setColor(0, 0, 0, 0.28)
  if sprites then
    -- Squashed to the projection's own ratio here rather than in the baker. The
    -- two-to-one is a property of how the world is drawn, and a shadow sprite
    -- baked oval would have to be rebaked the day that changes.
    local k = sprites.radius
    love_graphics.draw(sprites.shadow, sx, sy, 0,
                       r * hw * 1.05 / k, r * hh * 1.05 / k, k, k)
  else
    love_graphics.ellipse("fill", sx, sy, r * hw * 1.05, r * hh * 1.05)
  end

  local bx, by = Projection.to_screen(flat, x, y, z + r)
  local cr, cg, cb = Palette.creature(kind.name, bodies.team[id])

  -- Alight. Drawn over its own colour rather than instead of it, so that what is
  -- burning is still recognisable as what it was -- which matters when the thing
  -- most likely to be on fire is the machine that started the fire.
  if bodies.burning[id] and bodies.burning[id] > 0 then
    local flicker = 0.55 + 0.30 * math.sin(bodies.burning[id] * 21)
    cr = cr + (Palette.FIRE[1] - cr) * flicker
    cg = cg + (Palette.FIRE[2] - cg) * flicker
    cb = cb + (Palette.FIRE[3] - cb) * flicker
  end

  -- Held still by something. Drawn dimmer, because a body that is not moving and
  -- has not chosen not to move looks broken otherwise.
  if bodies.held[id] and bodies.held[id] > 0 then
    cr, cg, cb = cr * 0.55, cg * 0.55, cb * 0.62
  end

  love_graphics.setColor(cr, cg, cb, 1)

  if kind.locomotion ~= creatures.ROLLING then
    -- A standing body rather than a disc, so the kinds are told apart at a
    -- glance from two hundred cells away.
    local h = kind.body_height * Projection.LAYER_PIXELS * 1.15
    love_graphics.ellipse("fill", bx, by - h * 0.5, r * hw * 0.85, h * 0.5)
    love_graphics.setColor(cr * 0.55, cg * 0.55, cb * 0.55, 1)
    love_graphics.ellipse("line", bx, by - h * 0.5, r * hw * 0.85, h * 0.5)
  elseif sprites then
    -- The sprite carries brightness in all three channels and coverage in alpha,
    -- so setting the colour and drawing it is the whole of the tint. One sprite
    -- serves every kind and every team, and a team colour changing is a number
    -- rather than a sheet to rebake.
    local k = sprites.radius
    local scale = r * hw / k
    love_graphics.draw(sprites.ball, bx, by, 0, scale, scale, k, k)
  else
    love_graphics.circle("fill", bx, by, r * hw)
    -- A highlight where the light comes from, upper left, same as the stone.
    love_graphics.setColor(1, 1, 1, 0.30)
    love_graphics.circle("fill", bx - r * hw * 0.3, by - r * hw * 0.35, r * hw * 0.34)
    love_graphics.setColor(cr * 0.45, cg * 0.45, cb * 0.45, 1)
    love_graphics.circle("line", bx, by, r * hw)
  end
end
-- }}}

-- {{{ function M.count_faces(Stone, store)
-- How many faces the whole maze has, without building anything.
--
-- A number in the headless report. A face count that jumps when nothing visible
-- changed means the sweep or the culling broke, and it is the cheapest way to
-- notice.
function M.count_faces(Stone, store)
  local n = 0
  M.sweep(Stone, store, 0, 0, store.width - 1, store.depth - 1,
          function() n = n + 1 end)
  return n
end
-- }}}

return M
