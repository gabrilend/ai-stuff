-- {{{ Gradient Flow Visualizer
-- Visualizes gradient flow during backpropagation and computation graph

local GradientVisualizer = {}
GradientVisualizer.__index = GradientVisualizer

-- {{{ GradientVisualizer constructor
function GradientVisualizer:new(x, y, width, height)
    local obj = {
        x = x or 50,
        y = y or 550,
        width = width or 600,
        height = height or 200,
        
        -- Visual settings
        node_radius = 15,
        arrow_width = 3,
        animation_speed = 2.0,
        
        -- Colors
        colors = {
            positive_gradient = {0.3, 0.8, 0.3, 0.8},  -- Green
            negative_gradient = {0.8, 0.3, 0.3, 0.8},  -- Red
            zero_gradient = {0.5, 0.5, 0.5, 0.5},      -- Gray
            node_input = {0.3, 0.7, 0.8},              -- Light blue
            node_weight = {0.8, 0.6, 0.2},             -- Orange
            node_bias = {0.6, 0.3, 0.8},               -- Purple
            node_operation = {0.2, 0.6, 0.2},          -- Green
            node_activation = {0.8, 0.3, 0.5},         -- Pink
            node_loss = {0.8, 0.2, 0.2},               -- Red
            background = {0.1, 0.1, 0.15},
            border = {0.4, 0.4, 0.5},
            text = {1, 1, 1},
            arrow = {0.9, 0.9, 0.2}                     -- Yellow
        },
        
        -- Current visualization state
        computation_graph = nil,
        decision_tree = {},
        gradient_flow_paths = {},
        node_positions = {},
        animated_gradients = {},
        animation_time = 0,
        
        -- Interaction
        hovered_node = nil,
        selected_path = nil,
        show_all_paths = true
    }
    
    setmetatable(obj, self)
    return obj
end
-- }}}

-- {{{ Data management
function GradientVisualizer:set_computation_graph(graph)
    self.computation_graph = graph
    self:calculate_positions()
end

function GradientVisualizer:set_decision_tree(tree)
    self.decision_tree = tree
    self:calculate_positions()
end

function GradientVisualizer:set_gradient_flow_paths(paths)
    self.gradient_flow_paths = paths
    self:start_gradient_animation()
end

function GradientVisualizer:calculate_positions()
    if not self.computation_graph then
        return
    end
    
    self.node_positions = {}
    local tree = self.decision_tree
    
    if not tree.layers or #tree.layers == 0 then
        return
    end
    
    -- Calculate layer spacing
    local layer_spacing = self.width / math.max(1, tree.max_depth)
    
    for layer_depth = 1, tree.max_depth do
        local layer_nodes = tree.layers[layer_depth]
        if layer_nodes then
            local node_spacing = self.height / math.max(1, #layer_nodes)
            
            for i, node in ipairs(layer_nodes) do
                local x = self.x + (layer_depth - 1) * layer_spacing + self.node_radius
                local y = self.y + (i - 1) * node_spacing + self.node_radius
                
                self.node_positions[node.id] = {
                    x = x,
                    y = y,
                    node = node
                }
            end
        end
    end
end
-- }}}

-- {{{ Animation methods
function GradientVisualizer:start_gradient_animation()
    self.animated_gradients = {}
    self.animation_time = 0
    
    -- Create animated gradient particles for each path
    for path_index, path in ipairs(self.gradient_flow_paths) do
        if #path > 1 then
            table.insert(self.animated_gradients, {
                path = path,
                progress = 0,
                speed = self.animation_speed * (0.8 + math.random() * 0.4),
                color_intensity = math.random() * 0.5 + 0.5,
                particle_size = math.random() * 5 + 3
            })
        end
    end
end

function GradientVisualizer:update_animation(dt)
    self.animation_time = self.animation_time + dt
    
    for _, animated_grad in ipairs(self.animated_gradients) do
        animated_grad.progress = animated_grad.progress + animated_grad.speed * dt
        
        -- Loop animation
        if animated_grad.progress > 1.0 then
            animated_grad.progress = 0
        end
    end
end
-- }}}

-- {{{ Drawing methods
function GradientVisualizer:draw_background()
    love.graphics.setColor(self.colors.background)
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
    love.graphics.setColor(self.colors.border)
    love.graphics.rectangle("line", self.x, self.y, self.width, self.height)
end

function GradientVisualizer:draw_nodes()
    if not self.computation_graph or not self.node_positions then
        return
    end
    
    for node_id, pos_info in pairs(self.node_positions) do
        local node = pos_info.node
        local x, y = pos_info.x, pos_info.y
        
        -- Choose color based on node type
        local color = self.colors.node_operation
        if node.operation == "input" then
            color = self.colors.node_input
        elseif node.operation == "weight" then
            color = self.colors.node_weight
        elseif node.operation == "bias" then
            color = self.colors.node_bias
        elseif node.operation == "activation" then
            color = self.colors.node_activation
        elseif node.operation == "loss" then
            color = self.colors.node_loss
        end
        
        -- Modulate brightness based on gradient magnitude
        local gradient_intensity = 1.0
        if node.gradient and math.abs(node.gradient) > 0 then
            gradient_intensity = 0.3 + 0.7 * math.min(1.0, math.abs(node.gradient))
        end
        
        -- Draw node
        love.graphics.setColor(
            color[1] * gradient_intensity, 
            color[2] * gradient_intensity, 
            color[3] * gradient_intensity
        )
        love.graphics.circle("fill", x, y, self.node_radius)
        
        -- Draw gradient direction indicator
        if node.gradient and math.abs(node.gradient) > 0.001 then
            local indicator_color = node.gradient >= 0 and 
                self.colors.positive_gradient or 
                self.colors.negative_gradient
            
            love.graphics.setColor(indicator_color)
            love.graphics.circle("line", x, y, self.node_radius + 3)
            
            -- Draw gradient magnitude as text
            love.graphics.setColor(self.colors.text)
            love.graphics.print(string.format("%.3f", node.gradient), 
                x - 15, y + self.node_radius + 5)
        end
        
        -- Draw node border
        love.graphics.setColor(self.colors.border)
        love.graphics.circle("line", x, y, self.node_radius)
        
        -- Draw operation label
        love.graphics.setColor(self.colors.text)
        local op_text = node.operation:sub(1, 3)  -- Abbreviate
        love.graphics.print(op_text, x - 10, y - 5)
    end
end

function GradientVisualizer:draw_connections()
    if not self.computation_graph or not self.decision_tree.connections then
        return
    end
    
    love.graphics.setLineWidth(self.arrow_width)
    
    for node_id, connection_info in pairs(self.decision_tree.connections) do
        local from_pos = self.node_positions[node_id]
        
        if from_pos then
            for _, to_node_id in ipairs(connection_info.outputs) do
                local to_pos = self.node_positions[to_node_id]
                
                if to_pos then
                    -- Calculate gradient-based color and thickness
                    local from_node = from_pos.node
                    local gradient_mag = math.abs(from_node.gradient or 0)
                    local alpha = math.min(1.0, gradient_mag * 2)
                    
                    local color = gradient_mag > 0.001 and
                        (from_node.gradient >= 0 and 
                         self.colors.positive_gradient or 
                         self.colors.negative_gradient) or
                        self.colors.zero_gradient
                    
                    love.graphics.setColor(color[1], color[2], color[3], alpha)
                    
                    -- Draw gradient flow arrow
                    self:draw_arrow(from_pos.x, from_pos.y, to_pos.x, to_pos.y)
                end
            end
        end
    end
    
    love.graphics.setLineWidth(1)
end

function GradientVisualizer:draw_arrow(x1, y1, x2, y2)
    -- Draw line
    love.graphics.line(x1, y1, x2, y2)
    
    -- Draw arrowhead
    local angle = math.atan2(y2 - y1, x2 - x1)
    local arrowhead_size = 8
    
    local arrow_x1 = x2 - arrowhead_size * math.cos(angle - 0.5)
    local arrow_y1 = y2 - arrowhead_size * math.sin(angle - 0.5)
    local arrow_x2 = x2 - arrowhead_size * math.cos(angle + 0.5)
    local arrow_y2 = y2 - arrowhead_size * math.sin(angle + 0.5)
    
    love.graphics.line(x2, y2, arrow_x1, arrow_y1)
    love.graphics.line(x2, y2, arrow_x2, arrow_y2)
end

function GradientVisualizer:draw_animated_gradients()
    for _, animated_grad in ipairs(self.animated_gradients) do
        local path = animated_grad.path
        
        if #path > 1 then
            -- Calculate current position along path
            local total_segments = #path - 1
            local current_segment = math.floor(animated_grad.progress * total_segments) + 1
            local segment_progress = (animated_grad.progress * total_segments) % 1
            
            if current_segment < #path then
                local from_node = path[current_segment]
                local to_node = path[current_segment + 1]
                
                local from_pos = self.node_positions[from_node.id]
                local to_pos = self.node_positions[to_node.id]
                
                if from_pos and to_pos then
                    -- Interpolate position
                    local particle_x = from_pos.x + (to_pos.x - from_pos.x) * segment_progress
                    local particle_y = from_pos.y + (to_pos.y - from_pos.y) * segment_progress
                    
                    -- Draw animated particle
                    love.graphics.setColor(
                        self.colors.arrow[1] * animated_grad.color_intensity,
                        self.colors.arrow[2] * animated_grad.color_intensity,
                        self.colors.arrow[3] * animated_grad.color_intensity,
                        0.8
                    )
                    
                    love.graphics.circle("fill", particle_x, particle_y, animated_grad.particle_size)
                    
                    -- Draw trail effect
                    love.graphics.setColor(
                        self.colors.arrow[1] * animated_grad.color_intensity,
                        self.colors.arrow[2] * animated_grad.color_intensity,
                        self.colors.arrow[3] * animated_grad.color_intensity,
                        0.3
                    )
                    love.graphics.circle("fill", particle_x, particle_y, animated_grad.particle_size * 1.5)
                end
            end
        end
    end
end

function GradientVisualizer:draw_info_panel()
    -- Draw information about gradient flow
    love.graphics.setColor(self.colors.border)
    love.graphics.rectangle("line", self.x + self.width - 200, self.y, 190, 100)
    
    love.graphics.setColor(self.colors.text)
    love.graphics.print("Gradient Flow", self.x + self.width - 190, self.y + 10)
    
    if self.computation_graph then
        local stats = self.computation_graph:get_stats()
        love.graphics.print(string.format("Nodes: %d", stats.total_nodes),
            self.x + self.width - 190, self.y + 30)
        love.graphics.print(string.format("Paths: %d", #self.gradient_flow_paths),
            self.x + self.width - 190, self.y + 50)
        love.graphics.print(string.format("Depth: %d", stats.max_depth),
            self.x + self.width - 190, self.y + 70)
    end
end

function GradientVisualizer:draw()
    if not self.computation_graph then
        -- Draw placeholder
        love.graphics.setColor(self.colors.background)
        love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
        love.graphics.setColor(self.colors.border)
        love.graphics.rectangle("line", self.x, self.y, self.width, self.height)
        
        love.graphics.setColor(self.colors.text)
        love.graphics.print("Enable computation tracking to view gradient flow", 
            self.x + 20, self.y + self.height/2)
        return
    end
    
    self:draw_background()
    self:draw_connections()
    self:draw_nodes()
    self:draw_animated_gradients()
    self:draw_info_panel()
end
-- }}}

-- {{{ Interaction methods
function GradientVisualizer:mouse_moved(x, y)
    self.hovered_node = nil
    
    -- Check if mouse is over any node
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

function GradientVisualizer:mouse_pressed(x, y, button)
    if button == 1 and self.hovered_node then
        -- Select gradient path containing this node
        for i, path in ipairs(self.gradient_flow_paths) do
            for _, path_node in ipairs(path) do
                if path_node.id == self.hovered_node.node_id then
                    self.selected_path = i
                    return true
                end
            end
        end
    end
    return false
end

function GradientVisualizer:get_hovered_node()
    return self.hovered_node
end

function GradientVisualizer:get_selected_path()
    return self.selected_path and self.gradient_flow_paths[self.selected_path] or nil
end
-- }}}

-- {{{ Utility methods
function GradientVisualizer:set_bounds(x, y, width, height)
    self.x = x
    self.y = y
    self.width = width
    self.height = height
    self:calculate_positions()
end

function GradientVisualizer:get_bounds()
    return self.x, self.y, self.width, self.height
end

function GradientVisualizer:toggle_show_all_paths()
    self.show_all_paths = not self.show_all_paths
end

function GradientVisualizer:clear()
    self.computation_graph = nil
    self.decision_tree = {}
    self.gradient_flow_paths = {}
    self.node_positions = {}
    self.animated_gradients = {}
    self.hovered_node = nil
    self.selected_path = nil
end
-- }}}

return GradientVisualizer
-- }}}