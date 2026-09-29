--[[
Designs (Issue 517c)

Box-built stand-ins for the models a WC3 map places: trees, rocks, plants,
props, structures; buildings by race and size; units by what they do. Each
design is drawn in its own frame (along = forward, across = left, up) and
placed with designs.place(). All sizes are WC3 units.

    local designs = require("geometry.designs")
    local prims = designs.build({ design = "building", race = "human",
                                  size = "hall", team = 0 }, x, y, z, facing, scale)

Every design takes a spec table (see designs.build); unknown fields fall
back to plain looks, so a spec from a guessing classifier always draws.
]]

local designs = {}

-- {{{ Colours
-- Team colours, players 0-11 (red, blue, teal, purple, yellow, orange,
-- green, pink, grey, light blue, dark green, brown); 12 neutral hostile,
-- 15 neutral passive.
designs.TEAM = {
    [0] = { 255, 3, 3 }, { 0, 66, 255 }, { 28, 230, 185 }, { 84, 0, 129 },
    { 255, 252, 1 }, { 254, 138, 14 }, { 32, 192, 0 }, { 229, 91, 176 },
    { 149, 150, 151 }, { 126, 191, 241 }, { 16, 98, 70 }, { 78, 42, 4 },
    [12] = { 40, 40, 40 }, [15] = { 200, 200, 200 },
}

local RACE = {
    human    = { wall = { 214, 208, 190 }, trim = { 120, 110, 100 }, skin = { 230, 190, 150 }, cloth = { 90, 110, 170 } },
    orc      = { wall = { 140, 94, 56 },   trim = { 90, 60, 36 },    skin = { 96, 150, 70 },   cloth = { 150, 80, 50 } },
    undead   = { wall = { 70, 60, 92 },    trim = { 40, 34, 54 },    skin = { 170, 176, 150 }, cloth = { 60, 50, 80 } },
    nightelf = { wall = { 96, 72, 120 },   trim = { 60, 110, 70 },   skin = { 150, 120, 200 }, cloth = { 70, 60, 120 } },
    naga     = { wall = { 60, 120, 120 },  trim = { 30, 80, 90 },    skin = { 70, 150, 130 },  cloth = { 40, 90, 110 } },
    demon    = { wall = { 110, 40, 40 },   trim = { 60, 20, 20 },    skin = { 150, 60, 50 },   cloth = { 80, 30, 30 } },
    neutral  = { wall = { 170, 160, 140 }, trim = { 100, 90, 80 },   skin = { 200, 170, 130 }, cloth = { 120, 110, 90 } },
}

local TREE = {   -- by tileset letter: trunk, leaves, second leaves
    L = { { 100, 70, 40 }, { 60, 140, 50 }, { 80, 160, 60 } },     -- Lordaeron summer
    F = { { 100, 70, 40 }, { 190, 120, 40 }, { 200, 150, 50 } },   -- Lordaeron fall
    W = { { 90, 70, 50 }, { 60, 110, 70 }, { 235, 240, 245 } },    -- Lordaeron winter
    A = { { 80, 60, 50 }, { 40, 100, 60 }, { 110, 70, 140 } },     -- Ashenvale
    B = { { 110, 80, 50 }, { 150, 140, 60 }, { 120, 120, 50 } },   -- Barrens
    C = { { 110, 80, 50 }, { 70, 150, 60 }, { 90, 170, 70 } },     -- Felwood/others
    N = { { 80, 60, 50 }, { 50, 90, 70 }, { 240, 245, 250 } },     -- Northrend
    I = { { 80, 80, 100 }, { 110, 150, 180 }, { 220, 235, 250 } }, -- Icecrown
    Z = { { 90, 70, 50 }, { 40, 110, 70 }, { 60, 130, 80 } },      -- Sunken ruins
    Y = { { 100, 70, 40 }, { 70, 150, 60 }, { 90, 170, 80 } },     -- Cityscape
    V = { { 100, 70, 40 }, { 70, 150, 60 }, { 90, 170, 80 } },     -- Village
    J = { { 90, 70, 50 }, { 60, 130, 50 }, { 90, 150, 60 } },      -- Lordaeron-style others
    K = { { 90, 60, 50 }, { 120, 40, 40 }, { 150, 60, 50 } },      -- Black citadel
    O = { { 90, 60, 50 }, { 150, 70, 40 }, { 180, 110, 50 } },     -- Outland
    G = { { 80, 60, 50 }, { 120, 60, 120 }, { 150, 90, 150 } },    -- Underground
    D = { { 80, 60, 50 }, { 130, 100, 140 }, { 170, 130, 170 } },  -- Dungeon (mushrooms)
    X = { { 100, 70, 40 }, { 70, 150, 60 }, { 90, 170, 80 } },
}
local DEFAULT_TREE = TREE.L
-- }}}

