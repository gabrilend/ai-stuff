--[[
Drawing Effects and Missiles (Issue 530)

The map viewer's side of demo/wc3map/effects.lua: each effect and
missile drawn with its model (the asset source's: the map's, then the
install's), playing Birth, then Stand, and Death once destroyed; effects
on units sit at the unit model's attachment point (its "Overhead Ref",
"Origin Ref", "Chest Ref" ... node, in the model's rest pose), else at a
height by name. Where a model isn't found, a small marker stands in: a
ring coloured by what the effect is (gold caster, red target, violet buff,
blue area and effect, white the script's), an arrow for a missile.

    local draw_effects = require("demo.wc3map.draw_effects").new(render, model_cache, A)
    draw_effects:draw(game, cx, cy, reach, dt, add_prims, unit_model)
]]

local anim = require("assets.anim")
local figures = require("geometry.figures")

local D = {}
D.__index = D

local draw_effects = {}

-- heights for attachment points when the unit has no model
draw_effects.HEIGHTS = { overhead = 200, head = 110, chest = 70, origin = 5, hand = 70, weapon = 70, foot = 5,
                         sprite = 90, medium = 60, large = 100 }
draw_effects.COLORS = { caster = { 240, 200, 80 }, target = { 230, 70, 60 }, buff = { 190, 110, 240 },
                        effect = { 90, 160, 250 }, area = { 90, 160, 250 }, script = { 235, 235, 235 } }

function draw_effects.new(render, model_cache, A)
    return setmetatable({ render = render, cache = model_cache, A = A, models = {} }, D)
end

-- {{{ models by path
function D:model(path)
    local v = self.models[path]
    if v == nil then
        v = false
        if self.A and self.cache then
            local m = self.A:model(path)
            local id = m and self.cache:build(m, path)
            if id then v = { id = id, rig = self.cache:rig(id) } end
        end
        self.models[path] = v
    end
    return v or nil
end
-- }}}

-- {{{ attachment points
-- (dx, dy, dz) from a unit's position to an attachment point
local function attach_offset(u, attach, m, scale, rig)
    attach = (attach or "origin"):lower():gsub(",", " ")
    if m and m.attachments then
        for _, node in ipairs(m.attachments) do
            local name = (node.name or ""):lower():gsub("%s*ref%s*$", "")
            if name == attach or name:sub(1, #attach) == attach then
                -- where the unit's animation has it now (issue 538), else
                -- its rest place
                local p = rig and u.anim and anim.attachment(rig, u.anim, node.id) or m.pivots[node.id + 1]
                if p then
                    local f = u.facing or 0
                    local c, s = math.cos(f), math.sin(f)
                    return (p[1] * c - p[2] * s) * scale, (p[1] * s + p[2] * c) * scale, p[3] * scale
                end
            end
        end
    end
    local first = attach:match("^(%a+)")
    return 0, 0, draw_effects.HEIGHTS[first] or 60
end
draw_effects.attach_offset = attach_offset
-- }}}

-- {{{ draw_effects.bolt
-- A lightning bolt as quads: a jagged line from (x1, y1, z1) to (x2, y2, z2)
-- in segments of about seg, each bend thrown sideways by up to a fifth
-- of the segment; crossed ribbons so it reads from any angle (three quads
-- a segment). The
-- bends change every tenth of a second (seed and time)
function draw_effects.bolt(x1, y1, z1, x2, y2, z2, width, seg, color, seed, time)
    local dx, dy, dz = x2 - x1, y2 - y1, z2 - z1
    local len = math.sqrt(dx * dx + dy * dy + dz * dz)
    if len < 1 then return {} end
    local n = math.max(2, math.min(48, math.floor(len / math.max(8, seg or 64) + 0.5)))
    -- sideways (horizontal) and up, across the bolt
    local hx, hy = -dy, dx
    local hl = math.sqrt(hx * hx + hy * hy)
    if hl < 1e-6 then hx, hy, hl = 1, 0, 1 end
    hx, hy = hx / hl, hy / hl
    local tick = math.floor((time or 0) * 10)
    local function noise(i, k)
        local v = math.sin((seed or 1) * 12.9898 + i * 78.233 + k * 37.719 + tick * 3.1) * 43758.5453
        return (v - math.floor(v)) * 2 - 1
    end
    local amp = len / n / 5
    local pts = {}
    for i = 0, n do
        local f = i / n
        local side, up = 0, 0
        if i > 0 and i < n then side, up = noise(i, 1) * amp, noise(i, 2) * amp end
        pts[i] = { x1 + dx * f + hx * side, y1 + dy * f + hy * side, z1 + dz * f + up }
    end
    local w = (width or 20) / 3
    local list = {}
    for i = 0, n - 1 do
        local a, b = pts[i], pts[i + 1]
        -- (wound as the other figures' quads: faces up, and the upright
        -- ribbon both ways, so it shows from either side)
        list[#list + 1] = { kind = "quad", color = color, pts = {
            { a[1] + hx * w, a[2] + hy * w, a[3] }, { b[1] + hx * w, b[2] + hy * w, b[3] },
            { b[1] - hx * w, b[2] - hy * w, b[3] }, { a[1] - hx * w, a[2] - hy * w, a[3] } } }
        list[#list + 1] = { kind = "quad", color = color, pts = {
            { a[1], a[2], a[3] - w }, { b[1], b[2], b[3] - w }, { b[1], b[2], b[3] + w }, { a[1], a[2], a[3] + w } } }
        list[#list + 1] = { kind = "quad", color = color, pts = {
            { a[1], a[2], a[3] + w }, { b[1], b[2], b[3] + w }, { b[1], b[2], b[3] - w }, { a[1], a[2], a[3] - w } } }
    end
    return list
end
-- }}}

