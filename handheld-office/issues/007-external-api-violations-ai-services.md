# Issue #007: External API Violations in AI Services

## Priority: CRITICAL

## Description
The AI image service violates the P2P-only encrypted communication requirement by connecting to external HTTP APIs, including Stable Diffusion WebUI and other local services.

## Required Functionality (per `/notes/cryptographic-communication-vision`)
The security architecture specifies:
1. **Anbernic devices**: ONLY P2P-encrypted communication OR bytecode to paired laptops
2. **Laptop daemon**: CAN access external services as secure proxy for Anbernic devices
3. **All Anbernic communications**: Must be encrypted using relationship-specific PGP keys
4. **External access**: Only via laptop daemon with permission system and bytecode instructions

## Current Implementation Issues
**File**: `src/ai_image_service.rs` (AI Image Service)  
**Context**: This appears to be running ON the Anbernic device, not the laptop daemon

### Violation 1: Anbernic Device Making External HTTP Calls
```rust
// Line 295 - Anbernic device connecting directly to external service
.post("http://127.0.0.1:7860/sdapi/v1/txt2img")
```

### Violation 2: Missing Bytecode Instruction Interface
```rust  
// Lines 279-318 - Direct HTTP instead of bytecode to laptop daemon
async fn try_automatic1111(...)
```

### Violation 3: Wrong Security Boundary
- AI service should run on laptop daemon, not Anbernic device
- Anbernic should send bytecode instructions to paired laptop
- Laptop daemon should handle external API calls securely

## Impact
- **Architecture Violation**: Anbernic device accessing external services directly
- **Security Boundary**: Breaks the laptop-as-gateway security model
- **Missing Infrastructure**: No bytecode instruction system implemented
- **Vision Non-Compliance**: Violates the secure delegation model

## Required Fixes

### Option 1: Implement Proper Bytecode Architecture (RECOMMENDED)
Move AI service to laptop daemon and implement bytecode interface:
```rust
// ON ANBERNIC DEVICE: Send bytecode instruction to laptop daemon
pub async fn request_image_generation(
    &self,
    prompt: &str,
    laptop_daemon: &EncryptedConnection,
) -> Result<String, Box<dyn std::error::Error>> {
    let bytecode = ImageGenerationBytecode {
        instruction: Instruction::GenerateImage,
        prompt: prompt.to_string(),
        style: "default",
        resolution: "512x512",
    };
    
    laptop_daemon.send_encrypted_bytecode(bytecode).await
}

// ON LAPTOP DAEMON: Handle bytecode and make external API calls
pub async fn handle_image_generation_bytecode(
    &self,
    bytecode: ImageGenerationBytecode,
    requester_relationship: &RelationshipId,
) -> Result<Vec<u8>, Box<dyn std::error::Error>> {
    // Check permissions for this relationship
    if !self.permissions.allows_image_generation(requester_relationship) {
        return Err("Image generation not permitted".into());
    }
    
    // Make external API call (ONLY on laptop daemon)
    let response = reqwest::Client::new()
        .post("http://127.0.0.1:7860/sdapi/v1/txt2img")
        .json(&bytecode.to_api_request())
        .send()
        .await?;
        
    // Return encrypted result to Anbernic device
}
```

### Option 2: Local-Only AI Service
Keep AI service on Anbernic but remove external dependencies:
```rust
// Use only local generation methods:
// - ASCII art generation (already implemented)
// - Local candle-diffusers models (if hardware permits)
// - Simple procedural generation
```

### Option 3: P2P AI Distribution
Route AI requests through encrypted P2P to other OfficeOS devices:
```rust
// Send requests to other Anbernic devices with more powerful hardware
// All communication via encrypted P2P mesh
```

## Cross-References
- Related to `/notes/cryptographic-communication-vision`
- Connects to missing modules in Issue #001
- Part of P2P compliance review from claude-next-4

## Immediate Action Required
This is a CRITICAL violation of the core architecture requirements. External API calls must be removed or made compliant before any production deployment.

## Files to Modify
- `src/ai_image_service.rs` (lines 272-318, 295 specifically)
- Remove or disable `try_automatic1111` function
- Remove or disable `try_comfyui` function  
- Keep only local generation methods (ASCII art, etc.)

## Testing Required
- Verify no external HTTP connections are made
- Test that AI features work with local-only generation
- Confirm P2P integration works for image sharing