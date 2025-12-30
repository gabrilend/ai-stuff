# Issue 016e: Derived Attribute Engine

## Current Behavior

No system exists for computing attributes that depend on other attributes. Derived values like "attack power" (from strength + agility) would need manual recalculation scattered throughout the codebase.

## Intended Behavior

A derived attribute engine that:
- Builds dependency graphs from attribute schemas
- Performs lazy evaluation (compute only when accessed)
- Maintains cache invalidation chains
- Detects and prevents circular dependencies
- Supports multi-level derivation (A → B → C)

## Suggested Implementation Steps

### 1. Dependency Graph Builder

```lua
-- src/libs/attributes/derived.lua

local registry = require("src.libs.attributes.registry")

-- {{{ DependencyGraph
local DependencyGraph = {
    -- attr_id -> { attrs this depends on }
    dependencies = {},
    -- attr_id -> { attrs that depend on this }
    dependents = {},
    -- Topological order for evaluation
    eval_order = {},
}

-- {{{ build
function DependencyGraph.build()
    DependencyGraph.dependencies = {}
    DependencyGraph.dependents = {}

    for id, schema in pairs(registry.schemas) do
        if schema:is_derived() then
            DependencyGraph.dependencies[id] = schema.derived_from or {}

            for _, dep_id in ipairs(schema.derived_from) do
                DependencyGraph.dependents[dep_id] =
                    DependencyGraph.dependents[dep_id] or {}
                table.insert(DependencyGraph.dependents[dep_id], id)
            end
        end
    end

    -- Build topological order
    DependencyGraph.eval_order = DependencyGraph.topological_sort()
end
-- }}}

-- {{{ topological_sort
function DependencyGraph.topological_sort()
    local visited = {}
    local temp_mark = {}
    local order = {}

    local function visit(id)
        if temp_mark[id] then
            error("Circular dependency detected: " .. id)
        end
        if visited[id] then return end

        temp_mark[id] = true

        for _, dep_id in ipairs(DependencyGraph.dependencies[id] or {}) do
            visit(dep_id)
        end

        temp_mark[id] = nil
        visited[id] = true
        table.insert(order, id)
    end

    for id, _ in pairs(DependencyGraph.dependencies) do
        visit(id)
    end

    return order
end
-- }}}

-- {{{ get_dependents
function DependencyGraph.get_dependents(attr_id)
    return DependencyGraph.dependents[attr_id] or {}
end
-- }}}

-- {{{ get_all_dependents
-- Recursively get all attributes affected by a change
function DependencyGraph.get_all_dependents(attr_id)
    local result = {}
    local visited = {}

    local function collect(id)
        if visited[id] then return end
        visited[id] = true

        for _, dep_id in ipairs(DependencyGraph.dependents[id] or {}) do
            table.insert(result, dep_id)
            collect(dep_id)
        end
    end

    collect(attr_id)
    return result
end
-- }}}
-- }}}
```

### 2. Lazy Evaluation Cache

```lua
-- {{{ DerivedCache
local DerivedCache = {}

-- {{{ invalidate
function DerivedCache.invalidate(container, attr_id)
    local schema = registry.get(attr_id)
    if not schema then return end

    -- Mark this attribute dirty
    container.dirty[schema.index] = true

    -- Recursively invalidate dependents
    for _, dep_id in ipairs(DependencyGraph.get_dependents(attr_id)) do
        DerivedCache.invalidate(container, dep_id)
    end
end
-- }}}

-- {{{ invalidate_all
function DerivedCache.invalidate_all(container)
    for id, schema in pairs(registry.schemas) do
        if schema:is_derived() then
            container.dirty[schema.index] = true
        end
    end
end
-- }}}

-- {{{ is_dirty
function DerivedCache.is_dirty(container, attr_id)
    local schema = registry.get(attr_id)
    return schema and container.dirty[schema.index]
end
-- }}}

-- {{{ compute
function DerivedCache.compute(container, attr_id)
    local schema = registry.get(attr_id)
    if not schema or not schema:is_derived() then
        return nil, "Not a derived attribute"
    end

    -- Ensure dependencies are computed first
    for _, dep_id in ipairs(schema.derived_from or {}) do
        local dep_schema = registry.get(dep_id)
        if dep_schema and dep_schema:is_derived() then
            if container.dirty[dep_schema.index] then
                DerivedCache.compute(container, dep_id)
            end
        end
    end

    -- Create getter proxy for formula
    local getters = require("src.libs.attributes.getters")
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

-- {{{ recompute_all
-- Force recompute of all derived attributes in dependency order
function DerivedCache.recompute_all(container)
    for _, attr_id in ipairs(DependencyGraph.eval_order) do
        DerivedCache.compute(container, attr_id)
    end
end
-- }}}
-- }}}
```

