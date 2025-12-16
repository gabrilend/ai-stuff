# AI Playground - Complete User Reference

## Quick Start

```bash
# Launch the application
love .

# Experience neural networks immediately
# Press: SPACE → N → 3
```

## Overview

The AI Playground is an interactive neural network visualization and analysis system featuring:

- **Neural Network Visualization** - Real-time 2D and 3D network displays
- **AI Narrator** - LLM-powered explanations of network behavior
- **Draggable Interface** - Fully customizable panel layout system
- **3D Stereographic View** - Immersive rotating visualization with depth
- **Advanced Analysis** - Deep computation tracking and gradient visualization

## Essential Controls

### Core Keyboard Shortcuts
```
SPACE    - Run forward pass with AI narration
T        - Perform training step with analysis
G        - Toggle computation graph tracking
V        - Cycle view modes (Network → Gradient → Tree → 3D → All)
3        - Quick switch to 3D stereographic view
N        - Toggle LLM narrator on/off
R        - Randomize network weights
L        - Reset panel layout to default
ESC      - Exit application
```

### Mouse Controls
```
Left Click + Drag   - Move panels by their headers
Right Click         - Context menu (when available)
Mouse Wheel         - Scroll chat log and panel contents
Interactive Drag    - Rotate 3D view when in 3D mode
```

## Core Features

### Neural Network Visualization

Watch your neural network operate in real-time with clear visual feedback:

- **Connection Strength**: Line thickness shows weight magnitude
- **Color Coding**: Green lines = positive weights, Red lines = negative weights
- **Interactive Neurons**: Click individual nodes for detailed information
- **Live Updates**: Network state changes reflect immediately

**Basic Usage**: Press `SPACE` to run a forward pass and see data flow through the network.

### AI Narrator System

Get real-time explanations of neural network operations:

- **Event-Driven**: Automatic commentary during forward passes and training
- **Educational Focus**: Technical concepts explained in accessible language
- **Context Aware**: Understands current network state and provides relevant insights

**Controls**:
- `N` - Toggle narrator on/off
- Chat appears in the rightmost panel with auto-scrolling
- Different message types (AI, System, Error) are color-coded

### 3D Stereographic Visualization

Experience your neural network as an immersive 3D structure:

**Visual Elements**:
- ◯ Input neurons    ◆ Hidden neurons    ◈ Output neurons
- ● Active neurons   ○ Inactive neurons
- Strong connections appear closer, weak ones fade into background
- Icons scale naturally with perspective distance

**3D Controls**:
```
3 or V         - Enter 3D mode
R              - Manual rotation step
A              - Toggle auto-rotation
1/2/3/4        - Control rotation speed and direction
Mouse Drag     - Interactive rotation control
```

### Draggable Panel System

Customize your workspace for optimal workflow:

**How to Use**:
1. Click and hold any panel header (blue bar with title)
2. Drag panels to different positions
3. Panels automatically snap to optimal zones
4. Press `L` to reset to default layout anytime

**Available Panels**:
- Neural Network (main visualization)
- 3D Stereographic View
- Gradient Flow Analysis
- Decision Tree Display
- AI Narrator Chat Log
- Network Information Panel

### Advanced Computation Analysis

Enable deep tracking of neural network operations:

**Access**: Press `G` to toggle computation tracking

**Capabilities**:
- **Gradient Flow**: Watch backpropagation in action
- **Decision Trees**: Hierarchical view of computation pathways
- **Operation Breakdown**: See every mathematical step
- **Performance Analysis**: Understand computational efficiency

## View Modes Explained

Press `V` to cycle through different visualization perspectives:

### Network Mode
Traditional 2D neural network diagram with clear connection visualization and interactive neuron selection.

### Gradient Mode
Animated visualization of gradient flow during training, showing backpropagation paths through network layers.

### Tree Mode
Hierarchical view of the computation graph, displaying operation dependencies and gradient contributions.

### 3D Mode
Immersive stereographic visualization with rotating perspective and depth-based connection importance.

### All Mode
Multiple visualizations displayed simultaneously for comprehensive analysis and comparison.

## Workflows and Use Cases

### Learning Neural Networks
1. Start with `SPACE` to see forward passes
2. Enable narrator (`N`) for explanations
3. Try training steps (`T`) to observe learning
4. Switch to 3D view (`3`) to understand structure
5. Enable tracking (`G`) for detailed analysis

### Analyzing Network Behavior
1. Use `G` to enable computation tracking
2. Cycle through view modes with `V` to see different perspectives
3. Arrange panels optimally using drag-and-drop
4. Use training steps (`T`) to study gradient flow
5. Compare different network states using weight randomization (`R`)

### Educational Demonstrations
1. Set up optimal panel layout for audience viewing
2. Enable auto-rotation (`A`) in 3D mode for dynamic presentations
3. Use narrator explanations to provide real-time commentary
4. Show different view modes to illustrate various concepts
5. Demonstrate training dynamics with multiple training steps

## Troubleshooting

### Application Won't Start
```bash
# Check Love2D installation
love --version

# Ensure you're in the correct directory
cd /path/to/ai-playground
love .
```

### No AI Narrations
- Press `N` to enable narrator
- Check that chat log panel is visible
- Try pressing `SPACE` to trigger a forward pass

### 3D View Issues
- Press `V` to cycle to 3D mode or `3` for direct access
- Try `R` for manual rotation if auto-rotation fails
- Ensure mouse interaction works by dragging in 3D view

### Missing Panels
- Press `L` to reset layout to default
- Check if panels are minimized or moved off-screen
- Try switching view modes with `V`

### Performance Issues
- Disable computation tracking with `G` if enabled
- Use simpler view modes (Network mode is most efficient)
- Reset layout (`L`) if too many panels are visible

## Tips for Advanced Usage

### Optimization Strategies
- Use computation tracking (`G`) sparingly for performance
- Arrange panels to minimize visual clutter
- Take advantage of auto-rotation for hands-free 3D viewing
- Use narrator explanations to understand complex operations

### Educational Applications
- Start students with basic forward passes before introducing training
- Use 3D mode to help visualize network topology
- Enable tracking to show the mathematics behind neural networks
- Combine multiple view modes for comprehensive understanding

### Research and Analysis
- Use decision tree mode to understand computation graphs
- Track gradient flow to identify training dynamics
- Compare different network architectures using weight randomization
- Document interesting states using the narrator commentary

## Configuration

### Basic Network Modification
Edit network architecture in `main.lua`:
```lua
demo_network:add_layer(3)    -- Input layer size
demo_network:add_layer(4)    -- Hidden layer size  
demo_network:add_layer(2)    -- Output layer size
```

### Visual Customization
Modify colors and themes in:
- `src/visualization/network_renderer.lua` - 2D visualization
- `src/visualization/stereo_3d_renderer.lua` - 3D visualization

### Window Settings
Edit `conf.lua` to adjust:
- Window size and fullscreen options
- Graphics performance settings
- Display refresh rates

---

**Remember**: The system becomes more intuitive with exploration. Start with basic operations (`SPACE`, `N`, `3`) and gradually discover advanced features as you become comfortable with the interface.