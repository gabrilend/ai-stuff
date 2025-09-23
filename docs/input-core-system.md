# Core Input System Documentation

## Overview

The OfficeOS Core Input System provides the fundamental text entry and navigation capabilities for handheld gaming devices. This document focuses exclusively on core input functionality without external integrations.

## Core Components

### EnhancedInputManager (Core Only)

The central input coordinator handling basic text entry:

<details>
<summary>Core Structure (click to expand)</summary>

```rust
pub struct EnhancedInputManager {
    // Core input functionality
    pub config: InputConfig,
    pub current_mode: EnhancedInputMode,
    pub text_buffer: String,
    pub cursor_position: usize,
    pub edit_mode_state: EditModeState,
    
    // State management
    pub one_time_keyboard_state: Option<OneTimeKeyboardState>,
    pub button_states: HashMap<String, ButtonState>,
    pub last_input_time: Instant,
}
```
</details>

### Input Modes (Core)

<details>
<summary>Core Input Modes (click to expand)</summary>

```rust
pub enum EnhancedInputMode {
    Navigation,                    // Basic navigation
    EditMode,                      // Text editing
    OneTimeKeyboard { target_mode: Box<EnhancedInputMode> },
    RadialMenu { sector: String, level: usize },
    SpecialCharacterMode,
    DocumentSaver,
}
```
</details>

### Controller Support

#### Game Boy Style (4 buttons + D-pad)
- **A Button**: Primary action
- **B Button**: Secondary action/back
- **L/R Buttons**: Mode switching
- **D-pad**: Navigation/character selection

#### SNES Style (6+ buttons)
- All Game Boy buttons plus:
- **X/Y Buttons**: Extended functionality
- **L2/R2**: Additional options

## Basic Usage

### Simple Text Entry
```rust
use handheld_office::{EnhancedInputManager, UniversalButton};

// Create input manager
let mut input = EnhancedInputManager::gameboy_style();

// Handle button press
let results = input.handle_button_input(UniversalButton::A, true);

// Get current text
println!("Text: {}", input.text_buffer);
```

### Mode Switching
```rust
// Enter edit mode
input.set_mode(EnhancedInputMode::EditMode);

// Navigate with D-pad
input.handle_button_input(UniversalButton::DpadUp, true);
```

## Configuration

### Basic Configuration
<details>
<summary>InputConfig Structure (click to expand)</summary>

```rust
pub struct InputConfig {
    pub controller_type: ControllerType,
    pub keyboard_layout: KeyboardLayout,
    pub repeat_delay_ms: u64,
    pub repeat_rate_ms: u64,
    pub auto_exit_edit_mode: bool,
}
```
</details>

### Controller Types
- `GameBoy` - 4 buttons + D-pad
- `SNES` - 6+ buttons + D-pad  
- `Custom` - User-defined layout

## Text Editing Features

### Navigation
- **Cursor Movement**: D-pad for character-by-character navigation
- **Word Jumping**: L/R for word-level movement
- **Line Navigation**: Vertical movement with D-pad

### Editing Operations
- **Insert Mode**: Default text entry
- **Overwrite Mode**: Replace existing characters
- **Selection**: Character/word/line selection
- **Cut/Copy/Paste**: Basic clipboard operations

### Special Characters
- **Symbol Mode**: Access punctuation and symbols
- **Number Mode**: Numeric input optimization
- **Accent Mode**: Accented character entry

## Error Handling

### Common Issues
- **Button Conflicts**: Multiple buttons pressed simultaneously
- **Mode Confusion**: Invalid mode transitions
- **Buffer Overflow**: Text buffer limits

### Error Recovery
```rust
match input.handle_button_input(button, pressed) {
    Ok(results) => { /* Process results */ },
    Err(InputError::InvalidMode) => {
        input.reset_to_navigation();
    },
    Err(e) => {
        eprintln!("Input error: {}", e);
    }
}
```

## Performance Considerations

### Memory Usage
- Text buffer: Configurable maximum size
- Button states: Minimal overhead
- Mode state: Stack-based for efficient switching

### Latency
- Target response time: < 50ms
- Debounce handling: 20ms default
- Mode switching: < 10ms

## Integration Points

This core system provides integration points for external features:

- **P2P Integration**: See `docs/input-p2p-integration.md`
- **AI Features**: See `docs/input-ai-integration.md`  
- **Crypto System**: See `docs/input-crypto-integration.md`

---

**File**: Core input system only  
**Dependencies**: None (self-contained)  
**Integration**: Via documented interfaces  
**Performance**: Optimized for handheld devices