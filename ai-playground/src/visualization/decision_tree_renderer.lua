-- {{{ Decision Tree Renderer
-- Visualizes decision pathways and computation tree structure

local DecisionTreeRenderer = {}
DecisionTreeRenderer.__index = DecisionTreeRenderer

-- {{{ DecisionTreeRenderer constructor
function DecisionTreeRenderer:new(x, y, width, height)
    local obj = {
        x = x or 700,
        y = y or 120,
        width = width or 400,
        height = height or 600,
        
        -- Visual settings
        node_radius = 12,
        layer_spacing = 80,
        node_spacing = 40,
        connection_width = 2,
        
        -- Colors
        colors = {
            input_node = {0.2, 0.7, 0.3},      -- Green
            weight_node = {0.8, 0.6, 0.2},     -- Orange
            bias_node = {0.6, 0.3, 0.8},       -- Purple
            multiply_node = {0.3, 0.5, 0.8},   -- Blue
            add_node = {0.5, 0.8, 0.3},        -- Light green
            activation_node = {0.8, 0.3, 0.5}, -- Pink
            loss_node = {0.9, 0.2, 0.2},       -- Red
            
            connection = {0.5, 0.5, 0.5, 0.7},
            strong_gradient = {1.0, 1.0, 0.3, 0.9},      -- Bright yellow
            medium_gradient = {0.8, 0.8, 0.5, 0.7},      -- Yellow
            weak_gradient = {0.6, 0.6, 0.6, 0.5},        -- Gray
            
            background = {0.12, 0.12, 0.18},
            border = {0.4, 0.4, 0.5},
            text = {0.9, 0.9, 0.9},
            selected_highlight = {1, 1, 0},    -- Yellow
            path_highlight = {0, 1, 0}         -- Green
        },
        
        -- Tree structure
        decision_tree = {},
        node_positions = {},
        gradient_contributions = {},
        
        -- Interaction and animation
        selected_node = nil,
        highlighted_path = {},
        show_contributions = true,
        animation_time = 0,
        
        -- Layout parameters
        auto_layout = true,
        compact_mode = false
    }
    
    setmetatable(obj, self)
    return obj
end
-- }}}

-- {{{ Data management
function DecisionTreeRenderer:set_decision_tree(tree)
    self.decision_tree = tree
    self:calculate_layout()
end

function DecisionTreeRenderer:set_gradient_contributions(contributions)
    self.gradient_contributions = contributions
end

function DecisionTreeRenderer:calculate_layout()
    if not self.decision_tree.layers then
        return
    end
    
    self.node_positions = {}
    local layers = self.decision_tree.layers
    local max_depth = self.decision_tree.max_depth
    
    if max_depth == 0 then
        return
    end
    
    -- Calculate spacing
    local available_width = self.width - 2 * self.node_radius
    local available_height = self.height - 2 * self.node_radius
    
    local layer_spacing = available_width / math.max(1, max_depth - 1)
    
    for layer_depth = 1, max_depth do
        local layer_nodes = layers[layer_depth]
        if layer_nodes and #layer_nodes > 0 then
            
            -- Group nodes by type for better layout
            local grouped_nodes = self:group_nodes_by_type(layer_nodes)
            
            local total_groups = 0
            for _, group in pairs(grouped_nodes) do
                if #group > 0 then
                    total_groups = total_groups + 1
                end
            end
            
            local group_spacing = available_height / math.max(1, total_groups)
            local group_index = 0
            
            for node_type, group_nodes in pairs(grouped_nodes) do
                if #group_nodes > 0 then
                    local node_spacing_in_group = group_spacing / math.max(1, #group_nodes)
                    
                    for i, node in ipairs(group_nodes) do
                        local x = self.x + self.node_radius + (layer_depth - 1) * layer_spacing
                        local y = self.y + self.node_radius + 
                                 group_index * group_spacing + 
                                 (i - 1) * node_spacing_in_group
                        
                        self.node_positions[node.id] = {
                            x = x,
                            y = y,
                            node = node,
                            layer = layer_depth,
                            group_type = node_type
                        }
                    end
                    
                    group_index = group_index + 1
                end
            end
        end
    end
end

function DecisionTreeRenderer:group_nodes_by_type(nodes)
    local groups = {
        input = {},
        weight = {},
        bias = {},
        multiply = {},
        add = {},
        activation = {},
        loss = {}
    }
    
    for _, node in ipairs(nodes) do
        local node_type = node.operation
        if groups[node_type] then
            table.insert(groups[node_type], node)
        else
            -- Default group for unknown types
            if not groups.other then
                groups.other = {}
            end
            table.insert(groups.other, node)
        end
    end
    
    return groups
end
-- }}}

-- {{{ Drawing methods
function DecisionTreeRenderer:draw_background()
    love.graphics.setColor(self.colors.background)
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
    love.graphics.setColor(self.colors.border)
    love.graphics.rectangle("line", self.x, self.y, self.width, self.height)
    
    -- Draw title
    love.graphics.setColor(self.colors.text)
    love.graphics.print("Decision Tree", self.x + 10, self.y + 5)
end

function DecisionTreeRenderer:draw_connections()
    if not self.decision_tree.connections then
        return
    end
    
    love.graphics.setLineWidth(self.connection_width)
    
    -- Draw all connections between nodes
    for node_id, connection_info in pairs(self.decision_tree.connections) do
        local from_pos = self.node_positions[node_id]
        
        if from_pos then
            for _, to_node_id in ipairs(connection_info.outputs) do
                local to_pos = self.node_positions[to_node_id]
                
                if to_pos then
                    -- Determine connection color based on gradient strength
                    local color = self.colors.connection
                    local from_node = from_pos.node
                    local to_node = to_pos.node
                    
                    if self.gradient_contributions[node_id] and self.show_contributions then
                        local contrib = self.gradient_contributions[node_id]
                        local grad_magnitude = math.abs(contrib.total_gradient or 0)
                        
                        if grad_magnitude > 0.1 then
                            color = self.colors.strong_gradient
                        elseif grad_magnitude > 0.01 then
                            color = self.colors.medium_gradient
                        else
                            color = self.colors.weak_gradient
                        end
                    end
                    
                    -- Highlight if part of selected path
                    if self:is_in_highlighted_path(node_id, to_node_id) then
                        color = self.colors.path_highlight
                        love.graphics.setLineWidth(self.connection_width * 2)
                    end
                    
                    love.graphics.setColor(color)
                    
                    -- Draw curved connection for better visibility
                    self:draw_curved_connection(
                        from_pos.x, from_pos.y,
                        to_pos.x, to_pos.y
                    )
                    
                    love.graphics.setLineWidth(self.connection_width)
                end
            end
        end
    end
    
    love.graphics.setLineWidth(1)
end

function DecisionTreeRenderer:draw_curved_connection(x1, y1, x2, y2)
    -- Calculate control points for a smooth curve
    local control_offset = 30
    local cx1 = x1 + control_offset
    local cy1 = y1
    local cx2 = x2 - control_offset
    local cy2 = y2
    
    -- Draw bezier curve
    local points = {}
    local segments = 20
    
    for i = 0, segments do
        local t = i / segments
        local inv_t = 1 - t
        
        local x = inv_t^3 * x1 + 3 * inv_t^2 * t * cx1 + 
                  3 * inv_t * t^2 * cx2 + t^3 * x2
        local y = inv_t^3 * y1 + 3 * inv_t^2 * t * cy1 + 
                  3 * inv_t * t^2 * cy2 + t^3 * y2
        
        table.insert(points, x)
        table.insert(points, y)
    end
    
    if #points >= 4 then
        love.graphics.line(points)
    end
end

function DecisionTreeRenderer:draw_nodes()
    if not self.node_positions then
        return
    end
    
    for node_id, pos_info in pairs(self.node_positions) do
        local node = pos_info.node
        local x, y = pos_info.x, pos_info.y
        
        -- Choose color based on node operation type
        local color = self.colors.input_node
        if node.operation == "weight" then
            color = self.colors.weight_node
        elseif node.operation == "bias" then
            color = self.colors.bias_node
        elseif node.operation == "multiply" then
            color = self.colors.multiply_node
        elseif node.operation == "add" then
            color = self.colors.add_node
        elseif node.operation == "activation" then
            color = self.colors.activation_node
        elseif node.operation == "loss" then
            color = self.colors.loss_node
        end
        
        -- Modulate brightness based on gradient contribution
        local brightness = 0.5
        if self.gradient_contributions[node_id] and self.show_contributions then
            local contrib = self.gradient_contributions[node_id]
            local grad_magnitude = math.abs(contrib.total_gradient or 0)
            brightness = 0.3 + 0.7 * math.min(1.0, grad_magnitude * 5)
        end
        
        -- Draw node circle
        love.graphics.setColor(
            color[1] * brightness,
            color[2] * brightness, 
            color[3] * brightness
        )
        love.graphics.circle("fill", x, y, self.node_radius)
        
        -- Highlight if selected
        if self.selected_node and self.selected_node.node_id == node_id then
            love.graphics.setColor(self.colors.selected_highlight)
            love.graphics.setLineWidth(3)
            love.graphics.circle("line", x, y, self.node_radius + 2)
            love.graphics.setLineWidth(1)
        end
        
        -- Draw node border
        love.graphics.setColor(self.colors.border)
        love.graphics.circle("line", x, y, self.node_radius)
        
        -- Draw operation symbol/text
        love.graphics.setColor(self.colors.text)
        local symbol = self:get_operation_symbol(node.operation)
        local font = love.graphics.getFont()
        local text_width = font:getWidth(symbol)
        love.graphics.print(symbol, x - text_width/2, y - 6)
        
        -- Draw value if available
        if node.value and math.abs(node.value) > 0.001 then
            love.graphics.setColor(0.8, 0.8, 0.8)
            love.graphics.print(string.format("%.2f", node.value), 
                x - 15, y + self.node_radius + 2)
        end
        
        -- Draw gradient if available and significant
        if node.gradient and math.abs(node.gradient) > 0.001 then
            local grad_color = node.gradient >= 0 and {0.3, 0.8, 0.3} or {0.8, 0.3, 0.3}
            love.graphics.setColor(grad_color)
            love.graphics.print(string.format("∇%.2f", node.gradient),
                x - 18, y + self.node_radius + 15)
        end
    end
end

function DecisionTreeRenderer:get_operation_symbol(operation)
    local symbols = {
        input = "I",
        weight = "W",
        bias = "B",
        multiply = "×",
        add = "+",
        activation = "σ",
        loss = "L"
    }
    return symbols[operation] or "?"
end

function DecisionTreeRenderer:draw_info_panel()
    -- Draw information about selected node or general tree stats
    local panel_x = self.x + 10
    local panel_y = self.y + self.height - 120
    local panel_width = 180
    local panel_height = 110
    
    love.graphics.setColor(0.15, 0.15, 0.2, 0.8)
    love.graphics.rectangle("fill", panel_x, panel_y, panel_width, panel_height)
    love.graphics.setColor(self.colors.border)
    love.graphics.rectangle("line", panel_x, panel_y, panel_width, panel_height)
    
    love.graphics.setColor(self.colors.text)
    
    if self.selected_node then
        local node = self.selected_node.node
        love.graphics.print("Selected Node:", panel_x + 5, panel_y + 5)
        love.graphics.print(string.format("Op: %s", node.operation), 
            panel_x + 5, panel_y + 20)
        love.graphics.print(string.format("Value: %.4f", node.value or 0), 
            panel_x + 5, panel_y + 35)
        love.graphics.print(string.format("Grad: %.4f", node.gradient or 0), 
            panel_x + 5, panel_y + 50)
        
        -- Show contribution breakdown
        if self.gradient_contributions[self.selected_node.node_id] then
            local contrib = self.gradient_contributions[self.selected_node.node_id]
            love.graphics.print(string.format("Contrib: %d paths", 
                #(contrib.path_contributions or {})), 
                panel_x + 5, panel_y + 65)
        end
    else
        love.graphics.print("Tree Statistics:", panel_x + 5, panel_y + 5)
        love.graphics.print(string.format("Nodes: %d", 
            self:count_total_nodes()), panel_x + 5, panel_y + 20)
        love.graphics.print(string.format("Layers: %d", 
            self.decision_tree.max_depth or 0), panel_x + 5, panel_y + 35)
        love.graphics.print(string.format("Paths: %d", 
            self:count_gradient_paths()), panel_x + 5, panel_y + 50)
        
        love.graphics.print("Controls:", panel_x + 5, panel_y + 70)
        love.graphics.print("Click: Select node", panel_x + 5, panel_y + 85)
    end
end

function DecisionTreeRenderer:draw()
    if not self.decision_tree or not self.decision_tree.layers then
        -- Draw placeholder
        love.graphics.setColor(self.colors.background)
        love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
        love.graphics.setColor(self.colors.border)
        love.graphics.rectangle("line", self.x, self.y, self.width, self.height)
        
        love.graphics.setColor(self.colors.text)
        love.graphics.print("Decision tree will appear here", 
            self.x + 20, self.y + self.height/2)
        love.graphics.print("when computation tracking is enabled", 
            self.x + 20, self.y + self.height/2 + 20)
        return
    end
    
    self:draw_background()
    self:draw_connections()
    self:draw_nodes()
    self:draw_info_panel()
end
-- }}}

-- {{{ Interaction methods
function DecisionTreeRenderer:mouse_moved(x, y)
    self.hovered_node = nil
    
    for node_id, pos_info in pairs(self.node_positions) do
        local dx = x - pos_info.x
        local dy = y - pos_info.y
        local distance = math.sqrt(dx*dx + dy*dy)
        
        if distance <= self.node_radius then
            self.hovered_node = {
                node_id = node_id,
                node = pos_info.node,
                position = {x = pos_info.x, y = pos_info.y}
            }
            return
        end
    end
end

function DecisionTreeRenderer:mouse_pressed(x, y, button)
    if button == 1 and self.hovered_node then
        self.selected_node = self.hovered_node
        self:trace_path_from_node(self.selected_node.node_id)
        return true
    end
    return false
end

function DecisionTreeRenderer:trace_path_from_node(node_id)
    -- Trace all paths that go through this node
    self.highlighted_path = {}
    
    -- Simple path tracing - can be enhanced
    if self.decision_tree.connections and self.decision_tree.connections[node_id] then
        local connection_info = self.decision_tree.connections[node_id]
        
        -- Add all connected nodes to highlighted path
        for _, input_id in ipairs(connection_info.inputs or {}) do
            table.insert(self.highlighted_path, {from = input_id, to = node_id})
        end
        
        for _, output_id in ipairs(connection_info.outputs or {}) do
            table.insert(self.highlighted_path, {from = node_id, to = output_id})
        end
    end
end

function DecisionTreeRenderer:is_in_highlighted_path(from_id, to_id)
    for _, path_segment in ipairs(self.highlighted_path) do
        if path_segment.from == from_id and path_segment.to == to_id then
            return true
        end
    end
    return false
end

function DecisionTreeRenderer:get_selected_node()
    return self.selected_node
end
-- }}}

-- {{{ Utility methods
function DecisionTreeRenderer:count_total_nodes()
    local count = 0
    if self.decision_tree.layers then
        for _, layer in pairs(self.decision_tree.layers) do
            count = count + #layer
        end
    end
    return count
end

function DecisionTreeRenderer:count_gradient_paths()
    -- This would count the number of gradient flow paths
    -- For now, return an estimate based on connections
    local count = 0
    if self.decision_tree.connections then
        for _, connection_info in pairs(self.decision_tree.connections) do
            count = count + #(connection_info.outputs or {})
        end
    end
    return count
end

function DecisionTreeRenderer:set_bounds(x, y, width, height)
    self.x = x
    self.y = y
    self.width = width
    self.height = height
    self:calculate_layout()
end

function DecisionTreeRenderer:toggle_contributions()
    self.show_contributions = not self.show_contributions
end

function DecisionTreeRenderer:toggle_compact_mode()
    self.compact_mode = not self.compact_mode
    self:calculate_layout()
end

function DecisionTreeRenderer:clear()
    self.decision_tree = {}
    self.node_positions = {}
    self.gradient_contributions = {}
    self.selected_node = nil
    self.highlighted_path = {}
end
-- }}}

return DecisionTreeRenderer
-- }}}