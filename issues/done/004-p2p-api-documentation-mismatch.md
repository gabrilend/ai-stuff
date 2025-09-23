# Issue #004: P2P Mesh API Documentation Doesn't Match Implementation

## Priority: Medium

## Description
The P2P mesh system documentation shows incorrect struct definitions and function signatures compared to the actual implementation.

## Documented Functionality
**File**: `docs/p2p-mesh-system.md`  
**Lines**: 294-304, 283

Documented:
```rust
struct SharedFile {
    file_hash: String,
    // ... other fields
}

async fn share_file(&self, file_path: PathBuf) -> Result<String, Box<dyn std::error::Error>>
```

## Implemented Functionality  
**File**: `src/p2p_mesh.rs`  
**Lines**: 17-29, 379+

Actual implementation:
```rust
struct SharedFile {
    pub id: String,
    pub file_hash: String,
    pub file_path: Option<PathBuf>,
    pub metadata: FileMetadata,
    pub chunks: Vec<FileChunk>,
    pub completed: bool,
    pub peers: Vec<String>,
    pub created_at: u64,
}

// Function has additional parameters including tags
```

## Issue
1. **Struct field mismatch**: Documentation missing several fields (`id`, `file_path`, `metadata`, `chunks`, `completed`, `peers`, `created_at`)
2. **Function signature mismatch**: `share_file` function has different parameters in implementation
3. **Missing functionality**: Documentation doesn't cover chunk-based file sharing, metadata handling, or peer tracking

## Impact
- Developers using the documentation will write incorrect code
- Integration examples won't compile
- Feature capabilities are understated

## Suggested Fix
Update `docs/p2p-mesh-system.md` lines 294-304 with correct struct definition:

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SharedFile {
    pub id: String,
    pub file_hash: String,
    pub file_path: Option<PathBuf>,
    pub metadata: FileMetadata,
    pub chunks: Vec<FileChunk>,
    pub completed: bool,
    pub peers: Vec<String>,
    pub created_at: u64,
}
```

Update function signatures and add documentation for:
- Chunk-based file transfer mechanism
- Metadata and peer tracking features
- File completion and verification process

## Related Files
- `docs/p2p-mesh-system.md` (lines 294-304, 283)
- `src/p2p_mesh.rs` (lines 17-29, 379+)
- `docs/p2p-developer-guide.md` (may also need updates)

## Cross-References
- Related to P2P integration work completed
- May impact cryptographic communication implementation