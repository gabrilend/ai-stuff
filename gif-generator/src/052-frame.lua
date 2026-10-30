-- 052-frame.lua - one frame, two spaces: the world, the panes of glass,
-- and the composer that lays them together.
--
-- What this is, generally: a two-space score (issue 701d) has shapes in a
-- 3D world and 2D strokes painted onto panes of glass. A pane is fully
-- clear; where a stroke is painted on it, its light adds brightness to
-- whatever is behind it. This module holds the three moves every such frame
-- makes:
--   * draw the world: the 3D painter fills its colour and depth (the same
--     moves, in the same order, the shape films have always made, so a
--     score with only shapes films byte-identical to the scene it came
--     from; 039-shape-films.lua draws its frames through here too);
--   * lay the world panes into that depth: each subpixel looks along its
--     ray, and where it meets a pane nearer than the surface drawn there,
--     the pane's light at that spot is gathered;
--   * compose: the gathered light, the back panes' light where nothing is
--     drawn, and the front panes' light are summed, tone-mapped once, and
--     added to the 3D colour; each pixel is then indexed once.
--
-- Decisions worth knowing more than once:
--   * the 3D painter's colour is already display colour (0..1, lit and
--     edged), not light energy, so it is not tone-mapped again: the light
--     from the panes is tone-mapped once, and added on top. With no light,
--     a pixel is exactly the 3D painter's pixel; with no shapes, exactly
--     the 2D painter's pixel. Both byte-identity promises rest on that.
--   * a pane is glass: it hides nothing, and nothing in front of it is
--     dimmed. A shape in front of a world pane hides the pane's light; a
--     shape behind it shows through, brightened where the pane is painted.
--   * a world pane holds the facing the score gives it (open question 3 of
--     issue 701d asks whether it should also be able to turn to the camera).
--
-- Data formats worth knowing more than once:
--   rc (the 3D canvas)  rgb float[W*W*3], depth float[W*W] (1/distance,
--                       0 = nothing drawn), W = size * SUPERSAMPLE
--   a pane's light      a 000-canvas (energy float[w*h*3], y downward)
--   gathered light      float[W*W*3], energy at the 3D canvas's resolution

local ffi = require("ffi")

local frame = {}

-- {{{ function frame.draw_world()
-- One moment of the 3D world into the painter's canvas. The painter and
-- the stage manager are handed in, so this file loads nothing.
-- Returns the placed shapes, for landmarks.
function frame.draw_world(rc, raster, choreography, scene, t)
    raster.clear(rc)
    raster.set_view(rc, choreography.camera(scene, t))
    raster.draw_stars(rc, choreography.stars(scene, t))
    local placed = choreography.pose(scene, t)
    -- Three kinds of shape: solids are drawn face by face; blobs are
    -- gathered and drawn together (they melt into each other), lit by
    -- the scene's point lights; a spine that only carries parts has
    -- nothing of its own to draw.
    local blobs = {}
    for _, item in ipairs(placed) do
        if item.blob then
            blobs[#blobs + 1] = item
        elseif not item.hidden then
            raster.draw_item(rc, item)
        end
    end
    raster.draw_blobs(rc, blobs, choreography.lights(scene, t, placed))
    -- lines of light: wind and rails, beams joining moving things, and
    -- speed streaks along the camera's heading
    for _, stroke in ipairs(choreography.strokes(scene, t)) do raster.draw_stroke(rc, stroke) end
    for _, beam in ipairs(choreography.beams(scene, t, placed)) do raster.draw_stroke(rc, beam) end
    for _, streak in ipairs(choreography.streaks(scene, t)) do raster.draw_stroke(rc, streak) end
    return placed
end
-- }}}

-- {{{ function frame.landmark()
-- Where the first placed shape bearing `tag` appears in the picture this
-- moment, in pixels of a `size`-wide frame (y downward). Behind the lens,
-- it is far off the picture, so a stroke following it paints nothing.
function frame.landmark(rc, raster, placed, tag, size)
    for _, item in ipairs(placed) do
        if item.tag == tag then
            local p = item.position
            local fx, fy, depth = raster.project_point(rc, p[1], p[2], p[3])
            if depth <= 0 then return -10 * size, -10 * size end
            return fx * size, fy * size
        end
    end
    return -10 * size, -10 * size
end
-- }}}

-- {{{ local function sub(), dot(), cross(), unit()
local function sub(a, b) return { a[1] - b[1], a[2] - b[2], a[3] - b[3] } end
local function dot(a, b) return a[1] * b[1] + a[2] * b[2] + a[3] * b[3] end
local function cross(a, b)
    return { a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1] }
end
local function unit(a)
    local len = math.sqrt(dot(a, a))
    return { a[1] / len, a[2] / len, a[3] / len }
end
-- }}}

-- {{{ function frame.pane_axes()
-- A world pane's own directions: `right` along its width and `up` along its
-- height, both lying in the pane, with the picture's top toward the world's
-- up. A pane lying flat (facing straight up or down) puts its top toward -z,
-- away from the still camera's viewer.
function frame.pane_axes(facing)
    local n = unit(facing)
    local up_ref = { 0, 1, 0 }
    if math.abs(n[2]) > 0.99 then up_ref = { 0, 0, -1 } end
    local right = unit(cross(up_ref, n))
    local up = cross(n, right)
    return n, right, up
end
-- }}}

