--[[
Icons (Issue 518b)

Flat drawn glyphs for the console's buttons, in the geometry kit's plain
style (WC3's own icons are images in the owner's game data). Each draws
into the square (x, y, s) through a 2D backend with the render.ui_*
functions (the real render module, or a recorder in tests).

    icons.draw(ui, "attack", x, y, 56)
    icons.draw(ui, "train", x, y, 56, { team = {255, 3, 3}, archetype = "mounted" })
]]

local icons = {}

local STEEL = { 196, 204, 214 }
local GOLD = { 240, 200, 70 }
local WOOD = { 150, 100, 50 }
local RED = { 220, 50, 40 }
local GREEN = { 90, 200, 90 }

-- {{{ helpers (all in fractions of the square)
local function R(ui, x, y, s, a, b, w, h, c)
    ui.ui_rect(x + a * s, y + b * s, w * s, h * s, c[1], c[2], c[3], c[4] or 255)
end
local function L(ui, x, y, s, a, b, c2, d, t, c)
    ui.ui_line(x + a * s, y + b * s, x + c2 * s, y + d * s, t * s, c[1], c[2], c[3], c[4] or 255)
end
local function T(ui, x, y, s, a, b, c2, d, e, f, c)
    ui.ui_tri(x + a * s, y + b * s, x + c2 * s, y + d * s, x + e * s, y + f * s, c[1], c[2], c[3], c[4] or 255)
end
local function C(ui, x, y, s, a, b, r, c)
    ui.ui_circle(x + a * s, y + b * s, r * s, c[1], c[2], c[3], c[4] or 255)
end
-- }}}

