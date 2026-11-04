-- 019-the-arch.lua - the shape of the console: one hump of an M.
--
-- In plain terms: the console in the middle of the screen is an arch, like
-- one half of the McDonald's "M". Its curved band is glass through which the
-- map is seen. Beneath the curve and above the flat base is the dashboard
-- surface, where the buttons and dials are. With allies, the console is one
-- arch per ally side by side, sharing their feet — an M with a hump for each
-- — and each player sees only their own section: their arch whole, and the
-- feet of their neighbours' arches at the sides. More allies make the M
-- longer, never a section smaller.
--
-- Geometry (window pixels, y down). A section has a center x, a base y, a
-- height H, a width W and a band thickness T:
--
--   outer curve: rises H at the middle, meets the base at +-W/2
--                  up(x) = H * (1 - (x / (W/2))^2)
--   inner curve: rises H - T at the middle, meets the base at +-(W/2 - T)
--                  up(x) = (H - T) * (1 - (x / (W/2 - T))^2)
--   band:        between the two curves (glass: the map display)
--   interior:    under the inner curve, above the base (the dashboard)
--
-- Neighbouring sections sit W - T apart, so a foot of one and a foot of the
-- next overlap exactly: the M's middle stroke.
--
-- Layout inside a section is given in "arch units": `across` from the center
-- and `up` from the base, both as shares of H, so the dashboard keeps its
-- proportions at any window size.

local M = {}

-- {{{ function M.new()
-- A section: center_x, base_y, height, width, band (numbers, pixels).
function M.new(center_x, base_y, height, width_share, band_share)
    return {
        center_x = center_x,
        base_y = base_y,
        height = height,
        width = height * width_share,
        band = height * band_share,
    }
end
-- }}}

-- {{{ function M.shifted()
-- The same section moved sideways by whole sections (neighbours: -1, +1).
function M.shifted(section, steps)
    local copy = {}
    for key, value in pairs(section) do
        copy[key] = value
    end
    copy.center_x = section.center_x + steps * (section.width - section.band)
    return copy
end
-- }}}

-- {{{ function M.at()
-- Arch units -> window pixels.
function M.at(section, across, up)
    return section.center_x + across * section.height, section.base_y - up * section.height
end
-- }}}

-- {{{ local function outer_up()
-- Height of the outer curve above the base at horizontal offset dx (pixels);
-- negative outside the arch's span.
local function outer_up(section, dx)
    local half = section.width / 2
    return section.height * (1 - (dx / half) ^ 2)
end
-- }}}

-- {{{ local function inner_up()
local function inner_up(section, dx)
    local half = section.width / 2 - section.band
    return (section.height - section.band) * (1 - (dx / half) ^ 2)
end
-- }}}

-- {{{ function M.in_interior()
-- Whether a pixel lies on the dashboard surface (under the inner curve,
-- above the base).
function M.in_interior(section, x, y)
    local dx = x - section.center_x
    local up = section.base_y - y
    return up >= 0 and up <= inner_up(section, dx)
end
-- }}}

-- {{{ function M.in_band()
-- Whether a pixel lies on the glass band (under the outer curve, above the
-- inner one, above the base).
function M.in_band(section, x, y)
    local dx = x - section.center_x
    local up = section.base_y - y
    return up >= 0 and up <= outer_up(section, dx) and not M.in_interior(section, x, y)
end
-- }}}

-- {{{ function M.interior_half_width()
-- How wide the dashboard surface is (half, in arch units) at height `up`
-- (arch units): where a button or dial may go without crossing the band.
function M.interior_half_width(section, up)
    local H = section.height
    local inner_height = (H - section.band) / H
    local inner_half = (section.width / 2 - section.band) / H
    -- above the inner curve's top: no surface at all
    if up >= inner_height then
        return 0
    end
    return inner_half * math.sqrt(1 - up / inner_height)
end
-- }}}

-- {{{ function M.curve_points()
-- Matching points along the inner and outer curves, foot to foot: a list of
-- { inner_x, inner_y, outer_x, outer_y }. Spaced by an angle so they crowd
-- where the curves are steep (the feet) and thin out over the top.
function M.curve_points(section, steps)
    local points = {}
    local outer_half = section.width / 2
    local inner_half = section.width / 2 - section.band
    for step = 0, steps do
        local u = math.sin(-math.pi / 2 + math.pi * step / steps)
        local outer_dx = u * outer_half
        local inner_dx = u * inner_half
        points[#points + 1] = {
            section.center_x + inner_dx, section.base_y - inner_up(section, inner_dx),
            section.center_x + outer_dx, section.base_y - outer_up(section, outer_dx),
        }
    end
    return points
end
-- }}}

-- {{{ function M.interior_polygon()
-- The dashboard surface's outline as a flat x, y list (convex: the region
-- under a downward curve above a straight base).
function M.interior_polygon(section, steps)
    local outline = {}
    for _, point in ipairs(M.curve_points(section, steps)) do
        outline[#outline + 1] = point[1]
        outline[#outline + 1] = point[2]
    end
    return outline
end
-- }}}

return M
