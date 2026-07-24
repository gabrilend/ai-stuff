-- 010-physics.lua — the integrator: drag, wander, aging, death, and
-- the fade that carries a particle's remaining life to the renderer.
--
-- What this is, generally: the one loop that touches every live
-- particle every tick. Velocity gives up a little to drag, wanders a
-- little by seeded jitter, moves the particle, and age advances by
-- the tick. Whoever ages past their lifetime is reaped by the pool's
-- swap-with-last.
--
-- Written for LuaJIT's happy path: flat array indexing, no tables
-- born inside the loop, no closures inside the loop. The reap walks
-- BACKWARD because swap-with-last pulls the tail into the current
-- slot — walking forward would skip the swapped-in particle's turn
-- at dying and let it live one tick too long.

local pool = require("006-pool")
local emit = require("008-emit")

local physics = {}

-- The fade curve's shape: how a particle's light rides its life.
-- FADE_POWER above 1 means a fast bright youth and a long ember
-- tail. An aesthetic knob — tuning belongs in docs/balance-updates.md.
local FADE_POWER = 1.5

-- {{{ function physics.tick()
-- Integrate everyone, then reap. Drag is exponential-by-steps
-- (each tick keeps 1 - drag*dt of the velocity), jitter is a seeded
-- shove in a random direction, scaled by the square root of the
-- tick so wander strength does not depend on frame rate.
function physics.tick(p, rng, dt)
    local root_dt = math.sqrt(dt)
    for i = 0, p.live - 1 do
        local keep = 1 - p.drag[i] * dt
        -- heavy drag on a long tick could flip velocity backward,
        -- which reads as vibration; clamping to zero reads as rest
        if keep < 0 then keep = 0 end
        local ang = emit.uniform(rng) * 2 * math.pi
        local shove = p.jitter[i] * root_dt
        p.vx[i] = p.vx[i] * keep + math.cos(ang) * shove
        p.vy[i] = p.vy[i] * keep + math.sin(ang) * shove
        p.x[i] = p.x[i] + p.vx[i] * dt
        p.y[i] = p.y[i] + p.vy[i] * dt
        p.age[i] = p.age[i] + dt
    end
    -- backward, for the reason at the file head
    for i = p.live - 1, 0, -1 do
        if p.age[i] >= p.life[i] then
            pool.kill(p, i)
        end
    end
end
-- }}}

-- {{{ function physics.fade_of()
-- Remaining-life fraction, shaped: young blazes, old embers out.
-- The renderer multiplies light by this; the pool never stores it
-- because it is derived, and derived state stored is state to desync.
function physics.fade_of(p, i)
    local u = p.age[i] / p.life[i]
    if u >= 1 then return 0 end
    return (1 - u) ^ FADE_POWER
end
-- }}}

return physics
