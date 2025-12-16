# Issue #026: Update Cargo.toml Binary Paths for Game Reorganization

## Priority: HIGH

## Description
After moving game files to the new `src/games/` directory structure (Issue #025), the `Cargo.toml` file needs to be updated to reflect the new binary paths. Currently, all game demo binaries are configured with paths in the main `src/` directory.

## Current Binary Configurations in Cargo.toml

**Game-related binaries that need path updates:**
```toml
[[bin]]
name = "paint-demo"
path = "src/paint_demo.rs"

[[bin]]
name = "music-demo"
path = "src/music_demo.rs"

[[bin]]
name = "mmo-demo"
path = "src/mmo_demo.rs"

[[bin]]
name = "battleship-pong"
path = "src/battleship_pong_demo.rs"

[[bin]]
name = "rocketship-bacterium"
path = "src/rocketship_bacterium_demo.rs"

[[bin]]
name = "terminal-demo"
path = "src/terminal_demo.rs"

[[bin]]
name = "media-demo"
path = "src/media_demo.rs"
```

## Required Changes

### Updated Binary Configurations
```toml
[[bin]]
name = "paint-demo"
path = "src/games/bin/paint_demo.rs"

[[bin]]
name = "music-demo"
path = "src/games/bin/music_demo.rs"

[[bin]]
name = "mmo-demo"
path = "src/games/bin/mmo_demo.rs"

[[bin]]
name = "battleship-pong"
path = "src/games/bin/battleship_pong_demo.rs"

[[bin]]
name = "rocketship-bacterium"
path = "src/games/bin/rocketship_bacterium_demo.rs"

[[bin]]
name = "terminal-demo"
path = "src/games/bin/terminal_demo.rs"

[[bin]]
name = "media-demo"
path = "src/games/bin/media_demo.rs"
```

### Non-Game Binaries (Keep Unchanged)
These binaries should remain in their current locations:
```toml
[[bin]]
name = "daemon"
path = "src/daemon.rs"

[[bin]]
name = "laptop-daemon"
path = "src/laptop_daemon.rs"

[[bin]]
name = "handheld"
path = "src/handheld.rs"

[[bin]]
name = "desktop-llm"
path = "src/desktop_llm.rs"

[[bin]]
name = "email-demo"
path = "src/email_demo.rs"

[[bin]]
name = "scuttlebutt-mesh"
path = "src/scuttlebutt_demo.rs"
```

## Additional Considerations

### Email Demo Classification
The `email-demo` binary references `src/email_demo.rs`. Consider whether email functionality should be:
1. **Keep in main src/**: If email is a core system component
2. **Move to games/**: If email is considered a demo application
3. **Move to separate communications/ directory**: If creating broader reorganization

**Recommendation**: Keep in main `src/` as email is a core P2P communication feature, not a game.

### Scuttlebutt Demo Classification
The `scuttlebutt-mesh` binary is also a communication/P2P feature, not a game, so it should remain in main `src/`.

## Dependencies
- **Depends on**: Issue #025 (Game Files Reorganization)
- **Blocks**: Successful compilation of game demos
- **Related**: Issue #027 (Documentation updates)

## Validation Steps

### Pre-Update Validation
1. **Verify current builds work**:
   ```bash
   cargo build --bin mmo-demo
   cargo build --bin paint-demo
   cargo build --bin music-demo
   cargo build --bin terminal-demo
   cargo build --bin rocketship-bacterium
   cargo build --bin battleship-pong
   cargo build --bin media-demo
   ```

### Post-Update Validation
1. **Test individual game builds**:
   ```bash
   cargo build --bin mmo-demo
   cargo build --bin paint-demo
   cargo build --bin music-demo
   cargo build --bin terminal-demo
   cargo build --bin rocketship-bacterium
   cargo build --bin battleship-pong
   cargo build --bin media-demo
   ```

2. **Test all binaries build**:
   ```bash
   cargo build --bins
   ```

3. **Test release builds**:
   ```bash
   cargo build --bins --release
   ```

4. **Verify binary execution**:
   ```bash
   ./target/release/mmo-demo --help
   ./target/release/paint-demo --help
   # etc.
   ```

## Implementation Approach

### Safe Update Process
1. **Create backup of Cargo.toml**:
   ```bash
   cp Cargo.toml Cargo.toml.backup
   ```

2. **Update paths incrementally**:
   - Update one binary path at a time
   - Test compilation after each change
   - Revert if compilation fails

3. **Batch update approach** (alternative):
   - Update all paths at once
   - Test full compilation
   - Use backup if issues arise

### Error Handling
If compilation fails after path updates:
1. **Check file exists at new path**: Ensure Issue #025 file moves completed
2. **Verify path syntax**: Ensure no typos in path specification
3. **Check for import issues**: May need to wait for Issue #025 import updates

## Impact on Build System

### CI/CD Considerations
- Any CI/CD scripts that build specific binaries will continue to work
- Binary names remain unchanged, only paths updated
- Build artifacts will be generated in same locations

### Development Workflow
- `cargo run --bin <name>` commands remain unchanged
- IDE integration should continue to work
- Build scripts and makefiles unaffected

## Success Criteria
- [ ] All game demo binary paths updated in Cargo.toml
- [ ] All game demos compile successfully with new paths
- [ ] All game demos execute correctly
- [ ] Non-game binaries remain unchanged and functional
- [ ] Full `cargo build --bins` succeeds
- [ ] Release builds work correctly
- [ ] No broken binary references remain

## Risk Assessment
- **Low Risk**: Path updates are straightforward
- **Dependencies**: Requires Issue #025 file moves to be completed first
- **Rollback**: Easy to restore from Cargo.toml backup

## Notes
- This is a prerequisite for Issue #025 completion
- Should be done immediately after file moves are completed
- Consider updating in same commit as file moves to maintain atomicity

**Filed by**: Game reorganization dependency  
**Date**: 2025-09-23  
**Complexity**: Low - straightforward path updates