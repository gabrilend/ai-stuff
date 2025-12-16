-- {{{ Network class
-- Neural network implementation with layer management

local Neuron = require('libs/neural/neuron')
local Matrix = require('libs/math/matrix')
local ComputationGraph = require('libs/neural/computation_graph')

local Network = {}
Network.__index = Network

-- {{{ Network constructor
function Network:new()
    local obj = {
        layers = {},
        layer_sizes = {},
        output_history = {},
        training_data = {},
        loss_history = {},
        learning_rate = 0.01,
        
        -- Computation graph tracking
        computation_graph = nil,
        track_computation = false,
        last_loss_node = nil,
        gradient_flow_paths = {},
        decision_tree = {}
    }
    
    setmetatable(obj, self)
    return obj
end
-- }}}

-- {{{ Layer management
function Network:add_layer(size, activation_function)
    activation_function = activation_function or "sigmoid"
    local layer_index = #self.layers + 1
    
    -- Determine input size for this layer
    local input_size = 1
    if layer_index > 1 then
        input_size = self.layer_sizes[layer_index - 1]
    end
    
    -- Create neurons for this layer
    local layer = {}
    for i = 1, size do
        local neuron = Neuron:new(input_size, activation_function)
        table.insert(layer, neuron)
    end
    
    table.insert(self.layers, layer)
    table.insert(self.layer_sizes, size)
    
    -- Update input size for existing neurons if this is the first hidden layer
    if layer_index == 2 and #self.layers >= 1 then
        local first_layer = self.layers[1]
        for _, neuron in ipairs(first_layer) do
            -- This is the input layer, no weight updates needed
        end
    end
    
    return layer_index
end

function Network:get_layer(index)
    if index < 1 or index > #self.layers then
        error("Layer index out of bounds")
    end
    return self.layers[index]
end

function Network:get_layer_count()
    return #self.layers
end

function Network:get_layer_size(index)
    if index < 1 or index > #self.layer_sizes then
        error("Layer index out of bounds")
    end
    return self.layer_sizes[index]
end

function Network:get_neuron(layer_index, neuron_index)
    local layer = self:get_layer(layer_index)
    if neuron_index < 1 or neuron_index > #layer then
        error("Neuron index out of bounds")
    end
    return layer[neuron_index]
end
-- }}}

-- {{{ Network topology
function Network:get_topology()
    return table.unpack(self.layer_sizes)
end

function Network:validate_topology()
    if #self.layers == 0 then
        return false, "Network has no layers"
    end
    
    if #self.layers == 1 then
        return false, "Network must have at least input and output layers"
    end
    
    -- Check that each layer has the correct input size
    for i = 2, #self.layers do
        local layer = self.layers[i]
        local expected_input_size = self.layer_sizes[i - 1]
        
        for _, neuron in ipairs(layer) do
            if neuron.input_size ~= expected_input_size then
                return false, string.format("Layer %d neuron has wrong input size: expected %d, got %d", 
                    i, expected_input_size, neuron.input_size)
            end
        end
    end
    
    return true, "Network topology is valid"
end
-- }}}

-- {{{ Computation graph methods
function Network:enable_computation_tracking(enable)
    self.track_computation = enable
    if enable then
        self.computation_graph = ComputationGraph:new()
        -- Set computation graph for all neurons
        for layer_index = 2, #self.layers do
            local layer = self.layers[layer_index]
            for _, neuron in ipairs(layer) do
                neuron:set_computation_graph(self.computation_graph)
            end
        end
    else
        self.computation_graph = nil
        -- Clear computation graph from neurons
        for layer_index = 2, #self.layers do
            local layer = self.layers[layer_index]
            for _, neuron in ipairs(layer) do
                neuron:set_computation_graph(nil)
            end
        end
    end
end

function Network:get_computation_graph()
    return self.computation_graph
end

function Network:get_decision_tree()
    if self.computation_graph then
        self.decision_tree = self.computation_graph:get_decision_tree()
    end
    return self.decision_tree
end

function Network:get_gradient_flow_paths()
    if self.computation_graph then
        self.gradient_flow_paths = self.computation_graph:get_gradient_flow_paths()
    end
    return self.gradient_flow_paths
end

function Network:get_gradient_contributions()
    if self.computation_graph then
        return self.computation_graph:get_gradient_contributions()
    end
    return {}
end
-- }}}

-- {{{ Enhanced forward propagation with graph tracking
function Network:forward_with_graph(inputs)
    if #self.layers == 0 then
        error("Cannot run forward pass: network has no layers")
    end
    
    -- Clear previous computation graph if tracking
    if self.track_computation and self.computation_graph then
        self.computation_graph:clear()
    end
    
    local current_inputs = inputs
    local layer_outputs = {}
    
    for layer_index = 1, #self.layers do
        local layer = self.layers[layer_index]
        local layer_output = {}
        
        if layer_index == 1 then
            -- Input layer: just pass through the inputs
            layer_output = current_inputs
        else
            -- Hidden/output layers: compute neuron outputs with graph tracking
            for neuron_index, neuron in ipairs(layer) do
                local output
                if self.track_computation then
                    output = neuron:forward_with_graph(current_inputs, layer_index, neuron_index)
                else
                    output = neuron:forward(current_inputs)
                end
                table.insert(layer_output, output)
            end
        end
        
        layer_outputs[layer_index] = layer_output
        current_inputs = layer_output
    end
    
    -- Store the outputs for inspection
    self.last_layer_outputs = layer_outputs
    
    return layer_outputs[#layer_outputs] -- Return final output
end
-- }}}

-- {{{ Forward propagation
function Network:forward(inputs)
    if #self.layers == 0 then
        error("Cannot run forward pass: network has no layers")
    end
    
    local current_inputs = inputs
    local layer_outputs = {}
    
    for layer_index = 1, #self.layers do
        local layer = self.layers[layer_index]
        local layer_output = {}
        
        if layer_index == 1 then
            -- Input layer: just pass through the inputs
            layer_output = current_inputs
        else
            -- Hidden/output layers: compute neuron outputs
            for neuron_index, neuron in ipairs(layer) do
                local output = neuron:forward(current_inputs)
                table.insert(layer_output, output)
            end
        end
        
        layer_outputs[layer_index] = layer_output
        current_inputs = layer_output
    end
    
    -- Store the outputs for inspection
    self.last_layer_outputs = layer_outputs
    
    return layer_outputs[#layer_outputs] -- Return final output
end

function Network:get_layer_outputs()
    return self.last_layer_outputs
end

function Network:get_output()
    if self.last_layer_outputs then
        return self.last_layer_outputs[#self.last_layer_outputs]
    end
    return nil
end
-- }}}

-- {{{ Training support
function Network:set_learning_rate(rate)
    self.learning_rate = rate
end

function Network:get_learning_rate()
    return self.learning_rate
end

function Network:compute_loss(predicted, target, loss_function)
    loss_function = loss_function or "mse"
    
    if #predicted ~= #target then
        error("Predicted and target output sizes must match")
    end
    
    if loss_function == "mse" then
        -- Mean squared error
        local sum = 0
        for i = 1, #predicted do
            local diff = predicted[i] - target[i]
            sum = sum + diff * diff
        end
        return sum / #predicted
    elseif loss_function == "mae" then
        -- Mean absolute error
        local sum = 0
        for i = 1, #predicted do
            sum = sum + math.abs(predicted[i] - target[i])
        end
        return sum / #predicted
    else
        error("Unknown loss function: " .. tostring(loss_function))
    end
end

function Network:backward(target, loss_function)
    if not self.last_layer_outputs then
        error("Cannot run backward pass: no forward pass recorded")
    end
    
    loss_function = loss_function or "mse"
    local predicted = self.last_layer_outputs[#self.last_layer_outputs]
    
    -- Compute output layer gradients
    local output_gradients = {}
    for i = 1, #predicted do
        if loss_function == "mse" then
            -- dL/dy = 2 * (predicted - target) / n
            output_gradients[i] = 2 * (predicted[i] - target[i]) / #predicted
        elseif loss_function == "mae" then
            -- dL/dy = sign(predicted - target) / n
            local diff = predicted[i] - target[i]
            output_gradients[i] = (diff >= 0 and 1 or -1) / #predicted
        end
    end
    
    -- Backpropagate through all layers (except input layer)
    local layer_gradients = {}
    layer_gradients[#self.layers] = output_gradients
    
    for layer_index = #self.layers, 2, -1 do
        local layer = self.layers[layer_index]
        local current_gradients = layer_gradients[layer_index]
        local previous_gradients = {}
        
        -- Initialize previous layer gradients
        if layer_index > 2 then
            for i = 1, self.layer_sizes[layer_index - 1] do
                previous_gradients[i] = 0
            end
        end
        
        -- Process each neuron in current layer
        for neuron_index, neuron in ipairs(layer) do
            local gradient_info = neuron:compute_gradient(current_gradients[neuron_index])
            
            -- Update neuron weights and bias
            neuron:update_weights(
                gradient_info.weight_gradients,
                gradient_info.bias_gradient,
                self.learning_rate
            )
            
            -- Accumulate gradients for previous layer
            if layer_index > 2 then
                for i = 1, #gradient_info.input_gradients do
                    previous_gradients[i] = previous_gradients[i] + gradient_info.input_gradients[i]
                end
            end
        end
        
        if layer_index > 2 then
            layer_gradients[layer_index - 1] = previous_gradients
        end
    end
    
    return layer_gradients
end

-- {{{ Enhanced training with computation graph
function Network:train_step_with_graph(inputs, targets, loss_function)
    loss_function = loss_function or "mse"
    
    -- Forward pass with graph tracking
    local predicted = self:forward_with_graph(inputs)
    local loss = self:compute_loss(predicted, targets, loss_function)
    
    -- Create loss node in computation graph
    if self.track_computation and self.computation_graph then
        -- Get output nodes from the last layer
        local output_nodes = {}
        local last_layer = self.layers[#self.layers]
        for _, neuron in ipairs(last_layer) do
            if neuron.activation_node then
                table.insert(output_nodes, neuron.activation_node)
            end
        end
        
        -- Create loss node
        self.last_loss_node = self.computation_graph:create_loss_node(
            output_nodes,
            targets,
            loss_function,
            {type = "network_loss"}
        )
        
        -- Run comprehensive backward pass
        self:backward_with_graph()
        
        -- Update decision tree and gradient paths
        self.decision_tree = self.computation_graph:get_decision_tree()
        self.gradient_flow_paths = self.computation_graph:get_gradient_flow_paths()
    else
        -- Standard backward pass
        self:backward(targets, loss_function)
    end
    
    table.insert(self.loss_history, loss)
    
    return loss, predicted
end

function Network:backward_with_graph()
    if not self.computation_graph or not self.last_loss_node then
        error("No computation graph or loss node available for backward pass")
    end
    
    -- Run comprehensive backward pass
    self.computation_graph:backward_pass(self.last_loss_node)
    
    -- Update neuron weights using gradients from computation graph
    for layer_index = 2, #self.layers do
        local layer = self.layers[layer_index]
        for _, neuron in ipairs(layer) do
            if neuron.weight_nodes and neuron.bias_node then
                -- Update weights using gradients from computation graph
                local weight_gradients = {}
                for i, weight_node in ipairs(neuron.weight_nodes) do
                    weight_gradients[i] = weight_node:get_gradient()
                end
                
                local bias_gradient = neuron.bias_node:get_gradient()
                
                -- Apply updates
                neuron:update_weights(weight_gradients, bias_gradient, self.learning_rate)
            end
        end
    end
end

function Network:get_comprehensive_backward_info()
    if not self.computation_graph then
        return nil
    end
    
    return {
        decision_tree = self:get_decision_tree(),
        gradient_flow_paths = self:get_gradient_flow_paths(),
        gradient_contributions = self:get_gradient_contributions(),
        computation_stats = self.computation_graph:get_stats()
    }
end
-- }}}

function Network:train_step(inputs, targets, loss_function)
    if self.track_computation then
        return self:train_step_with_graph(inputs, targets, loss_function)
    else
        local predicted = self:forward(inputs)
        local loss = self:compute_loss(predicted, targets, loss_function)
        self:backward(targets, loss_function)
        
        table.insert(self.loss_history, loss)
        
        return loss, predicted
    end
end
-- }}}

-- {{{ Utility methods
function Network:randomize_weights(min, max)
    for layer_index = 2, #self.layers do -- Skip input layer
        local layer = self.layers[layer_index]
        for _, neuron in ipairs(layer) do
            neuron:randomize_weights(min, max)
        end
    end
end

function Network:get_total_parameters()
    local total = 0
    for layer_index = 2, #self.layers do -- Skip input layer
        local layer = self.layers[layer_index]
        for _, neuron in ipairs(layer) do
            total = total + neuron.input_size + 1 -- weights + bias
        end
    end
    return total
end

function Network:print()
    print("Neural Network:")
    print(string.format("  Layers: %d", #self.layers))
    print(string.format("  Topology: [%s]", table.concat(self.layer_sizes, ", ")))
    print(string.format("  Total parameters: %d", self:get_total_parameters()))
    print(string.format("  Learning rate: %.4f", self.learning_rate))
    
    for layer_index = 1, #self.layers do
        print(string.format("  Layer %d: %d neurons", layer_index, self.layer_sizes[layer_index]))
        if layer_index > 1 then
            local layer = self.layers[layer_index]
            local activation = layer[1] and layer[1]:get_activation_function() or "none"
            print(string.format("    Activation: %s", activation))
        end
    end
end

function Network:copy()
    local new_network = Network:new()
    
    -- Copy layer structure and neurons
    for layer_index = 1, #self.layers do
        local layer_size = self.layer_sizes[layer_index]
        local activation = "sigmoid"
        
        if layer_index > 1 and #self.layers[layer_index] > 0 then
            activation = self.layers[layer_index][1]:get_activation_function()
        end
        
        new_network:add_layer(layer_size, activation)
        
        -- Copy neuron weights and biases
        if layer_index > 1 then
            local original_layer = self.layers[layer_index]
            local new_layer = new_network.layers[layer_index]
            
            for i = 1, #original_layer do
                local original_neuron = original_layer[i]
                local new_neuron = new_layer[i]
                
                new_neuron:set_all_weights(original_neuron:get_all_weights())
                new_neuron:set_bias(original_neuron:get_bias())
            end
        end
    end
    
    new_network.learning_rate = self.learning_rate
    
    return new_network
end
-- }}}

-- {{{ Serialization
function Network:get_state()
    local state = {
        layer_sizes = {},
        layer_data = {},
        learning_rate = self.learning_rate
    }
    
    -- Copy layer sizes
    for i = 1, #self.layer_sizes do
        state.layer_sizes[i] = self.layer_sizes[i]
    end
    
    -- Copy neuron data (skip input layer)
    for layer_index = 2, #self.layers do
        local layer = self.layers[layer_index]
        local layer_data = {
            activation_function = layer[1] and layer[1]:get_activation_function() or "sigmoid",
            neurons = {}
        }
        
        for neuron_index, neuron in ipairs(layer) do
            table.insert(layer_data.neurons, neuron:get_state())
        end
        
        state.layer_data[layer_index] = layer_data
    end
    
    return state
end

function Network:load_state(state)
    -- Clear existing network
    self.layers = {}
    self.layer_sizes = {}
    
    -- Recreate layers
    for i = 1, #state.layer_sizes do
        local activation = "sigmoid"
        if state.layer_data[i] then
            activation = state.layer_data[i].activation_function
        end
        self:add_layer(state.layer_sizes[i], activation)
    end
    
    -- Load neuron data
    for layer_index = 2, #self.layers do
        if state.layer_data[layer_index] then
            local layer_data = state.layer_data[layer_index]
            local layer = self.layers[layer_index]
            
            for neuron_index, neuron_state in ipairs(layer_data.neurons) do
                if layer[neuron_index] then
                    layer[neuron_index]:load_state(neuron_state)
                end
            end
        end
    end
    
    self.learning_rate = state.learning_rate or 0.01
end
-- }}}

return Network
-- }}}