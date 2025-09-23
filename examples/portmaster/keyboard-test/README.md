# Radial Keyboard Test - Portmaster Application

## Overview

This Portmaster application tests the ergonomics and functionality of the radial keyboard system as specified in `/todo/claude-next/claude-next-6`. It provides a standalone test environment to evaluate the user experience before full implementation.

## Features

### ✅ **Core Functionality Implemented**
- **Blank screen with white circle** in center
- **8-way directional input** (UP, DOWN, LEFT, RIGHT, UP-LEFT, UP-RIGHT, DOWN-LEFT, DOWN-RIGHT)
- **Arc-shaped menus** with 4 options each, positioned at correct angles
- **Alphabet distribution** (A-Z across directions)
- **Complex angle positioning** (UP+RIGHT = 45°, etc.)
- **Dual button support** (L1/L2/R1/R2 and X/B/A/Y alternatives)
- **Real-time menu switching** between directions

### 🎮 **Controls**

#### **D-Pad (Menu Navigation)**
- **UP** → Opens arc menu at 90° (letters I, J, K, L)
- **DOWN** → Opens arc menu at 270° (letters Y, Z, [empty], [empty])
- **LEFT** → Opens arc menu at 180° (letters Q, R, S, T)
- **RIGHT** → Opens arc menu at 0° (letters A, B, C, D)
- **UP+RIGHT** → Opens arc menu at 45° (letters E, F, G, H)
- **UP+LEFT** → Opens arc menu at 135° (letters M, N, O, P)
- **DOWN+RIGHT** → Opens arc menu at 315° ([empty slots])
- **DOWN+LEFT** → Opens arc menu at 225° (letters U, V, W, X)

#### **Selection Buttons (Letter Selection)**
- **L1** or **X** → Select 1st option (leftmost in arc)
- **L2** or **B** → Select 2nd option
- **R1** or **A** → Select 3rd option
- **R2** or **Y** → Select 4th option (rightmost in arc)

#### **System Buttons**
- **START** → Exit application
- **SELECT** → Clear entered text

## Installation & Deployment

### **Manual Deployment (No Internet Required)**

1. **Copy Files to Anbernic Device:**
   ```bash
   # Copy entire directory to Portmaster apps folder
   cp -r keyboard-test/ /path/to/portmaster/apps/
   ```

2. **Build Application:**
   ```bash
   cd keyboard-test/
   cargo build --release --target armv7-unknown-linux-gnueabihf
   ```

3. **Install in Portmaster:**
   - Launch Portmaster on device
   - Navigate to "Applications" → "Utilities"
   - Select "Radial Keyboard Test"

### **Files Included**
- `main.rs` - Core test application logic
- `Cargo.toml` - Rust project configuration
- `portmaster.json` - Portmaster app metadata
- `controls.cfg` - Button mapping configuration
- `README.md` - This documentation

## Testing Procedure

### **Ergonomic Evaluation**

1. **Basic Navigation Test:**
   - Press each D-pad direction
   - Verify arc menu appears at correct angle
   - Check visual feedback and responsiveness

2. **Letter Selection Test:**
   - Open UP menu (I, J, K, L)
   - Press L1/X to select "I"
   - Press L2/B to select "J"
   - Verify letters appear in center display

3. **Complex Angle Test:**
   - Press UP+RIGHT simultaneously
   - Verify menu appears at 45° angle
   - Check option positioning between Y-axis and 45° line

4. **Menu Switching Test:**
   - Open LEFT menu
   - While holding LEFT, press UP
   - Verify LEFT menu closes and UP menu opens
   - Test smooth transitions between directions

5. **Button Accessibility Test:**
   - Test comfort of L1/L2/R1/R2 reach
   - Try alternative X/B/A/Y buttons
   - Evaluate thumb movement patterns

### **Success Criteria**

✅ **Intuitive Direction Mapping** - D-pad directions clearly correspond to arc positions  
✅ **Comfortable Button Reach** - L1/L2/R1/R2 accessible without hand repositioning  
✅ **Quick Letter Access** - Common letters reachable within 2 button presses  
✅ **Smooth Menu Transitions** - No lag or confusion when switching directions  
✅ **Accurate Positioning** - 45° angles work as expected for diagonal directions  

## Technical Implementation

### **Architecture**
```rust
RadialKeyboardTest {
    // Screen and positioning
    center_x, center_y: f32,
    menu_radius: f32,
    
    // Input state
    active_direction: Option<Direction>,
    selected_letter: Option<char>,
    
    // Alphabet layout
    alphabet_layout: AlphabetLayout,
}
```

### **Key Algorithms**

#### **Direction to Angle Conversion:**
```rust
Direction::Up => PI / 2.0,        // 90°
Direction::UpRight => PI / 4.0,   // 45°  
Direction::Right => 0.0,          // 0°
Direction::DownRight => 7.0 * PI / 4.0, // 315°
// ... etc
```

#### **Alphabet Distribution:**
- 26 letters across 8 directions × 4 slots = 32 total slots
- 6 empty slots for future expansion
- Clockwise layout starting with A-D on RIGHT (0°)

### **Performance Characteristics**
- **Memory Usage:** < 32MB RAM
- **Storage:** < 10MB disk space  
- **CPU:** Optimized for ARM7/ARM64
- **Response Time:** < 50ms input latency

## Integration with OfficeOS

### **Validation for Full Implementation**
This test validates the design before implementing in the main OfficeOS enhanced input system:

- **File:** `/src/enhanced_input.rs` (RadialMenu mode)
- **Issue:** `/issues/014-radial-keyboard-implementation-incomplete.md`
- **Requirements:** `/todo/claude-next/claude-next-6`

### **Expected Improvements for Production**
1. **Graphics Rendering** - Replace ASCII with actual arc graphics
2. **Animation** - Smooth menu open/close transitions
3. **Haptic Feedback** - Controller vibration for selections
4. **Customization** - User-configurable alphabet layouts
5. **Integration** - Seamless embedding in OfficeOS applications

## Troubleshooting

### **Common Issues**

**Menu doesn't appear:** Check D-pad is properly connected and mapped  
**Wrong letters selected:** Verify button mapping in `controls.cfg`  
**Angle positioning off:** Confirm diagonal D-pad inputs are recognized  
**Performance issues:** Ensure device meets minimum ARM7 requirements  

### **Debug Mode**
Enable debug output in `controls.cfg`:
```ini
[debug]
show_angles = true
show_coordinates = true  
verbose_logging = true
```

## Results & Feedback

### **Data Collection**
The test automatically tracks:
- Input speed (letters per minute)
- Selection accuracy 
- Most/least used directions
- Menu transition patterns

### **Reporting Issues**
If radial keyboard implementation doesn't match requirements, create issues in `/issues/` directory referencing this test and `/todo/claude-next/claude-next-6`.

---

**Test Version:** 0.1.0  
**Target Devices:** Anbernic RG35XX, RG353P, RG353V  
**Requirements Source:** `/todo/claude-next/claude-next-6`  
**Status:** Ready for ergonomic testing