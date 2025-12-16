-- {{{ Computation Graph
-- Tracks computation flow and gradient pathways for visualization

local ComputationGraph = {}
ComputationGraph.__index = ComputationGraph

-- {{{ ComputationNode class
local ComputationNode = {}
ComputationNode.__index = ComputationNode

-- {{{ ComputationNode constructor
function ComputationNode:new(operation, value, inputs, metadata)
    local obj = {
        id = string.format("node_%d_%d", math.random(1000000), os.clock() * 1000000),
        operation = operation or "value",  -- "input", "weight_sum", "activation", "loss", etc.
        value = value or 0,
        gradient = 0,
        inputs = inputs or {},  -- Parent nodes
        outputs = {},  -- Child nodes
        metadata = metadata or {},  -- Additional info (neuron_id, layer, etc.)
        
        -- For visualization
        x = 0,
        y = 0,
        visited = false,
        gradient_path = {},  -- Track gradient flow path
        contribution_weights = {}  -- Track how much each input contributes
    }
    
    setmetatable(obj, self)
    
    -- Register this node as output for all input nodes
    if inputs then
        for _, input_node in ipairs(inputs) do
            table.insert(input_node.outputs, obj)
        end
    end
    
    return obj
end
-- }}}

-- {{{ ComputationNode gradient methods
function ComputationNode:set_gradient(grad)
    self.gradient = grad
end

function ComputationNode:accumulate_gradient(grad)
    self.gradient = self.gradient + grad
end

function ComputationNode:get_gradient()
    return self.gradient
end

function ComputationNode:reset_gradient()
    self.gradient = 0
    self.visited = false
    self.gradient_path = {}
end

function ComputationNode:add_gradient_path_step(from_node, local_grad, operation_desc)
    table.insert(self.gradient_path, {
        from_node = from_node,
        local_gradient = local_grad,
        operation = operation_desc,
        timestamp = os.clock()
    })
end
-- }}}

-- {{{ ComputationNode utility methods
function ComputationNode:get_info()
    return {
        id = self.id,
        operation = self.operation,
        value = self.value,
        gradient = self.gradient,
        input_count = #self.inputs,
        output_count = #self.outputs,
        metadata = self.metadata
    }
end

function ComputationNode:print_info()
    print(string.format("Node %s (%s): value=%.4f, grad=%.4f", 
        self.id, self.operation, self.value, self.gradient))
end
-- }}}
-- }}}

-- {{{ ComputationGraph constructor
function ComputationGraph:new()
    local obj = {
        nodes = {},
        root_nodes = {},  -- Input nodes
        leaf_nodes = {},  -- Output nodes
        operation_sequence = {},  -- Forward pass sequence
        gradient_sequence = {},  -- Backward pass sequence
        
        -- Tree structure for visualization
        layers = {},  -- nodes organized by computational layer
        max_depth = 0
    }
    
    setmetatable(obj, self)
    return obj
end
-- }}}

-- {{{ Graph construction methods
function ComputationGraph:create_node(operation, value, inputs, metadata)
    local node = ComputationNode:new(operation, value, inputs, metadata)
    table.insert(self.nodes, node)
    table.insert(self.operation_sequence, node)
    
    -- Track root and leaf nodes
    if not inputs or #inputs == 0 then
        table.insert(self.root_nodes, node)
    end
    
    return node
end

function ComputationGraph:create_input_node(value, metadata)
    return self:create_node("input", value, nil, metadata)
end

function ComputationGraph:create_weight_node(weight, metadata)
    return self:create_node("weight", weight, nil, metadata)
end

function ComputationGraph:create_bias_node(bias, metadata)
    return self:create_node("bias", bias, nil, metadata)
end

function ComputationGraph:create_multiply_node(input1, input2, metadata)
    local value = input1.value * input2.value
    return self:create_node("multiply", value, {input1, input2}, metadata)
end

function ComputationGraph:create_add_node(inputs, metadata)
    local value = 0
    for _, input in ipairs(inputs) do
        value = value + input.value
    end
    return self:create_node("add", value, inputs, metadata)
end

function ComputationGraph:create_activation_node(input, activation_func, metadata)
    local ActivationFunctions = require('libs/neural/activation_functions')
    local value = ActivationFunctions.apply(activation_func, input.value)
    local meta = metadata or {}
    meta.activation_function = activation_func
    return self:create_node("activation", value, {input}, meta)
end

function ComputationGraph:create_loss_node(predicted, target, loss_func, metadata)
    local value = 0
    if loss_func == "mse" then
        for i = 1, #predicted do
            local diff = predicted[i].value - target[i]
            value = value + diff * diff
        end
        value = value / #predicted
    end
    
    local meta = metadata or {}
    meta.loss_function = loss_func
    meta.target = target
    return self:create_node("loss", value, predicted, meta)
end
-- }}}

-- {{{ Graph analysis methods
function ComputationGraph:organize_by_layers()
    self.layers = {}
    self.max_depth = 0
    
    -- Reset all nodes
    for _, node in ipairs(self.nodes) do
        node.visited = false
    end
    
    -- Assign layers using topological ordering
    local function assign_layer(node, depth)
        if node.visited then
            return
        end
        
        node.visited = true
        node.layer = depth
        self.max_depth = math.max(self.max_depth, depth)
        
        if not self.layers[depth] then
            self.layers[depth] = {}
        end
        table.insert(self.layers[depth], node)
        
        -- Recursively assign layers to outputs
        for _, output in ipairs(node.outputs) do
            assign_layer(output, depth + 1)
        end
    end
    
    -- Start from root nodes
    for _, root in ipairs(self.root_nodes) do
        assign_layer(root, 1)
    end
end

function ComputationGraph:get_gradient_flow_paths()
    local paths = {}
    
    -- Find all paths from leaf to root nodes during backward pass
    local function trace_path(node, current_path)
        local new_path = {}
        for _, step in ipairs(current_path) do
            table.insert(new_path, step)
        end
        table.insert(new_path, node)
        
        if #node.inputs == 0 then
            -- Reached a root node, save the complete path
            table.insert(paths, new_path)
        else
            -- Continue tracing through inputs
            for _, input in ipairs(node.inputs) do
                trace_path(input, new_path)
            end
        end
    end
    
    -- Start tracing from leaf nodes
    for _, node in ipairs(self.nodes) do
        if #node.outputs == 0 then
            trace_path(node, {})
        end
    end
    
    return paths
end

function ComputationGraph:get_decision_tree()
    self:organize_by_layers()
    
    local tree = {
        layers = self.layers,
        max_depth = self.max_depth,
        root_nodes = self.root_nodes,
        leaf_nodes = {},
        connections = {}
    }
    
    -- Find leaf nodes
    for _, node in ipairs(self.nodes) do
        if #node.outputs == 0 then
            table.insert(tree.leaf_nodes, node)
        end
    end
    
    -- Build connection map for visualization
    for _, node in ipairs(self.nodes) do
        tree.connections[node.id] = {
            inputs = {},
            outputs = {}
        }
        
        for _, input in ipairs(node.inputs) do
            table.insert(tree.connections[node.id].inputs, input.id)
        end
        
        for _, output in ipairs(node.outputs) do
            table.insert(tree.connections[node.id].outputs, output.id)
        end
    end
    
    return tree
end
-- }}}

-- {{{ Backward pass methods
function ComputationGraph:backward_pass(loss_node)
    -- Reset gradients
    for _, node in ipairs(self.nodes) do
        node:reset_gradient()
    end
    
    -- Initialize loss gradient
    loss_node:set_gradient(1.0)
    self.gradient_sequence = {}
    
    -- Reverse topological order for backward pass
    local function backward_node(node)
        if node.visited then
            return
        end
        
        node.visited = true
        table.insert(self.gradient_sequence, 1, node)  -- Prepend for reverse order
        
        -- Compute gradients for inputs based on operation type
        if node.operation == "multiply" then
            local input1, input2 = node.inputs[1], node.inputs[2]
            local grad1 = node.gradient * input2.value
            local grad2 = node.gradient * input1.value
            
            input1:accumulate_gradient(grad1)
            input2:accumulate_gradient(grad2)
            
            input1:add_gradient_path_step(node, grad1, "multiply_chain_rule")
            input2:add_gradient_path_step(node, grad2, "multiply_chain_rule")
            
        elseif node.operation == "add" then
            for _, input in ipairs(node.inputs) do
                input:accumulate_gradient(node.gradient)
                input:add_gradient_path_step(node, node.gradient, "add_pass_through")
            end
            
        elseif node.operation == "activation" then
            local ActivationFunctions = require('libs/neural/activation_functions')
            local activation_func = node.metadata.activation_function
            local input = node.inputs[1]
            local derivative = ActivationFunctions.apply_derivative(activation_func, input.value)
            local grad = node.gradient * derivative
            
            input:accumulate_gradient(grad)
            input:add_gradient_path_step(node, grad, "activation_derivative")
            
        elseif node.operation == "loss" then
            local loss_func = node.metadata.loss_function or "mse"
            local target = node.metadata.target
            
            if loss_func == "mse" then
                for i, input in ipairs(node.inputs) do
                    local grad = 2 * (input.value - target[i]) / #node.inputs
                    input:accumulate_gradient(grad)
                    input:add_gradient_path_step(node, grad, "mse_derivative")
                end
            end
        end
        
        -- Recursively process input nodes
        for _, input in ipairs(node.inputs) do
            backward_node(input)
        end
    end
    
    -- Start backward pass from loss node
    backward_node(loss_node)
end

function ComputationGraph:get_gradient_contributions()
    local contributions = {}
    
    for _, node in ipairs(self.nodes) do
        contributions[node.id] = {
            total_gradient = node.gradient,
            path_contributions = {},
            operation_breakdown = {}
        }
        
        -- Analyze gradient path contributions
        for _, path_step in ipairs(node.gradient_path) do
            table.insert(contributions[node.id].path_contributions, {
                from_operation = path_step.operation,
                gradient_magnitude = math.abs(path_step.local_gradient),
                gradient_direction = path_step.local_gradient >= 0 and "positive" or "negative"
            })
        end
        
        -- Group by operation type
        local ops = {}
        for _, path_step in ipairs(node.gradient_path) do
            if not ops[path_step.operation] then
                ops[path_step.operation] = {count = 0, total_magnitude = 0}
            end
            ops[path_step.operation].count = ops[path_step.operation].count + 1
            ops[path_step.operation].total_magnitude = ops[path_step.operation].total_magnitude + 
                math.abs(path_step.local_gradient)
        end
        contributions[node.id].operation_breakdown = ops
    end
    
    return contributions
end
-- }}}

-- {{{ Utility methods
function ComputationGraph:clear()
    self.nodes = {}
    self.root_nodes = {}
    self.leaf_nodes = {}
    self.operation_sequence = {}
    self.gradient_sequence = {}
    self.layers = {}
    self.max_depth = 0
end

function ComputationGraph:get_stats()
    return {
        total_nodes = #self.nodes,
        root_nodes = #self.root_nodes,
        max_depth = self.max_depth,
        total_operations = #self.operation_sequence
    }
end

function ComputationGraph:print_summary()
    local stats = self:get_stats()
    print("Computation Graph Summary:")
    print(string.format("  Total nodes: %d", stats.total_nodes))
    print(string.format("  Root nodes: %d", stats.root_nodes))
    print(string.format("  Max depth: %d", stats.max_depth))
    print(string.format("  Operations: %d", stats.total_operations))
end

function ComputationGraph:export_structure()
    local export = {
        nodes = {},
        connections = {},
        layers = self.layers,
        gradient_flow = {}
    }
    
    for _, node in ipairs(self.nodes) do
        table.insert(export.nodes, {
            id = node.id,
            operation = node.operation,
            value = node.value,
            gradient = node.gradient,
            layer = node.layer or 0,
            metadata = node.metadata
        })
    end
    
    for _, node in ipairs(self.nodes) do
        for _, output in ipairs(node.outputs) do
            table.insert(export.connections, {
                from = node.id,
                to = output.id,
                type = "forward"
            })
        end
    end
    
    return export
end
-- }}}

return ComputationGraph
-- }}}