# Issue #007: External API Violations in AI Services

## Priority: CRITICAL

## Status: ⚠️ *Architecture Designed* - Bytecode interface ready, needs integration

## Description
The AI image service architecture needs clarification regarding the correct deployment model. The service should run on the laptop daemon as a secure proxy, where HTTP calls to external services are permitted, but Anbernic devices must communicate only via encrypted WiFi Direct bytecode instructions.

## Required Functionality (per `/notes/cryptographic-communication-vision`)
The security architecture specifies:
1. **Anbernic devices**: ONLY P2P-encrypted communication OR bytecode to paired laptops
2. **Laptop daemon**: CAN access external services as secure proxy for Anbernic devices
3. **All Anbernic communications**: Must be encrypted using relationship-specific keys (Ed25519 + X25519 + ChaCha20-Poly1305)
4. **External access**: Only via laptop daemon with permission system and bytecode instructions

## Current Implementation Analysis
**File**: `src/ai_image_service.rs` (AI Image Service)  
**Deployment Context**: **LAPTOP DAEMON** (HTTP calls are PERMITTED here)

### ✅ **CORRECT: Laptop Daemon HTTP Calls**
```rust
// Line 283 - ALLOWED: Laptop daemon acting as secure proxy for external services
let client = reqwest::Client::new();
.post("http://127.0.0.1:7860/sdapi/v1/txt2img")
```
**Status**: HTTP calls are architecturally correct when running on laptop daemon

### ❌ **MISSING: Bytecode Interface for Anbernic Communication**
```rust  
// NEEDED: Bytecode instruction handler to receive requests from Anbernic devices
async fn handle_image_generation_bytecode(
    &self,
    bytecode: ImageGenerationBytecode,
    requester_relationship: &RelationshipId,
) -> Result<Vec<u8>, Box<dyn std::error::Error>>
```

### ⚠️ **INTEGRATION GAP: Anbernic → Laptop Communication**
- ✅ Laptop daemon external HTTP calls (correct)
- ❌ Missing: Anbernic devices sending bytecode instructions to laptop
- ❌ Missing: Laptop daemon translating bytecode to HTTP requests
- ❌ Missing: Response translation from HTTP back to encrypted bytecode

## Impact
- **Architecture Status**: ✅ Laptop daemon HTTP calls are CORRECT (secure proxy model)
- **Integration Gap**: ❌ Missing bytecode communication layer between Anbernic and laptop
- **Data Flow**: ❌ No WiFi Direct → Bytecode → HTTP → External Services pipeline
- **Current State**: Service runs correctly on laptop but lacks Anbernic device integration

## Required Fixes

### Option 1: Complete Bytecode Integration (RECOMMENDED)
AI service correctly runs on laptop daemon, now implement bytecode interface for Anbernic communication:
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
    
    // ✅ CORRECT: External API call from laptop daemon (acting as secure proxy)
    let response = reqwest::Client::new()
        .post("http://127.0.0.1:7860/sdapi/v1/txt2img")
        .json(&bytecode.to_api_request())
        .send()
        .await?;
        
    // Process response and encrypt for Anbernic device
    let image_data = self.process_external_response(response).await?;
    
    // Return encrypted bytecode response to Anbernic via WiFi Direct
    self.encrypt_and_send_to_anbernic(image_data, requester_relationship).await
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

## Architecture Clarification
The external HTTP calls in this service are CORRECT when running on laptop daemon. The critical missing piece is the bytecode communication interface between Anbernic devices and the laptop daemon proxy.

## Files to Modify
- `src/ai_image_service.rs` (lines 272-318, 295 specifically)
- Remove or disable `try_automatic1111` function
- Remove or disable `try_comfyui` function  
- Keep only local generation methods (ASCII art, etc.)

## Testing Required
- Verify no external HTTP connections are made
- Test that AI features work with local-only generation
- Confirm P2P integration works for image sharing