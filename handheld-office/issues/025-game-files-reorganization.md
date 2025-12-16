# Issue #025: Game Files Reorganization to src/games/ Directory

## Priority: MEDIUM

## Description
The project directory hierarchy has been updated with a new `src/games/` directory structure, but game-related files are still located in the main `src/` directory. These files need to be moved to the appropriate subdirectories and all references updated.

## Current Game Files Location
**Files in `/src/` that should be moved:**

### Game Engine Files
- `src/mmo_engine.rs` → `src/games/src/mmo_engine.rs`
- `src/rocketship_bacterium.rs` → `src/games/src/rocketship_bacterium.rs`
- `src/battleship_pong.rs` → `src/games/src/battleship_pong.rs`

### ❌ **NOT Game Files** (Move to Issue #028 - Utilities)
- ~~`src/music.rs`~~ → See Issue #028 (Utilities)
- ~~`src/paint.rs`~~ → See Issue #028 (Utilities)
- ~~`src/terminal.rs`~~ → See Issue #028 (Utilities)

### Game Demo/Binary Files
- `src/mmo_demo.rs` → `src/games/bin/mmo_demo.rs`
- `src/rocketship_bacterium_demo.rs` → `src/games/bin/rocketship_bacterium_demo.rs`
- `src/battleship_pong_demo.rs` → `src/games/bin/battleship_pong_demo.rs`

### ❌ **NOT Game Files** (Move to Issue #028 - Utilities)
- ~~`src/music_demo.rs`~~ → See Issue #028 (Utilities)
- ~~`src/paint_demo.rs`~~ → See Issue #028 (Utilities)
- ~~`src/terminal_demo.rs`~~ → See Issue #028 (Utilities)
- ~~`src/media_demo.rs`~~ → See Issue #028 (Utilities)

## New Directory Structure Required

```
src/games/
├── src/                    # Game engine implementations
│   ├── mmo_engine.rs
│   ├── rocketship_bacterium.rs
│   ├── battleship_pong.rs
│   └── mod.rs             # Module declarations
├── bin/                    # Game demo executables
│   ├── mmo_demo.rs
│   ├── rocketship_bacterium_demo.rs
│   └── battleship_pong_demo.rs
├── docs/                   # Game-specific documentation
│   └── (to be populated)
├── build/                  # Game build artifacts
│   └── (to be populated)
└── notes/                  # Game development notes
    └── (to be populated)
```

## Impact Analysis

### Files That Will Be Affected
1. **Cargo.toml**: All `[[bin]]` entries for game demos need path updates
2. **Import statements**: Any `use` statements importing game modules
3. **Documentation**: References to game demo paths in markdown files
4. **Build scripts**: Any scripts that reference specific game file paths
5. **Test files**: Tests that import or reference game modules

### Modules That Import Game Files
Based on analysis, these modules likely import game files:
- `src/lib.rs` - May declare game modules
- `src/handheld.rs` - May import various game engines
- Other demo files that cross-reference each other

## Required Changes

### Step 1: Create Module Structure
```rust
// src/games/src/mod.rs
pub mod mmo_engine;
pub mod rocketship_bacterium;
pub mod battleship_pong;
```

### Step 2: Update Main lib.rs
```rust
// src/lib.rs - Add or update:
pub mod games {
    pub use super::games::src::*;
}
```

### Step 3: Move Files
- Move all game engine `.rs` files to `src/games/src/`
- Move all game demo `.rs` files to `src/games/bin/`
- Update internal `use` statements in moved files

### Step 4: Update Import Statements
Replace imports like:
```rust
use crate::mmo_engine::*;
```
With:
```rust
use crate::games::mmo_engine::*;
```

## Dependencies
- **Blocks**: Clean project organization
- **Blocked by**: None
- **Related**: Issue #026 (Cargo.toml updates), Issue #027 (Documentation updates)

## Testing Requirements
1. **Compilation Test**: Ensure all games compile after move
   ```bash
   cargo build --bin mmo-demo
   cargo build --bin rocketship-bacterium
   cargo build --bin battleship-pong
   ```

2. **Module Resolution Test**: Verify all imports resolve correctly
   ```bash
   cargo check --lib
   ```

3. **Runtime Test**: Verify games still function correctly
   ```bash
   ./target/release/mmo-demo --test
   ./target/release/rocketship-bacterium --test
   ./target/release/battleship-pong --test
   ```

## Implementation Notes

### Preserve Git History
Use `git mv` commands to preserve file history:
```bash
git mv src/mmo_engine.rs src/games/src/mmo_engine.rs
git mv src/mmo_demo.rs src/games/bin/mmo_demo.rs
git mv src/rocketship_bacterium.rs src/games/src/rocketship_bacterium.rs
git mv src/rocketship_bacterium_demo.rs src/games/bin/rocketship_bacterium_demo.rs
git mv src/battleship_pong.rs src/games/src/battleship_pong.rs
git mv src/battleship_pong_demo.rs src/games/bin/battleship_pong_demo.rs
```

### Handle Circular Dependencies
- Watch for circular import issues when updating module paths
- Consider using `pub use` statements to maintain backward compatibility temporarily

### Update Relative Paths
- Any relative file paths in game code may need updates
- Asset loading paths may need adjustment

## Success Criteria
- [ ] All game files moved to appropriate `src/games/` subdirectories
- [ ] All imports updated to use new module paths
- [ ] `src/games/src/mod.rs` created with proper module declarations
- [ ] All game demos compile without errors
- [ ] All game demos run correctly
- [ ] No broken import statements remain
- [ ] Git history preserved for moved files

## Risk Assessment
- **Low Risk**: File moves with proper import updates
- **Medium Risk**: Potential circular dependency issues
- **Mitigation**: Test compilation at each step, use temporary compatibility imports if needed

**Filed by**: Directory reorganization request  
**Date**: 2025-09-23  
**Complexity**: Moderate - requires careful import management