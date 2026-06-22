-- Higher-level drawing primitives wrapping libharu's raw page API.
-- Generators in compile-pdf-ai.lua call into these instead of touching
-- hpdf.* directly, which keeps generator code reading as composition
-- ("flowing_curve from here to there") rather than as bookkeeping
-- ("MoveTo, LineTo, LineTo, LineTo, Stroke").

local M = {}

-- hpdf is only touched inside the drawing functions below, which run on
-- the render path under lua5.2 with the libharu binding on package.cpath.
-- The taxonomy pipeline (themes-v2/name-clusters.lua) loads this module
-- transitively under luajit just to read generator metadata and never
-- draws — and that luajit has no hpdf binding. So resolve hpdf lazily:
-- module load must not depend on the binding being loadable. Each key
-- memoizes into the table on first access, so steady-state draws are
-- plain table reads, not metatable dispatches.
local hpdf = setmetatable({}, {__index = function(t, k)
    local real = require "hpdf"
    local v = real[k]; rawset(t, k, v); return v
end})

-- The PDF handle is needed for ExtGState creation (alpha and blend modes
-- are page-state objects that must be created from the parent document).
-- Caller initializes the module once at PDF creation time.
M._pdf = nil

-- {{{ M.init(pdf)
-- Store the active PDF document so with_alpha and with_blend_mode can
-- create ExtGState objects against it. Must be called before any alpha
-- or blend-mode work; calling other primitives without init is harmless.
function M.init(pdf)
    M._pdf = pdf
end
-- }}}

-- {{{ M.bezier(page, points)
-- Draws a sequence of cubic Bezier segments through a flat list of points.
-- Format: { x0, y0, c1x, c1y, c2x, c2y, x1, y1, c1x, c1y, c2x, c2y, x2, y2, ... }
-- Each segment uses two control points then an endpoint. The pen ends at
-- the last point; caller is responsible for Stroke/Fill afterwards.
function M.bezier(page, points)
    if #points < 8 then return end
    hpdf.Page_MoveTo(page, points[1], points[2])
    local i = 3
    while i + 5 <= #points do
        hpdf.Page_CurveTo(page,
            points[i], points[i+1],
            points[i+2], points[i+3],
            points[i+4], points[i+5])
        i = i + 6
    end
end
-- }}}

-- {{{ M.flowing_curve(page, from_x, from_y, to_x, to_y, sway)
-- Draws a single cubic Bezier from one point to another with control
-- points pushed perpendicular to the line by `sway` (positive = left of
-- travel direction, negative = right). Used for natural-looking links.
function M.flowing_curve(page, from_x, from_y, to_x, to_y, sway)
    local dx, dy = to_x - from_x, to_y - from_y
    local len = math.sqrt(dx*dx + dy*dy)
    if len == 0 then
        -- Degenerate endpoints (typical cause: a generator handed us a
        -- zero-area Tier 1 space and the random sway happened to roll 0).
        -- Emit a zero-length stub path so the caller's Page_Stroke still
        -- has something to stroke. Without this, Stroke would be invoked
        -- from PAGE_DESCRIPTION mode rather than PATH_OBJECT mode and
        -- libharu raises "Invalid Graphics mode" — fatal, kills the run.
        hpdf.Page_MoveTo(page, from_x, from_y)
        hpdf.Page_LineTo(page, from_x, from_y)
        return
    end
    -- Perpendicular unit vector, rotated 90° counter-clockwise from travel
    local px, py = -dy / len, dx / len
    -- Control points at 1/3 and 2/3 along the line, swayed perpendicular
    local c1x = from_x + dx / 3 + px * sway
    local c1y = from_y + dy / 3 + py * sway
    local c2x = from_x + 2 * dx / 3 + px * sway
    local c2y = from_y + 2 * dy / 3 + py * sway
    hpdf.Page_MoveTo(page, from_x, from_y)
    hpdf.Page_CurveTo(page, c1x, c1y, c2x, c2y, to_x, to_y)
end
-- }}}

-- {{{ M.arc(page, cx, cy, radius, start_deg, end_deg)
-- Wraps libharu's native Page_Arc. Angles in degrees, measured clockwise
-- from 12 o'clock (libharu's convention). Caller strokes/fills afterward.
function M.arc(page, cx, cy, radius, start_deg, end_deg)
    hpdf.Page_Arc(page, cx, cy, radius, start_deg, end_deg)
end
-- }}}

