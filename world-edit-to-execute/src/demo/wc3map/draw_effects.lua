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
local function attach_offset(u, attach, m, scale)
    attach = (attach or "origin"):lower():gsub(",", " ")
    if m and m.attachments then
        for _, node in ipairs(m.attachments) do
            local name = (node.name or ""):lower():gsub("%s*ref%s*$", "")
            if name == attach or name:sub(1, #attach) == attach then
                local p = m.pivots[node.id + 1]
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

-- {{{ D:draw
-- unit_model(u) -> the unit's parsed MDX and scale, or nil
function D:draw(g, cx, cy, reach, dt, add_prims, unit_model)
    local render = self.render
    for _, fx in ipairs(g.effects or {}) do
        if fx.x and math.abs(fx.x - cx) < reach and math.abs(fx.y - cy) < reach then
            local x, y, z = fx.x, fx.y, fx.z or 0
            if fx.unit then
                local m, scale = nil, 1
                if unit_model then m, scale = unit_model(fx.unit) end
                local dx, dy, dz = attach_offset(fx.unit, fx.attach, m, scale or 1)
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
