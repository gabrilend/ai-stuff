--[[
Collision Detection System - Main API

Provides collision detection for the game engine:
- Collision component for entities
- Shape-based collision testing (circle, rect, point)
- Layer/mask filtering for collision groups
- Spatial queries (radius, rect, point)

Usage:
    local collision = require("runtime.collision")
    collision.init(ecs)  -- Register component with ECS

    -- Add collision to entity
    ecs.add_component(entity, "collision", {
        shape = "circle",
        radius = 32,
        layer = "unit",
        mask = {"unit", "building"},
    })
]]

local collision = {}

local shapes = require("runtime.collision.shapes")
local spatial = require("runtime.collision.spatial")

-- {{{ Module state
local ecs = nil  -- ECS reference, set during init
local initialized = false

-- Track which targets each projectile has hit (for piercing projectiles)
-- Moved here so reset() can clear it
local projectile_hits = {}
-- }}}

-- {{{ Shape constants
collision.SHAPE = {
    CIRCLE = "circle",
    RECT = "rect",
    POINT = "point",
}
-- }}}

-- {{{ Layer constants
-- Common collision layers for WC3-style games
collision.LAYER = {
    UNIT = "unit",
    BUILDING = "building",
    PROJECTILE = "projectile",
    TRIGGER = "trigger",
    DEBRIS = "debris",
    ITEM = "item",
}
-- }}}

-- {{{ Layer priority for picking/selection
-- Higher priority = selected first when overlapping
local LAYER_PRIORITY = {
    unit = 100,
    building = 50,
    item = 40,
    trigger = 10,
    projectile = 5,
    debris = 1,
}

function collision.get_layer_priority(layer)
    return LAYER_PRIORITY[layer] or 0
end

function collision.set_layer_priority(layer, priority)
    LAYER_PRIORITY[layer] = priority
end
-- }}}

-- {{{ collision.init
-- Initialize collision system and register component with ECS.
-- Must be called before using collision features.
function collision.init(ecs_module)
    if initialized then
        return
    end

    ecs = ecs_module

    -- Register collision component with default values (only if not already registered)
    local existing = ecs.get_component_defaults("collision")
    if not existing then
        ecs.register_component("collision", {
            shape = "circle",      -- "circle", "rect", "point"
            radius = 32,           -- for circles
            width = 64,            -- for rects
            height = 64,           -- for rects

            layer = "unit",        -- this entity's collision layer
            mask = {"unit"},       -- layers this entity collides with

            solid = true,          -- blocks movement if true
            trigger = false,       -- fires events but doesn't block
        })
    end

    initialized = true
end
-- }}}

-- {{{ collision.is_initialized
-- Check if collision system has been initialized.
function collision.is_initialized()
    return initialized
end
-- }}}

-- {{{ collision.get_ecs
-- Get the ECS reference (for internal use by sub-modules).
function collision.get_ecs()
    return ecs
end
-- }}}

-- {{{ collision.reset
-- Reset collision system state (for testing).
function collision.reset()
    initialized = false
    ecs = nil
    -- Clear projectile hit tracking
    for k in pairs(projectile_hits) do
        projectile_hits[k] = nil
    end
end
-- }}}

-- {{{ layer_matches_mask
-- Check if a layer string matches any entry in a mask table.
-- Returns true if mask is nil (match all) or contains layer or "*".
function collision.layer_matches_mask(layer, mask)
    if not mask then
        return true
    end

    for _, m in ipairs(mask) do
        if m == layer or m == "*" then
            return true
        end
    end

    return false
end
-- }}}

