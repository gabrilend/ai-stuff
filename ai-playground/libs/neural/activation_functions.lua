-- {{{ Activation Functions Library
-- Neural network activation functions with derivatives for backpropagation

local ActivationFunctions = {}

-- Registry for activation functions
ActivationFunctions.functions = {}

-- {{{ sigmoid
local function sigmoid(x)
    -- Numerical stability: avoid overflow for large negative values
    if x < -500 then
        return 0
    elseif x > 500 then
        return 1
    else
        return 1 / (1 + math.exp(-x))
    end
end

local function sigmoid_derivative(x)
    local s = sigmoid(x)
    return s * (1 - s)
end
-- }}}

-- {{{ relu
local function relu(x)
    return math.max(0, x)
end

local function relu_derivative(x)
    return x > 0 and 1 or 0
end
-- }}}

-- {{{ tanh
local function tanh_func(x)
    -- Numerical stability
    if x > 500 then
        return 1
    elseif x < -500 then
        return -1
    else
        return math.tanh(x)
    end
end

local function tanh_derivative(x)
    local t = tanh_func(x)
    return 1 - t * t
end
-- }}}

-- {{{ leaky_relu
local function leaky_relu(x, alpha)
    alpha = alpha or 0.01
    return x > 0 and x or alpha * x
end

local function leaky_relu_derivative(x, alpha)
    alpha = alpha or 0.01
    return x > 0 and 1 or alpha
end
-- }}}

-- {{{ linear
local function linear(x)
    return x
end

local function linear_derivative(x)
    return 1
end
-- }}}

-- {{{ softmax
local function softmax(inputs)
    -- inputs should be a table (array)
    local max_val = -math.huge
    for i = 1, #inputs do
        if inputs[i] > max_val then
            max_val = inputs[i]
        end
    end
    
    local exp_sum = 0
    local exp_values = {}
    for i = 1, #inputs do
        exp_values[i] = math.exp(inputs[i] - max_val)
        exp_sum = exp_sum + exp_values[i]
    end
    
    local result = {}
    for i = 1, #inputs do
        result[i] = exp_values[i] / exp_sum
    end
    
    return result
end

local function softmax_derivative(inputs, index)
    local sm = softmax(inputs)
    local result = {}
    for i = 1, #inputs do
        if i == index then
            result[i] = sm[i] * (1 - sm[i])
        else
            result[i] = -sm[i] * sm[index]
        end
    end
    return result
end
-- }}}

-- {{{ Function registration
function ActivationFunctions.register(name, func, derivative)
    ActivationFunctions.functions[name] = {
        func = func,
        derivative = derivative,
        name = name
    }
end

function ActivationFunctions.get(name)
    return ActivationFunctions.functions[name]
end

function ActivationFunctions.list()
    local names = {}
    for name, _ in pairs(ActivationFunctions.functions) do
        table.insert(names, name)
    end
    table.sort(names)
    return names
end

function ActivationFunctions.exists(name)
    return ActivationFunctions.functions[name] ~= nil
end
-- }}}

-- {{{ Batch processing functions
function ActivationFunctions.apply(name, input)
    local activation = ActivationFunctions.get(name)
    if not activation then
        error("Unknown activation function: " .. tostring(name))
    end
    
    if type(input) == "table" then
        -- Apply to array of values
        local result = {}
        for i = 1, #input do
            result[i] = activation.func(input[i])
        end
        return result
    else
        -- Apply to single value
        return activation.func(input)
    end
end

function ActivationFunctions.apply_derivative(name, input)
    local activation = ActivationFunctions.get(name)
    if not activation then
        error("Unknown activation function: " .. tostring(name))
    end
    
    if type(input) == "table" then
        -- Apply to array of values
        local result = {}
        for i = 1, #input do
            result[i] = activation.derivative(input[i])
        end
        return result
    else
        -- Apply to single value
        return activation.derivative(input)
    end
end
-- }}}

-- {{{ Custom function support
function ActivationFunctions.create_custom(name, func_str, derivative_str)
    -- This would allow users to define custom activation functions
    -- For now, we'll create a placeholder system
    local func = loadstring("return function(x) return " .. func_str .. " end")()
    local derivative = loadstring("return function(x) return " .. derivative_str .. " end")()
    
    ActivationFunctions.register(name, func, derivative)
end

function ActivationFunctions.get_function_string(name)
    -- Returns string representation of function for editing
    local predefined = {
        sigmoid = "1 / (1 + math.exp(-x))",
        relu = "math.max(0, x)",
        tanh = "math.tanh(x)",
        leaky_relu = "x > 0 and x or 0.01 * x",
        linear = "x"
    }
    return predefined[name] or "x"
end

function ActivationFunctions.get_derivative_string(name)
    -- Returns string representation of derivative for editing
    local predefined = {
        sigmoid = "sigmoid(x) * (1 - sigmoid(x))",
        relu = "x > 0 and 1 or 0",
        tanh = "1 - math.tanh(x) * math.tanh(x)",
        leaky_relu = "x > 0 and 1 or 0.01",
        linear = "1"
    }
    return predefined[name] or "1"
end
-- }}}

-- Register all built-in activation functions
ActivationFunctions.register("sigmoid", sigmoid, sigmoid_derivative)
ActivationFunctions.register("relu", relu, relu_derivative)
ActivationFunctions.register("tanh", tanh_func, tanh_derivative)
ActivationFunctions.register("leaky_relu", leaky_relu, leaky_relu_derivative)
ActivationFunctions.register("linear", linear, linear_derivative)

return ActivationFunctions
-- }}}