-- {{{ Building blocks

-- {{{ part
-- A box in the design's own frame
local function part(list, along, across, up, len, wid, hgt, color, yaw)
    list[#list + 1] = { kind = "box", x = along, y = across, z = up,
                        len = len, wid = wid, hgt = hgt, yaw = yaw or 0, color = color }
end
-- }}}

-- {{{ roof
-- A pitched roof over a len x wid block, ridge along its length, as two
-- sloped quads and two gable triangles
local function roof(list, along, across, up, len, wid, rise, color, gable)
    local hl, hw = len / 2, wid / 2
    local a0, a1 = along - hl, along + hl
    local c0, c1 = across - hw, across + hw
    local ridge = up + rise
    list[#list + 1] = { kind = "quad", color = color, pts = {
        { a0, c0, up }, { a1, c0, up }, { a1, across, ridge }, { a0, across, ridge } } }
    list[#list + 1] = { kind = "quad", color = color, pts = {
        { a0, c1, up }, { a1, c1, up }, { a1, across, ridge }, { a0, across, ridge } } }
    for _, a in ipairs({ a0, a1 }) do
        list[#list + 1] = { kind = "quad", color = gable or color, pts = {
            { a, c0, up }, { a, c1, up }, { a, across, ridge }, { a, across, ridge } } }
    end
end
-- }}}

-- {{{ spire
-- A four-sided pyramid of the given base and height
local function spire(list, along, across, up, base, height, color)
    local h = base / 2
    local apex = { along, across, up + height }
    local c = { { along - h, across - h }, { along + h, across - h },
                { along + h, across + h }, { along - h, across + h } }
    for i = 1, 4 do
        local p, q = c[i], c[i % 4 + 1]
        list[#list + 1] = { kind = "quad", color = color,
            pts = { { p[1], p[2], up }, { q[1], q[2], up }, apex, apex } }
    end
end
-- }}}

-- {{{ tint
local function tint(c, k)
    return { math.min(255, math.floor(c[1] * k)), math.min(255, math.floor(c[2] * k)),
             math.min(255, math.floor(c[3] * k)) }
end
-- }}}
-- }}}

