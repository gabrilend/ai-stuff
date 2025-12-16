#!/usr/bin/env lua

-- {{{ Enhanced Backpropagation Test Demo
-- Tests the comprehensive backward pass with computation graph tracking

local DIR = arg[0] and arg[0]:match("(.*/)")
if DIR then
    package.path = DIR .. "?.lua;" .. package.path
end

-- Import libraries
local ComputationGraph = require('libs/neural/computation_graph')
local Network = require('libs/neural/network')
local Neuron = require('libs/neural/neuron')

print("=== Enhanced Backpropagation Demo ===\n")

-- {{{ Test 1: Computation Graph Basic Operations
print("1. Testing Computation Graph Basic Operations...")

local graph = ComputationGraph:new()

-- Create simple computation: (x * w + b) with activation
local input_node = graph:create_input_node(0.5, {type = "test_input"})
local weight_node = graph:create_weight_node(0.8, {type = "test_weight"})
local bias_node = graph:create_bias_node(0.2, {type = "test_bias"})

local multiply_node = graph:create_multiply_node(input_node, weight_node, {type = "test_multiply"})
local add_node = graph:create_add_node({multiply_node, bias_node}, {type = "test_add"})
local activation_node = graph:create_activation_node(add_node, "sigmoid", {type = "test_activation"})

print(string.format("Forward computation: (%.2f * %.2f + %.2f) = %.4f -> sigmoid = %.4f",
    input_node.value, weight_node.value, bias_node.value, 
    add_node.value, activation_node.value))

-- Test backward pass
local loss_node = graph:create_loss_node({activation_node}, {0.8}, "mse", {type = "test_loss"})
graph:backward_pass(loss_node)

print("Gradients after backward pass:")
print(string.format("  Input gradient: %.4f", input_node:get_gradient()))
print(string.format("  Weight gradient: %.4f", weight_node:get_gradient()))
print(string.format("  Bias gradient: %.4f", bias_node:get_gradient()))
print(string.format("  Loss: %.6f", loss_node.value))

local decision_tree = graph:get_decision_tree()
print(string.format("Decision tree: %d layers, %d max depth", 
    decision_tree.layers and #decision_tree.layers or 0, 
    decision_tree.max_depth))

local gradient_paths = graph:get_gradient_flow_paths()
print(string.format("Gradient flow paths: %d", #gradient_paths))

print("Basic computation graph test completed.\n")
-- }}}

-- {{{ Test 2: Enhanced Neuron with Graph Tracking
print("2. Testing Enhanced Neuron with Graph Tracking...")

local test_graph = ComputationGraph:new()
local enhanced_neuron = Neuron:new(3, "sigmoid")
enhanced_neuron:set_computation_graph(test_graph)
enhanced_neuron:set_all_weights({0.5, -0.3, 0.8})
enhanced_neuron:set_bias(0.2)

print("Enhanced neuron configuration:")
enhanced_neuron:print()

local test_input = {0.7, -0.2, 0.4}
local neuron_output = enhanced_neuron:forward_with_graph(test_input, 2, 1)

print(string.format("Forward with graph tracking:"))
print(string.format("  Input: [%.2f, %.2f, %.2f]", test_input[1], test_input[2], test_input[3]))
print(string.format("  Output: %.4f", neuron_output))
print(string.format("  Weighted sum: %.4f", enhanced_neuron:get_weighted_sum()))

-- Check graph nodes created
local graph_stats = test_graph:get_stats()
print(string.format("Graph nodes created: %d", graph_stats.total_nodes))

print("Enhanced neuron test completed.\n")
-- }}}

-- {{{ Test 3: Enhanced Network Training with Computation Tracking
print("3. Testing Enhanced Network Training...")

local enhanced_network = Network:new()
enhanced_network:add_layer(2)  -- Input layer
enhanced_network:add_layer(3, "sigmoid")  -- Hidden layer
enhanced_network:add_layer(1, "sigmoid")  -- Output layer

enhanced_network:randomize_weights(-1, 1)
enhanced_network:set_learning_rate(0.1)

print("Enhanced network architecture:")
enhanced_network:print()

-- Enable computation tracking
enhanced_network:enable_computation_tracking(true)
print("Computation tracking enabled.")

-- Training data
local train_input = {0.6, -0.4}
local train_target = {0.8}

print("\nTraining step with computation graph tracking:")
print(string.format("Input: [%.2f, %.2f], Target: [%.2f]", 
    train_input[1], train_input[2], train_target[1]))

-- Perform training step with enhanced backward pass
local loss, predicted = enhanced_network:train_step(train_input, train_target)

print(string.format("Results: Loss = %.6f, Predicted = [%.4f]", loss, predicted[1]))

-- Get comprehensive backward pass information
local backward_info = enhanced_network:get_comprehensive_backward_info()
if backward_info then
    print("\nComputation Graph Analysis:")
    print(string.format("  Total nodes: %d", backward_info.computation_stats.total_nodes))
    print(string.format("  Tree depth: %d", backward_info.computation_stats.max_depth))
    print(string.format("  Gradient paths: %d", #backward_info.gradient_flow_paths))
    
    -- Show some gradient contributions
    local contrib_count = 0
    for node_id, contribution in pairs(backward_info.gradient_contributions) do
        contrib_count = contrib_count + 1
        if contrib_count <= 3 then  -- Show first 3 for brevity
            print(string.format("  Node %s: gradient %.4f, %d path contributions",
                node_id:sub(1, 8) .. "...", 
                contribution.total_gradient,
                #contribution.path_contributions))
        end
    end
    if contrib_count > 3 then
        print(string.format("  ... and %d more nodes", contrib_count - 3))
    end
end

print("Enhanced network training test completed.\n")
-- }}}

-- {{{ Test 4: Decision Tree Structure Analysis
print("4. Testing Decision Tree Structure...")

local tree = enhanced_network:get_decision_tree()
if tree.layers then
    print(string.format("Decision tree structure: %d layers", #tree.layers))
    
    for layer_idx, layer_nodes in ipairs(tree.layers) do
        local operation_counts = {}
        for _, node in ipairs(layer_nodes) do
            local op = node.operation
            operation_counts[op] = (operation_counts[op] or 0) + 1
        end
        
        local ops_str = ""
        for op, count in pairs(operation_counts) do
            if ops_str ~= "" then ops_str = ops_str .. ", " end
            ops_str = ops_str .. string.format("%s:%d", op, count)
        end
        
        print(string.format("  Layer %d: %d nodes (%s)", layer_idx, #layer_nodes, ops_str))
    end
    
    -- Analyze a few gradient paths
    local paths = enhanced_network:get_gradient_flow_paths()
    print(string.format("\nGradient flow analysis (%d paths):", #paths))
    
    for i = 1, math.min(3, #paths) do
        local path = paths[i]
        local path_desc = {}
        for j, node in ipairs(path) do
            table.insert(path_desc, node.operation)
            if j >= 5 then  -- Limit path description length
                table.insert(path_desc, "...")
                break
            end
        end
        print(string.format("  Path %d: %s", i, table.concat(path_desc, " -> ")))
    end
end

print("Decision tree analysis completed.\n")
-- }}}

-- {{{ Test 5: Multiple Training Steps Analysis
print("5. Testing Multiple Training Steps for Convergence...")

print("Running 5 training iterations to observe gradient evolution:")

for iteration = 1, 5 do
    local step_loss, step_predicted = enhanced_network:train_step(train_input, train_target)
    
    local step_info = enhanced_network:get_comprehensive_backward_info()
    local total_gradient_magnitude = 0
    local node_count = 0
    
    if step_info then
        for node_id, contribution in pairs(step_info.gradient_contributions) do
            total_gradient_magnitude = total_gradient_magnitude + math.abs(contribution.total_gradient)
            node_count = node_count + 1
        end
    end
    
    local avg_gradient = node_count > 0 and (total_gradient_magnitude / node_count) or 0
    
    print(string.format("  Step %d: Loss=%.6f, Output=[%.4f], AvgGrad=%.4f, Nodes=%d",
        iteration, step_loss, step_predicted[1], avg_gradient,
        step_info and step_info.computation_stats.total_nodes or 0))
end

print("Multiple training steps test completed.\n")
-- }}}

-- {{{ Test 6: Comparison with Standard Backpropagation
print("6. Comparing Enhanced vs Standard Backpropagation...")

-- Create identical network for comparison
local standard_network = Network:new()
standard_network:add_layer(2)  -- Input layer
standard_network:add_layer(3, "sigmoid")  -- Hidden layer
standard_network:add_layer(1, "sigmoid")  -- Output layer

-- Copy weights from enhanced network
local enhanced_state = enhanced_network:get_state()
standard_network:load_state(enhanced_state)
standard_network:enable_computation_tracking(false)  -- Standard mode

print("Networks configured identically.")

-- Test both on same data
local test_input = {0.3, 0.7}
local test_target = {0.5}

print(string.format("Test input: [%.2f, %.2f], Target: [%.2f]", 
    test_input[1], test_input[2], test_target[1]))

-- Enhanced network (with tracking)
local enhanced_loss, enhanced_pred = enhanced_network:train_step(test_input, test_target)

-- Standard network  
local standard_loss, standard_pred = standard_network:train_step(test_input, test_target)

print("Results comparison:")
print(string.format("  Enhanced: Loss=%.6f, Output=[%.4f]", enhanced_loss, enhanced_pred[1]))
print(string.format("  Standard: Loss=%.6f, Output=[%.4f]", standard_loss, standard_pred[1]))

local loss_diff = math.abs(enhanced_loss - standard_loss)
local pred_diff = math.abs(enhanced_pred[1] - standard_pred[1])

print(string.format("  Differences: Loss=%.8f, Output=%.8f", loss_diff, pred_diff))

if loss_diff < 1e-6 and pred_diff < 1e-6 then
    print("✓ Enhanced and standard backpropagation produce identical results!")
else
    print("✗ Results differ - check implementation")
end

print("Comparison test completed.\n")
-- }}}

print("=== All Enhanced Backpropagation Tests Completed! ===")
print("\nEnhanced Backward Pass Features Demonstrated:")
print("- Computation graph construction and tracking")
print("- Tree-pyramid decision pathway visualization")
print("- Comprehensive gradient flow analysis") 
print("- Enhanced neuron forward pass with graph recording")
print("- Network-wide computation tracking and analysis")
print("- Gradient contribution breakdown by operation")
print("- Decision tree layer organization")
print("- Multi-path gradient flow tracing")
print("- Training convergence with detailed insight")
print("- Equivalence with standard backpropagation")
print("\nTo see the visual representations:")
print("  love .  (then press G to enable tracking, T to train, V to cycle views)")
-- }}}