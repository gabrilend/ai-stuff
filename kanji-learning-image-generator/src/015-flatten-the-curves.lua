-- 015-flatten-the-curves.lua
--
-- Turns curves into short straight lines, and measures what it made.
--
-- For a general: a stroke arrives as a handful of curves. Almost nothing wants
-- to work with a curve -- drawing one means asking where it is at a thousand
-- places, and measuring one means calculus. Chopping it into short straight
-- lines makes both trivial, and if the pieces are short enough nobody can tell
-- the difference.
--
-- The chopping is not uniform. A kanji stroke is usually a long straight run
-- with one tight bend in it, so cutting it into equal pieces either wastes
-- hundreds of points on the straight part or rounds the corner off. Instead
-- each curve is split in half repeatedly and each half stops splitting once it
-- is straight enough to be a line -- so the points end up where the bending is.
--
-- What comes out is not only points. The field wants to thin a stroke towards
-- its ends, and the arrows want to know which way a stroke leaves its
-- beginning, and the scene grammar wants to know how curved a stroke is. All
-- three are answered from the distance travelled along the line, so that is
-- measured here and carried alongside.

local M = {}

-- {{{ MAX_DEPTH -- how many times a curve may be halved
--
-- Sixteen halvings is sixty-five thousand pieces, which no stroke in a
-- 109-unit box will ever ask for. It is here because the flatness test can be
-- defeated by a curve that doubles back on itself exactly -- the two control
-- points sit on the chord, the test says "straight", and the curve is not. A
-- depth limit costs one comparison and removes the possibility of a program
-- that never returns.
local MAX_DEPTH = 16
-- }}}

