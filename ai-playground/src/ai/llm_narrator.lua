-- {{{ LLM Narrator
-- Local LLM integration for real-time neural network narration

local LLMNarrator = {}
LLMNarrator.__index = LLMNarrator

-- {{{ LLMNarrator constructor
function LLMNarrator:new(config)
    local obj = {
        -- LLM Configuration
        llm_endpoint = config.llm_endpoint or "http://localhost:11434/api/generate",  -- Ollama default
        model_name = config.model_name or "llama2:7b",
        max_tokens = config.max_tokens or 150,
        temperature = config.temperature or 0.7,
        
        -- Narration state
        narration_history = {},
        current_request = nil,
        pending_requests = {},
        
        -- Network state tracking for context
        previous_network_state = nil,
        training_step_count = 0,
        
        -- Response caching
        response_cache = {},
        cache_max_size = 50,
        
        -- Settings
        enabled = config.enabled ~= false,
        auto_narrate = config.auto_narrate ~= false,
        context_window = config.context_window or 3,  -- Previous events to include
        
        -- HTTP client simulation (since Love2D doesn't have built-in HTTP)
        mock_mode = config.mock_mode or true,  -- Use mock responses when no LLM available
        
        -- Predefined response templates for fallback
        response_templates = {
            forward_pass = {
                "The network processes input [{inputs}] through {layers} layers, producing output [{outputs}] with {magnitude} signal strength.",
                "Neural signals flow: input [{inputs}] → hidden processing → final output [{outputs}]. The {strongest_layer} layer shows most activity.",
                "Forward propagation complete: {input_description} generates {output_description}. Network confidence: {confidence}.",
                "Data transformation: [{inputs}] travels through {layer_count} computational layers, resulting in [{outputs}].",
                "The network's {layer_count}-layer architecture processes [{inputs}] and converges to [{outputs}] with {activation_pattern} activation pattern."
            },
            training_step = {
                "Training iteration {step}: Loss decreased from {prev_loss} to {current_loss} ({improvement}% improvement). Gradients show {gradient_pattern}.",
                "Backpropagation adjusts {param_count} parameters. Loss: {current_loss}. The {most_adjusted_layer} layer received largest updates.",
                "Learning step {step} complete. Network error reduced to {current_loss}. Gradient magnitude: {grad_magnitude}.",
                "Parameter update: {weight_changes} weight modifications, {bias_changes} bias adjustments. New loss: {current_loss}.",
                "Training progress: {improvement_trend}. Current error: {current_loss}. The network is {learning_assessment}."
            },
            weight_randomization = {
                "Network weights randomized across {layer_count} layers. New parameter space initialized for fresh learning.",
                "Fresh start: All {param_count} parameters reset to random values in range [{range}]. Network ready for new training.",
                "Weight reinitialization complete. The network's {param_count} parameters now span a new exploration space.",
                "Parameter reset: Network architecture preserved, but all learned knowledge cleared. Ready for clean training session."
            },
            tracking_enabled = {
                "Computation graph tracking activated. Now monitoring {node_count} operations across {depth} computational layers.",
                "Enhanced analysis mode: Tracking complete gradient flow through {path_count} decision pathways.",
                "Detailed computation tracing enabled. Visualizing {operation_types} operation types in decision tree.",
                "Full transparency mode: Every mathematical operation will be recorded and analyzed."
            }
        }
    }
    
    setmetatable(obj, self)
    return obj
end
-- }}}

-- {{{ LLM Request Management
function LLMNarrator:generate_narration(event_type, context_data, callback)
    if not self.enabled then
        if callback then callback(nil) end
        return
    end
    
    -- Check cache first
    local cache_key = self:generate_cache_key(event_type, context_data)
    if self.response_cache[cache_key] then
        if callback then callback(self.response_cache[cache_key]) end
        return
    end
    
    -- Generate prompt based on event type and context
    local prompt = self:build_prompt(event_type, context_data)
    
    if self.mock_mode then
        -- Use template-based responses
        local response = self:generate_mock_response(event_type, context_data)
        if callback then callback(response) end
        self:cache_response(cache_key, response)
    else
        -- Make actual LLM request
        self:make_llm_request(prompt, function(response)
            if callback then callback(response) end
            if response then
                self:cache_response(cache_key, response)
            end
        end)
    end
end

function LLMNarrator:build_prompt(event_type, context_data)
    local base_prompt = [[You are an expert AI researcher explaining neural network behavior in real-time. 
Be concise (1-2 sentences), technical but accessible, and focus on what's actually happening in this specific moment.

Current Event: ]] .. event_type .. [[

Network State:]]
    
    -- Add context based on event type
    if event_type == "forward_pass" then
        base_prompt = base_prompt .. string.format([[
Input: [%s]
Output: [%s]
Network: %s
Layer Activities: %s]], 
            table.concat(context_data.inputs or {}, ", "),
            table.concat(context_data.outputs or {}, ", "),
            context_data.network_info or "Unknown",
            context_data.layer_activities or "Unknown")
            
    elseif event_type == "training_step" then
        base_prompt = base_prompt .. string.format([[
Loss: %.6f → %.6f
Parameters Updated: %d
Gradient Magnitude: %.4f
Learning Rate: %.3f]], 
            context_data.previous_loss or 0,
            context_data.current_loss or 0,
            context_data.parameters_updated or 0,
            context_data.gradient_magnitude or 0,
            context_data.learning_rate or 0)
    end
    
    -- Add recent history for context
    if #self.narration_history > 0 then
        base_prompt = base_prompt .. "\n\nRecent Events:\n"
        local recent_count = math.min(self.context_window, #self.narration_history)
        for i = #self.narration_history - recent_count + 1, #self.narration_history do
            base_prompt = base_prompt .. "- " .. self.narration_history[i].text .. "\n"
        end
    end
    
    base_prompt = base_prompt .. "\n\nExplain what just happened in this neural network:"
    
    return base_prompt
end

function LLMNarrator:make_llm_request(prompt, callback)
    -- This would be implemented with actual HTTP client
    -- For now, we'll use the mock system
    local response = self:generate_mock_response("custom", {prompt = prompt})
    if callback then callback(response) end
end

function LLMNarrator:generate_mock_response(event_type, context_data)
    local templates = self.response_templates[event_type]
    if not templates then
        return "Neural network activity detected: " .. (event_type or "unknown event")
    end
    
    -- Select random template
    local template = templates[math.random(#templates)]
    
    -- Fill in template variables
    local response = self:fill_template(template, context_data)
    
    return response
end

function LLMNarrator:fill_template(template, context_data)
    local filled = template
    
    -- Common substitutions
    local substitutions = {
        inputs = table.concat(context_data.inputs or {"0.0", "0.0", "0.0"}, ", "),
        outputs = table.concat(context_data.outputs or {"0.0", "0.0"}, ", "),
        layers = tostring(context_data.layer_count or 3),
        layer_count = tostring(context_data.layer_count or 3),
        step = tostring(self.training_step_count),
        current_loss = string.format("%.6f", context_data.current_loss or 0),
        prev_loss = string.format("%.6f", context_data.previous_loss or 0),
        param_count = tostring(context_data.param_count or 26),
        gradient_magnitude = string.format("%.4f", context_data.gradient_magnitude or 0.01),
        learning_rate = string.format("%.3f", context_data.learning_rate or 0.01),
        node_count = tostring(context_data.node_count or 40),
        depth = tostring(context_data.depth or 5),
        path_count = tostring(context_data.path_count or 22)
    }
    
    -- Calculated fields
    if context_data.current_loss and context_data.previous_loss then
        local improvement = ((context_data.previous_loss - context_data.current_loss) / context_data.previous_loss) * 100
        substitutions.improvement = string.format("%.1f", improvement)
    else
        substitutions.improvement = "unknown"
    end
    
    -- Descriptive fields
    substitutions.magnitude = self:describe_magnitude(context_data.output_magnitude)
    substitutions.strongest_layer = context_data.strongest_layer or "hidden"
    substitutions.confidence = self:describe_confidence(context_data.outputs)
    substitutions.input_description = self:describe_input_pattern(context_data.inputs)
    substitutions.output_description = self:describe_output_pattern(context_data.outputs)
    substitutions.activation_pattern = self:describe_activation_pattern(context_data.layer_activities)
    substitutions.gradient_pattern = self:describe_gradient_pattern(context_data.gradient_info)
    substitutions.most_adjusted_layer = context_data.most_adjusted_layer or "output"
    substitutions.weight_changes = tostring(context_data.weight_changes or 12)
    substitutions.bias_changes = tostring(context_data.bias_changes or 4)
    substitutions.improvement_trend = self:describe_improvement_trend(context_data.loss_history)
    substitutions.learning_assessment = self:assess_learning_progress(context_data.loss_history)
    substitutions.operation_types = tostring(context_data.operation_types or 6)
    substitutions.range = string.format("[%.1f, %.1f]", context_data.weight_min or -2, context_data.weight_max or 2)
    
    -- Perform substitutions
    for key, value in pairs(substitutions) do
        filled = string.gsub(filled, "{" .. key .. "}", value)
    end
    
    return filled
end
-- }}}

-- {{{ Descriptive Functions
function LLMNarrator:describe_magnitude(magnitude)
    if not magnitude then return "moderate" end
    if magnitude > 0.8 then return "strong"
    elseif magnitude > 0.5 then return "moderate"
    elseif magnitude > 0.2 then return "weak"
    else return "minimal" end
end

function LLMNarrator:describe_confidence(outputs)
    if not outputs or #outputs == 0 then return "uncertain" end
    local max_output = math.max(unpack(outputs))
    if max_output > 0.8 then return "high"
    elseif max_output > 0.6 then return "moderate"
    else return "low" end
end

function LLMNarrator:describe_input_pattern(inputs)
    if not inputs or #inputs == 0 then return "empty input" end
    local sum = 0
    for _, v in ipairs(inputs) do sum = sum + math.abs(v) end
    local avg = sum / #inputs
    
    if avg > 0.5 then return "high-energy input pattern"
    elseif avg > 0.2 then return "moderate input signal"
    else return "low-amplitude input" end
end

function LLMNarrator:describe_output_pattern(outputs)
    if not outputs or #outputs == 0 then return "no output" end
    local max_val = math.max(unpack(outputs))
    local min_val = math.min(unpack(outputs))
    local range = max_val - min_val
    
    if range > 0.5 then return "decisive output pattern"
    elseif range > 0.2 then return "moderate output distinction"
    else return "uncertain output signal" end
end

function LLMNarrator:describe_activation_pattern(layer_activities)
    local patterns = {"sparse", "distributed", "focused", "balanced", "saturated"}
    return patterns[math.random(#patterns)]
end

function LLMNarrator:describe_gradient_pattern(gradient_info)
    if not gradient_info then return "standard flow" end
    local patterns = {"strong backflow", "gentle correction", "focused updates", "distributed adjustment"}
    return patterns[math.random(#patterns)]
end

function LLMNarrator:describe_improvement_trend(loss_history)
    if not loss_history or #loss_history < 2 then return "initial training" end
    local recent_trend = "steady convergence"
    if #loss_history >= 3 then
        local trends = {"rapid convergence", "steady improvement", "gradual learning", "stable optimization"}
        recent_trend = trends[math.random(#trends)]
    end
    return recent_trend
end

function LLMNarrator:assess_learning_progress(loss_history)
    if not loss_history or #loss_history < 2 then return "just starting" end
    local assessments = {"learning effectively", "making progress", "adapting well", "optimizing steadily", "converging nicely"}
    return assessments[math.random(#assessments)]
end
-- }}}

-- {{{ Narration Management
function LLMNarrator:add_narration(text, event_type, timestamp)
    timestamp = timestamp or os.time()
    
    local entry = {
        text = text,
        event_type = event_type or "general",
        timestamp = timestamp,
        id = #self.narration_history + 1
    }
    
    table.insert(self.narration_history, entry)
    
    -- Limit history size
    if #self.narration_history > 100 then
        table.remove(self.narration_history, 1)
    end
end

function LLMNarrator:get_recent_narrations(count)
    count = count or 10
    local recent = {}
    local start_index = math.max(1, #self.narration_history - count + 1)
    
    for i = start_index, #self.narration_history do
        table.insert(recent, self.narration_history[i])
    end
    
    return recent
end

function LLMNarrator:clear_history()
    self.narration_history = {}
end

function LLMNarrator:get_history_count()
    return #self.narration_history
end
-- }}}

-- {{{ Cache Management
function LLMNarrator:generate_cache_key(event_type, context_data)
    -- Create a simple hash of the event and key context data
    local key_data = {
        event_type = event_type,
        input_pattern = context_data.inputs and table.concat(context_data.inputs, ",") or "",
        layer_count = context_data.layer_count or 0,
        loss_level = context_data.current_loss and string.format("%.2f", context_data.current_loss) or ""
    }
    
    local key_string = ""
    for k, v in pairs(key_data) do
        key_string = key_string .. k .. ":" .. tostring(v) .. ";"
    end
    
    return key_string
end

function LLMNarrator:cache_response(key, response)
    self.response_cache[key] = response
    
    -- Limit cache size
    if self:get_cache_size() > self.cache_max_size then
        self:clear_oldest_cache_entry()
    end
end

function LLMNarrator:get_cache_size()
    local count = 0
    for _ in pairs(self.response_cache) do
        count = count + 1
    end
    return count
end

function LLMNarrator:clear_oldest_cache_entry()
    -- Simple implementation - just remove a random entry
    -- In practice, you'd track timestamps and remove the oldest
    local first_key = next(self.response_cache)
    if first_key then
        self.response_cache[first_key] = nil
    end
end

function LLMNarrator:clear_cache()
    self.response_cache = {}
end
-- }}}

-- {{{ Configuration and State Management
function LLMNarrator:set_enabled(enabled)
    self.enabled = enabled
end

function LLMNarrator:is_enabled()
    return self.enabled
end

function LLMNarrator:set_mock_mode(enabled)
    self.mock_mode = enabled
end

function LLMNarrator:set_model(model_name)
    self.model_name = model_name
    self:clear_cache()  -- Clear cache when model changes
end

function LLMNarrator:set_temperature(temperature)
    self.temperature = math.max(0.1, math.min(2.0, temperature))
end

function LLMNarrator:update_training_step()
    self.training_step_count = self.training_step_count + 1
end

function LLMNarrator:reset_training_context()
    self.training_step_count = 0
    self.previous_network_state = nil
end

function LLMNarrator:get_stats()
    return {
        narration_count = #self.narration_history,
        cache_size = self:get_cache_size(),
        training_steps = self.training_step_count,
        enabled = self.enabled,
        mock_mode = self.mock_mode
    }
end
-- }}}

return LLMNarrator
-- }}}