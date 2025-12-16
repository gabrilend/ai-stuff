# Dark Volcano Phase 1 Demo - Game Design Document

## Overview

The Phase 1 demo serves as a comprehensive showcase of Dark Volcano's 
foundational systems through isolated, testable demonstrations. Each 
feature is presented independently to validate core mechanics, visual 
style, and technical architecture before integration. The demo provides
stakeholder validation and development milestone verification.

## Demo Architecture

### Main Menu Structure
```
DARK VOLCANO - PHASE 1 DEMO
├── Formation System Demo
├── Visual Style Demo  
├── Unit Classes Demo
├── AI Personality Demo
├── Item Gravity Demo
├── Combat System Demo
├── GPU Architecture Demo
├── Animation System Demo
├── Configuration Panel
└── Integrated Showcase
```

### Demo Navigation
- **Arrow Keys / WASD**: Navigate menu options
- **Enter / Space**: Select demo
- **Escape**: Return to main menu from any demo
- **F1**: Open configuration panel from any demo
- **F11**: Toggle fullscreen mode

## Individual Demo Specifications

### Demo 1: Formation System Showcase

**Purpose**: Validate 3x3 grid formations and aura mechanics

**Interface**:
- Large 3x3 grid with drag-and-drop unit placement
- Formation type indicator (Circle/Box/Invalid)
- Aura visualization with colored overlays
- Unit count display and formation validation

**Interactions**:
- Click unit portrait to select for placement
- Drag units onto grid positions
- Right-click to remove units from grid
- Formation auto-detection with visual feedback

**Test Scenarios**:
1. **Circle Formation Test**: Place exactly 7 units in cross pattern
   - Positions: 2,4,5,6,8 plus 1,3 or 7,9
   - All units glow with persistent aura effect
   - Display: "Circle Formation - 7 Enhanced Units"

2. **Box with Aura Test**: Place 5-9 units with center aura unit
   - Center position (5) must contain aura-capable unit
   - Affected positions (2,4,6,8) glow when occupied
   - Display: "Box Formation - X Enhanced + Y Normal Units"

3. **Box without Aura Test**: Place 1-9 units with no center aura
   - Any positions except center aura configuration
   - No special effects, pure unit count advantage
   - Display: "Box Formation - X Normal Units"

**Success Criteria**:
- Formation detection works instantly and accurately
- Aura effects are visually clear and distinct
- Power balance indicators show all formations as viable

**Configuration Options**:
- Aura intensity slider (visual feedback strength)
- Grid size scaling
- Formation validation strictness toggle

---

### Demo 2: Tron Visual Style Showcase

**Purpose**: Establish and validate Tron-inspired aesthetic

**Interface**:
- Rotating camera view of sample battle scene
- Visual effect intensity controls
- Color scheme selector
- Model complexity toggle

**Visual Elements**:
- Triangle and quad-based unit models with bright edge outlines
- Neon blue/cyan primary colors with accent highlighting
- Grid-pattern ground textures with subtle animation
- Particle effects for weapons and abilities

**Interaction Scenarios**:
1. **Static Model Display**: Showcase individual unit designs
   - 3-5 different FFTA class models (Soldier, Mage, Thief)
   - Rotating display with zoom controls
   - Edge glow intensity adjustment

2. **Animation Preview**: Basic movement and combat animations
   - Units walking in formation patterns
   - Simple attack animations with laser effects
   - Idle state animations with breathing/energy pulse

3. **Environmental Showcase**: Background and terrain elements
   - Dark background with subtle grid patterns
   - Glowing waypoint markers and UI elements
   - Electronic/digital particle effects

**Success Criteria**:
- Distinct Tron aesthetic that maintains readability
- Performance stable with multiple units and effects
- Visual coherence across all elements

**Configuration Options**:
- Glow intensity slider
- Color scheme presets (Blue/Cyan, Red/Orange, Green/Yellow)
- Effect density (Full, Reduced, Minimal)
- Model detail level (High, Medium, Low)

---

### Demo 3: Unit Classes System

**Purpose**: Demonstrate FFTA-inspired unit differentiation

**Interface**:
- Unit selection panel with 3-5 starter classes
- Stat comparison display
- Equipment preview system
- Ability demonstration area

**Featured Classes**:
1. **Soldier**: Balanced melee combatant
   - Medium stats across all categories
   - Sword + shield equipment
   - Basic attack and defend abilities

2. **Black Mage**: Elemental magic specialist  
   - High magic power, low physical defense
   - Staff + robes equipment
   - Fire/ice/lightning spell effects

