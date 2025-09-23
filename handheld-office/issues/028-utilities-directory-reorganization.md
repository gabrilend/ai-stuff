# Issue #028: Utilities Directory Reorganization and File Movement

## Priority: MEDIUM

## Description
Create a proper utilities module structure and move utility applications from the main `src/` directory. Utilities are distinct from games and need their own organized directory structure following the patterns established in `src/games/` and `src/networking/`.

## Utility Files to Reorganize

### Utility Engine Files (src/ → src/utilities/src/)
- `src/terminal.rs` → `src/utilities/src/terminal.rs` (Terminal emulator/file browser)
- `src/paint.rs` → `src/utilities/src/paint.rs` (Paint/drawing application)
- `src/music.rs` → `src/utilities/src/music.rs` (Audio synthesis and playback)
- `src/media.rs` → `src/utilities/src/media.rs` (Media playback and processing)

### Utility Demo Files (src/ → src/utilities/bin/)
- `src/terminal_demo.rs` → `src/utilities/bin/terminal_demo.rs`
- `src/paint_demo.rs` → `src/utilities/bin/paint_demo.rs`
- `src/music_demo.rs` → `src/utilities/bin/music_demo.rs`
- `src/media_demo.rs` → `src/utilities/bin/media_demo.rs`

## Directory Structure Created

```
src/utilities/
├── src/                    # Utility implementations
│   ├── terminal.rs         # Terminal emulator and file browser
│   ├── paint.rs            # Paint and drawing utilities
│   ├── music.rs            # Audio synthesis and playback
│   ├── media.rs            # Media processing utilities
│   └── mod.rs              # Module declarations
├── bin/                    # Utility demo executables
│   ├── terminal_demo.rs    # Terminal demo application
│   ├── paint_demo.rs       # Paint demo application
│   ├── music_demo.rs       # Music synthesis demo
│   └── media_demo.rs       # Media playback demo
├── src/                    # Local source directory
├── bin/                    # Local binaries directory
├── build/                  # Build artifacts
├── docs -> ../../docs      # Symlink to main docs
└── notes -> ../../notes    # Symlink to main notes
```

## Utility Classification

### Terminal Utilities
- **Terminal Emulator**: Radial menu filesystem navigation
- **File Browser**: SD card and storage management
- **Text Editor Integration**: Works with enhanced input system

### Media Utilities  
- **Paint Application**: Handheld-optimized drawing with line-based input
- **Music Synthesis**: Audio generation and playback for handheld devices
- **Media Player**: Video/audio playback with battery optimization

### Core Features
- **Radial Input Integration**: All utilities use the radial keyboard system
- **Battery Optimization**: Power-conscious operation for handheld devices
- **P2P Integration**: Share files and collaborate through encrypted channels
- **SD Card Friendly**: Minimize write operations for storage longevity

## Implementation Requirements

### Step 1: Create Module Structure
```rust
// src/utilities/src/mod.rs
pub mod terminal;
pub mod paint;
pub mod music;
pub mod media;

// Re-export commonly used items
pub use terminal::{TerminalEmulator, FileSystemNavigator};
pub use paint::{PaintEngine, DrawingCanvas};
pub use music::{AudioSynthesizer, SoundEngine};
pub use media::{MediaPlayer, VideoDecoder};
```

### Step 2: Update Main lib.rs
```rust
// src/lib.rs - Add utilities module
pub mod utilities {
    pub use crate::utilities::src::*;
}

// Maintain backward compatibility temporarily
pub use utilities::terminal;
pub use utilities::paint;
pub use utilities::music;
pub use utilities::media;
```

### Step 3: Update Import Statements
Replace imports throughout the codebase:
```rust
// Old imports
use crate::terminal::*;
use crate::paint::*;
use crate::music::*;
use crate::media::*;

// New imports
use crate::utilities::terminal::*;
use crate::utilities::paint::*;
use crate::utilities::music::*;
use crate::utilities::media::*;
```

## Files That Will Need Import Updates