-- {{{ function frame.gather_pane()
-- Lays one world pane into the 3D canvas's depth: every subpixel whose ray
-- meets the pane in front of what is drawn there (or where nothing is)
-- gathers the pane's light at that spot into `gathered`. `pane` carries
-- at, facing, size {w, h} in world units and its light canvas `cv`.
function frame.gather_pane(rc, raster, gathered, pane)
    local W, half, focal = rc.W, rc.W / 2, rc.focal
    local basis = raster.view_basis(rc)
    local eye, right_c, up_c, fwd = basis.eye, basis.right, basis.up, basis.forward
    local n, pr, pu = frame.pane_axes(pane.facing)
    local c = pane.at
    local pw, ph = pane.size[1], pane.size[2]
    local cv = pane.cv
    local cw, ch, energy = cv.width, cv.height, cv.energy
    local depth = rc.depth
    local near = raster.NEAR
    -- the plane's distance from the eye along its normal; a ray meets it
    -- at t = reach / (direction . n), at camera depth t
    local reach = dot(sub(c, eye), n)
    local ce = sub(c, eye)
    for y = 0, W - 1 do
        local v = (half - (y + 0.5)) / focal
        for x = 0, W - 1 do
            local u = ((x + 0.5) - half) / focal
            local dx = fwd[1] + right_c[1] * u + up_c[1] * v
            local dy = fwd[2] + right_c[2] * u + up_c[2] * v
            local dz = fwd[3] + right_c[3] * u + up_c[3] * v
            local along = dx * n[1] + dy * n[2] + dz * n[3]
            if along ~= 0 then
                local t = reach / along
                local i = y * W + x
                if t > near and (depth[i] == 0 or 1 / t >= depth[i]) then
                    -- the meeting point, measured from the pane's middle
                    local qx, qy, qz = dx * t - ce[1], dy * t - ce[2], dz * t - ce[3]
                    local a = qx * pr[1] + qy * pr[2] + qz * pr[3]
                    local b = qx * pu[1] + qy * pu[2] + qz * pu[3]
                    local px = math.floor((a / pw + 0.5) * cw)
                    local py = math.floor((0.5 - b / ph) * ch)
                    if px >= 0 and px < cw and py >= 0 and py < ch then
                        local s = (py * cw + px) * 3
                        local g = i * 3
                        gathered[g] = gathered[g] + energy[s]
                        gathered[g + 1] = gathered[g + 1] + energy[s + 1]
                        gathered[g + 2] = gathered[g + 2] + energy[s + 2]
                    end
                end
            end
        end
    end
end
-- }}}

-- {{{ function frame.compose()
-- The frame's pixels. Every input but `tm`, `out` and `index_of` may be nil:
--   rc        the 3D canvas (nil: no world; the ground is black)
--   gathered  world panes' light at the 3D canvas's resolution
--   back      back panes' and the background's light, size*size*3; shows
--             only where nothing in the world is drawn
--   front     front panes' light, size*size*3
--   tm        a 000-canvas the size of the frame, used to tone-map the sum
--   tonemap   000-canvas's tonemap
--   light_only  true: the world's depth still hides and shows the light,
--             but its colour is left out (the 2D half, for the phase 7 demo)
-- Light is summed, tone-mapped once, and added to the 3D colour; where the
-- sum is nothing, the pixel is the 3D painter's own (or black).
function frame.compose(spec)
    local rc, gathered, back, front = spec.rc, spec.gathered, spec.back, spec.front
    local tm, out, index_of = spec.tm, spec.out, spec.index_of
    local S = tm.width
    local light = tm.energy
    local ss = rc and rc.W / S or 1
    local W = rc and rc.W or S
    local quarter = 1 / (ss * ss)

    for y = 0, S - 1 do
        for x = 0, S - 1 do
            local p = (y * S + x) * 3
            local r, g, b = 0, 0, 0
            if front then r, g, b = front[p], front[p + 1], front[p + 2] end
            if gathered or (back and rc) then
                local gr, gg, gb, empty = 0, 0, 0, 0
                for dy = 0, ss - 1 do for dx = 0, ss - 1 do
                    local i = (y * ss + dy) * W + (x * ss + dx)
                    if gathered then
                        gr, gg, gb = gr + gathered[i * 3], gg + gathered[i * 3 + 1], gb + gathered[i * 3 + 2]
                    end
                    if rc.depth[i] == 0 then empty = empty + 1 end
                end end
                r, g, b = r + gr * quarter, g + gg * quarter, b + gb * quarter
                if back then
                    local share = empty * quarter
                    r, g, b = r + back[p] * share, g + back[p + 1] * share, b + back[p + 2] * share
                end
            elseif back then
                r, g, b = r + back[p], g + back[p + 1], b + back[p + 2]
            end
            light[p], light[p + 1], light[p + 2] = r, g, b
        end
    end
    local mapped = spec.tonemap(tm)

    local rgb = rc and rc.rgb
    local colour = rc and not spec.light_only
    for y = 0, S - 1 do
        for x = 0, S - 1 do
            local p = (y * S + x) * 3
            local lr, lg, lb = mapped[p], mapped[p + 1], mapped[p + 2]
            if colour then
                -- the 3D painter's own average, in its own order
                local r, g, b = 0, 0, 0
                for dy = 0, ss - 1 do for dx = 0, ss - 1 do
                    local i = ((y * ss + dy) * W + (x * ss + dx)) * 3
                    r, g, b = r + rgb[i], g + rgb[i + 1], b + rgb[i + 2]
                end end
                r, g, b = r * quarter, g * quarter, b * quarter
                if lr ~= 0 or lg ~= 0 or lb ~= 0 then
                    r, g, b = math.min(1, r + lr), math.min(1, g + lg), math.min(1, b + lb)
                end
                out[y * S + x] = index_of(r, g, b)
            else
                out[y * S + x] = index_of(lr, lg, lb)
            end
        end
    end
    return out
end
-- }}}

return frame
