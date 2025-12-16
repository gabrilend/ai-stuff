# AI Playground - Technical Reference

## Architecture Overview

The AI Playground is built with a modular architecture designed for extensibility and maintainability:

```
┌─────────────────────────────────────────┐
│                Main App                 │
│              (main.lua)                 │
├─────────────────────────────────────────┤
│  UI Layer        │  Visualization Layer │
│  ├─ Layout Mgr   │  ├─ Network Renderer │
│  ├─ Chat Log     │  ├─ 3D Renderer      │
│  └─ Panels       │  ├─ Gradient Viz     │
│                  │  └─ Decision Tree    │
├─────────────────────────────────────────┤
│        Neural Network Engine            │
│  ├─ Network      ├─ Neuron             │
│  ├─ Layer        ├─ Activation         │
│  └─ Computation Graph                   │
├─────────────────────────────────────────┤
│     Intelligence & Analysis Layer       │
│  ├─ LLM Narrator ├─ Claude Generator   │
│  ├─ Intel System ├─ Resume Builder     │
│  └─ Security Analysis                   │
└─────────────────────────────────────────┘
```

## Core Components

### 1. Neural Network Engine (`libs/neural/`)

#### Network Class (`network.lua`)
```lua
-- Core Methods
network:add_layer(size, activation)
network:forward(inputs)
network:train_step(inputs, targets)
network:randomize_weights(min, max)

-- Advanced Features
network:enable_computation_tracking(enabled)
network:get_computation_graph()
network:get_decision_tree()
network:get_gradient_flow_paths()
```

#### Neuron Class (`neuron.lua`)
```lua
-- Basic Operations
neuron:forward(inputs)
neuron:backward(error_gradient)
neuron:update_weights(learning_rate)

-- Graph Tracking
neuron:forward_with_graph(inputs, graph)
neuron:get_operation_breakdown()
```

#### Computation Graph (`computation_graph.lua`)
```lua
-- Graph Construction
graph:add_node(operation, inputs, outputs)
graph:add_connection(from_node, to_node)
graph:set_gradient(node, gradient)

-- Analysis
graph:get_backward_paths()
graph:generate_decision_tree()
graph:calculate_gradient_contributions()
```

### 2. Visualization System (`src/visualization/`)

#### Network Renderer (`network_renderer.lua`)
```lua
-- Core Rendering
renderer:set_network(network)
renderer:draw()
renderer:set_bounds(x, y, width, height)

-- Interaction
renderer:mouse_pressed(x, y, button)
renderer:get_selected_neuron()
```

#### 3D Stereographic Renderer (`stereo_3d_renderer.lua`)
```lua
-- 3D Projection
renderer:project_3d_to_2d(x3d, y3d, z3d)
renderer:calculate_node_positions()

-- Interaction Controls
renderer:key_pressed(key)  -- R, A, 1-4 for rotation
renderer:mouse_moved(x, y)
renderer:set_auto_rotate(enabled, speed)

-- Visual Mapping
renderer:map_strength_to_depth(strength)
renderer:calculate_icon_size(z3d)
```

### 3. UI Framework (`src/ui/`)

#### Layout Manager (`layout_manager.lua`)
```lua
-- Panel Management
layout_manager:register_panel(name, config)
layout_manager:toggle_panel_visibility(name)
layout_manager:snap_panel_to_slot(panel, slot)

-- Interaction
layout_manager:mouse_pressed(x, y, button)
layout_manager:start_dragging(panel_name, x, y)
```

#### Chat Log (`chat_log.lua`)
```lua
-- Message Management
chat_log:add_ai_narration(text)
chat_log:add_system_message(text)
chat_log:add_error_message(text)

-- Display Features
chat_log:set_typing_effect(enabled)
chat_log:set_auto_scroll(enabled)
chat_log:wheel_moved(x, y)  -- Scrolling
```

### 4. AI Integration (`src/ai/`)

#### LLM Narrator (`llm_narrator.lua`)
```lua
-- Narration Generation
narrator:generate_narration(event_type, context_data, callback)

-- Event Types
"forward_pass"        -- Neural network forward propagation
"training_step"       -- Backpropagation and weight updates
"weight_randomization" -- Network reinitialization
"tracking_enabled"    -- Computation graph activation

-- Context Data Structure
{
    inputs = {...},
    outputs = {...},
    layer_count = number,
    param_count = number,
    current_loss = number,
    previous_loss = number
}
```