-- {{{ shapes_collide
-- Test collision between two entities based on their shape types.
-- pos1, col1: position and collision component of first entity
-- pos2, col2: position and collision component of second entity
-- Returns true if shapes overlap.
function collision.shapes_collide(pos1, col1, pos2, col2)
    local s1, s2 = col1.shape, col2.shape

    if s1 == "circle" and s2 == "circle" then
        return shapes.circles_collide(
            pos1.x, pos1.y, col1.radius,
            pos2.x, pos2.y, col2.radius
        )

    elseif s1 == "circle" and s2 == "rect" then
        return shapes.circle_rect_collide(
            pos1.x, pos1.y, col1.radius,
            pos2.x, pos2.y, col2.width, col2.height
        )

    elseif s1 == "rect" and s2 == "circle" then
        return shapes.circle_rect_collide(
            pos2.x, pos2.y, col2.radius,
            pos1.x, pos1.y, col1.width, col1.height
        )

    elseif s1 == "rect" and s2 == "rect" then
        return shapes.rects_collide(
            pos1.x, pos1.y, col1.width, col1.height,
            pos2.x, pos2.y, col2.width, col2.height
        )

    elseif s1 == "point" then
        if s2 == "circle" then
            return shapes.point_in_circle(pos1.x, pos1.y, pos2.x, pos2.y, col2.radius)
        elseif s2 == "rect" then
            return shapes.point_in_rect(pos1.x, pos1.y, pos2.x, pos2.y, col2.width, col2.height)
        elseif s2 == "point" then
            -- Point-point: exact match within epsilon
            return math.abs(pos1.x - pos2.x) < 1 and math.abs(pos1.y - pos2.y) < 1
        end

    elseif s2 == "point" then
        if s1 == "circle" then
            return shapes.point_in_circle(pos2.x, pos2.y, pos1.x, pos1.y, col1.radius)
        elseif s1 == "rect" then
            return shapes.point_in_rect(pos2.x, pos2.y, pos1.x, pos1.y, col1.width, col1.height)
        end
    end

    return false
end
-- }}}

-- {{{ get_entity_radius
-- Get effective collision radius for an entity.
-- For rects, returns half-diagonal (bounding circle).
function collision.get_entity_radius(col)
    if col.shape == "circle" then
        return col.radius
    elseif col.shape == "rect" then
        return math.sqrt(col.width * col.width + col.height * col.height) / 2
    else
        return 0  -- point
    end
end
-- }}}

-- {{{ Re-export shapes module functions
-- Direct access to primitive collision functions
collision.circles_collide = shapes.circles_collide
collision.point_in_circle = shapes.point_in_circle
collision.point_in_rect = shapes.point_in_rect
collision.rects_collide = shapes.rects_collide
collision.circle_rect_collide = shapes.circle_rect_collide
collision.distance = shapes.distance
collision.distance_squared = shapes.distance_squared
collision.get_separation_vector = shapes.get_separation_vector
-- }}}

-- ============================================================================
-- Spatial Query API (405c)
-- Combines broad-phase (spatial hash) with narrow-phase (shape collision)
-- ============================================================================

-- {{{ collision.update
-- Update spatial hash. Call once per frame before queries.
function collision.update()
    if not initialized then
        error("Collision system not initialized. Call collision.init(ecs) first.")
    end
    spatial.update_all(ecs)
end
-- }}}

