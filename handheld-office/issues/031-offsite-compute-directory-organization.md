# Issue #031: Offsite Compute Infrastructure Organization in src/networking/

## Priority: HIGH

## Description
Organize the laptop daemon and related offsite compute services into a dedicated `src/networking/offsite-compute/` directory structure. This includes the laptop server daemon that listens for encrypted P2P requests from Anbernic devices and forwards them to external services using traditional networking, all while maintaining the air-gapped security architecture through bytecode VM communication.

## Current Offsite Compute Files

### Laptop Daemon System
- `src/laptop_daemon.rs` → `src/networking/offsite-compute/src/laptop_daemon.rs`
- `src/bin/laptop_daemon.rs` → `src/networking/offsite-compute/bin/laptop_daemon.rs`

### AI/LLM Services  
- `src/desktop_llm.rs` → `src/networking/offsite-compute/src/desktop_llm.rs`
- `src/ai_image_service.rs` → `src/networking/offsite-compute/src/ai_image_service.rs`

### Bytecode VM System (Already in crypto module)
- `src/crypto/bytecode.rs` (stays in `src/networking/src/crypto/`)
- `src/crypto/bytecode_executor.rs` (stays in `src/networking/src/crypto/`)

## Target Directory Structure

```
src/networking/offsite-compute/
├── src/                           # Offsite compute implementations
│   ├── laptop_daemon.rs           # Main laptop daemon server
│   ├── desktop_llm.rs             # LLM processing service
│   ├── ai_image_service.rs        # AI image generation service
│   ├── proxy_manager.rs           # NEW: Manages external service proxying
│   ├── permission_manager.rs      # NEW: Per-device permission management
│   └── mod.rs                     # Module declarations
├── bin/                           # Offsite compute executables
│   ├── laptop_daemon.rs           # Laptop daemon executable
│   ├── llm_service.rs             # NEW: Standalone LLM service
│   └── image_service.rs           # NEW: Standalone image service
├── config/                        # Configuration files
│   ├── daemon.toml                # Daemon configuration template
│   ├── permissions.toml           # Permission templates
│   └── services.toml              # Service configuration
├── docs -> ../../../docs          # Symlink to main docs
├── notes -> ../../../notes        # Symlink to main notes
└── build/                         # Build artifacts
```

## Offsite Compute Architecture

### WiFi Direct P2P → Laptop Bridge
```
[Anbernic Device] 
    ↓ WiFi Direct P2P (encrypted bytecode)
[Laptop Daemon] 
    ↓ Traditional networking (HTTP/API)
[External Services: OpenAI, Stability AI, etc.]
```

### Security Layer Separation
1. **Anbernic ↔ Laptop**: Encrypted bytecode VM communication (air-gapped compliant)
2. **Laptop ↔ External**: Traditional HTTP/API calls (laptop handles external dependencies)
3. **Permission System**: Per-device, per-service authorization

### Bytecode VM Integration
- **Encrypted Packets**: All Anbernic→Laptop communication uses bytecode instructions
- **VM Execution**: Laptop daemon executes bytecode safely in isolated environment
- **Response Encoding**: External service responses encoded as bytecode responses
- **No Direct API Access**: Anbernic devices never make external HTTP calls

## Files That Need Path Updates

### Import Statements Throughout Codebase
```rust
// OLD IMPORTS
use crate::laptop_daemon::*;
use crate::desktop_llm::*;
use crate::ai_image_service::*;

// NEW IMPORTS
use crate::networking::offsite_compute::laptop_daemon::*;
use crate::networking::offsite_compute::desktop_llm::*;
use crate::networking::offsite_compute::ai_image_service::*;
```

### Likely Files Needing Updates
- `src/handheld.rs` - May import laptop daemon for connectivity
- `src/crypto/bytecode_executor.rs` - Integrates with laptop daemon services
- `src/wifi_direct_p2p.rs` - Handles P2P communication to laptop daemon
- Any demo files that use LLM or AI image services

## Required Module Structure

### src/networking/offsite-compute/src/mod.rs
```rust
pub mod laptop_daemon;
pub mod desktop_llm;
pub mod ai_image_service;
pub mod proxy_manager;
pub mod permission_manager;

// Re-export main daemon interface
pub use laptop_daemon::{LaptopDaemon, LaptopDaemonConfig};
pub use desktop_llm::{DesktopLlmService, LlmRequest, LlmResponse};
pub use ai_image_service::{AiImageService, ImageGenerationRequest, ImageGenerationResponse};

// New management interfaces
pub use proxy_manager::ExternalServiceProxy;
pub use permission_manager::{DevicePermissionManager, ServicePermissions};
```

### Updated Networking Module
```rust
// src/networking/src/mod.rs - Add offsite compute
pub mod offsite_compute;

// Re-export for convenience
pub use offsite_compute::{LaptopDaemon, DesktopLlmService, AiImageService};
```

## New Files to Create

### Proxy Manager (NEW)
```rust
// src/networking/offsite-compute/src/proxy_manager.rs
/// Manages proxying requests to external services while maintaining security
pub struct ExternalServiceProxy {
    // Handles HTTP calls to OpenAI, Stability AI, etc.
    // Converts bytecode instructions to external API calls
    // Manages rate limiting and error handling
}
```

### Permission Manager (NEW)
```rust
// src/networking/offsite-compute/src/permission_manager.rs
/// Per-device permission management for offsite compute services
pub struct DevicePermissionManager {
    // Tracks which devices can access which services
    // Manages permission levels (deny, allow with confirmation, allow without asking)
    // Integrates with relationship-based encryption
}
```

