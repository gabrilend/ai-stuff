# Issue #030: Comprehensive Cargo.toml Updates for Directory Reorganization

## Priority: HIGH

## Description
Update all binary paths in `Cargo.toml` to reflect the new organized directory structure across games, utilities, and networking modules. This issue consolidates and coordinates all Cargo.toml changes needed for Issues #025, #028, and #029.

## Current vs New Binary Paths

### Games Module (Issue #025)
```toml
# OLD PATHS
[[bin]]
name = "mmo-demo"
path = "src/mmo_demo.rs"

[[bin]]
name = "rocketship-bacterium"
path = "src/rocketship_bacterium_demo.rs"

[[bin]]
name = "battleship-pong"
path = "src/battleship_pong_demo.rs"

# NEW PATHS
[[bin]]
name = "mmo-demo"
path = "src/games/bin/mmo_demo.rs"

[[bin]]
name = "rocketship-bacterium"
path = "src/games/bin/rocketship_bacterium_demo.rs"

[[bin]]
name = "battleship-pong"
path = "src/games/bin/battleship_pong_demo.rs"
```

### Utilities Module (Issue #028)
```toml
# OLD PATHS
[[bin]]
name = "paint-demo"
path = "src/paint_demo.rs"

[[bin]]
name = "music-demo"
path = "src/music_demo.rs"

[[bin]]
name = "terminal-demo"
path = "src/terminal_demo.rs"

[[bin]]
name = "media-demo"
path = "src/media_demo.rs"

# NEW PATHS
[[bin]]
name = "paint-demo"
path = "src/utilities/bin/paint_demo.rs"

[[bin]]
name = "music-demo"
path = "src/utilities/bin/music_demo.rs"

[[bin]]
name = "terminal-demo"
path = "src/utilities/bin/terminal_demo.rs"

[[bin]]
name = "media-demo"
path = "src/utilities/bin/media_demo.rs"
```

### Networking Module (Issue #029)
```toml
# OLD PATHS
[[bin]]
name = "daemon"
path = "src/daemon.rs"

[[bin]]
name = "laptop-daemon"
path = "src/laptop_daemon.rs"

[[bin]]
name = "desktop-llm"
path = "src/desktop_llm.rs"

[[bin]]
name = "email-demo"
path = "src/email_demo.rs"

[[bin]]
name = "scuttlebutt-mesh"
path = "src/scuttlebutt_demo.rs"

# NEW PATHS
[[bin]]
name = "daemon"
path = "src/networking/src/daemon.rs"

[[bin]]
name = "laptop-daemon"
path = "src/networking/bin/laptop_daemon.rs"

[[bin]]
name = "desktop-llm"
path = "src/networking/src/desktop_llm.rs"

[[bin]]
name = "email-demo"
path = "src/networking/bin/email_demo.rs"

[[bin]]
name = "scuttlebutt-mesh"
path = "src/networking/bin/scuttlebutt_demo.rs"
```

### Core System Binaries (Unchanged)
```toml
# REMAIN IN MAIN src/
[[bin]]
name = "handheld"
path = "src/handheld.rs"  # Main handheld application
```

## Complete Updated Cargo.toml Binary Section

```toml
# Core System Binaries
[[bin]]
name = "handheld"
path = "src/handheld.rs"

# Games Module Binaries
[[bin]]
name = "mmo-demo"
path = "src/games/bin/mmo_demo.rs"

[[bin]]
name = "rocketship-bacterium"
path = "src/games/bin/rocketship_bacterium_demo.rs"

[[bin]]
name = "battleship-pong"
path = "src/games/bin/battleship_pong_demo.rs"

# Utilities Module Binaries
[[bin]]
name = "paint-demo"
path = "src/utilities/bin/paint_demo.rs"

[[bin]]
name = "music-demo"
path = "src/utilities/bin/music_demo.rs"

[[bin]]
name = "terminal-demo"
path = "src/utilities/bin/terminal_demo.rs"

[[bin]]
name = "media-demo"
path = "src/utilities/bin/media_demo.rs"

# Networking Module Binaries
[[bin]]
name = "daemon"
path = "src/networking/src/daemon.rs"

[[bin]]
name = "laptop-daemon"
path = "src/networking/bin/laptop_daemon.rs"

[[bin]]
name = "desktop-llm"
path = "src/networking/src/desktop_llm.rs"

[[bin]]
name = "email-demo"
path = "src/networking/bin/email_demo.rs"

[[bin]]
name = "scuttlebutt-mesh"
path = "src/networking/bin/scuttlebutt_demo.rs"
```

