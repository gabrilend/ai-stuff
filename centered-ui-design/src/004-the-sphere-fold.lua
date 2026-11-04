-- 004-the-sphere-fold.lua - how the sphere's tiers become a circle on screen.
--
-- In plain terms: the world is a grid on a sphere, with the hub at one pole
-- and the tiers as bands of latitude, each taking the same time to cross.
-- To see every tier at once the map is drawn as a circle around the
-- dashboard, with the inner tiers given the most room and the outer tiers
-- folded together toward the edge, like an accordion closing. This file is
-- that fold, as one curve and its inverse.
--
-- Data flow:  tier distance r (0 = hub, 1 = edge of tier 1, ...)
--          -> fraction = ln(1 + k r) / ln(1 + k r_max)     (k = fold strength)
--          -> radius on the ground = hub_radius + fraction * (edge - hub)
--
-- With k = 0 the curve is a straight line (every tier equally wide). The
-- curve always increases, so a radius on the ground runs back to exactly one
-- tier distance.
--
-- Things far out also shrink, by the same factor their tier is squeezed, so
-- a unit near the edge is drawn small, as everything there is — except under
-- the size law "keep" (fold.size_keep = 1, the slant view of issue 214),
-- where everything keeps its full size: the owner asked that the stuff near
-- the top "remains the same size relative to the part near the dashboard".

local M = {}

-- The views that keep far things full size (the size law "keep", 1); the
-- others shrink them (0).
M.SIZE_KEEPING_VIEWS = { slant = 1, arch = 1 }

-- {{{ local function fraction_of()
-- The curve's shape alone: tier distance -> 0..1 across the drawn map.
local function fraction_of(r, k, r_max)
    -- No fold: the straight line. (The log form would be 0/0 here.)
    if k < 1e-6 then
        return r / r_max
    end
    -- Folded: logarithmic, inner tiers wide, outer tiers compressed.
    return math.log(1 + k * r) / math.log(1 + k * r_max)
end
-- }}}

-- {{{ function M.radius()
-- Tier distance -> radius on the ground (world units).
-- `fold` is a table: strength (k), tiers_shown (r_max), hub_radius, edge_radius.
function M.radius(fold, r)
    local fraction = fraction_of(r, fold.strength, fold.tiers_shown)
    return fold.hub_radius + fraction * (fold.edge_radius - fold.hub_radius)
end
-- }}}

-- {{{ function M.tier_distance()
-- Radius on the ground -> tier distance. The exact inverse of M.radius.
function M.tier_distance(fold, radius)
    local fraction = (radius - fold.hub_radius) / (fold.edge_radius - fold.hub_radius)
    local k = fold.strength
    -- No fold: undo the straight line.
    if k < 1e-6 then
        return fraction * fold.tiers_shown
    end
    -- Folded: undo the logarithm.
    return (math.exp(fraction * math.log(1 + k * fold.tiers_shown)) - 1) / k
end
-- }}}

