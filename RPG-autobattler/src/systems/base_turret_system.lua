-- {{{ BaseTurretSystem
-- Every standing base has one automatic turret. Each frame the turret picks
-- an enemy unit in range by its targeting mode, turns toward it at a fixed
-- speed, and fires when it is lined up and reloaded. Shots are projectiles
-- that home in on their target; a shot that missed its accuracy roll flies
-- past and does no damage. A battered base reloads more slowly, by its
-- structural integrity (issue 036). A destroyed base's turret falls silent.
local BaseTurretSystem = {}

local Base = require("src.entities.base")
local DefenseShield = require("src.entities.defense_shield")
local Unit = require("src.entities.unit")
local debug = require("src.utils.debug")

-- Lua 5.4 dropped math.atan2; its math.atan takes (y, x) instead.
local atan2 = math.atan2 or math.atan

-- {{{ Turret settings
BaseTurretSystem.DEFAULTS = {
    -- Reach past the shield ring, measured from the base's centre, so the
    -- turret can hit ranged units (45 at most) shooting at the shields.
    reach_past_shields = 60,
    damage = 25,
    accuracy = 0.9,
    fire_interval = 1.0,        -- seconds between shots at full integrity
    rotation_speed = math.pi,   -- radians per second
    aim_tolerance = 0.1,        -- radians off target that still fires
    projectile_speed = 300,     -- pixels per second
    muzzle_flash_time = 0.1,
    targeting_mode = "closest"
}

-- How dangerous each unit type is, for the "highest_threat" mode. Ranged and
-- special units hit hardest from a distance, so they come first.
BaseTurretSystem.THREAT = {
    special = 4,
    ranged = 3,
    melee = 2,
    tank = 2,
    support = 1
}

BaseTurretSystem.MODES = {"closest", "highest_threat", "weakest"}
-- }}}

-- {{{ BaseTurretSystem:new
-- options.random may replace math.random (a function returning 0..1), so
-- tests can decide which shots hit.
function BaseTurretSystem:new(entity_manager, options)
    options = options or {}
    local system = {
        entity_manager = entity_manager,
        name = "base_turret_system",
        random = options.random or math.random,
        projectiles = {},
        events = {},
        stats = {shots = 0, hits = 0, misses = 0, damage_dealt = 0, kills = 0}
    }
    setmetatable(system, {__index = BaseTurretSystem})

    debug.info("BaseTurretSystem created", "TURRET")
    return system
end
-- }}}

-- {{{ BaseTurretSystem:get_turret
-- Returns the base's turret, creating it with the defaults the first time.
function BaseTurretSystem:get_turret(base_entity)
    local base = self.entity_manager:get_component(base_entity, "base")
    if not base then
        return nil
    end
    if not base.turret then
        local turret = {}
        for key, value in pairs(BaseTurretSystem.DEFAULTS) do
            turret[key] = value
        end
        turret.range = DefenseShield.RING_RADIUS + turret.reach_past_shields
        local team_id = Unit.get_team_id(self.entity_manager, base_entity)
        turret.angle = team_id == 1 and 0 or math.pi
        turret.cooldown = 0
        turret.target = nil
        turret.muzzle_flash = 0
        base.turret = turret
    end
    return base.turret
end
-- }}}

-- {{{ BaseTurretSystem:set_targeting_mode
function BaseTurretSystem:set_targeting_mode(base_entity, mode)
    local valid = false
    for _, name in ipairs(BaseTurretSystem.MODES) do
        if name == mode then
            valid = true
        end
    end
    if not valid then
        error("Unknown targeting mode: " .. tostring(mode))
    end
    local turret = self:get_turret(base_entity)
    turret.targeting_mode = mode
    turret.target = nil
end
-- }}}

-- {{{ local function normalize_angle
-- Wraps an angle into -pi..pi.
local function normalize_angle(angle)
    while angle > math.pi do
        angle = angle - 2 * math.pi
    end
    while angle < -math.pi do
        angle = angle + 2 * math.pi
    end
    return angle
end
-- }}}

-- {{{ local function distance
local function distance(ax, ay, bx, by)
    local dx, dy = bx - ax, by - ay
    return math.sqrt(dx * dx + dy * dy)
end
-- }}}

-- {{{ BaseTurretSystem:is_valid_target
function BaseTurretSystem:is_valid_target(base_entity, turret, unit)
    local em = self.entity_manager
    if not unit or not em.entities[unit.id] then
        return false
    end
    if not em:has_components(unit, {"position", "health", "team", "unit_data"}) then
        return false
    end
    if not Unit.is_alive(em, unit) then
        return false
    end
    if Unit.get_team_id(em, unit) == Unit.get_team_id(em, base_entity) then
        return false
    end
    local base_pos = em:get_component(base_entity, "position")
    local unit_pos = em:get_component(unit, "position")
    return distance(base_pos.x, base_pos.y, unit_pos.x, unit_pos.y) <= turret.range
end
-- }}}

-- {{{ BaseTurretSystem:score_target
-- Lower is better. Every mode breaks ties by distance.
function BaseTurretSystem:score_target(base_entity, turret, unit)
    local em = self.entity_manager
    local base_pos = em:get_component(base_entity, "position")
    local unit_pos = em:get_component(unit, "position")
    local dist = distance(base_pos.x, base_pos.y, unit_pos.x, unit_pos.y)

    if turret.targeting_mode == "highest_threat" then
        local threat = BaseTurretSystem.THREAT[Unit.get_unit_type(em, unit)] or 1
        return -threat * 10000 + dist
    elseif turret.targeting_mode == "weakest" then
        local health = em:get_component(unit, "health")
        return health.current_hp * 10000 + dist
    end
    return dist
end
-- }}}

-- {{{ BaseTurretSystem:select_target
function BaseTurretSystem:select_target(base_entity, turret)
    local best, best_score = nil, nil
    local candidates = self.entity_manager:get_entities_with_components({"position", "health", "team", "unit_data"})
    for _, unit in ipairs(candidates) do
        if self:is_valid_target(base_entity, turret, unit) then
            local score = self:score_target(base_entity, turret, unit)
            if not best_score or score < best_score or (score == best_score and unit.id < best.id) then
                best, best_score = unit, score
            end
        end
    end
    return best
end
-- }}}

-- {{{ BaseTurretSystem:update
function BaseTurretSystem:update(dt)
    for _, base_entity in ipairs(self.entity_manager:get_entities_with_component("base")) do
        if not Base.is_destroyed(self.entity_manager, base_entity) then
            self:update_turret(base_entity, dt)
        end
    end
    self:update_projectiles(dt)
end
-- }}}

-- {{{ BaseTurretSystem:update_turret
function BaseTurretSystem:update_turret(base_entity, dt)
    local em = self.entity_manager
    local turret = self:get_turret(base_entity)

    turret.cooldown = math.max(0, turret.cooldown - dt)
    turret.muzzle_flash = math.max(0, turret.muzzle_flash - dt)

    -- Keep the current target while it stays valid, so the turret does not
    -- flick between units of equal score.
    if not self:is_valid_target(base_entity, turret, turret.target) then
        turret.target = self:select_target(base_entity, turret)
    end
    if not turret.target then
        return
    end

    local base_pos = em:get_component(base_entity, "position")
    local target_pos = em:get_component(turret.target, "position")
    local wanted = atan2(target_pos.y - base_pos.y, target_pos.x - base_pos.x)
    local diff = normalize_angle(wanted - turret.angle)
    local step = turret.rotation_speed * dt
    if math.abs(diff) <= step then
        turret.angle = wanted
        diff = 0
    else
        turret.angle = normalize_angle(turret.angle + (diff > 0 and step or -step))
        diff = normalize_angle(wanted - turret.angle)
    end

    if math.abs(diff) <= turret.aim_tolerance and turret.cooldown <= 0 then
        self:fire(base_entity, turret)
    end
end
-- }}}

-- {{{ BaseTurretSystem:fire
function BaseTurretSystem:fire(base_entity, turret)
    local em = self.entity_manager
    local base_pos = em:get_component(base_entity, "position")
    local hits = self.random() < turret.accuracy

    table.insert(self.projectiles, {
        x = base_pos.x,
        y = base_pos.y,
        target = turret.target,
        damage = turret.damage,
        speed = turret.projectile_speed,
        will_hit = hits,
        team = Unit.get_team_id(em, base_entity),
        travelled = 0,
        max_travel = turret.range * 1.5
    })

    -- Reload is slower as the base falls apart.
    local effectiveness = math.max(0.1, Base.get_effectiveness(em, base_entity))
    turret.cooldown = turret.fire_interval / effectiveness
    turret.muzzle_flash = turret.muzzle_flash_time
    self.stats.shots = self.stats.shots + 1
    table.insert(self.events, {type = "turret_fired", team = Unit.get_team_id(em, base_entity),
        angle = turret.angle})
end
-- }}}

-- {{{ BaseTurretSystem:update_projectiles
function BaseTurretSystem:update_projectiles(dt)
    local em = self.entity_manager
    local remaining = {}
    for _, shot in ipairs(self.projectiles) do
        local alive_target = shot.target and em.entities[shot.target.id] and Unit.is_alive(em, shot.target)
        if alive_target then
            local pos = em:get_component(shot.target, "position")
            local dist = distance(shot.x, shot.y, pos.x, pos.y)
            local step = shot.speed * dt
            if dist <= step then
                self:resolve_hit(shot)
            else
                shot.x = shot.x + (pos.x - shot.x) / dist * step
                shot.y = shot.y + (pos.y - shot.y) / dist * step
                shot.travelled = shot.travelled + step
                if shot.travelled <= shot.max_travel then
                    table.insert(remaining, shot)
                end
            end
        end
        -- A shot whose target is already gone simply fizzles.
    end
    self.projectiles = remaining
end
-- }}}

-- {{{ BaseTurretSystem:resolve_hit
function BaseTurretSystem:resolve_hit(shot)
    local em = self.entity_manager
    if not shot.will_hit then
        self.stats.misses = self.stats.misses + 1
        table.insert(self.events, {type = "turret_missed", team = shot.team})
        return
    end
    local health = em:get_component(shot.target, "health")
    local before = health.current_hp
    Unit.damage_unit(em, shot.target, shot.damage)
    local dealt = before - health.current_hp
    self.stats.hits = self.stats.hits + 1
    self.stats.damage_dealt = self.stats.damage_dealt + dealt
    local killed = not Unit.is_alive(em, shot.target)
    if killed then
        self.stats.kills = self.stats.kills + 1
    end
    table.insert(self.events, {type = "turret_hit", team = shot.team, target_id = shot.target.id,
        damage = dealt, killed = killed})
end
-- }}}

-- {{{ BaseTurretSystem:get_projectiles
function BaseTurretSystem:get_projectiles()
    return self.projectiles
end
-- }}}

-- {{{ BaseTurretSystem:pop_events
function BaseTurretSystem:pop_events()
    local events = self.events
    self.events = {}
    return events
end
-- }}}

-- {{{ BaseTurretSystem:get_debug_info
function BaseTurretSystem:get_debug_info()
    return {
        projectiles = #self.projectiles,
        shots = self.stats.shots,
        hits = self.stats.hits,
        misses = self.stats.misses,
        damage_dealt = self.stats.damage_dealt,
        kills = self.stats.kills
    }
end
-- }}}

return BaseTurretSystem
-- }}}
