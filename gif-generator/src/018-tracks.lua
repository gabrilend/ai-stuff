-- 018-tracks.lua — the track and the timeline: one stroke's complete
-- instructions, and the list the simulator walks each tick.
--
-- What this is, generally: a track binds an activation window (start
-- and duration in seconds), a motion easing, a fade envelope, a path,
-- and an emitter recipe. Asked about a frame time it answers either
-- "inactive" or "here is my tip, my heading, and how strongly I am
-- emitting". The timeline is just the array of tracks plus the one
-- step that runs a whole simulation tick: every active track emits,
-- then physics moves everyone.
--
-- Design notes worth knowing more than once:
--   * sequencing is nothing but windows — "after the sweep" means a
--     start time equal to the sweep's end. The timeline is dumb
--     about causality on purpose: all ordering became numbers at
--     compile time, so the runtime never resolves a dependency.
--   * each track carries its own emit_tick closure, assigned by its
--     builder. Spot tracks (this file) emit from the moving tip;
--     field tracks (the fills module) emit across a region. The
--     step never asks which kind it holds — uniform records instead
--     of a type switch.
--   * the window is half-open: active at its first instant,
--     inactive at exactly start + duration. Two windows meeting at
--     one number hand off with neither a gap nor a doubled tick.

local emit = require("008-emit")
local physics = require("010-physics")

local tracks = {}

-- {{{ function tracks.track()
-- A spot track: an emitter riding a path's tip.
-- spec: { name, from, lasts, ease (fn), envelope (fn), path,
--         recipe }
function tracks.track(spec)
    if spec.lasts <= 0 then
        error("tracks: '" .. tostring(spec.name) .. "' lasts "
              .. tostring(spec.lasts) .. " seconds — a stroke must "
              .. "take time; an instant of paint is a point in a "
              .. "picture that moves")
    end
    local tr = {
        name = spec.name,
        from = spec.from,
        lasts = spec.lasts,
        ease = spec.ease,
        envelope = spec.envelope,
        path = spec.path,
        recipe = spec.recipe,
        carry = 0,
    }
    -- {{{ tr.emit_tick()
    -- one tick of this stroke's paint: eased tip, enveloped strength
    tr.emit_tick = function(p, rng, u, dt)
        local progress = tr.ease(u)
        local x, y = tr.path.at(progress)
        local hx, hy = tr.path.heading(progress)
        local strength = tr.envelope(u)
        tr.carry = emit.step(p, rng, tr.recipe, tr.name,
                             x, y, hx, hy, strength, dt, tr.carry)
    end
    -- }}}
    return tr
end
-- }}}

-- {{{ function tracks.where()
-- Interrogation without consequence: where is this track at time t,
-- and how strongly is it speaking? nil when inactive. Tests and
-- viewers use this; the step uses emit_tick.
function tracks.where(tr, t)
    local u = tracks.window(tr, t)
    if not u then return nil end
    local progress = tr.ease(u)
    local x, y = tr.path.at(progress)
    local hx, hy = tr.path.heading(progress)
    return x, y, hx, hy, tr.envelope(u)
end
-- }}}

-- {{{ function tracks.window()
-- The half-open window: raw time-fraction in [0,1), or nil.
function tracks.window(tr, t)
    if t < tr.from or t >= tr.from + tr.lasts then return nil end
    return (t - tr.from) / tr.lasts
end
-- }}}

-- {{{ function tracks.endpoint()
-- Where this stroke's journey ends — the landmark later strokes
-- borrow ("from the left hand's tip"). Ease(1) is 1 by the easing
-- contract, so the endpoint is simply the path's end.
function tracks.endpoint(tr)
    return tr.path.at(1)
end
-- }}}

-- {{{ function tracks.timeline()
-- The array the simulator walks, plus the render-wide constant
-- force (a scene's gravity, if its strokes want one — zero when
-- unspoken, explicitly).
function tracks.timeline(list, fx, fy)
    return { tracks = list, fx = fx, fy = fy }
end
-- }}}

-- {{{ function tracks.step()
-- One whole simulation tick at time t: every active track paints,
-- then physics moves the world. The order (emit, then move) means a
-- particle born this tick takes its first step this tick — birth
-- and motion share the frame, which keeps tips from stuttering.
function tracks.step(tl, p, rng, t, dt)
    for _, tr in ipairs(tl.tracks) do
        local u = tracks.window(tr, t)
        if u then
            tr.emit_tick(p, rng, u, dt)
        end
    end
    physics.tick(p, rng, dt, tl.fx, tl.fy)
end
-- }}}

return tracks
