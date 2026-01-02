-- Derived Attribute Engine Module
-- Centralized management for computed attributes that depend on other attributes.
--
-- This module provides:
-- - Dependency graph utilities and introspection
-- - Circular dependency detection with clear error messages
-- - Lazy evaluation cache management
-- - Debug tools for explaining derivations
-- - Visualization of dependency trees
--
-- The actual computation is performed by getters.lua, and invalidation is
-- triggered by setters.lua and modifiers.lua. This module provides the
-- orchestration layer and debugging utilities.
--
-- Usage:
--   local derived = require("libs.attributes.derived")
--
--   -- Check for circular dependencies after registration
--   local ok, err = derived.validate_no_cycles()
--
--   -- Debug: explain how a derived value is computed
--   local explanation = derived.explain(container, "attack_power")
--
--   -- Force recompute all derived attributes
--   derived.recompute_all(container)

local registry = require("libs.attributes.registry")

-- {{{ Module state
local derived = {}
-- }}}

-- {{{ Dependency Graph Utilities

-- {{{ derived.get_dependencies
-- Get the list of attributes that this attribute depends on.
-- @param attr_id Attribute ID
-- @return Array of dependency IDs (empty if not derived)
function derived.get_dependencies(attr_id)
    return registry.get_dependencies(attr_id)
end
-- }}}

-- {{{ derived.get_dependents
-- Get the list of attributes that depend on this attribute.
-- @param attr_id Attribute ID
-- @return Array of dependent IDs (empty if nothing depends on this)
function derived.get_dependents(attr_id)
    return registry.get_dependents(attr_id)
end
-- }}}

-- {{{ derived.get_all_dependents
-- Recursively get ALL attributes affected by a change to this attribute.
-- Includes multi-level dependents (A changes → B recalculates → C recalculates).
-- @param attr_id Attribute ID
-- @return Array of all dependent IDs in evaluation order
function derived.get_all_dependents(attr_id)
    local result = {}
    local visited = {}

    local function collect(id)
        local dependents = registry.get_dependents(id)
        for i = 1, #dependents do
            local dep_id = dependents[i]
            if not visited[dep_id] then
                visited[dep_id] = true
                result[#result + 1] = dep_id
                -- Recursively collect dependents of dependents
                collect(dep_id)
            end
        end
    end

    collect(attr_id)
    return result
end
-- }}}

-- {{{ derived.get_all_dependencies
-- Recursively get ALL attributes that this attribute depends on.
-- Includes multi-level dependencies.
-- @param attr_id Attribute ID
-- @return Array of all dependency IDs
function derived.get_all_dependencies(attr_id)
    local result = {}
    local visited = {}

    local function collect(id)
        local deps = registry.get_dependencies(id)
        for i = 1, #deps do
            local dep_id = deps[i]
            if not visited[dep_id] then
                visited[dep_id] = true
                result[#result + 1] = dep_id
                -- Recursively collect dependencies of dependencies
                collect(dep_id)
            end
        end
    end

    collect(attr_id)
    return result
end
-- }}}

-- {{{ derived.get_evaluation_order
-- Get the topological order for evaluating derived attributes.
-- Dependencies are evaluated before dependents.
-- @return Array of attribute IDs in evaluation order
function derived.get_evaluation_order()
    return registry.get_topological_order()
end
-- }}}

-- }}}

-- {{{ Circular Dependency Detection

-- {{{ derived.detect_cycle
-- Detect if adding a dependency would create a cycle.
-- Useful for validating before registration.
-- @param from_id The attribute that would depend on to_id
-- @param to_id The attribute that from_id would depend on
-- @return false if no cycle, or the cycle path as an array
function derived.detect_cycle(from_id, to_id)
    -- If to_id transitively depends on from_id, adding from_id → to_id creates a cycle
    local deps = derived.get_all_dependencies(to_id)
    for i = 1, #deps do
        if deps[i] == from_id then
            -- Build the cycle path
            local path = { from_id, to_id }
            -- Trace back through dependencies
            local current = to_id
            while current ~= from_id do
                local next_deps = registry.get_dependencies(current)
                for j = 1, #next_deps do
                    local dep = next_deps[j]
                    -- Check if this dep leads to from_id
                    local sub_deps = derived.get_all_dependencies(dep)
                    local leads_to_from = dep == from_id
                    if not leads_to_from then
                        for k = 1, #sub_deps do
                            if sub_deps[k] == from_id then
                                leads_to_from = true
                                break
                            end
                        end
                    end
                    if leads_to_from or dep == from_id then
                        path[#path + 1] = dep
                        current = dep
                        break
                    end
                end
                if current == to_id then
                    -- Couldn't trace back, just return simple cycle indicator
                    break
                end
            end
            return path
        end
    end

    return false
end
-- }}}

-- {{{ derived.validate_no_cycles
-- Validate that there are no circular dependencies in the registry.
-- Should be called after bulk registration to catch errors early.
-- @return true if no cycles, or false and error message with cycle path
function derived.validate_no_cycles()
    local schemas = registry.list({ derived = true })

    -- Track visited and in-progress nodes for cycle detection
    local visited = {}
    local in_progress = {}
    local cycle_path = {}

    local function visit(id, path)
        if in_progress[id] then
            -- Found a cycle - build the path
            local cycle = {}
            local found_start = false
            for i = 1, #path do
                if path[i] == id or found_start then
                    found_start = true
                    cycle[#cycle + 1] = path[i]
                end
            end
            cycle[#cycle + 1] = id
            return cycle
        end

        if visited[id] then
            return nil
        end

        in_progress[id] = true
        path[#path + 1] = id

        local deps = registry.get_dependencies(id)
        for i = 1, #deps do
            local cycle = visit(deps[i], path)
            if cycle then
                return cycle
            end
        end

        path[#path] = nil
        in_progress[id] = nil
        visited[id] = true

        return nil
    end

    for i = 1, #schemas do
        local schema = schemas[i]
        local cycle = visit(schema.id, {})
        if cycle then
            local cycle_str = table.concat(cycle, " → ")
            return false, "Circular dependency detected: " .. cycle_str
        end
    end

    return true
end
-- }}}

-- }}}

-- {{{ Cache Management

-- {{{ derived.is_dirty
-- Check if a derived attribute needs recalculation.
-- @param container The attribute container
-- @param attr_id Attribute ID
-- @return boolean
function derived.is_dirty(container, attr_id)
    local schema = registry.get(attr_id)
    if not schema then
        return false
    end
    return container.dirty[schema.index] == true
end
-- }}}

-- {{{ derived.mark_dirty
-- Mark a derived attribute as needing recalculation.
-- Also marks all its dependents as dirty.
-- @param container The attribute container
-- @param attr_id Attribute ID
function derived.mark_dirty(container, attr_id)
    local schema = registry.get(attr_id)
    if schema and schema:is_derived() then
        container.dirty[schema.index] = true
    end

    -- Also mark dependents
    local dependents = registry.get_dependents(attr_id)
    for i = 1, #dependents do
        derived.mark_dirty(container, dependents[i])
    end
end
-- }}}

-- {{{ derived.invalidate_all
-- Mark all derived attributes as needing recalculation.
-- @param container The attribute container
function derived.invalidate_all(container)
    local schemas = registry.list({ derived = true })
    for i = 1, #schemas do
        container.dirty[schemas[i].index] = true
    end
end
-- }}}

-- {{{ derived.recompute
-- Force recomputation of a derived attribute.
-- @param container The attribute container
-- @param attr_id Attribute ID
-- @return The computed value, or nil and error if not derived
function derived.recompute(container, attr_id)
    local schema = registry.get(attr_id)
    if not schema then
        return nil, "Unknown attribute: " .. tostring(attr_id)
    end

    if not schema:is_derived() then
        return nil, "Not a derived attribute: " .. attr_id
    end

    -- Ensure dependencies are computed first
    local deps = schema.derived_from or {}
    for i = 1, #deps do
        local dep_id = deps[i]
        local dep_schema = registry.get(dep_id)
        if dep_schema and dep_schema:is_derived() then
            if container.dirty[dep_schema.index] then
                derived.recompute(container, dep_id)
            end
        end
    end

    -- Create getter proxy for formula
    local getters = require("libs.attributes.getters")
    local get = function(id)
        return getters.get(container, id) or 0
    end

    -- Execute formula
    local new_value = schema.formula(get)

    -- Store result and clear dirty flag
    container.values[schema.index] = new_value
    container.dirty[schema.index] = nil

    return new_value
end
-- }}}

-- {{{ derived.recompute_all
-- Force recomputation of all derived attributes in dependency order.
-- @param container The attribute container
-- @return Table mapping attr_id to new value
function derived.recompute_all(container)
    local results = {}
    local eval_order = derived.get_evaluation_order()

    for i = 1, #eval_order do
        local attr_id = eval_order[i]
        local schema = registry.get(attr_id)
        if schema and schema:is_derived() then
            results[attr_id] = derived.recompute(container, attr_id)
        end
    end

    return results
end
-- }}}

-- {{{ derived.get_dirty_count
-- Count how many derived attributes are currently dirty.
-- @param container The attribute container
-- @return number
function derived.get_dirty_count(container)
    local count = 0
    local schemas = registry.list({ derived = true })
    for i = 1, #schemas do
        if container.dirty[schemas[i].index] then
            count = count + 1
        end
    end
    return count
end
-- }}}

-- }}}

-- {{{ Debug and Introspection

-- {{{ derived.explain
-- Get a detailed explanation of how a derived value is computed.
-- Useful for debugging and UI tooltips.
-- @param container The attribute container
-- @param attr_id Attribute ID
-- @return Explanation table, or nil and error message
function derived.explain(container, attr_id)
    local schema = registry.get(attr_id)
    if not schema then
        return nil, "Unknown attribute: " .. tostring(attr_id)
    end

    if not schema:is_derived() then
        return nil, "Not a derived attribute: " .. attr_id
    end

    local getters = require("libs.attributes.getters")

    local explanation = {
        attribute = attr_id,
        index = schema.index,
        is_dirty = container.dirty[schema.index] == true,
        dependencies = {},
        final_value = getters.get(container, attr_id),
    }

    -- Collect dependency info
    local deps = schema.derived_from or {}
    for i = 1, #deps do
        local dep_id = deps[i]
        local dep_schema = registry.get(dep_id)
        local dep_value = getters.get(container, dep_id)

        explanation.dependencies[#explanation.dependencies + 1] = {
            id = dep_id,
            value = dep_value,
            raw_value = getters.get_raw(container, dep_id),
            is_derived = dep_schema and dep_schema:is_derived() or false,
            is_dirty = dep_schema and container.dirty[dep_schema.index] or false,
        }
    end

    return explanation
end
-- }}}

-- {{{ derived.get_dependency_tree
-- Build a tree structure showing the full dependency chain.
-- @param attr_id Attribute ID
-- @param max_depth Optional maximum depth (default: 10)
-- @return Tree node table
function derived.get_dependency_tree(attr_id, max_depth)
    max_depth = max_depth or 10

    local function build_node(id, depth)
        if depth > max_depth then
            return { id = id, truncated = true }
        end

        local schema = registry.get(id)
        if not schema then
            return { id = id, error = "Unknown attribute" }
        end

        local node = {
            id = id,
            depth = depth,
            is_derived = schema:is_derived(),
            children = {},
        }

        if schema:is_derived() then
            local deps = schema.derived_from or {}
            for i = 1, #deps do
                node.children[#node.children + 1] = build_node(deps[i], depth + 1)
            end
        end

        return node
    end

    return build_node(attr_id, 0)
end
-- }}}

-- {{{ derived.format_dependency_tree
-- Format a dependency tree as a string for display.
-- @param attr_id Attribute ID
-- @param max_depth Optional maximum depth
-- @return Formatted string
function derived.format_dependency_tree(attr_id, max_depth)
    local tree = derived.get_dependency_tree(attr_id, max_depth)
    local lines = {}

    local function format_node(node, prefix, is_last)
        local marker = node.is_derived and "[D]" or "[B]"
        local status = ""
        if node.truncated then
            status = " ..."
        elseif node.error then
            status = " (error: " .. node.error .. ")"
        end

        lines[#lines + 1] = prefix .. marker .. " " .. node.id .. status

        if node.children then
            for i = 1, #node.children do
                local child = node.children[i]
                local child_is_last = (i == #node.children)
                local new_prefix = prefix .. (is_last and "    " or "│   ")
                local branch = child_is_last and "└── " or "├── "
                format_node(child, prefix .. branch, child_is_last)
            end
        end
    end

    format_node(tree, "", true)
    return table.concat(lines, "\n")
end
-- }}}

-- {{{ derived.get_reverse_tree
-- Build a tree showing what depends on this attribute.
-- @param attr_id Attribute ID
-- @param max_depth Optional maximum depth (default: 10)
-- @return Tree node table
function derived.get_reverse_tree(attr_id, max_depth)
    max_depth = max_depth or 10

    local function build_node(id, depth)
        if depth > max_depth then
            return { id = id, truncated = true }
        end

        local schema = registry.get(id)
        if not schema then
            return { id = id, error = "Unknown attribute" }
        end

        local node = {
            id = id,
            depth = depth,
            is_derived = schema:is_derived(),
            children = {},
        }

        local dependents = registry.get_dependents(id)
        for i = 1, #dependents do
            node.children[#node.children + 1] = build_node(dependents[i], depth + 1)
        end

        return node
    end

    return build_node(attr_id, 0)
end
-- }}}

-- {{{ derived.list_derived
-- List all derived attributes with their dependencies.
-- @return Array of { id, dependencies, dependents }
function derived.list_derived()
    local schemas = registry.list({ derived = true })
    local result = {}

    for i = 1, #schemas do
        local schema = schemas[i]
        result[#result + 1] = {
            id = schema.id,
            index = schema.index,
            dependencies = schema.derived_from or {},
            dependents = registry.get_dependents(schema.id),
        }
    end

    return result
end
-- }}}

-- {{{ derived.get_stats
-- Get statistics about derived attributes.
-- @param container Optional - if provided, includes dirty counts
-- @return Stats table
function derived.get_stats(container)
    local schemas = registry.list({ derived = true })
    local all_schemas = registry.list()

    local stats = {
        total_attributes = #all_schemas,
        derived_count = #schemas,
        base_count = #all_schemas - #schemas,
        max_depth = 0,
        multi_level_count = 0,  -- Derived that depend on other derived
    }

    -- Calculate max depth and multi-level count
    for i = 1, #schemas do
        local schema = schemas[i]
        local deps = schema.derived_from or {}

        -- Check if any dependency is derived (multi-level)
        for j = 1, #deps do
            local dep_schema = registry.get(deps[j])
            if dep_schema and dep_schema:is_derived() then
                stats.multi_level_count = stats.multi_level_count + 1
                break
            end
        end

        -- Calculate depth
        local depth = 0
        local function calc_depth(id, d)
            local s = registry.get(id)
            if s and s:is_derived() then
                d = d + 1
                if d > depth then depth = d end
                local sub_deps = s.derived_from or {}
                for k = 1, #sub_deps do
                    calc_depth(sub_deps[k], d)
                end
            end
        end
        calc_depth(schema.id, 0)
        if depth > stats.max_depth then
            stats.max_depth = depth
        end
    end

    -- Add dirty stats if container provided
    if container then
        stats.dirty_count = derived.get_dirty_count(container)
    end

    return stats
end
-- }}}

-- }}}

-- {{{ Formula Helpers

-- {{{ derived.create_formula
-- Helper to create common formula patterns.
-- @param pattern Pattern name ("sum", "weighted_sum", "max", "min", "product")
-- @param deps Dependency specifications
-- @return Formula function
function derived.create_formula(pattern, deps)
    if pattern == "sum" then
        -- Simple sum: sum of all dependencies
        return function(get)
            local total = 0
            for i = 1, #deps do
                total = total + (get(deps[i]) or 0)
            end
            return total
        end

    elseif pattern == "weighted_sum" then
        -- Weighted sum: { {id, weight}, ... }
        return function(get)
            local total = 0
            for i = 1, #deps do
                local id, weight = deps[i][1], deps[i][2]
                total = total + (get(id) or 0) * weight
            end
            return total
        end

    elseif pattern == "max" then
        -- Maximum of all dependencies
        return function(get)
            local result = nil
            for i = 1, #deps do
                local val = get(deps[i]) or 0
                if result == nil or val > result then
                    result = val
                end
            end
            return result or 0
        end

    elseif pattern == "min" then
        -- Minimum of all dependencies
        return function(get)
            local result = nil
            for i = 1, #deps do
                local val = get(deps[i]) or 0
                if result == nil or val < result then
                    result = val
                end
            end
            return result or 0
        end

    elseif pattern == "product" then
        -- Product of all dependencies
        return function(get)
            local result = 1
            for i = 1, #deps do
                result = result * (get(deps[i]) or 1)
            end
            return result
        end

    else
        error("Unknown formula pattern: " .. tostring(pattern))
    end
end
-- }}}

-- }}}

return derived
