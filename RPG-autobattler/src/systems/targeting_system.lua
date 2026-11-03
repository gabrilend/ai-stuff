-- {{{ Targeting system
-- Finds what an ability should be aimed at. find_targets(caster, ability)
-- returns a list of targets, best first, and a table of extra facts (the
-- centre of an area, or why nothing was found).
--
-- A target is a table:
--   entity, x, y, distance (from the caster), current_health,
--   max_health, unit_type, team, has_effect (true when it already carries
--   the ability's buff or debuff), stats (its "stats" component, if any),
--   and for area abilities distance_from_center.
-- It carries the fields ManaEfficiency.plan reads, so the list can go
-- straight into a plan.
--
-- By targeting type:
--   enemy   living enemies within range
--   ally    living allies within range, the caster included unless the
--           ability says exclude_self
--   self    the caster
--   area    the best centre within range for the ability's circle, and
--   ground  the units it would affect (enemies for damage, allies for
--           healing), nearest the centre first
-- Targets are checked for line of sight when the ability asks for it,
-- sorted by the ability's target_priority, and cut to its max_targets.
--
-- Living units are read once per frame into a snapshot with a grid, so a
-- hundred casters don't each walk every unit. Results are cached per
-- caster and ability until the next update() (or for cache_duration
-- seconds when that's set), and stats counts hits and misses.
local TargetingSystem = {}
TargetingSystem.__index = TargetingSystem

TargetingSystem.CELL_SIZE = 64

-- What each kind prefers when the ability doesn't name a priority.
TargetingSystem.DEFAULT_PRIORITY = {
    damage = "closest",
    debuff = "highest_value",
    heal = "lowest_health_percentage",
    buff = "closest",
    area = "closest"
}

-- How much a unit type is worth hitting first, for "highest_value".
TargetingSystem.TYPE_VALUE = {
    melee = 1.0,
    tank = 0.9,
    ranged = 1.2,
    support = 1.3,
    special = 1.3
}

-- {{{ TargetingSystem:new
-- options:
--   blocked(x1, y1, x2, y2)  true when something stands between the points
--   obstacles                 a list of circles {x, y, radius} that block
--                             sight, checked when blocked isn't given
--   cache_duration            seconds a result may be reused (default 0:
--                             only within one frame)
function TargetingSystem:new(entity_manager, options)
    options = options or {}
    local system = {
        entity_manager = entity_manager,
        blocked = options.blocked,
        obstacles = options.obstacles or {},
        cache_duration = options.cache_duration or 0,
        clock = 0,
        frame = 0,
        snapshot_data = nil,
        snapshot_time = nil,
        cache = {},
        stats = {queries = 0, cache_hits = 0, line_of_sight_checks = 0, blocked = 0}
    }
    setmetatable(system, self)
    return system
end
-- }}}

-- {{{ TargetingSystem:update
-- Call once a frame, before abilities look for targets.
function TargetingSystem:update(dt)
    self.clock = self.clock + (dt or 0)
    self.frame = self.frame + 1
    if self.snapshot_time == nil or self.clock - self.snapshot_time >= self.cache_duration - 1e-9 then
        self:invalidate()
    end
end
-- }}}

-- {{{ TargetingSystem:invalidate
-- Forgets the snapshot and cached results, e.g. after units move outside
-- the normal update order.
function TargetingSystem:invalidate()
    self.snapshot_data = nil
    self.snapshot_time = nil
    self.cache = {}
end
-- }}}

-- {{{ local function cell_key
local function cell_key(cx, cy)
    return cx * 100003 + cy
end
-- }}}

-- {{{ TargetingSystem:snapshot
-- Every living unit, read once, and a grid of them by cell.
function TargetingSystem:snapshot()
    if self.snapshot_data then
        return self.snapshot_data
    end
    local em = self.entity_manager
    local units, grid = {}, {}
    local size = TargetingSystem.CELL_SIZE
    for _, entity in ipairs(em:get_entities_with_components({"position", "health", "team"})) do
        local health = em:get_component(entity, "health")
        if health.alive and health.current_hp > 0 then
            local pos = em:get_component(entity, "position")
            local unit_data = em:get_component(entity, "unit_data")
            local effects = em:get_component(entity, "effects")
            local unit = {
                entity = entity,
                x = pos.x,
                y = pos.y,
                team = em:get_component(entity, "team").player_id,
                current_health = health.current_hp,
                max_health = health.max_hp,
                unit_type = unit_data and unit_data.unit_type or "unknown",
                effects = effects and effects.active or nil,
                stats = em:get_component(entity, "stats"),
                ability_count = 0
            }
            local abilities = em:get_component(entity, "abilities")
            if abilities then
                unit.ability_count = #abilities.abilities
            end
            units[#units + 1] = unit
            units[entity] = unit
            local key = cell_key(math.floor(pos.x / size), math.floor(pos.y / size))
            local cell = grid[key]
            if not cell then
                cell = {}
                grid[key] = cell
            end
            cell[#cell + 1] = unit
        end
    end
    self.snapshot_data = {units = units, grid = grid}
    self.snapshot_time = self.snapshot_time or self.clock
    return self.snapshot_data
end
-- }}}

-- {{{ TargetingSystem:units_within
-- Living units within `radius` of (x, y), with a filter(unit) -> bool.
function TargetingSystem:units_within(x, y, radius, filter)
    local snap = self:snapshot()
    local size = TargetingSystem.CELL_SIZE
    local found = {}
    local radius_sq = radius * radius
    for cx = math.floor((x - radius) / size), math.floor((x + radius) / size) do
        for cy = math.floor((y - radius) / size), math.floor((y + radius) / size) do
            local cell = snap.grid[cell_key(cx, cy)]
            if cell then
                for _, unit in ipairs(cell) do
                    local dx, dy = unit.x - x, unit.y - y
                    if dx * dx + dy * dy <= radius_sq and (not filter or filter(unit)) then
                        found[#found + 1] = unit
                    end
                end
            end
        end
    end
    return found
end
-- }}}

-- {{{ local function segment_hits_circle
local function segment_hits_circle(x1, y1, x2, y2, circle)
    local dx, dy = x2 - x1, y2 - y1
    local length_sq = dx * dx + dy * dy
    local t = 0
    if length_sq > 0 then
        t = ((circle.x - x1) * dx + (circle.y - y1) * dy) / length_sq
        t = math.max(0, math.min(1, t))
    end
    local px, py = x1 + t * dx - circle.x, y1 + t * dy - circle.y
    return px * px + py * py < circle.radius * circle.radius
end
-- }}}

-- {{{ TargetingSystem:has_line_of_sight
function TargetingSystem:has_line_of_sight(x1, y1, x2, y2)
    self.stats.line_of_sight_checks = self.stats.line_of_sight_checks + 1
    local blocked
    if self.blocked then
        blocked = self.blocked(x1, y1, x2, y2)
    else
        blocked = false
        for _, circle in ipairs(self.obstacles) do
            if segment_hits_circle(x1, y1, x2, y2, circle) then
                blocked = true
                break
            end
        end
    end
    if blocked then
        self.stats.blocked = self.stats.blocked + 1
    end
    return not blocked
end
-- }}}

-- {{{ local function make_target
local function make_target(unit, caster, ability)
    local dx, dy = unit.x - caster.x, unit.y - caster.y
    local effect_name = ability.effect_name
    return {
        entity = unit.entity,
        x = unit.x,
        y = unit.y,
        team = unit.team,
        distance = math.sqrt(dx * dx + dy * dy),
        current_health = unit.current_health,
        max_health = unit.max_health,
        unit_type = unit.unit_type,
        stats = unit.stats,
        ability_count = unit.ability_count,
        has_effect = effect_name ~= nil and unit.effects ~= nil and unit.effects[effect_name] ~= nil
    }
end
-- }}}

-- {{{ TargetingSystem.target_value
-- How much a target is worth hitting first: its health, weighted by its
-- type and by how many abilities it carries.
function TargetingSystem.target_value(target)
    local weight = TargetingSystem.TYPE_VALUE[target.unit_type] or 1.0
    return target.current_health * weight * (1 + 0.1 * (target.ability_count or 0))
end
-- }}}

-- {{{ TargetingSystem.prioritize
-- Sorts targets in place by mode; ties go to the closer target, then the
-- lower entity id, so the order never depends on table order.
function TargetingSystem.prioritize(targets, mode)
    local key
    if mode == "farthest" then
        key = function(t) return -t.distance end
    elseif mode == "weakest" then
        key = function(t) return t.current_health end
    elseif mode == "strongest" then
        key = function(t) return -t.current_health end
    elseif mode == "lowest_health_percentage" then
        key = function(t) return t.current_health / t.max_health end
    elseif mode == "highest_value" then
        key = function(t) return -TargetingSystem.target_value(t) end
    else
        key = function(t) return t.distance end
    end
    for _, target in ipairs(targets) do
        target.sort_key = key(target)
    end
    table.sort(targets, function(a, b)
        -- Targets that already carry the effect go last.
        if a.has_effect ~= b.has_effect then
            return b.has_effect
        end
        if a.sort_key ~= b.sort_key then
            return a.sort_key < b.sort_key
        end
        if a.distance ~= b.distance then
            return a.distance < b.distance
        end
        return a.entity.id < b.entity.id
    end)
    return targets
end
-- }}}

-- {{{ local function limit
local function limit(targets, count)
    if count and #targets > count then
        for i = #targets, count + 1, -1 do
            targets[i] = nil
        end
    end
    return targets
end
-- }}}

-- {{{ TargetingSystem:affects_enemies
-- Whether an ability's effect falls on enemies (damage, debuffs, area
-- damage) or on allies (healing, buffs, area healing).
function TargetingSystem.affects_enemies(ability)
    if ability.type == "area" then
        return (ability.area_effect or "damage") ~= "heal"
    end
    if ability.targeting == "ally" or ability.targeting == "self" then
        return false
    end
    return ability.type ~= "heal" and ability.type ~= "buff"
end
-- }}}

-- {{{ TargetingSystem:find_unit_targets
-- Enemy and ally targeting.
function TargetingSystem:find_unit_targets(caster, ability, enemies)
    local found = {}
    local candidates = self:units_within(caster.x, caster.y, ability.range, function(unit)
        if enemies then
            return unit.team ~= caster.team
        end
        if unit.entity == caster.entity then
            return not ability.exclude_self
        end
        return unit.team == caster.team
    end)
    for _, unit in ipairs(candidates) do
        local target = make_target(unit, caster, ability)
        if unit.entity == caster.entity or not ability.line_of_sight
            or self:has_line_of_sight(caster.x, caster.y, unit.x, unit.y) then
            found[#found + 1] = target
        end
    end
    local mode = ability.target_priority or TargetingSystem.DEFAULT_PRIORITY[ability.type] or "closest"
    TargetingSystem.prioritize(found, mode)
    return limit(found, ability.max_targets)
end
-- }}}

-- {{{ TargetingSystem:score_center
-- How much good a circle at (x, y) would do: for each affected unit
-- inside, the share of the ability's power it can use (health for
-- damage, missing health for healing), weaker towards the edge.
function TargetingSystem:score_center(x, y, ability, affected_team_test)
    local radius = ability.area_radius
    local falloff = ability.falloff or 0
    local heal = (ability.area_effect or "damage") == "heal"
    local power = ability.power > 0 and ability.power or 1
    local score, count = 0, 0
    for _, unit in ipairs(self:units_within(x, y, radius, affected_team_test)) do
        local dx, dy = unit.x - x, unit.y - y
        local factor = 1 - falloff * math.sqrt(dx * dx + dy * dy) / radius
        local need = heal and (unit.max_health - unit.current_health) or unit.current_health
        score = score + factor * math.min(power, need) / power
        count = count + 1
    end
    return score, count
end
-- }}}

-- {{{ TargetingSystem:find_area_targets
-- Area and ground targeting. Candidate centres are the affected units
-- within range of the caster (and the caster itself, for healing); the
-- best-scoring one with line of sight wins.
function TargetingSystem:find_area_targets(caster, ability)
    local enemies = TargetingSystem.affects_enemies(ability)
    local affected = function(unit)
        if enemies then
            return unit.team ~= caster.team
        end
        return unit.team == caster.team
    end

    local best, best_score = nil, 0
    for _, candidate in ipairs(self:units_within(caster.x, caster.y, ability.range, affected)) do
        local score = self:score_center(candidate.x, candidate.y, ability, affected)
        if score > best_score + 1e-9 then
            local is_caster = candidate.entity == caster.entity
            if is_caster or not ability.line_of_sight
                or self:has_line_of_sight(caster.x, caster.y, candidate.x, candidate.y) then
                best, best_score = candidate, score
            end
        end
    end
    if not best then
        return {}, {reason = "no_targets"}
    end

    local targets = {}
    for _, unit in ipairs(self:units_within(best.x, best.y, ability.area_radius, affected)) do
        -- With line of sight on, a wall between the centre and a unit
        -- shields it.
        if ability.line_of_sight and unit.entity ~= best.entity
            and not self:has_line_of_sight(best.x, best.y, unit.x, unit.y) then
            goto continue
        end
        local target = make_target(unit, caster, ability)
        local dx, dy = unit.x - best.x, unit.y - best.y
        target.distance_from_center = math.sqrt(dx * dx + dy * dy)
        targets[#targets + 1] = target
        ::continue::
    end
    table.sort(targets, function(a, b)
        if a.distance_from_center ~= b.distance_from_center then
            return a.distance_from_center < b.distance_from_center
        end
        return a.entity.id < b.entity.id
    end)
    limit(targets, ability.max_targets)
    return targets, {center = {x = best.x, y = best.y}, score = best_score}
end
-- }}}

-- {{{ TargetingSystem:find_targets
-- Returns targets (best first) and info: {center, score} for areas, or
-- {reason} when nothing was found ("no_caster" or "no_targets").
function TargetingSystem:find_targets(caster_entity, ability)
    self.stats.queries = self.stats.queries + 1
    local key = tostring(caster_entity.id) .. ":" .. tostring(ability.id)
    local cached = self.cache[key]
    if cached then
        self.stats.cache_hits = self.stats.cache_hits + 1
        return cached.targets, cached.info
    end

    local caster = self:snapshot().units[caster_entity]
    local targets, info
    if not caster then
        targets, info = {}, {reason = "no_caster"}
    elseif ability.targeting == "self" then
        targets, info = {make_target(caster, caster, ability)}, {}
    elseif ability.targeting == "area" or ability.targeting == "ground" then
        targets, info = self:find_area_targets(caster, ability)
    else
        targets, info = self:find_unit_targets(caster, ability, ability.targeting == "enemy"), {}
    end
    if #targets == 0 and not info.reason then
        info.reason = "no_targets"
    end

    self.cache[key] = {targets = targets, info = info}
    return targets, info
end
-- }}}

return TargetingSystem
-- }}}