3. **Thief**: Speed and utility specialist
   - High speed, low durability
   - Dual knives + light armor
   - Steal and movement abilities

4. **White Mage**: Healing and support
   - High magic power, healing focus
   - Staff + white robes
   - Cure and protective spell effects

5. **Archer**: Ranged physical damage
   - High accuracy, moderate attack
   - Bow + light armor  
   - Long-range attack abilities

**Demonstration Features**:
- Click class to see detailed stat breakdown
- Equipment visualization on unit models
- Ability effect previews (non-interactive)
- Comparative analysis between classes

**Success Criteria**:
- Clear visual and statistical differentiation between classes
- Equipment changes visibly affect unit appearance
- Ability effects are distinct and thematically appropriate

**Configuration Options**:
- Stat display format (bars, numbers, percentages)
- Equipment detail level
- Animation speed controls

---

### Demo 4: AI Personality Matrix

**Purpose**: Showcase 4-color personality system and decision-making

**Interface**:
- 2D personality matrix visualization (X/Y axes)
- Unit personality adjustment sliders
- Decision scenario simulator
- Behavioral pattern display

**Personality Types**:
- **Red (Aggressive)**: Direct, confrontational solutions
- **Blue (Defensive)**: Cautious, protective strategies  
- **Green (Balanced)**: Adaptive, versatile approaches
- **Yellow (Creative)**: Unconventional, innovative tactics

**Interactive Scenarios**:
1. **Combat Decision Test**: Present tactical situation
   - Enemy approaching from multiple directions
   - Show how different personalities choose targets
   - Display decision percentages for each option

2. **Resource Management Test**: Limited resources scenario
   - Scarce healing items available
   - Demonstrate personality-based priority systems
   - Show risk vs. reward calculations

3. **Movement Pattern Test**: Navigation challenge
   - Obstacles and multiple path options
   - Display Dijkstra mapping results
   - Show personality influence on pathfinding

**Visualization Features**:
- Real-time personality coordinate display
- Decision tree animations showing thought process
- Heat map overlays for spatial awareness
- Percentage breakdowns for choice likelihood

**Success Criteria**:
- Personalities produce clearly distinct behaviors
- Decision-making feels logical and consistent
- Visual feedback helps players understand AI reasoning

**Configuration Options**:
- Personality coordinate manual adjustment
- Decision speed controls
- Visualization detail level
- AI reasoning display toggle

---

### Demo 5: Item Gravity Mechanics

**Purpose**: Demonstrate unique item physics and will-based carrying

**Interface**:
- Test arena with units and items
- Gravity timer displays
- Item state indicators
- Carrier assignment controls

**Mechanics Demonstration**:
1. **Basic Gravity Test**: Drop items without carriers
   - Items begin sinking timer countdown
   - Visual representation of "2 inches per 10 seconds"
   - Items disappear when reaching "core" threshold

2. **Carrier System Test**: Assign items to unit carriers
   - Items remain stable when held by units
   - Transfer items between units
   - Show weight/capacity limitations

3. **Death and Recovery Test**: Unit death scenarios
   - Items drop when carrier units are defeated
   - Recovery time pressure demonstration
   - Multiple item priority decisions

**Visual Effects**:
- Sinking animation with particle effects
- Carrier link visualization (energy tethers)
- Timer countdown displays
- Core destination glow effect

**Success Criteria**:
- Gravity mechanics create meaningful time pressure
- Carrier system is intuitive and responsive
- Visual feedback clearly communicates item state

**Configuration Options**:
- Gravity speed multiplier
- Timer visibility toggle
- Animation intensity controls
- Item value display options

---

### Demo 6: Tick-Based Combat System

**Purpose**: Showcase damage calculation and visual feedback systems

**Interface**:
- Combat arena with opposing units
- Health bar overlays (linear gradient + chunked display)
- Damage calculation visualization
- Combat speed controls

**Combat Features**:
1. **Dual Health System Display**:
   - Hidden linear gradient (actual health)
   - Visible "4 quarters to heart" chunked display
   - Final swing reconciliation demonstration

2. **Laser Weapon Effects**:
   - Arm-length quarterstaff-like energy weapons
   - Explosion and ricochet animations on impact
   - Hover and reformation sequence

3. **Rate-Based Damage Application**:
   - Damage applied as continuous rates
   - Visual ticking countdown of health chunks
   - Discrete health bar updates

**Test Scenarios**:
- Single unit vs single unit combat
- Formation-based combat with aura effects
- Multiple unit engagement with overlapping attacks
- Weapon type variety showcase