### Configuration Templates
```toml
# src/networking/offsite-compute/config/daemon.toml
[daemon]
device_name = "Laptop Daemon"
max_paired_devices = 8
auto_accept_pairing = false

[services]
llm_enabled = true
image_generation_enabled = true
file_torrenting_enabled = false

[external_apis]
openai_api_key = ""  # Set via environment variable
stability_api_key = ""  # Set via environment variable
rate_limit_requests_per_minute = 60

[networking]
wifi_direct_enabled = true
bind_address = "127.0.0.1"
bind_port = 8080
```

## Cargo.toml Updates Required

### Binary Path Updates
```toml
# OLD PATHS
[[bin]]
name = "laptop-daemon"
path = "src/laptop_daemon.rs"

[[bin]]
name = "desktop-llm"
path = "src/desktop_llm.rs"

# NEW PATHS
[[bin]]
name = "laptop-daemon"
path = "src/networking/offsite-compute/bin/laptop_daemon.rs"

[[bin]]
name = "desktop-llm"
path = "src/networking/offsite-compute/src/desktop_llm.rs"  # Keep as service module

# NEW BINARIES
[[bin]]
name = "llm-service"
path = "src/networking/offsite-compute/bin/llm_service.rs"

[[bin]]
name = "image-service"
path = "src/networking/offsite-compute/bin/image_service.rs"
```

## Architecture Compliance Requirements

### Air-Gapped Security Maintained
- **No Direct External APIs from Anbernic**: All external calls proxy through laptop
- **Encrypted P2P Only**: Anbernic↔Laptop uses relationship-specific encryption
- **Bytecode VM Isolation**: External service requests isolated in VM environment
- **Permission-Based Access**: Per-device, per-service authorization

### Bytecode VM Integration
```rust
// Example: LLM request flow
// 1. Anbernic sends encrypted bytecode instruction
let bytecode_instruction = BytecodeInstruction {
    op_code: OpCode::LLMRequest,
    data: encrypted_llm_request,
    device_id: relationship_id,
};

// 2. Laptop daemon executes in VM
let vm_result = bytecode_executor.execute(bytecode_instruction).await?;

// 3. Laptop makes external HTTP call
let external_response = openai_client.completions(llm_request).await?;

// 4. Laptop returns encrypted bytecode response
let bytecode_response = BytecodeResponse {
    op_code: OpCode::LLMResponse,
    data: encrypted_llm_response,
    execution_status: ExecutionStatus::Success,
};
```

## Implementation Strategy

### Phase 1: Directory Creation and Structure
1. Create `src/networking/offsite-compute/` directory tree
2. Create module files and basic structure
3. Add symlinks to docs and notes

### Phase 2: File Migration
1. Move laptop daemon files with `git mv`
2. Move LLM and AI image service files  
3. Update internal imports within moved files

### Phase 3: New Component Creation
1. Implement `proxy_manager.rs` for external service handling
2. Implement `permission_manager.rs` for device authorization
3. Create configuration templates and standalone binaries

### Phase 4: Integration Updates
1. Update all import statements throughout codebase
2. Update Cargo.toml binary paths
3. Test compilation and functionality

### Git History Preservation
```bash
# Move existing files preserving history
git mv src/laptop_daemon.rs src/networking/offsite-compute/src/laptop_daemon.rs
git mv src/desktop_llm.rs src/networking/offsite-compute/src/desktop_llm.rs
git mv src/ai_image_service.rs src/networking/offsite-compute/src/ai_image_service.rs
git mv src/bin/laptop_daemon.rs src/networking/offsite-compute/bin/laptop_daemon.rs
```

## Testing Requirements

### Compilation Tests
```bash
# Test offsite compute builds
cargo build --bin laptop-daemon
cargo build --bin llm-service
cargo build --bin image-service

# Test module compilation
cargo check --lib

# Test integration
cargo test networking::offsite_compute
```

### Functionality Tests
```bash
# Test laptop daemon startup
./target/release/laptop-daemon --config config/daemon.toml --test

# Test P2P connectivity
./target/release/laptop-daemon --test-p2p

# Test external service proxying
./target/release/laptop-daemon --test-external-apis
```

### Security Validation
- Verify no direct external API calls from Anbernic side
- Test bytecode VM isolation and execution
- Validate permission system works correctly
- Ensure encrypted P2P communication maintained

## Dependencies
- **Depends on**: Issue #029 (Networking reorganization) completion
- **Blocks**: Clean offsite compute architecture
- **Related**: External API violation fixes (Issues #007, #008)

## Success Criteria
- [ ] All offsite compute files moved to proper directory structure
- [ ] New proxy and permission management components created
- [ ] All import statements updated throughout codebase
- [ ] Cargo.toml binary paths updated correctly
- [ ] Laptop daemon compiles and runs correctly
- [ ] P2P bytecode communication preserved
- [ ] External service proxying works correctly
- [ ] Permission system functional
- [ ] Air-gapped security architecture maintained
- [ ] Configuration templates created and documented

## Risk Assessment
- **High Risk**: Laptop daemon is critical for offsite compute functionality
- **Medium Risk**: External API integration complexity
- **Mitigation**: Comprehensive testing, preserve bytecode VM isolation
- **Security Priority**: Maintain air-gapped compliance during reorganization

**Filed by**: Offsite compute architecture organization  
**Date**: 2025-09-23  
**Complexity**: High - critical infrastructure with security requirements