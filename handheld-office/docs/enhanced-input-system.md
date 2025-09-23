# Enhanced Input System Documentation

## Overview

The Handheld Office Enhanced Input System provides a sophisticated, configurable input method specifically designed for handheld gaming devices with limited buttons. It transforms the basic 4-button layout (A, B, L, R, D-pad) into a powerful text entry and navigation system supporting multiple input modes and controller types.

## Table of Contents

1. [System Architecture](#system-architecture)
2. [Controller Support](#controller-support)
3. [Input Modes](#input-modes)
4. [AI Image Integration](#ai-image-integration)
5. [P2P Collaboration Features](#p2p-collaboration-features)
6. [Configuration System](#configuration-system)
7. [Getting Started](#getting-started)
8. [Advanced Features](#advanced-features)
9. [API Reference](#api-reference)

> **Quick Reference**: See [Input Quick Reference Guide](input-quick-reference.md) for button layouts and common sequences.

## System Architecture

### Core Components

#### EnhancedInputManager
The central coordinator managing all input functionality:

```rust
pub struct EnhancedInputManager {
    pub config: InputConfig,
    pub current_mode: EnhancedInputMode,
    pub text_buffer: String,
    pub cursor_position: usize,
    pub edit_mode_state: EditModeState,
    
    // P2P mesh networking for document sharing
    pub p2p_manager: Option<P2PMeshManager>,
    pub shared_documents: Vec<SharedDocument>,
    pub collaboration_state: Option<CollaborationState>,
    
    // WiFi Direct P2P for AI image generation
    pub wifi_direct: Option<WiFiDirectP2P>,
    pub available_image_files: Vec<ImageFileEntry>,
    pub pending_image_requests: Vec<PendingImageRequest>,
}
```

#### InputConfig
User-configurable system supporting multiple controller types and layouts:

```rust
pub struct InputConfig {
    pub controller_type: ControllerType,
    pub keyboard_layouts: HashMap<String, KeyboardLayout>,
    pub edit_mode_settings: EditModeSettings,
    pub special_character_sets: HashMap<String, Vec<char>>,
    pub language_layouts: HashMap<String, LanguageLayout>,
}
```

## Controller Support

### Game Boy Style Controllers
- **Buttons**: A, B, SELECT, START, D-Pad
- **Input Method**: 4-option radial sectors with hierarchical navigation
- **Best For**: Simple text entry, retro gaming feel

```rust
// Example Game Boy configuration
let gameboy_manager = EnhancedInputManager::gameboy_style();
```

### SNES Style Controllers  
- **Buttons**: A, B, X, Y, L, R, SELECT, START, D-Pad
- **Input Method**: 6-option radial menus on D-pad directions
- **Best For**: Fast text entry, advanced users

```rust
// Example SNES configuration
let snes_manager = EnhancedInputManager::snes_style();
```

### Custom Controllers
- **Configurable**: User-defined button mappings
- **Flexible**: Adapt to any handheld device layout

## Input Modes

### 1. Navigation Mode
**Default state** - Navigate through interface elements

**Controls:**
- **D-pad**: Move between UI elements
- **A**: Select/confirm
- **B**: Back/cancel  
- **SELECT**: Enter edit mode
- **START**: Context menu

### 2. Edit Mode
**Text editing** with cursor navigation and input methods

**Entry:** Press SELECT button
**Exit:** Press SELECT again or auto-timeout (30 seconds)

**Controls in Edit Mode:**
- **D-pad**: Move cursor (up/down/left/right)
- **A**: Open one-time keyboard
- **B**: Backspace (delete previous character)
- **L/R**: Word-level cursor movement (optional)

**Features:**
- Real-time cursor position display
- Word wrap support
- Line number display (configurable)
- Auto-save on exit

### 3. One-Time Keyboard Mode
**Character selection** for single character input

**Entry:** Press A button while in edit mode
**Exit:** Automatic after character selection

**Game Boy Style:**
- Navigate sectors with D-pad (Up/Down/Left/Right)
- Each sector contains 4 characters
- Select character with A button

**SNES Style:**
- D-pad directions open radial menus (6 options each)
- A/B/X/Y/L/R select from current menu
- Instant character insertion

### 4. Radial Menu Mode (SNES)
**Fast character selection** using 6-button radial layout

**Radial Assignments:**
- **UP**: Uppercase letters (A-F, G-L, etc.)
- **DOWN**: Lowercase letters (a-f, g-l, etc.)  
- **LEFT**: Numbers (0-5, 6-9, symbols)
- **RIGHT**: Special characters (!@#$%^)

**Selection:**
- **A**: Option 1 (12 o'clock)
- **Y**: Option 2 (2 o'clock)  
- **B**: Option 3 (4 o'clock)
- **X**: Option 4 (8 o'clock)
- **L**: Option 5 (10 o'clock)
- **R**: Option 6 (6 o'clock)

### 5. Special Character Mode
**Extended character input** for symbols, emojis, and special text

**Features:**
- Access to special character sets defined in configuration
- Language-specific accented characters
- Emoji keyboard integration
- Mathematical symbols and currency

### 6. P2P Browser Mode
**Document sharing** through peer-to-peer mesh networking

**Controls:**
- **D-pad**: Navigate shared documents list
- **A**: Open/download selected document
- **B/SELECT**: Exit P2P browser
- **X**: Refresh peer discovery
- **Y**: Share current document

### 7. Collaboration Mode  
**Real-time document collaboration** with connected peers

**Features:**
- Live text synchronization between devices
- Cursor position sharing
- Conflict resolution for simultaneous edits
- Version history tracking

### 8. Image Menu Mode
**Image file management and AI generation**

**Entry:** L/R + D-pad direction for media functions, then A
**Exit:** SELECT button

**Controls:**
- **A**: Insert existing image file
- **B**: Create new AI image (if laptop connected)
- **X/Y**: Navigate image file categories
- **SELECT**: Return to previous mode

### 9. AI Image Prompt Mode
**AI-powered image generation** through laptop daemon connection

**Entry:** Select "Create AI image" from Image Menu
**Exit:** SELECT (cancel) or A (submit prompt)

**Features:**
- Real-time prompt typing with backspace (B button)
- Immediate placeholder insertion: `[AI_IMAGE_GENERATING:img_123]`
- Automatic replacement when generation complete
- Non-blocking operation - continue working during generation

## AI Image Integration

### Overview
The enhanced input system integrates seamlessly with AI image generation capabilities through WiFi Direct P2P connections to laptop daemons. This allows users to generate images using natural language prompts without requiring internet connectivity.

### Architecture
- **WiFi Direct P2P**: Direct device-to-device communication with laptops
- **Laptop Daemon**: AI computation backend running on paired laptop
- **Async Processing**: Non-blocking generation with placeholder system
- **Multiple AI Backends**: Support for Automatic1111, ComfyUI, Diffusers CLI, Ollama

### Image File Management
Images are organized by source type in dedicated directories:

```
./images/
├── paint/              # Paint program creations
├── ai_generated/       # AI-generated images  
├── shared/            # P2P shared images
└── downloads/         # External downloads
```

### Supported Image Sources
- **Paint Application**: Files created in integrated paint program
- **AI Generated**: Images created via laptop daemon AI services
- **Shared Files**: Images received via P2P file sharing
- **Downloaded**: Images from external sources

### Image Generation Workflow

#### 1. Access Image Menu
- Hold L/R + D-pad direction to access media functions
- Press A to open image menu

#### 2. Create AI Image
- Press B to select "Create new AI image" (only available when laptop connected)
- Option disappears automatically when not tethered

#### 3. Enter Prompt
- Type prompt using radial keyboard system
- Use B button for backspace/correction
- Press A to submit prompt

#### 4. Placeholder System
```rust
// Immediate insertion
[AI_IMAGE_GENERATING:img_1672531200]

// After completion (success)
[IMAGE:ai_generated_img_1672531200.png]

// After completion (failure)  
[AI_IMAGE_FAILED:error_message]
```

#### 5. Async Processing
- User can continue working while generation proceeds
- Background processing through WiFi Direct messages
- Automatic replacement when complete

### Message Protocol
```rust
MessageContent::ImageGenerationRequest {
    request_id: String,
    prompt: String,
    style: ImageStyle,        // "default", "photorealistic", "artistic"
    resolution: ImageResolution, // "512x512", "1024x1024"
    steps: u32,              // AI generation steps (20-50)
    guidance_scale: f32,     // Prompt adherence (7.5)
}
```

### Error Handling
- **Connection Lost**: Graceful degradation, option disappears
- **Generation Failed**: Clear error messages in placeholder
- **Timeout**: Automatic cleanup of pending requests
- **Storage Full**: Warning before generation starts

## P2P Collaboration Features

### Overview
The enhanced input system provides sophisticated peer-to-peer collaboration capabilities through mesh networking, enabling real-time document sharing and collaborative editing between handheld devices.

### P2P Architecture
- **Mesh Networking**: Automatic peer discovery and connection
- **Document Synchronization**: Real-time text sharing
- **Conflict Resolution**: Intelligent merge of simultaneous edits
- **Offline Capability**: No internet dependency

### P2P Browser Mode

#### Entry and Navigation
- Access via special key combination or menu system
- Automatically discovers nearby devices
- Lists shared documents from connected peers

#### Features
- **Document Discovery**: Browse documents shared by nearby devices
- **Live Updates**: Real-time list updates as peers join/leave
- **Category Filtering**: Filter by document type or peer
- **Download Management**: Background document downloads

### Collaboration Mode

#### Real-time Editing
- **Live Synchronization**: Text changes sync immediately
- **Cursor Sharing**: See where collaborators are editing
- **Conflict Resolution**: Automatic merge of simultaneous changes
- **Version History**: Track document evolution

#### Collaboration State Management
```rust
pub struct CollaborationState {
    pub session_id: String,
    pub participants: Vec<PeerDevice>,
    pub document_id: String,
    pub local_changes: Vec<DocumentChange>,
    pub pending_sync: Vec<SyncOperation>,
}
```

#### Document Sharing
- **Automatic Sharing**: Documents can be auto-shared with trusted peers
- **Permission Control**: Granular access control per document
- **Selective Sync**: Choose which documents to share/sync
- **Bandwidth Management**: Intelligent syncing based on connection quality

### Security Features
- **Relationship-specific Encryption**: Each device pair has unique keys
- **Trust Management**: Establish trusted peer relationships
- **Access Control**: Fine-grained document access permissions
- **Air-gapped Operation**: No external network dependencies

### P2P Integration with AI Features
- **Shared AI Images**: AI-generated images can be shared between devices
- **Collaborative Prompts**: Multiple users can contribute to AI prompts
- **Resource Sharing**: Share access to laptop daemon AI capabilities
- **Distributed Generation**: Load balance AI generation across multiple laptops

## Configuration System

### JSON Configuration Files

Store input configurations in JSON format for easy customization:

```json
{
  "controller_type": {
    "GameBoy": {
      "buttons": {
        "a": {
          "primary_action": "Select",
          "secondary_action": "OpenKeyboard",
          "edit_mode_action": "OpenKeyboard"
        },
        "select": {
          "primary_action": "ToggleMode",
          "secondary_action": "EnterEditMode", 
          "edit_mode_action": "ExitEditMode"
        }
      }
    }
  },
  "keyboard_layouts": {
    "english": {
      "name": "English (Game Boy)",
      "sectors": [
        {
          "direction": "Up",
          "characters": ["a", "b", "c", "d"],
          "action_type": "CharacterInput"
        }
      ]
    }
  }
}
```

### Loading Configurations

```rust
// Load from file
let config = InputConfig::load_from_file("config/my_input.json")?;
let manager = EnhancedInputManager::new(config);

// Use built-in defaults
let manager = EnhancedInputManager::gameboy_style();
let manager = EnhancedInputManager::snes_style();
```

### Edit Mode Settings

Customize edit mode behavior:

```json
{
  "edit_mode_settings": {
    "cursor_blink_rate_ms": 500,
    "auto_exit_timeout_ms": 30000,
    "word_wrap": true,
    "show_line_numbers": false,
    "highlight_current_line": true,
    "tab_size": 4,
    "vim_mode": false
  }
}
```

## Getting Started

### Basic Usage

```rust
use handheld_office::{EnhancedInputManager, UniversalButton, InputResult};

// Create input manager
let mut input_manager = EnhancedInputManager::gameboy_style();

// Handle button press
let results = input_manager.handle_button_input(UniversalButton::A, true);

// Process results
for result in results {
    match result {
        InputResult::TextInput { text } => {
            println!("Text updated: {}", text);
        },
        InputResult::InsertText { text } => {
            // Handle AI image placeholders, file insertions
            println!("Inserting: {}", text);
        },
        InputResult::ReplaceText { find, replace } => {
            // Handle AI image completion replacements
            println!("Replacing '{}' with '{}'", find, replace);
        },
        InputResult::StatusMessage { message } => {
            // Handle P2P status, AI generation status
            println!("Status: {}", message);
        },
        InputResult::ModeChange { new_mode } => {
            println!("Mode changed to: {:?}", new_mode);
        },
        _ => {}
    }
}

// Get current text
println!("Current text: {}", input_manager.text_buffer);
```

### Interactive Demo

Run the interactive demonstration:

```bash
cargo run --example enhanced_input_demo
```

**Demo Features:**
- Controller type selection (Game Boy vs SNES)
- Real-time input simulation
- Mode switching demonstration
- Configuration save/load

### Typical Workflow

1. **Start in Navigation Mode**
   - Use D-pad to navigate interface
   - Press A to select items

2. **Enter Edit Mode**
   - Press SELECT to start text editing
   - Cursor appears, ready for input

3. **Add Text**
   - Press A to open character keyboard
   - Navigate and select characters
   - Use B for backspace

4. **Navigate Text**
   - Use D-pad to move cursor
   - Edit at any position

5. **Exit Edit Mode**
   - Press SELECT to exit
   - Or wait for auto-timeout

## Advanced Features

### Special Actions

Configure advanced input combinations:

```json
{
  "special_actions": [
    {
      "trigger": {
        "LongPress": {
          "button": "A",
          "duration_ms": 1000
        }
      },
      "result": {
        "OpenKeyboard": {
          "layout": "symbols"
        }
      }
    },
    {
      "trigger": {
        "ButtonCombination": {
          "buttons": ["L", "R"]
        }
      },
      "result": {
        "OpenKeyboard": {
          "layout": "emoji"
        }
      }
    }
  ]
}
```

### Multi-Language Support

Define language-specific layouts:

```json
{
  "language_layouts": {
    "es": {
      "language_code": "es",
      "display_name": "Español",
      "character_sets": {
        "lowercase": ["a", "b", "c", "ñ", "..."],
        "accented": ["á", "é", "í", "ó", "ú"]
      },
      "special_combinations": {
        "n~": "ñ",
        "a'": "á"
      }
    }
  }
}
```

### Custom Character Sets

Add special characters and emojis:

```json
{
  "special_character_sets": {
    "symbols": ["!", "@", "#", "$", "%", "^", "&", "*"],
    "emojis": ["😀", "😎", "👍", "❤️", "🎮", "🔥"],
    "math": ["±", "∞", "∑", "∆", "π", "√"]
  }
}
```

### Performance Optimization

For battery-powered devices:

```json
{
  "edit_mode_settings": {
    "auto_exit_timeout_ms": 15000,  // Shorter timeout
    "cursor_blink_rate_ms": 1000,   // Slower blink
    "vim_mode": true                // Efficient editing
  }
}
```

## API Reference

### Core Types

#### UniversalButton
```rust
pub enum UniversalButton {
    A, B, X, Y,           // Face buttons
    L, R,                 // Shoulder buttons  
    Select, Start,        // System buttons
    Up, Down, Left, Right // D-pad
}
```

#### InputResult
```rust
pub enum InputResult {
    TextInput { text: String },
    InsertText { text: String },
    ReplaceText { find: String, replace: String },
    ModeChange { new_mode: EnhancedInputMode },
    CursorMove { new_position: usize },
    SpecialAction { action: String },
    Navigation { direction: String },
    StatusMessage { message: String },
    NoAction,
}
```

#### EnhancedInputMode
```rust
pub enum EnhancedInputMode {
    Navigation,
    EditMode,
    OneTimeKeyboard { target_mode: Box<EnhancedInputMode> },
    RadialMenu { sector: String, level: usize },
    SpecialCharacterMode,
    P2PBrowser,
    CollaborationMode,
    DocumentSaver,
    ImageMenu { submenu: ImageSubmenu },
    AIImagePrompt { prompt: String },
}
```

### Core Methods

#### handle_button_input()
```rust
pub fn handle_button_input(
    &mut self, 
    button: UniversalButton, 
    pressed: bool
) -> Vec<InputResult>
```
Process button press/release events. Returns vector of results for batch processing.

**New Features:**
- AI image generation integration
- P2P collaboration mode handling
- Image menu navigation
- Async operation support

#### get_cursor_info()
```rust
pub fn get_cursor_info(&self) -> CursorInfo
```
Get current cursor position and text statistics.

#### save_config() / load_config()
```rust
pub fn save_config(&self, path: &Path) -> Result<(), Error>
pub fn load_config(path: &Path) -> Result<InputConfig, Error>
```
Save and load input configurations.

#### update()
```rust
pub fn update(&mut self) -> Vec<InputResult>
```
Handle time-based events (auto-exit, cursor blink, async operations).

#### AI Integration Methods

#### submit_ai_image_request()
```rust
fn submit_ai_image_request(&mut self, prompt: String) -> Vec<InputResult>
```
Submit AI image generation request with immediate placeholder insertion.

#### scan_available_images()
```rust
pub fn scan_available_images(&mut self) -> Result<(), Error>
```
Refresh the list of available image files from all sources.

#### check_wifi_direct_connection()
```rust
pub fn check_wifi_direct_connection(&self) -> bool
```
Check if laptop daemon is connected via WiFi Direct.

#### P2P Collaboration Methods

#### start_collaboration_session()
```rust
pub fn start_collaboration_session(&mut self, document_id: String) -> Result<(), Error>
```
Begin real-time collaboration on specified document.

#### share_document()
```rust
pub fn share_document(&mut self, document_id: String, peers: Vec<String>) -> Result<(), Error>
```
Share document with specified peer devices.

#### sync_document_changes()
```rust
pub fn sync_document_changes(&mut self) -> Vec<InputResult>
```
Process pending document synchronization operations.

### Configuration Builder

#### GameBoy Style Setup
```rust
impl EnhancedInputManager {
    pub fn gameboy_style() -> Self {
        // Creates Game Boy controller configuration
        // - 4-option radial sectors
        // - Hierarchical navigation
        // - SELECT for edit mode
    }
    
    pub fn snes_style() -> Self {
        // Creates SNES controller configuration  
        // - 6-option radial menus
        // - D-pad opens character sets
        // - Fast character selection
    }
}
```

### Utility Functions

#### Character Set Helpers
```rust
pub fn get_character_at_sector(sector: Direction, index: usize) -> Option<char>
pub fn find_sector_for_character(character: char) -> Option<(Direction, usize)>
```

#### Input State Queries
```rust
pub fn is_in_edit_mode(&self) -> bool
pub fn can_input_text(&self) -> bool  
pub fn get_available_actions(&self) -> Vec<ButtonAction>
```

## Integration Examples

### Game Integration
```rust
// In your game loop
match game_state {
    GameState::Menu => {
        // Use navigation mode
        if input_manager.current_mode != EnhancedInputMode::Navigation {
            input_manager.enter_navigation_mode();
        }
    },
    GameState::TextEntry => {
        // Use edit mode for text input
        if !input_manager.is_in_edit_mode() {
            input_manager.enter_edit_mode();
        }
    }
}
```

### Cross-Application Text Sharing
```rust
// Share text between applications
let shared_text = input_manager.get_text();
email_app.set_message_body(&shared_text);
note_app.append_text(&shared_text);
```

### AI Image Integration Example
```rust
// Initialize with WiFi Direct support
let mut input_manager = EnhancedInputManager::snes_style();
input_manager.enable_wifi_direct()?;

// Check for laptop connection
if input_manager.check_wifi_direct_connection() {
    println!("Laptop daemon connected - AI features available");
} else {
    println!("AI features disabled - no laptop connection");
}

// Handle AI image generation result
match result {
    InputResult::InsertText { text } if text.starts_with("[AI_IMAGE_") => {
        if text.contains("GENERATING") {
            show_progress_indicator();
        } else if text.contains("FAILED") {
            show_error_message(&text);
        } else {
            // Success - image is ready
            load_and_display_image(&text);
        }
    }
    _ => {}
}
```

### P2P Collaboration Example
```rust
// Initialize with P2P mesh networking
let mut input_manager = EnhancedInputManager::new(config);
input_manager.enable_p2p_mesh()?;

// Start collaboration session
input_manager.start_collaboration_session("document_123".to_string())?;

// Handle collaboration events
match result {
    InputResult::StatusMessage { message } if message.contains("peer") => {
        update_peer_list(&message);
    }
    InputResult::ReplaceText { find, replace } => {
        // Collaborative edit from remote peer
        apply_remote_edit(&find, &replace);
    }
    _ => {}
}

// Share current document
input_manager.share_document(
    "my_document".to_string(), 
    vec!["peer_device_123".to_string()]
)?;
```

### Device-Specific Optimization
```rust
// Detect device capabilities
match device_type {
    DeviceType::GameBoy => {
        EnhancedInputManager::gameboy_style()
    },
    DeviceType::SNES => {
        EnhancedInputManager::snes_style()  
    },
    DeviceType::Custom => {
        let config = InputConfig::load_from_file("device_config.json")?;
        EnhancedInputManager::new(config)
    }
}
```

## Troubleshooting

### Common Issues

**Input not responding:**
- Check controller configuration matches hardware
- Verify button mappings in config file
- Ensure proper mode for current context

**Characters not appearing:**
- Check if in correct input mode
- Verify character set configuration
- Test with default configuration first

**Mode switching problems:**
- Check SELECT button configuration
- Verify timeout settings
- Look for conflicting special actions

**AI image generation not working:**
- Verify WiFi Direct connection to laptop daemon
- Check laptop daemon is running and paired
- Confirm AI backend (Automatic1111, ComfyUI, etc.) is operational
- Review laptop daemon permissions for the device

**P2P collaboration issues:**
- Check mesh networking is enabled
- Verify peer devices are in range
- Confirm document sharing permissions
- Review encryption key synchronization

**Image menu not appearing:**
- Check L/R + D-pad button combination
- Verify image directories exist and are accessible
- Scan for available images using refresh function

### Debug Tools

Enable debug logging:
```rust
input_manager.set_debug_mode(true);
```

Check current state:
```rust
let state = input_manager.get_debug_state();
println!("Mode: {:?}", state.current_mode);
println!("Buffer: {}", state.text_buffer);
println!("Cursor: {}", state.cursor_position);
```

## Performance Considerations

### Battery Life
- Use longer timeouts for auto-exit
- Reduce cursor blink frequency
- Enable low-power mode optimizations

### Memory Usage
- Limit text buffer size for long documents
- Use streaming for large character sets
- Configure appropriate history limits

### Responsiveness
- Tune input repeat rates for device performance
- Use efficient character lookup algorithms
- Optimize radial menu rendering

This enhanced input system transforms the limited button layout of handheld devices into a powerful, efficient text input method while maintaining the retro gaming aesthetic and feel.