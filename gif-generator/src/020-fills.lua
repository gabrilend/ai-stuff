-- 020-fills.lua — fill regions: fields of glow whose coverage grows.
--
-- What this is, generally: the vision says "fill the triangle,
-- slowly" — and a fill here is not a polygon rasterizer but a FIELD
-- EMITTER whose covered portion grows from nothing to everything.
-- Particles land uniformly inside the covered part, so the advancing
-- frontier glows and leaves settling light behind. One mechanism
-- serves triangles, any polygon, and the zero-thickness line (the
-- vision's fading seal-line is a two-vertex region).
--
-- Sweep styles — how coverage c in [0,1] shapes the covered part:
--   * "at-once"  : the whole region at any c above zero (a line or
--                  shape that fades in as one thing).
--   * "downward" : a horizontal frontier descends; covered is the
--                  part above it.
--   * "radial"   : a disc grows from the region's centroid.
--   * "along"    : two-vertex lines only — the line draws itself
--                  from its first vertex toward its second.
--
-- Sampling is proposal-shaped-by-coverage: propose points inside a
-- simple shape that ALREADY respects the frontier (a strip, a disc,
-- a prefix), then reject only on the polygon test. This keeps the
-- acceptance rate healthy at tiny coverage — naive rejection against
-- the whole bounding box starves exactly when the frontier is a
-- sliver, which is every fill's opening moment.

local emit = require("008-emit")

local fills = {}

-- Rejection cap: with coverage-shaped proposals the acceptance rate
-- stays near the polygon-in-box ratio (about half for sane shapes),
-- so hundreds of failures in a row means the region is degenerate —
-- an error to hear about, not ride past.
local MAX_TRIES = 400

-- {{{ local function point_in_polygon()
-- Even-odd ray cast, the classic: count edge crossings of a ray
-- running east from the point.
local function point_in_polygon(verts, x, y)
    local inside = false
    local n = #verts
    local j = n
    for i = 1, n do
        local xi, yi = verts[i][1], verts[i][2]
        local xj, yj = verts[j][1], verts[j][2]
        if ((yi > y) ~= (yj > y)) then
            local cross_x = (xj - xi) * (y - yi) / (yj - yi) + xi
            if x < cross_x then inside = not inside end
        end
        j = i
    end
    return inside
end
-- }}}

-- {{{ local function polygon_frame()
-- The facts every sweep needs, computed once at build time: bounds,
-- centroid, and the reach from the centroid to the farthest vertex.
local function polygon_frame(verts)
    local xmin, ymin, xmax, ymax = math.huge, math.huge, -math.huge, -math.huge
    local cx, cy = 0, 0
    for _, v in ipairs(verts) do
        if v[1] < xmin then xmin = v[1] end
        if v[1] > xmax then xmax = v[1] end
        if v[2] < ymin then ymin = v[2] end
        if v[2] > ymax then ymax = v[2] end
        cx, cy = cx + v[1], cy + v[2]
    end
    cx, cy = cx / #verts, cy / #verts
    local reach = 0
    for _, v in ipairs(verts) do
        local d = math.sqrt((v[1] - cx) ^ 2 + (v[2] - cy) ^ 2)
        if d > reach then reach = d end
    end
    return { xmin = xmin, ymin = ymin, xmax = xmax, ymax = ymax,
             cx = cx, cy = cy, reach = reach }
end
-- }}}

-- Proposal-and-test samplers, one per sweep style. Each returns a
-- candidate point already inside the frontier; the shared loop
-- rejects on the polygon alone. A dispatch table, so adding a sweep
-- is adding a row — never another branch in a ladder.
local PROPOSERS = {
    -- {{{ at-once
    ["at-once"] = function(fr, verts, rng, c)
        local x = fr.xmin + emit.uniform(rng) * (fr.xmax - fr.xmin)
        local y = fr.ymin + emit.uniform(rng) * (fr.ymax - fr.ymin)
        return x, y
    end,
    -- }}}
    -- {{{ downward
    ["downward"] = function(fr, verts, rng, c)
        local frontier = fr.ymin + c * (fr.ymax - fr.ymin)
        local x = fr.xmin + emit.uniform(rng) * (fr.xmax - fr.xmin)
        local y = fr.ymin + emit.uniform(rng) * (frontier - fr.ymin)
        return x, y
    end,
    -- }}}
    -- {{{ radial
    ["radial"] = function(fr, verts, rng, c)
        -- exact disc sampling (angle, rooted radius) keeps the
        -- proposal inside the grown disc, so tiny coverage still
        -- accepts nearly everything near the centroid
        local ang = emit.uniform(rng) * 2 * math.pi
        local rad = math.sqrt(emit.uniform(rng)) * c * fr.reach
        return fr.cx + math.cos(ang) * rad, fr.cy + math.sin(ang) * rad
    end,
    -- }}}
}

-- {{{ function fills.region()
-- Build a region: two vertices make a line (sweeps: at-once,
-- along); three or more make a polygon (sweeps: at-once, downward,
-- radial). Everything else is refused with the reason.
function fills.region(spec)
    local verts = spec.vertices
    if type(verts) ~= "table" or #verts < 2 then
        error("fills: a region needs at least two vertices")
    end

    if #verts == 2 then
        local x0, y0 = verts[1][1], verts[1][2]
        local dx, dy = verts[2][1] - x0, verts[2][2] - y0
        if dx == 0 and dy == 0 then
            error("fills: a line region from a point to itself has "
                  .. "no extent — the emitters issue's point path is "
                  .. "the honest tool for standing still")
        end
        if spec.sweep ~= "at-once" and spec.sweep ~= "along" then
            error("fills: a line region sweeps \"at-once\" or "
                  .. "\"along\", got '" .. tostring(spec.sweep) .. "'")
        end
        local along = spec.sweep == "along"
        return {
            kind = "line",
            -- {{{ sample()
            -- uniform on the covered prefix; "at-once" covers all
            -- of it at any coverage above zero
            sample = function(rng, c)
                local span = along and c or 1
                local t = emit.uniform(rng) * span
                return x0 + dx * t, y0 + dy * t
            end,
            -- }}}
        }
    end

    -- polygon: verify it has area at all (all-collinear or
    -- all-coincident vertices would starve the sampler forever)
    local fr = polygon_frame(verts)
    if fr.xmax - fr.xmin < 1e-9 or fr.ymax - fr.ymin < 1e-9 then
        error("fills: this polygon has no area — its vertices sit on "
              .. "a line or a point")
    end
    local propose = PROPOSERS[spec.sweep]
    if not propose then
        local legal = {}
        for name in pairs(PROPOSERS) do legal[#legal + 1] = name end
        table.sort(legal)
        error("fills: no sweep named '" .. tostring(spec.sweep)
              .. "' for a polygon — legal: " .. table.concat(legal, ", "))
    end
    return {
        kind = "polygon",
        -- {{{ sample()
        sample = function(rng, c)
            for _ = 1, MAX_TRIES do
                local x, y = propose(fr, verts, rng, c)
                if point_in_polygon(verts, x, y) then
                    return x, y
                end
            end
            error("fills: " .. MAX_TRIES .. " proposals all missed the "
                  .. "polygon — the region is degenerate and hiding it "
                  .. "would hide the bug")
        end,
        -- }}}
    }
end
-- }}}

-- {{{ function fills.track()
-- A field track: same record shape as a spot track (the timeline
-- never asks), but every birth lands at its own sampled point and
-- headings are zero — a field scatters by its recipe, and "aim"
-- honestly means nothing extra here.
-- spec: { name, from, lasts, ease (coverage curve), envelope,
--         region, recipe }
function fills.track(spec)
    if spec.lasts <= 0 then
        error("fills: '" .. tostring(spec.name) .. "' lasts "
              .. tostring(spec.lasts) .. " seconds — a fill must take"
              .. " time; \"slowly\" was the founding word")
    end
    local tr = {
        name = spec.name,
        from = spec.from,
        lasts = spec.lasts,
        ease = spec.ease,
        envelope = spec.envelope,
        region = spec.region,
        recipe = spec.recipe,
        carry = 0,
    }
    -- {{{ tr.emit_tick()
    tr.emit_tick = function(p, rng, u, dt)
        local coverage = tr.ease(u)
        -- zero coverage is zero ground: nothing can land, and the
        -- carry neither grows nor spends — the fill simply has not
        -- started. (The alternative, banking births against ground
        -- that does not exist yet, would dump them all on the first
        -- covered sliver as a flash nobody choreographed.)
        if coverage <= 0 then return end
        local strength = tr.envelope(u)
        local births
        births, tr.carry = emit.due(tr.recipe, strength, dt, tr.carry)
        for _ = 1, births do
            local x, y = tr.region.sample(rng, coverage)
            emit.birth(p, rng, tr.recipe, tr.name, x, y, 0, 0)
        end
    end
    -- }}}
    return tr
end
-- }}}

return fills