### 3. Formula Definition Patterns

```lua
-- {{{ Formula patterns for common derived attributes

-- Simple additive formula
-- attack_power = strength * 2 + agility
local function attack_power_formula(get)
    return get("strength") * 2 + get("agility")
end

-- Percentage-based formula
-- crit_chance = (agility / 20) + base_crit
local function crit_chance_formula(get)
    return (get("agility") / 20) + get("base_crit")
end

-- Multi-level derived (depends on another derived)
-- effective_attack_power = attack_power * (1 + crit_chance / 100)
local function effective_attack_power_formula(get)
    return get("attack_power") * (1 + get("crit_chance") / 100)
end

-- Conditional formula
-- armor_reduction = armor / (armor + 400 + 85 * level)
local function armor_reduction_formula(get)
    local armor = get("armor")
    local level = get("level")
    if armor <= 0 then return 0 end
    return armor / (armor + 400 + 85 * level)
end

-- Resource formula (capped)
-- max_health = stamina * 10 + base_health
-- clamped to min 1
local function max_health_formula(get)
    local value = get("stamina") * 10 + get("base_health")
    return math.max(1, value)
end
-- }}}
```

### 4. Debug and Introspection

```lua
-- {{{ Debug utilities

-- {{{ explain_derivation
-- Show the full calculation chain for a derived attribute
function DerivedCache.explain_derivation(container, attr_id)
    local schema = registry.get(attr_id)
    if not schema or not schema:is_derived() then
        return nil, "Not a derived attribute"
    end

    local explanation = {
        attribute = attr_id,
        formula = "formula(get)",  -- Can't serialize function
        dependencies = {},
        final_value = nil,
    }

    local getters = require("src.libs.attributes.getters")

    for _, dep_id in ipairs(schema.derived_from or {}) do
        local dep_value = getters.get(container, dep_id)
        local dep_schema = registry.get(dep_id)

        table.insert(explanation.dependencies, {
            id = dep_id,
            value = dep_value,
            is_derived = dep_schema and dep_schema:is_derived() or false,
        })
    end

    explanation.final_value = getters.get(container, attr_id)

    return explanation
end
-- }}}

-- {{{ get_dependency_tree
-- Visualize the full dependency tree
function DerivedCache.get_dependency_tree(attr_id, depth)
    depth = depth or 0
    local schema = registry.get(attr_id)
    if not schema then return nil end

    local node = {
        id = attr_id,
        depth = depth,
        is_derived = schema:is_derived(),
        children = {},
    }

    if schema:is_derived() then
        for _, dep_id in ipairs(schema.derived_from or {}) do
            local child = DerivedCache.get_dependency_tree(dep_id, depth + 1)
            if child then
                table.insert(node.children, child)
            end
        end
    end

    return node
end
-- }}}

-- {{{ print_dependency_tree
function DerivedCache.print_dependency_tree(attr_id)
    local function print_node(node, prefix)
        local marker = node.is_derived and "[D]" or "[B]"
        print(prefix .. marker .. " " .. node.id)

        for i, child in ipairs(node.children) do
            local is_last = (i == #node.children)
            local child_prefix = prefix .. (is_last and "    " or "│   ")
            local branch = is_last and "└── " or "├── "
            print_node(child, prefix .. branch:sub(1, 0) .. "")
            -- Actually recursively print
        end
    end

    local tree = DerivedCache.get_dependency_tree(attr_id)
    if tree then
        print_node(tree, "")
    end
end
-- }}}
-- }}}

return {
    DependencyGraph = DependencyGraph,
    DerivedCache = DerivedCache,
}
```

### 5. Integration with Getters

```lua
-- In getters.lua, derived attributes use this:

if schema:is_derived() then
    GETTERS[id] = function(container)
        if container.dirty[index] then
            DerivedCache.compute(container, id)
        end
        return container.values[index]
    end
end
```

## Related Documents

- Issue 016a - Schema defines derived_from and formula
- Issue 016b - Getters integrate with lazy evaluation
- Issue 016c - Setters trigger invalidation
- Issue 016f - WC3 derived attributes (attack damage, armor)
- Issue 016g - WoW derived attributes (attack power, spell power)

## Acceptance Criteria

- [ ] Dependency graph built from schemas
- [ ] Topological sort for evaluation order
- [ ] Circular dependency detection with error
- [ ] Lazy evaluation on access
- [ ] Cache invalidation cascades to dependents
- [ ] Multi-level derivation works correctly
- [ ] explain_derivation() for debugging
- [ ] Unit tests for dependency chains

---

**Status:** Pending
**Dependencies:** 016a (Core Attribute Registry)

