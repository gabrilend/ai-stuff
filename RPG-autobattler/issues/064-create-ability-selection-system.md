# Issue #508: Create Ability Selection System

## Current Behavior
Template editor allows basic ability editing but lacks a comprehensive ability selection and configuration system.

## Intended Behavior
Create an advanced ability selection interface that provides a library of pre-defined abilities, custom ability creation, and sophisticated configuration options with real-time validation.

## Implementation Details

### Ability Library System (src/data/ability_library.lua)
```lua
-- {{{ AbilityLibrary
local AbilityLibrary = {}
AbilityLibrary.__index = AbilityLibrary

function AbilityLibrary:new()
    local library = {
        abilities = {},
        categories = {},
        search_index = {},
        custom_abilities = {}
    }
    
    library:initialize_default_abilities()
    setmetatable(library, self)
    return library
end
-- }}}

-- {{{ function AbilityLibrary:initialize_default_abilities
function AbilityLibrary:initialize_default_abilities()
    -- Damage Abilities
    self:register_ability({
        id = "basic_strike",
        name = "Basic Strike",
        description = "A simple melee attack that deals moderate damage",
        category = "damage",
        subcategory = "melee",
        effect_type = "damage",
        target_type = "enemy",
        base_config = {
            base_value = 30,
            range = 25,
            max_mana = 100,
            mana_rate = 10,
            cooldown = 0
        },
        customizable_properties = {"base_value", "range", "mana_rate"},
        cost_multipliers = {base_value = 0.04, range = 0.02},
        constraints = {
            base_value = {min = 15, max = 80},
            range = {min = 15, max = 40},
            mana_rate = {min = 5, max = 20}
        },
        tags = {"basic", "reliable", "melee"},
        icon = "⚔",
        color = {0.8, 0.3, 0.3}
    })
    
    self:register_ability({
        id = "power_attack",
        name = "Power Attack",
        description = "High damage attack with longer cooldown",
        category = "damage",
        subcategory = "melee",
        effect_type = "damage",
        target_type = "enemy",
        base_config = {
            base_value = 55,
            range = 25,
            max_mana = 150,
            mana_rate = 6,
            cooldown = 2
        },
        customizable_properties = {"base_value", "cooldown", "mana_rate"},
        cost_multipliers = {base_value = 0.05, cooldown = -2},
        constraints = {
            base_value = {min = 40, max = 100},
            cooldown = {min = 1, max = 5},
            mana_rate = {min = 4, max = 12}
        },
        tags = {"high_damage", "slow", "melee"},
        icon = "💥",
        color = {1.0, 0.2, 0.2}
    })
    
    self:register_ability({
        id = "arrow_shot",
        name = "Arrow Shot",
        description = "Basic ranged attack with good range",
        category = "damage",
        subcategory = "ranged",
        effect_type = "damage",
        target_type = "enemy",
        base_config = {
            base_value = 25,
            range = 80,
            max_mana = 100,
            mana_rate = 10,
            cooldown = 0
        },
        customizable_properties = {"base_value", "range", "mana_rate"},
        cost_multipliers = {base_value = 0.04, range = 0.015},
        constraints = {
            base_value = {min = 15, max = 60},
            range = {min = 50, max = 150},
            mana_rate = {min = 6, max = 15}
        },
        tags = {"basic", "ranged", "reliable"},
        icon = "🏹",
        color = {0.3, 0.8, 0.3}
    })
    
    -- Healing Abilities
    self:register_ability({
        id = "minor_heal",
        name = "Minor Heal",
        description = "Restores moderate health to an ally",
        category = "heal",
        subcategory = "single_target",
        effect_type = "heal",
        target_type = "ally",
        base_config = {
            base_value = 35,
            range = 60,
            max_mana = 120,
            mana_rate = 8,
            cooldown = 0
        },
        customizable_properties = {"base_value", "range", "mana_rate"},
        cost_multipliers = {base_value = 0.03, range = 0.01},
        constraints = {
            base_value = {min = 20, max = 80},
            range = {min = 40, max = 100},
            mana_rate = {min = 5, max = 15}
        },
        tags = {"heal", "support", "reliable"},
        icon = "✚",
        color = {0.2, 0.8, 0.2}
    })
    
    -- Area Effect Abilities
    self:register_ability({
        id = "fireball",
        name = "Fireball",
        description = "Area damage spell that hits multiple enemies",
        category = "damage",
        subcategory = "area_effect",
        effect_type = "damage",
        target_type = "enemy",
        base_config = {
            base_value = 20,
            range = 70,
            area_radius = 20,
            max_mana = 180,
            mana_rate = 5,
            cooldown = 1
        },
        customizable_properties = {"base_value", "area_radius", "range", "cooldown"},
        cost_multipliers = {base_value = 0.06, area_radius = 0.5, range = 0.02},
        constraints = {
            base_value = {min = 12, max = 40},
            area_radius = {min = 15, max = 35},
            range = {min = 50, max = 120},
            cooldown = {min = 0.5, max = 3}
        },
        tags = {"area", "magic", "damage"],
        icon = "🔥",
        color = {1.0, 0.5, 0.0}
    })
    
    -- Buff/Debuff Abilities
    self:register_ability({
        id = "battle_roar",
        name = "Battle Roar",
        description = "Boosts nearby allies' damage output",
        category = "buff",
        subcategory = "area_buff",
        effect_type = "buff",
        target_type = "ally",
        base_config = {
            base_value = 15,
            range = 50,
            area_radius = 40,
            duration = 10,
            max_mana = 200,
            mana_rate = 4,
            cooldown = 5
        },
        customizable_properties = {"base_value", "area_radius", "duration"},
        cost_multipliers = {base_value = 0.8, area_radius = 0.3, duration = 0.5},
        constraints = {
            base_value = {min = 5, max = 30},
            area_radius = {min = 25, max = 60},
            duration = {min = 5, max = 20}
        },
        tags = {"buff", "area", "support"],
        icon = "📢",
        color = {0.8, 0.8, 0.2}
    })
    
    -- Utility Abilities
    self:register_ability({
        id = "shield_wall",
        name = "Shield Wall",
        description = "Temporarily increases armor and blocks projectiles",
        category = "utility",
        subcategory = "defensive",
        effect_type = "buff",
        target_type = "self",
        base_config = {
            base_value = 5, -- armor bonus
            duration = 8,
            max_mana = 160,
            mana_rate = 6,
            cooldown = 3
        },
        customizable_properties = {"base_value", "duration", "cooldown"},
        cost_multipliers = {base_value = 2, duration = 0.8, cooldown = -1.5},
        constraints = {
            base_value = {min = 2, max = 12},
            duration = {min = 4, max = 15},
            cooldown = {min = 2, max = 8}
        },
        tags = {"defense", "utility", "self"],
        icon = "🛡",
        color = {0.6, 0.6, 0.8}
    })
end
-- }}}

-- {{{ function AbilityLibrary:register_ability
function AbilityLibrary:register_ability(ability_data)
    self.abilities[ability_data.id] = ability_data
    
    -- Add to category index
    if not self.categories[ability_data.category] then
        self.categories[ability_data.category] = {}
    end
    table.insert(self.categories[ability_data.category], ability_data.id)
    
    -- Add to search index
    self:index_ability_for_search(ability_data)
end
-- }}}

-- {{{ function AbilityLibrary:index_ability_for_search
function AbilityLibrary:index_ability_for_search(ability_data)
    local search_terms = {
        string.lower(ability_data.name),
        string.lower(ability_data.description),
        string.lower(ability_data.category),
        string.lower(ability_data.subcategory or "")
    }
    
    for _, tag in ipairs(ability_data.tags or {}) do
        table.insert(search_terms, string.lower(tag))
    end
    
    self.search_index[ability_data.id] = search_terms
end
-- }}}

-- {{{ function AbilityLibrary:search_abilities
function AbilityLibrary:search_abilities(query, filters)
    local results = {}
    query = string.lower(query or "")
    
    for ability_id, search_terms in pairs(self.search_index) do
        local ability = self.abilities[ability_id]
        local matches = false
        
        -- Text search
        if query == "" then
            matches = true
        else
            for _, term in ipairs(search_terms) do
                if string.find(term, query, 1, true) then
                    matches = true
                    break
                end
            end
        end
        
        -- Apply filters
        if matches and filters then
            if filters.category and ability.category ~= filters.category then
                matches = false
            end
            
            if filters.effect_type and ability.effect_type ~= filters.effect_type then
                matches = false
            end
            
            if filters.target_type and ability.target_type ~= filters.target_type then
                matches = false
            end
            
            if filters.tags then
                local has_required_tag = false
                for _, required_tag in ipairs(filters.tags) do
                    for _, ability_tag in ipairs(ability.tags or {}) do
                        if ability_tag == required_tag then
                            has_required_tag = true
                            break
                        end
                    end
                    if has_required_tag then break end
                end
                if not has_required_tag then
                    matches = false
                end
            end
        end
        
        if matches then
            table.insert(results, ability)
        end
    end
    
    return results
end
-- }}}

-- {{{ function AbilityLibrary:get_ability
function AbilityLibrary:get_ability(ability_id)
    return self.abilities[ability_id]
end
-- }}}

-- {{{ function AbilityLibrary:get_categories
function AbilityLibrary:get_categories()
    local category_list = {}
    for category, _ in pairs(self.categories) do
        table.insert(category_list, category)
    end
    table.sort(category_list)
    return category_list
end
-- }}}

-- {{{ function AbilityLibrary:create_ability_instance
function AbilityLibrary:create_ability_instance(ability_id, customizations)
    local ability_template = self.abilities[ability_id]
    if not ability_template then return nil end
    
    local instance = {
        template_id = ability_id,
        name = ability_template.name,
        description = ability_template.description,
        effect_type = ability_template.effect_type,
        target_type = ability_template.target_type,
        category = ability_template.category,
        icon = ability_template.icon,
        color = ability_template.color
    }
    
    -- Apply base configuration
    for property, value in pairs(ability_template.base_config) do
        instance[property] = value
    end
    
    -- Apply customizations
    if customizations then
        for property, value in pairs(customizations) do
            if self:is_property_customizable(ability_template, property) then
                local constraints = ability_template.constraints[property]
                if constraints then
                    value = math.max(constraints.min, math.min(constraints.max, value))
                end
                instance[property] = value
            end
        end
    end
    
    return instance
end
-- }}}

-- {{{ function AbilityLibrary:is_property_customizable
function AbilityLibrary:is_property_customizable(ability_template, property)
    for _, customizable_prop in ipairs(ability_template.customizable_properties or {}) do
        if customizable_prop == property then
            return true
        end
    end
    return false
end
-- }}}

return AbilityLibrary
```

