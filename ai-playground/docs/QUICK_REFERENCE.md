# AI Playground - Quick Reference Card

## 🚀 Getting Started (30 seconds)

```bash
# Launch the application
love .

# See neural network in action  
SPACE    # Run forward pass with AI explanation
T        # Train the network one step
3        # Switch to amazing 3D view
```

## ⌨️ Essential Keyboard Shortcuts

| Key | Action | Description |
|-----|--------|-------------|
| `SPACE` | Forward Pass | Run data through network + AI narration |
| `T` | Train Step | One training iteration with analysis |
| `G` | Track Toggle | Enable/disable detailed computation tracking |
| `V` | View Cycle | Network → Gradient → Tree → **3D** → All |
| `3` | 3D Mode | Jump directly to stereographic 3D view |
| `N` | Narrator | Toggle AI explanations on/off |
| `R` | Randomize | Reset all network weights randomly |
| `L` | Layout Reset | Return panels to default positions |
| `ESC` | Exit | Close application |

## 🎮 3D Stereographic View Controls

| Control | Action |
|---------|--------|
| `3` or `V` | Enter 3D mode |
| `R` | Rotate 45° manually |
| `A` | Auto-rotation on/off |
| `1` | Stop rotation |
| `2` | Forward rotation |
| `3` | Reverse rotation |
| `4` | Slow rotation |
| Mouse Drag | Interactive rotation |

**3D Visual Elements:**
- ◯ Input neurons  ◆ Hidden neurons  ◈ Output neurons
- ● Active neurons  ○ Inactive neurons
- **Closer = Stronger connections**  
- **Further = Weaker connections**

## 🖱️ Mouse Controls

| Action | Result |
|--------|--------|
| Drag Panel Header | Move panels around screen |
| Mouse Wheel | Scroll chat log |
| Click Neuron | Select and inspect (2D mode) |
| Drag in 3D | Rotate view manually |

## 🤖 AI Narrator Features

The AI explains everything happening in your neural network:
- **Automatic**: Narrates on SPACE, T, R, G key presses
- **Contextual**: Understands current network state  
- **Educational**: Technical but accessible explanations
- **Real-time**: Updates appear in chat log instantly

**Toggle**: Press `N` to turn on/off

## 📊 View Modes Explained

| Mode | What You See | Best For |
|------|-------------|----------|
| **Network** | Traditional 2D diagram | Understanding architecture |
| **Gradient** | Training visualization | Watching learning process |
| **Tree** | Computation breakdown | Deep technical analysis |
| **3D** | Rotating stereographic view | **Intuitive understanding** |
| **All** | Multiple views at once | Comprehensive analysis |

**Switch**: Press `V` to cycle through modes

## 🎛️ Panel System

**Available Panels:**
- Neural Network (main visualization)
- 3D Stereographic View  
- Gradient Flow Analysis
- Decision Tree Display
- AI Narrator Chat Log
- Network Information

**Controls:**
- **Move**: Drag blue panel headers
- **Auto-snap**: Panels snap to optimal positions
- **Reset**: Press `L` for default layout

## 🔧 Advanced Features

### Advanced Analysis  
```bash
G                                    # Toggle computation tracking
T                                    # Training step with analysis
SPACE + G                           # Forward pass with tracking
```

### Export and Documentation
```bash
# Access comprehensive guides
docs/USER_GUIDE.md                  # Complete manual
docs/STEREOGRAPHIC_3D_GUIDE.md     # 3D system guide
docs/TECHNICAL_REFERENCE.md        # Architecture details
```

## 🎯 Common Workflows

### **Learning Neural Networks**
1. `SPACE` - See forward pass
2. `N` - Enable AI narrator  
3. `T` - Try training
4. `3` - Switch to 3D view
5. `A` - Auto-rotate to see structure

### **Analyzing Network Behavior**
1. `G` - Enable computation tracking
2. `V` - Cycle through different views
3. `SPACE` - Run multiple forward passes
4. Watch AI explanations in chat log

### **Exploring in 3D**
1. `3` - Enter 3D mode
2. `A` - Enable auto-rotation
3. Mouse drag - Manual control
4. `R` - Step rotation for specific angles
5. Observe depth = connection strength

### **Demonstrating Capabilities**
1. `3` - Show impressive 3D visualization
2. `N` + `SPACE` - Enable AI narration for explanations
3. `V` - Cycle through different visualization modes
4. `G` + `T` - Show detailed computation analysis

## 🐛 Troubleshooting

| Problem | Solution |
|---------|----------|
| No AI narrations | Press `N` to enable narrator |
| 3D view not working | Press `3` or cycle with `V` |
| Panels missing | Press `L` to reset layout |
| App won't start | Run `love .` from project directory |
| Performance slow | Press `G` to disable computation tracking |

## 📁 Important Files

| File | Purpose |
|------|---------|
| `main.lua` | Main application |
| `love .` | Application launcher |
| `USER_GUIDE.md` | Complete user guide |
| `STEREOGRAPHIC_3D_GUIDE.md` | 3D visualization details |
| `TECHNICAL_REFERENCE.md` | Technical architecture and APIs |

## 💡 Pro Tips

1. **Start Simple**: Use `SPACE` and `N` for basic exploration
2. **3D First**: The 3D view is often the most intuitive way to understand networks
3. **Drag Panels**: Customize layout for your workflow
4. **Read AI Narrations**: They provide deep insights into what's happening
5. **Experiment**: Try different combinations of controls
6. **Use Training**: Press `T` repeatedly to watch learning in action

## 🎨 Visual Legend

**2D Network View:**
- Green lines = Strong positive connections
- Red lines = Strong negative connections  
- Line thickness = Connection strength
- Circle size = Neuron activation

**3D Stereographic View:**
- Distance from viewer = Connection importance
- Icon size = Natural perspective scaling
- Rotation = Reveals hidden structure patterns
- Depth fog = Visual hierarchy

---

**Remember**: This system becomes more intuitive with use. Start with `SPACE`, `N`, and `3` - then explore from there!