-- {{{ function M.slope()
-- How many ground units one tier distance spans at r (the curve's slope).
-- Used to turn a unit's speed through the tiers into a direction on the
-- ground, so it can face where it is going.
function M.slope(fold, r)
    local k = fold.strength
    local span = fold.edge_radius - fold.hub_radius
    -- No fold: constant slope.
    if k < 1e-6 then
        return span / fold.tiers_shown
    end
    -- Folded: the logarithm's slope.
    return span * k / ((1 + k * r) * math.log(1 + k * fold.tiers_shown))
end
-- }}}

-- {{{ function M.size_scale()
-- How much a thing at tier distance r is shrunk: 1 at the edge of tier 1,
-- smaller further out. (1 + k) / (1 + k r) is the curve's slope relative to
-- its slope at r = 1, and is exactly 1 everywhere when k = 0.
function M.size_scale(fold, r)
    -- the slant view: full size everywhere
    if fold.size_keep == 1 then
        return 1
    end
    -- the other views: shrunk as the tier is squeezed
    return (1 + fold.strength) / (1 + fold.strength * r)
end
-- }}}

-- {{{ function M.side_radius()
-- How far a lap around the hub at tier distance r really is, as the radius
-- of that circle of latitude on the sphere (tiers): (P / pi) sin(pi r / P),
-- with our hub at one pole and the foes' pole P tiers out. Near our hub it
-- is about r; it shrinks again toward the far pole. The map draws every lap
-- as a full circle of its folded radius, so walking sideways near the far
-- pole crosses the screen fast — the owner: "They will move left-right
-- faster while they are far away, but closer / farther is always just
-- dense." Twin of side_radius in 020-ceramic-boxes.c.
function M.side_radius(fold, r)
    local pole = fold.far_pole
    return pole / math.pi * math.sin(math.pi * r / pole)
end
-- }}}

-- {{{ function M.ground_position()
-- A place (tier distance, angle) -> world x, z on the ground. Angle 0 points
-- up the screen (north, -z) and grows clockwise.
function M.ground_position(fold, r, angle)
    local radius = M.radius(fold, r)
    return radius * math.sin(angle), -radius * math.cos(angle)
end
-- }}}

-- {{{ function M.from_settings()
function M.from_settings(settings)
    return {
        strength = settings.fold_strength,
        tiers_shown = settings.tiers_shown,
        hub_radius = settings.hub_radius,
        edge_radius = settings.edge_radius,
        -- the size law (0 or 1; see size_scale): kept only by the slant view
        size_keep = M.SIZE_KEEPING_VIEWS[settings.view_depth] or 0,
        -- the foes' pole, in tiers from ours (see side_radius)
        far_pole = settings.far_pole_tier,
    }
end
-- }}}

-- The shader twin of the fold. Prepended to the ground and unit shaders.
M.GLSL = [[
uniform float fold_strength;
uniform float tiers_shown;
uniform float hub_radius;
uniform float edge_radius;
uniform float fold_size_keep;   // 1: full size everywhere (slant view)

// Tier distance -> radius on the ground. Twin of M.radius in
// 004-the-sphere-fold.lua.
float fold_radius(float r) {
    float fraction;
    if (fold_strength < 1e-6) {
        // no fold: straight line
        fraction = r / tiers_shown;
    } else {
        // folded: logarithmic
        fraction = log(1.0 + fold_strength * r) / log(1.0 + fold_strength * tiers_shown);
    }
    return hub_radius + fraction * (edge_radius - hub_radius);
}

// Ground units per tier at r. Twin of M.slope.
float fold_slope(float r) {
    if (fold_strength < 1e-6) {
        // no fold: constant
        return (edge_radius - hub_radius) / tiers_shown;
    }
    // folded: the logarithm's slope
    return (edge_radius - hub_radius) * fold_strength
         / ((1.0 + fold_strength * r) * log(1.0 + fold_strength * tiers_shown));
}

// How much a thing at r is shrunk (1 at the edge of tier 1).
float fold_size_scale(float r) {
    if (fold_size_keep > 0.5) {
        // the slant view: full size everywhere
        return 1.0;
    }
    return (1.0 + fold_strength) / (1.0 + fold_strength * r);
}

vec3 fold_ground_position(float r, float angle) {
    float radius = fold_radius(r);
    return vec3(radius * sin(angle), 0.0, -radius * cos(angle));
}
]]

-- {{{ function M.send()
function M.send(fold, shader)
    shader:send("fold_strength", fold.strength)
    shader:send("tiers_shown", fold.tiers_shown)
    shader:send("hub_radius", fold.hub_radius)
    shader:send("edge_radius", fold.edge_radius)
    -- only the shaders that size things use it (the ground does not, and an
    -- unused uniform is removed when a shader is compiled)
    if shader:hasUniform("fold_size_keep") then
        shader:send("fold_size_keep", fold.size_keep)
    end
end
-- }}}

return M
