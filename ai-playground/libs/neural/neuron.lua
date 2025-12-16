-- {{{ Neuron class
-- Individual neuron implementation for neural networks

local ActivationFunctions = require('libs/neural/activation_functions')
local Matrix = require('libs/math/matrix')
local ComputationGraph = require('libs/neural/computation_graph')

local Neuron = {}
Neuron.__index = Neuron

-- {{{ Neuron constructor
function Neuron:new(input_size, activation_function, bias)
    local obj = {
        input_size = input_size or 1,
        weights = Matrix.random(1, input_size or 1, -1, 1),
        bias = bias or (math.random() * 2 - 1),
        activation_function = activation_function or "sigmoid",
        last_input = nil,
        last_output = nil,
        last_weighted_sum = nil,
        
        -- Computation graph tracking
        computation_graph = nil,
        input_nodes = {},
        weight_nodes = {},
        bias_node = nil,
        weighted_sum_node = nil,
        activation_node = nil,
        
        -- For visualization
        x = 0,
        y = 0,
        id = math.random(1000000)
    }
    
    setmetatable(obj, self)
    return obj
end
-- }}}

-- {{{ Weight and bias management
function Neuron:get_weight(index)
    if index < 1 or index > self.input_size then
        error("Weight index out of bounds")
    end
    return self.weights:get(1, index)
end

function Neuron:set_weight(index, value)
    if index < 1 or index > self.input_size then
        error("Weight index out of bounds")
    end
    self.weights:set(1, index, value)
end

function Neuron:get_all_weights()
    local weights = {}
    for i = 1, self.input_size do
        weights[i] = self.weights:get(1, i)
    end
    return weights
end

function Neuron:set_all_weights(weights)
    if #weights ~= self.input_size then
        error("Weight array size must match input size")
    end
    for i = 1, self.input_size do
        self.weights:set(1, i, weights[i])
    end
end

function Neuron:get_bias()
    return self.bias
end

function Neuron:set_bias(value)
    self.bias = value
end

function Neuron:randomize_weights(min, max)
    min = min or -1
    max = max or 1
    for i = 1, self.input_size do
        self.weights:set(1, i, min + (max - min) * math.random())
    end
    self.bias = min + (max - min) * math.random()
end
-- }}}

-- {{{ Activation function management
function Neuron:set_activation_function(name)
    if not ActivationFunctions.exists(name) then
        error("Unknown activation function: " .. tostring(name))
    end
    self.activation_function = name
end

function Neuron:get_activation_function()
    return self.activation_function
end
-- }}}

-- {{{ Computation graph methods
function Neuron:set_computation_graph(graph)
    self.computation_graph = graph
end

function Neuron:get_computation_graph()
    return self.computation_graph
end

function Neuron:clear_computation_nodes()
    self.input_nodes = {}
    self.weight_nodes = {}
    self.bias_node = nil
    self.weighted_sum_node = nil
    self.activation_node = nil
end
-- }}}

-- {{{ Forward propagation with graph tracking
function Neuron:forward_with_graph(inputs, layer_idx, neuron_idx)
    if not self.computation_graph then
        return self:forward(inputs)
    end
    
    local graph = self.computation_graph
    self:clear_computation_nodes()
    
    -- Convert inputs to array if needed
    local input_array
    if type(inputs) == "table" then
        input_array = inputs
    else
        -- Convert matrix to array
        input_array = {}
        for i = 1, self.input_size do
            input_array[i] = inputs:get(i, 1)
        end
    end
    
    -- Create input nodes
    for i = 1, #input_array do
        local input_node = graph:create_input_node(input_array[i], {
            input_index = i,
            layer = layer_idx,
            neuron = neuron_idx,
            type = "neuron_input"
        })
        table.insert(self.input_nodes, input_node)
    end
    
    -- Create weight nodes
    for i = 1, self.input_size do
        local weight_node = graph:create_weight_node(self:get_weight(i), {
            weight_index = i,
            layer = layer_idx,
            neuron = neuron_idx,
            type = "neuron_weight"
        })
        table.insert(self.weight_nodes, weight_node)
    end
    
    -- Create bias node
    self.bias_node = graph:create_bias_node(self.bias, {
        layer = layer_idx,
        neuron = neuron_idx,
        type = "neuron_bias"
    })
    
    -- Create multiplication nodes (input * weight)
    local multiply_nodes = {}
    for i = 1, self.input_size do
        local multiply_node = graph:create_multiply_node(
            self.input_nodes[i], 
            self.weight_nodes[i],
            {
                operation_index = i,
                layer = layer_idx,
                neuron = neuron_idx,
                type = "weight_multiply"
            }
        )
        table.insert(multiply_nodes, multiply_node)
    end
    
    -- Create weighted sum node (sum of all products + bias)
    local sum_inputs = {}
    for _, mult_node in ipairs(multiply_nodes) do
        table.insert(sum_inputs, mult_node)
    end
    table.insert(sum_inputs, self.bias_node)
    
    self.weighted_sum_node = graph:create_add_node(sum_inputs, {
        layer = layer_idx,
        neuron = neuron_idx,
        type = "weighted_sum"
    })
    
    -- Create activation node
    self.activation_node = graph:create_activation_node(
        self.weighted_sum_node, 
        self.activation_function,
        {
            layer = layer_idx,
            neuron = neuron_idx,
            type = "neuron_output"
        }
    )
    
    -- Store values for traditional access
    self.last_input = Matrix.from_array(input_array, #input_array, 1)
    self.last_weighted_sum = self.weighted_sum_node.value
    self.last_output = self.activation_node.value
    
    return self.last_output
end
-- }}}

-- {{{ Forward propagation
function Neuron:forward(inputs)
    -- Convert inputs to matrix if needed
    local input_matrix
    if type(inputs) == "table" then
        if #inputs ~= self.input_size then
            error(string.format("Input size mismatch: expected %d, got %d", 
                  self.input_size, #inputs))
        end
        input_matrix = Matrix.from_array(inputs, #inputs, 1)
    else
        input_matrix = inputs -- Assume it's already a matrix
    end
    
    -- Store input for backpropagation
    self.last_input = input_matrix:copy()
    
    -- Calculate weighted sum: w * x + b
    self.last_weighted_sum = (self.weights:multiply(input_matrix)):get(1, 1) + self.bias
    
    -- Apply activation function
    self.last_output = ActivationFunctions.apply(self.activation_function, self.last_weighted_sum)
    
    return self.last_output
end

function Neuron:get_weighted_sum()
    return self.last_weighted_sum
end

function Neuron:get_last_output()
    return self.last_output
end

function Neuron:get_last_input()
    return self.last_input
end
-- }}}

-- {{{ Backpropagation support
function Neuron:compute_gradient(output_gradient)
    if not self.last_weighted_sum then
        error("Cannot compute gradient: no forward pass recorded")
    end
    
    -- Compute activation derivative
    local activation_derivative = ActivationFunctions.apply_derivative(
        self.activation_function, 
        self.last_weighted_sum
    )
    
    -- Local gradient = output_gradient * activation_derivative
    local local_gradient = output_gradient * activation_derivative
    
    -- Weight gradients = local_gradient * input
    local weight_gradients = {}
    for i = 1, self.input_size do
        weight_gradients[i] = local_gradient * self.last_input:get(i, 1)
    end
    
    -- Bias gradient = local_gradient
    local bias_gradient = local_gradient
    
    -- Input gradients = local_gradient * weights (for previous layer)
    local input_gradients = {}
    for i = 1, self.input_size do
        input_gradients[i] = local_gradient * self.weights:get(1, i)
    end
    
    return {
        weight_gradients = weight_gradients,
        bias_gradient = bias_gradient,
        input_gradients = input_gradients,
        local_gradient = local_gradient
    }
end

function Neuron:update_weights(weight_gradients, bias_gradient, learning_rate)
    learning_rate = learning_rate or 0.01
    
    -- Update weights
    for i = 1, self.input_size do
        local current_weight = self.weights:get(1, i)
        local new_weight = current_weight - learning_rate * weight_gradients[i]
        self.weights:set(1, i, new_weight)
    end
    
    -- Update bias
    self.bias = self.bias - learning_rate * bias_gradient
end
-- }}}

-- {{{ Position management for visualization
function Neuron:set_position(x, y)
    self.x = x
    self.y = y
end

function Neuron:get_position()
    return self.x, self.y
end

function Neuron:get_id()
    return self.id
end
-- }}}

-- {{{ Utility methods
function Neuron:copy()
    local new_neuron = Neuron:new(self.input_size, self.activation_function, self.bias)
    
    -- Copy weights
    for i = 1, self.input_size do
        new_neuron.weights:set(1, i, self.weights:get(1, i))
    end
    
    -- Copy position
    new_neuron.x = self.x
    new_neuron.y = self.y
    
    return new_neuron
end

function Neuron:get_state()
    return {
        input_size = self.input_size,
        weights = self:get_all_weights(),
        bias = self.bias,
        activation_function = self.activation_function,
        last_output = self.last_output,
        last_weighted_sum = self.last_weighted_sum,
        position = {x = self.x, y = self.y}
    }
end

function Neuron:load_state(state)
    self.input_size = state.input_size
    self:set_all_weights(state.weights)
    self.bias = state.bias
    self.activation_function = state.activation_function
    self.last_output = state.last_output
    self.last_weighted_sum = state.last_weighted_sum
    if state.position then
        self.x = state.position.x
        self.y = state.position.y
    end
end

function Neuron:print()
    print(string.format("Neuron (ID: %d)", self.id))
    print(string.format("  Input size: %d", self.input_size))
    print(string.format("  Activation: %s", self.activation_function))
    print(string.format("  Bias: %.3f", self.bias))
    print("  Weights: [" .. table.concat(self:get_all_weights(), ", ") .. "]")
    if self.last_output then
        print(string.format("  Last output: %.3f", self.last_output))
    end
    if self.last_weighted_sum then
        print(string.format("  Last weighted sum: %.3f", self.last_weighted_sum))
    end
end
-- }}}

return Neuron
-- }}}