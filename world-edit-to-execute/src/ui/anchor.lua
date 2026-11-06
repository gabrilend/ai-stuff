--[[
anchor.lua - interface elements placed by anchors, resolved to screen rectangles (issue 506b)

In plain terms: an element says where it sits relative to another one,
as WC3's frames do (FDF's SetPoint): "my BOTTOMLEFT at the screen's
BOTTOMLEFT, 6 across and 184 up", with a size, or with two points
(left and right edges) so that it stretches. When the window changes
size, every element is worked out once into a rectangle in pixels; in
between, the same rectangles are handed out.

Units. Offsets and sizes are in the 4:3 area's own units: 960 across and
720 down (WC3's 0.8 by 0.6, times 1200; `anchor.WC3`), y downward. The
4:3 area ("ui") is the window's full height and 4/3 of it across,
centred (on a window narrower than 4:3, the whole window); the whole
window is "screen". So an element anchored to "ui" keeps WC3's 4:3 place
at any width, and one pinned to both sides of "screen" stretches across
a wide window. One unit is `scale` pixels: min(width / 960, height /
720).

    local anchor = require("ui.anchor")
    local frames = {
        { id = "bar", to = "screen", h = 192,
          points = { { "BOTTOMLEFT", "BOTTOMLEFT" }, { "BOTTOMRIGHT", "BOTTOMRIGHT" } } },
        { id = "map", w = 176, h = 176, points = { { "TOPLEFT", "BOTTOMLEFT", 38, -184 } } },
    }
    local rects = anchor.resolve(frames, 1920, 1080)   -- rects.map = { x, y, w, h }
    local cached = anchor.cache(frames)
    cached:get(1920, 1080)          -- worked out once per size

A frame: `id`, `to` (the frame its points refer to unless a point names
another; default "ui"), `w`, `h` (units), and `points`, each
`{ point, relative_point, x, y, to }` (x, y default 0; `to` defaults to
the frame's). The nine points are TOPLEFT, TOP, TOPRIGHT, LEFT, CENTER,
RIGHT, BOTTOMLEFT, BOTTOM, BOTTOMRIGHT. Along each axis, two points at
different places (a left and a right one) set both edges; one point and
the size set the place. Rectangles come out in whole pixels, each edge
rounded on its own, so neighbours meet without gaps.
]]

local anchor = {}

anchor.UI_W, anchor.UI_H = 960, 720
anchor.WC3 = 1200                       -- units per WC3 screen unit (0.8 x 0.6)

-- {{{ points
anchor.POINTS = {
    TOPLEFT = { 0, 0 }, TOP = { 0.5, 0 }, TOPRIGHT = { 1, 0 },
    LEFT = { 0, 0.5 }, CENTER = { 0.5, 0.5 }, RIGHT = { 1, 0.5 },
    BOTTOMLEFT = { 0, 1 }, BOTTOM = { 0.5, 1 }, BOTTOMRIGHT = { 1, 1 },
}
-- }}}

-- {{{ anchor.roots
-- The two rectangles everything hangs from, in pixels, and the scale. The
-- 4:3 area always has the window's full height, so what hangs from its top
-- and bottom meets the bars at the window's edges; on a window narrower
-- than 4:3 it is the window, and the room left over is between them.
function anchor.roots(w, h)
    local s = math.min(w / anchor.UI_W, h / anchor.UI_H)
    local uw = anchor.UI_W * s
    return { screen = { x = 0, y = 0, w = w, h = h },
             ui = { x = (w - uw) / 2, y = 0, w = uw, h = h } }, s
end
-- }}}

-- {{{ one axis
-- The constraints on one axis: { frac (0, .5, 1 of the frame), at (pixels) }.
-- Returns the low edge and the length, or nil and why.
local function solve(cons, size, s, id, axis)
    if #cons == 0 then return nil, id .. " has no point on its " .. axis .. " axis" end
    local a = cons[1]
    for i = 2, #cons do
        local b = cons[i]
        if b.frac ~= a.frac then
            if a.frac > b.frac then a, b = b, a end
            local len = (b.at - a.at) / (b.frac - a.frac)
            if len < 0 then return nil, id .. "'s points cross on its " .. axis .. " axis" end
            return a.at - a.frac * len, len
        end
    end
    if not size then return nil, id .. " needs a " .. (axis == "x" and "w" or "h") .. " or a second point" end
    local len = size * s
    return a.at - a.frac * len, len
end
-- }}}

-- {{{ anchor.resolve
-- Every frame's rectangle in pixels for a window of w x h, or nil and why.
function anchor.resolve(frames, w, h)
    local roots, s = anchor.roots(w, h)
    local by_id, raw, out = {}, {}, {}
    for _, f in ipairs(frames) do
        if not f.id or roots[f.id] then return nil, "a frame needs an id other than screen or ui" end
        if by_id[f.id] then return nil, "two frames are called " .. f.id end
        by_id[f.id] = f
    end
    for k, v in pairs(roots) do raw[k] = v end
    local busy = {}
    local function place(id)
        if raw[id] then return raw[id] end
        local f = by_id[id]
        if not f then return nil, "no frame " .. tostring(id) end
        if busy[id] then return nil, "frames anchored in a circle at " .. id end
        busy[id] = true
        local xs, ys = {}, {}
        for _, p in ipairs(f.points or {}) do
            local mine, theirs = anchor.POINTS[p[1]], anchor.POINTS[p[2] or p[1]]
            if not mine or not theirs then return nil, id .. ": no point " .. tostring(not mine and p[1] or p[2]) end
            local rel, why = place(p.to or f.to or "ui")
            if not rel then return nil, why end
            xs[#xs + 1] = { frac = mine[1], at = rel.x + theirs[1] * rel.w + (p[3] or 0) * s }
            ys[#ys + 1] = { frac = mine[2], at = rel.y + theirs[2] * rel.h + (p[4] or 0) * s }
        end
        local x, fw = solve(xs, f.w, s, id, "x")
        if not x then return nil, fw end
        local y, fh = solve(ys, f.h, s, id, "y")
        if not y then return nil, fh end
        busy[id] = nil
        raw[id] = { x = x, y = y, w = fw, h = fh }
        return raw[id]
    end
    local function round(v) return math.floor(v + 0.5) end
    for _, f in ipairs(frames) do
        local r, why = place(f.id)
        if not r then return nil, why end
        local x0, y0 = round(r.x), round(r.y)
        out[f.id] = { x = x0, y = y0, w = round(r.x + r.w) - x0, h = round(r.y + r.h) - y0 }
    end
    return out, s, roots
end
-- }}}

-- {{{ anchor.cache
-- The frames worked out once per window size: `:get(w, h)` returns the
-- rectangles (and the scale), computing them only when the size changed;
-- `.computed` counts how often it did.
function anchor.cache(frames)
    local c = { computed = 0 }
    function c:get(w, h)
        if self.w ~= w or self.h ~= h or not self.rects then
            local rects, s, roots = anchor.resolve(frames, w, h)
            if not rects then return nil, s end
            self.rects, self.scale, self.roots, self.w, self.h = rects, s, roots, w, h
            self.computed = self.computed + 1
        end
        return self.rects, self.scale, self.roots
    end
    return c
end
-- }}}

return anchor