-- {{{ D:draw
-- unit_model(u) -> the unit's parsed MDX and scale, or nil
function D:draw(g, cx, cy, reach, dt, add_prims, unit_model)
    local render = self.render
    for _, fx in ipairs(g.effects or {}) do
        if fx.x and math.abs(fx.x - cx) < reach and math.abs(fx.y - cy) < reach then
            local x, y, z = fx.x, fx.y, fx.z or 0
            if fx.unit then
                local m, scale, rig = nil, 1, nil
                if unit_model then m, scale, rig = unit_model(fx.unit) end
                local dx, dy, dz = attach_offset(fx.unit, fx.attach, m, scale or 1, rig)
                x, y, z = fx.unit.x + dx, fx.unit.y + dy, (fx.unit.z or 0) + dz
            end
            local mod = self:model(fx.path)
            if mod then
                local st = fx.anim
                local pose
                if mod.rig then
                    if not st then
                        st = anim.state()
                        fx.anim = st
                        if not anim.play(mod.rig, st, "birth") then anim.play(mod.rig, st, "stand") end
                    end
                    if fx.dying then
                        anim.play(mod.rig, st, "death", { fallback = "stand" })
                    elseif st.name == "birth" and st.done then
                        anim.play(mod.rig, st, "stand")
                    end
                    anim.step(mod.rig, st, dt)
                    pose = anim.pose(mod.rig, st)
                end
                -- a destroyed effect without a Death is gone at once
                if not (fx.dying and st and st.name ~= "death") then
                    render.model_draw(mod.id, x, y, z, fx.facing or 0, fx.scale or 1, 255, 255, 255, 1, pose)
                end
            elseif not fx.dying then
                local c = draw_effects.COLORS[fx.kind or "script"] or draw_effects.COLORS.script
                add_prims(figures.ring(x, y, z + 4, 22, c, 12, 4))
            end
        end
    end
    -- lightning (issue 538)
    for _, l in ipairs(g.lightnings or {}) do
        local x1, y1, z1, x2, y2, z2 = g.lightning_ends(l)
        if math.abs(x1 - cx) < reach and math.abs(y1 - cy) < reach then
            local function c(v) return math.max(0, math.min(255, math.floor((v or 1) * 255 + 0.5))) end
            add_prims(draw_effects.bolt(x1, y1, z1, x2, y2, z2, l.type.width, l.type.seg,
                { c(l.r), c(l.g), c(l.b) }, l.seed, g.time))
        end
    end
    for _, m in ipairs(g.missiles or {}) do
        if math.abs(m.x - cx) < reach and math.abs(m.y - cy) < reach then
            local mod = m.path and self:model(m.path)
            if mod then
                local st = m.anim
                if mod.rig and not st then
                    st = anim.state()
                    m.anim = st
                    anim.play(mod.rig, st, "stand")
                end
                if mod.rig then anim.step(mod.rig, st, dt) end
                render.model_draw(mod.id, m.x, m.y, m.z, m.facing or 0, 1, 255, 255, 255, 1,
                    mod.rig and anim.pose(mod.rig, st) or nil)
            else
                local f = m.facing or 0
                add_prims(figures.arrow(m.x, m.y, m.z, math.cos(f), math.sin(f), 0))
            end
        end
    end
end
-- }}}

return draw_effects
