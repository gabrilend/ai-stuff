# Issue #008: External LLM API Violations in Desktop LLM Service

## Priority: CRITICAL

## Description
The desktop LLM service violates P2P-only requirements by connecting to external HTTP APIs for LLM inference, including llama-cpp-python and KoboldCPP servers.

## Required Functionality (per `/notes/cryptographic-communication-vision`)
The security architecture specifies:
1. **Anbernic devices**: ONLY P2P-encrypted communication OR bytecode to paired laptops
2. **Laptop daemon**: CAN access external services as secure proxy for Anbernic devices  
3. **All Anbernic communications**: Must be encrypted using relationship-specific keys (Ed25519 + X25519 + ChaCha20-Poly1305)
4. **External access**: Only via laptop daemon with permission system and bytecode instructions

## Current Implementation Analysis
**File**: `src/desktop_llm.rs` (Desktop LLM Service)  
**Context**: This appears to be the laptop daemon service - external APIs may be ALLOWED here

### Potential Issue 1: Service Location Unclear
```rust
// If this runs on Anbernic device - VIOLATION
// If this runs on laptop daemon - ALLOWED
http://localhost:8000/v1/completions
```

### Potential Issue 2: Missing Permission System
```rust
// Missing: Permission checks for relationship-based access control
// Missing: Bytecode instruction interface for Anbernic requests
http://localhost:5001/api/v1/generate
```

### Potential Issue 3: No Bytecode Interface
- Service should accept bytecode instructions from Anbernic devices
- Current implementation appears to be direct API usage
- Missing relationship-based permission validation

## Impact (If Running on Anbernic Device)
- **Architecture Violation**: Anbernic device accessing external services directly
- **Security Boundary**: Breaks the laptop-as-gateway security model
- **Missing Infrastructure**: No bytecode instruction system implemented

## Impact (If Running on Laptop Daemon)
- **Missing Security**: No permission system for relationship-based access
- **Missing Interface**: No bytecode instruction handling for Anbernic requests
- **Architecture Incomplete**: Should be proxy service, not direct API access

## Required Fixes

### Option 1: Implement Complete Laptop Daemon Architecture (RECOMMENDED)
If this is the laptop daemon, implement proper bytecode interface:
```rust
// LAPTOP DAEMON: Accept bytecode from Anbernic devices
pub struct LaptopDaemon {
    permissions: PermissionManager,
    llm_services: Vec<LLMBackend>,
    active_relationships: HashMap<RelationshipId, DeviceConnection>,
}

impl LaptopDaemon {
    pub async fn handle_llm_bytecode(
        &self,
        bytecode: LLMBytecode,
        requester_relationship: &RelationshipId,
    ) -> Result<String, Box<dyn std::error::Error>> {
        // Check permissions for this specific relationship
        if !self.permissions.allows_llm_access(requester_relationship) {
            return Err("LLM access not permitted for this relationship".into());
        }
        
        // Make external API call (ALLOWED on laptop daemon)
        match bytecode.instruction {
            LLMInstruction::GenerateText { prompt, max_tokens } => {
                let response = reqwest::Client::new()
                    .post("http://localhost:8000/v1/completions")
                    .json(&json!({
                        "prompt": prompt,
                        "max_tokens": max_tokens,
                    }))
                    .send()
                    .await?;
                    
                // Return encrypted result to Anbernic device
                Ok(response.text().await?)
            }
        }
    }
}

// ANBERNIC DEVICE: Send bytecode to laptop daemon
pub async fn request_llm_generation(
    &self,
    prompt: &str,
    laptop_daemon: &EncryptedConnection,
) -> Result<String, Box<dyn std::error::Error>> {
    let bytecode = LLMBytecode {
        instruction: LLMInstruction::GenerateText {
            prompt: prompt.to_string(),
            max_tokens: 150,
        },
    };
    
    laptop_daemon.send_encrypted_bytecode(bytecode).await
}
```

### Option 2: Move Service to Anbernic with Local Models
If this should run on Anbernic, remove external APIs:
```rust
// Use local inference only:
// - candle-transformers for local LLM inference
// - Smaller models that fit on handheld hardware
// - Text processing without external dependencies
```

### Option 3: Clarify Service Architecture
Determine proper service location and implement accordingly:
- If laptop daemon: Add bytecode interface and permissions
- If Anbernic service: Remove external API calls
- Implement proper encrypted communication between services

## Specific Code Changes Required

### Remove External API Dependencies
**Files to modify:**
- `src/desktop_llm.rs` (remove HTTP client code)
- Any configuration that references localhost:8000 or localhost:5001

### Replace with Local Inference
```rust
// Replace HTTP-based inference with:
pub struct LocalLLMService {
    model: Option<LlamaModel>,
    device: Device,
    tokenizer: Tokenizer,
}

impl LocalLLMService {
    pub async fn load_model(&mut self, model_path: &str) -> Result<()> {
        // Load model directly into memory
    }
    
    pub async fn generate(&self, prompt: &str) -> Result<String> {
        // Run inference locally without HTTP
    }
}
```

## Cross-References
- Related to Issue #007 (AI Service external APIs)
- Connected to `/notes/cryptographic-communication-vision` requirements
- Part of claude-next-4 P2P compliance review

## Immediate Action Required
This is a CRITICAL violation. External HTTP APIs for LLM services must be removed to comply with P2P-only architecture.

## Testing Required
- Verify no external HTTP connections for LLM inference
- Test local model loading and inference
- Confirm P2P integration works for LLM services
- Validate encrypted communication for any remote LLM requests

## Files to Audit
- `src/desktop_llm.rs` (primary violations)
- Any configuration files referencing external LLM endpoints
- Documentation claiming P2P-only operation