## Advanced Analysis System (`src/`)

### Computation Tracking System
```bash
# Runtime Analysis
G                                      # Toggle computation tracking
T                                      # Training step with analysis
SPACE + G                             # Forward pass with detailed tracking

# View Analysis  
V                                     # Cycle through analysis modes
3                                     # Enter 3D stereographic view
```

### Integration Architecture
- **Modular Design**: Each visualization component is independently accessible
- **Event System**: Communication between UI, renderer, and analysis systems
- **Extensible API**: Add new visualization modes and analysis types
- **Performance Optimization**: Efficient rendering and computation tracking

## Data Structures

### Network Structure
```lua
network = {
    layers = {
        {
            neurons = {
                { weights = {...}, bias = number, output = number },
                ...
            },
            activation_function = "sigmoid"|"relu"|"tanh"
        },
        ...
    },
    learning_rate = number,
    computation_graph = ComputationGraph|nil
}
```

### 3D Renderer State
```lua
stereo_3d_renderer = {
    camera = {
        x, y, z = numbers,
        rotation_x, rotation_y, rotation_z = radians,
        fov = degrees,
        near, far = distances
    },
    nodes = {
        {
            x3d, y3d, z3d = world_coordinates,
            layer, neuron = indices,
            activation = 0.0-1.0,
            type = "input"|"hidden"|"output",
            icon = "◯"|"◆"|"◈"|"●"|"○"
        },
        ...
    },
    connections = {
        {
            from_node, to_node = indices,
            strength = 0.0-1.0,
            width = pixels,
            depth = z_coordinate,
            color = {r, g, b}
        },
        ...
    }
}
```

### Panel Configuration
```lua
panel_config = {
    title = "Panel Name",
    slot = "main"|"right"|"bottom"|"far-right",
    render_func = function(x, y, w, h, panel) end,
    update_func = function(dt, panel) end,
    visible = boolean,
    resizable = boolean,
    min_width, min_height = pixels
}
```

## Key Algorithms

### 3D Stereographic Projection
```lua
function project_3d_to_2d(x3d, y3d, z3d)
    -- Apply rotation matrices
    local x_rot = x3d * cos_ry - z3d * sin_ry
    local z_rot = x3d * sin_ry + z3d * cos_ry
    local y_rot = y3d * cos_rx - z_rot * sin_rx
    z3d = y3d * sin_rx + z_rot * cos_rx
    
    -- Perspective projection
    z3d = z3d + camera.z
    if z3d <= 0.01 then z3d = 0.01 end
    
    local fov_factor = math.tan(math.rad(camera.fov / 2))
    local scale = (screen_width / 2) / (fov_factor * z3d)
    
    return center_x + x_rot * scale, center_y - y_rot * scale, z3d
end
```

### Connection Strength to Depth Mapping
```lua
function map_strength_to_depth(strength)
    -- Strong connections closer to viewer
    local depth_min, depth_max = -5, 5
    return depth_max - (strength * (depth_max - depth_min))
end
```

### Neural Network Forward Pass
```lua
function forward(inputs)
    local activations = {inputs}
    
    for layer_idx = 1, #self.layers do
        local layer_output = {}
        for neuron_idx = 1, #self.layers[layer_idx].neurons do
            local neuron = self.layers[layer_idx].neurons[neuron_idx]
            local output = neuron:forward(activations[layer_idx])
            table.insert(layer_output, output)
        end
        table.insert(activations, layer_output)
    end
    
    return activations[#activations]
end
```

## Configuration Files

### Love2D Configuration (`conf.lua`)
```lua
function love.conf(t)
    t.title = "AI Playground"
    t.window.width = 1400
    t.window.height = 900
    t.window.resizable = true
    t.modules.audio = false  -- Disable unused modules
    t.console = true         -- Enable console output
end
```