-- {{{ collision.query_radius
-- Find all entities whose collision shape overlaps a circle.
-- x, y: center of query circle
-- radius: query radius
-- layer_mask: optional table of layer strings to match (nil = all)
-- Returns: array of entities, sorted by distance (nearest first)
function collision.query_radius(x, y, radius, layer_mask)
    if not initialized then
        return {}
    end

    local results = {}

    -- Broad phase: get candidates from spatial hash
    local candidates = spatial.get_nearby(x, y, radius)

    for _, entity in ipairs(candidates) do
        local pos = ecs.get_component(entity, "position")
        local col = ecs.get_component(entity, "collision")

        if pos and col then
            -- Check layer filter
            if collision.layer_matches_mask(col.layer, layer_mask) then
                -- Narrow phase: precise collision check
                local collides = false

                if col.shape == "circle" then
                    collides = shapes.circles_collide(x, y, radius, pos.x, pos.y, col.radius)
                elseif col.shape == "rect" then
                    collides = shapes.circle_rect_collide(x, y, radius, pos.x, pos.y, col.width, col.height)
                elseif col.shape == "point" then
                    collides = shapes.point_in_circle(pos.x, pos.y, x, y, radius)
                end

                if collides then
                    local dx = pos.x - x
                    local dy = pos.y - y
                    local dist_sq = dx * dx + dy * dy
                    results[#results + 1] = {entity = entity, dist_sq = dist_sq}
                end
            end
        end
    end

    -- Sort by distance (nearest first)
    table.sort(results, function(a, b) return a.dist_sq < b.dist_sq end)

    -- Extract just entities
    local entities = {}
    for i, r in ipairs(results) do
        entities[i] = r.entity
    end

    return entities
end
-- }}}

-- {{{ collision.query_rect
-- Find all entities whose collision shape overlaps a rectangle.
-- x, y: center of query rectangle
-- width, height: dimensions of query rectangle
-- layer_mask: optional table of layer strings to match
-- Returns: array of entities (unsorted)
function collision.query_rect(x, y, width, height, layer_mask)
    if not initialized then
        return {}
    end

    local results = {}

    -- Broad phase: get candidates from spatial hash
    local candidates = spatial.get_in_rect(x, y, width, height)

    for _, entity in ipairs(candidates) do
        local pos = ecs.get_component(entity, "position")
        local col = ecs.get_component(entity, "collision")

        if pos and col then
            if collision.layer_matches_mask(col.layer, layer_mask) then
                local collides = false

                if col.shape == "circle" then
                    collides = shapes.circle_rect_collide(pos.x, pos.y, col.radius, x, y, width, height)
                elseif col.shape == "rect" then
                    collides = shapes.rects_collide(x, y, width, height, pos.x, pos.y, col.width, col.height)
                elseif col.shape == "point" then
                    collides = shapes.point_in_rect(pos.x, pos.y, x, y, width, height)
                end

                if collides then
                    results[#results + 1] = entity
                end
            end
        end
    end

    return results
end
-- }}}

-- {{{ collision.query_point
-- Find entity at an exact point (for mouse picking).
-- Returns the topmost entity at the point, or nil.
-- Priority: units > buildings > items > triggers
function collision.query_point(x, y, layer_mask)
    if not initialized then
        return nil
    end

    local results = {}

    -- Use small radius for spatial hash query (to catch entities at point)
    local candidates = spatial.get_nearby(x, y, 64)

    for _, entity in ipairs(candidates) do
        local pos = ecs.get_component(entity, "position")
        local col = ecs.get_component(entity, "collision")

        if pos and col then
            if collision.layer_matches_mask(col.layer, layer_mask) then
                local contains = false

                if col.shape == "circle" then
                    contains = shapes.point_in_circle(x, y, pos.x, pos.y, col.radius)
                elseif col.shape == "rect" then
                    contains = shapes.point_in_rect(x, y, pos.x, pos.y, col.width, col.height)
                elseif col.shape == "point" then
                    -- Point-point: exact match only (within small epsilon)
                    contains = (math.abs(pos.x - x) < 1 and math.abs(pos.y - y) < 1)
                end

                if contains then
                    results[#results + 1] = {entity = entity, layer = col.layer}
                end
            end
        end
    end

    if #results == 0 then
        return nil
    end

    -- Sort by selection priority (higher priority first)
    table.sort(results, function(a, b)
        return collision.get_layer_priority(a.layer) > collision.get_layer_priority(b.layer)
    end)

    return results[1].entity
end
-- }}}

-- {{{ collision.query_all_at_point
-- Find all entities at an exact point.
-- Returns array of entities sorted by priority (highest first).
function collision.query_all_at_point(x, y, layer_mask)
    if not initialized then
        return {}
    end

    local results = {}

    local candidates = spatial.get_nearby(x, y, 64)

    for _, entity in ipairs(candidates) do
        local pos = ecs.get_component(entity, "position")
        local col = ecs.get_component(entity, "collision")

        if pos and col then
            if collision.layer_matches_mask(col.layer, layer_mask) then
                local contains = false

                if col.shape == "circle" then
                    contains = shapes.point_in_circle(x, y, pos.x, pos.y, col.radius)
                elseif col.shape == "rect" then
                    contains = shapes.point_in_rect(x, y, pos.x, pos.y, col.width, col.height)
                elseif col.shape == "point" then
                    contains = (math.abs(pos.x - x) < 1 and math.abs(pos.y - y) < 1)
                end

                if contains then
                    results[#results + 1] = {entity = entity, priority = collision.get_layer_priority(col.layer)}
                end
            end
        end
    end

    -- Sort by priority
    table.sort(results, function(a, b) return a.priority > b.priority end)

    -- Extract entities
    local entities = {}
    for i, r in ipairs(results) do
        entities[i] = r.entity
    end

    return entities
end
-- }}}

-- {{{ collision.query_colliding
-- Find all entities colliding with a specific entity.
-- entity: the entity to check collisions for
-- layer_mask: optional layer filter
-- Returns: array of colliding entities
function collision.query_colliding(entity, layer_mask)
    if not initialized then
        return {}
    end

    local pos = ecs.get_component(entity, "position")
    local col = ecs.get_component(entity, "collision")

    if not pos or not col then
        return {}
    end

    local results = {}

    -- Determine query radius based on shape
    local radius = collision.get_entity_radius(col)

    -- Get candidates (double radius to catch overlapping entities)
    local candidates = spatial.get_nearby(pos.x, pos.y, radius * 2)

    for _, other in ipairs(candidates) do
        if other ~= entity then
            local other_pos = ecs.get_component(other, "position")
            local other_col = ecs.get_component(other, "collision")

            if other_pos and other_col then
                if collision.layer_matches_mask(other_col.layer, layer_mask) then
                    if collision.shapes_collide(pos, col, other_pos, other_col) then
                        results[#results + 1] = other
                    end
                end
            end
        end
    end

    return results
end
-- }}}

-- {{{ collision.set_cell_size
-- Configure spatial hash cell size.
-- Larger cells = fewer lookups but more entities per cell.
-- Rule of thumb: 2-4x the largest entity radius.
function collision.set_cell_size(size)
    spatial.set_cell_size(size)
end
-- }}}

-- {{{ collision.get_cell_size
-- Get current spatial hash cell size.
function collision.get_cell_size()
    return spatial.get_cell_size()
end
-- }}}

-- {{{ collision.get_stats
-- Get collision system statistics.
function collision.get_stats()
    return spatial.get_stats()
end
-- }}}

-- {{{ collision.clear_spatial
-- Clear spatial hash (for testing or level transitions).
function collision.clear_spatial()
    spatial.clear()
end
-- }}}

-- ============================================================================
-- Projectile Hit Detection and Picking API (405e)
-- ============================================================================

-- Note: projectile_hits table is declared at top of module in Module state section

-- {{{ collision.register_projectile_hit
-- Register that a projectile hit a target (prevents double hits).
function collision.register_projectile_hit(projectile, target)
    if not projectile_hits[projectile] then
        projectile_hits[projectile] = {}
    end
    projectile_hits[projectile][target] = true
end
-- }}}

-- {{{ collision.was_hit_by
-- Check if target was already hit by this projectile.
function collision.was_hit_by(projectile, target)
    local hits = projectile_hits[projectile]
    return hits and hits[target] or false
end
-- }}}

-- {{{ collision.clear_projectile_hits
-- Clear hit tracking for a projectile (call when destroyed).
function collision.clear_projectile_hits(projectile)
    projectile_hits[projectile] = nil
end
-- }}}

-- {{{ collision.get_projectile_hit_count
-- Get number of targets hit by a projectile.
function collision.get_projectile_hit_count(projectile)
    local hits = projectile_hits[projectile]
    if not hits then return 0 end

    local count = 0
    for _ in pairs(hits) do
        count = count + 1
    end
    return count
end
-- }}}

-- {{{ collision.is_valid_target
-- Check if target is valid for a projectile.
-- Considers: already hit, alive, team (if applicable)
-- projectile: entity with projectile component
-- target: potential target entity
-- options: optional table with target_allies, target_enemies flags
function collision.is_valid_target(projectile, target, options)
    options = options or {}

    -- Skip already hit targets
    if collision.was_hit_by(projectile, target) then
        return false
    end

    if not ecs then
        return true  -- Can't check without ECS
    end

    -- Get target components
    local target_unit = ecs.get_component(target, "unit_type")
    local target_stats = ecs.get_component(target, "stats")

    -- Skip dead units (if stats component exists with hp field)
    if target_stats and target_stats.hp and target_stats.hp <= 0 then
        return false
    end

    -- Team filtering (if owner component exists)
    local proj_owner = ecs.get_component(projectile, "owner")
    local target_owner = ecs.get_component(target, "owner")

    if proj_owner and target_owner then
        local same_team = proj_owner.player_id == target_owner.player_id

        -- By default, target enemies only
        local target_allies = options.target_allies or false
        local target_enemies = options.target_enemies
        if target_enemies == nil then target_enemies = true end

        if same_team and not target_allies then
            return false
        end
        if not same_team and not target_enemies then
            return false
        end
    end

    return true
end
-- }}}

-- {{{ collision.check_projectile_hit
-- Check if projectile collides with any valid target.
-- Returns first valid target hit, or nil.
-- projectile: entity with position and collision components
-- options: optional table with target_allies, target_enemies, layer_mask
function collision.check_projectile_hit(projectile, options)
    if not initialized then
        return nil
    end

    options = options or {}

    local pos = ecs.get_component(projectile, "position")
    local col = ecs.get_component(projectile, "collision")

    if not pos then
        return nil
    end

    -- Default to small radius if no collision component
    local radius = col and col.radius or 8
    local layer_mask = options.layer_mask or {"unit"}

    -- Query nearby entities
    local targets = collision.query_radius(pos.x, pos.y, radius, layer_mask)

    for _, target in ipairs(targets) do
        if collision.is_valid_target(projectile, target, options) then
            -- Register hit
            collision.register_projectile_hit(projectile, target)
            return target
        end
    end

    return nil
end
-- }}}

-- {{{ collision.check_projectile_hits_all
-- Check projectile against all valid targets (for AoE/piercing).
-- Returns array of all valid targets hit.
function collision.check_projectile_hits_all(projectile, options)
    if not initialized then
        return {}
    end

    options = options or {}

    local pos = ecs.get_component(projectile, "position")
    local col = ecs.get_component(projectile, "collision")

    if not pos then
        return {}
    end

    local radius = col and col.radius or 8
    local layer_mask = options.layer_mask or {"unit"}

    local results = {}
    local targets = collision.query_radius(pos.x, pos.y, radius, layer_mask)

    for _, target in ipairs(targets) do
        if collision.is_valid_target(projectile, target, options) then
            collision.register_projectile_hit(projectile, target)
            results[#results + 1] = target
        end
    end

    return results
end
-- }}}

-- {{{ collision.is_selectable
-- Check if entity can be selected by the player.
function collision.is_selectable(entity)
    if not ecs then
        return false
    end

    local col = ecs.get_component(entity, "collision")

    -- Must have collision shape
    if not col then
        return false
    end

    -- Only units and buildings are typically selectable
    if col.layer ~= "unit" and col.layer ~= "building" and col.layer ~= "item" then
        return false
    end

    -- Check for selectable component if it exists
    local selectable = ecs.get_component(entity, "selectable")
    if selectable and selectable.can_select == false then
        return false
    end

    return true
end
-- }}}

-- {{{ collision.pick_at_point
-- Find selectable entity at world coordinates (single-click selection).
function collision.pick_at_point(world_x, world_y)
    if not initialized then
        return nil
    end

    local entity = collision.query_point(world_x, world_y, {"unit", "building", "item"})

    if entity and collision.is_selectable(entity) then
        return entity
    end

    return nil
end
-- }}}

-- {{{ collision.pick_in_rect
-- Find all selectable entities in a rectangle (box/drag selection).
-- x1, y1: first corner
-- x2, y2: second corner (can be in any order)
-- max_count: optional limit on selection (default 12, like WC3)
function collision.pick_in_rect(x1, y1, x2, y2, max_count)
    if not initialized then
        return {}
    end

    max_count = max_count or 12

    -- Normalize rectangle
    if x1 > x2 then x1, x2 = x2, x1 end
    if y1 > y2 then y1, y2 = y2, y1 end

    local width = x2 - x1
    local height = y2 - y1
    local center_x = (x1 + x2) / 2
    local center_y = (y1 + y2) / 2

    -- Query rectangle for selectable layers
    local candidates = collision.query_rect(center_x, center_y, width, height, {"unit", "building", "item"})

    -- Filter to selectable only
    local results = {}
    for _, entity in ipairs(candidates) do
        if collision.is_selectable(entity) then
            results[#results + 1] = entity
        end
    end

    -- Limit selection count
    if #results > max_count then
        -- Build distance table for sorting
        local dist_map = {}
        local cx, cy = center_x, center_y
        for _, entity in ipairs(results) do
            local pos = ecs.get_component(entity, "position")
            if pos then
                local dx = pos.x - cx
                local dy = pos.y - cy
                dist_map[entity] = dx * dx + dy * dy
            else
                dist_map[entity] = math.huge
            end
        end

        -- Sort by distance
        table.sort(results, function(a, b)
            return dist_map[a] < dist_map[b]
        end)

        -- Truncate to max count
        local truncated = {}
        for i = 1, max_count do
            truncated[i] = results[i]
        end

        results = truncated
    end

    return results
end
-- }}}

-- {{{ collision.pick_all_at_point
-- Find all selectable entities at a point.
function collision.pick_all_at_point(world_x, world_y)
    if not initialized then
        return {}
    end

    local entities = collision.query_all_at_point(world_x, world_y, {"unit", "building", "item"})

    local results = {}
    for _, entity in ipairs(entities) do
        if collision.is_selectable(entity) then
            results[#results + 1] = entity
        end
    end

    return results
end
-- }}}

-- ============================================================================
-- Movement Collision Integration (405d)
-- Functions for checking movement validity and resolving overlaps
-- ============================================================================

-- {{{ collision.can_move_to
-- Check if entity can move to a new position without collision.
-- Returns: boolean success, entity that blocked (or nil)
function collision.can_move_to(entity, new_x, new_y)
    if not initialized then
        return true, nil
    end

    local col = ecs.get_component(entity, "collision")

    -- Non-solid entities can always move
    if not col or not col.solid then
        return true, nil
    end

    -- Get effective radius for broad-phase query
    local radius = collision.get_entity_radius(col)

    -- Broad phase: query for nearby entities at new position
    -- Use double radius to catch all potential colliders
    local candidates = spatial.get_nearby(new_x, new_y, radius * 2)

    for _, other in ipairs(candidates) do
        if other ~= entity then
            local other_pos = ecs.get_component(other, "position")
            local other_col = ecs.get_component(other, "collision")

            if other_pos and other_col and other_col.solid then
                -- Check if entity's mask includes other's layer
                if collision.layer_matches_mask(other_col.layer, col.mask) then
                    -- Create temporary position for collision test
                    local temp_pos = {x = new_x, y = new_y}

                    if collision.shapes_collide(temp_pos, col, other_pos, other_col) then
                        return false, other
                    end
                end
            end
        end
    end

    return true, nil
end
-- }}}

-- {{{ collision.resolve_overlap
-- Push two overlapping entities apart using minimum separation vector.
-- Entities are pushed equally in opposite directions.
function collision.resolve_overlap(entity1, entity2)
    if not initialized then
        return
    end

    local pos1 = ecs.get_component(entity1, "position")
    local pos2 = ecs.get_component(entity2, "position")
    local col1 = ecs.get_component(entity1, "collision")
    local col2 = ecs.get_component(entity2, "collision")

    if not (pos1 and pos2 and col1 and col2) then
        return
    end

    -- Calculate separation vector (pointing from entity2 to entity1)
    local dx = pos1.x - pos2.x
    local dy = pos1.y - pos2.y
    local dist = math.sqrt(dx * dx + dy * dy)

    -- Avoid division by zero - push apart on arbitrary axis
    if dist < 0.001 then
        dx, dy = 1, 0
        dist = 1
    end

    -- Calculate overlap amount based on shape types
    local r1 = collision.get_entity_radius(col1)
    local r2 = collision.get_entity_radius(col2)
    local overlap = (r1 + r2) - dist

    if overlap <= 0 then
        return  -- No overlap
    end

    -- Normalize direction
    local nx = dx / dist
    local ny = dy / dist

    -- Push apart equally with small extra margin to prevent re-collision
    local push = overlap / 2 + 0.1

    pos1.x = pos1.x + nx * push
    pos1.y = pos1.y + ny * push
    pos2.x = pos2.x - nx * push
    pos2.y = pos2.y - ny * push

    -- Note: Spatial hash is rebuilt each frame in collision.update()
    -- No need to update individual entities here
end
-- }}}

-- {{{ collision.slide_move
-- Attempt to move entity, sliding along obstacles if blocked.
-- Returns the actual position achieved (may be different from desired).
function collision.slide_move(entity, desired_x, desired_y)
    if not initialized then
        return desired_x, desired_y
    end

    local pos = ecs.get_component(entity, "position")
    if not pos then
        return desired_x, desired_y
    end

    -- Try direct move first
    local can_move, _ = collision.can_move_to(entity, desired_x, desired_y)
    if can_move then
        return desired_x, desired_y
    end

    -- Try sliding along X axis only
    local can_x, _ = collision.can_move_to(entity, desired_x, pos.y)
    if can_x then
        return desired_x, pos.y
    end

    -- Try sliding along Y axis only
    local can_y, _ = collision.can_move_to(entity, pos.x, desired_y)
    if can_y then
        return pos.x, desired_y
    end

    -- Completely blocked - stay in place
    return pos.x, pos.y
end
-- }}}

-- {{{ collision.resolve_all_overlaps
-- Find and resolve all current overlaps between solid entities.
-- Call after movement update to fix any penetrations that occurred.
function collision.resolve_all_overlaps()
    if not initialized then
        return
    end

    -- Collect all entities with solid collision
    local entities = {}
    for entity in ecs.query_single("collision") do
        local col = ecs.get_component(entity, "collision")
        if col and col.solid then
            entities[#entities + 1] = entity
        end
    end

    -- Check all pairs for overlap
    -- This uses spatial hash internally via shapes_collide setup
    for i = 1, #entities do
        for j = i + 1, #entities do
            local e1, e2 = entities[i], entities[j]
            local col1 = ecs.get_component(e1, "collision")
            local col2 = ecs.get_component(e2, "collision")

            -- Check layer compatibility
            if collision.layer_matches_mask(col2.layer, col1.mask) then
                local pos1 = ecs.get_component(e1, "position")
                local pos2 = ecs.get_component(e2, "position")

                if pos1 and pos2 and collision.shapes_collide(pos1, col1, pos2, col2) then
                    collision.resolve_overlap(e1, e2)
                end
            end
        end
    end
end
-- }}}

-- {{{ Trigger zone tracking state
-- Maps trigger entity to table of entities currently inside
local trigger_inside = {}
-- }}}

-- {{{ collision.check_trigger_collisions
-- Check trigger zones and fire enter/leave events.
-- Tracks which entities are inside each trigger and fires events on changes.
-- event_callback: function(event_type, trigger_entity, other_entity)
--   event_type is "trigger_enter" or "trigger_leave"
function collision.check_trigger_collisions(event_callback)
    if not initialized then
        return
    end

    -- Find all trigger entities
    for trigger_entity in ecs.query_single("collision") do
        local col = ecs.get_component(trigger_entity, "collision")

        if col and col.trigger then
            local pos = ecs.get_component(trigger_entity, "position")
            if not pos then
                goto continue
            end

            -- Query for entities currently inside this trigger
            local radius = collision.get_entity_radius(col)
            local candidates = spatial.get_nearby(pos.x, pos.y, radius)

            -- Build current inside set
            local current_inside = {}
            for _, entity in ipairs(candidates) do
                if entity ~= trigger_entity then
                    local other_pos = ecs.get_component(entity, "position")
                    local other_col = ecs.get_component(entity, "collision")

                    if other_pos and other_col then
                        -- Check layer filter
                        if collision.layer_matches_mask(other_col.layer, col.mask) then
                            if collision.shapes_collide(pos, col, other_pos, other_col) then
                                current_inside[entity] = true
                            end
                        end
                    end
                end
            end

            -- Get previous inside set
            local prev_inside = trigger_inside[trigger_entity] or {}

            -- Fire enter events for newly inside entities
            for entity in pairs(current_inside) do
                if not prev_inside[entity] then
                    if event_callback then
                        event_callback("trigger_enter", trigger_entity, entity)
                    end
                end
            end

            -- Fire leave events for entities that left
            for entity in pairs(prev_inside) do
                if not current_inside[entity] then
                    if event_callback then
                        event_callback("trigger_leave", trigger_entity, entity)
                    end
                end
            end

            -- Update tracking
            trigger_inside[trigger_entity] = current_inside

            ::continue::
        end
    end
end
-- }}}

-- {{{ collision.clear_trigger_tracking
-- Clear trigger tracking state (for reset/testing).
function collision.clear_trigger_tracking()
    for k in pairs(trigger_inside) do
        trigger_inside[k] = nil
    end
end
-- }}}

-- {{{ collision.get_trigger_contents
-- Get list of entities currently inside a trigger zone.
function collision.get_trigger_contents(trigger_entity)
    local inside = trigger_inside[trigger_entity]
    if not inside then
        return {}
    end

    local result = {}
    for entity in pairs(inside) do
        result[#result + 1] = entity
    end
    return result
end
-- }}}

return collision