## Dependencies and Coordination

### Implementation Order
1. **Complete file moves** (Issues #025, #028, #029)
2. **Update Cargo.toml paths** (This issue)
3. **Test compilation** for all modules
4. **Update documentation** (Issues #026, #027, #031)

### Critical Dependencies
- **MUST complete BEFORE**: All file moves from Issues #025, #028, #029
- **MUST complete AFTER**: File reorganization
- **BLOCKS**: Successful compilation of any moved binaries

## Validation Strategy

### Pre-Update Backup
```bash
# Create backup of working Cargo.toml
cp Cargo.toml Cargo.toml.pre-reorganization.backup
```

### Incremental Testing Approach
```bash
# Test each module separately after updating paths

# Test Games Module
cargo build --bin mmo-demo
cargo build --bin rocketship-bacterium  
cargo build --bin battleship-pong

# Test Utilities Module
cargo build --bin paint-demo
cargo build --bin music-demo
cargo build --bin terminal-demo
cargo build --bin media-demo

# Test Networking Module
cargo build --bin daemon
cargo build --bin laptop-daemon
cargo build --bin desktop-llm
cargo build --bin email-demo
cargo build --bin scuttlebutt-mesh

# Test Core System
cargo build --bin handheld

# Test All Binaries
cargo build --bins
```

### Full System Validation
```bash
# Comprehensive build test
cargo build --bins --release

# Individual binary execution test
./target/release/mmo-demo --help
./target/release/paint-demo --help
./target/release/terminal-demo --help
./target/release/daemon --help
./target/release/handheld --help
# ... test all binaries
```

## Implementation Phases

### Phase 1: Games Module (After Issue #025)
1. Update games binary paths in Cargo.toml
2. Test games compilation only
3. Verify games functionality

### Phase 2: Utilities Module (After Issue #028)  
1. Update utilities binary paths in Cargo.toml
2. Test utilities compilation only
3. Verify utilities functionality

### Phase 3: Networking Module (After Issue #029)
1. Update networking binary paths in Cargo.toml
2. Test networking compilation only
3. Verify networking functionality

### Phase 4: Full System Integration
1. Test all binaries compile together
2. Test cross-module functionality
3. Validate complete system operation

## Error Handling and Rollback

### Common Error Scenarios
1. **File not found**: File move incomplete or incorrect path
2. **Module import errors**: Module reorganization incomplete
3. **Dependency issues**: Cross-module dependencies broken

### Rollback Procedure
```bash
# If compilation fails, restore from backup
cp Cargo.toml.pre-reorganization.backup Cargo.toml

# Test that rollback works
cargo build --bins

# Identify and fix issue, then retry update
```

### Debugging Failed Builds
```bash
# Check specific binary compilation
cargo build --bin <failing-binary> --verbose

# Check if file exists at specified path
ls -la src/games/bin/mmo_demo.rs
ls -la src/utilities/bin/paint_demo.rs
ls -la src/networking/bin/email_demo.rs

# Verify module structure
cargo check --lib --verbose
```

## Success Criteria
- [ ] All binary paths updated to reflect new directory structure
- [ ] All binaries compile successfully with new paths
- [ ] All binaries execute correctly
- [ ] Full `cargo build --bins` succeeds
- [ ] Release builds work: `cargo build --bins --release`
- [ ] No broken binary references remain
- [ ] All module-specific binaries work in their new locations

## Integration with Other Issues

### Relationship to File Move Issues
- **Issue #025**: Games reorganization must complete first
- **Issue #028**: Utilities reorganization must complete first  
- **Issue #029**: Networking reorganization must complete first

### Relationship to Documentation Issues
- **Issue #026**: Update game documentation after Cargo.toml changes
- **Issue #027**: Update utilities documentation after Cargo.toml changes
- **Issue #031**: Update networking documentation after Cargo.toml changes

## Risk Assessment
- **High Risk**: System-wide compilation impact
- **Medium Risk**: Binary name consistency
- **Mitigation**: Incremental testing, backup/rollback procedures
- **Verification**: Comprehensive testing at each phase

## Notes
- Binary names remain unchanged - only paths are updated
- IDE integration should continue to work
- CI/CD scripts remain unaffected (same binary names)
- Developer workflow commands (`cargo run --bin <name>`) unchanged

**Filed by**: Directory reorganization coordination  
**Date**: 2025-09-23  
**Complexity**: Medium - straightforward but system-wide impact