-- {{{ M.with_alpha(page, alpha, fn)
-- Apply alpha transparency to everything fn draws, then restore prior
-- state. Both fill and stroke get the same alpha — split into
-- with_alpha_fill / with_alpha_stroke if a generator wants asymmetric
-- transparency. Always reaches for Page_GSave/Page_GRestore so the
-- caller doesn't have to clean up.
function M.with_alpha(page, alpha, fn)
    if not M._pdf then
        error("art-primitives.with_alpha: M.init(pdf) was not called")
    end
    local gstate = hpdf.CreateExtGState(M._pdf)
    hpdf.ExtGState_SetAlphaFill(gstate, alpha)
    hpdf.ExtGState_SetAlphaStroke(gstate, alpha)
    hpdf.Page_GSave(page)
    hpdf.Page_SetExtGState(page, gstate)
    fn()
    hpdf.Page_GRestore(page)
end
-- }}}

-- {{{ M.with_blend_mode(page, mode, fn)
-- Same shape as with_alpha but for blend modes (multiply, screen, overlay,
-- etc.). Mode is a libharu HPDF_BMode_* constant. Use sparingly — blend
-- modes can interact unexpectedly with alpha.
function M.with_blend_mode(page, mode, fn)
    if not M._pdf then
        error("art-primitives.with_blend_mode: M.init(pdf) was not called")
    end
    local gstate = hpdf.CreateExtGState(M._pdf)
    hpdf.ExtGState_SetBlendMode(gstate, mode)
    hpdf.Page_GSave(page)
    hpdf.Page_SetExtGState(page, gstate)
    fn()
    hpdf.Page_GRestore(page)
end
-- }}}

-- {{{ M.axial_gradient(page, x1, y1, x2, y2, color_a, color_b, steps)
-- Simulates a linear gradient by drawing `steps` parallel strips from
-- color_a to color_b along the line (x1,y1)→(x2,y2). At 20 steps this
-- looks gradient-like at PDF resolution; at 50 it's indistinguishable
-- from a real gradient. Steps below ~10 show visible banding.
-- libharu's native HPDF_Shading_* family isn't currently bound in
-- libs/luahpdf/hpdf.c, so simulation is the working option until
-- those bindings get added (see Issue 018 stretch goal).
function M.axial_gradient(page, x1, y1, x2, y2, color_a, color_b, steps)
    steps = steps or 30
    local dx, dy = x2 - x1, y2 - y1
    local len = math.sqrt(dx*dx + dy*dy)
    if len == 0 then return end
    -- Perpendicular for strip width — strips are 1.5/step long to cover overlap
    local px, py = -dy / len, dx / len
    local strip_len = len * 1.5 / steps
    for i = 0, steps - 1 do
        local t = i / (steps - 1)
        local r = color_a[1] + (color_b[1] - color_a[1]) * t
        local g = color_a[2] + (color_b[2] - color_a[2]) * t
        local b = color_a[3] + (color_b[3] - color_a[3]) * t
        local mid_x = x1 + dx * t
        local mid_y = y1 + dy * t
        hpdf.Page_SetRGBStroke(page, r, g, b)
        hpdf.Page_SetLineWidth(page, len / steps + 1)
        hpdf.Page_MoveTo(page, mid_x + px * strip_len / 2, mid_y + py * strip_len / 2)
        hpdf.Page_LineTo(page, mid_x - px * strip_len / 2, mid_y - py * strip_len / 2)
        hpdf.Page_Stroke(page)
    end
end
-- }}}

-- {{{ M.radial_gradient(page, cx, cy, r_inner, r_outer, color_inner, color_outer, steps)
-- Simulates a radial gradient as concentric stroked circles, each one
-- with interpolated color. The inner circle is filled with color_inner
-- to handle the center region cleanly.
function M.radial_gradient(page, cx, cy, r_inner, r_outer, color_inner, color_outer, steps)
    steps = steps or 30
    -- Solid center to avoid a gap inside r_inner
    hpdf.Page_SetRGBFill(page, color_inner[1], color_inner[2], color_inner[3])
    hpdf.Page_Circle(page, cx, cy, r_inner)
    hpdf.Page_Fill(page)
    local width = (r_outer - r_inner) / steps + 1
    for i = 0, steps - 1 do
        local t = i / (steps - 1)
        local r = color_inner[1] + (color_outer[1] - color_inner[1]) * t
        local g = color_inner[2] + (color_outer[2] - color_inner[2]) * t
        local b = color_inner[3] + (color_outer[3] - color_inner[3]) * t
        local radius = r_inner + (r_outer - r_inner) * t
        hpdf.Page_SetRGBStroke(page, r, g, b)
        hpdf.Page_SetLineWidth(page, width)
        hpdf.Page_Circle(page, cx, cy, radius)
        hpdf.Page_Stroke(page)
    end
end
-- }}}

return M