### Topic Configuration (`scripts/claude_topics_config.sh`)
```bash
declare -A TOPIC_RESUME=(
    [type]="resume_generation"
    [priority_weights]="10,19,28,37,46,55,64,73,82,91,100"
    [scan_patterns]="*.md,*.txt,*.lua,*.py,*.js,*.sh"
    [output_format]="structured_resume"
)
```

## Event System

### Application Events
```lua
-- Love2D Callbacks
love.load()           -- Initialize application
love.update(dt)       -- Update game state
love.draw()           -- Render frame
love.keypressed(key)  -- Handle keyboard input
love.mousepressed(x, y, button)  -- Handle mouse clicks
```

### Custom Events
```lua
-- Network Events
"network_forward"     -- Forward pass completed
"network_training"    -- Training step executed
"weights_randomized"  -- Network reinitialized

-- UI Events  
"panel_dragged"       -- Panel position changed
"view_mode_changed"   -- Visualization mode switched
"narrator_toggled"    -- AI narrator enabled/disabled
```

## Performance Considerations

### Rendering Optimization
- **Depth Sorting**: Render far-to-near for proper transparency
- **Culling**: Skip off-screen or fully transparent objects
- **LOD**: Use simpler representations for distant objects
- **Batching**: Group similar rendering operations

### Memory Management
- **Panel Caching**: Reuse panel render targets
- **Message Limiting**: Cap chat log message history
- **Graph Pruning**: Clean old computation graph nodes

### Update Frequency
- **Network State**: Update on forward/training passes only
- **3D Animation**: Continuous for smooth rotation
- **UI Elements**: Only when user interaction occurs

## Extension Points

### Adding New Visualizations
1. Create renderer class in `src/visualization/`
2. Implement required interface methods
3. Register with layout manager in `main.lua`
4. Add to view mode cycling

### Adding Intelligence Topics
1. Define topic in `scripts/claude_topics_config.sh`
2. Add analysis logic to `claude_intelligence_integration.sh`
3. Update help text and documentation

### Network Architecture Extensions
1. Extend base classes in `libs/neural/`
2. Add new activation functions or layer types
3. Update visualization to handle new features

## Debugging and Logging

### Debug Output
```lua
-- Enable debug prints
local DEBUG = true
if DEBUG then print("Debug: " .. message) end
```

### Error Handling
```lua
-- Safe method calls
local success, result = pcall(risky_function, args)
if not success then
    log_error("Function failed: " .. result)
    return fallback_value
end
```

### Performance Monitoring
```lua
-- Frame time tracking
local frame_start = love.timer.getTime()
-- ... rendering code ...
local frame_time = love.timer.getTime() - frame_start
if frame_time > 0.016 then  -- > 16ms = < 60fps
    print("Slow frame: " .. frame_time)
end
```

## Enhanced Computation Tracking System

### Overview

The AI Playground includes a comprehensive backward pass system that creates a **tree-pyramid-like structure** to track all decision pathways during neural network training. This provides unprecedented visibility into the gradient flow and decision-making process of neural networks.

### Key Features

#### 🌳 **Decision Tree Visualization**
- **Tree-pyramid structure** that organizes computation nodes by layers
- **Complete pathway tracking** from inputs through weights, operations, activations, to loss
- **Visual gradient flow** showing how gradients propagate backward through every decision point
- **Interactive exploration** of individual nodes and their contribution pathways

#### 🔄 **Comprehensive Computation Graph**
- **Full operation tracking**: Every mathematical operation is recorded as a graph node
- **Gradient contribution analysis**: Track how much each operation contributes to the final gradient
- **Path tracing**: Follow the complete journey of gradients from loss back to inputs
- **Decision pathway mapping**: Understand which paths have the most impact on learning

#### 🎨 **Multi-View Visualization System**
1. **Network View**: Traditional neural network visualization with enhanced gradient information
2. **Gradient Flow View**: Animated visualization of gradient propagation with pathway tracing
3. **Decision Tree View**: Hierarchical view of the computation graph organized by operation type
4. **Combined View**: All visualizations simultaneously for complete understanding

### Technical Implementation

#### Core Components

1. **ComputationGraph** (`libs/neural/computation_graph.lua`)
   - Node-based graph structure tracking all operations
   - Comprehensive backward pass implementation
   - Gradient path analysis and decision tree generation

