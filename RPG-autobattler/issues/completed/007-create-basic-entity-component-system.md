# Issue #007: Create Basic Entity Component System

## Current Behavior
No entity-component system exists to manage game objects like units, projectiles, and bases.

## Intended Behavior
A lightweight ECS (Entity-Component-System) should be implemented to efficiently manage game entities and their behaviors.

## Implementation Details

### Entity Manager (src/systems/entity_manager.lua)
```lua
local EntityManager = {}
EntityManager.entities = {}
EntityManager.next_id = 1
EntityManager.components = {}

function EntityManager:create_entity()
    local entity = {
        id = self.next_id,
        components = {}
    }
    self.entities[self.next_id] = entity
    self.next_id = self.next_id + 1
    return entity
end

function EntityManager:add_component(entity, component_type, component_data)
    entity.components[component_type] = component_data
    
    if not self.components[component_type] then
        self.components[component_type] = {}
    end
    self.components[component_type][entity.id] = component_data
end

function EntityManager:get_entities_with_component(component_type)
    local entities = {}
    for entity_id, _ in pairs(self.components[component_type] or {}) do
        table.insert(entities, self.entities[entity_id])
    end
    return entities
end

function EntityManager:remove_entity(entity)
    for component_type, _ in pairs(entity.components) do
        self.components[component_type][entity.id] = nil
    end
    self.entities[entity.id] = nil
end

return EntityManager
```

### Core Components (src/components/)
1. **Position**: x, y coordinates
2. **Health**: current_hp, max_hp
3. **Team**: player_id, team_color
4. **Renderable**: shape, color, size
5. **Moveable**: velocity, target_position

### Component Definitions
```lua
-- src/components/position.lua
return function(x, y)
    return {
        x = x or 0,
        y = y or 0
    }
end

-- src/components/health.lua
return function(max_hp)
    return {
        current_hp = max_hp,
        max_hp = max_hp,
        alive = true
    }
end
```

### System Framework (src/systems/base_system.lua)
```lua
local BaseSystem = {}
BaseSystem.__index = BaseSystem

function BaseSystem:new(entity_manager)
    local system = {
        entity_manager = entity_manager,
        required_components = {}
    }
    setmetatable(system, BaseSystem)
    return system
end

function BaseSystem:get_entities()
    -- Return entities that have all required components
    local entities = {}
    for _, entity in pairs(self.entity_manager.entities) do
        local has_all = true
        for _, component in ipairs(self.required_components) do
            if not entity.components[component] then
                has_all = false
                break
            end
        end
        if has_all then
            table.insert(entities, entity)
        end
    end
    return entities
end

function BaseSystem:update(dt) end
function BaseSystem:draw() end

return BaseSystem
```

### Considerations
- Keep ECS lightweight and simple initially
- Plan for efficient component queries
- Consider memory pooling for frequently created/destroyed entities
- Design for easy addition of new component types
- Ensure components are data-only (no methods)

### Tool Suggestions
- Use Write tool to create ECS framework files
- Create example entities to test the system
- Verify component addition/removal works correctly
- Test entity queries and filtering

### Acceptance Criteria
- [ ] Entities can be created and destroyed
- [ ] Components can be added and removed from entities
- [ ] Entity queries by component type work correctly
- [ ] Memory usage is reasonable for large entity counts
- [ ] System framework supports entity processing
- [ ] No memory leaks when entities are destroyed