-- {{{ Props

-- {{{ tree
-- Round trees (a trunk and two blocks of leaves) or pines (stacked tiers),
-- coloured by tileset. spec.variant (0-9) varies the shape a little.
local function tree(list, spec)
    local pal = TREE[spec.tileset or "L"] or DEFAULT_TREE
    local v = (spec.variant or 0) % 10
    local tall = 1 + (v % 3) * 0.12
    part(list, 0, 0, 0, 22, 22, 90 * tall, pal[1])
    if spec.style == "pine" then
        for i = 0, 3 do
            local s = (120 - i * 26) * tall
            part(list, 0, 0, (50 + i * 48) * tall, s, s, 44 * tall,
                 i == 3 and pal[3] or pal[2], math.rad(45 * (i % 2)))
        end
    else
        part(list, 0, 0, 80 * tall, 130, 130, 90 * tall, pal[2], math.rad(v * 9))
        part(list, 8, -6, 160 * tall, 90, 90, 50 * tall, pal[3], math.rad(v * 9 + 45))
    end
end
-- }}}

-- {{{ rock
local function rock(list, spec)
    local c = spec.color or { 128, 120, 112 }
    local v = spec.variant or 0
    part(list, 0, 0, 0, 90, 70, 50, c, math.rad(v * 23))
    part(list, 30, 24, 0, 50, 46, 34, tint(c, 0.85), math.rad(v * 41 + 20))
    part(list, -26, 20, 0, 36, 30, 24, tint(c, 1.1), math.rad(v * 13 + 50))
end
-- }}}

-- {{{ plant
local function plant(list, spec)
    local pal = TREE[spec.tileset or "L"] or DEFAULT_TREE
    part(list, 0, 0, 0, 40, 40, 30, pal[2], math.rad(20))
    part(list, 10, -8, 0, 26, 26, 44, pal[3], math.rad(60))
end
-- }}}

-- {{{ prop
-- Crates, barrels, lamp posts, signs: a small block, or a post with a lamp
local function prop(list, spec)
    if spec.style == "lamp" then
        part(list, 0, 0, 0, 10, 10, 150, { 50, 50, 56 })
        part(list, 0, 0, 150, 26, 26, 22, { 255, 220, 120 })
    else
        local c = spec.color or { 150, 110, 70 }
        part(list, 0, 0, 0, 56, 56, 48, c)
        part(list, 0, 0, 48, 60, 60, 6, tint(c, 0.7))
    end
end
-- }}}

-- {{{ structure
-- Walls, ruins and other built doodads: a stone block, walls longer than wide
local function structure(list, spec)
    local c = spec.color or { 150, 144, 136 }
    if spec.style == "wall" then
        -- a plain section with a cap: map makers scale and turn these into
        -- pillars and round towers, so no battlements to multiply
        part(list, 0, 0, 0, 160, 48, 96, c)
        part(list, 0, 0, 96, 168, 56, 10, tint(c, 1.15))
    else
        part(list, 0, 0, 0, 120, 120, 110, c)
        part(list, 0, 0, 110, 90, 90, 30, tint(c, 0.8))
    end
end
-- }}}
-- }}}

-- {{{ Buildings

local BUILDING_SIZE = {   -- footprint, wall height
    small = { 224, 110 }, medium = { 352, 150 }, hall = { 480, 190 },
    tower = { 144, 330 }, altar = { 320, 90 }, special = { 320, 170 },
}

-- {{{ building
-- By race: human (stone, pitched roof in team colour), orc (timber and
-- spikes), undead (stepped ziggurat), night elf (a living tree), others
-- (plain block, roof in team colour). spec.size picks the footprint.
local function building(list, spec)
    local r = RACE[spec.race or "neutral"] or RACE.neutral
    local team = designs.TEAM[spec.team or 15] or designs.TEAM[15]
    local size = BUILDING_SIZE[spec.size or "medium"] or BUILDING_SIZE.medium
    local foot, height = size[1], size[2]
    local race = spec.race or "neutral"

    if spec.size == "tower" then
        part(list, 0, 0, 0, foot, foot, height, r.wall)
        part(list, 0, 0, height, foot + 24, foot + 24, 24, r.trim)
        if race == "undead" or race == "orc" then
            spire(list, 0, 0, height + 24, foot, 90, team)
        else
            spire(list, 0, 0, height + 24, foot + 24, 110, team)
        end
        return
    end

    if race == "undead" then
        for i = 0, 2 do
            local s = foot * (1 - i * 0.28)
            part(list, 0, 0, i * height * 0.45, s, s, height * 0.45, i == 2 and team or r.wall)
        end
        part(list, 0, 0, height * 1.35, 30, 30, 40, { 120, 255, 160 })
    elseif race == "nightelf" then
        part(list, 0, 0, 0, foot * 0.45, foot * 0.45, height * 1.4, { 110, 80, 60 })
        part(list, 0, 0, height * 1.1, foot, foot, height * 0.6, r.trim, math.rad(20))
        part(list, 0, 0, height * 1.6, foot * 0.7, foot * 0.7, height * 0.35, r.wall, math.rad(65))
        part(list, foot * 0.3, 0, 0, foot * 0.2, foot * 0.6, 20, team)
    elseif race == "orc" then
        part(list, 0, 0, 0, foot, foot * 0.85, height, r.wall)
        part(list, 0, 0, 0, foot * 0.85, foot, height, r.wall, math.rad(45))
        roof(list, 0, 0, height, foot, foot * 0.85, height * 0.45, team, r.trim)
        for _, s in ipairs({ -1, 1 }) do
            part(list, foot * 0.5, s * foot * 0.3, height * 0.5, 80, 10, 10, { 235, 225, 200 }, math.rad(s * 20))
        end
    else
        part(list, 0, 0, 0, foot, foot * 0.8, height, r.wall)
        roof(list, 0, 0, height, foot + 16, foot * 0.8 + 16, height * 0.55, team, r.trim)
        part(list, foot / 2, 0, 0, 8, foot * 0.2, height * 0.5, r.trim)   -- door
        if spec.size == "hall" then
            for _, s in ipairs({ -1, 1 }) do
                part(list, foot * 0.4, s * foot * 0.45, 0, 90, 90, height * 1.5, r.wall)
                spire(list, foot * 0.4, s * foot * 0.45, height * 1.5, 100, 90, team)
            end
        end
    end
end
-- }}}
-- }}}

