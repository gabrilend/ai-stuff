# Issue #506: Design Template Editor UI

## Current Behavior
No user interface exists for creating or editing unit templates.

## Intended Behavior
Create an intuitive template editor interface that allows players to design custom units, allocate stats, select abilities, and preview their creations in real-time.

## Implementation Details

### Template Editor State Manager (src/states/template_editor_state.lua)
```lua
-- {{{ TemplateEditorState
local TemplateEditorState = {}
TemplateEditorState.__index = TemplateEditorState

function TemplateEditorState:new(game_state_manager)
    local state = {
        game_state_manager = game_state_manager,
        ui_manager = require("src.ui.ui_manager"):new(),
        
        -- Current template being edited
        current_template = nil,
        original_template = nil,
        
        -- UI Components
        stat_editor = nil,
        ability_editor = nil,
        preview_panel = nil,
        point_budget_display = nil,
        
        -- Editor state
        selected_tab = "stats",
        selected_ability_index = 1,
        validation_results = {},
        
        -- Preview
        preview_enabled = true,
        preview_unit = nil
    }
    
    state:initialize_ui()
    setmetatable(state, self)
    return state
end
-- }}}

-- {{{ function TemplateEditorState:initialize_ui
function TemplateEditorState:initialize_ui()
    -- Create main UI layout
    self.ui_manager:create_panel("main_editor", {
        x = 0, y = 0,
        width = love.graphics.getWidth(),
        height = love.graphics.getHeight(),
        background_color = {0.1, 0.1, 0.1, 1.0}
    })
    
    -- Create tab system
    self:create_tab_system()
    
    -- Create stat editor
    self:create_stat_editor()
    
    -- Create ability editor
    self:create_ability_editor()
    
    -- Create preview panel
    self:create_preview_panel()
    
    -- Create point budget display
    self:create_point_budget_display()
    
    -- Create action buttons
    self:create_action_buttons()
end
-- }}}

-- {{{ function TemplateEditorState:create_tab_system
function TemplateEditorState:create_tab_system()
    local tabs = {"stats", "abilities", "appearance", "preview"}
    local tab_width = 120
    local tab_height = 40
    
    for i, tab_name in ipairs(tabs) do
        local x = (i - 1) * tab_width + 20
        
        self.ui_manager:create_button(tab_name .. "_tab", {
            x = x, y = 20,
            width = tab_width, height = tab_height,
            text = string.upper(string.sub(tab_name, 1, 1)) .. string.sub(tab_name, 2),
            font_size = 16,
            on_click = function() self:switch_tab(tab_name) end,
            background_color = tab_name == self.selected_tab and {0.3, 0.3, 0.5, 1.0} or {0.2, 0.2, 0.2, 1.0}
        })
    end
end
-- }}}

-- {{{ function TemplateEditorState:create_stat_editor
function TemplateEditorState:create_stat_editor()
    local panel_x = 20
    local panel_y = 80
    local panel_width = 400
    local panel_height = 500
    
    self.ui_manager:create_panel("stats_panel", {
        x = panel_x, y = panel_y,
        width = panel_width, height = panel_height,
        background_color = {0.15, 0.15, 0.15, 1.0},
        border_color = {0.3, 0.3, 0.3, 1.0},
        visible = true
    })
    
    -- Template name input
    self.ui_manager:create_text_input("template_name", {
        x = panel_x + 20, y = panel_y + 20,
        width = panel_width - 40, height = 30,
        placeholder = "Template Name",
        font_size = 16,
        on_change = function(text) self:update_template_name(text) end
    })
    
    -- Unit type selector
    self.ui_manager:create_dropdown("unit_type", {
        x = panel_x + 20, y = panel_y + 70,
        width = 150, height = 30,
        options = {"melee", "ranged"},
        selected = "melee",
        on_change = function(value) self:update_unit_type(value) end
    })
    
    -- Stat sliders
    local stats = {
        {name = "health", label = "Health", min = 50, max = 300, default = 100},
        {name = "speed", label = "Speed", min = 20, max = 120, default = 50},
        {name = "armor", label = "Armor", min = 0, max = 15, default = 0},
        {name = "detection_range", label = "Detection Range", min = 40, max = 150, default = 60}
    }
    
    for i, stat in ipairs(stats) do
        local y_offset = panel_y + 120 + (i - 1) * 80
        
        -- Stat label
        self.ui_manager:create_label(stat.name .. "_label", {
            x = panel_x + 20, y = y_offset,
            width = 200, height = 20,
            text = stat.label .. ": " .. stat.default,
            font_size = 14
        })
        
        -- Stat slider
        self.ui_manager:create_slider(stat.name .. "_slider", {
            x = panel_x + 20, y = y_offset + 25,
            width = panel_width - 40, height = 20,
            min_value = stat.min,
            max_value = stat.max,
            current_value = stat.default,
            on_change = function(value) self:update_stat(stat.name, value) end
        })
        
        -- Point cost display
        self.ui_manager:create_label(stat.name .. "_cost", {
            x = panel_x + 300, y = y_offset,
            width = 80, height = 20,
            text = "Cost: 0",
            font_size = 12,
            color = {0.7, 0.7, 0.7, 1.0}
        })
    end
end
-- }}}

-- {{{ function TemplateEditorState:create_ability_editor
function TemplateEditorState:create_ability_editor()
    local panel_x = 440
    local panel_y = 80
    local panel_width = 400
    local panel_height = 500
    
    self.ui_manager:create_panel("abilities_panel", {
        x = panel_x, y = panel_y,
        width = panel_width, height = panel_height,
        background_color = {0.15, 0.15, 0.15, 1.0},
        border_color = {0.3, 0.3, 0.3, 1.0},
        visible = false
    })
    
    -- Ability slots (1-4)
    for i = 1, 4 do
        local slot_y = panel_y + 20 + (i - 1) * 110
        
        -- Ability slot button
        self.ui_manager:create_button("ability_slot_" .. i, {
            x = panel_x + 20, y = slot_y,
            width = panel_width - 40, height = 100,
            text = "Empty Ability Slot",
            font_size = 14,
            on_click = function() self:select_ability_slot(i) end,
            background_color = {0.2, 0.2, 0.2, 1.0},
            border_color = {0.4, 0.4, 0.4, 1.0}
        })
    end
    
    -- Ability configuration panel
    self:create_ability_config_panel(panel_x, panel_y + 460)
end
-- }}}

-- {{{ function TemplateEditorState:create_ability_config_panel
function TemplateEditorState:create_ability_config_panel(x, y)
    local config_width = 380
    local config_height = 200
    
    self.ui_manager:create_panel("ability_config", {
        x = x + 10, y = y,
        width = config_width, height = config_height,
        background_color = {0.12, 0.12, 0.12, 1.0},
        border_color = {0.25, 0.25, 0.25, 1.0},
        visible = false
    })
    
    -- Ability name input
    self.ui_manager:create_text_input("ability_name", {
        x = x + 20, y = y + 20,
        width = 180, height = 25,
        placeholder = "Ability Name",
        font_size = 12
    })
    
    -- Effect type dropdown
    self.ui_manager:create_dropdown("ability_effect_type", {
        x = x + 210, y = y + 20,
        width = 100, height = 25,
        options = {"damage", "heal", "buff", "debuff"},
        selected = "damage"
    })
    
    -- Target type dropdown
    self.ui_manager:create_dropdown("ability_target_type", {
        x = x + 320, y = y + 20,
        width = 80, height = 25,
        options = {"enemy", "ally", "self"},
        selected = "enemy"
    })
    
    -- Value slider
    self.ui_manager:create_label("ability_value_label", {
        x = x + 20, y = y + 55,
        width = 100, height = 20,
        text = "Base Value: 25",
        font_size = 12
    })
    
    self.ui_manager:create_slider("ability_value_slider", {
        x = x + 20, y = y + 75,
        width = 200, height = 15,
        min_value = 1,
        max_value = 100,
        current_value = 25
    })
    
    -- Range slider
    self.ui_manager:create_label("ability_range_label", {
        x = x + 240, y = y + 55,
        width = 100, height = 20,
        text = "Range: 50",
        font_size = 12
    })
    
    self.ui_manager:create_slider("ability_range_slider", {
        x = x + 240, y = y + 75,
        width = 120, height = 15,
        min_value = 10,
        max_value = 150,
        current_value = 50
    })
    
    -- Action buttons
    self.ui_manager:create_button("save_ability", {
        x = x + 20, y = y + 110,
        width = 80, height = 30,
        text = "Save",
        font_size = 12,
        on_click = function() self:save_current_ability() end
    })
    
    self.ui_manager:create_button("clear_ability", {
        x = x + 110, y = y + 110,
        width = 80, height = 30,
        text = "Clear",
        font_size = 12,
        on_click = function() self:clear_current_ability() end
    })
end
-- }}}

-- {{{ function TemplateEditorState:create_preview_panel
function TemplateEditorState:create_preview_panel()
    local panel_x = 860
    local panel_y = 80
    local panel_width = 300
    local panel_height = 500
    
    self.ui_manager:create_panel("preview_panel", {
        x = panel_x, y = panel_y,
        width = panel_width, height = panel_height,
        background_color = {0.1, 0.1, 0.1, 1.0},
        border_color = {0.3, 0.3, 0.3, 1.0}
    })
    
    -- Preview title
    self.ui_manager:create_label("preview_title", {
        x = panel_x + 10, y = panel_y + 10,
        width = panel_width - 20, height = 30,
        text = "Unit Preview",
        font_size = 16,
        text_align = "center"
    })
    
    -- Unit render area (handled in render function)
    
    -- Combat stats display
    local stats_y = panel_y + 200
    self.ui_manager:create_label("combat_stats_title", {
        x = panel_x + 10, y = stats_y,
        width = panel_width - 20, height = 20,
        text = "Combat Effectiveness",
        font_size = 14,
        text_align = "center"
    })
    
    local combat_stats = {"DPS", "Survivability", "Utility", "Mobility"}
    for i, stat in ipairs(combat_stats) do
        local stat_y = stats_y + 30 + (i - 1) * 25
        
        self.ui_manager:create_label("combat_" .. string.lower(stat), {
            x = panel_x + 20, y = stat_y,
            width = 100, height = 20,
            text = stat .. ": 0",
            font_size = 12
        })
        
        self.ui_manager:create_progress_bar("combat_" .. string.lower(stat) .. "_bar", {
            x = panel_x + 130, y = stat_y + 5,
            width = 150, height = 10,
            current_value = 0,
            max_value = 100,
            color = {0.3, 0.7, 0.3, 1.0}
        })
    end
end
-- }}}

-- {{{ function TemplateEditorState:create_point_budget_display
function TemplateEditorState:create_point_budget_display()
    local display_x = 20
    local display_y = 600
    local display_width = 400
    local display_height = 60
    
    self.ui_manager:create_panel("budget_panel", {
        x = display_x, y = display_y,
        width = display_width, height = display_height,
        background_color = {0.15, 0.15, 0.2, 1.0},
        border_color = {0.4, 0.4, 0.5, 1.0}
    })
    
    -- Points used display
    self.ui_manager:create_label("points_used", {
        x = display_x + 20, y = display_y + 10,
        width = 200, height = 20,
        text = "Points Used: 0 / 100",
        font_size = 16
    })
    
    -- Points remaining bar
    self.ui_manager:create_progress_bar("points_bar", {
        x = display_x + 20, y = display_y + 35,
        width = display_width - 40, height = 15,
        current_value = 0,
        max_value = 100,
        color = {0.2, 0.6, 0.2, 1.0},
        background_color = {0.3, 0.1, 0.1, 1.0}
    })
end
-- }}}

-- {{{ function TemplateEditorState:create_action_buttons
function TemplateEditorState:create_action_buttons()
    local button_y = 600
    local button_width = 100
    local button_height = 40
    
    -- Save template button
    self.ui_manager:create_button("save_template", {
        x = 500, y = button_y,
        width = button_width, height = button_height,
        text = "Save",
        font_size = 16,
        on_click = function() self:save_template() end,
        background_color = {0.2, 0.6, 0.2, 1.0}
    })
    
    -- Load template button
    self.ui_manager:create_button("load_template", {
        x = 610, y = button_y,
        width = button_width, height = button_height,
        text = "Load",
        font_size = 16,
        on_click = function() self:show_load_dialog() end,
        background_color = {0.2, 0.2, 0.6, 1.0}
    })
    
    -- Reset template button
    self.ui_manager:create_button("reset_template", {
        x = 720, y = button_y,
        width = button_width, height = button_height,
        text = "Reset",
        font_size = 16,
        on_click = function() self:reset_template() end,
        background_color = {0.6, 0.2, 0.2, 1.0}
    })
    
    -- Exit editor button
    self.ui_manager:create_button("exit_editor", {
        x = 830, y = button_y,
        width = button_width, height = button_height,
        text = "Exit",
        font_size = 16,
        on_click = function() self:exit_editor() end,
        background_color = {0.4, 0.4, 0.4, 1.0}
    })
end
-- }}}

-- {{{ function TemplateEditorState:switch_tab
function TemplateEditorState:switch_tab(tab_name)
    -- Hide all panels
    self.ui_manager:set_element_visible("stats_panel", false)
    self.ui_manager:set_element_visible("abilities_panel", false)
    self.ui_manager:set_element_visible("appearance_panel", false)
    
    -- Update tab buttons
    local tabs = {"stats", "abilities", "appearance", "preview"}
    for _, tab in ipairs(tabs) do
        local is_selected = tab == tab_name
        self.ui_manager:set_element_property(tab .. "_tab", "background_color", 
            is_selected and {0.3, 0.3, 0.5, 1.0} or {0.2, 0.2, 0.2, 1.0})
    end
    
    -- Show selected panel
    if tab_name == "stats" then
        self.ui_manager:set_element_visible("stats_panel", true)
    elseif tab_name == "abilities" then
        self.ui_manager:set_element_visible("abilities_panel", true)
    elseif tab_name == "appearance" then
        self.ui_manager:set_element_visible("appearance_panel", true)
    end
    
    self.selected_tab = tab_name
end
-- }}}

-- {{{ function TemplateEditorState:update
function TemplateEditorState:update(dt)
    self.ui_manager:update(dt)
    
    if self.current_template then
        self:update_point_budget_display()
        self:update_preview()
        self:validate_template()
    end
end
-- }}}

-- {{{ function TemplateEditorState:render
function TemplateEditorState:render()
    self.ui_manager:render()
    
    if self.selected_tab == "preview" and self.current_template then
        self:render_unit_preview()
    end
    
    self:render_validation_feedback()
end
-- }}}

-- {{{ function TemplateEditorState:render_unit_preview
function TemplateEditorState:render_unit_preview()
    local preview_x = 860 + 150  -- Center of preview panel
    local preview_y = 80 + 120   -- Center of preview area
    
    if self.current_template and self.current_template.appearance then
        local appearance = self.current_template.appearance
        local size = 20 * (appearance.size_modifier or 1.0)
        
        -- Set color
        love.graphics.setColor(appearance.primary_color)
        
        -- Draw shape based on type
        if appearance.shape == "circle" then
            love.graphics.circle("fill", preview_x, preview_y, size)
        elseif appearance.shape == "square" then
            love.graphics.rectangle("fill", preview_x - size, preview_y - size, size * 2, size * 2)
        elseif appearance.shape == "triangle" then
            love.graphics.polygon("fill", 
                preview_x, preview_y - size,
                preview_x - size, preview_y + size,
                preview_x + size, preview_y + size)
        end
        
        -- Draw border
        love.graphics.setColor(appearance.secondary_color)
        love.graphics.setLineWidth(2)
        
        if appearance.shape == "circle" then
            love.graphics.circle("line", preview_x, preview_y, size)
        elseif appearance.shape == "square" then
            love.graphics.rectangle("line", preview_x - size, preview_y - size, size * 2, size * 2)
        elseif appearance.shape == "triangle" then
            love.graphics.polygon("line", 
                preview_x, preview_y - size,
                preview_x - size, preview_y + size,
                preview_x + size, preview_y + size)
        end
    end
    
    love.graphics.setColor(1, 1, 1, 1) -- Reset color
end
-- }}}

return TemplateEditorState
```

