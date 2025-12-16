-- {{{ Stereographic 3D Neural Network Renderer
-- Creates immersive 3D representation of neural networks with rotating perspective
-- Connection strength determines depth positioning for intuitive structure visualization

local Stereo3DRenderer = {}
Stereo3DRenderer.__index = Stereo3DRenderer

-- {{{ Constructor
function Stereo3DRenderer:new(x, y, width, height)
    local obj = {
        x = x or 0,
        y = y or 0,
        width = width or 800,
        height = height or 600,
        
        -- 3D projection parameters
        camera = {
            x = 0,
            y = 0,
            z = -10,
            rotation_x = 0,
            rotation_y = 0,
            rotation_z = 0,
            fov = 60,
            near = 0.1,
            far = 100
        },
        
        -- Rotation control
        rotation_speed = 0.02,
        auto_rotate = false,
        rotation_direction = 1,
        target_rotation_y = 0,
        
        -- Node positioning and rendering
        nodes = {},
        connections = {},
        node_icons = {},
        depth_layers = 5,
        min_icon_size = 8,
        max_icon_size = 32,
        
        -- Network reference
        network = nil,
        
        -- Perspective settings
        perspective_strength = 0.8,
        depth_range = {-5, 5},
        connection_depth_factor = 0.7,
        
        -- Visual settings
        colors = {
            strong_connection = {0.2, 0.8, 0.3},
            weak_connection = {0.8, 0.3, 0.2},
            node_core = {0.9, 0.9, 1.0},
            node_active = {1.0, 0.8, 0.2},
            background = {0.02, 0.02, 0.08},
            depth_fog = {0.1, 0.1, 0.2}
        },
        
        -- Interaction
        mouse_dragging = false,
        last_mouse_x = 0,
        last_mouse_y = 0,
        
        -- Animation
        animation_time = 0,
        pulse_frequency = 2.0,
        rotation_smoothing = 0.1
    }
    
    setmetatable(obj, self)
    obj:initialize_node_icons()
    return obj
end
-- }}}

-- {{{ 3D Mathematics Functions
function Stereo3DRenderer:project_3d_to_2d(x3d, y3d, z3d)
    -- Apply camera rotation
    local cos_rx, sin_rx = math.cos(self.camera.rotation_x), math.sin(self.camera.rotation_x)
    local cos_ry, sin_ry = math.cos(self.camera.rotation_y), math.sin(self.camera.rotation_y)
    
    -- Rotate around Y axis
    local x_rotated = x3d * cos_ry - z3d * sin_ry
    local z_rotated = x3d * sin_ry + z3d * cos_ry
    
    -- Rotate around X axis
    local y_rotated = y3d * cos_rx - z_rotated * sin_rx
    z3d = y3d * sin_rx + z_rotated * cos_rx
    
    -- Apply camera translation
    z3d = z3d + self.camera.z
    
    -- Perspective projection
    if z3d <= 0.01 then z3d = 0.01 end
    
    local fov_factor = math.tan(math.rad(self.camera.fov / 2))
    local scale = (self.width / 2) / (fov_factor * z3d)
    
    local x2d = self.x + self.width / 2 + x_rotated * scale
    local y2d = self.y + self.height / 2 - y_rotated * scale
    
    return x2d, y2d, z3d
end

function Stereo3DRenderer:calculate_connection_strength(layer1, neuron1, layer2, neuron2)
    if not self.network then return 0.5 end
    
    -- Try to get weight between neurons if method exists
    if self.network.get_weight then
        local weight = self.network:get_weight(layer1, neuron1, layer2, neuron2)
        if weight then
            return math.abs(weight)
        end
    end
    
    -- Fallback: calculate based on layer structure if available
    if self.network.layers and self.network.layers[layer1] then
        local layer = self.network.layers[layer1]
        if layer.neurons and layer.neurons[neuron1] and layer.neurons[neuron1].weights then
            local weights = layer.neurons[neuron1].weights
            if weights[neuron2] then
                return math.abs(weights[neuron2])
            end
        end
    end
    
    -- Final fallback: generate consistent pseudo-random weight
    local seed = (layer1 * 1000) + (neuron1 * 100) + (layer2 * 10) + neuron2
    math.randomseed(seed)
    local weight = 0.2 + math.random() * 0.6  -- Between 0.2 and 0.8
    math.randomseed(os.time())  -- Reset random seed
    
    return weight
end

function Stereo3DRenderer:map_strength_to_depth(strength)
    -- Stronger connections are closer to viewer (smaller z values)
    local depth_min, depth_max = self.depth_range[1], self.depth_range[2]
    return depth_max - (strength * (depth_max - depth_min))
end

function Stereo3DRenderer:calculate_icon_size(z3d)
    -- Smaller icons for farther objects
    local depth_factor = math.max(0.1, 1.0 / (1.0 + math.abs(z3d) * 0.3))
    return self.min_icon_size + (self.max_icon_size - self.min_icon_size) * depth_factor
end
-- }}}

-- {{{ Node Icon System
function Stereo3DRenderer:initialize_node_icons()
    self.node_icons = {
        input = "◯",      -- Input neurons
        hidden = "◆",     -- Hidden layer neurons
        output = "◈",     -- Output neurons
        active = "●",     -- Currently firing neurons
        inactive = "○"    -- Inactive neurons
    }
end

function Stereo3DRenderer:get_node_icon(layer_type, activation_level)
    if activation_level > 0.8 then
        return self.node_icons.active
    elseif activation_level < 0.2 then
        return self.node_icons.inactive
    else
        return self.node_icons[layer_type] or self.node_icons.hidden
    end
end

function Stereo3DRenderer:calculate_node_positions()
    if not self.network then return end
    
    self.nodes = {}
    local layer_count = self.network:get_layer_count()
    
    for layer_idx = 1, layer_count do
        local layer_size = self.network:get_layer_size(layer_idx)
        local layer_type = (layer_idx == 1) and "input" or 
                          (layer_idx == layer_count) and "output" or "hidden"
        
        for neuron_idx = 1, layer_size do
            -- Calculate 3D position
            local x3d = (layer_idx - layer_count / 2 - 0.5) * 4
            local y3d = (neuron_idx - layer_size / 2 - 0.5) * 3
            
            -- Get activation level for depth calculation
            local activation = self:get_neuron_activation(layer_idx, neuron_idx)
            local base_depth = self:map_strength_to_depth(activation)
            
            -- Add some variation for visual interest
            local z3d = base_depth + math.sin(self.animation_time + neuron_idx) * 0.5
            
            table.insert(self.nodes, {
                layer = layer_idx,
                neuron = neuron_idx,
                x3d = x3d,
                y3d = y3d,
                z3d = z3d,
                type = layer_type,
                activation = activation,
                icon = self:get_node_icon(layer_type, activation)
            })
        end
    end
end

function Stereo3DRenderer:get_neuron_activation(layer_idx, neuron_idx)
    -- Try to get activation from network if method exists
    if self.network and self.network.get_neuron_activation then
        return self.network:get_neuron_activation(layer_idx, neuron_idx) or 0.5
    end
    
    -- Fallback: calculate based on current layer outputs if available
    if self.network and self.network.layers and self.network.layers[layer_idx] then
        local layer = self.network.layers[layer_idx]
        if layer.neurons and layer.neurons[neuron_idx] then
            return layer.neurons[neuron_idx].output or 0.5
        end
    end
    
    -- Fallback: generate pseudo-random but consistent activation
    local seed = (layer_idx * 100) + neuron_idx + math.floor(self.animation_time * 2)
    math.randomseed(seed)
    local activation = 0.3 + math.random() * 0.4  -- Between 0.3 and 0.7
    math.randomseed(os.time())  -- Reset random seed
    
    return activation
end

function Stereo3DRenderer:calculate_connection_positions()
    if not self.network then return end
    
    self.connections = {}
    
    -- Generate connections between adjacent layers
    for i, node1 in ipairs(self.nodes) do
        for j, node2 in ipairs(self.nodes) do
            if node2.layer == node1.layer + 1 then
                local strength = self:calculate_connection_strength(
                    node1.layer, node1.neuron, node2.layer, node2.neuron
                )
                
                -- Calculate connection depth based on strength
                local conn_depth = self:map_strength_to_depth(strength) * self.connection_depth_factor
                
                table.insert(self.connections, {
                    from_node = i,
                    to_node = j,
                    strength = strength,
                    width = math.max(1, strength * 5),
                    depth = conn_depth,
                    color = strength > 0.5 and self.colors.strong_connection or self.colors.weak_connection
                })
            end
        end
    end
end
-- }}}

-- {{{ Network Integration
function Stereo3DRenderer:set_network(network)
    self.network = network
    self:calculate_node_positions()
    self:calculate_connection_positions()
end

function Stereo3DRenderer:update_network_state()
    if not self.network then return end
    
    -- Update node activations and positions
    for _, node in ipairs(self.nodes) do
        node.activation = self:get_neuron_activation(node.layer, node.neuron)
        node.icon = self:get_node_icon(node.type, node.activation)
        
        -- Update depth based on activation
        local new_depth = self:map_strength_to_depth(node.activation)
        node.z3d = new_depth + math.sin(self.animation_time + node.neuron) * 0.3
    end
    
    -- Update connection strengths
    for _, conn in ipairs(self.connections) do
        local node1, node2 = self.nodes[conn.from_node], self.nodes[conn.to_node]
        conn.strength = self:calculate_connection_strength(
            node1.layer, node1.neuron, node2.layer, node2.neuron
        )
        conn.width = math.max(1, conn.strength * 5)
        conn.color = conn.strength > 0.5 and self.colors.strong_connection or self.colors.weak_connection
    end
end
-- }}}

-- {{{ Rendering Functions
function Stereo3DRenderer:draw()
    -- Update animation
    self.animation_time = self.animation_time + love.timer.getDelta()
    
    -- Update rotation
    if self.auto_rotate then
        self.camera.rotation_y = self.camera.rotation_y + self.rotation_speed * self.rotation_direction
    else
        -- Smooth rotation to target
        local rotation_diff = self.target_rotation_y - self.camera.rotation_y
        self.camera.rotation_y = self.camera.rotation_y + rotation_diff * self.rotation_smoothing
    end
    
    -- Update network state
    self:update_network_state()
    
    -- Clear background with depth fog effect
    love.graphics.setColor(self.colors.background)
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
    
    -- Draw connections first (behind nodes)
    self:draw_connections()
    
    -- Draw nodes on top
    self:draw_nodes()
    
    -- Draw UI controls
    self:draw_controls()
end

function Stereo3DRenderer:draw_connections()
    for _, conn in ipairs(self.connections) do
        local node1 = self.nodes[conn.from_node]
        local node2 = self.nodes[conn.to_node]
        
        -- Project both endpoints to 2D
        local x1_2d, y1_2d, z1_3d = self:project_3d_to_2d(node1.x3d, node1.y3d, node1.z3d)
        local x2_2d, y2_2d, z2_3d = self:project_3d_to_2d(node2.x3d, node2.y3d, node2.z3d)
        
        -- Calculate average depth for connection
        local avg_depth = (z1_3d + z2_3d) / 2
        
        -- Apply depth-based alpha and width scaling
        local depth_alpha = math.max(0.1, 1.0 / (1.0 + avg_depth * 0.2))
        local depth_width = conn.width * math.max(0.3, depth_alpha)
        
        -- Set color with depth-based transparency
        love.graphics.setColor(conn.color[1], conn.color[2], conn.color[3], depth_alpha)
        love.graphics.setLineWidth(depth_width)
        
        -- Draw connection line
        love.graphics.line(x1_2d, y1_2d, x2_2d, y2_2d)
    end
    
    love.graphics.setLineWidth(1)
end

function Stereo3DRenderer:draw_nodes()
    -- Sort nodes by depth (far to near) for proper rendering order
    local sorted_nodes = {}
    for i, node in ipairs(self.nodes) do
        local x2d, y2d, z3d = self:project_3d_to_2d(node.x3d, node.y3d, node.z3d)
        table.insert(sorted_nodes, {
            index = i,
            node = node,
            x2d = x2d,
            y2d = y2d,
            z3d = z3d
        })
    end
    
    table.sort(sorted_nodes, function(a, b) return a.z3d > b.z3d end)
    
    -- Draw nodes from far to near
    for _, sorted_node in ipairs(sorted_nodes) do
        local node = sorted_node.node
        local x2d, y2d, z3d = sorted_node.x2d, sorted_node.y2d, sorted_node.z3d
        
        -- Calculate size and alpha based on depth
        local icon_size = self:calculate_icon_size(z3d)
        local depth_alpha = math.max(0.2, 1.0 / (1.0 + math.abs(z3d) * 0.15))
        
        -- Choose color based on activation and type
        local color = self.colors.node_core
        if node.activation > 0.7 then
            color = self.colors.node_active
        end
        
        -- Add pulsing effect for active nodes
        local pulse_factor = 1.0
        if node.activation > 0.6 then
            pulse_factor = 1.0 + 0.3 * math.sin(self.animation_time * self.pulse_frequency)
        end
        
        -- Set font size based on icon size
        local font_size = math.floor(icon_size * pulse_factor)
        local font = love.graphics.newFont(font_size)
        love.graphics.setFont(font)
        
        -- Draw node icon
        love.graphics.setColor(color[1], color[2], color[3], depth_alpha)
        love.graphics.print(node.icon, x2d - font_size/4, y2d - font_size/2)
        
        -- Draw subtle glow for active nodes
        if node.activation > 0.8 then
            love.graphics.setColor(color[1], color[2], color[3], depth_alpha * 0.3)
            for i = 1, 3 do
                love.graphics.print(node.icon, 
                    x2d - font_size/4 + i, y2d - font_size/2,
                    0, 1.1, 1.1)
            end
        end
    end
end

function Stereo3DRenderer:draw_controls()
    love.graphics.setFont(love.graphics.newFont(14))
    love.graphics.setColor(0.8, 0.8, 0.8, 0.8)
    
    local control_x = self.x + 10
    local control_y = self.y + self.height - 100
    
    love.graphics.print("3D Controls:", control_x, control_y)
    love.graphics.print("R: Rotate  |  A: Auto-rotate  |  Mouse: Drag to rotate", 
                       control_x, control_y + 20)
    love.graphics.print(string.format("Rotation Y: %.1f°", math.deg(self.camera.rotation_y)), 
                       control_x, control_y + 40)
    love.graphics.print(string.format("Auto-rotate: %s", self.auto_rotate and "ON" or "OFF"), 
                       control_x, control_y + 60)
end
-- }}}

-- {{{ Input Handling
function Stereo3DRenderer:mouse_pressed(x, y, button)
    if button == 1 and x >= self.x and x <= self.x + self.width and 
       y >= self.y and y <= self.y + self.height then
        self.mouse_dragging = true
        self.last_mouse_x = x
        self.last_mouse_y = y
        return true
    end
    return false
end

function Stereo3DRenderer:mouse_moved(x, y)
    if self.mouse_dragging then
        local dx = x - self.last_mouse_x
        local dy = y - self.last_mouse_y
        
        -- Convert mouse movement to rotation
        self.target_rotation_y = self.target_rotation_y + dx * 0.01
        self.camera.rotation_x = math.max(-math.pi/3, 
                                 math.min(math.pi/3, 
                                 self.camera.rotation_x - dy * 0.01))
        
        self.last_mouse_x = x
        self.last_mouse_y = y
        self.auto_rotate = false  -- Disable auto-rotate when manually controlling
    end
end

function Stereo3DRenderer:mouse_released(x, y, button)
    if button == 1 then
        self.mouse_dragging = false
        return true
    end
    return false
end

function Stereo3DRenderer:key_pressed(key)
    if key == "r" then
        -- Manual rotation step
        self.target_rotation_y = self.target_rotation_y + math.pi / 8
        self.auto_rotate = false
    elseif key == "a" then
        -- Toggle auto-rotation
        self.auto_rotate = not self.auto_rotate
    elseif key == "1" or key == "2" or key == "3" or key == "4" then
        -- Set rotation direction
        local directions = {
            ["1"] = 0,     -- Stop
            ["2"] = 1,     -- Forward
            ["3"] = -1,    -- Reverse
            ["4"] = 0.5    -- Slow
        }
        self.rotation_direction = directions[key]
        self.rotation_speed = (key == "4") and 0.01 or 0.02
    end
end
-- }}}

-- {{{ Utility Functions
function Stereo3DRenderer:set_bounds(x, y, width, height)
    self.x = x
    self.y = y
    self.width = width
    self.height = height
end

function Stereo3DRenderer:reset_view()
    self.camera.rotation_x = 0
    self.camera.rotation_y = 0
    self.target_rotation_y = 0
    self.auto_rotate = false
end

function Stereo3DRenderer:set_auto_rotate(enabled, speed)
    self.auto_rotate = enabled
    if speed then
        self.rotation_speed = speed
    end
end

function Stereo3DRenderer:get_stats()
    return {
        node_count = #self.nodes,
        connection_count = #self.connections,
        rotation_y = self.camera.rotation_y,
        auto_rotate = self.auto_rotate
    }
end
-- }}}

return Stereo3DRenderer
-- }}}