-- {{{ Units

-- {{{ body
-- The common figure: legs, torso, head, arms; about 90 tall at scale 1
local function body(list, r, team, opts)
    local s = opts.bulk or 1
    part(list, 0, 7 * s, 0, 12 * s, 10 * s, 38, tint(r.cloth, 0.8))
    part(list, 0, -7 * s, 0, 12 * s, 10 * s, 38, tint(r.cloth, 0.8))
    part(list, 0, 0, 38, 20 * s, 28 * s, 30, team)
    part(list, 0, 0, 68, 18, 18, 18, r.skin)
    part(list, 6, 16 * s, 44, 10, 8, 22, r.skin)
    part(list, 6, -16 * s, 44, 10, 8, 22, r.skin)
end
-- }}}

-- {{{ unit
-- Archetypes: infantry (sword and shield), ranged (bow), gunner, caster
-- (robe and staff), mounted (horse and rider), heavy (a big hunched brute),
-- flyer (winged, off the ground), siege (a wheeled engine), ship (hull,
-- mast and sail), worker (small, with a tool), beast (four legs).
-- spec.hero adds a golden ring and makes it larger.
local function unit(list, spec)
    local r = RACE[spec.race or "neutral"] or RACE.neutral
    local team = designs.TEAM[spec.team or 12] or designs.TEAM[12]
    local a = spec.archetype or "infantry"
    local steel = { 180, 186, 196 }
    local wood = { 120, 80, 40 }

    if a == "ship" then
        part(list, 0, 0, -10, 260, 90, 50, wood)
        part(list, 100, 0, -10, 70, 50, 60, tint(wood, 0.8))
        part(list, 0, 0, 40, 12, 12, 200, wood)
        list[#list + 1] = { kind = "quad", color = team, pts = {
            { 0, -70, 90 }, { 0, 70, 90 }, { 0, 60, 220 }, { 0, -60, 220 } } }
    elseif a == "siege" then
        part(list, 0, 0, 14, 120, 70, 40, wood)
        for _, p in ipairs({ { 40, 40 }, { 40, -40 }, { -40, 40 }, { -40, -40 } }) do
            part(list, p[1], p[2], 0, 30, 8, 30, tint(wood, 0.6))
        end
        part(list, -10, 0, 54, 110, 14, 14, tint(wood, 1.2), 0)
        part(list, 40, 0, 54, 20, 30, 50, team)
    elseif a == "mounted" then
        part(list, 0, 0, 40, 110, 40, 44, { 110, 80, 60 })       -- horse
        part(list, 62, 0, 70, 40, 26, 40, { 110, 80, 60 })
        for _, p in ipairs({ { 38, 14 }, { 38, -14 }, { -38, 14 }, { -38, -14 } }) do
            part(list, p[1], p[2], 0, 12, 12, 42, { 80, 58, 44 })
        end
        part(list, 0, 0, 84, 22, 28, 34, team)                   -- rider
        part(list, 0, 0, 118, 18, 18, 18, r.skin)
        part(list, 30, 18, 90, 90, 6, 6, steel)                   -- lance
    elseif a == "flyer" then
        part(list, 0, 0, 160, 90, 36, 34, r.cloth)
        part(list, 50, 0, 176, 30, 24, 24, r.skin)
        for _, s in ipairs({ -1, 1 }) do
            list[#list + 1] = { kind = "quad", color = team, pts = {
                { 20, s * 18, 184 }, { -30, s * 18, 184 }, { -40, s * 120, 200 }, { 10, s * 110, 200 } } }
        end
    elseif a == "beast" then
        part(list, 0, 0, 30, 100, 44, 40, r.skin)
        part(list, 56, 0, 40, 36, 30, 32, tint(r.skin, 0.9))
        for _, p in ipairs({ { 34, 16 }, { 34, -16 }, { -34, 16 }, { -34, -16 } }) do
            part(list, p[1], p[2], 0, 12, 12, 30, tint(r.skin, 0.7))
        end
        part(list, 0, 0, 70, 30, 30, 6, team)
    elseif a == "heavy" then
        body(list, r, team, { bulk = 1.8 })
        part(list, 10, 0, 56, 40, 60, 30, tint(r.skin, 0.9))
        part(list, 24, -34, 20, 12, 12, 60, wood)
    elseif a == "worker" then
        body(list, r, team, { bulk = 0.8 })
        part(list, 14, -16, 40, 8, 8, 40, wood)
        part(list, 14, -16, 78, 26, 8, 8, steel)
    else
        body(list, r, team, {})
        if a == "ranged" then
            part(list, 22, 10, 36, 5, 5, 50, wood)
        elseif a == "gunner" then
            part(list, 26, -12, 54, 50, 6, 6, { 70, 70, 76 })
        elseif a == "caster" then
            part(list, 0, 0, 0, 30, 32, 40, team)                 -- robe
            part(list, 14, -18, 0, 6, 6, 110, wood)
            part(list, 14, -18, 110, 14, 14, 14, { 140, 220, 255 })
        else
            part(list, 20, -16, 40, 40, 5, 5, steel, 0)           -- sword
            part(list, 10, 18, 34, 6, 30, 36, tint(team, 0.8))    -- shield
        end
    end
end
-- }}}
-- }}}