### UI Manager Extension (src/ui/template_editor_ui.lua)
```lua
-- {{{ TemplateEditorUI
local TemplateEditorUI = {}
TemplateEditorUI.__index = TemplateEditorUI

function TemplateEditorUI:new()
    local ui = {
        elements = {},
        active_element = nil,
        hover_element = nil,
        tooltip_text = "",
        tooltip_timer = 0
    }
    setmetatable(ui, self)
    return ui
end
-- }}}

-- {{{ function TemplateEditorUI:create_slider
function TemplateEditorUI:create_slider(id, config)
    self.elements[id] = {
        type = "slider",
        x = config.x,
        y = config.y,
        width = config.width,
        height = config.height,
        min_value = config.min_value,
        max_value = config.max_value,
        current_value = config.current_value,
        on_change = config.on_change,
        dragging = false,
        visible = config.visible ~= false
    }
end
-- }}}

-- {{{ function TemplateEditorUI:create_dropdown
function TemplateEditorUI:create_dropdown(id, config)
    self.elements[id] = {
        type = "dropdown",
        x = config.x,
        y = config.y,
        width = config.width,
        height = config.height,
        options = config.options,
        selected = config.selected,
        selected_index = 1,
        expanded = false,
        on_change = config.on_change,
        visible = config.visible ~= false
    }
    
    -- Find selected index
    for i, option in ipairs(config.options) do
        if option == config.selected then
            self.elements[id].selected_index = i
            break
        end
    end
end
-- }}}

-- {{{ function TemplateEditorUI:create_progress_bar
function TemplateEditorUI:create_progress_bar(id, config)
    self.elements[id] = {
        type = "progress_bar",
        x = config.x,
        y = config.y,
        width = config.width,
        height = config.height,
        current_value = config.current_value,
        max_value = config.max_value,
        color = config.color or {0.2, 0.6, 0.2, 1.0},
        background_color = config.background_color or {0.2, 0.2, 0.2, 1.0},
        visible = config.visible ~= false
    }
end
-- }}}

-- {{{ function TemplateEditorUI:handle_mouse_input
function TemplateEditorUI:handle_mouse_input(x, y, button, pressed)
    for id, element in pairs(self.elements) do
        if element.visible and self:point_in_element(x, y, element) then
            if element.type == "slider" and button == 1 then
                if pressed then
                    element.dragging = true
                    self:update_slider_value(element, x)
                else
                    element.dragging = false
                end
                return true
            elseif element.type == "dropdown" and button == 1 and pressed then
                element.expanded = not element.expanded
                return true
            elseif element.type == "button" and button == 1 and pressed then
                if element.on_click then
                    element.on_click()
                end
                return true
            end
        end
    end
    
    return false
end
-- }}}

-- {{{ function TemplateEditorUI:update_slider_value
function TemplateEditorUI:update_slider_value(slider, mouse_x)
    local relative_x = mouse_x - slider.x
    local percentage = math.max(0, math.min(1, relative_x / slider.width))
    local new_value = slider.min_value + (slider.max_value - slider.min_value) * percentage
    
    if new_value ~= slider.current_value then
        slider.current_value = new_value
        if slider.on_change then
            slider.on_change(new_value)
        end
    end
end
-- }}}

-- {{{ function TemplateEditorUI:render_slider
function TemplateEditorUI:render_slider(slider)
    -- Background
    love.graphics.setColor(0.3, 0.3, 0.3, 1.0)
    love.graphics.rectangle("fill", slider.x, slider.y, slider.width, slider.height)
    
    -- Fill
    local fill_percentage = (slider.current_value - slider.min_value) / (slider.max_value - slider.min_value)
    local fill_width = slider.width * fill_percentage
    
    love.graphics.setColor(0.4, 0.6, 0.8, 1.0)
    love.graphics.rectangle("fill", slider.x, slider.y, fill_width, slider.height)
    
    -- Handle
    local handle_x = slider.x + fill_width - 5
    love.graphics.setColor(0.8, 0.8, 0.8, 1.0)
    love.graphics.rectangle("fill", handle_x, slider.y - 2, 10, slider.height + 4)
    
    -- Border
    love.graphics.setColor(0.6, 0.6, 0.6, 1.0)
    love.graphics.rectangle("line", slider.x, slider.y, slider.width, slider.height)
end
-- }}}

-- {{{ function TemplateEditorUI:render_dropdown
function TemplateEditorUI:render_dropdown(dropdown)
    -- Main box
    love.graphics.setColor(0.25, 0.25, 0.25, 1.0)
    love.graphics.rectangle("fill", dropdown.x, dropdown.y, dropdown.width, dropdown.height)
    
    -- Selected text
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(dropdown.options[dropdown.selected_index], dropdown.x + 5, dropdown.y + 5)
    
    -- Arrow
    love.graphics.setColor(0.7, 0.7, 0.7, 1.0)
    local arrow_x = dropdown.x + dropdown.width - 15
    local arrow_y = dropdown.y + dropdown.height / 2
    if dropdown.expanded then
        love.graphics.polygon("fill", arrow_x, arrow_y - 3, arrow_x + 6, arrow_y + 3, arrow_x - 6, arrow_y + 3)
    else
        love.graphics.polygon("fill", arrow_x, arrow_y + 3, arrow_x + 6, arrow_y - 3, arrow_x - 6, arrow_y - 3)
    end
    
    -- Border
    love.graphics.setColor(0.6, 0.6, 0.6, 1.0)
    love.graphics.rectangle("line", dropdown.x, dropdown.y, dropdown.width, dropdown.height)
    
    -- Expanded options
    if dropdown.expanded then
        local option_height = 25
        for i, option in ipairs(dropdown.options) do
            local option_y = dropdown.y + dropdown.height + (i - 1) * option_height
            
            love.graphics.setColor(0.2, 0.2, 0.2, 1.0)
            love.graphics.rectangle("fill", dropdown.x, option_y, dropdown.width, option_height)
            
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.print(option, dropdown.x + 5, option_y + 5)
            
            love.graphics.setColor(0.5, 0.5, 0.5, 1.0)
            love.graphics.rectangle("line", dropdown.x, option_y, dropdown.width, option_height)
        end
    end
end
-- }}}

-- {{{ function TemplateEditorUI:render_progress_bar
function TemplateEditorUI:render_progress_bar(bar)
    -- Background
    love.graphics.setColor(bar.background_color)
    love.graphics.rectangle("fill", bar.x, bar.y, bar.width, bar.height)
    
    -- Fill
    local fill_percentage = bar.current_value / bar.max_value
    local fill_width = bar.width * fill_percentage
    
    love.graphics.setColor(bar.color)
    love.graphics.rectangle("fill", bar.x, bar.y, fill_width, bar.height)
    
    -- Border
    love.graphics.setColor(0.6, 0.6, 0.6, 1.0)
    love.graphics.rectangle("line", bar.x, bar.y, bar.width, bar.height)
end
-- }}}

return TemplateEditorUI
```

### Acceptance Criteria
- [ ] Intuitive tabbed interface for different editing aspects
- [ ] Real-time point budget tracking and validation
- [ ] Visual stat sliders with immediate feedback
- [ ] Comprehensive ability editor with all options
- [ ] Live unit preview showing appearance and stats
- [ ] Save/load functionality integrated with template storage
- [ ] Responsive UI that works well at different screen sizes
- [ ] Clear visual feedback for validation errors and warnings