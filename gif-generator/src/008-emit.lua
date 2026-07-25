-- 008-emit.lua — emitter recipes, the seeded generator, and the emit
-- step that turns "a source of particles with a character" into
-- filled pool slots.
--
-- What this is, generally: a recipe is data — how many per second,
-- how scattered, how fast, how long-lived, which hue. The emit step
-- reads a recipe, a position, and a heading, and births the right
-- number of particles this tick. All chance flows from one seeded
-- generator: the same score and seed always make the same gif, which
-- keeps tests honest and bugs reproducible.
--
-- Data-format notes worth knowing more than once:
--   * spawn counts accumulate FRACTIONALLY across ticks: 400 per
--     second at 25 fps is exactly 16 per tick, and 7.3 per second
--     drifts nowhere because the remainder is carried, never
--     rounded away. The carry lives with the caller (one per
--     stroke), not in the recipe — recipes are shared, carries are
--     not.
--   * the generator is xorshift32: tiny, fast, and identical on
--     every machine (no dependence on any C library's dice).

local pool = require("006-pool")

local emit = {}

-- Recipe defaults: the documented vocabulary of an emit block.
-- Absent fields mean these numbers — that is a definition, not a
-- fallback; the score format document points here.
local DEFAULTS = {
    rate        = 300,   -- particles per second
    spread      = 1.6,   -- birth scatter radius, pixels
    speed       = 14,    -- typical birth speed, pixels per second
    aim         = 0.5,   -- 0 = scatter every way, 1 = all along the heading
    life        = 0.6,   -- expected lifetime, seconds
    life_jitter = 0.35,  -- fraction of life rolled per particle
    drag        = 2.2,   -- how quickly motion gives up, per second
    jitter      = 30,    -- wander force, pixels per second squared
}

-- {{{ function emit.rng()
-- One xorshift32 stream per render. Seed 0 would lock the generator
-- at zero forever, so it is nudged — documented here because a
-- score's seed field may legally be 0.
function emit.rng(seed)
    local state = seed % 4294967296
    if state == 0 then state = 2463534242 end
    return { state = state }
end
-- }}}

-- {{{ function emit.uniform()
-- The generator's only voice: a double in [0, 1).
function emit.uniform(rng)
    local s = rng.state
    s = bit.bxor(s, bit.lshift(s, 13)) % 4294967296
    s = bit.bxor(s, bit.rshift(s, 17)) % 4294967296
    s = bit.bxor(s, bit.lshift(s, 5)) % 4294967296
    rng.state = s
    return s / 4294967296
end
-- }}}

-- {{{ function emit.recipe()
-- Fill a partial emit block with the documented defaults and check
-- what remains. Unknown fields are refused — a misspelled field
-- would otherwise silently mean "use the default", which is the
-- exact lie this project bans.
function emit.recipe(block, hue_index)
    local r = {}
    for k, v in pairs(DEFAULTS) do r[k] = v end
    if block then
        for k, v in pairs(block) do
            if DEFAULTS[k] == nil then
                local legal = {}
                for name in pairs(DEFAULTS) do legal[#legal + 1] = name end
                table.sort(legal)
                error("emit: unknown recipe field '" .. tostring(k)
                      .. "' — legal fields: " .. table.concat(legal, ", "))
            end
            r[k] = v
        end
    end
    r.hue = hue_index
    return r
end
-- }}}

-- {{{ function emit.birth()
-- One particle, born at one place with one heading. Made public
-- with the fill-regions issue: field emitters place EVERY birth at
-- its own sampled point, so the single birth is the shared atom and
-- the tick-step below is one caller of it.
function emit.birth(p, rng, recipe, asker, x, y, hx, hy)
    local i = pool.spawn(p, asker)
    -- birth scatter: uniform in a disc, via angle plus rooted
    -- radius (the root keeps the disc uniform, not center-heavy)
    local ang = emit.uniform(rng) * 2 * math.pi
    local rad = math.sqrt(emit.uniform(rng)) * recipe.spread
    p.x[i] = x + math.cos(ang) * rad
    p.y[i] = y + math.sin(ang) * rad
    -- velocity: a blend of scatter and heading. aim = 0 wanders
    -- every way; aim = 1 rides the stroke's motion entirely
    local vang = emit.uniform(rng) * 2 * math.pi
    local vmag = recipe.speed * (0.5 + emit.uniform(rng))
    local sx, sy = math.cos(vang) * vmag, math.sin(vang) * vmag
    p.vx[i] = sx * (1 - recipe.aim) + hx * vmag * recipe.aim
    p.vy[i] = sy * (1 - recipe.aim) + hy * vmag * recipe.aim
    p.age[i] = 0
    p.life[i] = recipe.life
                * (1 + (emit.uniform(rng) - 0.5) * 2 * recipe.life_jitter)
    p.drag[i] = recipe.drag
    p.jitter[i] = recipe.jitter
    -- bright-seed: some particles simply burn brighter, rolled
    -- once at birth so each keeps its temperament for life
    p.seed[i] = 0.6 + emit.uniform(rng) * 0.8
    p.hue[i] = recipe.hue
end
-- }}}

-- {{{ function emit.due()
-- The fractional-carry arithmetic, shared by every kind of emitter:
-- how many whole births this tick, and what fraction rides forward.
function emit.due(recipe, strength, dt, carry)
    local owed = recipe.rate * strength * dt + carry
    local births = math.floor(owed)
    return births, owed - births
end
-- }}}

-- {{{ function emit.step()
-- One tick of one SPOT stroke's emission: every birth at the same
-- tip, with the same heading. Returns the new carry.
function emit.step(p, rng, recipe, asker, x, y, hx, hy, strength, dt, carry)
    local births, new_carry = emit.due(recipe, strength, dt, carry)
    for _ = 1, births do
        emit.birth(p, rng, recipe, asker, x, y, hx, hy)
    end
    return new_carry
end
-- }}}

return emit
