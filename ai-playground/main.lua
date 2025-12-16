-- {{{ main entry point
-- AI Playground - Neural Network Visualizer
-- Main Love2d entry point

local DIR = love.filesystem.getSource()

-- Import libraries
local Network = require('libs/neural/network')
local NetworkRenderer = require('src/visualization/network_renderer')
local GradientVisualizer = require('src/visualization/gradient_visualizer')
local DecisionTreeRenderer = require('src/visualization/decision_tree_renderer')
local Stereo3DRenderer = require('src/visualization/stereo_3d_renderer')
local LayoutManager = require('src/ui/layout_manager')
local ChatLog = require('src/ui/chat_log')
local LLMNarrator = require('src/ai/llm_narrator')

-- Global state
local game_state = {}
local demo_network = nil
local network_renderer = nil
local gradient_visualizer = nil
local decision_tree_renderer = nil
local stereo_3d_renderer = nil
local layout_manager = nil
local chat_log = nil
local llm_narrator = nil
local computation_tracking_enabled = false
local current_view_mode = "network" -- "network", "gradient", "tree", "3d"

-- {{{ love.load
function love.load()
    -- Set up basic graphics
    love.graphics.setBackgroundColor(0.08, 0.08, 0.12)
    love.graphics.setColor(1, 1, 1)
    
    -- Initialize game state
    game_state = {
        font = love.graphics.newFont(14),
        title_font = love.graphics.newFont(24),
        mouse_x = 0,
        mouse_y = 0,
        window_width = love.graphics.getWidth(),
        window_height = love.graphics.getHeight()
    }
    
    love.graphics.setFont(game_state.font)
    
    -- Initialize layout manager
    layout_manager = LayoutManager:new(game_state.window_width, game_state.window_height)
    
    -- Initialize LLM narrator
    llm_narrator = LLMNarrator:new({
        enabled = true,
        mock_mode = true,  -- Use template-based responses
        auto_narrate = true,
        temperature = 0.7
    })
    
    -- Initialize chat log
    chat_log = ChatLog:new(0, 0, 300, 400)
    chat_log:add_system_message("AI Playground initialized with enhanced backpropagation visualization.")
    chat_log:add_ai_narration("Ready to explain neural network behavior in real-time!")
    
    -- Create demo network
    demo_network = Network:new()
    demo_network:add_layer(3) -- Input layer (3 inputs)
    demo_network:add_layer(4, "sigmoid") -- Hidden layer (4 neurons, sigmoid)
    demo_network:add_layer(2, "sigmoid") -- Output layer (2 neurons, sigmoid)
    
    -- Initialize network with random weights
    demo_network:randomize_weights(-2, 2)
    demo_network:set_learning_rate(0.1)
    
    -- Create visualizers
    network_renderer = NetworkRenderer:new(0, 0, 500, 350)
    network_renderer:set_network(demo_network)
    
    gradient_visualizer = GradientVisualizer:new(0, 0, 500, 200)
    
    decision_tree_renderer = DecisionTreeRenderer:new(0, 0, 350, 400)
    
    stereo_3d_renderer = Stereo3DRenderer:new(0, 0, 600, 450)
    stereo_3d_renderer:set_network(demo_network)
    
    -- Register panels with layout manager
    layout_manager:register_panel("network_view", {
        title = "Neural Network",
        slot = "main",
        render_func = function(x, y, w, h, panel)
            network_renderer:set_bounds(x, y, w, h)
            network_renderer:draw()
        end
    })
    
    layout_manager:register_panel("gradient_view", {
        title = "Gradient Flow",
        slot = "bottom",
        render_func = function(x, y, w, h, panel)
            gradient_visualizer:set_bounds(x, y, w, h)
            gradient_visualizer:draw()
        end
    })
    
    layout_manager:register_panel("tree_view", {
        title = "Decision Tree",
        slot = "right",
        render_func = function(x, y, w, h, panel)
            decision_tree_renderer:set_bounds(x, y, w, h)
            decision_tree_renderer:draw()
        end
    })
    
    layout_manager:register_panel("3d_view", {
        title = "3D Stereographic View",
        slot = "main",
        render_func = function(x, y, w, h, panel)
            stereo_3d_renderer:set_bounds(x, y, w, h)
            stereo_3d_renderer:draw()
        end,
        visible = false  -- Start hidden, show when 3D mode is selected
    })
    
    layout_manager:register_panel("chat_log", {
        title = "AI Narrator",
        slot = "far-right",
        render_func = function(x, y, w, h, panel)
            chat_log:resize(w, h)
            love.graphics.push()
            love.graphics.translate(x, y)
            chat_log.x = 0
            chat_log.y = 0
            chat_log:draw()
            love.graphics.pop()
        end,
        update_func = function(dt, panel)
            chat_log:update(dt)
        end
    })
    
    layout_manager:register_panel("info_panel", {
        title = "Network Information",
        slot = "bottom-right",
        render_func = function(x, y, w, h, panel)
            draw_info_panel(x, y, w, h)
        end
    })
    
    -- Run initial forward pass and narrate it
    local sample_input = {0.5, -0.3, 0.8}
    demo_network:forward(sample_input)
    
    -- Generate initial narration
    llm_narrator:generate_narration("forward_pass", {
        inputs = sample_input,
        outputs = demo_network:get_output(),
        layer_count = demo_network:get_layer_count(),
        param_count = demo_network:get_total_parameters()
    }, function(narration)
        if narration then
            chat_log:add_ai_narration(narration)
        end
    end)
    
    print("AI Playground with LLM Narration loaded successfully")
    print("Demo network created: 3-4-2 architecture")
    print("Drag panels to rearrange the interface!")
end
-- }}}

-- {{{ Info panel drawing function
function draw_info_panel(x, y, w, h)
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.print("Network Status", x + 10, y + 10)
    
    local y_offset = 30
    if demo_network then
        local outputs = demo_network:get_output()
        if outputs then
            love.graphics.setColor(0.6, 0.6, 0.6)
            love.graphics.print("Current Outputs:", x + 10, y + y_offset)
            y_offset = y_offset + 20
            
            for i, output in ipairs(outputs) do
                love.graphics.print(string.format("  Output %d: %.4f", i, output), 
                    x + 10, y + y_offset)
                y_offset = y_offset + 18
            end
        end
        
        y_offset = y_offset + 10
        love.graphics.print(string.format("Learning Rate: %.3f", demo_network:get_learning_rate()),
            x + 10, y + y_offset)
        y_offset = y_offset + 18
        
        love.graphics.print(string.format("Parameters: %d", demo_network:get_total_parameters()),
            x + 10, y + y_offset)
        y_offset = y_offset + 18
        
        -- Show computation tracking status
        if computation_tracking_enabled then
            love.graphics.setColor(0.3, 0.8, 0.3)
            love.graphics.print("Graph Tracking: ON", x + 10, y + y_offset)
            
            local graph = demo_network:get_computation_graph()
            if graph then
                local stats = graph:get_stats()
                love.graphics.setColor(0.6, 0.6, 0.6)
                y_offset = y_offset + 18
                love.graphics.print(string.format("Nodes: %d", stats.total_nodes), x + 10, y + y_offset)
            end
        else
            love.graphics.setColor(0.8, 0.3, 0.3)
            love.graphics.print("Graph Tracking: OFF", x + 10, y + y_offset)
        end
    end
    
    -- Show LLM narrator stats
    if llm_narrator then
        local narrator_stats = llm_narrator:get_stats()
        love.graphics.setColor(0.6, 0.8, 0.6)
        y_offset = y_offset + 25
        love.graphics.print("LLM Narrator:", x + 10, y + y_offset)
        y_offset = y_offset + 18
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.print(string.format("Messages: %d", narrator_stats.narration_count), x + 10, y + y_offset)
        y_offset = y_offset + 16
        love.graphics.print(string.format("Mode: %s", narrator_stats.mock_mode and "Mock" or "Live"), x + 10, y + y_offset)
    end
end
-- }}}

-- {{{ love.update
function love.update(dt)
    -- Update mouse position
    game_state.mouse_x, game_state.mouse_y = love.mouse.getPosition()
    
    -- Update window dimensions
    local new_width, new_height = love.graphics.getWidth(), love.graphics.getHeight()
    if new_width ~= game_state.window_width or new_height ~= game_state.window_height then
        game_state.window_width = new_width
        game_state.window_height = new_height
        if layout_manager then
            layout_manager:resize_window(new_width, new_height)
        end
    end
    
    -- Update layout manager
    if layout_manager then
        layout_manager:update(dt)
    end
    
    -- Update visualizers
    if network_renderer then
        network_renderer:mouse_moved(game_state.mouse_x, game_state.mouse_y)
    end
    if gradient_visualizer then
        gradient_visualizer:mouse_moved(game_state.mouse_x, game_state.mouse_y)
        gradient_visualizer:update_animation(dt)
    end
    if decision_tree_renderer then
        decision_tree_renderer:mouse_moved(game_state.mouse_x, game_state.mouse_y)
    end
    if stereo_3d_renderer then
        stereo_3d_renderer:mouse_moved(game_state.mouse_x, game_state.mouse_y)
    end
end
-- }}}

-- {{{ love.draw
function love.draw()
    -- Draw title bar
    love.graphics.setFont(game_state.title_font)
    love.graphics.setColor(0.8, 0.9, 1.0)
    love.graphics.print("AI Playground - Enhanced with LLM Narration", 20, 20)
    
    -- Draw status information
    love.graphics.setFont(game_state.font)
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.print("Drag panels to rearrange • Press keys for actions", 20, 50)
    love.graphics.print(string.format("Network: 3-4-2 | Tracking: %s | AI Narrator: %s", 
        computation_tracking_enabled and "ON" or "OFF",
        llm_narrator and llm_narrator:is_enabled() and "ON" or "OFF"), 20, 70)
    
    -- Draw layout manager (handles all panels)
    if layout_manager then
        layout_manager:draw()
    end
    
    -- Draw controls overlay (bottom left)
    love.graphics.setColor(0.1, 0.1, 0.15, 0.8)
    love.graphics.rectangle("fill", 10, game_state.window_height - 160, 300, 150)
    love.graphics.setColor(0.4, 0.4, 0.5)
    love.graphics.rectangle("line", 10, game_state.window_height - 160, 300, 150)
    
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.print("Controls:", 20, game_state.window_height - 150)
    love.graphics.setColor(0.6, 0.6, 0.6)
    love.graphics.print("SPACE: Forward pass + narration", 20, game_state.window_height - 130)
    love.graphics.print("T: Training step + analysis", 20, game_state.window_height - 115)
    love.graphics.print("G: Toggle computation tracking", 20, game_state.window_height - 100)
    love.graphics.print("V: Cycle views (2D→3D→All)", 20, game_state.window_height - 85)
    love.graphics.print("3: Quick 3D stereographic view", 20, game_state.window_height - 70)
    love.graphics.print("N: Toggle LLM narrator", 20, game_state.window_height - 55)
    love.graphics.print("R: Randomize weights | L: Reset layout", 20, game_state.window_height - 40)
    love.graphics.print("ESC: Exit", 20, game_state.window_height - 25)
end
-- }}}

-- {{{ love.keypressed
function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    elseif key == "space" then
        -- Run forward pass with random input and generate narration
        if demo_network then
            local random_input = {
                math.random() * 2 - 1,  -- Random between -1 and 1
                math.random() * 2 - 1,
                math.random() * 2 - 1
            }
            
            if computation_tracking_enabled then
                demo_network:forward_with_graph(random_input)
                print(string.format("Forward pass with graph tracking: [%.2f, %.2f, %.2f]", 
                    random_input[1], random_input[2], random_input[3]))
            else
                demo_network:forward(random_input)
                print(string.format("Forward pass with input [%.2f, %.2f, %.2f]", 
                    random_input[1], random_input[2], random_input[3]))
            end
            
            -- Generate LLM narration for the forward pass
            if llm_narrator then
                llm_narrator:generate_narration("forward_pass", {
                    inputs = random_input,
                    outputs = demo_network:get_output(),
                    layer_count = demo_network:get_layer_count(),
                    param_count = demo_network:get_total_parameters(),
                    output_magnitude = demo_network:get_output_magnitude(),
                    layer_activities = demo_network:get_layer_activities()
                }, function(narration)
                    if narration and chat_log then
                        chat_log:add_ai_narration(narration)
                    end
                end)
            end
        end
    elseif key == "r" then
        -- Randomize network weights and narrate
        if demo_network then
            demo_network:randomize_weights(-2, 2)
            print("Network weights randomized")
            
            -- Generate narration for weight randomization
            if llm_narrator then
                llm_narrator:generate_narration("weight_randomization", {
                    layer_count = demo_network:get_layer_count(),
                    param_count = demo_network:get_total_parameters(),
                    weight_min = -2,
                    weight_max = 2
                }, function(narration)
                    if narration and chat_log then
                        chat_log:add_ai_narration(narration)
                    end
                end)
            end
        end
    elseif key == "t" then
        -- Test training step with analysis and narration
        if demo_network then
            local train_input = {0.5, -0.3, 0.8}
            local target_output = {0.2, 0.7}
            local previous_loss = demo_network:get_last_loss() or 0
            local loss, predicted = demo_network:train_step(train_input, target_output)
            
            print(string.format("Training step: loss = %.4f, output = [%.3f, %.3f]",
                loss, predicted[1], predicted[2]))
            
            -- Update training step counter
            if llm_narrator then
                llm_narrator:update_training_step()
            end
            
            -- Update visualizers with new computation graph data
            if computation_tracking_enabled then
                local graph = demo_network:get_computation_graph()
                local tree = demo_network:get_decision_tree()
                local paths = demo_network:get_gradient_flow_paths()
                local contributions = demo_network:get_gradient_contributions()
                
                gradient_visualizer:set_computation_graph(graph)
                gradient_visualizer:set_decision_tree(tree)
                gradient_visualizer:set_gradient_flow_paths(paths)
                
                decision_tree_renderer:set_decision_tree(tree)
                decision_tree_renderer:set_gradient_contributions(contributions)
                
                print("Updated visualization with computation graph data")
            end
            
            -- Generate training step narration
            if llm_narrator then
                llm_narrator:generate_narration("training_step", {
                    current_loss = loss,
                    previous_loss = previous_loss,
                    predicted_output = predicted,
                    target_output = target_output,
                    learning_rate = demo_network:get_learning_rate(),
                    param_count = demo_network:get_total_parameters()
                }, function(narration)
                    if narration and chat_log then
                        chat_log:add_ai_narration(narration)
                    end
                end)
            end
        end
    elseif key == "g" then
        -- Toggle computation graph tracking
        computation_tracking_enabled = not computation_tracking_enabled
        if demo_network then
            demo_network:enable_computation_tracking(computation_tracking_enabled)
            print("Computation tracking: " .. (computation_tracking_enabled and "ENABLED" or "DISABLED"))
            
            -- Clear visualizers when tracking is disabled
            if not computation_tracking_enabled then
                gradient_visualizer:clear()
                decision_tree_renderer:clear()
            end
            
            -- Generate narration for tracking state change
            if llm_narrator then
                llm_narrator:generate_narration("tracking_enabled", {
                    tracking_enabled = computation_tracking_enabled,
                    node_count = computation_tracking_enabled and 40 or 0,
                    depth = computation_tracking_enabled and 5 or 0
                }, function(narration)
                    if narration and chat_log then
                        chat_log:add_system_message(narration)
                    end
                end)
            end
        end
    elseif key == "n" then
        -- Toggle LLM narrator
        if llm_narrator then
            llm_narrator:set_enabled(not llm_narrator:is_enabled())
            local status = llm_narrator:is_enabled() and "ENABLED" or "DISABLED"
            print("LLM Narrator: " .. status)
            
            if chat_log then
                chat_log:add_system_message("LLM Narrator: " .. status)
            end
        end
    elseif key == "l" then
        -- Reset panel layout
        if layout_manager then
            layout_manager:reset_to_default()
            print("Panel layout reset to default")
            
            if chat_log then
                chat_log:add_system_message("Panel layout reset to default configuration")
            end
        end
    elseif key == "v" then
        -- Cycle view mode
        local modes = {"network", "gradient", "tree", "3d", "all"}
        local current_index = 1
        for i, mode in ipairs(modes) do
            if mode == current_view_mode then
                current_index = i
                break
            end
        end
        current_index = (current_index % #modes) + 1
        current_view_mode = modes[current_index]
        
        -- Toggle panel visibility based on view mode
        if layout_manager then
            if current_view_mode == "3d" then
                layout_manager:toggle_panel_visibility("network_view")
                layout_manager:toggle_panel_visibility("3d_view")
                if not layout_manager:is_panel_visible("3d_view") then
                    layout_manager:toggle_panel_visibility("3d_view")
                end
                if layout_manager:is_panel_visible("network_view") then
                    layout_manager:toggle_panel_visibility("network_view")
                end
            elseif current_view_mode == "network" then
                if not layout_manager:is_panel_visible("network_view") then
                    layout_manager:toggle_panel_visibility("network_view")
                end
                if layout_manager:is_panel_visible("3d_view") then
                    layout_manager:toggle_panel_visibility("3d_view")
                end
            elseif current_view_mode == "all" then
                -- Show all panels
                if not layout_manager:is_panel_visible("network_view") then
                    layout_manager:toggle_panel_visibility("network_view")
                end
                if not layout_manager:is_panel_visible("3d_view") then
                    layout_manager:toggle_panel_visibility("3d_view")
                end
            end
        end
        
        print("View mode: " .. current_view_mode)
    elseif key == "3" then
        -- Quick toggle to 3D mode
        current_view_mode = "3d"
        if layout_manager then
            if layout_manager:is_panel_visible("network_view") then
                layout_manager:toggle_panel_visibility("network_view")
            end
            if not layout_manager:is_panel_visible("3d_view") then
                layout_manager:toggle_panel_visibility("3d_view")
            end
        end
        print("Switched to 3D stereographic view")
    end
    
    -- Pass keyboard input to 3D renderer when in 3D mode
    if (current_view_mode == "3d" or current_view_mode == "all") and stereo_3d_renderer then
        stereo_3d_renderer:key_pressed(key)
    end
end
-- }}}

-- {{{ love.mousepressed
function love.mousepressed(x, y, button, istouch, presses)
    if button == 1 then -- Left mouse button
        local handled = false
        
        -- First try layout manager for panel dragging
        if layout_manager then
            handled = layout_manager:mouse_pressed(x, y, button)
        end
        
        -- If not handled by layout manager, try chat log
        if not handled and chat_log then
            handled = chat_log:mouse_pressed(x, y, button)
        end
        
        -- Then try interaction with different visualizers based on current mode
        if not handled and (current_view_mode == "network" or current_view_mode == "all") and network_renderer then
            handled = network_renderer:mouse_pressed(x, y, button)
            if handled then
                local selected = network_renderer:get_selected_neuron()
                if selected then
                    print(string.format("Selected neuron: Layer %d, Neuron %d", 
                        selected.layer, selected.neuron))
                end
            end
        end
        
        if not handled and (current_view_mode == "gradient" or current_view_mode == "all") and gradient_visualizer then
            handled = gradient_visualizer:mouse_pressed(x, y, button)
            if handled then
                local selected_path = gradient_visualizer:get_selected_path()
                if selected_path then
                    print(string.format("Selected gradient path with %d nodes", #selected_path))
                end
            end
        end
        
        if not handled and (current_view_mode == "tree" or current_view_mode == "all") and decision_tree_renderer then
            handled = decision_tree_renderer:mouse_pressed(x, y, button)
            if handled then
                local selected = decision_tree_renderer:get_selected_node()
                if selected then
                    print(string.format("Selected tree node: %s", selected.node.operation))
                end
            end
        end
        
        if not handled and (current_view_mode == "3d" or current_view_mode == "all") and stereo_3d_renderer then
            handled = stereo_3d_renderer:mouse_pressed(x, y, button)
            if handled then
                print("3D view interaction detected")
            end
        end
    end
end

-- {{{ love.mousemoved
function love.mousemoved(x, y, dx, dy)
    -- Update game state mouse position
    game_state.mouse_x, game_state.mouse_y = x, y
    
    -- Handle layout manager dragging
    if layout_manager then
        layout_manager:mouse_moved(x, y)
    end
    
    -- Handle chat log interactions
    if chat_log then
        chat_log:mouse_moved(x, y)
    end
end

-- {{{ love.mousereleased
function love.mousereleased(x, y, button)
    -- Handle layout manager
    if layout_manager then
        layout_manager:mouse_released(x, y, button)
    end
    
    -- Handle chat log
    if chat_log then
        chat_log:mouse_released(x, y, button)
    end
    
    -- Handle 3D renderer
    if stereo_3d_renderer then
        stereo_3d_renderer:mouse_released(x, y, button)
    end
end

-- {{{ love.wheelmoved
function love.wheelmoved(x, y)
    -- Handle chat log scrolling
    if chat_log then
        chat_log:wheel_moved(x, y)
    end
end
-- }}}

-- {{{ love.resize
function love.resize(w, h)
    print(string.format("Window resized to %dx%d", w, h))
end
-- }}}
-- }}}