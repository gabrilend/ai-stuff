-- {{{ Mana bar renderer
-- Draws each unit's mana bars above it with plain shapes: one thin bar
-- per ability, the primary on top and a little taller. Colour is never
-- the only clue, as the vision asks of the whole game:
--   colour   the ability's type (ManaSystem.TYPE_COLORS)
--   pattern  drawn over the fill: damage diagonal lines, heal a cross
--            hatch, buff dots, debuff upright lines, area a centre line
--   shape    a small mark right of the bar: damage a triangle, heal a
--            cross, buff a plus over a bar, debuff a minus, area a ring
-- and the bar's state:
--   ready      a white border that pulses
--   charging   a bright tick at the edge of the fill
--   waiting    a dark cover over the part of the bar still cooling down
--   kept mana  after a cast that spent only part of the bar (mana
--              efficiency), the part kept is outlined for a moment
--
-- Detail follows the zoom: at 1 or more, everything; from 0.5, plain
-- bars; below that, one dot per ability, filled when ready. Bars grow
-- and shrink with the zoom within limits, and units off screen are
-- skipped.
--
-- draw() takes the graphics object to draw with (love.graphics in the
-- game), so the drawing can be checked without a window.
local ManaBarRenderer = {}
ManaBarRenderer.__index = ManaBarRenderer

local ManaSystem = require("src.systems.mana_system")

ManaBarRenderer.PATTERNS = {
    damage = "diagonal",
    heal = "cross_hatch",
    buff = "dots",
    debuff = "vertical",
    area = "centre_line"
}

local WHITE = {1, 1, 1, 1}
local BACKGROUND = {0.1, 0.1, 0.1, 0.75}
local COOLDOWN_COVER = {0, 0, 0, 0.6}

-- {{{ ManaBarRenderer.new
-- options: bar_width (24), bar_height (3), spacing (1), offset_y (-14,
-- from the unit's centre to the bottom bar), kept_time (0.6 s), and
-- the zoom thresholds high_detail_zoom (1) and low_detail_zoom (0.5).
function ManaBarRenderer.new(options)
    options = options or {}
    local renderer = {
        bar_width = options.bar_width or 24,
        bar_height = options.bar_height or 3,
        spacing = options.spacing or 1,
        offset_y = options.offset_y or -14,
        kept_time = options.kept_time or 0.6,
        high_detail_zoom = options.high_detail_zoom or 1,
        low_detail_zoom = options.low_detail_zoom or 0.5,
        min_scale = 0.75,
        max_scale = 2,
        time = 0,
        kept = {},             -- entity -> {index, from, to, time}
        drawn_last = 0         -- units drawn in the last draw()
    }
    return setmetatable(renderer, ManaBarRenderer)
end
-- }}}

-- {{{ ManaBarRenderer:update
function ManaBarRenderer:update(dt)
    self.time = self.time + dt
    for entity, mark in pairs(self.kept) do
        if self.time - mark.time > self.kept_time then
            self.kept[entity] = nil
        end
    end
end
-- }}}

-- {{{ ManaBarRenderer:notice
-- Shows mana efficiency: given an activation event (from the activation
-- system), outlines the mana the cast kept in its bar for kept_time.
function ManaBarRenderer:notice(event)
    local bar_max = event.ability and event.ability.max_mana or 0
    if bar_max <= 0 or not event.mana_spent or event.mana_spent >= bar_max - 1e-9 then
        return
    end
    self.kept[event.caster] = {
        index = event.index,
        to = (bar_max - event.mana_spent) / bar_max,
        time = self.time
    }
end
-- }}}

-- {{{ ManaBarRenderer:detail_for
function ManaBarRenderer:detail_for(zoom)
    if zoom >= self.high_detail_zoom then
        return "high"
    elseif zoom >= self.low_detail_zoom then
        return "medium"
    end
    return "low"
end
-- }}}

-- {{{ ManaBarRenderer:pulse
-- 0.6 to 1, twice a second, for ready bars.
function ManaBarRenderer:pulse()
    return 0.8 + 0.2 * math.sin(self.time * math.pi * 4)
end
-- }}}

-- {{{ local function with_alpha
local function with_alpha(color, alpha)
    return {color[1], color[2], color[3], (color[4] or 1) * alpha}
end
-- }}}

-- {{{ ManaBarRenderer.draw_pattern
-- Lines over a fill, in a faint white, so types differ without colour.
function ManaBarRenderer.draw_pattern(g, pattern, x, y, width, height)
    if width <= 0 then
        return
    end
    g.setColor(1, 1, 1, 0.35)
    if pattern == "diagonal" then
        for i = 0, width - 1, 3 do
            g.line(x + i, y + height, x + math.min(width, i + height), y)
        end
    elseif pattern == "cross_hatch" then
        for i = 0, width, 3 do
            g.line(x + i, y, x + i, y + height)
        end
        g.line(x, y + height / 2, x + width, y + height / 2)
    elseif pattern == "dots" then
        for i = 1, width - 1, 3 do
            g.points(x + i, y + height / 2)
        end
    elseif pattern == "vertical" then
        for i = 1, width - 1, 2 do
            g.line(x + i, y, x + i, y + height)
        end
    elseif pattern == "centre_line" then
        g.line(x, y + height / 2, x + width, y + height / 2)
    end
end
-- }}}

-- {{{ ManaBarRenderer.draw_shape
-- The type's mark, centred at (cx, cy), `size` across.
function ManaBarRenderer.draw_shape(g, kind, cx, cy, size)
    local r = size / 2
    g.setColor(WHITE)
    if kind == "damage" then
        g.polygon("fill", cx, cy - r, cx + r, cy + r, cx - r, cy + r)
    elseif kind == "heal" then
        g.line(cx - r, cy - r, cx + r, cy + r)
        g.line(cx - r, cy + r, cx + r, cy - r)
    elseif kind == "buff" then
        g.line(cx - r, cy, cx + r, cy)
        g.line(cx, cy - r, cx, cy + r)
    elseif kind == "debuff" then
        g.line(cx - r, cy, cx + r, cy)
    elseif kind == "area" then
        g.circle("line", cx, cy, r)
    else
        g.rectangle("fill", cx - r, cy - r, size, size)
    end
end
-- }}}

-- {{{ ManaBarRenderer:draw_bar
function ManaBarRenderer:draw_bar(g, bar, index, x, y, width, height, detail, cooldown_fraction, kept)
    local fraction = math.max(0, math.min(1, bar.current / bar.max))
    local ready = fraction >= 1 - 1e-9
    local color = ManaSystem.TYPE_COLORS[bar.type] or WHITE

    g.setColor(BACKGROUND)
    g.rectangle("fill", x, y, width, height)
    g.setColor(with_alpha(color, ready and self:pulse() or 0.85))
    g.rectangle("fill", x, y, width * fraction, height)

    if detail == "high" then
        ManaBarRenderer.draw_pattern(g, ManaBarRenderer.PATTERNS[bar.type], x, y, width * fraction, height)
        if bar.charging and not ready then
            g.setColor(WHITE)
            g.line(x + width * fraction, y - 1, x + width * fraction, y + height + 1)
        end
        ManaBarRenderer.draw_shape(g, bar.type, x + width + height + 1, y + height / 2, math.max(2, height + 1))
    end

    if cooldown_fraction and cooldown_fraction > 0 then
        g.setColor(COOLDOWN_COVER)
        g.rectangle("fill", x + width * (1 - cooldown_fraction), y, width * cooldown_fraction, height)
    end

    if kept and kept.index == index then
        g.setColor(1, 1, 1, 0.9)
        g.rectangle("line", x, y - 1, width * kept.to, height + 2)
    end

    if ready then
        g.setColor(with_alpha(WHITE, self:pulse()))
    else
        g.setColor(0.5, 0.5, 0.5, 0.9)
    end
    g.rectangle("line", x, y, width, height)
end
-- }}}

-- {{{ ManaBarRenderer:draw_dots
-- Far out: one dot per ability, filled when ready.
function ManaBarRenderer:draw_dots(g, mana, cx, y, scale)
    local count = #mana.bars
    local step = 3 * scale
    local start = cx - (count - 1) * step / 2
    for index, bar in ipairs(mana.bars) do
        local color = ManaSystem.TYPE_COLORS[bar.type] or WHITE
        g.setColor(color)
        local ready = bar.current >= bar.max - 1e-9
        g.circle(ready and "fill" or "line", start + (index - 1) * step, y, 1.2 * scale)
    end
end
-- }}}

-- {{{ ManaBarRenderer:draw_unit
-- Draws one unit's bars with its centre at screen point (sx, sy).
function ManaBarRenderer:draw_unit(g, entity, mana, abilities, sx, sy, zoom)
    local detail = self:detail_for(zoom)
    local scale = math.max(self.min_scale, math.min(self.max_scale, zoom))
    if detail == "low" then
        self:draw_dots(g, mana, sx, sy + self.offset_y * scale, scale)
        return
    end

    local width = self.bar_width * scale
    local height = self.bar_height * scale
    local gap = self.spacing * scale
    local x = sx - width / 2
    -- Bottom bar sits at offset_y; the rest stack upward, primary on top.
    local y = sy + self.offset_y * scale
    local kept = self.kept[entity]
    for index = #mana.bars, 1, -1 do
        local bar = mana.bars[index]
        local bar_height = bar.is_primary and height + scale or height
        y = y - bar_height
        local cooldown_fraction = nil
        if abilities and (abilities.cooldowns[index] or 0) > 0 then
            local duration = (abilities.cooldown_durations or {})[index] or abilities.cooldowns[index]
            cooldown_fraction = math.min(1, abilities.cooldowns[index] / duration)
        end
        self:draw_bar(g, bar, index, x, y, width, bar_height, detail, cooldown_fraction, kept)
        y = y - gap
    end
end
-- }}}

-- {{{ ManaBarRenderer:draw
-- view (all optional): x, y the world point at the screen's top-left,
-- zoom, and width, height of the screen for skipping units off it.
function ManaBarRenderer:draw(g, entity_manager, view)
    view = view or {}
    local zoom = view.zoom or 1
    local left, top = view.x or 0, view.y or 0
    local width, height = view.width, view.height
    local margin = 40
    local drawn = 0
    for _, entity in ipairs(entity_manager:get_entities_with_components({"mana", "position"})) do
        local health = entity_manager:get_component(entity, "health")
        if not health or (health.alive and health.current_hp > 0) then
            local pos = entity_manager:get_component(entity, "position")
            local sx, sy = (pos.x - left) * zoom, (pos.y - top) * zoom
            local on_screen = not width or (sx > -margin and sx < width + margin
                and sy > -margin and sy < height + margin)
            if on_screen then
                self:draw_unit(g, entity, entity_manager:get_component(entity, "mana"),
                    entity_manager:get_component(entity, "abilities"), sx, sy, zoom)
                drawn = drawn + 1
            end
        end
    end
    self.drawn_last = drawn
    g.setColor(WHITE)
    return drawn
end
-- }}}

return ManaBarRenderer
-- }}}
