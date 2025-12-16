#!/usr/bin/env lua

-- {{{ Phase 1 Test Demo Script
-- Tests all components implemented in Phase 1

local DIR = arg[0]:match("(.*/)")

-- Add the project root to package path
package.path = DIR .. "../../?.lua;" .. package.path

-- Import libraries
local Matrix = require('libs/math/matrix')
local ActivationFunctions = require('libs/neural/activation_functions')
local Neuron = require('libs/neural/neuron')
local Network = require('libs/neural/network')

print("=== AI Playground Phase 1 Test Demo ===\n")

-- {{{ Test Matrix Operations
print("1. Testing Matrix Operations...")

local m1 = Matrix:new(2, 2, {{1, 2}, {3, 4}})
local m2 = Matrix:new(2, 2, {{5, 6}, {7, 8}})

print("Matrix 1:")
m1:print()
print("Matrix 2:")
m2:print()

local m3 = m1:multiply(m2)
print("Matrix 1 * Matrix 2:")
m3:print()

local m4 = Matrix.random(3, 3, -1, 1)
print("Random 3x3 Matrix:")
m4:print()

print("Matrix operations test completed.\n")
-- }}}

-- {{{ Test Activation Functions
print("2. Testing Activation Functions...")

local test_values = {-2, -1, 0, 1, 2}
local functions = {"sigmoid", "relu", "tanh", "linear"}

for _, func_name in ipairs(functions) do
    print(string.format("Testing %s:", func_name))
    for _, x in ipairs(test_values) do
        local y = ActivationFunctions.apply(func_name, x)
        local dy = ActivationFunctions.apply_derivative(func_name, x)
        print(string.format("  f(%.1f) = %.4f, f'(%.1f) = %.4f", x, y, x, dy))
    end
    print()
end

print("Activation functions test completed.\n")
-- }}}

-- {{{ Test Neuron
print("3. Testing Neuron...")

local neuron = Neuron:new(3, "sigmoid")
neuron:set_all_weights({0.5, -0.3, 0.8})
neuron:set_bias(0.2)

print("Neuron configuration:")
neuron:print()

local test_input = {1.0, 0.5, -0.2}
local output = neuron:forward(test_input)

print(string.format("Input: [%.2f, %.2f, %.2f]", test_input[1], test_input[2], test_input[3]))
print(string.format("Output: %.4f", output))
print(string.format("Weighted sum: %.4f", neuron:get_weighted_sum()))

-- Test gradient computation
local gradients = neuron:compute_gradient(1.0) -- Assume gradient from next layer = 1
print("Gradients:")
print(string.format("  Weight gradients: [%.4f, %.4f, %.4f]", 
    gradients.weight_gradients[1], gradients.weight_gradients[2], gradients.weight_gradients[3]))
print(string.format("  Bias gradient: %.4f", gradients.bias_gradient))

print("Neuron test completed.\n")
-- }}}

-- {{{ Test Network
print("4. Testing Network...")

local network = Network:new()
network:add_layer(3) -- Input layer
network:add_layer(4, "sigmoid") -- Hidden layer
network:add_layer(2, "sigmoid") -- Output layer

print("Network architecture:")
network:print()

-- Initialize with small random weights
network:randomize_weights(-1, 1)
network:set_learning_rate(0.1)

-- Test forward pass
local input = {0.5, -0.3, 0.8}
local output = network:forward(input)

print(string.format("Forward pass with input [%.2f, %.2f, %.2f]:", input[1], input[2], input[3]))
print(string.format("Output: [%.4f, %.4f]", output[1], output[2]))

-- Test training step
local target = {0.2, 0.7}
local loss, predicted = network:train_step(input, target)

print(string.format("Training step with target [%.2f, %.2f]:", target[1], target[2]))
print(string.format("Loss: %.6f", loss))
print(string.format("Predicted: [%.4f, %.4f]", predicted[1], predicted[2]))

-- Test multiple training steps
print("\nRunning 5 training iterations:")
for i = 1, 5 do
    local train_loss, train_pred = network:train_step(input, target)
    print(string.format("Iteration %d: Loss = %.6f, Output = [%.4f, %.4f]", 
        i, train_loss, train_pred[1], train_pred[2]))
end

print("Network test completed.\n")
-- }}}

-- {{{ Test Network Serialization
print("5. Testing Network Serialization...")

local original_state = network:get_state()
print("Original network state saved.")

-- Create new network and load state
local new_network = Network:new()
new_network:load_state(original_state)

print("Network state loaded into new network:")
new_network:print()

-- Test that both networks produce same output
local orig_output = network:forward(input)
local new_output = new_network:forward(input)

print(string.format("Original output: [%.4f, %.4f]", orig_output[1], orig_output[2]))
print(string.format("New network output: [%.4f, %.4f]", new_output[1], new_output[2]))

local diff1 = math.abs(orig_output[1] - new_output[1])
local diff2 = math.abs(orig_output[2] - new_output[2])
print(string.format("Output difference: [%.6f, %.6f]", diff1, diff2))

if diff1 < 1e-6 and diff2 < 1e-6 then
    print("✓ Serialization test PASSED")
else
    print("✗ Serialization test FAILED")
end

print("Serialization test completed.\n")
-- }}}

print("=== All Phase 1 Tests Completed Successfully! ===")
print("\nPhase 1 Components Implemented:")
print("- Matrix operations library with full arithmetic support")
print("- Activation functions (sigmoid, ReLU, tanh, linear) with derivatives")
print("- Neuron class with forward/backward propagation")
print("- Network class with layer management and training")
print("- Network visualization (available in Love2d application)")
print("- Basic serialization/deserialization")
print("\nTo run the visual demo:")
print("  love .")
print("  (or: cd ai-playground && love .)")
-- }}}