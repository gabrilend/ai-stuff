# Issue #011: Documentation-Code Mismatch - MediaPlayer API

## Priority: HIGH

## Description
The P2P mesh system documentation (`docs/p2p-mesh-system.md`) describes an API that doesn't match the actual implementation in the code.

## Documented Functionality (from `/docs/p2p-mesh-system.md` lines 29-32)
The documentation shows this example:
```rust
let mut media_player = MediaPlayer::new()?;
media_player.enable_p2p("my_device_name".to_string())?;
```

## Actual Implementation (from `/src/media.rs` line 150)
The actual struct is named differently:
```rust
pub struct AnbernicMediaPlayer {
    // ... implementation
}
```

## Code Location
- **Documentation**: `/docs/p2p-mesh-system.md:29-32`
- **Implementation**: `/src/media.rs:150`
- **Related Issue**: This was previously identified in `/issues/done/005-missing-mediaplayer-implementation.md`

## Impact
- **Developer Confusion**: Documentation examples won't compile
- **API Inconsistency**: Expected `MediaPlayer::new()` doesn't exist
- **Integration Problems**: Other code trying to follow docs will fail

## Required Fixes

### Option 1: Update Documentation to Match Implementation
Change documentation examples to use actual struct name:
```rust
// Update docs/p2p-mesh-system.md line 30
let mut media_player = AnbernicMediaPlayer::new()?;
```

### Option 2: Update Implementation to Match Documentation  
Add a type alias or rename the struct:
```rust
// In src/media.rs
pub type MediaPlayer = AnbernicMediaPlayer;
// OR
pub struct MediaPlayer { // rename from AnbernicMediaPlayer
```

### Option 3: Check if `new()` Method Exists
Verify if `AnbernicMediaPlayer::new()` method is implemented as documented.

## Additional Investigation Needed

1. **Check Enhanced Input Documentation**: Similar mismatch suspected in enhanced input examples
2. **Verify P2P Integration Methods**: Confirm if `enable_p2p()` method actually exists
3. **Review Other Application APIs**: Paint app and other components may have similar issues

## Cross-References
- **Related Issue**: #005 (MediaPlayer implementation) - marked as resolved but documentation not updated
- **Todo Item**: `/todo/claude-next/claude-next-3` (documentation review request)
- **Documentation**: `/docs/p2p-mesh-system.md` needs comprehensive review

## Suggested Resolution Priority
1. **Immediate**: Fix MediaPlayer documentation examples  
2. **Short-term**: Audit all documentation examples for compilation errors
3. **Medium-term**: Establish process to keep docs and code synchronized

**Filed by**: Documentation audit (claude-next-3)  
**Date**: 2025-01-27