**Success Criteria**:
- Combat feels satisfying and visually impressive
- Health systems are clear and understandable
- Weapon effects enhance rather than distract from combat

**Configuration Options**:
- Combat speed multiplier
- Health bar visibility options
- Weapon effect intensity
- Damage number display toggle

---

### Demo 7: GPU Architecture Showcase

**Purpose**: Demonstrate multi-core rendering and GPU gamestate

**Interface**:
- Performance monitoring dashboard
- CPU core utilization display
- GPU memory usage indicators
- Rendering pipeline visualization

**Technical Demonstrations**:
1. **Multi-Core Screen Segmentation**:
   - Visual representation of screen divided by CPU core count
   - Core allocation indicators
   - Load balancing demonstration

2. **GPU Gamestate Calculation**:
   - Gamestate processing entirely on graphics card
   - Comparison with CPU-based calculation fallback
   - Performance metrics display

3. **Parallel Rendering Pipeline**:
   - Multiple render targets processing simultaneously
   - Frame rate optimization demonstration
   - Memory allocation efficiency

**Success Criteria**:
- Performance benefits clearly visible and measurable
- System gracefully handles GPU vs CPU fallbacks
- Architecture supports planned scaling requirements

**Configuration Options**:
- CPU core count override
- GPU processing toggle
- Performance overlay detail level
- Benchmark mode activation

---

### Demo 8: Procedural Animation System

**Purpose**: Validate Vulkan-based real-time animation optimization

**Interface**:
- Animation test arena
- Optimization problem visualization
- Physics constraint displays
- Animation quality controls

**Animation Features**:
1. **Hinges and Joints System**:
   - Real-time physics optimization for unit movement
   - Joint constraint visualization
   - Stabilizing inertia effects

2. **Dynamic Problem Solving**:
   - Animation goals vs. physics constraints
   - Optimization process visualization
   - Multiple solution comparison

3. **Performance Scaling**:
   - Single unit vs. multiple unit animation
   - Quality degradation under load
   - Vulkan compute shader utilization

**Success Criteria**:
- Animations feel natural and responsive
- Optimization problems solved in real-time
- System scales well with multiple animated units

**Configuration Options**:
- Animation quality presets
- Physics constraint strictness
- Optimization iteration limits
- Vulkan feature toggles

---

## Configuration Panel

### Global Demo Settings
- **Rendering Quality**: Ultra, High, Medium, Low, Minimal
- **Performance Monitoring**: FPS, Frame Time, Memory Usage
- **Debug Overlays**: Wireframes, Collision Boxes, AI State
- **Audio**: Master Volume, SFX, Music (Phase 1: minimal audio)

### Development Tools
- **Screenshot Capture**: F12 key binding
- **Performance Logging**: Automatic benchmark recording
- **Error Reporting**: Debug log export functionality
- **Reset Options**: Individual demo reset or full demo reset

## Integrated Showcase

**Purpose**: Demonstrate multiple systems working together

**Scenario**: "Formation Combat Test"
- Create party with mixed formations
- Deploy against AI-controlled enemies
- Showcase all systems in coordinated demonstration
- 2-3 minute guided experience highlighting key features

**Success Criteria**:
- All individual systems work together seamlessly
- Integration demonstrates emergent complexity
- Performance remains stable with all systems active

## Technical Requirements

### Minimum System Requirements
- CPU: 4-core processor (for multi-core rendering demo)
- GPU: DirectX 11 compatible with Compute Shader support
- RAM: 4GB minimum
- Storage: 2GB available space

### Recommended System Requirements  
- CPU: 6+ core processor for full multi-core demonstration
- GPU: Vulkan 1.0 compatible for full procedural animation features
- RAM: 8GB for optimal performance monitoring
- Storage: 4GB for development tools and logging

### Platform Support
- Windows 10+ (primary target)
- Linux (secondary target if Raylib supports)
- macOS (stretch goal)

## Demo Completion Metrics

Each demo includes automated validation:
- **Functional Tests**: Core mechanics work as designed
- **Performance Tests**: Frame rate and memory usage within targets
- **Visual Tests**: Art style consistency and effect quality
- **Usability Tests**: Interface clarity and ease of navigation

## Documentation and Training

**User Guide**: Simple controls and navigation explanation
**Developer Notes**: Technical implementation details for each demo
**Stakeholder Summary**: High-level feature validation document
**Issue Tracking**: Direct links to relevant Phase 1 issues for each demo

This demo structure ensures every Phase 1 deliverable is thoroughly 
validated in isolation while providing a comprehensive preview of Dark 
Volcano's unique gameplay and technical innovations.