-- {{{ designs.place
-- Move a design's primitives to (x, y, z), turned to facing, scaled by
-- scale (a number, or {x, y, z}) about its base
function designs.place(list, x, y, z, facing, scale)
    local sx, sy, sz
    if type(scale) == "table" then sx, sy, sz = scale[1], scale[2], scale[3]
    else sx, sy, sz = scale or 1, scale or 1, scale or 1 end
    local c, s = math.cos(facing or 0), math.sin(facing or 0)
    local function at(a, b, h)
        a, b = a * sx, b * sy
        return x + a * c - b * s, y + a * s + b * c, z + h * sz
    end
    for _, p in ipairs(list) do
        if p.kind == "quad" then
            for i, q in ipairs(p.pts) do
                local nx, ny, nz = at(q[1], q[2], q[3])
                p.pts[i] = { nx, ny, nz }
            end
        else
            p.x, p.y, p.z = at(p.x, p.y, p.z)
            p.len, p.wid, p.hgt = p.len * sx, p.wid * sy, p.hgt * sz
            p.yaw = p.yaw + (facing or 0)
        end
    end
    return list
end
-- }}}

-- {{{ designs.build
-- spec.design: "tree" | "rock" | "plant" | "prop" | "structure" |
-- "building" | "unit"; the rest of spec as each design reads it. Returns
-- primitives placed at (x, y, z).
local BUILDERS = { tree = tree, rock = rock, plant = plant, prop = prop,
                   structure = structure, building = building, unit = unit }

function designs.build(spec, x, y, z, facing, scale)
    local list = {}
    local fn = BUILDERS[spec.design] or prop
    fn(list, spec)
    if spec.hero then
        for i = 0, 7 do
            local a = i / 8 * 2 * math.pi
            part(list, math.cos(a) * 44, math.sin(a) * 44, 1, 22, 8, 3, { 255, 210, 60 }, a + math.pi / 2)
        end
        if type(scale) == "table" then
            scale = { scale[1] * 1.25, scale[2] * 1.25, scale[3] * 1.25 }
        else
            scale = (scale or 1) * 1.25
        end
    end
    return designs.place(list, x, y, z, facing, scale)
end
-- }}}

return designs
