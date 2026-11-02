-- {{{ MatchRenderer
-- Draws a match (src/systems/match.lua) with plain shapes on black, as the
-- vision asks: team colours for flavour, shapes so that colour is never the
-- only clue.
--   base        team 1 a square, team 2 a diamond, dimmer as it is damaged,
--               with a health bar above and its damage stage below
--   shields     a ring for each standing shield, filled by its health;
--               it flashes yellow while vulnerable; a fallen one is an "x"
--   turret      a barrel line from the base's centre toward its aim, a
--               small yellow dot at the tip just after firing, and a faint
--               ring showing its range
--   shots       small white dots
--   units       circle / triangle / square by type in team colour, grey
--               when dead, faded while being removed by a reset
--   reset       a banner across the top with the phase and a progress bar
--   victory     the winner in the middle, and how to start again
--
-- Every function takes the graphics object to draw with (love.graphics in
-- the game), so the drawing can be checked without a window.
local MatchRenderer = {}

local Base = require("src.entities.base")
local DefenseShield = require("src.entities.defense_shield")
local Unit = require("src.entities.unit")

local WHITE = {1, 1, 1, 1}
local GREY = {0.4, 0.4, 0.4, 1}
local YELLOW = {1, 1, 0, 1}
local RED = {1, 0, 0, 1}
local GREEN = {0, 1, 0, 1}

local SHIELD_RADIUS = 9
local BARREL_LENGTH = 22

local RESET_TEXT = {
    warning = "Shield down! Attackers will be cleared",
    collection = "Shield down! Collecting attackers",
    removal = "Shield down! Removing attackers"
}

-- {{{ local function with_alpha
local function with_alpha(color, alpha)
    return {color[1], color[2], color[3], (color[4] or 1) * alpha}
end
-- }}}

-- {{{ local function health_bar
local function health_bar(g, x, y, width, fraction)
    g.setColor(GREY)
    g.rectangle("fill", x - width / 2, y, width, 4)
    g.setColor(fraction > 0.3 and GREEN or RED)
    g.rectangle("fill", x - width / 2, y, width * math.max(0, math.min(1, fraction)), 4)
end
-- }}}

-- {{{ MatchRenderer.draw_base
function MatchRenderer.draw_base(g, match, base_entity)
    local em = match.entity_manager
    local pos = em:get_component(base_entity, "position")
    local renderable = em:get_component(base_entity, "renderable")
    local base = em:get_component(base_entity, "base")
    local team = Unit.get_team_id(em, base_entity)
    local size = renderable.size

    g.setColor(base.destroyed and GREY or Base.get_render_color(em, base_entity))
    if team == 1 then
        g.rectangle("fill", pos.x - size / 2, pos.y - size / 2, size, size)
    else
        g.polygon("fill", pos.x, pos.y - size * 0.7, pos.x + size * 0.7, pos.y,
            pos.x, pos.y + size * 0.7, pos.x - size * 0.7, pos.y)
    end

    health_bar(g, pos.x, pos.y - size - 10, size * 2, Base.get_health_fraction(em, base_entity))
    g.setColor(WHITE)
    g.print(base.damage_section, pos.x - size, pos.y + size)
end
-- }}}

-- {{{ MatchRenderer.draw_shields
function MatchRenderer.draw_shields(g, match, base_entity)
    local em = match.entity_manager
    local team_color = Unit.get_team_color(Unit.get_team_id(em, base_entity))
    -- Vulnerable shields flash four times a second.
    local flash_on = math.floor(match.time * 8) % 2 == 0

    for _, row in ipairs(DefenseShield.get_status(Base.get_shields(em, base_entity))) do
        if row.active then
            g.setColor(with_alpha(team_color, 0.25 + 0.5 * row.fraction))
            g.circle("fill", row.x, row.y, SHIELD_RADIUS * row.fraction)
            g.setColor((row.vulnerable and flash_on) and YELLOW or team_color)
            g.circle("line", row.x, row.y, SHIELD_RADIUS)
        else
            g.setColor(GREY)
            local r = SHIELD_RADIUS * 0.6
            g.line(row.x - r, row.y - r, row.x + r, row.y + r)
            g.line(row.x - r, row.y + r, row.x + r, row.y - r)
        end
    end
end
-- }}}

-- {{{ MatchRenderer.draw_turret
function MatchRenderer.draw_turret(g, match, base_entity)
    local em = match.entity_manager
    local base = em:get_component(base_entity, "base")
    local turret = base.turret
    if not turret or base.destroyed then
        return
    end
    local pos = em:get_component(base_entity, "position")

    g.setColor(with_alpha(WHITE, 0.12))
    g.circle("line", pos.x, pos.y, turret.range)

    local tip_x = pos.x + math.cos(turret.angle) * BARREL_LENGTH
    local tip_y = pos.y + math.sin(turret.angle) * BARREL_LENGTH
    g.setColor(WHITE)
    g.setLineWidth(3)
    g.line(pos.x, pos.y, tip_x, tip_y)
    g.setLineWidth(1)

    if turret.muzzle_flash > 0 then
        g.setColor(YELLOW)
        g.circle("fill", tip_x, tip_y, 4)
    end
end
-- }}}

-- {{{ MatchRenderer.draw_projectiles
function MatchRenderer.draw_projectiles(g, match)
    g.setColor(WHITE)
    for _, shot in ipairs(match.turret_system:get_projectiles()) do
        g.circle("fill", shot.x, shot.y, 2)
    end
end
-- }}}

-- {{{ MatchRenderer.draw_unit
function MatchRenderer.draw_unit(g, match, unit)
    local em = match.entity_manager
    local pos = em:get_component(unit, "position")
    local data = em:get_component(unit, "unit_data")
    local unit_type = data.unit_type or "melee"
    local size = Unit.get_unit_size(unit_type)

    local color = Unit.get_unit_color_by_type(unit_type, Unit.get_team_id(em, unit))
    if not Unit.is_alive(em, unit) then
        color = GREY
    elseif data.state == "being_reset" then
        color = with_alpha(color, 0.35)
    end
    g.setColor(color)

    local shape = Unit.get_unit_shape(unit_type)
    if shape == "triangle" then
        g.polygon("fill", pos.x, pos.y - size, pos.x + size, pos.y + size, pos.x - size, pos.y + size)
    elseif shape == "rectangle" then
        g.rectangle("fill", pos.x - size / 2, pos.y - size / 2, size, size)
    else
        g.circle("fill", pos.x, pos.y, size / 2)
    end
end
-- }}}

-- {{{ MatchRenderer.draw_reset_banner
function MatchRenderer.draw_reset_banner(g, match)
    local progress = match.reset_system:get_progress()
    if not progress then
        return
    end
    local width = match.width
    g.setColor(with_alpha(YELLOW, 0.15))
    g.rectangle("fill", 0, 50, width, 34)
    g.setColor(YELLOW)
    g.printf(RESET_TEXT[progress.phase] .. " (team " .. progress.defending_team .. " defends)",
        0, 54, width, "center")

    -- One bar for the whole reset: each phase fills its share.
    local total, done = 0, 0
    for _, phase in ipairs(match.reset_system.PHASES) do
        if phase.name == progress.phase then
            done = total + phase.duration * progress.progress
        end
        total = total + phase.duration
    end
    g.rectangle("fill", width * 0.3, 74, width * 0.4 * (done / total), 4)
end
-- }}}

-- {{{ MatchRenderer.draw_victory
function MatchRenderer.draw_victory(g, match)
    if not match:is_over() then
        return
    end
    g.setColor(with_alpha({0, 0, 0, 1}, 0.6))
    g.rectangle("fill", 0, match.height / 2 - 40, match.width, 80)
    g.setColor(WHITE)
    g.printf("Team " .. tostring(match:get_winner()) .. " wins!", 0, match.height / 2 - 20, match.width, "center")
    g.printf("Press R for a new match", 0, match.height / 2 + 5, match.width, "center")
end
-- }}}

-- {{{ MatchRenderer.draw
-- Draws the whole match: field pieces first, then units and shots, then
-- the banners on top.
function MatchRenderer.draw(g, match)
    for _, base_entity in ipairs(match.bases) do
        MatchRenderer.draw_turret(g, match, base_entity)
        MatchRenderer.draw_base(g, match, base_entity)
        MatchRenderer.draw_shields(g, match, base_entity)
    end
    for _, unit in ipairs(match:get_units()) do
        MatchRenderer.draw_unit(g, match, unit)
    end
    MatchRenderer.draw_projectiles(g, match)
    MatchRenderer.draw_reset_banner(g, match)
    MatchRenderer.draw_victory(g, match)
    g.setColor(WHITE)
end
-- }}}

return MatchRenderer
-- }}}