### Ability Selection UI (src/ui/components/ability_selector.lua)
```lua
-- {{{ AbilitySelector
local AbilitySelector = {}
AbilitySelector.__index = AbilitySelector

function AbilitySelector:new(template_editor)
    local selector = {
        template_editor = template_editor,
        ability_library = require("src.data.ability_library"):new(),
        
        -- UI State
        current_slot = 1,
        selected_ability_template = nil,
        search_query = "",
        selected_category = "all",
        selected_filters = {},
        
        -- UI Components
        ability_list = {},
        search_results = {},
        customization_panel = nil,
        
        -- Layout
        library_panel = {x = 20, y = 100, width = 300, height = 500},
        details_panel = {x = 340, y = 100, width = 280, height = 500},
        customization_panel_bounds = {x = 640, y = 100, width = 200, height = 500}
    }
    
    selector:refresh_ability_list()
    setmetatable(selector, self)
    return selector
end
-- }}}

-- {{{ function AbilitySelector:refresh_ability_list
function AbilitySelector:refresh_ability_list()
    local filters = {
        category = self.selected_category ~= "all" and self.selected_category or nil,
        tags = #self.selected_filters > 0 and self.selected_filters or nil
    }
    
    self.search_results = self.ability_library:search_abilities(self.search_query, filters)
    
    -- Sort results by category and name
    table.sort(self.search_results, function(a, b)
        if a.category ~= b.category then
            return a.category < b.category
        end
        return a.name < b.name
    end)
end
-- }}}

-- {{{ function AbilitySelector:set_current_slot
function AbilitySelector:set_current_slot(slot_index)
    self.current_slot = slot_index
    
    -- Load existing ability from template if it exists
    if self.template_editor.current_template and 
       self.template_editor.current_template.abilities[slot_index] then
        local existing_ability = self.template_editor.current_template.abilities[slot_index]
        self:load_ability_for_editing(existing_ability)
    else
        self.selected_ability_template = nil
        self:clear_customization_panel()
    end
end
-- }}}

-- {{{ function AbilitySelector:load_ability_for_editing
function AbilitySelector:load_ability_for_editing(ability_instance)
    if ability_instance.template_id then
        self.selected_ability_template = self.ability_library:get_ability(ability_instance.template_id)
        self:setup_customization_panel(ability_instance)
    else
        -- Handle custom abilities
        self:setup_custom_ability_panel(ability_instance)
    end
end
-- }}}

-- {{{ function AbilitySelector:select_ability_template
function AbilitySelector:select_ability_template(ability_template)
    self.selected_ability_template = ability_template
    self:setup_customization_panel()
end
-- }}}

-- {{{ function AbilitySelector:setup_customization_panel
function AbilitySelector:setup_customization_panel(existing_instance)
    if not self.selected_ability_template then return end
    
    self.customization_panel = {
        ability_template = self.selected_ability_template,
        current_config = {},
        controls = {},
        cost_display = 0
    }
    
    -- Initialize with base config or existing values
    local source_config = existing_instance or self.selected_ability_template.base_config
    for property, value in pairs(source_config) do
        self.customization_panel.current_config[property] = value
    end
    
    -- Create controls for customizable properties
    self:create_customization_controls()
    self:update_ability_cost()
end
-- }}}

-- {{{ function AbilitySelector:create_customization_controls
function AbilitySelector:create_customization_controls()
    local panel = self.customization_panel
    local y_offset = 40
    
    panel.controls = {}
    
    for _, property in ipairs(panel.ability_template.customizable_properties or {}) do
        local constraints = panel.ability_template.constraints[property]
        if constraints then
            local control = {
                property = property,
                label = self:format_property_name(property),
                bounds = {
                    x = self.customization_panel_bounds.x + 10,
                    y = self.customization_panel_bounds.y + y_offset,
                    width = self.customization_panel_bounds.width - 20,
                    height = 60
                },
                min_value = constraints.min,
                max_value = constraints.max,
                current_value = panel.current_config[property],
                slider = {
                    x = self.customization_panel_bounds.x + 20,
                    y = self.customization_panel_bounds.y + y_offset + 25,
                    width = self.customization_panel_bounds.width - 40,
                    height = 15,
                    dragging = false
                }
            }
            
            panel.controls[property] = control
            y_offset = y_offset + 70
        end
    end
end
-- }}}

-- {{{ function AbilitySelector:format_property_name
function AbilitySelector:format_property_name(property)
    local formatted = string.gsub(property, "_", " ")
    return string.upper(string.sub(formatted, 1, 1)) .. string.sub(formatted, 2)
end
-- }}}

-- {{{ function AbilitySelector:update_ability_property
function AbilitySelector:update_ability_property(property, new_value)
    if not self.customization_panel then return end
    
    local constraints = self.selected_ability_template.constraints[property]
    if constraints then
        new_value = math.max(constraints.min, math.min(constraints.max, new_value))
    end
    
    self.customization_panel.current_config[property] = new_value
    
    if self.customization_panel.controls[property] then
        self.customization_panel.controls[property].current_value = new_value
    end
    
    self:update_ability_cost()
end
-- }}}

-- {{{ function AbilitySelector:update_ability_cost
function AbilitySelector:update_ability_cost()
    if not self.customization_panel then return end
    
    local base_cost = self:calculate_base_ability_cost()
    local customization_cost = self:calculate_customization_cost()
    
    self.customization_panel.cost_display = base_cost + customization_cost
end
-- }}}

-- {{{ function AbilitySelector:calculate_base_ability_cost
function AbilitySelector:calculate_base_ability_cost()
    if not self.selected_ability_template then return 0 end
    
    -- Use the primary ability cost if this is slot 1, otherwise secondary
    local is_primary = self.current_slot == 1
    return is_primary and 10 or 20
end
-- }}}

-- {{{ function AbilitySelector:calculate_customization_cost
function AbilitySelector:calculate_customization_cost()
    if not self.customization_panel then return 0 end
    
    local total_cost = 0
    local template = self.selected_ability_template
    local config = self.customization_panel.current_config
    
    for property, multiplier in pairs(template.cost_multipliers or {}) do
        local base_value = template.base_config[property] or 0
        local current_value = config[property] or base_value
        local difference = current_value - base_value
        
        total_cost = total_cost + (difference * multiplier)
    end
    
    return math.max(0, total_cost)
end
-- }}}

-- {{{ function AbilitySelector:apply_ability_to_slot
function AbilitySelector:apply_ability_to_slot()
    if not self.selected_ability_template or not self.customization_panel then return end
    
    local ability_instance = self.ability_library:create_ability_instance(
        self.selected_ability_template.id,
        self.customization_panel.current_config
    )
    
    if ability_instance then
        self.template_editor:set_ability_for_slot(self.current_slot, ability_instance)
        self:show_application_feedback()
    end
end
-- }}}

-- {{{ function AbilitySelector:clear_ability_slot
function AbilitySelector:clear_ability_slot()
    self.template_editor:set_ability_for_slot(self.current_slot, nil)
    self.selected_ability_template = nil
    self:clear_customization_panel()
end
-- }}}

-- {{{ function AbilitySelector:clear_customization_panel
function AbilitySelector:clear_customization_panel()
    self.customization_panel = nil
end
-- }}}

-- {{{ function AbilitySelector:show_application_feedback
function AbilitySelector:show_application_feedback()
    -- TODO: Implement visual feedback (e.g., brief animation, notification)
    print("Ability applied to slot " .. self.current_slot)
end
-- }}}

-- {{{ function AbilitySelector:handle_mouse_input
function AbilitySelector:handle_mouse_input(x, y, button, pressed)
    if button == 1 and pressed then
        -- Check ability list clicks
        if self:point_in_bounds(x, y, self.library_panel) then
            local selected_ability = self:get_ability_at_position(x, y)
            if selected_ability then
                self:select_ability_template(selected_ability)
                return true
            end
        end
        
        -- Check customization panel interactions
        if self.customization_panel then
            return self:handle_customization_panel_input(x, y)
        end
    end
    
    return false
end
-- }}}

-- {{{ function AbilitySelector:get_ability_at_position
function AbilitySelector:get_ability_at_position(x, y)
    local list_start_y = self.library_panel.y + 60
    local item_height = 40
    local relative_y = y - list_start_y
    
    if relative_y >= 0 then
        local index = math.floor(relative_y / item_height) + 1
        if index <= #self.search_results then
            return self.search_results[index]
        end
    end
    
    return nil
end
-- }}}

-- {{{ function AbilitySelector:handle_customization_panel_input
function AbilitySelector:handle_customization_panel_input(x, y)
    if not self.customization_panel then return false end
    
    for property, control in pairs(self.customization_panel.controls) do
        if self:point_in_bounds(x, y, control.slider) then
            self:update_slider_from_mouse(control, x)
            return true
        end
    end
    
    return false
end
-- }}}

-- {{{ function AbilitySelector:update_slider_from_mouse
function AbilitySelector:update_slider_from_mouse(control, mouse_x)
    local slider = control.slider
    local relative_x = mouse_x - slider.x
    local percentage = math.max(0, math.min(1, relative_x / slider.width))
    
    local value_range = control.max_value - control.min_value
    local new_value = control.min_value + (value_range * percentage)
    
    self:update_ability_property(control.property, new_value)
end
-- }}}

-- {{{ function AbilitySelector:render
function AbilitySelector:render()
    self:render_library_panel()
    self:render_details_panel()
    if self.customization_panel then
        self:render_customization_panel()
    end
end
-- }}}

-- {{{ function AbilitySelector:render_library_panel
function AbilitySelector:render_library_panel()
    local panel = self.library_panel
    
    -- Background
    love.graphics.setColor(0.1, 0.1, 0.1, 0.9)
    love.graphics.rectangle("fill", panel.x, panel.y, panel.width, panel.height)
    
    -- Title
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Ability Library", panel.x + 10, panel.y + 10)
    
    -- Search box (simplified for now)
    love.graphics.setColor(0.2, 0.2, 0.2, 1)
    love.graphics.rectangle("fill", panel.x + 10, panel.y + 30, panel.width - 20, 25)
    love.graphics.setColor(0.7, 0.7, 0.7, 1)
    love.graphics.print("Search: " .. self.search_query, panel.x + 15, panel.y + 35)
    
    -- Ability list
    local list_y = panel.y + 60
    local item_height = 40
    
    for i, ability in ipairs(self.search_results) do
        local item_y = list_y + (i - 1) * item_height
        
        if item_y + item_height > panel.y + panel.height then
            break -- Don't render outside panel
        end
        
        -- Background (highlight if selected)
        local is_selected = self.selected_ability_template and 
                           self.selected_ability_template.id == ability.id
        local bg_color = is_selected and {0.3, 0.3, 0.5, 1} or {0.15, 0.15, 0.15, 1}
        
        love.graphics.setColor(bg_color)
        love.graphics.rectangle("fill", panel.x + 5, item_y, panel.width - 10, item_height - 2)
        
        -- Icon and name
        love.graphics.setColor(ability.color)
        love.graphics.print(ability.icon, panel.x + 10, item_y + 5)
        
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(ability.name, panel.x + 30, item_y + 5)
        
        -- Category
        love.graphics.setColor(0.7, 0.7, 0.7, 1)
        love.graphics.print(ability.category, panel.x + 10, item_y + 20)
    end
    
    -- Border
    love.graphics.setColor(0.4, 0.4, 0.4, 1)
    love.graphics.rectangle("line", panel.x, panel.y, panel.width, panel.height)
end
-- }}}

-- {{{ function AbilitySelector:render_details_panel
function AbilitySelector:render_details_panel()
    local panel = self.details_panel
    
    -- Background
    love.graphics.setColor(0.1, 0.1, 0.1, 0.9)
    love.graphics.rectangle("fill", panel.x, panel.y, panel.width, panel.height)
    
    if self.selected_ability_template then
        local ability = self.selected_ability_template
        local y_offset = 20
        
        -- Name and icon
        love.graphics.setColor(ability.color)
        love.graphics.print(ability.icon .. " " .. ability.name, panel.x + 10, panel.y + y_offset)
        y_offset = y_offset + 30
        
        -- Description
        love.graphics.setColor(0.9, 0.9, 0.9, 1)
        self:render_wrapped_text(ability.description, panel.x + 10, panel.y + y_offset, panel.width - 20)
        y_offset = y_offset + 60
        
        -- Properties
        love.graphics.setColor(0.8, 0.8, 0.8, 1)
        love.graphics.print("Effect: " .. ability.effect_type, panel.x + 10, panel.y + y_offset)
        y_offset = y_offset + 20
        
        love.graphics.print("Target: " .. ability.target_type, panel.x + 10, panel.y + y_offset)
        y_offset = y_offset + 20
        
        -- Base stats
        love.graphics.setColor(0.7, 0.7, 0.9, 1)
        love.graphics.print("Base Configuration:", panel.x + 10, panel.y + y_offset)
        y_offset = y_offset + 25
        
        for property, value in pairs(ability.base_config) do
            love.graphics.setColor(0.6, 0.6, 0.6, 1)
            love.graphics.print(string.format("  %s: %s", 
                self:format_property_name(property), 
                tostring(value)), 
                panel.x + 15, panel.y + y_offset)
            y_offset = y_offset + 18
        end
    else
        love.graphics.setColor(0.6, 0.6, 0.6, 1)
        love.graphics.print("Select an ability to view details", panel.x + 10, panel.y + 20)
    end
    
    -- Border
    love.graphics.setColor(0.4, 0.4, 0.4, 1)
    love.graphics.rectangle("line", panel.x, panel.y, panel.width, panel.height)
end
-- }}}

-- {{{ function AbilitySelector:render_customization_panel
function AbilitySelector:render_customization_panel()
    local panel_bounds = self.customization_panel_bounds
    
    -- Background
    love.graphics.setColor(0.1, 0.1, 0.1, 0.9)
    love.graphics.rectangle("fill", panel_bounds.x, panel_bounds.y, panel_bounds.width, panel_bounds.height)
    
    -- Title
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Customize", panel_bounds.x + 10, panel_bounds.y + 10)
    
    -- Cost display
    love.graphics.setColor(0.8, 0.8, 0.2, 1)
    love.graphics.print(string.format("Cost: %.1f pts", self.customization_panel.cost_display), 
        panel_bounds.x + 10, panel_bounds.y + panel_bounds.height - 60)
    
    -- Render controls
    for property, control in pairs(self.customization_panel.controls) do
        self:render_customization_control(control)
    end
    
    -- Apply/Clear buttons
    love.graphics.setColor(0.2, 0.6, 0.2, 1)
    love.graphics.rectangle("fill", panel_bounds.x + 10, panel_bounds.y + panel_bounds.height - 35, 80, 25)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Apply", panel_bounds.x + 15, panel_bounds.y + panel_bounds.height - 30)
    
    love.graphics.setColor(0.6, 0.2, 0.2, 1)
    love.graphics.rectangle("fill", panel_bounds.x + 100, panel_bounds.y + panel_bounds.height - 35, 80, 25)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Clear", panel_bounds.x + 105, panel_bounds.y + panel_bounds.height - 30)
    
    -- Border
    love.graphics.setColor(0.4, 0.4, 0.4, 1)
    love.graphics.rectangle("line", panel_bounds.x, panel_bounds.y, panel_bounds.width, panel_bounds.height)
end
-- }}}

-- {{{ function AbilitySelector:render_customization_control
function AbilitySelector:render_customization_control(control)
    -- Label
    love.graphics.setColor(0.9, 0.9, 0.9, 1)
    love.graphics.print(control.label, control.bounds.x, control.bounds.y)
    
    -- Value display
    love.graphics.setColor(0.8, 0.8, 0.8, 1)
    love.graphics.print(string.format("%.1f", control.current_value), 
        control.bounds.x + control.bounds.width - 40, control.bounds.y)
    
    -- Slider
    local slider = control.slider
    
    -- Background
    love.graphics.setColor(0.3, 0.3, 0.3, 1)
    love.graphics.rectangle("fill", slider.x, slider.y, slider.width, slider.height)
    
    -- Fill
    local percentage = (control.current_value - control.min_value) / (control.max_value - control.min_value)
    local fill_width = slider.width * percentage
    
    love.graphics.setColor(0.4, 0.6, 0.8, 1)
    love.graphics.rectangle("fill", slider.x, slider.y, fill_width, slider.height)
    
    -- Handle
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", slider.x + fill_width - 2, slider.y - 2, 4, slider.height + 4)
    
    -- Border
    love.graphics.setColor(0.5, 0.5, 0.5, 1)
    love.graphics.rectangle("line", slider.x, slider.y, slider.width, slider.height)
end
-- }}}

-- {{{ function AbilitySelector:render_wrapped_text
function AbilitySelector:render_wrapped_text(text, x, y, max_width)
    local words = {}
    for word in text:gmatch("%S+") do
        table.insert(words, word)
    end
    
    local line = ""
    local line_y = y
    local font = love.graphics.getFont()
    
    for _, word in ipairs(words) do
        local test_line = line == "" and word or line .. " " .. word
        if font:getWidth(test_line) <= max_width then
            line = test_line
        else
            if line ~= "" then
                love.graphics.print(line, x, line_y)
                line_y = line_y + font:getHeight()
            end
            line = word
        end
    end
    
    if line ~= "" then
        love.graphics.print(line, x, line_y)
    end
end
-- }}}

-- {{{ function AbilitySelector:point_in_bounds
function AbilitySelector:point_in_bounds(x, y, bounds)
    return x >= bounds.x and x <= bounds.x + bounds.width and
           y >= bounds.y and y <= bounds.y + bounds.height
end
-- }}}

return AbilitySelector
```

### Acceptance Criteria
- [ ] Comprehensive library of pre-defined abilities covering all major types
- [ ] Search and filtering system to find relevant abilities quickly
- [ ] Detailed ability customization with real-time cost calculation
- [ ] Visual ability preview showing effects and constraints
- [ ] Easy application of abilities to template slots
- [ ] Support for creating custom abilities from scratch
- [ ] Clear feedback on ability costs and point impact