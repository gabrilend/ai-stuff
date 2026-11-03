-- {{{ Ability cue renderer
-- Shows what abilities do, with plain LÖVE shapes and text, from the
-- cues the ability effect system keeps (pop_cues) and the state it and
-- the persistent effects system hold:
--   floating numbers   damage and healing rise and fade over the target,
--                      coloured by kind (physical, magical, true, over
--                      time, healing); a miss shows "miss"
--   melee swings       an arc from the caster toward the target, shaped
--                      by weapon (sword, axe, dagger, spear), wider for
--                      cleaving weapons
--   projectiles        drawn in flight, shaped by visual_effect (arrow,
--                      bolt, stone, javelin, dart)
--   area casts         the circle flashes
--   zones              the circle stays, fading as the zone runs out
--   effects on units   a triangle per buff (up) or debuff (down), a ring
--                      when stunned, a dot per effect over time
--   deaths             a fading cross
-- and plays each cue's sound_effect through a SoundPlayer, when one is
-- given and the file exists.
--
-- Like the mana bar renderer, draw() takes the graphics object to draw
-- with (love.graphics in the game), so it can be checked without a
-- window. Colour is never the only clue: kinds also differ in shape or
-- text.
--
--   AbilityCueRenderer.new(options)
--   renderer:take(cues, entity_manager)   once a frame, with pop_cues()
--   renderer:update(dt)
--   renderer:draw(g, world, view)   world: {entity_manager, effects (the
--                                   effect system), persistent}; view as
--                                   the mana bar renderer's: x, y, zoom
local AbilityCueRenderer = {}
AbilityCueRenderer.__index = AbilityCueRenderer

local WHITE = {1, 1, 1, 1}

AbilityCueRenderer.NUMBER_COLORS = {
    physical = {1, 0.85, 0.6},
    magical = {0.75, 0.55, 1},
    ["true"] = {1, 1, 1},
    over_time = {0.85, 1, 0.4},
    heal = {0.4, 1, 0.5},
    heal_over_time = {0.65, 1, 0.75},
    miss = {0.7, 0.7, 0.7}
}

-- How each projectile looks, by visual_effect: shape, length, width,
-- colour.
AbilityCueRenderer.PROJECTILES = {
    arrow_shot = {shape = "arrow", length = 10, width = 1, color = {0.85, 0.7, 0.45}},
    piercing_arrow = {shape = "arrow", length = 12, width = 2, color = {0.95, 0.85, 0.5}},
    bolt_shot = {shape = "bolt", length = 7, width = 3, color = {0.55, 0.55, 0.6}},
    stone_shot = {shape = "stone", length = 2.5, width = 1, color = {0.6, 0.6, 0.55}},
    javelin_throw = {shape = "javelin", length = 16, width = 2, color = {0.75, 0.6, 0.4}},
    poison_dart = {shape = "dart", length = 5, width = 1, color = {0.5, 0.9, 0.3}},
    default = {shape = "orb", length = 3, width = 1, color = {1, 1, 1}}
}

-- How each weapon swings: arc (radians), reach (share of the distance to
-- the target), colour, and style ("arc", or "thrust" for a straight
-- line).
AbilityCueRenderer.WEAPONS = {
    sword = {style = "arc", arc = 0.9, reach = 0.8, color = {0.85, 0.85, 0.95}},
    axe = {style = "arc", arc = 1.4, reach = 0.85, color = {0.9, 0.55, 0.4}},
    dagger = {style = "arc", arc = 0.5, reach = 0.7, color = {0.8, 0.9, 0.9}},
    spear = {style = "thrust", arc = 0, reach = 1, color = {0.8, 0.75, 0.55}},
    default = {style = "arc", arc = 0.8, reach = 0.8, color = {1, 1, 1}}
}
AbilityCueRenderer.CLEAVE_WIDENING = 1.5

AbilityCueRenderer.ZONE_COLORS = {damage = {1, 0.35, 0.3}, heal = {0.35, 1, 0.45}, status = {0.45, 0.6, 1}}
AbilityCueRenderer.EFFECT_COLORS = {buff = {0.35, 0.85, 1}, debuff = {1, 0.4, 0.35}, stun = {1, 0.9, 0.3},
    damage = {1, 0.3, 0.25}, heal = {0.35, 1, 0.45}}

-- {{{ local function with_alpha
local function with_alpha(color, alpha)
    return {color[1], color[2], color[3], (color[4] or 1) * alpha}
end
-- }}}

-- {{{ AbilityCueRenderer.new
-- options: float_time (1 s), flash_time (0.4 s), swing_time (0.25 s),
-- float_rise (20, distance a number rises), marker_size (4), sound (a
-- SoundPlayer; none plays nothing).
function AbilityCueRenderer.new(options)
    options = options or {}
    local renderer = {
        float_time = options.float_time or 1,
        flash_time = options.flash_time or 0.4,
        swing_time = options.swing_time or 0.25,
        float_rise = options.float_rise or 20,
        marker_size = options.marker_size or 4,
        sound = options.sound,
        floats = {},
        flashes = {},
        swings = {},
        drawn = {}
    }
    return setmetatable(renderer, AbilityCueRenderer)
end
-- }}}

-- {{{ local function position
local function position(entity_manager, entity)
    local pos = entity and entity_manager and entity_manager:get_component(entity, "position")
    if pos then
        return pos.x, pos.y
    end
end
-- }}}

-- {{{ AbilityCueRenderer:take
-- Turns cues into short-lived things to draw, and plays their sounds.
-- entity_manager is used to find a melee caster's position.
function AbilityCueRenderer:take(cues, entity_manager)
    for _, cue in ipairs(cues or {}) do
        local kind = cue.kind
        if kind == "damage" and (cue.amount or 0) > 0 then
            local key = cue.over_time and "over_time" or (cue.damage_type or "physical")
            table.insert(self.floats, {x = cue.x, y = cue.y, text = string.format("%d", math.floor(cue.amount + 0.5)),
                color = AbilityCueRenderer.NUMBER_COLORS[key] or AbilityCueRenderer.NUMBER_COLORS.physical,
                small = cue.over_time, age = 0})
            if not cue.over_time and cue.delivery ~= "projectile" then
                local cx, cy = position(entity_manager, cue.caster)
                if cx and (cx ~= cue.x or cy ~= cue.y) then
                    table.insert(self.swings, {from_x = cx, from_y = cy, to_x = cue.x, to_y = cue.y,
                        weapon = cue.weapon, cleave = cue.cleave, age = 0})
                end
            end
        elseif kind == "heal" and (cue.amount or 0) > 0 then
            table.insert(self.floats, {x = cue.x, y = cue.y, text = string.format("+%d", math.floor(cue.amount + 0.5)),
                color = AbilityCueRenderer.NUMBER_COLORS[cue.over_time and "heal_over_time" or "heal"],
                small = cue.over_time, age = 0})
        elseif kind == "projectile_miss" then
            table.insert(self.floats, {x = cue.x, y = cue.y, text = "miss", color = AbilityCueRenderer.NUMBER_COLORS.miss,
                small = true, age = 0})
        elseif kind == "area" then
            table.insert(self.flashes, {kind = "area", x = cue.x, y = cue.y, radius = cue.radius or 0,
                color = AbilityCueRenderer.ZONE_COLORS[cue.effect == "heal" and "heal" or "damage"], age = 0})
        elseif kind == "death" then
            table.insert(self.flashes, {kind = "death", x = cue.x, y = cue.y, radius = 6, color = WHITE, age = 0})
        end
        if cue.sound and self.sound then
            self.sound:play(cue.sound)
        end
    end
end
-- }}}

-- {{{ local function age_list
local function age_list(list, dt, limit)
    for index = #list, 1, -1 do
        local item = list[index]
        item.age = item.age + dt
        if item.age >= limit then
            table.remove(list, index)
        end
    end
end
-- }}}

-- {{{ AbilityCueRenderer:update
function AbilityCueRenderer:update(dt)
    age_list(self.floats, dt, self.float_time)
    age_list(self.flashes, dt, self.flash_time)
    age_list(self.swings, dt, self.swing_time)
end
-- }}}

-- {{{ AbilityCueRenderer.draw_projectile
-- One projectile at screen point (sx, sy), heading (dx, dy).
function AbilityCueRenderer.draw_projectile(g, look, sx, sy, dx, dy, zoom)
    local length = look.length * zoom
    local tail_x, tail_y = sx - dx * length, sy - dy * length
    g.setColor(look.color)
    g.setLineWidth(look.width)
    if look.shape == "stone" or look.shape == "orb" then
        g.circle("fill", sx, sy, length)
    else
        g.line(tail_x, tail_y, sx, sy)
        if look.shape == "arrow" or look.shape == "javelin" then
            -- A head: two short strokes back from the tip.
            local head = 3 * zoom
            local px, py = -dy, dx
            g.line(sx, sy, sx - dx * head + px * head * 0.6, sy - dy * head + py * head * 0.6)
            g.line(sx, sy, sx - dx * head - px * head * 0.6, sy - dy * head - py * head * 0.6)
        elseif look.shape == "bolt" then
            g.circle("fill", sx, sy, look.width * zoom * 0.6)
        end
    end
    g.setLineWidth(1)
end
-- }}}

-- {{{ AbilityCueRenderer:draw_swing
function AbilityCueRenderer:draw_swing(g, swing, to_screen, zoom)
    local look = AbilityCueRenderer.WEAPONS[swing.weapon] or AbilityCueRenderer.WEAPONS.default
    local fade = 1 - swing.age / self.swing_time
    local fx, fy = to_screen(swing.from_x, swing.from_y)
    local tx, ty = to_screen(swing.to_x, swing.to_y)
    local dx, dy = tx - fx, ty - fy
    local distance = math.sqrt(dx * dx + dy * dy)
    g.setColor(with_alpha(look.color, fade))
    g.setLineWidth(2)
    if look.style == "thrust" then
        g.line(fx, fy, fx + dx * look.reach, fy + dy * look.reach)
    else
        local arc = look.arc * (swing.cleave and AbilityCueRenderer.CLEAVE_WIDENING or 1)
        local angle = math.atan2 and math.atan2(dy, dx) or math.atan(dy, dx)
        -- The arc sweeps across as the swing ages.
        local sweep = arc * math.min(1, swing.age / self.swing_time * 2)
        g.arc("line", "open", fx, fy, math.max(2 * zoom, distance * look.reach), angle - arc / 2,
            angle - arc / 2 + math.max(sweep, 0.05))
    end
    g.setLineWidth(1)
end
-- }}}

-- {{{ AbilityCueRenderer:draw_markers
-- Effects on one unit, in a row above it.
function AbilityCueRenderer:draw_markers(g, effects, ticking, sx, sy, zoom)
    local size = self.marker_size * math.max(0.75, math.min(2, zoom))
    local names = {}
    for name in pairs(effects and effects.active or {}) do
        table.insert(names, name)
    end
    table.sort(names)
    local count = #names + #ticking
    if count == 0 then
        return 0
    end
    local x = sx - (count - 1) * size * 1.5 / 2
    local y = sy - 22 * zoom
    for _, name in ipairs(names) do
        local effect = effects.active[name]
        if effect.stun then
            g.setColor(AbilityCueRenderer.EFFECT_COLORS.stun)
            g.circle("line", sx, sy, 10 * zoom)
        end
        local color = AbilityCueRenderer.EFFECT_COLORS[effect.kind == "buff" and "buff" or "debuff"]
        g.setColor(color)
        if effect.kind == "buff" then
            g.polygon("fill", x, y - size / 2, x - size / 2, y + size / 2, x + size / 2, y + size / 2)
        else
            g.polygon("fill", x, y + size / 2, x - size / 2, y - size / 2, x + size / 2, y - size / 2)
        end
        if (effect.stacks or 1) > 1 then
            g.print("x" .. effect.stacks, x + size / 2, y - size)
        end
        x = x + size * 1.5
    end
    for _, tick in ipairs(ticking) do
        g.setColor(AbilityCueRenderer.EFFECT_COLORS[tick.kind == "heal" and "heal" or "damage"])
        g.circle("fill", x, y, size / 2)
        x = x + size * 1.5
    end
    return count
end
-- }}}

-- {{{ AbilityCueRenderer:draw
-- Draws everything, zones first and numbers last. Returns the counts
-- drawn, also kept as self.drawn: {zones, flashes, projectiles, swings,
-- markers, floats}.
function AbilityCueRenderer:draw(g, world, view)
    world, view = world or {}, view or {}
    local zoom = view.zoom or 1
    local left, top = view.x or 0, view.y or 0
    local function to_screen(x, y)
        return (x - left) * zoom, (y - top) * zoom
    end
    local drawn = {zones = 0, flashes = 0, projectiles = 0, swings = 0, markers = 0, floats = 0}

    if world.persistent then
        for _, zone in ipairs(world.persistent:get_zones()) do
            local sx, sy = to_screen(zone.x, zone.y)
            local color = AbilityCueRenderer.ZONE_COLORS[zone.effect] or AbilityCueRenderer.ZONE_COLORS.status
            g.setColor(with_alpha(color, 0.15 * zone.fraction))
            g.circle("fill", sx, sy, zone.radius * zoom)
            g.setColor(with_alpha(color, 0.3 + 0.6 * zone.fraction))
            g.circle("line", sx, sy, zone.radius * zoom)
            drawn.zones = drawn.zones + 1
        end
    end

    for _, flash in ipairs(self.flashes) do
        local sx, sy = to_screen(flash.x, flash.y)
        local fade = 1 - flash.age / self.flash_time
        g.setColor(with_alpha(flash.color, fade))
        if flash.kind == "death" then
            local r = flash.radius * zoom
            g.line(sx - r, sy - r, sx + r, sy + r)
            g.line(sx - r, sy + r, sx + r, sy - r)
        else
            g.circle("line", sx, sy, flash.radius * zoom)
            g.setColor(with_alpha(flash.color, 0.25 * fade))
            g.circle("fill", sx, sy, flash.radius * zoom)
        end
        drawn.flashes = drawn.flashes + 1
    end

    if world.effects then
        for _, projectile in ipairs(world.effects.projectiles or {}) do
            local look = AbilityCueRenderer.PROJECTILES[projectile.ability and projectile.ability.visual_effect]
                or AbilityCueRenderer.PROJECTILES.default
            local sx, sy = to_screen(projectile.x, projectile.y)
            AbilityCueRenderer.draw_projectile(g, look, sx, sy, projectile.dir_x, projectile.dir_y, zoom)
            drawn.projectiles = drawn.projectiles + 1
        end
    end

    for _, swing in ipairs(self.swings) do
        self:draw_swing(g, swing, to_screen, zoom)
        drawn.swings = drawn.swings + 1
    end

    local em = world.entity_manager
    if em then
        for _, entity in ipairs(em:get_entities_with_components({"position"})) do
            local health = em:get_component(entity, "health")
            if not health or (health.alive ~= false and health.current_hp > 0) then
                local effects = em:get_component(entity, "effects")
                local ticking = world.persistent and world.persistent:get_effects_on(entity) or {}
                local pos = em:get_component(entity, "position")
                local sx, sy = to_screen(pos.x, pos.y)
                drawn.markers = drawn.markers + self:draw_markers(g, effects, ticking, sx, sy, zoom)
            end
        end
    end

    for _, float in ipairs(self.floats) do
        local progress = float.age / self.float_time
        local sx, sy = to_screen(float.x, float.y)
        g.setColor(with_alpha(float.color, 1 - progress))
        local scale = float.small and 0.8 or 1
        g.print(float.text, sx, sy - 10 * zoom - progress * self.float_rise * zoom, 0, scale, scale)
        drawn.floats = drawn.floats + 1
    end

    g.setColor(WHITE)
    self.drawn = drawn
    return drawn
end
-- }}}

return AbilityCueRenderer
-- }}}
