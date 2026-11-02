-- {{{ Match
-- One match between two teams: each team's base (with its three shields and
-- its turret), and the reset that follows a fallen shield. The game state
-- owns one Match and calls update each frame; nothing here touches LÖVE, so
-- a whole match can be run without a window (see tests/test_match.lua).
--
-- Each frame runs, in order:
--   1. the turrets (aim, fire, move shots, hit units);
--   2. the units' assault on the enemy base (walk up, hit the front
--      shield, then the core; issue 040b);
--   3. the bases (repair, shield timing; collects "shield_destroyed",
--      "shield_vulnerable", "base_destroyed" and "victory" events);
--   4. the reset, which starts on each "shield_destroyed" event;
-- and every event from all four is kept for drawing and the UI.
-- Once a base has fallen the match is over and stops updating.
local Match = {}

local EntityManager = require("src.systems.entity_manager")
local Base = require("src.entities.base")
local Unit = require("src.entities.unit")
local BaseHealthSystem = require("src.systems.base_health_system")
local BaseTurretSystem = require("src.systems.base_turret_system")
local BaseAssaultSystem = require("src.systems.base_assault_system")
local UnitResetSystem = require("src.systems.unit_reset_system")
local debug = require("src.utils.debug")

-- How far each base sits in from the left and right edges of the field.
Match.BASE_INSET = 80

-- {{{ Match:new
-- options:
--   width, height    size of the field in pixels (default 1024 x 768)
--   base_type        type for both bases (default "standard")
--   random           replaces math.random for turret accuracy (tests)
--   entity_manager   use this one instead of making a new one
--   march            false keeps units where they are put instead of
--                    walking them toward the enemy base (default true)
function Match:new(options)
    options = options or {}
    local width = options.width or 1024
    local height = options.height or 768
    local entity_manager = options.entity_manager or EntityManager:new()

    local match = {
        width = width,
        height = height,
        entity_manager = entity_manager,
        time = 0,
        events = {},
        bases = {}
    }
    setmetatable(match, {__index = Match})

    local base_type = options.base_type or "standard"
    match.bases[1] = Base.create_base(entity_manager, 1, {x = Match.BASE_INSET, y = height / 2}, base_type)
    match.bases[2] = Base.create_base(entity_manager, 2, {x = width - Match.BASE_INSET, y = height / 2}, base_type)

    match.base_health_system = BaseHealthSystem:new(entity_manager)
    match.turret_system = BaseTurretSystem:new(entity_manager, {random = options.random})
    match.reset_system = UnitResetSystem:new(entity_manager)
    match.assault_system = BaseAssaultSystem:new(entity_manager, {march = options.march})

    debug.info("Match created on a " .. width .. "x" .. height .. " field", "MATCH")
    return match
end
-- }}}

-- {{{ local function keep_events
local function keep_events(match, events)
    for _, event in ipairs(events) do
        event.time = match.time
        table.insert(match.events, event)
    end
end
-- }}}

-- {{{ Match:update
function Match:update(dt)
    if self:is_over() then
        return
    end
    self.time = self.time + dt

    self.turret_system:update(dt)
    keep_events(self, self.turret_system:pop_events())

    self.assault_system:update(dt)
    keep_events(self, self.assault_system:pop_events())

    self.base_health_system:update(dt)
    local base_events = self.base_health_system:pop_events()
    keep_events(self, base_events)

    self.reset_system:handle_events(base_events)
    self.reset_system:update(dt)
    keep_events(self, self.reset_system:pop_events())
end
-- }}}

-- {{{ Match:get_base
function Match:get_base(team_id)
    return self.bases[team_id]
end
-- }}}

-- {{{ Match:spawn_unit
-- Puts a unit of unit_type for team_id at (x, y) and returns it.
function Match:spawn_unit(team_id, unit_type, x, y)
    return Unit.create_basic_unit(self.entity_manager, x, y, team_id, unit_type)
end
-- }}}

-- {{{ Match:get_units
-- Every unit on the field, or only team_id's when it is given.
function Match:get_units(team_id)
    local units = {}
    for _, entity in ipairs(self.entity_manager:get_entities_with_components({"unit_data", "team"})) do
        if not team_id or Unit.get_team_id(self.entity_manager, entity) == team_id then
            table.insert(units, entity)
        end
    end
    return units
end
-- }}}

-- {{{ Match:is_over
function Match:is_over()
    return self.base_health_system:is_game_over()
end
-- }}}

-- {{{ Match:get_winner
function Match:get_winner()
    return self.base_health_system:get_winner()
end
-- }}}

-- {{{ Match:is_resetting
function Match:is_resetting()
    return self.reset_system:is_resetting()
end
-- }}}

-- {{{ Match:pop_events
-- Every event since the last call, oldest first, each stamped with the
-- match time it happened at.
function Match:pop_events()
    local events = self.events
    self.events = {}
    return events
end
-- }}}

-- {{{ Match:get_debug_info
function Match:get_debug_info()
    return {
        time = self.time,
        over = self:is_over(),
        winner = self:get_winner(),
        resetting = self:is_resetting(),
        bases = self.base_health_system:get_debug_info().bases,
        turret = self.turret_system:get_debug_info(),
        assault = self.assault_system:get_debug_info(),
        reset = self.reset_system:get_debug_info()
    }
end
-- }}}

return Match
-- }}}
