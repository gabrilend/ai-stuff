-- {{{ Network Renderer
-- Visualizes neural networks with neurons and connections

local NetworkRenderer = {}
NetworkRenderer.__index = NetworkRenderer

-- {{{ NetworkRenderer constructor
function NetworkRenderer:new(x, y, width, height)
    local obj = {
        x = x or 50,
        y = y or 120,
        width = width or 600,
        height = height or 400,
        
        -- Visual settings
        neuron_radius = 25,
        layer_spacing = 150,
        neuron_spacing = 60,
        connection_width = 2,
        
        -- Colors
        colors = {
            input_layer = {0.3, 0.7, 0.3},      -- Green
            hidden_layer = {0.3, 0.5, 0.8},     -- Blue  
            output_layer = {0.8, 0.3, 0.3},     -- Red
            connection = {0.6, 0.6, 0.6, 0.7},  -- Gray with alpha
            connection_positive = {0.3, 0.8, 0.3, 0.8}, -- Green
            connection_negative = {0.8, 0.3, 0.3, 0.8}, -- Red
            neuron_border = {0.8, 0.8, 0.8},
            text = {1, 1, 1},
            background = {0.15, 0.15, 0.2}
        },
        
        -- Current network
        network = nil,
        neuron_positions = {},
        
        -- Interaction
        hovered_neuron = nil,
        selected_neuron = nil
    }
    
    setmetatable(obj, self)
    return obj
end
-- }}}

-- {{{ Network management
function NetworkRenderer:set_network(network)
    self.network = network
    self:calculate_positions()
end

function NetworkRenderer:get_network()
    return self.network
end
-- }}}

-- {{{ Position calculation
function NetworkRenderer:calculate_positions()
    if not self.network then
        return
    end
    
    self.neuron_positions = {}
    local layer_count = self.network:get_layer_count()
    
    if layer_count == 0 then
        return
    end
    
    -- Calculate layer spacing
    local available_width = self.width - 2 * self.neuron_radius
    local spacing = available_width / math.max(1, layer_count - 1)
    
    for layer_index = 1, layer_count do
        local layer = self.network:get_layer(layer_index)
        local layer_size = #layer
        self.neuron_positions[layer_index] = {}
        
        -- Calculate x position for this layer
        local layer_x = self.x + self.neuron_radius
        if layer_count > 1 then
            layer_x = self.x + self.neuron_radius + (layer_index - 1) * spacing
        end
        
        -- Calculate y positions for neurons in this layer
        local available_height = self.height - 2 * self.neuron_radius
        local neuron_spacing = 0
        if layer_size > 1 then
            neuron_spacing = available_height / (layer_size - 1)
        end
        
        local start_y = self.y + self.neuron_radius
        if layer_size == 1 then
            start_y = self.y + self.height / 2
        end
        
        for neuron_index = 1, layer_size do
            local neuron_y = start_y
            if layer_size > 1 then
                neuron_y = start_y + (neuron_index - 1) * neuron_spacing
            end
            
            self.neuron_positions[layer_index][neuron_index] = {
                x = layer_x,
                y = neuron_y
            }
            
            -- Update neuron position for interaction
            if layer_index > 1 then -- Skip input layer
                local neuron = self.network:get_neuron(layer_index, neuron_index)
                neuron:set_position(layer_x, neuron_y)
            end
        end
    end
end
-- }}}

-- {{{ Drawing methods
function NetworkRenderer:draw_background()
    love.graphics.setColor(self.colors.background)
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
    love.graphics.setColor(self.colors.neuron_border)
    love.graphics.rectangle("line", self.x, self.y, self.width, self.height)
end

function NetworkRenderer:draw_connections()
    if not self.network or not self.neuron_positions then
        return
    end
    
    love.graphics.setLineWidth(self.connection_width)
    
    -- Draw connections between layers
    for layer_index = 2, self.network:get_layer_count() do
        local current_layer = self.network:get_layer(layer_index)
        local prev_layer_positions = self.neuron_positions[layer_index - 1]
        local current_layer_positions = self.neuron_positions[layer_index]
        
        for neuron_index, neuron in ipairs(current_layer) do
            local neuron_pos = current_layer_positions[neuron_index]
            
            -- Draw connection from each previous layer neuron to this neuron
            for prev_neuron_index = 1, #prev_layer_positions do
                local prev_pos = prev_layer_positions[prev_neuron_index]
                local weight = neuron:get_weight(prev_neuron_index)
                
                -- Color based on weight sign and magnitude
                local alpha = math.min(math.abs(weight), 1)
                if weight >= 0 then
                    love.graphics.setColor(
                        self.colors.connection_positive[1],
                        self.colors.connection_positive[2], 
                        self.colors.connection_positive[3],
                        alpha * 0.8
                    )
                else
                    love.graphics.setColor(
                        self.colors.connection_negative[1],
                        self.colors.connection_negative[2],
                        self.colors.connection_negative[3], 
                        alpha * 0.8
                    )
                end
                
                -- Draw line with thickness based on weight magnitude
                local thickness = math.max(1, math.abs(weight) * 5)
                love.graphics.setLineWidth(thickness)
                
                love.graphics.line(
                    prev_pos.x, prev_pos.y,
                    neuron_pos.x, neuron_pos.y
                )
            end
        end
    end
    
    love.graphics.setLineWidth(1)
end

function NetworkRenderer:draw_neurons()
    if not self.network or not self.neuron_positions then
        return
    end
    
    for layer_index = 1, self.network:get_layer_count() do
        local layer_positions = self.neuron_positions[layer_index]
        
        -- Choose color based on layer type
        local color
        if layer_index == 1 then
            color = self.colors.input_layer
        elseif layer_index == self.network:get_layer_count() then
            color = self.colors.output_layer
        else
            color = self.colors.hidden_layer
        end
        
        for neuron_index = 1, #layer_positions do
            local pos = layer_positions[neuron_index]
            
            -- Get neuron output for brightness modulation
            local brightness = 1.0
            if layer_index > 1 then
                local neuron = self.network:get_neuron(layer_index, neuron_index)
                local output = neuron:get_last_output()
                if output then
                    brightness = 0.3 + 0.7 * math.max(0, math.min(1, output))
                end
            end
            
            -- Draw neuron circle
            love.graphics.setColor(
                color[1] * brightness, 
                color[2] * brightness, 
                color[3] * brightness
            )
            love.graphics.circle("fill", pos.x, pos.y, self.neuron_radius)
            
            -- Draw border (highlight if hovered)
            if self.hovered_neuron and 
               self.hovered_neuron.layer == layer_index and 
               self.hovered_neuron.neuron == neuron_index then
                love.graphics.setColor(1, 1, 0) -- Yellow highlight
                love.graphics.setLineWidth(3)
            else
                love.graphics.setColor(self.colors.neuron_border)
                love.graphics.setLineWidth(2)
            end
            love.graphics.circle("line", pos.x, pos.y, self.neuron_radius)
            
            -- Draw neuron index
            love.graphics.setColor(self.colors.text)
            local font = love.graphics.getFont()
            local text = tostring(neuron_index)
            local text_width = font:getWidth(text)
            local text_height = font:getHeight()
            love.graphics.print(text, 
                pos.x - text_width/2, 
                pos.y - text_height/2
            )
        end
    end
    
    love.graphics.setLineWidth(1)
end

function NetworkRenderer:draw_labels()
    if not self.network then
        return
    end
    
    love.graphics.setColor(self.colors.text)
    local layer_count = self.network:get_layer_count()
    
    for layer_index = 1, layer_count do
        local positions = self.neuron_positions[layer_index]
        if positions and #positions > 0 then
            local label
            if layer_index == 1 then
                label = "Input"
            elseif layer_index == layer_count then
                label = "Output"
            else
                label = "Hidden " .. (layer_index - 1)
            end
            
            local pos = positions[1]
            love.graphics.print(label, pos.x - 30, self.y - 20)
        end
    end
end

function NetworkRenderer:draw()
    if not self.network then
        -- Draw placeholder
        love.graphics.setColor(0.3, 0.3, 0.3)
        love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.rectangle("line", self.x, self.y, self.width, self.height)
        
        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.print("No network loaded", 
            self.x + self.width/2 - 60, 
            self.y + self.height/2
        )
        return
    end
    
    self:draw_background()
    self:draw_connections()
    self:draw_neurons()
    self:draw_labels()
end
-- }}}

-- {{{ Interaction methods
function NetworkRenderer:mouse_moved(x, y)
    self.hovered_neuron = nil
    
    if not self.neuron_positions then
        return
    end
    
    -- Check if mouse is over any neuron
    for layer_index, layer_positions in ipairs(self.neuron_positions) do
        for neuron_index, pos in ipairs(layer_positions) do
            local dx = x - pos.x
            local dy = y - pos.y
            local distance = math.sqrt(dx*dx + dy*dy)
            
            if distance <= self.neuron_radius then
                self.hovered_neuron = {
                    layer = layer_index,
                    neuron = neuron_index,
                    position = pos
                }
                return
            end
        end
    end
end

function NetworkRenderer:mouse_pressed(x, y, button)
    if button == 1 and self.hovered_neuron then -- Left click
        self.selected_neuron = self.hovered_neuron
        return true
    end
    return false
end

function NetworkRenderer:get_hovered_neuron()
    return self.hovered_neuron
end

function NetworkRenderer:get_selected_neuron()
    return self.selected_neuron
end
-- }}}

-- {{{ Utility methods
function NetworkRenderer:set_bounds(x, y, width, height)
    self.x = x
    self.y = y
    self.width = width
    self.height = height
    self:calculate_positions()
end

function NetworkRenderer:get_bounds()
    return self.x, self.y, self.width, self.height
end

function NetworkRenderer:resize(width, height)
    self.width = width
    self.height = height
    self:calculate_positions()
end

function NetworkRenderer:get_neuron_info(layer_index, neuron_index)
    if not self.network then
        return nil
    end
    
    if layer_index == 1 then
        return {
            type = "input",
            index = neuron_index,
            value = nil -- Input values would come from external source
        }
    end
    
    local neuron = self.network:get_neuron(layer_index, neuron_index)
    return {
        type = layer_index == self.network:get_layer_count() and "output" or "hidden",
        index = neuron_index,
        weights = neuron:get_all_weights(),
        bias = neuron:get_bias(),
        activation_function = neuron:get_activation_function(),
        last_output = neuron:get_last_output(),
        weighted_sum = neuron:get_weighted_sum()
    }
end
-- }}}

return NetworkRenderer
-- }}}