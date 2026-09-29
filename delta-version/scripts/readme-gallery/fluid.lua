-- fluid.lua - a small liquid sloshing in an invisible box, worked out ahead.
--
-- What this is, generally: a handful of liquid drops (particles) poured into
-- a box nobody sees. The box tilts back and forth; gravity pulls the drops
-- down the tilt; each drop pushes away any neighbour that crowds it and
-- drags a little on neighbours moving differently (a thick, syrupy liquid);
-- the walls stop them. Step by step that makes the liquid slosh. This file
-- only works out where every drop is in every frame. Drawing them -- as soft
-- blobs that melt into a surface -- is the painter's job, not this file's.
--
-- Why the loop is seamless even though a simulation never repeats itself:
-- the box's tilting repeats exactly once per loop, so after a few loops the
-- sloshing settles into nearly repeating. The liquid is run for `warmup`
-- loops to get there, then two more loops (and a little) are recorded. Among
-- the first recorded loop's frames, the one whose drops sit closest to where
-- the same drops sit one whole loop later is chosen as the film's first
-- frame. The film is then that loop of frames; over its first `blend`
-- frames each drop glides from where it will be one loop on (continuing
-- straight out of the film's last frame) to where it is now, so the join
-- never jumps. The trade: for those few frames the drops' paths are blended,
-- not simulated -- a little less true, never seen as a jump.
--
-- Data formats:
--   spec (scene.fluid) = {
--     count, seed, radius,              -- drops, their placement recipe, size
--     box = {x, y, z},                  -- inside half-widths of the container
--     tilt = { axis = {x,y,z}, amount = radians, cycles = whole },
--     gravity, stiffness, drag,         -- the liquid's feel
--     substeps, warmup, blend           -- steps per frame, loops to settle,
--   }                                   -- frames blended at the join
--   result = { frames = { [i] = { {x,y,z}, ... } (box's own frame) },
--              start = first chosen frame's index in the recording,
--              seam  = how far (on average, per drop) the chosen frame was
--                      from its match one loop on }

local fluid = {}

local TAU = 2 * math.pi

-- {{{ local function tilt_matrix()
-- The box's turn at loop moment t (rows): a rock about `axis`.
local function tilt_matrix(tilt, t)
    local angle = tilt.amount * math.sin(TAU * tilt.cycles * t)
    local ax = tilt.axis
    local len = math.sqrt(ax[1] ^ 2 + ax[2] ^ 2 + ax[3] ^ 2)
    local x, y, z = ax[1] / len, ax[2] / len, ax[3] / len
    local c, s = math.cos(angle), math.sin(angle)
    local k = 1 - c
    return {
        { c + x * x * k, x * y * k - z * s, x * z * k + y * s },
        { y * x * k + z * s, c + y * y * k, y * z * k - x * s },
        { z * x * k - y * s, z * y * k + x * s, c + z * z * k },
    }
end
fluid.tilt_matrix = tilt_matrix
-- }}}

-- {{{ local function seeded()
local function seeded(seed)
    local state = seed % 2147483647
    if state <= 0 then state = state + 2147483646 end
    return function()
        state = (state * 16807) % 2147483647
        return (state - 1) / 2147483646
    end
end
-- }}}

-- {{{ function fluid.simulate()
-- Runs the liquid and returns the film's frames (see the file head).
-- `frames` is the scene's frame count: one loop.
function fluid.simulate(spec, frames)
    local n, r = spec.count, spec.radius
    local hx, hy, hz = spec.box[1] - r, spec.box[2] - r, spec.box[3] - r
    local g, stiff, drag = spec.gravity or 9, spec.stiffness or 60, spec.drag or 1.2
    local substeps = spec.substeps or 6
    local dt = 1 / (frames * substeps) * (spec.time_scale or 6)
    local h = 2 * r                          -- drops closer than this push apart
    local random = seeded(spec.seed or 1)

    -- pour the drops in: a loose lattice in the lower half, jostled a little
    local px, py, pz, vx, vy, vz = {}, {}, {}, {}, {}, {}
    local side = math.ceil((n) ^ (1 / 3)) + 1
    for i = 1, n do
        local a, b, c = (i - 1) % side, math.floor((i - 1) / side) % side, math.floor((i - 1) / (side * side))
        px[i] = -hx + (a + 0.5) * (2 * hx / side) + (random() - 0.5) * 0.05
        pz[i] = -hz + (b + 0.5) * (2 * hz / side) + (random() - 0.5) * 0.05
        py[i] = -hy + (c + 0.5) * h * 0.9 + (random() - 0.5) * 0.05
        vx[i], vy[i], vz[i] = 0, 0, 0
    end

    -- {{{ local function step()
    -- One small step at loop moment t: gravity as the tilted box feels it,
    -- crowding pushes and syrupy drag between neighbours (found through a
    -- grid of cells one push-distance wide), then walls.
    local function step(t)
        local m = tilt_matrix(spec.tilt, t)
        -- world "down" (0,-g,0) seen from inside the box: the box's own
        -- directions are the rows of its turn, so down in box terms is the
        -- second column, negated
        local gx, gy, gz = -g * m[2][1], -g * m[2][2], -g * m[2][3]
        local cells = {}
        for i = 1, n do
            local key = math.floor(px[i] / h) * 73856093 + math.floor(py[i] / h) * 19349663 + math.floor(pz[i] / h) * 83492791
            local list = cells[key]
            if not list then list = {}; cells[key] = list end
            list[#list + 1] = i
        end
        local ax, ay, az = {}, {}, {}
        for i = 1, n do ax[i], ay[i], az[i] = gx, gy, gz end
        for i = 1, n do
            local cx, cy, cz = math.floor(px[i] / h), math.floor(py[i] / h), math.floor(pz[i] / h)
            for ox = -1, 1 do for oy = -1, 1 do for oz = -1, 1 do
                local list = cells[(cx + ox) * 73856093 + (cy + oy) * 19349663 + (cz + oz) * 83492791]
                if list then
                    for _, j in ipairs(list) do
                        if j > i then
                            local dx, dy, dz = px[j] - px[i], py[j] - py[i], pz[j] - pz[i]
                            local d2 = dx * dx + dy * dy + dz * dz
                            if d2 < h * h and d2 > 1e-12 then
                                local d = math.sqrt(d2)
                                local nx, ny, nz = dx / d, dy / d, dz / d
                                local push = stiff * (h - d)
                                local rel = (vx[j] - vx[i]) * nx + (vy[j] - vy[i]) * ny + (vz[j] - vz[i]) * nz
                                local f = push - drag * rel
                                ax[i], ay[i], az[i] = ax[i] - nx * f, ay[i] - ny * f, az[i] - nz * f
                                ax[j], ay[j], az[j] = ax[j] + nx * f, ay[j] + ny * f, az[j] + nz * f
                            end
                        end
                    end
                end
            end end end
        end
        for i = 1, n do
            vx[i], vy[i], vz[i] = vx[i] + ax[i] * dt, vy[i] + ay[i] * dt, vz[i] + az[i] * dt
            px[i], py[i], pz[i] = px[i] + vx[i] * dt, py[i] + vy[i] * dt, pz[i] + vz[i] * dt
            -- walls: stop at the inside face, keep a little of the bounce
            if px[i] < -hx then px[i] = -hx; vx[i] = -vx[i] * 0.3 elseif px[i] > hx then px[i] = hx; vx[i] = -vx[i] * 0.3 end
            if py[i] < -hy then py[i] = -hy; vy[i] = -vy[i] * 0.3 elseif py[i] > hy then py[i] = hy; vy[i] = -vy[i] * 0.3 end
            if pz[i] < -hz then pz[i] = -hz; vz[i] = -vz[i] * 0.3 elseif pz[i] > hz then pz[i] = hz; vz[i] = -vz[i] * 0.3 end
        end
    end
    -- }}}

    -- settle for `warmup` whole loops, then record two loops and the blend
    local warm = (spec.warmup or 3) * frames
    local blend = spec.blend or 8
    local total = warm + 2 * frames + blend
    local recorded = {}
    for frame = 0, total - 1 do
        for s = 0, substeps - 1 do
            step((frame + s / substeps) / frames)
        end
        if frame >= warm then
            local snapshot = {}
            for i = 1, n do snapshot[i] = { px[i], py[i], pz[i] } end
            recorded[frame - warm] = snapshot
        end
    end

    -- {{{ local function gap()
    -- How far apart two recorded frames are, on average per drop.
    local function gap(a, b)
        local sum = 0
        for i = 1, n do
            local p, q = recorded[a][i], recorded[b][i]
            sum = sum + math.sqrt((p[1] - q[1]) ^ 2 + (p[2] - q[2]) ^ 2 + (p[3] - q[3]) ^ 2)
        end
        return sum / n
    end
    -- }}}
    local start, best = 0, math.huge
    for a = 0, frames - 1 do
        local d = gap(a, a + frames)
        if d < best then start, best = a, d end
    end

    -- the film: one loop from `start`, its first `blend` frames gliding from
    -- where each drop will be one loop on toward where it is
    local out = {}
    for i = 0, frames - 1 do
        local here = recorded[start + i]
        if i < blend then
            local later = recorded[start + frames + i]
            local w = (i + 0.5) / blend
            w = w * w * (3 - 2 * w)
            local mixed = {}
            for k = 1, n do
                local p, q = later[k], here[k]
                mixed[k] = { p[1] + (q[1] - p[1]) * w, p[2] + (q[2] - p[2]) * w, p[3] + (q[3] - p[3]) * w }
            end
            out[i] = mixed
        else
            out[i] = here
        end
    end
    return { frames = out, start = start, seam = best }
end
-- }}}

return fluid
