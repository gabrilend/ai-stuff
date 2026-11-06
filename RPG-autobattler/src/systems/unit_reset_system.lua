-- {{{ UnitResetSystem
-- When a defence shield falls, every enemy unit on the map is removed, so the
-- attacker has to push forward again and one won battle cannot snowball into
-- the next. This is the vision's anti-snowball rule.
--
-- A reset runs in three phases:
--   warning     1.0 s  the reset is announced; units still fight
--   collection  1.5 s  enemy units stop moving and fighting
--   removal     0.5 s  then every enemy unit still on the map is removed
-- Feed it the events from BaseHealthSystem:pop_events(); it reacts to
-- "shield_destroyed". It records its own events for effects and the UI.
local UnitResetSystem = {}

local Unit = require("src.entities.unit")
local debug = require("src.utils.debug")

UnitResetSystem.PHASES = {
    {name = "warning", duration = 1.0},
    {name = "collection", duration = 1.5},
    {name = "removal", duration = 0.5}
}

-- {{{ UnitResetSystem:new
function UnitResetSystem:new(entity_manager)
    local system = {
        entity_manager = entity_manager,
        name = "unit_reset_system",
        active = nil,        -- the reset in progress, if any
        queue = {},          -- resets waiting for the active one to finish
        events = {},
        stats = {
            resets_completed = 0,
            units_removed = 0,
            empty_triggers = 0,
            resets_by_defender = {}
        }
    }
    setmetatable(system, {__index = UnitResetSystem})

    debug.info("UnitResetSystem created", "RESET")
    return system
end
-- }}}

-- {{{ UnitResetSystem:get_enemy_units
-- Every unit (alive or a corpse) not on the defending team.
function UnitResetSystem:get_enemy_units(defending_team)
    local em = self.entity_manager
    local enemies = {}
    for _, entity in ipairs(em:get_entities_with_components({"unit_data", "team"})) do
        if Unit.get_team_id(em, entity) ~= defending_team then
            table.insert(enemies, entity)
        end
    end
    table.sort(enemies, function(a, b) return a.id < b.id end)
    return enemies
end
-- }}}

-- {{{ UnitResetSystem:handle_events
function UnitResetSystem:handle_events(events)
    for _, event in ipairs(events or {}) do
        self:handle_event(event)
    end
end
-- }}}

-- {{{ UnitResetSystem:handle_event
function UnitResetSystem:handle_event(event)
    if event.type == "shield_destroyed" then
        self:trigger_reset(event.team, event)
    end
end
-- }}}

-- {{{ UnitResetSystem:trigger_reset
-- Starts a reset in favour of defending_team, or queues it behind the one
-- already running so that no shield's fall goes without its reset. Returns
-- false when there were no enemy units to remove.
function UnitResetSystem:trigger_reset(defending_team, source)
    if #self:get_enemy_units(defending_team) == 0 then
        self.stats.empty_triggers = self.stats.empty_triggers + 1
        debug.info("Shield of team " .. defending_team .. " fell with no enemy units on the map", "RESET")
        return false
    end

    local reset = {
        defending_team = defending_team,
        source = source,
        phase_index = 1,
        phase_time = 0,
        disabled = {},
        removed = 0
    }

    if self.active then
        table.insert(self.queue, reset)
        debug.info("Reset for team " .. defending_team .. " queued behind the running one", "RESET")
    else
        self:start(reset)
    end
    return true
end
-- }}}

-- {{{ UnitResetSystem:start
-- Begins the warning phase. A queued reset whose enemies were all removed by
-- the reset before it has nothing to do, so it is counted and skipped.
function UnitResetSystem:start(reset)
    local count = #self:get_enemy_units(reset.defending_team)
    if count == 0 then
        self.stats.empty_triggers = self.stats.empty_triggers + 1
        self:start_next()
        return
    end
    self.active = reset
    table.insert(self.events, {
        type = "reset_warning",
        defending_team = reset.defending_team,
        units = count,
        duration = UnitResetSystem.PHASES[1].duration
    })
    debug.info("Unit reset warning: " .. count .. " units facing team " .. reset.defending_team, "RESET")
end
-- }}}

-- {{{ UnitResetSystem:disable_units
-- Stops enemy units in place and marks them as being reset. Run every frame
-- of the collection phase, so units that arrive late are caught too.
function UnitResetSystem:disable_units(reset)
    local em = self.entity_manager
    for _, entity in ipairs(self:get_enemy_units(reset.defending_team)) do
        if not reset.disabled[entity.id] then
            reset.disabled[entity.id] = true
            local unit_data = em:get_component(entity, "unit_data")
            unit_data.reset_in_progress = true
            unit_data.state = "being_reset"
            unit_data.combat_state = "idle"
            unit_data.combat_target = nil
            unit_data.target_position = nil

            local moveable = em:get_component(entity, "moveable")
            if moveable then
                moveable.velocity_x = 0
                moveable.velocity_y = 0
                moveable.is_moving = false
                moveable.speed = 0
            end
        end
    end
end
-- }}}

-- {{{ UnitResetSystem:remove_units
function UnitResetSystem:remove_units(reset)
    for _, entity in ipairs(self:get_enemy_units(reset.defending_team)) do
        self.entity_manager:remove_entity(entity)
        reset.removed = reset.removed + 1
    end
end
-- }}}

-- {{{ UnitResetSystem:enter_phase
function UnitResetSystem:enter_phase(reset)
    local phase = UnitResetSystem.PHASES[reset.phase_index]
    table.insert(self.events, {
        type = "reset_" .. phase.name,
        defending_team = reset.defending_team,
        duration = phase.duration
    })
    if phase.name == "collection" then
        self:disable_units(reset)
    end
end
-- }}}

-- {{{ UnitResetSystem:finish
function UnitResetSystem:finish(reset)
    self:remove_units(reset)

    local stats = self.stats
    stats.resets_completed = stats.resets_completed + 1
    stats.units_removed = stats.units_removed + reset.removed
    stats.resets_by_defender[reset.defending_team] = (stats.resets_by_defender[reset.defending_team] or 0) + 1

    table.insert(self.events, {
        type = "reset_completed",
        defending_team = reset.defending_team,
        units_removed = reset.removed
    })
    debug.info("Unit reset complete: removed " .. reset.removed .. " units facing team " ..
        reset.defending_team, "RESET")

    self.active = nil
    self:start_next()
end
-- }}}

-- {{{ UnitResetSystem:start_next
function UnitResetSystem:start_next()
    if #self.queue > 0 then
        self:start(table.remove(self.queue, 1))
    end
end
-- }}}

-- {{{ UnitResetSystem:update
function UnitResetSystem:update(dt)
    local reset = self.active
    if not reset then
        return
    end

    if UnitResetSystem.PHASES[reset.phase_index].name == "collection" then
        self:disable_units(reset)
    end

    reset.phase_time = reset.phase_time + dt
    while self.active == reset and reset.phase_time >= UnitResetSystem.PHASES[reset.phase_index].duration do
        reset.phase_time = reset.phase_time - UnitResetSystem.PHASES[reset.phase_index].duration
        if reset.phase_index == #UnitResetSystem.PHASES then
            self:finish(reset)
        else
            reset.phase_index = reset.phase_index + 1
            self:enter_phase(reset)
        end
    end
end
-- }}}

-- {{{ UnitResetSystem:is_resetting
function UnitResetSystem:is_resetting()
    return self.active ~= nil
end
-- }}}

-- {{{ UnitResetSystem:get_progress
-- For drawing: the running phase's name, how far through it (0..1), and the
-- defending team; nil when no reset is running.
function UnitResetSystem:get_progress()
    local reset = self.active
    if not reset then
        return nil
    end
    local phase = UnitResetSystem.PHASES[reset.phase_index]
    return {
        phase = phase.name,
        progress = math.min(1, reset.phase_time / phase.duration),
        defending_team = reset.defending_team,
        queued = #self.queue
    }
end
-- }}}

-- {{{ UnitResetSystem:pop_events
function UnitResetSystem:pop_events()
    local events = self.events
    self.events = {}
    return events
end
-- }}}

-- {{{ UnitResetSystem:get_debug_info
function UnitResetSystem:get_debug_info()
    return {
        resetting = self:is_resetting(),
        queued = #self.queue,
        resets_completed = self.stats.resets_completed,
        units_removed = self.stats.units_removed,
        empty_triggers = self.stats.empty_triggers
    }
end
-- }}}

return UnitResetSystem
-- }}}