2. **Enhanced Neuron** (`libs/neural/neuron.lua`)
   - Graph-aware forward propagation
   - Detailed operation breakdown (input×weight, bias addition, activation)
   - Per-operation gradient tracking

3. **Enhanced Network** (`libs/neural/network.lua`)
   - Network-wide computation tracking
   - Comprehensive backward pass with full pathway analysis
   - Decision tree organization by computational layers

4. **Visualization Components**
   - **GradientVisualizer**: Animated gradient flow with path highlighting
   - **DecisionTreeRenderer**: Interactive tree structure visualization
   - **NetworkRenderer**: Enhanced traditional view with gradient information

### Data Structure

The system creates a **tree-pyramid structure** where:
- **Leaves** = Input values and weight parameters
- **Branches** = Mathematical operations (multiply, add, activation)
- **Root** = Loss function
- **Pathways** = Complete gradient flow routes from loss to every parameter

Each pathway represents a **decision chain** showing exactly how each input/weight influences the final loss through the sequence of operations.

### Usage

#### Interactive Controls

```bash
love .  # Start the visual application
```

**Keyboard Controls:**
- `G` - Toggle computation graph tracking ON/OFF
- `V` - Cycle through view modes (network → gradient → tree → all)
- `T` - Perform training step with backward pass analysis
- `SPACE` - Run forward pass (with/without tracking based on mode)
- `R` - Randomize network weights

#### Programmatic Usage

```lua
local Network = require('libs/neural/network')

-- Create network and enable tracking
local network = Network:new()
network:add_layer(3)  -- Input
network:add_layer(4, "sigmoid")  -- Hidden
network:add_layer(2, "sigmoid")  -- Output

-- Enable comprehensive tracking
network:enable_computation_tracking(true)

-- Train with full analysis
local loss, predicted = network:train_step(inputs, targets)

-- Get complete backward pass information
local analysis = network:get_comprehensive_backward_info()
local decision_tree = analysis.decision_tree
local gradient_paths = analysis.gradient_flow_paths
local contributions = analysis.gradient_contributions
```

### Understanding the Output

#### Decision Tree Structure
```
Layer 1: [input:3, weight:12, bias:4]     ← Parameter nodes
Layer 2: [multiply:12]                    ← Input×Weight operations  
Layer 3: [add:4]                          ← Weighted sum + bias
Layer 4: [activation:4]                   ← Activation functions
Layer 5: [loss:1]                         ← Final loss computation
```

#### Gradient Flow Paths
Each path shows the complete route a gradient takes:
```
loss → activation → add → multiply → weight
loss → activation → add → multiply → input
loss → activation → add → bias
```

#### Gradient Contributions
For each node, see:
- **Total gradient magnitude**: How much this node affects the loss
- **Path contributions**: Breakdown by different gradient pathways
- **Operation breakdown**: Analysis by operation type

### Educational Benefits

#### **Complete Transparency**
- See **every single operation** that affects the gradient
- Understand **exactly why** certain weights change more than others
- Visualize **all decision pathways** that influence learning

#### **Intuitive Understanding**
- **Tree structure** makes the computation hierarchy clear
- **Animated gradients** show the backpropagation process in real-time
- **Interactive exploration** lets you click on any node to trace its impact

#### **Problem Shape Analysis**
- Identify **gradient bottlenecks** and vanishing gradient issues
- See **which pathways dominate** the learning process
- Understand **network capacity** and information flow patterns

### Technical Validation

The enhanced system maintains **mathematical equivalence** with standard backpropagation while providing complete visibility:
- ✅ Identical loss values and parameter updates
- ✅ Same convergence behavior
- ✅ Equivalent computational complexity for training
- ✅ Additional insight without accuracy trade-offs

## Dependencies

### Required
- **Love2D** (11.0+): Game engine and windowing
- **Lua** (5.1+): Core scripting language
- **Bash** (4.0+): Shell scripts for analysis tools

### Optional
- **Git**: Version control and project tracking
- **OpenSSL**: Encryption for security analysis
- **Ollama/LLM**: Advanced AI narration (falls back to templates)

---

This technical reference provides the foundation for understanding, maintaining, and extending the AI Playground system.