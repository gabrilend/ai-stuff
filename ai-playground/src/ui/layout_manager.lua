-- {{{ Layout Manager
-- Flexible UI layout system with draggable panels and customizable slots

local LayoutManager = {}
LayoutManager.__index = LayoutManager

-- {{{ LayoutManager constructor
function LayoutManager:new(window_width, window_height)
    local obj = {
        window_width = window_width or 1200,
        window_height = window_height or 800,
        
        -- Panel definitions
        panels = {},
        panel_slots = {},
        active_panels = {},
        
        -- Dragging state
        dragging_panel = nil,
        drag_offset_x = 0,
        drag_offset_y = 0,
        
        -- Snap zones
        snap_distance = 20,
        slot_zones = {},
        
        -- Visual settings
        colors = {
            panel_border = {0.4, 0.4, 0.5},
            panel_header = {0.3, 0.3, 0.4},
            panel_background = {0.15, 0.15, 0.2, 0.9},
            drag_highlight = {1, 1, 0, 0.5},
            slot_zone = {0.2, 0.6, 0.8, 0.3},
            snap_zone = {0.3, 0.8, 0.3, 0.6}
        },
        
        -- Default layout configuration
        default_layout = {
            network_view = {x = 50, y = 120, width = 600, height = 400, slot = "main"},
            gradient_view = {x = 50, y = 540, width = 600, height = 180, slot = "bottom"},
            tree_view = {x = 670, y = 120, width = 400, height = 400, slot = "right"},
            info_panel = {x = 670, y = 540, width = 400, height = 180, slot = "bottom-right"},
            chat_log = {x = 1090, y = 120, width = 300, height = 500, slot = "far-right"}
        }
    }
    
    setmetatable(obj, self)
    self:initialize_default_slots()
    return obj
end
-- }}}

-- {{{ Slot management
function LayoutManager:initialize_default_slots()
    -- Define predefined slot zones that panels can snap to
    local w, h = self.window_width or 1200, self.window_height or 800
    
    self.slot_zones = {
        main = {x = 50, y = 120, width = w * 0.4, height = h * 0.5},
        right = {x = w * 0.5, y = 120, width = w * 0.3, height = h * 0.5},
        bottom = {x = 50, y = h * 0.65, width = w * 0.4, height = h * 0.25},
        ["bottom-right"] = {x = w * 0.5, y = h * 0.65, width = w * 0.3, height = h * 0.25},
        ["far-right"] = {x = w * 0.82, y = 120, width = w * 0.16, height = h * 0.7},
        ["top-bar"] = {x = 50, y = 50, width = w - 100, height = 60},
        floating = {x = w * 0.1, y = h * 0.1, width = w * 0.2, height = h * 0.2}
    }
end

function LayoutManager:add_custom_slot(name, x, y, width, height)
    self.slot_zones[name] = {x = x, y = y, width = width, height = height}
end

function LayoutManager:get_slot_at_position(x, y)
    for slot_name, zone in pairs(self.slot_zones) do
        if x >= zone.x and x <= zone.x + zone.width and
           y >= zone.y and y <= zone.y + zone.height then
            return slot_name, zone
        end
    end
    return nil, nil
end
-- }}}

-- {{{ Panel management
function LayoutManager:register_panel(name, panel_config)
    self.panels[name] = {
        name = name,
        title = panel_config.title or name,
        x = panel_config.x or 0,
        y = panel_config.y or 0,
        width = panel_config.width or 300,
        height = panel_config.height or 200,
        min_width = panel_config.min_width or 200,
        min_height = panel_config.min_height or 150,
        resizable = panel_config.resizable ~= false,
        visible = panel_config.visible ~= false,
        slot = panel_config.slot or "floating",
        render_func = panel_config.render_func,
        update_func = panel_config.update_func,
        
        -- State
        is_dragging = false,
        is_resizing = false,
        z_order = panel_config.z_order or 1
    }
    
    -- Set panel to slot position if specified
    if panel_config.slot and self.slot_zones[panel_config.slot] then
        local zone = self.slot_zones[panel_config.slot]
        self.panels[name].x = zone.x
        self.panels[name].y = zone.y
        self.panels[name].width = zone.width
        self.panels[name].height = zone.height
    end
    
    table.insert(self.active_panels, name)
end

function LayoutManager:get_panel(name)
    return self.panels[name]
end

function LayoutManager:set_panel_position(name, x, y)
    if self.panels[name] then
        self.panels[name].x = x
        self.panels[name].y = y
    end
end

function LayoutManager:set_panel_size(name, width, height)
    if self.panels[name] then
        local panel = self.panels[name]
        panel.width = math.max(width, panel.min_width)
        panel.height = math.max(height, panel.min_height)
    end
end

function LayoutManager:toggle_panel_visibility(name)
    if self.panels[name] then
        self.panels[name].visible = not self.panels[name].visible
    end
end

function LayoutManager:snap_panel_to_slot(panel_name, slot_name)
    local panel = self.panels[panel_name]
    local slot = self.slot_zones[slot_name]
    
    if panel and slot then
        panel.x = slot.x
        panel.y = slot.y
        panel.width = slot.width
        panel.height = slot.height
        panel.slot = slot_name
    end
end
-- }}}

-- {{{ Input handling
function LayoutManager:mouse_pressed(x, y, button)
    if button ~= 1 then return false end
    
    -- Check panels in reverse z-order (top to bottom)
    local sorted_panels = {}
    for _, panel_name in ipairs(self.active_panels) do
        table.insert(sorted_panels, {name = panel_name, panel = self.panels[panel_name]})
    end
    table.sort(sorted_panels, function(a, b) return a.panel.z_order > b.panel.z_order end)
    
    for _, panel_info in ipairs(sorted_panels) do
        local name = panel_info.name
        local panel = panel_info.panel
        
        if panel.visible and self:is_point_in_panel(x, y, panel) then
            -- Check if clicking on header (for dragging)
            if y <= panel.y + 25 then  -- Header area
                self:start_dragging(name, x, y)
                return true
            end
            
            -- Bring panel to front
            self:bring_to_front(name)
            return true
        end
    end
    
    return false
end

function LayoutManager:mouse_moved(x, y)
    if self.dragging_panel then
        local panel = self.panels[self.dragging_panel]
        local new_x = x - self.drag_offset_x
        local new_y = y - self.drag_offset_y
        
        -- Check for snap zones
        local snap_slot, snap_zone = self:get_slot_at_position(x, y)
        if snap_slot and snap_zone then
            -- Snap to zone
            panel.x = snap_zone.x
            panel.y = snap_zone.y
            panel.width = snap_zone.width
            panel.height = snap_zone.height
            panel.slot = snap_slot
        else
            -- Free positioning
            panel.x = new_x
            panel.y = new_y
            panel.slot = "floating"
        end
    end
end

function LayoutManager:mouse_released(x, y, button)
    if button == 1 and self.dragging_panel then
        self:stop_dragging()
        return true
    end
    return false
end

function LayoutManager:start_dragging(panel_name, x, y)
    local panel = self.panels[panel_name]
    if panel then
        self.dragging_panel = panel_name
        self.drag_offset_x = x - panel.x
        self.drag_offset_y = y - panel.y
        panel.is_dragging = true
        self:bring_to_front(panel_name)
    end
end

function LayoutManager:stop_dragging()
    if self.dragging_panel then
        self.panels[self.dragging_panel].is_dragging = false
        self.dragging_panel = nil
        self.drag_offset_x = 0
        self.drag_offset_y = 0
    end
end

function LayoutManager:is_point_in_panel(x, y, panel)
    return x >= panel.x and x <= panel.x + panel.width and
           y >= panel.y and y <= panel.y + panel.height
end

function LayoutManager:bring_to_front(panel_name)
    local max_z = 0
    for _, panel in pairs(self.panels) do
        if panel.z_order > max_z then
            max_z = panel.z_order
        end
    end
    self.panels[panel_name].z_order = max_z + 1
end
-- }}}

-- {{{ Rendering
function LayoutManager:update(dt)
    -- Update all panels
    for _, panel_name in ipairs(self.active_panels) do
        local panel = self.panels[panel_name]
        if panel.visible and panel.update_func then
            panel.update_func(dt, panel)
        end
    end
end

function LayoutManager:draw()
    -- Draw slot zones if dragging
    if self.dragging_panel then
        self:draw_slot_zones()
    end
    
    -- Draw panels in z-order
    local sorted_panels = {}
    for _, panel_name in ipairs(self.active_panels) do
        table.insert(sorted_panels, {name = panel_name, panel = self.panels[panel_name]})
    end
    table.sort(sorted_panels, function(a, b) return a.panel.z_order < b.panel.z_order end)
    
    for _, panel_info in ipairs(sorted_panels) do
        local name = panel_info.name
        local panel = panel_info.panel
        
        if panel.visible then
            self:draw_panel(name, panel)
        end
    end
end

function LayoutManager:draw_panel(name, panel)
    -- Draw panel background
    love.graphics.setColor(self.colors.panel_background)
    love.graphics.rectangle("fill", panel.x, panel.y, panel.width, panel.height)
    
    -- Draw panel border (highlight if dragging)
    local border_color = panel.is_dragging and self.colors.drag_highlight or self.colors.panel_border
    love.graphics.setColor(border_color)
    love.graphics.setLineWidth(panel.is_dragging and 3 or 1)
    love.graphics.rectangle("line", panel.x, panel.y, panel.width, panel.height)
    love.graphics.setLineWidth(1)
    
    -- Draw header
    love.graphics.setColor(self.colors.panel_header)
    love.graphics.rectangle("fill", panel.x, panel.y, panel.width, 25)
    
    -- Draw title
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(panel.title, panel.x + 5, panel.y + 5)
    
    -- Draw slot indicator
    if panel.slot and panel.slot ~= "floating" then
        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.print("[" .. panel.slot .. "]", panel.x + panel.width - 80, panel.y + 5)
    end
    
    -- Draw panel content
    if panel.render_func then
        -- Set clip to panel content area
        love.graphics.push()
        love.graphics.intersectScissor(panel.x, panel.y + 25, panel.width, panel.height - 25)
        
        panel.render_func(panel.x, panel.y + 25, panel.width, panel.height - 25, panel)
        
        love.graphics.pop()
    end
end

function LayoutManager:draw_slot_zones()
    love.graphics.setColor(self.colors.slot_zone)
    for slot_name, zone in pairs(self.slot_zones) do
        love.graphics.rectangle("line", zone.x, zone.y, zone.width, zone.height)
        
        -- Draw slot label
        love.graphics.setColor(1, 1, 1, 0.7)
        love.graphics.print(slot_name, zone.x + 5, zone.y + 5)
    end
end
-- }}}

-- {{{ Layout presets and saving
function LayoutManager:save_layout()
    local layout = {}
    for name, panel in pairs(self.panels) do
        layout[name] = {
            x = panel.x,
            y = panel.y,
            width = panel.width,
            height = panel.height,
            slot = panel.slot,
            visible = panel.visible
        }
    end
    return layout
end

function LayoutManager:load_layout(layout)
    for name, config in pairs(layout) do
        if self.panels[name] then
            local panel = self.panels[name]
            panel.x = config.x
            panel.y = config.y
            panel.width = config.width
            panel.height = config.height
            panel.slot = config.slot
            panel.visible = config.visible
        end
    end
end

function LayoutManager:reset_to_default()
    self:load_layout(self.default_layout)
end
-- }}}

-- {{{ Utility methods
function LayoutManager:resize_window(new_width, new_height)
    local scale_x = new_width / self.window_width
    local scale_y = new_height / self.window_height
    
    -- Scale all panels and slots
    for _, panel in pairs(self.panels) do
        panel.x = panel.x * scale_x
        panel.y = panel.y * scale_y
        panel.width = panel.width * scale_x
        panel.height = panel.height * scale_y
    end
    
    for _, zone in pairs(self.slot_zones) do
        zone.x = zone.x * scale_x
        zone.y = zone.y * scale_y
        zone.width = zone.width * scale_x
        zone.height = zone.height * scale_y
    end
    
    self.window_width = new_width
    self.window_height = new_height
end

function LayoutManager:get_panel_bounds(name)
    local panel = self.panels[name]
    if panel then
        return panel.x, panel.y, panel.width, panel.height
    end
    return 0, 0, 0, 0
end

function LayoutManager:is_panel_visible(name)
    return self.panels[name] and self.panels[name].visible
end

function LayoutManager:get_panels_in_slot(slot_name)
    local panels = {}
    for name, panel in pairs(self.panels) do
        if panel.slot == slot_name then
            table.insert(panels, name)
        end
    end
    return panels
end
-- }}}

return LayoutManager
-- }}}