-- {{{ split(x0, y0, x1, y1, x2, y2, x3, y3, tolerance, depth, xs, ys)
-- One curve, halved until each piece is straight, appending the far end of
-- every piece.
--
-- The flatness test is how far the two control points sit off the straight line
-- between the ends, measured as a cross product so no square root is needed.
-- The comparison is done squared, against the chord length squared, for the
-- same reason.
--
-- The starting point is never appended -- only endpoints. Whoever calls this
-- puts the first point in, and then every piece contributes exactly its own
-- end, so no point is stored twice and the arc length adds up.
local function split(x0, y0, x1, y1, x2, y2, x3, y3, tolerance, depth, xs, ys)
  local dx, dy = x3 - x0, y3 - y0
  local chord = dx * dx + dy * dy

  local flat
  if chord < 1e-12 then
    -- The two ends are in the same place, so there is no chord to measure
    -- against and the cross product would say everything is flat. A curve like
    -- this is a loop -- rare in handwriting and possible in a flourish -- and
    -- the honest measure is how far the controls stray from the point itself.
    local a = (x1 - x0) * (x1 - x0) + (y1 - y0) * (y1 - y0)
    local b = (x2 - x0) * (x2 - x0) + (y2 - y0) * (y2 - y0)
    flat = (a <= tolerance * tolerance) and (b <= tolerance * tolerance)
  else
    local first = (x1 - x0) * dy - (y1 - y0) * dx
    local second = (x2 - x0) * dy - (y2 - y0) * dx
    if first < 0 then first = -first end
    if second < 0 then second = -second end
    local off = first + second
    flat = (off * off) <= (tolerance * tolerance * chord)
  end

  if flat or depth >= MAX_DEPTH then
    xs[#xs + 1] = x3
    ys[#ys + 1] = y3
    return
  end

  -- de Casteljau at the middle: repeatedly average neighbouring points, and
  -- the two halves fall out of the intermediate averages.
  local ax, ay = (x0 + x1) * 0.5, (y0 + y1) * 0.5
  local bx, by = (x1 + x2) * 0.5, (y1 + y2) * 0.5
  local cx, cy = (x2 + x3) * 0.5, (y2 + y3) * 0.5
  local dx1, dy1 = (ax + bx) * 0.5, (ay + by) * 0.5
  local ex, ey = (bx + cx) * 0.5, (by + cy) * 0.5
  local mx, my = (dx1 + ex) * 0.5, (dy1 + ey) * 0.5

  split(x0, y0, ax, ay, dx1, dy1, mx, my, tolerance, depth + 1, xs, ys)
  split(mx, my, ex, ey, cx, cy, x3, y3, tolerance, depth + 1, xs, ys)
end
-- }}}

-- {{{ M.flatten(path, tolerance)
-- A parsed path, as points with distances along it.
--
-- Returns a table holding:
--   xs, ys    the points, in order
--   count     how many
--   at        distance from the start, at each point; at[1] is zero
--   travel    the whole distance along the line
--   span      the straight-line distance from the first point to the last
--   bbox      x0, y0, x1, y1
--
-- `travel / span` is the cheapest description of a stroke's shape there is:
-- one means straight, and well above one means it bends. `docs/004` uses it.
function M.flatten(path, tolerance)
  tolerance = tolerance or 0.05

  local xs, ys = { path.x }, { path.y }
  local x, y = path.x, path.y
  for _, curve in ipairs(path.curves) do
    split(x, y, curve[1], curve[2], curve[3], curve[4], curve[5], curve[6],
          tolerance, 0, xs, ys)
    x, y = curve[5], curve[6]
  end

  local count = #xs
  local at = { 0 }
  local travel = 0
  local x0, y0, x1, y1 = xs[1], ys[1], xs[1], ys[1]
  for index = 2, count do
    local step_x = xs[index] - xs[index - 1]
    local step_y = ys[index] - ys[index - 1]
    travel = travel + math.sqrt(step_x * step_x + step_y * step_y)
    at[index] = travel
    if xs[index] < x0 then x0 = xs[index] end
    if ys[index] < y0 then y0 = ys[index] end
    if xs[index] > x1 then x1 = xs[index] end
    if ys[index] > y1 then y1 = ys[index] end
  end

  local span_x = xs[count] - xs[1]
  local span_y = ys[count] - ys[1]

  return {
    xs = xs, ys = ys, count = count, at = at, travel = travel,
    span = math.sqrt(span_x * span_x + span_y * span_y),
    bbox = { x0, y0, x1, y1 },
  }
end
-- }}}

-- {{{ M.locate(flat, distance)
-- Where the line is, a given distance along it.
--
-- Returns x, y and the index of the point just before. Distances outside the
-- line are clamped to its ends rather than refused, because the callers ask for
-- "a little past the end" on purpose -- the arrow layer places a head beyond
-- the last point and the taper measures inward from both ends.
function M.locate(flat, distance)
  if distance <= 0 then return flat.xs[1], flat.ys[1], 1 end
  if distance >= flat.travel then
    return flat.xs[flat.count], flat.ys[flat.count], flat.count
  end
  -- Walking forward rather than searching. Every caller asks for distances in
  -- increasing order along the same stroke, so a search would repeatedly
  -- re-find the region it just left; and a stroke has tens of points, not
  -- thousands.
  local index = 1
  while index < flat.count and flat.at[index + 1] < distance do
    index = index + 1
  end
  local before = flat.at[index]
  local after = flat.at[index + 1]
  local width = after - before
  local part = (width > 0) and ((distance - before) / width) or 0
  return flat.xs[index] + (flat.xs[index + 1] - flat.xs[index]) * part,
         flat.ys[index] + (flat.ys[index + 1] - flat.ys[index]) * part,
         index
end
-- }}}

-- {{{ M.direction(flat, index)
-- Which way the line is going at one of its points, as a unit vector.
--
-- WHY NOT THE CHORD. The arrows in `206` need the direction a stroke *leaves*
-- its beginning, and for a stroke that bends, that is nothing like the
-- direction from its first point to its last. An arrow pointing at the far end
-- of a curving stroke points straight through the bend and teaches the wrong
-- exit.
--
-- Taken from the flattened line rather than from the curve's own derivative,
-- which would be the mathematically direct answer and has a case the flattened
-- version does not: a curve whose first control point sits exactly on its start
-- has a derivative of zero there and no direction at all. The first flattened
-- piece is always a real segment with a real direction.
function M.direction(flat, index)
  if index >= flat.count then index = flat.count - 1 end
  if index < 1 then index = 1 end
  local dx = flat.xs[index + 1] - flat.xs[index]
  local dy = flat.ys[index + 1] - flat.ys[index]
  local size = math.sqrt(dx * dx + dy * dy)
  -- Two identical points in a row would have no direction. Flattening only
  -- appends the far end of each piece, so a zero-length piece means the curve
  -- itself doubled back exactly, and the next piece is the one to ask.
  if size < 1e-9 then
    if index + 2 <= flat.count then return M.direction(flat, index + 1) end
    return 1, 0
  end
  return dx / size, dy / size
end
-- }}}

-- {{{ M.direction_at(flat, distance)
-- The same, at a distance along the line rather than at a point.
function M.direction_at(flat, distance)
  local _, _, index = M.locate(flat, distance)
  return M.direction(flat, index)
end
-- }}}

return M
