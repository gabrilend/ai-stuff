-- {{{ BaseHealthSystem
-- Keeps every base up to date each frame (self-repair, damage condition),
-- passes on "shield_destroyed" events from each base, and watches for a
-- destroyed base. The first base to fall ends the match: the
-- system records a "base_destroyed" event and names the winning team, which
-- the game state reads to show victory or defeat.
local BaseHealthSystem = {}

local Base = require("src.entities.base")
local DefenseShield = require("src.entities.defense_shield")
local Unit = require("src.entities.unit")
local debug = require("src.utils.debug")

-- {{{ BaseHealthSystem:new
function BaseHealthSystem:new(entity_manager)
    local system = {
        entity_manager = entity_manager,
        name = "base_health_system",
        game_over = false,
        winner = nil,
        events = {},
        reported = {}
    }
    setmetatable(system, {__index = BaseHealthSystem})

    debug.info("BaseHealthSystem created", "BASE")
    return system
end
-- }}}

-- {{{ BaseHealthSystem:get_bases
function BaseHealthSystem:get_bases()
    return self.entity_manager:get_entities_with_component("base")
end
-- }}}

-- {{{ BaseHealthSystem:get_base_for_team
function BaseHealthSystem:get_base_for_team(team_id)
    for _, entity in ipairs(self:get_bases()) do
        if Unit.get_team_id(self.entity_manager, entity) == team_id then
            return entity
        end
    end
    return nil
end
-- }}}

-- {{{ BaseHealthSystem:update
function BaseHealthSystem:update(dt)
    for _, entity in ipairs(self:get_bases()) do
        Base.update(self.entity_manager, entity, dt)
        -- Pass on shield losses so the unit reset (issue 040) can react.
        for _, event in ipairs(Base.pop_events(self.entity_manager, entity)) do
            table.insert(self.events, event)
        end
        self:check_destruction(entity)
    end
end
-- }}}

-- {{{ BaseHealthSystem:check_destruction
function BaseHealthSystem:check_destruction(entity)
    if self.reported[entity.id] or not Base.is_destroyed(self.entity_manager, entity) then
        return
    end
    self.reported[entity.id] = true

    local base = self.entity_manager:get_component(entity, "base")
    local loser = Unit.get_team_id(self.entity_manager, entity)
    table.insert(self.events, {
        type = "base_destroyed",
        team = loser,
        destroyed_by = base.destroyed_by
    })

    if not self.game_over then
        self.game_over = true
        self.winner = base.destroyed_by or self:find_surviving_team(loser)
        table.insert(self.events, {type = "victory", winner = self.winner, loser = loser})
        debug.info("Team " .. tostring(self.winner) .. " wins: base of team " .. loser .. " destroyed", "BASE")
    end
end
-- }}}

-- {{{ BaseHealthSystem:find_surviving_team
-- Used when a base falls to damage with no recorded attacker.
function BaseHealthSystem:find_surviving_team(loser)
    for _, entity in ipairs(self:get_bases()) do
        local team_id = Unit.get_team_id(self.entity_manager, entity)
        if team_id ~= loser and not Base.is_destroyed(self.entity_manager, entity) then
            return team_id
        end
    end
    return nil
end
-- }}}

-- {{{ BaseHealthSystem:is_game_over
function BaseHealthSystem:is_game_over()
    return self.game_over
end
-- }}}

-- {{{ BaseHealthSystem:get_winner
function BaseHealthSystem:get_winner()
    return self.winner
end
-- }}}

-- {{{ BaseHealthSystem:pop_events
-- Returns the events recorded since the last call and clears them.
function BaseHealthSystem:pop_events()
    local events = self.events
    self.events = {}
    return events
end
-- }}}

-- {{{ BaseHealthSystem:get_debug_info
function BaseHealthSystem:get_debug_info()
    local info = {game_over = self.game_over, winner = self.winner, bases = {}}
    for _, entity in ipairs(self:get_bases()) do
        local base = self.entity_manager:get_component(entity, "base")
        local health = self.entity_manager:get_component(entity, "health")
        table.insert(info.bases, {
            team = Unit.get_team_id(self.entity_manager, entity),
            base_type = base.base_type,
            health = health.current_hp,
            max_health = health.max_hp,
            section = base.damage_section,
            shields_active = DefenseShield.count_active(base.shields),
            integrity = base.structural_integrity
        })
    end
    return info
end
-- }}}

return BaseHealthSystem
-- }}}