-- {{{ Glyphs
local GLYPHS = {}

GLYPHS.move = function(ui, x, y, s)          -- a boot-shaped arrow
    L(ui, x, y, s, 0.2, 0.75, 0.72, 0.28, 0.12, GREEN)
    T(ui, x, y, s, 0.52, 0.2, 0.82, 0.18, 0.8, 0.48, GREEN)
end
GLYPHS.stop = function(ui, x, y, s)          -- a stop sign square
    R(ui, x, y, s, 0.24, 0.24, 0.52, 0.52, RED)
    R(ui, x, y, s, 0.32, 0.46, 0.36, 0.08, { 255, 240, 230 })
end
GLYPHS.hold = function(ui, x, y, s)          -- a shield
    T(ui, x, y, s, 0.22, 0.22, 0.78, 0.22, 0.5, 0.84, STEEL)
    R(ui, x, y, s, 0.22, 0.2, 0.56, 0.2, STEEL)
    L(ui, x, y, s, 0.5, 0.26, 0.5, 0.7, 0.06, { 90, 110, 170 })
end
GLYPHS.attack = function(ui, x, y, s)        -- a sword
    L(ui, x, y, s, 0.25, 0.75, 0.78, 0.22, 0.09, STEEL)
    L(ui, x, y, s, 0.2, 0.58, 0.42, 0.8, 0.08, GOLD)
    L(ui, x, y, s, 0.14, 0.86, 0.26, 0.74, 0.09, WOOD)
end
GLYPHS.patrol = function(ui, x, y, s)        -- two arrows, there and back
    L(ui, x, y, s, 0.2, 0.36, 0.72, 0.36, 0.08, GREEN)
    T(ui, x, y, s, 0.7, 0.24, 0.86, 0.36, 0.7, 0.48, GREEN)
    L(ui, x, y, s, 0.28, 0.66, 0.8, 0.66, 0.08, GREEN)
    T(ui, x, y, s, 0.3, 0.54, 0.14, 0.66, 0.3, 0.78, GREEN)
end
GLYPHS.build = function(ui, x, y, s)         -- a hammer
    L(ui, x, y, s, 0.3, 0.82, 0.62, 0.36, 0.1, WOOD)
    R(ui, x, y, s, 0.44, 0.16, 0.36, 0.2, STEEL)
end
GLYPHS.repair = function(ui, x, y, s)        -- a wrench
    L(ui, x, y, s, 0.24, 0.78, 0.62, 0.38, 0.1, STEEL)
    C(ui, x, y, s, 0.68, 0.32, 0.14, STEEL)
    C(ui, x, y, s, 0.74, 0.26, 0.06, { 40, 40, 50 })
end
GLYPHS.gather = function(ui, x, y, s)        -- a pick over a nugget
    L(ui, x, y, s, 0.24, 0.8, 0.6, 0.3, 0.08, WOOD)
    L(ui, x, y, s, 0.36, 0.2, 0.84, 0.46, 0.08, STEEL)
    C(ui, x, y, s, 0.72, 0.74, 0.12, GOLD)
end
GLYPHS.learn = function(ui, x, y, s)         -- a golden plus
    R(ui, x, y, s, 0.42, 0.18, 0.16, 0.64, GOLD)
    R(ui, x, y, s, 0.18, 0.42, 0.64, 0.16, GOLD)
end
GLYPHS.rally = function(ui, x, y, s)         -- a flag
    L(ui, x, y, s, 0.3, 0.84, 0.3, 0.16, 0.06, WOOD)
    T(ui, x, y, s, 0.32, 0.16, 0.8, 0.3, 0.32, 0.46, RED)
end
GLYPHS.cancel = function(ui, x, y, s)        -- a red cross
    L(ui, x, y, s, 0.24, 0.24, 0.76, 0.76, 0.12, RED)
    L(ui, x, y, s, 0.76, 0.24, 0.24, 0.76, 0.12, RED)
end
GLYPHS.ability = function(ui, x, y, s, o)    -- a star, tinted by name
    local c = o and o.tint or { 120, 180, 255 }
    T(ui, x, y, s, 0.5, 0.14, 0.64, 0.5, 0.36, 0.5, c)
    T(ui, x, y, s, 0.5, 0.86, 0.64, 0.5, 0.36, 0.5, c)
    T(ui, x, y, s, 0.14, 0.5, 0.5, 0.36, 0.5, 0.64, c)
    T(ui, x, y, s, 0.86, 0.5, 0.5, 0.36, 0.5, 0.64, c)
end
GLYPHS.structure = function(ui, x, y, s, o)  -- a little house
    local c = o and o.team or STEEL
    R(ui, x, y, s, 0.24, 0.46, 0.52, 0.36, { 200, 190, 170 })
    T(ui, x, y, s, 0.18, 0.48, 0.82, 0.48, 0.5, 0.16, c)
end
GLYPHS.unit = function(ui, x, y, s, o)       -- a figure by archetype
    local team = o and o.team or STEEL
    local a = o and o.archetype or "infantry"
    if a == "mounted" or a == "beast" then
        R(ui, x, y, s, 0.2, 0.52, 0.56, 0.18, { 130, 96, 70 })
        R(ui, x, y, s, 0.24, 0.7, 0.08, 0.14, { 100, 74, 56 })
        R(ui, x, y, s, 0.64, 0.7, 0.08, 0.14, { 100, 74, 56 })
        R(ui, x, y, s, 0.7, 0.4, 0.14, 0.16, { 130, 96, 70 })
    end
    if a == "flyer" then
        T(ui, x, y, s, 0.12, 0.3, 0.5, 0.5, 0.2, 0.6, team)
        T(ui, x, y, s, 0.88, 0.3, 0.5, 0.5, 0.8, 0.6, team)
    end
    if a ~= "beast" then
        R(ui, x, y, s, 0.38, 0.3, 0.24, 0.3, team)
        C(ui, x, y, s, 0.5, 0.22, 0.09, { 230, 190, 150 })
        if a ~= "mounted" and a ~= "flyer" then
            R(ui, x, y, s, 0.4, 0.6, 0.08, 0.24, { 90, 80, 70 })
            R(ui, x, y, s, 0.52, 0.6, 0.08, 0.24, { 90, 80, 70 })
        end
    end
    if a == "ranged" then L(ui, x, y, s, 0.7, 0.2, 0.7, 0.66, 0.04, WOOD) end
    if a == "caster" then
        L(ui, x, y, s, 0.72, 0.16, 0.72, 0.86, 0.05, WOOD)
        C(ui, x, y, s, 0.72, 0.16, 0.06, { 140, 220, 255 })
    end
    if a == "infantry" or a == "heavy" then L(ui, x, y, s, 0.7, 0.3, 0.84, 0.66, 0.05, STEEL) end
    if a == "worker" then L(ui, x, y, s, 0.66, 0.34, 0.8, 0.64, 0.05, WOOD) end
end
GLYPHS.train = GLYPHS.unit
GLYPHS.hero = function(ui, x, y, s, o)
    GLYPHS.unit(ui, x, y, s, o)
    L(ui, x, y, s, 0.36, 0.1, 0.64, 0.1, 0.05, GOLD)
end
-- }}}

-- {{{ icons.draw
function icons.draw(ui, name, x, y, s, opts)
    local g = GLYPHS[name] or GLYPHS.ability
    g(ui, x, y, s, opts)
end

function icons.has(name)
    return GLYPHS[name] ~= nil
end
-- }}}

return icons