### Likely to Import Utility Modules
- `src/handheld.rs` - Main handheld application
- `src/enhanced_input.rs` - Input system integration
- Any demo files that cross-reference utilities
- Integration tests and examples

### Demo Files Internal References
- Utility demos may reference their corresponding engines
- Cross-utility integration (e.g., music in paint application)

## Cargo.toml Updates Required

### Binary Path Updates
```toml
# Update these entries:
[[bin]]
name = "terminal-demo"
path = "src/utilities/bin/terminal_demo.rs"

[[bin]]
name = "paint-demo"  
path = "src/utilities/bin/paint_demo.rs"

[[bin]]
name = "music-demo"
path = "src/utilities/bin/music_demo.rs"

[[bin]]
name = "media-demo"
path = "src/utilities/bin/media_demo.rs"
```

## Updated Game Reorganization Scope

### Remove from Issue #025 (Games)
The following files should NOT be moved to `src/games/`:
- ❌ `src/terminal.rs` and `src/terminal_demo.rs`
- ❌ `src/paint.rs` and `src/paint_demo.rs`
- ❌ `src/music.rs` and `src/music_demo.rs`
- ❌ `src/media.rs` and `src/media_demo.rs`

### Keep in Issue #025 (Games)
These files are actual games and should move to `src/games/`:
- ✅ `src/mmo_engine.rs` and `src/mmo_demo.rs`
- ✅ `src/rocketship_bacterium.rs` and `src/rocketship_bacterium_demo.rs`
- ✅ `src/battleship_pong.rs` and `src/battleship_pong_demo.rs`

## Dependencies
- **Blocks**: Clean project organization
- **Blocked by**: None (can be implemented independently)
- **Related**: Issue #025 (scope reduction), Issue #029 (Cargo.toml updates), Issue #030 (documentation updates)

## Testing Requirements

### Compilation Tests
```bash
# Test utility builds
cargo build --bin terminal-demo
cargo build --bin paint-demo  
cargo build --bin music-demo
cargo build --bin media-demo

# Test library compilation
cargo check --lib

# Test all binaries
cargo build --bins
```

### Functionality Tests
```bash
# Test utility functionality
./target/release/terminal-demo --test
./target/release/paint-demo --test
./target/release/music-demo --test
./target/release/media-demo --test
```

### Integration Tests
- Verify utilities integrate with enhanced input system
- Test P2P functionality in utilities
- Verify file I/O operations work correctly

## Implementation Strategy

### Git History Preservation
```bash
# Use git mv to preserve file history
git mv src/terminal.rs src/utilities/src/terminal.rs
git mv src/terminal_demo.rs src/utilities/bin/terminal_demo.rs
git mv src/paint.rs src/utilities/src/paint.rs
git mv src/paint_demo.rs src/utilities/bin/paint_demo.rs
git mv src/music.rs src/utilities/src/music.rs
git mv src/music_demo.rs src/utilities/bin/music_demo.rs
git mv src/media.rs src/utilities/src/media.rs
git mv src/media_demo.rs src/utilities/bin/media_demo.rs
```

### Incremental Implementation
1. **Create module structure** and test basic compilation
2. **Move one utility at a time** and test after each move
3. **Update imports systematically** across all affected files
4. **Update Cargo.toml** after file moves are complete
5. **Test full system compilation** and functionality

## Success Criteria
- [ ] All utility files moved to appropriate `src/utilities/` subdirectories  
- [ ] `src/utilities/src/mod.rs` created with proper module declarations
- [ ] All imports updated to use new utility module paths
- [ ] All utility demos compile and run correctly
- [ ] Library compilation succeeds with new module structure
- [ ] No broken import statements remain
- [ ] Git history preserved for all moved files
- [ ] Utilities directory structure follows established patterns

## Risk Assessment
- **Low Risk**: Utilities are relatively self-contained
- **Medium Risk**: Potential cross-dependencies between utilities
- **Mitigation**: Test each utility independently, identify dependencies early

**Filed by**: Directory reorganization and utility classification  
**Date**: 2025-09-23  
**Complexity**: Moderate - requires careful import and dependency management